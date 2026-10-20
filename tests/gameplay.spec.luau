-- Execute the production round/movement modules with deterministic Roblox boundaries.
-- This validates state transitions and authority checks, not live Roblox physics.
-- Run: .tooling/bin/lune run tests/gameplay.spec.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Rules = require("../src/shared/Rules")
local Config = require("../src/shared/Config")
local Modifiers = require("../src/shared/Modifiers")
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
	function value:IsA(name) return self.ClassName == name or (name == "BasePart" and self.ClassName == "Part") end
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
		value.AssemblyMass = 12
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
		Vector3 = Vector3, Vector2 = roblox.Vector2, CFrame = CFrame, Enum = Enum,
		Instance = { new = object },
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
			Movement = table.clone(Config.Movement),
			Hide = table.clone(Config.Hide),
			Progression = Config.Progression,
		},
		Rules = Rules, Modifiers = Modifiers, Services = {},
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
	local f = { environment = environment, ctx = ctx, round = round, movement = movement, players = roster, playersService = players, run = run, world = world, ground = ground, notices = notices, snapshots = snapshots, awards = awards }
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
		humanoid.RigType = Enum.HumanoidRigType.R15
		humanoid.AutoRotate = true
		humanoid.Died, humanoid.state = signal(), Enum.HumanoidStateType.Running
		function humanoid:GetState() return self.state end
		function humanoid:ChangeState(state) self.state = state end
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

-- Reproduce Studio's R6 HipHeight=0 with finite-length ground intersections.
-- Earlier R15-only fixtures concealed this rejection: an R6 root stands
-- 3 studs above the floor, beyond the old 2.25-stud query. R15, scaled rigs,
-- and the small tolerated floor gap must keep their existing behavior.
for _, rig in ipairs({
	{ name = "R6", kind = Enum.HumanoidRigType.R6, root = 2, leg = 2, hip = 0, support = 3 },
	{ name = "scaled R6", kind = Enum.HumanoidRigType.R6, root = 3, leg = 3, hip = 0.4, support = 4.9 },
	{ name = "R6 right-leg fallback", kind = Enum.HumanoidRigType.R6, root = 2, leg = 2, hip = 0, support = 3, right = true },
	{ name = "R15", kind = Enum.HumanoidRigType.R15, root = 2, leg = 20, hip = 2, support = 3 },
	{ name = "scaled R15", kind = Enum.HumanoidRigType.R15, root = 3, hip = 3, support = 4.5 },
	{ name = "small R15", kind = Enum.HumanoidRigType.R15, root = 1, hip = 1, support = 1.5 },
}) do
	local f = fixture(1)
	local player = f.players[1]
	local character = player.Character
	local humanoid, root = character.children.Humanoid, character.children.HumanoidRootPart
	humanoid.RigType, humanoid.HipHeight = rig.kind, rig.hip
	root.Size = Vector3.new(2, rig.root, 1)
	if rig.leg then
		local leg = object("Part")
		leg.Size, leg.Parent = Vector3.new(1, rig.leg, 1), character
		character.children[rig.right and "Right Leg" or "Left Leg"] = leg
	end
	f:pose(player, 0, rig.support, 0, true)
	local rayLength, excluded
	f.world.raycast = function(origin, delta, parameters)
		if delta.X == 0 and delta.Z == 0 and delta.Y < 0 then
			rayLength, excluded = -delta.Y, parameters.FilterDescendantsInstances[1]
			if origin.Y >= 0 and origin.Y + delta.Y <= 0 then
				return { Position = Vector3.new(origin.X, 0, origin.Z), Normal = Vector3.yAxis, Instance = f.ground }
			end
		end
		return nil
	end
	expect(f.movement:_grounded(character, humanoid, root), rig.name .. " standing on the floor must be grounded")
	local tolerance = math.clamp(rig.root * 0.625, 0.5, 1.25)
	expect(math.abs(rayLength - rig.support - tolerance) < 0.001 and excluded == character,
		rig.name .. " must query its actual support height plus bounded tolerance, excluding its own shoes")
	f:pose(player, 0, rig.support + tolerance + 0.1, 0, true)
	expect(not f.movement:_grounded(character, humanoid, root), rig.name .. " above the bounded floor gap must remain airborne")
	root.AssemblyLinearVelocity = Vector3.new(0, 0, -20)
	f.movement:Handle(player, "Slide", {})
	expect(not f.movement:_state(player).slideMotion and #f.notices == 0,
		rig.name .. " airborne slide must be rejected without consuming cooldown")
	f:pose(player, 0, rig.support, 0, true)
	root.AssemblyLinearVelocity = Vector3.new(0, 0, -20)
	f.movement:Handle(player, "Slide", {})
	local state = f.movement:_state(player)
	local motion = state.slideMotion
	expect(motion ~= nil and character:GetAttribute("Sliding") and #f.notices == 1,
		rig.name .. " moving on the floor must actually start a slide and acknowledge its cooldown")
	f:advance(0.1)
	f.movement:_step(player, 0.1)
	expect(state.slideMotion == motion and motion.velocity.PlaneVelocity.Magnitude > 20,
		rig.name .. " slide must stay grounded and accelerate on subsequent server updates")
	f:advance(Config.Movement.SlideDuration)
	f.movement:_step(player, 0.1)
	expect(not state.slideMotion and humanoid:GetState() == Enum.HumanoidStateType.Running,
		rig.name .. " slide must clean up to Running instead of misclassifying the floor as Freefall")
	f:pose(player, 0, rig.support, 0, true)
	root.AssemblyLinearVelocity = Vector3.new(0, 0, -20)
	f.movement:Handle(player, "Slide", {})
	expect(state.slideMotion ~= nil, rig.name .. " trusted spawn/reset must permit a fresh slide")
end

-- Slide requires measured ground momentum, even while Shift is held. It must
-- retain a horizontal actuator across frames instead of pulsing character speed.
do
	local f = fixture(1)
	local player = f.players[1]
	local humanoid, root, state = player.Character.children.Humanoid, player.Character.children.HumanoidRootPart, f.movement:_state(player)
	f.movement:Handle(player, "Slide", {})
	expect(not player.Character:GetAttribute("Sliding"), "Stationary nonsprinting player must not slide")
	f.movement:Handle(player, "Sprint", { active = true })
	f.movement:Handle(player, "Slide", {})
	expect(not state.slideMotion and state.lastSlide == -math.huge and #f.notices == 0,
		"Holding Shift while stationary must not create propulsion or consume cooldown")
	root.AssemblyLinearVelocity = Vector3.new(26, -2, 0)
	root.Anchored = true
	f.movement:Handle(player, "Slide", {})
	expect(not state.slideMotion and #f.notices == 0, "An anchored avatar must not begin an actuator slide")
	root.Anchored = false
	f.world.raycast = function() return nil end
	f.movement:Handle(player, "Slide", {})
	expect(not state.slideMotion and #f.notices == 0, "Airborne slide must not create an air dash or acknowledge cooldown")
	f.world.raycast = nil
	f.movement:Handle(player, "Slide", {})
	local motion = state.slideMotion
	expect(player.Character:GetAttribute("Sliding") and root.owner == "server", "Accepted slide must take server network ownership")
	expect(motion and humanoid:GetState() == Enum.HumanoidStateType.Physics and humanoid.WalkSpeed == 0 and not humanoid.AutoRotate,
		"Slide must suppress the Humanoid motor that otherwise brakes away its propulsion")
	expect(motion.velocity.PlaneVelocity == roblox.Vector2.new(26, 0) and state.slideDirection == Vector3.xAxis,
		"Slide must follow measured forward travel rather than force the camera-facing axis")
	expect(motion.velocity.VelocityConstraintMode == Enum.VelocityConstraintMode.Plane and motion.velocity.ForceLimitsEnabled
		and motion.velocity.MaxPlanarAxesForce.X > 0 and motion.velocity.MaxPlanarAxesForce.Y > 0,
		"Slide must apply bounded horizontal force while leaving gravity unconstrained")
	expect(#f.notices == 1 and f.notices[1].notice.action == "Slide" and f.notices[1].notice.cooldown == 3,
		"Only an accepted slide should start the displayed server cooldown")
	-- The fixture does not simulate physics. Real Roblox serialization catches
	-- misspelled/unsupported actuator properties in addition to these policy tests.
	local model, actualRoot = roblox.Instance.new("Model"), roblox.Instance.new("Part")
	actualRoot.Parent = model
	local actualAttachment = roblox.Instance.new("Attachment"); actualAttachment.Parent = actualRoot
	for _, record in ipairs({ motion.velocity, motion.orientation }) do
		local instance = roblox.Instance.new(record.ClassName)
		for key, value in pairs(record) do
			if type(value) ~= "function" and key ~= "ClassName" and key ~= "children" and key ~= "attributes"
				and key ~= "Parent" and key ~= "Attachment0" then instance[key] = value end
		end
		instance.Attachment0, instance.Parent = actualAttachment, actualRoot
	end
	expect(#roblox.serializeModel({ model }) > 0, "Slide actuator properties must serialize as valid Roblox objects")
	model:Destroy()
	local first = state.lastSlide
	f:advance(Config.Movement.SlideAccelerationTime)
	f.movement:_stepSlide(player, state, 1 / 60)
	expect(math.abs(motion.velocity.PlaneVelocity.Magnitude - Config.Movement.SlideSpeed) < 0.001,
		"Slide should ramp smoothly to its configured speed")
	f.movement:Handle(player, "Slide", {})
	expect(state.lastSlide == first, "Slide request must not refresh an active slide")
	f:advance(0.3)
	f.movement:_stepSlide(player, state, 1 / 60)
	expect(motion.velocity.PlaneVelocity.Magnitude < Config.Movement.SlideSpeed
		and motion.velocity.PlaneVelocity.Magnitude > Config.Movement.RunnerSprint,
		"Slide should ease back toward running speed before releasing control")
	f:advance(Config.Movement.SlideDuration)
	f.movement:_step(player, 0.08)
	expect(not player.Character:GetAttribute("Sliding") and root.owner == "auto", "Slide completion must restore automatic network ownership")
	expect(not state.slideMotion and motion.velocity.destroyed and motion.orientation.destroyed and motion.attachment.destroyed,
		"Slide completion must remove every temporary force and attachment")
	expect(humanoid.AutoRotate and humanoid.WalkSpeed == Config.Movement.RunnerSprint and humanoid:GetState() == Enum.HumanoidStateType.Running,
		"Slide completion must restore normal Humanoid locomotion")
	f.movement:Handle(player, "Slide", {})
	expect(state.lastSlide == first, "Cooldown must continue after slide animation ends")
	f:advance(3)
	f.movement:Handle(player, "Slide", {})
	expect(state.lastSlide > first and #f.notices == 2, "A moving player must be able to slide again after the server cooldown")
end

local function slidingFixture()
	local f = fixture(1)
	local player = f.players[1]
	local root, humanoid = player.Character.children.HumanoidRootPart, player.Character.children.Humanoid
	root.AssemblyLinearVelocity = Vector3.new(0, 0, -20)
	f.movement:Handle(player, "Slide", {})
	local state = f.movement:_state(player)
	assert(state.slideMotion, "Sliding test setup failed")
	return f, player, humanoid, root, state, state.slideMotion
end

-- Obstacles, ledges, jumping, death, teleports and respawn must never retain a
-- force or Physics state from the preceding slide.
for _, ending in ipairs({ "wall", "ledge", "jump", "death", "freeze", "seat", "anchor", "teleport", "correction", "respawn", "disconnect" }) do
	local f, player, humanoid, root, state, motion = slidingFixture()
	local character = player.Character
	if ending == "wall" then
		f.world.blockcast = function() return { Instance = f.ground, Normal = Vector3.zAxis } end
	elseif ending == "ledge" then
		f.world.raycast = function() return nil end
	elseif ending == "jump" then
		f.movement:Handle(player, "Vault", {})
	elseif ending == "death" then
		humanoid.Health = 0
	elseif ending == "freeze" then
		character:SetAttribute("RoundFrozen", true)
	elseif ending == "seat" then
		humanoid.Sit = true
	elseif ending == "anchor" then
		root.Anchored = true
	elseif ending == "teleport" then
		f:pose(player, 20, 3, 20, true)
	elseif ending == "correction" then
		f:advance(0.1)
		f:pose(player, 100, 3, 0)
		expect(not f.movement:ValidatePosition(player), "Illegal movement during a slide must still be corrected")
	elseif ending == "respawn" then
		local replacement = f:addPlayer(2)
		player.Character = replacement.Character
		f.movement:ResetPlayer(player)
	elseif ending == "disconnect" then
		f.movement:Start()
		f:remove(player)
	end
	f.movement:_stepSlide(player, state, 1 / 60)
	expect(not state.slideMotion and not character:GetAttribute("Sliding"), ending .. " must clear the replicated slide state")
	expect(motion.velocity.destroyed and motion.orientation.destroyed and motion.attachment.destroyed,
		ending .. " must destroy forces belonging to the old avatar")
	if ending ~= "anchor" then expect(root.owner == "auto", ending .. " must release server network ownership") end
	if ending == "jump" then
		expect(humanoid:GetState() == Enum.HumanoidStateType.Jumping and root.AssemblyLinearVelocity.Y == Config.Movement.JumpPower,
			"Jump must leave the slide immediately and preserve a normal jump impulse")
	elseif ending == "ledge" then
		expect(humanoid:GetState() == Enum.HumanoidStateType.Freefall, "Leaving a ledge must return to gravity-driven freefall")
	elseif ending == "freeze" then
		expect(humanoid.WalkSpeed == 0 and humanoid.JumpPower == 0, "Slide cleanup must respect a newly frozen round state")
		expect(humanoid:GetState() ~= Enum.HumanoidStateType.Physics, "Freezing must not strand an avatar in Physics after the next release")
	elseif ending == "respawn" then
		expect(humanoid:GetState() ~= Enum.HumanoidStateType.Physics and not player.Character:GetAttribute("Sliding"),
			"Respawn must release the old Humanoid without applying its pose to the replacement")
		player.Character.children.HumanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, -20)
		f.movement:Handle(player, "Slide", {})
		expect(state.slideMotion and state.slideMotion.character == player.Character, "Fresh avatar must slide immediately after respawning")
	end
end

-- Before activation, a wall rejects the move without burning a cooldown. The
-- accepted slide actuator then updates each frame independent of the 12.5 Hz
-- general validation budget.
do
	local f = fixture(1)
	local player = f.players[1]
	local root, state = player.Character.children.HumanoidRootPart, f.movement:_state(player)
	root.AssemblyLinearVelocity = Vector3.new(0, 0, -20)
	f.world.raycast = function(origin, delta)
		return { Instance = f.ground, Position = origin + delta, Normal = delta.Y < 0 and Vector3.yAxis or Vector3.zAxis }
	end
	f.movement:Handle(player, "Slide", {})
	expect(not state.slideMotion and state.lastSlide == -math.huge and #f.notices == 0, "A close wall must reject slide before cooldown begins")
	f.world.raycast = nil
	f.movement:Start()
	f.movement:Handle(player, "Slide", {})
	local before = state.slideMotion.velocity.PlaneVelocity.Magnitude
	f:advance(1 / 60)
	f.run.Heartbeat:Fire(1 / 60)
	expect(state.slideMotion.velocity.PlaneVelocity.Magnitude > before and f.movement.accumulator < 0.08,
		"Slide speed should update each Heartbeat without waiting for general validation")
end

-- Starting a round during a lobby slide holds a hunter, then releases it with
-- the standard Humanoid controller restored after the five-second head start.
do
	local f = fixture(2)
	local hunter = f.players[1]
	local root, humanoid = hunter.Character.children.HumanoidRootPart, hunter.Character.children.Humanoid
	root.AssemblyLinearVelocity = Vector3.new(0, 0, -20)
	f.movement:Handle(hunter, "Slide", {})
	expect(humanoid:GetState() == Enum.HumanoidStateType.Physics, "Round transition fixture must begin in a real slide state")
	f.round:_startRound(f.round:_eligible())
	expect(root.Anchored and not f.movement:_state(hunter).slideMotion and humanoid:GetState() ~= Enum.HumanoidStateType.Physics,
		"Head start must anchor a sliding hunter after cleaning up its Physics state")
	f:advance(5)
	f.round:_activate()
	expect(not root.Anchored and humanoid.AutoRotate and humanoid.WalkSpeed > 0 and humanoid:GetState() ~= Enum.HumanoidStateType.Physics,
		"Head start release must restore movement after an interrupted lobby slide")
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
	local vaultRaycast = f.world.raycast
	f.world.raycast = nil
	f:pose(player, 0, 3, 0, true)
	root.AssemblyLinearVelocity = Vector3.new(0, 0, -20)
	f.movement:Handle(player, "Slide", {})
	local slideMotion = f.movement:_state(player).slideMotion
	expect(slideMotion ~= nil, "Slide-vault fixture must begin with active propulsion")
	f.world.raycast = vaultRaycast
	f.movement:Handle(player, "Vault", {})
	expect(not f.movement:_state(player).slideMotion and slideMotion.velocity.destroyed
		and player.Character:GetAttribute("Vaulting") and root.Anchored,
		"Vault should replace slide propulsion with one bounded anchored trajectory")
	f:advance(0.5)
	expect(not root.Anchored and player.Character.children.Humanoid:GetState() ~= Enum.HumanoidStateType.Physics,
		"A slide-vault sequence must return to normal locomotion")
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


-- Round modifiers: deterministic selection and per-modifier rules.
do
	local last = function(maximum) return maximum end
	local first = function() return 1 end
	expect(Modifiers.Pick(12, nil, true, last).id == "classic", "Practice must always be Classic")
	expect(Modifiers.Pick(2, nil, false, last).id == "frenzy", "Two players may only see modifiers they support")
	expect(Modifiers.Pick(3, nil, false, first).id == "classic", "Infection needs four players")
	for _, modifier in ipairs(Modifiers.List) do
		for _, roll in ipairs({ first, last }) do
			expect(Modifiers.Pick(12, modifier.id, false, roll).id ~= modifier.id, "A modifier must not repeat back to back: " .. modifier.id)
		end
	end
	expect(Modifiers.HunterCount(Modifiers.ById.swarm, 6, 1) == 2, "Swarm adds a hunter")
	expect(Modifiers.HunterCount(Modifiers.ById.swarm, 12, 2) == 3, "Swarm adds a hunter in a full lobby")
	expect(Modifiers.HunterCount(Modifiers.ById.classic, 12, 2) == 2, "Classic keeps base hunter count")
	expect(Modifiers.HunterCount(Modifiers.ById.swarm, 3, 1) == 1, "Swarm never starves runners")
	expect(Modifiers.Get("nonsense").id == "classic", "Unknown modifier ids fall back to Classic")
end

-- Infection: tagged runners become held hunters, keep survival credit, and share the hunter win.
do
	local f = fixture(4)
	f.round.modifier = Modifiers.ById.infection
	f:startActive()
	local hunter, runner, second, third = f.players[1], f.players[2], f.players[3], f.players[4]
	expect(f.round:Snapshot().modifier.id == "infection", "Snapshot must publish the active modifier")
	expect(select(2, f.round:_counts()) == 1, "Four-player infection starts with one hunter")
	f:advance(30)
	f:pose(runner, 4, 3, 0, true)
	expect(f.round:TryTag(hunter), "Infection tag should land")
	expect(f.round:GetRole(runner) == "Hunter" and f.round:IsActive(runner), "Tagged runner must stay in the round as a hunter")
	expect(runner.Character:GetAttribute("RoundFrozen") and runner.Character.children.HumanoidRootPart.Anchored, "Infected player is held briefly by the server")
	expect(runner.Character.children.HumanoidRootPart.Position.Z == 0 and runner.Character.children.HumanoidRootPart.Position.X == 0, "Infected player respawns at a hunter spawn")
	f:pose(second, 4, 3, 0, true)
	f:advance(0.7)
	expect(not f.round:TryTag(runner), "Infected hunter cannot tag while held")
	f:advance(4)
	expect(not runner.Character:GetAttribute("RoundFrozen") and not runner.Character.children.HumanoidRootPart.Anchored, "Infected hunter is released after the hold")
	expect(f.round:GetRole(runner) == "Hunter", "Role remains hunter after release")
	f:pose(second, runner.Character.children.HumanoidRootPart.Position.X + 3, 3, runner.Character.children.HumanoidRootPart.Position.Z, true)
	expect(f.round:TryTag(runner), "Infected hunter can tag remaining runners")
	expect(f.round.roster[runner.UserId].tags == 1, "Infected tags are credited")
	f:advance(5)
	f:pose(third, 4, 3, 0, true)
	f:advance(1)
	expect(f.round:TryTag(hunter), "Original hunter catches the last runner")
	f:advance(0)
	expect(f.round.phase == "Results", "Catching every runner ends infection")
	local infected = {}
	for _, award in ipairs(f.awards) do infected[award.player.UserId] = award.summary end
	expect(infected[runner.UserId].role == "Hunter" and infected[runner.UserId].win and infected[runner.UserId].tags == 1, "Infected player shares the hunter win")
	expect(infected[runner.UserId].survived >= 30 and infected[runner.UserId].survived < 40, "Infected player keeps survival time")
	expect(infected[second.UserId].role == "Hunter" and infected[second.UserId].win, "Players infected later also share the win")
	expect(f.round:CooldownScale() == 1, "Cooldown scale resets outside the chase")
end

-- Infection near the final seconds stops converting so the clock decides the ending.
do
	local f = fixture(4)
	f.round.modifier = Modifiers.ById.infection
	f:startActive()
	local hunter, runner = f.players[1], f.players[2]
	f:advance(176)
	f:pose(runner, 4, 3, 0, true)
	expect(f.round:TryTag(hunter), "Late tag should land")
	expect(f.round:GetRole(runner) == "Spectator", "Late tags eliminate instead of infecting")
end

-- Infected players that time out lose with the runner team and a departing infected hunter is cleaned up.
do
	local f = fixture(4)
	f.round.modifier = Modifiers.ById.infection
	f:startActive()
	local hunter, runner = f.players[1], f.players[2]
	f:pose(runner, 4, 3, 0, true)
	expect(f.round:TryTag(hunter), "Tag to infect")
	f.round:Start()
	f:remove(runner)
	expect(not f.round.roster[runner.UserId].alive, "A departing infected hunter must leave the roster")
	f:advance(180.5)
	expect(f.round.phase == "Results" and #f.round.winners == 2, "Surviving runners win when time expires")
end

-- Swarm and Slide Frenzy change only the intended parameters.
do
	local f = fixture(6)
	f.round.modifier = Modifiers.ById.swarm
	f:startActive()
	local runners, hunters = f.round:_counts()
	expect(hunters == 2 and runners == 4, "Swarm adds a second hunter in a six-player lobby")
	expect(f.round.endsAt - f:time() == 120, "Swarm rounds last 120 seconds")
	local frenzy = fixture(3)
	frenzy.round.modifier = Modifiers.ById.frenzy
	expect(frenzy.movement:_cooldown(3) == 3, "Frenzy cooldown does not apply before the chase")
	frenzy:startActive()
	expect(frenzy.movement:_cooldown(3) == 1.5 and frenzy.round.endsAt - frenzy:time() == 180, "Frenzy halves slide and vault cooldowns only")
	local solo = fixture(1, true)
	solo.round.modifier = Modifiers.ById.infection
	solo:startActive()
	expect(solo.round.modifier.id == "classic", "Solo practice is always Classic")
end

-- Hiding, searching, scanning, coins and close calls ---------------------------------------------
do
	local f = fixture(4)
	local Hide = luau.load(fs.readFile("src/server/Services/HideService.lua"), { environment = f.environment, debugName = "HideService" })()
	local hide = Hide.new(f.ctx)
	f.ctx.Services.HideService = hide
	f:startActive()
	local hunter, runnerA, runnerB
	for _, player in ipairs(f.players) do
		local role = f.round:GetRole(player)
		if role == "Hunter" then hunter = player elseif not runnerA then runnerA = player elseif not runnerB then runnerB = player end
	end
	local function part(x, y, z)
		local p = object("Part")
		p.CFrame = CFrame.new(x, y, z)
		p.GetChildren = function() return {} end
		return p
	end
	local promptPart = part(22, 3, 0)
	local spot = {
		id = "test_cell", model = object("Model"), prompt = { MaxActivationDistance = 8, Parent = promptPart }, door = object("Part"),
		inside = CFrame.new(30, 3.1, 0), exit = CFrame.new(22, 3.1, -5), occupant = nil, lockedUntil = 0, anchorPart = promptPart,
	}
	hide.spots = { spot }
	f:pose(runnerA, 21, 3, 0, true)
	f:pose(runnerB, 20, 3, 2, true)
	f:pose(hunter, 18, 3, 0, true)
	local rootA, character = runnerA.Character.children.HumanoidRootPart, runnerA.Character
	hide:_triggered(runnerA, spot)
	expect(hide:IsHiding(runnerA) and rootA.Anchored and character:GetAttribute("CatchHiding") == true, "A runner in range hides and is anchored inside the cell")
	expect((rootA.CFrame.Position - spot.inside.Position).Magnitude < 0.01 and spot.model:GetAttribute("Occupied") == true, "Hiding places the runner inside and marks the cell occupied")
	expect(f.round:MoodFor(runnerA) == "Hide", "A hiding runner shows the hiding face")
	for _, other in ipairs(f.players) do
		if other ~= hunter and other ~= runnerA then f:pose(other, 90, 3, 90, true) end
	end
	f:pose(hunter, 24, 3, 0, true)
	expect(not f.round:TryTag(hunter), "A hiding runner cannot be tagged through the cell door")
	hide:_triggered(runnerB, spot)
	expect(not hide:IsHiding(runnerB) and spot.occupant == runnerA, "An occupied cell cannot be entered by a second runner")
	expect(not hide:Leave(runnerA), "Leaving within the minimum stay is refused")
	-- Distance is validated by the server, not trusted from the prompt.
	local far = f:pose(runnerB, 80, 3, 80, true)
	hide:_triggered(runnerB, spot)
	expect(not hide:IsHiding(runnerB), "Triggering a prompt from across the map is ignored")
	f:pose(runnerB, 20, 3, 2, true)
	-- A hunter's Search ejects the occupant next to the exit.
	hide:_triggered(hunter, spot)
	expect(not hide:IsHiding(runnerA) and not rootA.Anchored and character:GetAttribute("CatchHiding") == false, "Search ejects and unanchors the hidden runner")
	expect((rootA.CFrame.Position - spot.exit.Position).Magnitude < 0.01, "The discovered runner is placed at the cell exit")
	expect(f.round.roster[hunter.UserId].finds == 1, "The hunter is credited with the discovery")
	local sawReveal, sawFound = false, false
	for _, item in ipairs(f.notices) do
		if item.notice.kind == "reveal" and item.notice.userId == runnerA.UserId then sawReveal = true end
		if item.notice.kind == "found" and item.player == hunter then sawFound = true end
	end
	expect(sawReveal and sawFound, "Everyone sees the reveal and the searcher gets the discovery cue")
	hide:_triggered(hunter, spot)
	expect(f.round.roster[hunter.UserId].finds == 1, "Search spam inside the cooldown does nothing")
	-- The ejected runner must wait before hiding again; the spot is also briefly locked.
	hide:_triggered(runnerA, spot)
	expect(not hide:IsHiding(runnerA), "A runner just found cannot immediately re-hide")
	f:advance(13)
	f:pose(runnerA, 21, 3, 0, true)
	hide:_triggered(runnerA, spot)
	expect(hide:IsHiding(runnerA), "After the cooldown the runner can hide again")
	-- Scan: exposes visible runners and occupied cells (never named), then cools down.
	f:pose(hunter, 24, 3, 0, true)
	table.clear(f.notices)
	expect(hide:Scan(hunter), "A hunter can scan during the chase")
	local scan
	for _, item in ipairs(f.notices) do if item.notice.kind == "scan" then scan = item.notice end end
	expect(scan and table.find(scan.targets, runnerB.UserId) and not table.find(scan.targets, runnerA.UserId), "Scan lists visible runners but not hidden ones")
	expect(scan and #scan.spots == 1, "Scan exposes the occupied cell as an unnamed position")
	expect(not hide:Scan(hunter), "Scan respects its cooldown")
	expect(not hide:Scan(runnerB), "Runners cannot scan")
	f:advance(26)
	expect(hide:Scan(hunter), "Scan is available again after its cooldown")
	-- Timeout releases the runner next to the exit with a cooldown.
	f:advance(8)
	hide:_tick()
	expect(not hide:IsHiding(runnerA) and not rootA.Anchored, "Hiding ends automatically after the maximum time")
	-- Coins: validated pickup, one-time, capped, reset each round.
	local coinPart = part(21, 3.2, 2)
	local record = { part = coinPart, position = coinPart.CFrame.Position, collected = false }
	hide.coins = { record }
	hide.coinBuckets = { ["1,0,0"] = { record } }
	f:pose(runnerB, 21, 3, 2, true)
	hide:_collectCoins(runnerB, runnerB.Character.children.HumanoidRootPart)
	expect(record.collected and coinPart.Transparency == 1 and f.round.roster[runnerB.UserId].pickups == 1, "A runner in range collects the coin")
	hide:_collectCoins(runnerB, runnerB.Character.children.HumanoidRootPart)
	expect(f.round.roster[runnerB.UserId].pickups == 1, "A coin can only be collected once")
	f.round.roster[runnerB.UserId].pickups = f.ctx.Config.Hide.PickupCap
	record.collected = false
	hide:_collectCoins(runnerB, runnerB.Character.children.HumanoidRootPart)
	expect(not record.collected, "Pickups are capped per round")
	expect(f.round:AddPickup(hunter) == nil, "Hunters cannot collect coins")
	-- Close calls: near a hunter, then clear away, pays once per gap.
	f.round.roster[runnerB.UserId].pickups = 0
	local hunterRoot = f:pose(hunter, 30, 3, 0, true)
	local runnerRoot = f:pose(runnerB, 34, 3, 0, true)
	hide:_closeCalls(runnerB, runnerRoot, { hunterRoot })
	runnerRoot.CFrame = CFrame.new(70, 3, 0)
	hide:_closeCalls(runnerB, runnerRoot, { hunterRoot })
	expect(f.round.roster[runnerB.UserId].closeCalls == 1, "A close call is credited after escaping")
	runnerRoot.CFrame = CFrame.new(34, 3, 0)
	hide:_closeCalls(runnerB, runnerRoot, { hunterRoot })
	runnerRoot.CFrame = CFrame.new(70, 3, 0)
	hide:_closeCalls(runnerB, runnerRoot, { hunterRoot })
	expect(f.round.roster[runnerB.UserId].closeCalls == 1, "Close calls have a minimum gap so they cannot be farmed")
	-- Rewards include the objectives, and the results screen receives what the server granted.
	local reward = Rules.RoundReward({ role = "Runner", win = true, tags = 0, survived = 100, pickups = 10, closeCalls = 2 }, f.ctx.Config)
	local plain = Rules.RoundReward({ role = "Runner", win = true, tags = 0, survived = 100 }, f.ctx.Config)
	expect(reward.xp == plain.xp + 10 * 3 + 2 * 5 and reward.coins == plain.coins + 10, "Objective rewards are coins and XP only")
	-- A round change releases everyone and restores the coins.
	hide:_triggered(runnerA, spot)
	f.round.phase = "Results"
	hide:_tick()
	expect(not hide:IsHiding(runnerA) and not runnerA.Character.children.HumanoidRootPart.Anchored, "Round end releases hiders without a stuck anchor")
	f.round.phase = "Active"
	hide:ResetRound()
	expect(not record.collected and coinPart.Transparency == 0, "A new round restores the coins")
end

print("Gameplay service tests passed: " .. checks .. " checks")
