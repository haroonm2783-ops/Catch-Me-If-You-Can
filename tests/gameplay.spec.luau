-- Execute the production round/movement modules with deterministic Roblox boundaries.
-- This validates state transitions and authority checks, not live Roblox physics.
-- Run: .tooling/bin/lune run tests/gameplay.spec.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Rules = require("../src/shared/Rules")
local Vector3, CFrame, Enum = roblox.Vector3, roblox.CFrame, roblox.Enum
local checks = 0

local function expect(condition, message)
	checks += 1
	assert(condition, message)
end

local function signal()
	local handlers = {}
	return {
		Connect = function(_, fn)
			local connection = { fn = fn, connected = true }
			table.insert(handlers, connection)
			return { Disconnect = function() connection.connected = false end }
		end,
		Fire = function(_, ...)
			for _, connection in ipairs(table.clone(handlers)) do
				if connection.connected then connection.fn(...) end
			end
		end,
		Wait = function() return coroutine.yield(1 / 60) end,
	}
end

local function object(className)
	local value = { ClassName = className, attributes = {}, children = {} }
	function value:FindFirstChild(name) return self.children[name] end
	function value:WaitForChild(name) return self.children[name] end
	function value:FindFirstChildOfClass(name)
		for _, child in pairs(self.children) do if child.ClassName == name then return child end end
	end
	function value:FindFirstAncestorOfClass() return nil end
	function value:IsA(name) return self.ClassName == name end
	function value:IsDescendantOf(parent) return self.Parent == parent end
	function value:SetAttribute(name, attribute) self.attributes[name] = attribute end
	function value:GetAttribute(name) return self.attributes[name] end
	function value:SetNetworkOwner() self.owner = "server" end
	function value:SetNetworkOwnershipAuto() self.owner = "auto" end
	function value:Destroy() self.destroyed = true end
	if className == "Part" then
		value.CFrame = CFrame.new()
		value.Size = Vector3.new(2, 2, 1)
		value.AssemblyLinearVelocity = Vector3.zero
		value.AssemblyAngularVelocity = Vector3.zero
		value.Anchored = false
		value.CanCollide = true
		setmetatable(value, { __index = function(self, key) if key == "Position" then return self.CFrame.Position end end })
	end
	return value
end

local function fixture(playerCount, studio)
	local timestamp, scheduled, roster, notices, snapshots, awards = 100, {}, {}, {}, {}, {}
	local players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return table.clone(roster) end }
	local ground = object("Part")
	ground.Anchored = true
	local world = { Gravity = 196.2, GetServerTimeNow = function() return timestamp end }
	function world:Raycast(origin, delta, parameters)
		if self.raycast then return self.raycast(origin, delta, parameters) end
		if delta.Y < 0 and delta.X == 0 and delta.Z == 0 and origin.Y >= 0 and origin.Y + delta.Y <= 0 then
			return { Position = Vector3.new(origin.X, 0, origin.Z), Normal = Vector3.yAxis, Instance = ground }
		end
		return nil
	end
	function world:GetPartBoundsInBox(cframe, size, parameters)
		return self.overlap and self.overlap(cframe, size, parameters) or {}
	end
	function world:Blockcast(cframe, size, delta, parameters)
		return self.blockcast and self.blockcast(cframe, size, delta, parameters) or nil
	end
	local run = { IsStudio = function() return studio == true end, Heartbeat = signal() }
	local services = { Players = players, Workspace = world, RunService = run }
	local function schedule(fn, delay)
		table.insert(scheduled, { thread = coroutine.create(fn), wake = timestamp + (delay or 0) })
	end
	local environment = {
		game = { GetService = function(_, name) return assert(services[name], name) end },
		Vector3 = Vector3, CFrame = CFrame, Enum = Enum,
		Random = { new = function() return { NextInteger = function(_, _, high) return high end } end },
		RaycastParams = { new = function() return {} end },
		OverlapParams = { new = function() return {} end },
		task = {
			spawn = function(fn) schedule(fn) end,
			delay = function(delay, fn) schedule(fn, delay) end,
			wait = function(delay) return coroutine.yield(delay or 1 / 60) end,
		},
	}
	local ctx = {
		Config = {
			Round = { MaxPlayers = 12, MinimumPlayers = 2, Duration = 180, Intermission = 16, ResultsDuration = 10, HeadStart = 5, FinalSeconds = 30, RespawnDelay = 2, StudioSolo = true },
			Movement = { WalkSpeed = 17, RunnerSprint = 26, HunterSprint = 27, Acceleration = 7, JumpPower = 48, SlideSpeed = 35, SlideDuration = 0.65, SlideCooldown = 3, VaultCooldown = 1.1, VaultDistance = 5, VaultHeight = 4.5, TagRange = 5.8, TagCooldown = 0.65 },
		},
		Rules = Rules, Services = {},
		World = { LobbySpawn = CFrame.new(0, 3, 250), RunnerSpawns = { CFrame.new(20, 3, 0) }, HunterSpawns = { CFrame.new(0, 3, 0) }, Bounds = { min = Vector3.new(-155, -25, -140), max = Vector3.new(155, 100, 145) } },
		Remotes = {
			State = { FireAllClients = function(_, state) table.insert(snapshots, state) end },
			Notice = {
				FireClient = function(_, player, notice) table.insert(notices, { player = player, notice = notice }) end,
				FireAllClients = function(_, notice) table.insert(notices, { notice = notice }) end,
			},
		},
	}
	ctx.Services.DataService = {
		Ready = function(_, player) return player.ready ~= false end,
		AwardRound = function(_, player, summary) table.insert(awards, { player = player, summary = summary }) end,
	}
	ctx.Services.CosmeticService = { ShowWinners = function() end }
	local Round = luau.load(fs.readFile("src/server/Services/RoundService.lua"), { environment = environment, debugName = "RoundService" })()
	local Movement = luau.load(fs.readFile("src/server/Services/MovementService.lua"), { environment = environment, debugName = "MovementService" })()
	local round, movement = Round.new(ctx), Movement.new(ctx)
	ctx.Services.RoundService, ctx.Services.MovementService = round, movement
	local f = { ctx = ctx, round = round, movement = movement, players = roster, playersService = players, world = world, ground = ground, notices = notices, snapshots = snapshots, awards = awards }
	function f:advance(seconds)
		local target, executions = timestamp + seconds, 0
		while true do
			local nextIndex, nextWake
			for index, job in ipairs(scheduled) do
				if job.wake <= target and (not nextWake or job.wake < nextWake) then nextIndex, nextWake = index, job.wake end
			end
			if not nextIndex then break end
			local job = table.remove(scheduled, nextIndex)
			timestamp = math.max(timestamp, job.wake)
			local success, delay = coroutine.resume(job.thread)
			assert(success, tostring(delay))
			if coroutine.status(job.thread) ~= "dead" then
				job.wake = timestamp + math.max(delay or 0, 0.00001)
				table.insert(scheduled, job)
			end
			executions += 1
			assert(executions < 100000, "Test scheduler runaway")
		end
		timestamp = target
	end
	function f:time() return timestamp end
	function f:addPlayer(id)
		local player, character, humanoid, root = object("Player"), object("Model"), object("Humanoid"), object("Part")
		player.UserId, player.Name, player.DisplayName, player.Parent = id, "Player" .. id, "Player " .. id, players
		player.CharacterAdded = signal()
		humanoid.Health, humanoid.HipHeight, humanoid.WalkSpeed, humanoid.JumpPower = 100, 2, 17, 48
		humanoid.Died, humanoid.state = signal(), Enum.HumanoidStateType.Running
		function humanoid:GetState() return self.state end
		root.CFrame = CFrame.new(0, 3, 0)
		root.Parent, humanoid.Parent = character, character
		character.children.Humanoid, character.children.HumanoidRootPart = humanoid, root
		character.Parent, player.Character = world, character
		function character:PivotTo(cframe) root.CFrame = cframe end
		function player:LoadCharacterAsync() self.loadCalls = (self.loadCalls or 0) + 1 end
		table.insert(roster, player)
		movement:ResetPlayer(player)
		return player, humanoid, root
	end
	function f:remove(player)
		players.PlayerRemoving:Fire(player)
		player.Parent = nil
		for index, member in ipairs(roster) do if member == player then table.remove(roster, index); break end end
	end
	function f:pose(player, x, y, z, trusted)
		local root = player.Character:FindFirstChild("HumanoidRootPart")
		root.CFrame = CFrame.new(x, y, z)
		if trusted then movement:ResetPlayer(player) end
		return root
	end
	function f:startActive()
		round:_startRound(round:_eligible())
		self:advance(ctx.Config.Round.HeadStart)
		round:_activate()
	end
	for id = 1, playerCount do f:addPlayer(id) end
	return f
end

-- Eligibility, two-team allocation, head start, late joining, and the exact clock.
do
	local f = fixture(12)
	f.round:_step()
	expect(f.round.phase == "Intermission", "Ready lobby should begin intermission")
	f:advance(16)
	f.round:_step()
	local runners, hunters = f.round:_counts()
	expect(runners == 10 and hunters == 2, "Twelve players should produce ten runners and two hunters")
	local hunter = f.players[1]
	expect(hunter.Character:GetAttribute("RoundFrozen") and hunter.Character.children.HumanoidRootPart.Anchored, "Head start must anchor hunters on the server")
	expect(not f.round:TryTag(hunter), "Tag must be rejected during head start")
	local late = f:addPlayer(13)
	expect(f.round:GetRole(late) == "Spectator" and not f.round:IsActive(late), "Midround joins must remain spectators")
	expect(#f.round:_eligible() == 12, "Round admission must enforce the twelve-player cap")
	f:advance(5)
	f.round:_step()
	expect(f.round.phase == "Active" and f.round.endsAt - f:time() == 180, "Competitive chase must last exactly 180 seconds after head start")
	expect(not hunter.Character.children.HumanoidRootPart.Anchored and not hunter.Character:GetAttribute("RoundFrozen"), "Active phase must release hunters")
	f:advance(151)
	expect(f.round:Snapshot().finalChase, "Final chase should activate for the last thirty seconds")
end

-- Activation must not trust a runner's new client-owned position or cancel parkour.
do
	local f = fixture(2)
	f.round:_startRound(f.round:_eligible())
	local runner = f.players[2]
	local state = f.movement:_state(runner)
	local remembered, modeId = state.lastPosition, state.modeId
	state.sprint = true
	runner.Character:SetAttribute("Sprinting", true)
	f:pose(runner, 100, 3, 0)
	f:advance(5)
	f.round:_activate()
	expect(state.lastPosition == remembered and state.modeId == modeId and state.sprint, "Releasing hunters must preserve runner movement history and sprint")
	expect(not f.movement:ValidatePosition(runner), "Activation must not bless a runner teleport")
end

-- Tag authority: live hunter, range, geometry, cooldown, and one elimination.
do
	local f = fixture(3)
	f:startActive()
	local hunter, runner, other = f.players[1], f.players[2], f.players[3]
	f:pose(runner, 8, 3, 0, true)
	f:pose(other, 40, 3, 0, true)
	expect(not f.round:TryTag(hunter), "Out-of-range target must not tag")
	f:pose(runner, 4, 3, 0, true)
	expect(not f.round:TryTag(hunter), "Misses must still consume the server tag cooldown")
	f:advance(0.7)
	f.world.raycast = function(origin, delta)
		if delta.Y == 0 and delta.Magnitude > 0 then return { Instance = f.ground, Normal = Vector3.xAxis, Position = origin + delta / 2 } end
		return { Instance = f.ground, Normal = Vector3.yAxis, Position = Vector3.new(origin.X, 0, origin.Z) }
	end
	expect(not f.round:TryTag(hunter), "Walls must block a tag inside the range radius")
	f.world.raycast = nil
	f:advance(0.7)
	expect(not f.round:TryTag(runner), "A runner must never tag another player")
	expect(f.round:TryTag(hunter), "Nearby unobstructed runner should be tagged")
	expect(f.round:GetRole(runner) == "Spectator" and f.round.roster[hunter.UserId].tags == 1, "Tag must eliminate once and credit the hunter")
	expect(runner.Character.children.HumanoidRootPart.Position.Z == 250, "Caught avatar must move to the lobby immediately")
	expect(f.round:Snapshot().lastRunner, "Last runner state must follow the alive roster")
	f:advance(0.7)
	expect(not f.round:TryTag(hunter) and f.round.roster[hunter.UserId].tags == 1, "An eliminated player must not be farmable")
end

-- Remote and death events at the deadline must settle a runner victory first.
for _, event in ipairs({ "tag", "reset" }) do
	local f = fixture(2)
	f:startActive()
	local hunter, runner = f.players[1], f.players[2]
	f:pose(runner, 4, 3, 0, true)
	f:advance(180)
	if event == "tag" then expect(not f.round:TryTag(hunter), "Tag at the exact deadline must be rejected")
	else f.round:_eliminate(runner, "reset") end
	f:advance(0)
	expect(f.round.phase == "Results" and f.round.winners[1] == runner.UserId, "Deadline must preserve the escaped runner's victory for " .. event)
	expect(f.round.roster[hunter.UserId].tags == 0, "Deadline race must not award a tag")
	local runnerAward
	for _, award in ipairs(f.awards) do if award.player == runner then runnerAward = award.summary end end
	expect(runnerAward and runnerAward.win and runnerAward.survived == 180, "Timer result must award the authoritative survival duration")
	f.round:_checkWin()
	f:advance(0)
	expect(#f.awards == 2, "Results must be idempotent across later win checks")
end

-- Real connection handlers cover departure, death, loading, and next-round recovery.
do
	local f = fixture(3)
	f.round:Start()
	f:advance(0)
	f:advance(16.1)
	f:advance(5.1)
	expect(f.round.phase == "Active", "Started service should advance its scheduled round loop")
	local hunter, runner = f.players[1], f.players[2]
	runner.Character.children.Humanoid.Health = 0
	runner.Character.children.Humanoid.Died:Fire()
	expect(f.round:GetRole(runner) == "Spectator", "Character death must eliminate its roster entry")
	f:remove(hunter)
	f:advance(0)
	expect(f.round.phase == "Results" and #f.round.winners == 1 and f.round.winners[1] == 3, "Last hunter leaving must reward only surviving runners")
	expect(not f.round.connections[hunter] and not f.round.characterConnections[hunter], "Departing player's connections must be disconnected")
	for _, award in ipairs(f.awards) do expect(award.player ~= hunter, "Departing player must not receive a round award") end
	f:advance(2)
	expect(runner.loadCalls and runner.loadCalls > 0, "Dead avatar must be queued for respawn")
	f:advance(9)
	expect(f.round.phase ~= "Results", "Results must expire and return to lobby flow")
end

-- Studio solo is playable, explicit, and cannot produce a competitive victory.
do
	local public = fixture(1, false)
	public.round:_step()
	expect(public.round.phase == "Waiting", "A public single-player server must wait for a competitor")
	local f = fixture(1, true)
	f:startActive()
	expect(f.round.practice and f.round:GetRole(f.players[1]) == "Runner", "Solo Studio must create a runner practice round")
	f:advance(180)
	f.round:_step()
	f:advance(0)
	expect(f.round.phase == "Results" and #f.round.winners == 0, "Practice completion must not create winners")
	expect(#f.awards == 1 and f.awards[1].summary.practice and not f.awards[1].summary.win, "Practice award summary must remain explicitly noncompetitive")
	local pending = fixture(2)
	pending.players[2].ready = false
	pending.round:_step()
	expect(pending.round.phase == "Waiting", "Unloaded profiles must not enter a competitive round")
end

-- Movement credit cannot be minted by remote spam; corrections restore a safe point.
do
	local f = fixture(1)
	local player = f.players[1]
	local root, state = player.Character.children.HumanoidRootPart, f.movement:_state(player)
	f:advance(0.08)
	f:pose(player, 1.3, 3, 0)
	expect(f.movement:ValidatePosition(player), "Normal walking should pass")
	local credit = state.credit
	for _ = 1, 20 do expect(f.movement:ValidatePosition(player), "Repeated unchanged position may validate") end
	expect(state.credit == credit, "Repeated intents must not mint movement credit")
	f:advance(0.08)
	f:pose(player, 80, 3, 0)
	expect(not f.movement:ValidatePosition(player) and math.abs(root.Position.X - 1.3) < 0.001, "Teleport must reject and restore the last grounded position")
	expect(not f.movement:ValidatePosition(player), "Correction must briefly block further range-sensitive actions")
	f:advance(0.4)
	f.movement:Handle(player, "Sprint", { active = "true" })
	expect(not state.sprint, "Malformed sprint payload must be ignored")
	f.movement:Handle(player, "Sprint", { active = true })
	expect(state.sprint and player.Character:GetAttribute("Sprinting"), "Server-approved sprint must set the animation attribute")
	f.movement:Handle(player, "Sprint", { active = false })
	expect(not state.sprint and not player.Character:GetAttribute("Sprinting"), "Sprint release must clear state")
	f:pose(player, 100, 3, 0, true)
	expect(f.movement:ValidatePosition(player), "Trusted server teleports must reset the movement history")
end

-- A ladder must exist, and its vertical climb consumes speed credit.
do
	local f = fixture(1)
	local player = f.players[1]
	local humanoid = player.Character.children.Humanoid
	humanoid.state = Enum.HumanoidStateType.Climbing
	f:advance(0.1)
	f:pose(player, 0, 25, 0)
	expect(not f.movement:ValidatePosition(player), "Spoofed Climbing without a ladder must not permit flight")
	f:advance(0.4)
	f:pose(player, 0, 3, 0, true)
	local ladder = object("TrussPart")
	f.world.overlap = function() return { ladder } end
	f:advance(0.1)
	f:pose(player, 0, 4.2, 0)
	expect(f.movement:ValidatePosition(player), "Normal ascent beside a real ladder should pass")
	f:advance(0.1)
	f:pose(player, 0, 18.2, 0)
	expect(f.movement:ValidatePosition(player), "Initial replication credit should tolerate a bounded climb burst")
	f:advance(0.1)
	f:pose(player, 0, 32.2, 0)
	expect(not f.movement:ValidatePosition(player), "Repeated fast vertical climbing must exhaust movement credit")
end

-- Slide requires ground and momentum, has a server cooldown, and yields ownership.
do
	local f = fixture(1)
	local player = f.players[1]
	local root, state = player.Character.children.HumanoidRootPart, f.movement:_state(player)
	f.movement:Handle(player, "Slide", {})
	expect(not player.Character:GetAttribute("Sliding"), "Stationary nonsprinting player must not slide")
	f.movement:Handle(player, "Sprint", { active = true })
	f.movement:Handle(player, "Slide", {})
	expect(player.Character:GetAttribute("Sliding") and root.owner == "server", "Accepted slide must take server network ownership")
	local first = state.lastSlide
	f:advance(0.1)
	f.movement:Handle(player, "Slide", {})
	expect(state.lastSlide == first, "Slide request must not refresh an active slide")
	f:advance(0.6)
	f.movement:_step(player, 0.08)
	expect(not player.Character:GetAttribute("Sliding") and root.owner == "auto", "Slide completion must restore automatic network ownership")
	f.movement:Handle(player, "Slide", {})
	expect(state.lastSlide == first, "Cooldown must continue after slide animation ends")
end

-- Vault accepts only server-detected low obstacles and a clear swept path.
do
	local f = fixture(1)
	local player = f.players[1]
	local root = player.Character.children.HumanoidRootPart
	local obstacle = object("Part")
	obstacle.Anchored = true
	f.world.raycast = function(origin, delta)
		if delta.Z < 0 then return { Instance = obstacle, Position = Vector3.new(0, 2, -2), Normal = Vector3.zAxis } end
		if origin.Z < -4 then return { Instance = f.ground, Position = Vector3.new(0, 0, origin.Z), Normal = Vector3.yAxis } end
		if origin.Z < -1 then return { Instance = obstacle, Position = Vector3.new(0, 2.7, origin.Z), Normal = Vector3.yAxis } end
		if delta.Y < 0 then return { Instance = f.ground, Position = Vector3.new(0, 0, 0), Normal = Vector3.yAxis } end
		return nil
	end
	f.world.blockcast = function() return { Instance = obstacle } end
	f.movement:Handle(player, "Vault", {})
	expect(not player.Character:GetAttribute("Vaulting") and not root.Anchored, "Blocked vault trajectory must be rejected")
	f.world.blockcast = nil
	f.movement:Handle(player, "Vault", {})
	expect(player.Character:GetAttribute("Vaulting") and root.Anchored, "Clear low obstacle should begin an anchored server vault")
	f:advance(0.2)
	expect(root.Position.Y > 5 and f.movement:ValidatePosition(player), "Bounded server vault may rise above the jump envelope")
	f:advance(0.3)
	expect(not root.Anchored and not player.Character:GetAttribute("Vaulting") and root.owner == "auto", "Completed vault must release its anchor and ownership")
	expect(math.abs(root.Position.Z + 5.2) < 0.001 and math.abs(root.Position.Y - 3.15) < 0.001, "Vault must land at the server-computed clear destination")
	expect(f.movement:ValidatePosition(player), "Completed server vault must seed valid movement history")
	f:pose(player, 0, 3, 0, true)
	f.movement:Handle(player, "Vault", {})
	f:advance(0.12)
	expect(root.Anchored, "Second server vault should be in progress before a round teleport")
	f:pose(player, 20, 3, 20, true)
	f:advance(0.5)
	expect(root.Position == Vector3.new(20, 3, 20) and not root.Anchored, "Canceled vault coroutine must not undo a newer trusted teleport")
	expect(not player.Character:GetAttribute("Vaulting"), "Trusted teleport must clear the canceled vault pose")
	f:pose(player, 0, 3, 0, true)
	f.movement:Handle(player, "Vault", {})
	f:advance(0.12)
	player.Character.children.Humanoid.Health = 0
	f:advance(0.5)
	expect(not root.Anchored and not player.Character:GetAttribute("Vaulting"), "Death during a vault must not leave the old avatar anchored")
end

print("Gameplay service tests passed: " .. checks .. " checks")
