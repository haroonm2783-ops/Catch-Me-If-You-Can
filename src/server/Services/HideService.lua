-- Hiding, searching, scanning and mall-coin pickups. Every rule here is server-owned: clients only
-- fire ProximityPrompts or the Scan/Unhide actions; the server validates role, phase, distance,
-- cooldowns and then moves avatars itself.
--
-- Design goals: hiding is a short breather that costs a cooldown, never a safe zone. Hunters have
-- three fair counters: spot a tell (feet under the curtain), Search a cell (ejects an occupant next
-- to the searcher), or pulse a Scan that exposes nearby runners and occupied cells.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HideService = {}
HideService.__index = HideService

local function now()
	return Workspace:GetServerTimeNow()
end

local function liveCharacter(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and humanoid and humanoid.Health > 0 and root then
		return character, humanoid, root
	end
	return nil
end

function HideService.new(ctx)
	return setmetatable({
		ctx = ctx,
		spots = {},
		spotByPrompt = {},
		hiding = {},          -- player -> {spot, endsAt, character}
		cooldownUntil = {},   -- player -> hide cooldown deadline
		lastSearch = {},      -- hunter -> time
		scanReadyAt = {},     -- hunter -> time
		closeCall = {},       -- runner -> {near, last}
		coins = {},
		coinBuckets = {},
		connections = {},
		accumulator = 0,
	}, HideService)
end

function HideService:_config()
	return self.ctx.Config.Hide
end

function HideService:_notice(player, payload)
	if player.Parent == Players then
		self.ctx.Remotes.Notice:FireClient(player, payload)
	end
end

function HideService:_round()
	return self.ctx.Services.RoundService
end

-- Map data ---------------------------------------------------------------------------------------

function HideService:_collect()
	local model = self.ctx.World and self.ctx.World.Model
	if not model then
		return
	end
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Model") and descendant:GetAttribute("CatchHideSpot") then
			local prompt = descendant:FindFirstChild("HidePrompt", true)
			local door = descendant:FindFirstChild("Door")
			local inside, exit = descendant:GetAttribute("InsideCFrame"), descendant:GetAttribute("ExitCFrame")
			if prompt and prompt:IsA("ProximityPrompt") and typeof(inside) == "CFrame" and typeof(exit) == "CFrame" then
				local spot = {
					id = descendant:GetAttribute("SpotId"), model = descendant, prompt = prompt, door = door,
					inside = inside, exit = exit, occupant = nil, lockedUntil = 0, anchorPart = prompt.Parent,
				}
				table.insert(self.spots, spot)
				self.spotByPrompt[prompt] = spot
				descendant:SetAttribute("Occupied", false)
				table.insert(self.connections, prompt.Triggered:Connect(function(player)
					local ok, err = pcall(function() self:_triggered(player, spot) end)
					if not ok then warn("[Catch hide] prompt failed: " .. tostring(err)) end
				end))
			end
		end
	end
	local folder = model:FindFirstChild("MallCoins")
	if folder then
		for _, coin in ipairs(folder:GetChildren()) do
			if coin:IsA("BasePart") then
				local position = coin.Position
				local record = {part = coin, position = position, collected = false}
				table.insert(self.coins, record)
				local key = math.floor(position.X / 12) .. "," .. math.floor(position.Z / 12) .. "," .. math.floor(position.Y / 12)
				local bucket = self.coinBuckets[key]
				if not bucket then
					bucket = {}
					self.coinBuckets[key] = bucket
				end
				table.insert(bucket, record)
			end
		end
	end
end

-- Hiding -----------------------------------------------------------------------------------------

function HideService:IsHiding(player)
	return self.hiding[player] ~= nil
end

function HideService:_release(player, reason, teleport)
	local state = self.hiding[player]
	if not state then
		return false
	end
	self.hiding[player] = nil
	local spot, config = state.spot, self:_config()
	spot.occupant = nil
	spot.lockedUntil = now() + config.SpotLock
	spot.model:SetAttribute("Occupied", false)
	spot.model:SetAttribute("OccupantUserId", 0)
	local character = state.character
	local movement = self.ctx.Services.MovementService
	if character and character.Parent then
		character:SetAttribute("CatchHiding", false)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = character:GetAttribute("RoundFrozen") == true
			if teleport then
				root.CFrame = spot.exit
				root.AssemblyLinearVelocity = Vector3.zero
			end
			if movement and player.Character == character then
				movement:ResetPlayer(player)
			end
		end
	end
	if reason ~= "round" then
		self.cooldownUntil[player] = now() + config.Cooldown
	end
	self:_notice(player, {kind = "hide", state = "out", reason = reason, cooldown = reason ~= "round" and config.Cooldown or 0})
	return true
end

function HideService:_enter(player, spot)
	local character, humanoid, root = liveCharacter(player)
	if not character or character:GetAttribute("Sliding") or character:GetAttribute("Vaulting") or character:GetAttribute("RoundFrozen") then
		return
	end
	local config = self:_config()
	local movement = self.ctx.Services.MovementService
	root.CFrame = spot.inside
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	if movement then
		movement:ResetPlayer(player)
	end
	root.Anchored = true
	humanoid.AutoRotate = false
	character:SetAttribute("CatchHiding", true)
	character:SetAttribute("Sprinting", false)
	local endsAt = now() + config.MaxSeconds
	self.hiding[player] = {spot = spot, endsAt = endsAt, character = character}
	spot.occupant = player
	spot.model:SetAttribute("Occupied", true)
	spot.model:SetAttribute("OccupantUserId", player.UserId)
	self:_notice(player, {kind = "hide", state = "in", endsAt = endsAt, duration = config.MaxSeconds, spotId = spot.id})
end

function HideService:_eject(spot, reason)
	local occupant = spot.occupant
	if not occupant then
		return nil
	end
	self:_release(occupant, reason, true)
	return occupant
end

-- A runner asks to leave early (also fired by the prompt on their own cell).
function HideService:Leave(player)
	local state = self.hiding[player]
	if not state then
		return false
	end
	-- A short minimum stay stops a flicker of in-and-out used to dodge a tag.
	if now() - (state.endsAt - self:_config().MaxSeconds) < 0.6 then
		return false
	end
	self:_release(player, "left", true)
	return true
end

function HideService:_inRange(player, spot)
	local _, _, root = liveCharacter(player)
	if not root then
		return false
	end
	local part = spot.anchorPart
	local reach = (spot.prompt.MaxActivationDistance or 8) + self:_config().PromptSlack
	return (root.Position - part.Position).Magnitude <= reach
end

function HideService:_triggered(player, spot)
	local round = self:_round()
	if not round or round.phase ~= "Active" or not round:IsActive(player) or not self:_inRange(player, spot) then
		return
	end
	local role = round:GetRole(player)
	local timestamp = now()
	local config = self:_config()
	if role == "Runner" then
		local state = self.hiding[player]
		if state then
			if state.spot == spot then
				self:Leave(player)
			end
			return
		end
		if spot.occupant then
			self:_notice(player, {kind = "toast", text = "Someone is already in there!"})
			return
		end
		if timestamp < spot.lockedUntil then
			self:_notice(player, {kind = "toast", text = "The door is still swinging. Try another spot."})
			return
		end
		local waiting = (self.cooldownUntil[player] or 0) - timestamp
		if waiting > 0 then
			self:_notice(player, {kind = "toast", text = string.format("Catch your breath: %d s until you can hide again.", math.ceil(waiting))})
			return
		end
		self:_enter(player, spot)
	elseif role == "Hunter" then
		if timestamp - (self.lastSearch[player] or -math.huge) < config.SearchCooldown then
			return
		end
		local character = player.Character
		if not character or character:GetAttribute("RoundFrozen") then
			return
		end
		self.lastSearch[player] = timestamp
		local found = self:_eject(spot, "found")
		if found then
			local entry = round.roster[player.UserId]
			if entry then entry.finds = math.min((entry.finds or 0) + 1, 10) end
			-- Everyone nearby sees the reveal; the searcher gets the discovery cue.
			self.ctx.Remotes.Notice:FireAllClients({kind = "reveal", userId = found.UserId, duration = 2.5})
			self:_notice(player, {kind = "found", text = "FOUND " .. string.upper(found.DisplayName) .. "!"})
		else
			self:_notice(player, {kind = "toast", text = "Nobody here. Keep looking!"})
		end
	end
end

-- Hunter scan ------------------------------------------------------------------------------------

function HideService:Scan(player)
	local round = self:_round()
	if not round or round.phase ~= "Active" or not round:IsActive(player) or round:GetRole(player) ~= "Hunter" then
		return false
	end
	local config, timestamp = self:_config(), now()
	if timestamp < (self.scanReadyAt[player] or 0) then
		return false
	end
	local character, _, root = liveCharacter(player)
	if not character or character:GetAttribute("RoundFrozen") then
		return false
	end
	self.scanReadyAt[player] = timestamp + config.ScanCooldown
	local targets, spots = {}, {}
	for _, entry in pairs(round.roster) do
		if entry.role == "Runner" and entry.alive and entry.player ~= player and entry.player.Parent == Players then
			local _, _, targetRoot = liveCharacter(entry.player)
			if targetRoot and (targetRoot.Position - root.Position).Magnitude <= config.ScanRadius then
				if not self.hiding[entry.player] then
					table.insert(targets, entry.player.UserId)
				end
			end
		end
	end
	-- Occupied cells are exposed as "something is in there", never as a named player.
	for _, spot in ipairs(self.spots) do
		if spot.occupant and (spot.anchorPart.Position - root.Position).Magnitude <= config.ScanRadius then
			table.insert(spots, spot.anchorPart.Position + Vector3.new(0, 4, 0))
		end
	end
	self:_notice(player, {kind = "ability", action = "Scan", cooldown = config.ScanCooldown})
	self:_notice(player, {kind = "scan", targets = targets, spots = spots, duration = config.ScanDuration})
	return true
end

-- Coins and close calls --------------------------------------------------------------------------

function HideService:_collectCoins(player, root)
	local position = root.Position
	local radius = self:_config().PickupRadius
	local cx, cz, cy = math.floor(position.X / 12), math.floor(position.Z / 12), math.floor((position.Y + 3) / 12)
	local round = self:_round()
	for dx = -1, 1 do
		for dz = -1, 1 do
			for dy = -1, 1 do
				local bucket = self.coinBuckets[(cx + dx) .. "," .. (cz + dz) .. "," .. (cy + dy)]
				if bucket then
					for _, coin in ipairs(bucket) do
						if not coin.collected and (coin.position - position).Magnitude <= radius then
							local count = round:AddPickup(player)
							if count then
								coin.collected = true
								coin.part.Transparency = 1
								coin.part:SetAttribute("Collected", true)
								for _, child in ipairs(coin.part:GetChildren()) do
									if child:IsA("BasePart") then child.Transparency = 1 end
								end
								self:_notice(player, {kind = "pickup", count = count, cap = self:_config().PickupCap, position = coin.position})
							end
						end
					end
				end
			end
		end
	end
end

function HideService:_closeCalls(player, root, hunterRoots)
	local config, timestamp = self:_config(), now()
	local record = self.closeCall[player]
	if not record then
		record = {}
		self.closeCall[player] = record
	end
	local nearest = math.huge
	for _, hunterRoot in ipairs(hunterRoots) do
		nearest = math.min(nearest, (hunterRoot.Position - root.Position).Magnitude)
	end
	if nearest <= config.CloseCallNear then
		record.near = timestamp
	elseif record.near then
		if nearest >= config.CloseCallFar then
			if timestamp - record.near <= 4 and timestamp - (record.last or -math.huge) >= config.CloseCallGap then
				record.last = timestamp
				self:_round():AddCloseCall(player)
			end
			record.near = nil
		elseif timestamp - record.near > 4 then
			record.near = nil
		end
	end
end

-- Lifecycle --------------------------------------------------------------------------------------

function HideService:ResetRound()
	for player in pairs(self.hiding) do
		self:_release(player, "round", false)
	end
	table.clear(self.cooldownUntil)
	table.clear(self.lastSearch)
	table.clear(self.scanReadyAt)
	table.clear(self.closeCall)
	for _, coin in ipairs(self.coins) do
		coin.collected = false
		coin.part.Transparency = 0
		coin.part:SetAttribute("Collected", false)
		for _, child in ipairs(coin.part:GetChildren()) do
			if child:IsA("BasePart") then child.Transparency = 0 end
		end
	end
end

function HideService:_tick()
	local round = self:_round()
	if not round then
		return
	end
	local timestamp = now()
	local active = round.phase == "Active"
	for player, state in pairs(self.hiding) do
		local character = state.character
		if not active or player.Parent ~= Players or player.Character ~= character or not round:IsActive(player)
			or round:GetRole(player) ~= "Runner" or not liveCharacter(player) then
			self:_release(player, active and "gone" or "round", false)
		elseif timestamp >= state.endsAt then
			self:_release(player, "timeout", true)
		end
	end
	if not active then
		return
	end
	local hunterRoots = {}
	for _, entry in pairs(round.roster) do
		if entry.role == "Hunter" and entry.alive and entry.player.Parent == Players then
			local _, _, root = liveCharacter(entry.player)
			if root then table.insert(hunterRoots, root) end
		end
	end
	for _, entry in pairs(round.roster) do
		local player = entry.player
		if entry.role == "Runner" and entry.alive and player.Parent == Players and not self.hiding[player] and not round.practice then
			local character, _, root = liveCharacter(player)
			if character and not character:GetAttribute("RoundFrozen") then
				if #self.coins > 0 then self:_collectCoins(player, root) end
				if #hunterRoots > 0 then self:_closeCalls(player, root, hunterRoots) end
			end
		elseif entry.role == "Runner" and entry.alive and round.practice and player.Parent == Players and not self.hiding[player] then
			-- Practice still lets you collect coins for the feel of it (no rewards are granted).
			local character, _, root = liveCharacter(player)
			if character and #self.coins > 0 then self:_collectCoins(player, root) end
		end
	end
end

function HideService:Start()
	if self.started then
		return
	end
	self.started = true
	self:_collect()
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self.accumulator += dt
		if self.accumulator >= 0.12 then
			self.accumulator = 0
			local ok, err = pcall(function() self:_tick() end)
			if not ok then warn("[Catch hide] tick failed: " .. tostring(err)) end
		end
	end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
		if self.hiding[player] then self:_release(player, "round", false) end
		self.cooldownUntil[player], self.lastSearch[player], self.scanReadyAt[player], self.closeCall[player] = nil, nil, nil, nil
	end))
end

return HideService
