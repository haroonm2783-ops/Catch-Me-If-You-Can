-- Clients send intentions only. The server chooses speed, geometry, and cooldowns.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MovementService = {}
MovementService.__index = MovementService

local function now()
	return Workspace:GetServerTimeNow()
end

local function horizontal(vector)
	return Vector3.new(vector.X, 0, vector.Z)
end

local function finiteVector(vector)
	return vector.X == vector.X and vector.Y == vector.Y and vector.Z == vector.Z
		and math.abs(vector.X) < 1e7 and math.abs(vector.Y) < 1e7 and math.abs(vector.Z) < 1e7
end

local function avatar(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root then
		return character, humanoid, root
	end
	return nil
end

local function rayParameters(character)
	local parameters = RaycastParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { character }
	parameters.RespectCanCollide = true
	return parameters
end

function MovementService.new(ctx)
	return setmetatable({ ctx = ctx, states = {}, connections = {}, accumulator = 0 }, MovementService)
end

function MovementService:_state(player)
	local state = self.states[player]
	if not state then
		state = {
			sprint = false,
			slideUntil = 0,
			vaultUntil = 0,
			lastSlide = -math.huge,
			lastVault = -math.huge,
			modeId = 0,
			lastTime = now(),
			credit = 12,
		}
		self.states[player] = state
	end
	return state
end

function MovementService:_clearMotion(player, state)
	state.modeId += 1
	state.sprint = false
	state.slideUntil, state.vaultUntil = 0, 0
	local character = player.Character
	if character then
		character:SetAttribute("Sprinting", false)
		character:SetAttribute("Sliding", false)
		character:SetAttribute("Vaulting", false)
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.Anchored = character:GetAttribute("RoundFrozen") == true
			if not root.Anchored then
				pcall(function()
					root:SetNetworkOwnershipAuto()
				end)
			end
		end
	end
end

-- Only server code calls this immediately after its own spawn/teleport.
function MovementService:ResetPlayer(player)
	local state = self:_state(player)
	self:_clearMotion(player, state)
	local character, humanoid, root = avatar(player)
	state.character = character
	state.lastTime = now()
	state.lastSlide, state.lastVault = -math.huge, -math.huge
	state.airStart = nil
	state.groundY = root and root.Position.Y or 0
	state.credit = self.ctx.Config.Movement.RunnerSprint * 0.4 + 3
	state.lastPosition = root and root.Position or nil
	state.safeCFrame = root and root.CFrame or nil
	state.rejectUntil = 0
	if character then
		local frozen = character:GetAttribute("RoundFrozen") == true
		humanoid.WalkSpeed = frozen and 0 or self.ctx.Config.Movement.WalkSpeed
		humanoid.JumpPower = frozen and 0 or self.ctx.Config.Movement.JumpPower
		humanoid.AutoRotate = not frozen
	end
end

function MovementService:_grounded(character, humanoid, root)
	local distance = humanoid.HipHeight + root.Size.Y * 0.5 + 1.25
	local hit = Workspace:Raycast(root.Position, Vector3.new(0, -distance, 0), rayParameters(character))
	return hit ~= nil and hit.Normal.Y > 0.3, hit
end

function MovementService:_climbing(character, humanoid, root)
	if humanoid:GetState() ~= Enum.HumanoidStateType.Climbing then
		return false
	end
	-- A client-owned Humanoid state alone must not authorize unlimited ascent.
	local parameters = OverlapParams.new()
	parameters.FilterType = Enum.RaycastFilterType.Exclude
	parameters.FilterDescendantsInstances = { character }
	for _, part in ipairs(Workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(6, 8, 6), parameters)) do
		if part:IsA("TrussPart") then
			return true
		end
	end
	return false
end

function MovementService:_allowedSpeed(player, state)
	local config = self.ctx.Config.Movement
	if state.slideUntil > now() then
		return config.SlideSpeed + 5
	end
	if state.sprint then
		return (self.ctx.Services.RoundService:GetRole(player) == "Hunter" and config.HunterSprint or config.RunnerSprint) + 5
	end
	return config.WalkSpeed + 5
end

function MovementService:_correct(player, state, root)
	if state.safeCFrame then
		root.CFrame = state.safeCFrame
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	state.lastPosition = root.Position
	state.lastTime = now()
	state.credit = 2
	state.rejectUntil = now() + 0.35
	state.airStart = nil
	state.groundY = root.Position.Y
	self:_clearMotion(player, state)
	return false
end

-- Called both by Heartbeat and immediately before every tag/range-sensitive intent.
function MovementService:ValidatePosition(player)
	local character, humanoid, root = avatar(player)
	if not character then
		return false
	end
	local state = self:_state(player)
	if state.character ~= character or not state.lastPosition then
		self:ResetPlayer(player)
		return false
	end
	local timestamp = now()
	if timestamp < (state.rejectUntil or 0) then
		return false
	end
	if not finiteVector(root.Position) or not finiteVector(root.AssemblyLinearVelocity) then
		return self:_correct(player, state, root)
	end
	-- A vault has a server-owned, anchored trajectory and a strict expiration.
	if state.vaultUntil > timestamp and root.Anchored then
		state.lastPosition, state.safeCFrame, state.lastTime = root.Position, root.CFrame, timestamp
		return true
	end
	local dt = math.max(timestamp - state.lastTime, 0)
	if dt < 0.015 then
		-- Do not mint extra distance allowance by spamming the Tag remote.
		return (root.Position - state.lastPosition).Magnitude <= 2
	end
	local speed = self:_allowedSpeed(player, state)
	state.credit = math.min(speed * 0.55 + 3, state.credit + speed * math.min(dt, 0.75))
	local difference = root.Position - state.lastPosition
	local traveled = horizontal(difference).Magnitude
	if traveled > state.credit or math.abs(difference.Y) > 110 * math.min(dt, 0.75) + 8 then
		return self:_correct(player, state, root)
	end
	if traveled > 0.25 then
		local wall = Workspace:Raycast(state.lastPosition, difference, rayParameters(character))
		if wall and wall.Instance.Anchored and math.abs(wall.Normal.Y) < 0.65 then
			local model = wall.Instance:FindFirstAncestorOfClass("Model")
			if not model or not model:FindFirstChildOfClass("Humanoid") then
				return self:_correct(player, state, root)
			end
		end
	end
	local bounds = self.ctx.World.Bounds
	if bounds and (root.Position.X < bounds.min.X - 20 or root.Position.X > bounds.max.X + 20
		or root.Position.Z < bounds.min.Z - 20 or root.Position.Z > bounds.max.Z + 20
		or root.Position.Y > bounds.max.Y + 30) then
		-- Lobby can be intentionally outside the arena bounds.
		if self.ctx.Services.RoundService:IsActive(player) then
			return self:_correct(player, state, root)
		end
	end
	local grounded = self:_grounded(character, humanoid, root)
	local climbing = self:_climbing(character, humanoid, root)
	if grounded or climbing then
		state.airStart = nil
		state.groundY = root.Position.Y
	else
		state.airStart = state.airStart or timestamp
		local jumpRise = (self.ctx.Config.Movement.JumpPower ^ 2) / (2 * math.max(Workspace.Gravity, 1)) + 7
		if root.Position.Y - (state.groundY or root.Position.Y) > jumpRise then
			return self:_correct(player, state, root)
		end
		-- Long descents are valid. Hovering beyond a full jump is not.
		if timestamp - state.airStart > 2.4 and root.AssemblyLinearVelocity.Y > -7 then
			return self:_correct(player, state, root)
		end
	end
	state.credit -= traveled
	state.lastPosition, state.lastTime = root.Position, timestamp
	-- Retain a grounded recovery point so a flight correction cannot bless a hover.
	if grounded or climbing then
		state.safeCFrame = root.CFrame
	end
	return true
end

function MovementService:_canMove(player)
	local character, humanoid, root = avatar(player)
	if not character or character:GetAttribute("RoundFrozen") or humanoid.Sit then
		return nil
	end
	if not self:ValidatePosition(player) then
		return nil
	end
	return character, humanoid, root
end

function MovementService:_ack(player, action, cooldown)
	self.ctx.Remotes.Notice:FireClient(player, { kind = "ability", action = action, cooldown = cooldown })
end

function MovementService:_slide(player)
	local character, humanoid, root = self:_canMove(player)
	if not character then
		return
	end
	local state, config = self:_state(player), self.ctx.Config.Movement
	local timestamp = now()
	if timestamp - state.lastSlide < config.SlideCooldown or state.vaultUntil > timestamp or state.slideUntil > timestamp then
		return
	end
	if not self:_grounded(character, humanoid, root) or (not state.sprint and horizontal(root.AssemblyLinearVelocity).Magnitude < 6) then
		return
	end
	local direction = horizontal(root.CFrame.LookVector)
	if direction.Magnitude < 0.1 then
		return
	end
	direction = direction.Unit
	-- Do not propel a player into a wall or launch a slide through thin geometry.
	local wall = Workspace:Raycast(root.Position - Vector3.new(0, 0.8, 0), direction * 3, rayParameters(character))
	if wall and math.abs(wall.Normal.Y) < 0.65 then
		return
	end
	state.lastSlide, state.slideUntil = timestamp, timestamp + config.SlideDuration
	state.slideDirection = direction
	state.credit = math.max(state.credit, config.SlideSpeed * 0.25)
	character:SetAttribute("Sliding", true)
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	self:_ack(player, "Slide", config.SlideCooldown)
end

function MovementService:_clearBox(character, cframe, size)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	for _, part in ipairs(Workspace:GetPartBoundsInBox(cframe, size, params)) do
		if part.CanCollide then
			return false
		end
	end
	return true
end

function MovementService:_vault(player)
	local character, humanoid, root = self:_canMove(player)
	if not character then
		return
	end
	local state, config = self:_state(player), self.ctx.Config.Movement
	local timestamp = now()
	if timestamp - state.lastVault < config.VaultCooldown or state.slideUntil > timestamp or state.vaultUntil > timestamp then
		return
	end
	-- Accept the beginning of a normal jump too: Space intentionally preserves Jump.
	local grounded = self:_grounded(character, humanoid, root)
	if not grounded and (not state.airStart or timestamp - state.airStart > 0.22) then
		return
	end
	local direction = horizontal(root.CFrame.LookVector)
	if direction.Magnitude < 0.1 then
		return
	end
	direction = direction.Unit
	local params = rayParameters(character)
	local front = Workspace:Raycast(root.Position - Vector3.new(0, 1, 0), direction * config.VaultDistance, params)
	if not front or not front.Instance.Anchored or math.abs(front.Normal.Y) > 0.45 then
		return
	end
	local groundOffset = humanoid.HipHeight + root.Size.Y * 0.5
	local topOrigin = front.Position + direction * 0.7 + Vector3.new(0, config.VaultHeight + 1, 0)
	local top = Workspace:Raycast(topOrigin, Vector3.new(0, -config.VaultHeight - 2, 0), params)
	if not top or top.Normal.Y < 0.7 then
		return
	end
	local height = top.Position.Y - (root.Position.Y - groundOffset)
	if height < 0.5 or height > config.VaultHeight then
		return
	end
	local beyond = front.Position + direction * 3.2
	local landing = Workspace:Raycast(Vector3.new(beyond.X, top.Position.Y + 2, beyond.Z), Vector3.new(0, -9, 0), params)
	if not landing or landing.Normal.Y < 0.65 then
		return
	end
	local destination = Vector3.new(beyond.X, landing.Position.Y + groundOffset + 0.15, beyond.Z)
	if horizontal(destination - root.Position).Magnitude > config.VaultDistance + 3.5 then
		return
	end
	local elevatedY = math.max(root.Position.Y, destination.Y, top.Position.Y + groundOffset + 0.4)
	local elevatedStart = Vector3.new(root.Position.X, elevatedY, root.Position.Z)
	local elevatedEnd = Vector3.new(destination.X, elevatedY, destination.Z)
	local boxSize = Vector3.new(2.1, math.max(3, groundOffset * 2 - 0.5), 2.1)
	local facing = CFrame.lookAt(Vector3.zero, direction)
	local endCF = CFrame.new(destination) * facing
	if not self:_clearBox(character, endCF, boxSize)
		or not self:_clearBox(character, CFrame.new(elevatedStart) * facing, boxSize)
		or not self:_clearBox(character, CFrame.new(elevatedEnd) * facing, boxSize) then
		return
	end
	local elevatedStartCF = CFrame.new(elevatedStart) * facing
	local pathHit = Workspace:Blockcast(elevatedStartCF, boxSize, elevatedEnd - elevatedStart, params)
	local lift = elevatedStart - root.Position
	local ceiling = lift.Magnitude > 0.05 and Workspace:Blockcast(root.CFrame, boxSize, lift, params)
	if pathHit or ceiling then
		return
	end
	state.lastVault = timestamp
	state.vaultUntil = timestamp + 0.48
	state.modeId += 1
	local modeId = state.modeId
	character:SetAttribute("Vaulting", true)
	root.Anchored = true
	root.AssemblyLinearVelocity = Vector3.zero
	local startPosition = root.Position
	self:_ack(player, "Vault", config.VaultCooldown)
	task.spawn(function()
		local duration = 0.4
		while now() - timestamp < duration do
			if player.Character ~= character or self.states[player] ~= state or state.modeId ~= modeId or humanoid.Health <= 0 then
				break
			end
			local alpha = math.clamp((now() - timestamp) / duration, 0, 1)
			local position
			if alpha < 0.28 then
				position = startPosition:Lerp(elevatedStart, alpha / 0.28)
			elseif alpha < 0.76 then
				position = elevatedStart:Lerp(elevatedEnd, (alpha - 0.28) / 0.48)
			else
				position = elevatedEnd:Lerp(destination, (alpha - 0.76) / 0.24)
			end
			root.CFrame = CFrame.new(position) * facing
			RunService.Heartbeat:Wait()
		end
		if self.states[player] == state and state.modeId == modeId and player.Character == character then
			if humanoid.Health > 0 then
				root.CFrame = endCF
			end
			root.Anchored = character:GetAttribute("RoundFrozen") == true
			root.AssemblyLinearVelocity = Vector3.zero
			state.vaultUntil = 0
			state.lastPosition, state.safeCFrame, state.lastTime = root.Position, root.CFrame, now()
			state.groundY, state.airStart = root.Position.Y, nil
			state.credit = config.WalkSpeed * 0.4 + 3
			character:SetAttribute("Vaulting", false)
			if not root.Anchored then
				pcall(function()
					root:SetNetworkOwnershipAuto()
				end)
			end
		end
	end)
end

function MovementService:Handle(player, action, payload)
	if action == "Sprint" then
		if type(payload) ~= "table" or type(payload.active) ~= "boolean" then
			return
		end
		local state = self:_state(player)
		if not payload.active then
			state.sprint = false
			if player.Character then
				player.Character:SetAttribute("Sprinting", false)
			end
			return
		end
		local character = self:_canMove(player)
		if character then
			state.sprint = true
			character:SetAttribute("Sprinting", true)
		end
	elseif action == "Slide" then
		self:_slide(player)
	elseif action == "Vault" then
		self:_vault(player)
	end
end

function MovementService:_step(player, dt)
	local character, humanoid, root = avatar(player)
	if not character then
		return
	end
	local state = self:_state(player)
	if state.character ~= character then
		self:ResetPlayer(player)
	end
	local config, timestamp = self.ctx.Config.Movement, now()
	local frozen = character:GetAttribute("RoundFrozen") == true
	if frozen then
		root.Anchored = true
		humanoid.WalkSpeed, humanoid.JumpPower = 0, 0
		state.lastPosition, state.lastTime = root.Position, timestamp
		return
	end
	if not self:ValidatePosition(player) then
		return
	end
	local targetSpeed = state.sprint and (self.ctx.Services.RoundService:GetRole(player) == "Hunter" and config.HunterSprint or config.RunnerSprint) or config.WalkSpeed
	humanoid.WalkSpeed += (targetSpeed - humanoid.WalkSpeed) * math.min(1, config.Acceleration * dt)
	humanoid.JumpPower = config.JumpPower
	if state.slideUntil > timestamp then
		local direction = state.slideDirection
		local distance = config.SlideSpeed * dt + 1.7
		local wall = Workspace:Raycast(root.Position - Vector3.new(0, 0.8, 0), direction * distance, rayParameters(character))
		if wall and math.abs(wall.Normal.Y) < 0.65 then
			state.slideUntil = 0
		else
			local progress = math.clamp((timestamp - state.lastSlide) / config.SlideDuration, 0, 1)
			local slideSpeed = config.SlideSpeed * (1 - 0.28 * progress)
			root.AssemblyLinearVelocity = direction * slideSpeed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
	end
	if character:GetAttribute("Sliding") and state.slideUntil <= timestamp then
		character:SetAttribute("Sliding", false)
		local velocity = horizontal(root.AssemblyLinearVelocity)
		if velocity.Magnitude > targetSpeed then
			root.AssemblyLinearVelocity = velocity.Unit * targetSpeed + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
		end
		if not root.Anchored then
			pcall(function()
				root:SetNetworkOwnershipAuto()
			end)
		end
	end
	-- A fallen avatar is eliminated through the same death path as a reset.
	local bounds = self.ctx.World.Bounds
	if bounds and root.Position.Y < bounds.min.Y - 35 then
		humanoid.Health = 0
	end
end

function MovementService:Start()
	if self.started then
		return
	end
	self.started = true
	Players.PlayerRemoving:Connect(function(player)
		local state = self.states[player]
		if state then
			self:_clearMotion(player, state)
		end
		self.states[player] = nil
	end)
	RunService.Heartbeat:Connect(function(dt)
		self.accumulator += dt
		if self.accumulator < 0.08 then
			return
		end
		local elapsed = self.accumulator
		self.accumulator = 0
		for _, player in ipairs(Players:GetPlayers()) do
			local ok, err = xpcall(function()
				self:_step(player, math.min(elapsed, 0.25))
			end, debug.traceback)
			if not ok then
				warn("[Catch] Movement update failed: " .. tostring(err))
			end
		end
	end)
end

return MovementService
