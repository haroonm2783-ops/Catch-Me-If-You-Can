-- Server-owned roster, timers, tags, respawns, and progression summaries.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RoundService = {}
RoundService.__index = RoundService

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

function RoundService.new(ctx)
	return setmetatable({
		ctx = ctx,
		phase = "Waiting",
		endsAt = 0,
		roundId = 0,
		practice = false,
		roster = {},
		winners = {},
		resultText = "Waiting for players",
		tagTimes = {},
		loading = {},
		connections = {},
		characterConnections = {},
		departing = {},
		hunterTurns = {},
		random = Random.new(),
		startedAt = 0,
		lastBroadcast = 0,
		modifier = ctx.Modifiers.Default,
		lastModifierId = nil,
	}, RoundService)
end

function RoundService:_playingPhase()
	return self.phase == "HeadStart" or self.phase == "Active"
end

-- Slide/vault cooldown multiplier for the running round (Slide Frenzy halves it).
function RoundService:CooldownScale()
	if self:_playingPhase() then
		return self.modifier.cooldownScale or 1
	end
	return 1
end

function RoundService:_pickModifier(playerCount)
	local roll = function(maximum)
		return self.random:NextInteger(1, maximum)
	end
	self.modifier = self.ctx.Modifiers.Pick(playerCount, self.lastModifierId, playerCount < 2, roll)
end

function RoundService:GetRole(player)
	local entry = self.roster[player.UserId]
	if self:_playingPhase() then
		if entry and entry.alive then
			return entry.role
		end
		return "Spectator"
	end
	return "Lobby"
end

function RoundService:IsActive(player)
	local entry = self.roster[player.UserId]
	return self:_playingPhase() and entry ~= nil and entry.alive and not self.departing[player]
end

function RoundService:_counts()
	local runners, hunters = 0, 0
	for _, entry in pairs(self.roster) do
		if entry.alive and entry.player.Parent == Players and not self.departing[entry.player] then
			if entry.role == "Runner" then
				runners += 1
			else
				hunters += 1
			end
		end
	end
	return runners, hunters
end

function RoundService:Snapshot()
	local runners = self:_counts()
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if not self.departing[player] then
			local entry = self.roster[player.UserId]
			table.insert(list, {
				userId = player.UserId,
				name = player.Name,
				displayName = player.DisplayName,
				role = self:GetRole(player),
				alive = entry ~= nil and entry.alive and self:_playingPhase(),
			})
		end
	end
	table.sort(list, function(a, b)
		return a.userId < b.userId
	end)
	return {
		phase = self.phase,
		endsAt = self.endsAt,
		roundId = self.roundId,
		practice = self.practice,
		finalChase = self.phase == "Active" and self.endsAt - now() <= self.ctx.Config.Round.FinalSeconds,
		lastRunner = self:_playingPhase() and runners == 1 and not self.practice,
		aliveRunners = runners,
		players = list,
		winners = table.clone(self.winners),
		resultText = self.resultText,
		modifier = self.ctx.Modifiers.Public(self.modifier),
		mapName = "NEON MALL",
		queued = self:_queuedCount(),
	}
end

function RoundService:_broadcast()
	self.lastBroadcast = now()
	self.ctx.Remotes.State:FireAllClients(self:Snapshot())
end

function RoundService:_notice(player, payload)
	if player.Parent == Players and not self.departing[player] then
		self.ctx.Remotes.Notice:FireClient(player, payload)
	end
end

function RoundService:_setCharacterRole(player, character)
	local role = self:GetRole(player)
	player:SetAttribute("RoundRole", role)
	character:SetAttribute("RoundRole", role)
	local entry = self.roster[player.UserId]
	local held = (self.phase == "HeadStart" and role == "Hunter")
		or (entry ~= nil and entry.frozenUntil ~= nil and entry.frozenUntil > now())
	character:SetAttribute("RoundFrozen", held)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = held
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	if humanoid then
		humanoid.AutoRotate = not held
		humanoid.UseJumpPower = true
		humanoid.JumpPower = held and 0 or self.ctx.Config.Movement.JumpPower
		humanoid.WalkSpeed = held and 0 or self.ctx.Config.Movement.WalkSpeed
	end
	local movement = self.ctx.Services.MovementService
	if movement then
		movement:ResetPlayer(player)
	end
end

function RoundService:_destination(player)
	local entry = self.roster[player.UserId]
	if self:IsActive(player) and entry then
		return entry.spawn
	end
	-- Keep a dozen avatars from sharing one exact collision point.
	local offset = (math.abs(player.UserId) % 9) - 4
	return self.ctx.World.LobbySpawn * CFrame.new(offset * 2.5, 0, 0)
end

function RoundService:_place(player, character)
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	character:PivotTo(self:_destination(player))
	self:_setCharacterRole(player, character)
	local forceField = character:FindFirstChildOfClass("ForceField")
	if forceField then
		forceField:Destroy()
	end
end

function RoundService:_load(player)
	if self.loading[player] or player.Parent ~= Players or self.departing[player] then
		return
	end
	self.loading[player] = true
	task.spawn(function()
		local ok, err = pcall(function()
			player:LoadCharacterAsync()
		end)
		self.loading[player] = nil
		if not ok and player.Parent == Players then
			warn("[Catch] Character load failed for user " .. player.UserId .. ": " .. tostring(err))
			self:_notice(player, { kind = "toast", text = "Avatar is still loading. Retrying shortly." })
			task.delay(3, function()
				if player.Parent == Players and not liveCharacter(player) then
					self:_load(player)
				end
			end)
		end
	end)
end

function RoundService:_onCharacter(player, character)
	local previous = self.characterConnections[player]
	if previous then
		previous:Disconnect()
		self.characterConnections[player] = nil
	end
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not humanoid or not root or player.Character ~= character or player.Parent ~= Players then
			return
		end
		self:_place(player, character)
		self.characterConnections[player] = humanoid.Died:Connect(function()
			if player.Character ~= character then
				return
			end
			self:_eliminate(player, "reset")
			task.delay(self.ctx.Config.Round.RespawnDelay, function()
				if player.Parent == Players and player.Character == character then
					self:_load(player)
				end
			end)
		end)
	end)
end

function RoundService:_onPlayer(player)
	self.departing[player] = nil
	local connection = player.CharacterAdded:Connect(function(character)
		self:_onCharacter(player, character)
	end)
	self.connections[player] = connection
	if player.Character then
		self:_onCharacter(player, player.Character)
	else
		self:_load(player)
	end
	player:SetAttribute("RoundRole", self:GetRole(player))
	self:_broadcast()
end

-- The Plaza hub is a safe social area: only players who pressed PLAY join rounds.
function RoundService:IsQueued(player)
	return not self.ctx.Config.Round.RequireQueue or player:GetAttribute("CatchQueued") == true
end

function RoundService:Queue(player, on)
	if player.Parent ~= Players or self.departing[player] then return false end
	if self.roster[player.UserId] and self:_playingPhase() and not on then return false end
	if (player:GetAttribute("CatchQueued") == true) == (on == true) then return true end
	player:SetAttribute("CatchQueued", on == true)
	self:_notice(player, { kind = "toast", text = on and "You're in the queue. The next chase starts automatically." or "You left the queue. Enjoy the Plaza!" })
	self:_broadcast()
	return true
end

function RoundService:_queuedCount()
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		if not self.departing[player] and self:IsQueued(player) then count += 1 end
	end
	return count
end

function RoundService:_eligible()
	local eligible = {}
	local data = self.ctx.Services.DataService
	for _, player in ipairs(Players:GetPlayers()) do
		if not self.departing[player] and data:Ready(player) and liveCharacter(player) and self:IsQueued(player) then
			table.insert(eligible, player)
		end
	end
	-- Late players still enter a full next round, with a hard cap matching place settings.
	table.sort(eligible, function(a, b)
		return a.UserId < b.UserId
	end)
	while #eligible > self.ctx.Config.Round.MaxPlayers do
		table.remove(eligible)
	end
	return eligible
end

function RoundService:_hasEnough(eligible)
	return #eligible >= self.ctx.Config.Round.MinimumPlayers
		or (#eligible == 1 and RunService:IsStudio() and self.ctx.Config.Round.StudioSolo)
end

function RoundService:_startRound(eligible)
	self.roundId += 1
	self.roster = {}
	self.tagTimes = {}
	self.winners = {}
	self.practice = #eligible == 1
	-- Player counts can change during intermission; never keep a modifier the lobby no longer supports.
	if self.practice or #eligible < self.modifier.minPlayers then
		self:_pickModifier(#eligible)
	end
	self.lastModifierId = self.modifier.id
	self.startedAt = now()
	self.phase = "HeadStart"
	self.endsAt = now() + self.ctx.Config.Round.HeadStart
	self.resultText = self.practice and "STUDIO PRACTICE · no rewards"
		or (self.modifier.id == "classic" and "Runners, find your route!" or (self.modifier.name .. " · " .. self.modifier.tagline))
	local cosmetic = self.ctx.Services.CosmeticService
	if cosmetic then
		cosmetic:ShowWinners({})
	end
	-- Shuffle ties, then prefer players who have spent fewer rounds hunting.
	for index = #eligible, 2, -1 do
		local swap = self.random:NextInteger(1, index)
		eligible[index], eligible[swap] = eligible[swap], eligible[index]
	end
	local tieBreak = {}
	for index, player in ipairs(eligible) do
		tieBreak[player] = index
	end
	table.sort(eligible, function(a, b)
		local aTurns, bTurns = self.hunterTurns[a.UserId] or 0, self.hunterTurns[b.UserId] or 0
		if aTurns == bTurns then
			return tieBreak[a] < tieBreak[b]
		end
		return aTurns < bTurns
	end)
	local hunters = self.practice and 0
		or self.ctx.Modifiers.HunterCount(self.modifier, #eligible, self.ctx.Rules.HunterCount(#eligible))
	local runnerIndex, hunterIndex = 0, 0
	for index, player in ipairs(eligible) do
		local role = index <= hunters and "Hunter" or "Runner"
		local spawns, spawnIndex
		if role == "Hunter" then
			hunterIndex += 1
			spawns, spawnIndex = self.ctx.World.HunterSpawns, hunterIndex
			self.hunterTurns[player.UserId] = (self.hunterTurns[player.UserId] or 0) + 1
		else
			runnerIndex += 1
			spawns, spawnIndex = self.ctx.World.RunnerSpawns, runnerIndex
		end
		local spawn = spawns[((spawnIndex - 1) % #spawns) + 1]
		self.roster[player.UserId] = {
			player = player,
			role = role,
			alive = true,
			tags = 0,
			joinedAt = self.startedAt,
			spawn = spawn,
		}
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			self:_place(player, player.Character)
		end
	end
	self:_broadcast()
	self.ctx.Remotes.Notice:FireAllClients({ kind = "round", text = self.resultText })
end

function RoundService:_activate()
	self.phase = "Active"
	self.startedAt = now()
	self.endsAt = self.startedAt + self.modifier.duration
	self.resultText = self.practice and "Explore NEON HEIGHTS · practice awards no XP or coins" or (self.modifier.id == "classic" and "The chase is on!" or (self.modifier.name .. " · " .. self.modifier.tagline))
	for _, entry in pairs(self.roster) do
		entry.joinedAt = self.startedAt
		if entry.alive and entry.role == "Hunter" and entry.player.Character then
			-- Only held hunters need releasing. Resetting a running player's movement
			-- here would bless an unvalidated position and interrupt an in-flight vault.
			self:_setCharacterRole(entry.player, entry.player.Character)
		end
	end
	self:_broadcast()
	self.ctx.Remotes.Notice:FireAllClients({ kind = "round", text = self.resultText })
end

function RoundService:_endRound(winningRole, reason)
	if not self:_playingPhase() then
		return
	end
	local endedAt = now()
	self.phase = "Results" -- Guard reentry before touching avatars or awarding data.
	self.endsAt = endedAt + self.ctx.Config.Round.ResultsDuration
	self.winners = {}
	self.resultText = self.practice and (reason or "Practice complete · no progression awarded")
		or (reason or (winningRole == "Hunter" and "Hunters caught every runner!" or "Runners escaped!"))
	local winningPlayers = {}
	for _, entry in pairs(self.roster) do
		local player = entry.player
		local connected = player.Parent == Players and not self.departing[player]
		-- Eliminated runners do not receive a survival victory when a teammate escapes.
		local won = not self.practice and entry.role == winningRole and (entry.role == "Hunter" or entry.alive)
		if connected and won then
			table.insert(self.winners, player.UserId)
			table.insert(winningPlayers, player)
		end
		if connected then
			-- Infected hunters keep the time they survived as runners.
			local survived = (entry.role == "Runner" or entry.infected == true)
				and math.clamp((entry.eliminatedAt or endedAt) - self.startedAt, 0, self.modifier.duration)
				or 0
			local summary = {
				role = entry.role,
				win = won,
				tags = entry.tags,
				survived = survived,
				practice = self.practice,
				roundId = self.roundId,
			}
			task.spawn(function()
				local ok, err = pcall(function()
					self.ctx.Services.DataService:AwardRound(player, summary)
				end)
				if not ok then
					warn("[Catch] Round award failed: " .. tostring(err))
				end
			end)
		end
	end
	table.sort(self.winners)
	for _, player in ipairs(Players:GetPlayers()) do
		if not self.departing[player] then
			local character = liveCharacter(player)
			if character then
				self:_place(player, character)
			else
				self:_load(player)
			end
		end
	end
	local cosmetic = self.ctx.Services.CosmeticService
	if cosmetic then
		cosmetic:ShowWinners(winningPlayers)
	end
	self:_broadcast()
	self.ctx.Remotes.Notice:FireAllClients({ kind = "round", text = self.resultText })
end

function RoundService:_checkWin()
	if not self:_playingPhase() then
		return
	end
	local runners, hunters = self:_counts()
	if self.phase == "Active" and now() >= self.endsAt then
		self:_endRound("Runner", self.practice and "Practice complete · no XP or coins awarded" or "Time is up · runners escaped!")
	elseif runners == 0 then
		self:_endRound("Hunter", self.practice and "Practice ended · try another route next round" or "Hunters caught every runner!")
	elseif not self.practice and hunters == 0 then
		self:_endRound("Runner", "Runners win · no hunters remain")
	end
end

function RoundService:_eliminate(player, reason)
	-- Timer ticks are deliberately infrequent. A death/reset event arriving after
	-- the deadline must settle the completed chase before it changes the roster.
	if self.phase == "Active" and now() >= self.endsAt then
		self:_checkWin()
		return
	end
	local entry = self.roster[player.UserId]
	if not self:_playingPhase() or not entry or not entry.alive then
		return
	end
	entry.alive = false
	entry.eliminatedAt = now()
	player:SetAttribute("RoundRole", "Spectator")
	if player.Character then
		self:_setCharacterRole(player, player.Character)
	end
	if reason ~= "left" then
		self:_notice(player, {
			kind = "toast",
			text = reason == "tag" and "Caught! Watch the chase, then run again next round."
				or "Round ended for you. You will return to the lobby.",
		})
	end
	self:_checkWin()
	if self:_playingPhase() then
		self:_broadcast()
	end
end

function RoundService:TryTag(player)
	-- Resolve the deadline synchronously; a late remote must not steal a win in
	-- the interval between the visible timer reaching zero and the next tick.
	if self.phase == "Active" and now() >= self.endsAt then
		self:_checkWin()
		return false
	end
	if self.phase ~= "Active" or self:GetRole(player) ~= "Hunter" or not self:IsActive(player) then
		return false
	end
	local character, _, root = liveCharacter(player)
	if not character or character:GetAttribute("Vaulting") or character:GetAttribute("RoundFrozen") then
		return false
	end
	local movement = self.ctx.Services.MovementService
	if movement and not movement:ValidatePosition(player) then
		return false
	end
	local timestamp = now()
	local cooldown = self.ctx.Config.Movement.TagCooldown
	if timestamp - (self.tagTimes[player] or -math.huge) < cooldown then
		return false
	end
	self.tagTimes[player] = timestamp
	self:_notice(player, { kind = "ability", action = "Tag", cooldown = cooldown })
	local closest, closestDistance
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	rayParams.RespectCanCollide = true
	for _, entry in pairs(self.roster) do
		if entry.role == "Runner" and entry.alive and not self.departing[entry.player] then
			local targetCharacter, _, targetRoot = liveCharacter(entry.player)
			if targetCharacter and (not movement or movement:ValidatePosition(entry.player)) then
				local delta = targetRoot.Position - root.Position
				local distance = delta.Magnitude
				if distance <= self.ctx.Config.Movement.TagRange and (not closestDistance or distance < closestDistance) then
					local hit = Workspace:Raycast(root.Position, delta, rayParams)
					if not hit or hit.Instance:IsDescendantOf(targetCharacter) then
						closest = entry
						closestDistance = distance
					end
				end
			end
		end
	end
	if not closest then
		return false
	end
	local hunter = self.roster[player.UserId]
	hunter.tags += 1
	local target = closest.player
	local targetCharacter, _, targetRoot = liveCharacter(target)
	local cosmetic = self.ctx.Services.CosmeticService
	if cosmetic and cosmetic.TagEffect then
		cosmetic:TagEffect(player, target)
	elseif targetRoot then
		self.ctx.Remotes.Notice:FireAllClients({ kind = "tag", position = targetRoot.Position, userId = player.UserId, victimUserId = target.UserId })
	end
	local modifier = self.modifier
	if modifier.infection and closest.alive and self.endsAt - now() > (modifier.infectCutoff or 0) then
		self:_infect(closest)
		return true
	end
	self:_eliminate(target, "tag")
	-- A tagged avatar immediately leaves the arena; no invisible blockers or second tags.
	if targetCharacter and target.Character == targetCharacter then
		self:_place(target, targetCharacter)
	end
	return true
end

-- Infection: a tagged runner joins the hunters at a hunter spawn after a short, server-held pause.
function RoundService:_infect(entry)
	local player = entry.player
	local hunterSpawns = self.ctx.World.HunterSpawns
	self.infections = (self.infections or 0) + 1
	entry.role = "Hunter"
	entry.infected = true
	entry.eliminatedAt = now()
	entry.spawn = hunterSpawns[((self.infections - 1) % #hunterSpawns) + 1]
	local delay = self.modifier.infectDelay or 3
	entry.frozenUntil = now() + delay
	self:_notice(player, {
		kind = "toast",
		text = "Infected! You are a hunter now. Tag the remaining runners.",
	})
	local character = player.Character
	if character then
		self:_place(player, character)
	end
	local roundId = self.roundId
	task.delay(delay, function()
		if self.roundId ~= roundId or not self:_playingPhase() or not entry.alive then
			return
		end
		entry.frozenUntil = nil
		local current = player.Character
		if player.Parent == Players and current and current:GetAttribute("RoundFrozen") then
			self:_setCharacterRole(player, current)
		end
	end)
	self:_checkWin()
	if self:_playingPhase() then
		self:_broadcast()
	end
end

function RoundService:_step()
	if self.phase == "Waiting" then
		local eligible = self:_eligible()
		if self:_hasEnough(eligible) then
			self.phase = "Intermission"
			self.endsAt = now() + self.ctx.Config.Round.Intermission
			self.practice = #eligible == 1
			self:_pickModifier(#eligible)
			self.resultText = self.practice and "Studio solo practice starts soon · no rewards" or "Next chase starts soon"
			self:_broadcast()
		end
	elseif self.phase == "Intermission" then
		local eligible = self:_eligible()
		if not self:_hasEnough(eligible) then
			self.phase, self.endsAt = "Waiting", 0
			self.practice = false
			self.modifier = self.ctx.Modifiers.Default
			self.resultText = "Waiting for at least two ready players"
			self:_broadcast()
		elseif now() >= self.endsAt then
			self:_startRound(eligible)
		end
	elseif self.phase == "HeadStart" then
		self:_checkWin()
		if self.phase == "HeadStart" and now() >= self.endsAt then
			self:_activate()
		end
	elseif self.phase == "Active" then
		self:_checkWin()
	elseif self.phase == "Results" and now() >= self.endsAt then
		self.phase, self.endsAt = "Waiting", 0
		self.roster, self.winners = {}, {}
		self.practice = false
		self.resultText = "Waiting for players"
		local cosmetic = self.ctx.Services.CosmeticService
		if cosmetic then
			cosmetic:ShowWinners({})
		end
		self:_broadcast()
	end
	if now() - self.lastBroadcast >= 1 then
		self:_broadcast()
	end
end

function RoundService:Start()
	if self.started then
		return
	end
	self.started = true
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(function(player)
		self:_onPlayer(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self.departing[player] = true
		self:_eliminate(player, "left")
		self.tagTimes[player], self.loading[player], self.hunterTurns[player.UserId] = nil, nil, nil
		if self.connections[player] then
			self.connections[player]:Disconnect()
			self.connections[player] = nil
		end
		if self.characterConnections[player] then
			self.characterConnections[player]:Disconnect()
			self.characterConnections[player] = nil
		end
		self:_broadcast()
		-- Keep the departure marker only while a removed player's callbacks can still run.
		task.delay(10, function()
			self.departing[player] = nil
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		self:_onPlayer(player)
	end
	task.spawn(function()
		while self.started do
			local ok, err = xpcall(function()
				self:_step()
			end, debug.traceback)
			if not ok then
				warn("[Catch] Round step failed: " .. tostring(err))
			end
			task.wait(0.2)
		end
	end)
end

return RoundService
