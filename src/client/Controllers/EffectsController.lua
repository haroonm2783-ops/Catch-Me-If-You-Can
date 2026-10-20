-- All feedback is cosmetic. Original visuals and engine-bundled sound fallbacks.
local Players = game:GetService("Players")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local EffectsController = {}
EffectsController.__index = EffectsController

local CYAN = Color3.fromRGB(75, 236, 235)
local GOLD = Color3.fromRGB(255, 203, 100)
local CORAL = Color3.fromRGB(255, 105, 117)
local WHITE = Color3.fromRGB(237, 249, 255)

-- These ship with Roblox; no marketplace IDs, external audio or permissions needed.
-- Missing engine files are cached as unavailable and skipped without repeated loads.
local BUILTIN_AUDIO = {
	Sprint = { path = "action_footsteps_plastic.mp3", pitch = 1.2, gain = 0.4 },
	Slide = { path = "action_footsteps_plastic.mp3", pitch = 0.7, gain = 0.4 },
	Land = { path = "action_footsteps_plastic.mp3", pitch = 0.82, gain = 0.38 },
	Vault = { path = "action_jump.mp3", pitch = 1.08, gain = 0.5 },
	Tag = { path = "electronicpingshort.wav", pitch = 1.25, gain = 0.55 },
	Win = { path = "electronicpingshort.wav", pitch = 1.4, gain = 0.6 },
	Lose = { path = "electronicpingshort.wav", pitch = 0.72, gain = 0.35 },
	Level = { path = "electronicpingshort.wav", pitch = 1.5, gain = 0.55 },
	Countdown = { path = "electronicpingshort.wav", pitch = 1, gain = 0.45 },
	Final = { path = "electronicpingshort.wav", pitch = 0.85, gain = 0.5 },
	Purchase = { path = "electronicpingshort.wav", pitch = 1.3, gain = 0.45 },
	Pickup = { path = "electronicpingshort.wav", pitch = 1.75, gain = 0.5 },
	CloseCall = { path = "action_jump.mp3", pitch = 1.35, gain = 0.5 },
	Found = { path = "electronicpingshort.wav", pitch = 0.95, gain = 0.6 },
	Hide = { path = "action_footsteps_plastic.mp3", pitch = 0.55, gain = 0.3 },
	Reveal = { path = "electronicpingshort.wav", pitch = 0.6, gain = 0.5 },
	Scan = { path = "electronicpingshort.wav", pitch = 0.5, gain = 0.5 },
}

local function audioSpec(config, name)
	local id = tonumber((config.Audio or {})[name])
	if id and id > 0 and id < math.huge and id == math.floor(id) then
		return "rbxassetid://" .. tostring(id), 1, 1
	end
	local builtin = BUILTIN_AUDIO[name]
	if builtin then
		return "rbxasset://sounds/" .. builtin.path, builtin.pitch, builtin.gain
	end
	return nil
end

local function tween(instance, duration, properties, style)
	local animation = TweenService:Create(instance,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	animation:Play()
	return animation
end

function EffectsController.new(ctx)
	return setmetatable({
		ctx = ctx,
		player = Players.LocalPlayer,
		connections = {},
		sounds = {},
		audioAvailability = {},
		pendingSounds = {},
		lastTag = 0,
		elapsed = 0,
		sequence = 0,
		random = Random.new(),
	}, EffectsController)
end

function EffectsController:_play(sound, predicate, setting)
	setting = setting or "sfx"
	local source = sound.SoundId
	if self.audioAvailability[source] == false or self.pendingSounds[sound] then
		return
	end
	local function playIfAllowed()
		if not self.destroyed and sound.Parent and self:_settings()[setting] ~= false
			and (not predicate or predicate()) then
			pcall(function()
				sound:Play()
			end)
		end
	end
	if self.audioAvailability[source] then
		playIfAllowed()
		return
	end
	self.pendingSounds[sound] = true
	task.spawn(function()
		local loaded = false
		local ok = pcall(function()
			ContentProvider:PreloadAsync({ sound }, function(_, status)
				loaded = status == Enum.AssetFetchStatus.Success
			end)
		end)
		self.pendingSounds[sound] = nil
		self.audioAvailability[source] = ok and loaded
		if ok and loaded then
			playIfAllowed()
		end
	end)
end

function EffectsController:_settings()
	return self.ctx.Profile.settings or {}
end

function EffectsController:_sound(name, volume, pitchScale)
	if self:_settings().sfx == false then
		return
	end
	local source, pitch, gain = audioSpec(self.ctx.Config, name)
	if not source or self.audioAvailability[source] == false then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Catch" .. name
	sound.SoundId = source
	sound.PlaybackSpeed = pitch * (pitchScale or 1)
	sound.Volume = (volume or 0.4) * gain
	sound.Parent = SoundService
	self.sounds[sound] = true
	sound.Ended:Once(function()
		self.sounds[sound] = nil
		sound:Destroy()
	end)
	sound.Destroying:Once(function()
		self.sounds[sound] = nil
	end)
	self:_play(sound)
	Debris:AddItem(sound, 15)
end

-- Looping beds (soundtrack and mall ambience). Both follow the music preference and only play
-- when a verified asset id is configured; nothing is invented here.
function EffectsController:_loop(field, configKey, name, volume)
	if not self[field] then
		local id = tonumber((self.ctx.Config.Audio or {})[configKey])
		if not id or id <= 0 or id == math.huge or id ~= math.floor(id) then
			return
		end
		self[field] = Instance.new("Sound")
		self[field].Name = name
		self[field].SoundId = "rbxassetid://" .. tostring(id)
		self[field].Looped = true
		self[field].Volume = volume
		self[field].Parent = SoundService
	end
	local sound = self[field]
	if self:_settings().music == false then
		sound:Pause()
	elseif not sound.IsPlaying then
		if sound.TimePosition > 0 then
			sound:Resume()
		else
			-- Validate a configured soundtrack just like SFX. Music has its own
			-- preference: muting footsteps must not mute an enabled soundtrack.
			self:_play(sound, nil, "music")
		end
	end
end

function EffectsController:_music()
	self:_loop("music", "Music", "CatchMusic", 0.18)
	self:_loop("ambience", "Ambience", "CatchAmbience", 0.12)
end

function EffectsController:_sprintAudio()
	local character = self.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local active = self:_settings().sfx ~= false and character
		and character:GetAttribute("Sprinting") == true
		and character:GetAttribute("Sliding") ~= true and character:GetAttribute("Vaulting") ~= true and humanoid
		and humanoid.Health > 0 and humanoid.MoveDirection.Magnitude > 0.1
		and humanoid.FloorMaterial ~= Enum.Material.Air
	self.sprintWanted = active == true
	if not active then
		if self.sprintSound then
			self.sprintSound:Pause()
		end
		return
	end
	if not self.sprintSound then
		local source, pitch, gain = audioSpec(self.ctx.Config, "Sprint")
		if not source or self.audioAvailability[source] == false then
			return
		end
		self.sprintSound = Instance.new("Sound")
		self.sprintSound.Name = "CatchSprint"
		self.sprintSound.SoundId = source
		self.sprintSound.PlaybackSpeed = pitch
		self.sprintSound.Volume = 0.12 * gain
		self.sprintSound.Looped = true
		self.sprintSound.Parent = SoundService
	end
	if not self.sprintSound.IsPlaying then
		self:_play(self.sprintSound, function()
			return self.sprintWanted
		end)
	end
end

function EffectsController:_pulse(color, strength)
	if not self.gui or not self.gui.Parent then
		return
	end
	local reduced = self:_settings().reducedMotion == true
	local frame = Instance.new("Frame")
	frame.Name = "EdgePulse"
	frame.Size = UDim2.new(1, -12, 1, -12)
	frame.Position = UDim2.fromOffset(6, 6)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = self.gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = reduced and 2 or 4
	stroke.Transparency = 1 - math.clamp(strength or 0.7, 0, 0.8)
	stroke.Parent = frame
	tween(stroke, reduced and 0.5 or 0.8, { Transparency = 1, Thickness = 1 })
	Debris:AddItem(frame, 0.9)
end

function EffectsController:_banner(text, color, duration, large)
	if not self.gui or not self.gui.Parent then
		return
	end
	self.sequence += 1
	if self.banner then
		self.banner:Destroy()
	end
	local label = Instance.new("TextLabel")
	label.Name = "ChaseCue"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.55)
	label.Size = UDim2.new(0.85, 0, 0, large and 110 or 42)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.TextSize = large and 82 or 25
	label.TextScaled = true
	local textLimit = Instance.new("UITextSizeConstraint")
	textLimit.MaxTextSize = large and 82 or 25
	textLimit.MinTextSize = large and 34 or 13
	textLimit.Parent = label
	label.TextStrokeColor3 = Color3.fromRGB(14, 23, 40)
	label.TextStrokeTransparency = 0.3
	label.TextTransparency = 0
	label.Parent = self.gui
	self.banner = label
	local scale = Instance.new("UIScale")
	scale.Scale = self:_settings().reducedMotion and 1 or 0.92
	scale.Parent = label
	if not self:_settings().reducedMotion then
		tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	task.delay(duration or 0.65, function()
		if label.Parent then
			tween(label, 0.25, { TextTransparency = 1, TextStrokeTransparency = 1 })
			Debris:AddItem(label, 0.3)
		end
	end)
end

function EffectsController:_confetti(color)
	if self:_settings().reducedMotion or not self.gui then
		return
	end
	for index = 1, 22 do
		local shard = Instance.new("Frame")
		shard.Name = "Confetti"
		shard.AnchorPoint = Vector2.new(0.5, 0.5)
		shard.Size = UDim2.fromOffset(self.random:NextInteger(4, 8), self.random:NextInteger(8, 15))
		shard.BackgroundColor3 = index % 3 == 0 and WHITE or color
		shard.BorderSizePixel = 0
		shard.Rotation = self.random:NextInteger(-90, 90)
		local left = index % 2 == 0
		shard.Position = UDim2.fromScale(left and 0 or 1, self.random:NextNumber(0.4, 0.7))
		shard.Parent = self.gui
		local duration = self.random:NextNumber(0.85, 1.35)
		tween(shard, duration, {
			Position = UDim2.fromScale(left and self.random:NextNumber(0.15, 0.42)
				or self.random:NextNumber(0.58, 0.85), self.random:NextNumber(0.08, 0.3)),
			Rotation = shard.Rotation + self.random:NextInteger(-160, 160),
			BackgroundTransparency = 1,
		})
		Debris:AddItem(shard, duration + 0.1)
	end
end

function EffectsController:_worldBurst(position, color, bloom, palette)
	if typeof(position) ~= "Vector3" or self:_settings().reducedMotion or not self.worldEffects then
		return
	end
	local camera = workspace.CurrentCamera
	if not camera or (camera.CFrame.Position - position).Magnitude > 160 then
		return
	end
	local count = bloom and 14 or 9
	for index = 1, count do
		local angle = index / count * math.pi * 2
		local direction = Vector3.new(math.cos(angle), self.random:NextNumber(-0.1, 0.8), math.sin(angle))
		local spark = Instance.new("Part")
		spark.Name = "TagSpark"
		spark.Size = bloom and Vector3.new(0.22, 0.22, 0.22) or Vector3.new(0.13, 0.45, 0.13)
		spark.Shape = bloom and Enum.PartType.Ball or Enum.PartType.Block
		spark.Material = Enum.Material.Neon
		spark.Color = palette and palette[(index % #palette) + 1] or (index % 3 == 0 and WHITE or color)
		spark.CanCollide = false
		spark.CanTouch = false
		spark.CanQuery = false
		spark.CastShadow = false
		spark.Anchored = true
		spark.CFrame = CFrame.new(position + direction * 0.3)
		spark.Parent = self.worldEffects
		tween(spark, 0.48, {
			Position = position + direction * (bloom and 4 or 3),
			Transparency = 1,
			Size = Vector3.new(0.03, 0.03, 0.03),
		})
		Debris:AddItem(spark, 0.55)
	end
end

-- A small ring of dust puffs at the feet: slides, vaults and hard landings. Cosmetic and short-lived.
function EffectsController:_dust(strong)
	local character = self.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not self.worldEffects or self:_settings().reducedMotion then return end
	local base = root.Position - Vector3.new(0, 2.6, 0)
	local count = strong and 6 or 4
	for index = 1, count do
		local angle = index / count * math.pi * 2 + self.random:NextNumber(-0.3, 0.3)
		local dx, dz = math.cos(angle), math.sin(angle)
		local puff = Instance.new("Part")
		puff.Name = "DustPuff"
		puff.Shape = Enum.PartType.Ball
		puff.Size = Vector3.new(0.8, 0.8, 0.8)
		puff.Material = Enum.Material.SmoothPlastic
		puff.Color = Color3.fromRGB(236, 228, 214)
		puff.Transparency = 0.3
		puff.Anchored, puff.CanCollide, puff.CanTouch, puff.CanQuery, puff.CastShadow = true, false, false, false, false
		puff.Position = base + Vector3.new(dx * 0.8, 0.2, dz * 0.8)
		puff.Parent = self.worldEffects
		tween(puff, 0.5, {Position = base + Vector3.new(dx * 2.6, 0.9, dz * 2.6), Size = Vector3.new(2.4, 2.4, 2.4), Transparency = 1})
		Debris:AddItem(puff, 0.6)
	end
end

-- Danger vignette: red glows at the screen edges that grow as a hunter closes in on a runner.
function EffectsController:_buildDanger()
	self.dangerFrames = {}
	self.danger = 0
	local specs = {
		{UDim2.new(1, 0, 0, 120), UDim2.fromScale(0, 0), 90}, {UDim2.new(1, 0, 0, 120), UDim2.new(0, 0, 1, -120), 270},
		{UDim2.new(0, 120, 1, 0), UDim2.fromScale(0, 0), 0}, {UDim2.new(0, 120, 1, 0), UDim2.new(1, -120, 0, 0), 180},
	}
	for _, spec in ipairs(specs) do
		local frame = Instance.new("Frame")
		frame.Name = "DangerEdge"
		frame.Size, frame.Position = spec[1], spec[2]
		frame.BackgroundColor3 = CORAL
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Visible = false
		frame.Active = false
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = spec[3]
		gradient.Transparency = NumberSequence.new(0, 1)
		gradient.Parent = frame
		frame.Parent = self.gui
		table.insert(self.dangerFrames, frame)
	end
end

function EffectsController:_dangerTick()
	local state = self.ctx.State
	local target = 0
	local character = self.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if state.phase == "Active" and root and not self:_settings().reducedMotion and character:GetAttribute("CatchHiding") ~= true then
		local runner = false
		for _, entry in ipairs(state.players or {}) do
			if entry.userId == self.player.UserId then runner = entry.role == "Runner" and entry.alive ~= false end
		end
		if runner then
			local range = (self.ctx.Config.Round or {}).ScareDistance or 34
			local nearest = math.huge
			for _, entry in ipairs(state.players or {}) do
				if entry.role == "Hunter" and entry.alive ~= false then
					local other = Players:GetPlayerByUserId(entry.userId)
					local otherRoot = other and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
					if otherRoot then nearest = math.min(nearest, (otherRoot.Position - root.Position).Magnitude) end
				end
			end
			if nearest < range then target = 1 - nearest / range end
		end
	end
	self.danger = (self.danger or 0) + (target - (self.danger or 0)) * 0.4
	for _, frame in ipairs(self.dangerFrames or {}) do
		frame.Visible = self.danger > 0.03
		frame.BackgroundTransparency = 1 - math.min(0.7, self.danger * 0.75)
	end
end

function EffectsController:_countdown()
	local state = self.ctx.State
	if not state.endsAt or (state.phase ~= "Active" and state.phase ~= "HeadStart") then
		return
	end
	local seconds = math.ceil(state.endsAt - workspace:GetServerTimeNow())
	local threshold = state.phase == "HeadStart" and 3 or 5
	if seconds < 1 or seconds > threshold then
		return
	end
	local key = tostring(state.roundId) .. state.phase .. tostring(seconds)
	if self.countdownKey == key then
		return
	end
	self.countdownKey = key
	self:_sound("Countdown", 0.25)
	self:_banner(tostring(seconds), state.phase == "HeadStart" and CYAN or CORAL, 0.35, true)
end

function EffectsController:OnState(state)
	local previousPhase = self.phase
	local changedRound = self.roundId ~= state.roundId
	if changedRound then
		self.countdownKey = nil
		self.finalShown = false
		self.lastRunnerShown = false
		self.participated = false
	end
	if state.phase == "HeadStart" or state.phase == "Active" then
		for _, entry in ipairs(state.players or {}) do
			if entry.userId == self.player.UserId and (entry.role == "Runner" or entry.role == "Hunter") then
				self.participated = true
				break
			end
		end
	end
	if state.phase == "Active" and previousPhase == "HeadStart" then
		self:_banner("CHASE ON", CYAN, 0.7, false)
		self:_pulse(CYAN, 0.5)
	end
	if state.phase == "Active" and state.lastRunner and not self.lastRunnerShown then
		self.lastRunnerShown = true
		self:_banner("LAST RUNNER STANDING", CORAL, 1.1, false)
		self:_pulse(CORAL, 0.55)
		self:_sound("Final", 0.3)
	end
	if state.phase == "Active" and state.finalChase and not self.finalShown then
		self.finalShown = true
		self:_banner(state.lastRunner and "LAST RUNNER" or "FINAL CHASE", CORAL, 1.1, false)
		self:_pulse(CORAL, 0.7)
		self:_sound("Final", 0.4)
	end
	if state.phase == "Results" and (previousPhase ~= "Results" or changedRound) then
		local winner = table.find(state.winners or {}, self.player.UserId) ~= nil
		if winner and not state.practice then
			self:_pulse(GOLD, 0.75)
			self:_confetti(GOLD)
			self:_sound("Win", 0.5)
		elseif self.participated and not state.practice then
			self:_sound("Lose", 0.35)
		end
	end
	self.phase = state.phase
	self.roundId = state.roundId
end

function EffectsController:OnCharacter(character)
	if self.character == character then return end
	if self.landingConnection then self.landingConnection:Disconnect() self.landingConnection = nil end
	self.character = character
	self.airborneAt = nil
	if not character then return end
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or self.destroyed or self.character ~= character then return end
		self.landingConnection = humanoid.StateChanged:Connect(function(_, nextState)
			if nextState == Enum.HumanoidStateType.Freefall then
				self.airborneAt = os.clock()
			elseif nextState == Enum.HumanoidStateType.Landed then
				local duration = self.airborneAt and os.clock() - self.airborneAt or 0
				self.airborneAt = nil
				if duration >= 0.2 and humanoid.Health > 0 and not character:GetAttribute("Vaulting") then
					self:_sound("Land", math.min(0.28, 0.12 + duration * 0.06))
					if duration >= 0.35 then self:_dust(duration >= 0.7) end
					if not self:_settings().reducedMotion and self:_settings().cameraShake ~= false then self:_pulse(WHITE, 0.12) end
				end
			elseif nextState == Enum.HumanoidStateType.Dead or nextState == Enum.HumanoidStateType.Seated then
				self.airborneAt = nil
			end
		end)
	end)
end

function EffectsController:OnProfile(_profile)
	self:_music()
	if self:_settings().sfx == false then
		for sound in pairs(self.sounds) do
			sound:Stop()
			sound:Destroy()
		end
		table.clear(self.sounds)
		if self.sprintSound then
			self.sprintSound:Pause()
		end
	end
	if self:_settings().reducedMotion and self.worldEffects then
		self.worldEffects:ClearAllChildren()
	end
end

function EffectsController:OnNotice(notice)
	if notice.kind == "tag" then
		local now = os.clock()
		if now - self.lastTag < 0.07 then
			return
		end
		self.lastTag = now
		local bloom = notice.action == "tag_bloom"
		if notice.action == "tag_spark" or bloom then
			self:_worldBurst(notice.position, bloom and CORAL or CYAN, bloom)
		elseif notice.action == "tag_star" then
			self:_worldBurst(notice.position, GOLD, true)
		elseif notice.action == "tag_confetti" then
			self:_worldBurst(notice.position, GOLD, true, {GOLD, CORAL, CYAN, WHITE, Color3.fromRGB(150, 110, 255), Color3.fromRGB(110, 235, 150)})
		end
		if notice.userId == self.player.UserId then
			self:_pulse(CYAN, 0.65)
			self:_sound("Tag", 0.45)
		else
			local root = self.player.Character and self.player.Character:FindFirstChild("HumanoidRootPart")
			local caught = notice.victimUserId == self.player.UserId
				or (root and typeof(notice.position) == "Vector3" and (root.Position - notice.position).Magnitude < 3)
			if caught then
				self:_pulse(CORAL, 0.6)
				self:_sound("Tag", 0.35)
			end
		end
	elseif notice.kind == "level" or notice.kind == "unlock" then
		self:_pulse(GOLD, 0.6)
		self:_confetti(GOLD)
		self:_sound("Level", 0.4)
	elseif notice.kind == "purchase" and notice.success == true then
		self:_pulse(CYAN, 0.45)
		self:_sound("Purchase", 0.3)
	elseif notice.kind == "ability" and notice.success ~= false then
		if notice.action == "Slide" or notice.action == "Vault" then
			self:_sound(notice.action, 0.25)
			self:_dust(true)
		end
	elseif notice.kind == "pickup" then
		-- The pitch climbs with the stack so a coin run feels like a combo.
		local count = tonumber(notice.count) or 1
		self:_sound("Pickup", 0.4, 1 + math.min(count, 25) * 0.015)
		self:_worldBurst(notice.position, GOLD, true)
	elseif notice.kind == "closecall" then
		self:_banner("CLOSE CALL!", GOLD, 0.8, false)
		self:_pulse(GOLD, 0.45)
		self:_sound("CloseCall", 0.4)
	elseif notice.kind == "found" then
		self:_pulse(CORAL, 0.5)
		self:_sound("Found", 0.5)
	elseif notice.kind == "reveal" then
		self:_sound("Reveal", 0.3)
		if notice.userId == self.player.UserId then
			self:_banner("YOU WERE FOUND!", CORAL, 0.9, false)
			self:_pulse(CORAL, 0.6)
		end
	elseif notice.kind == "hide" then
		if notice.state == "in" then
			self:_sound("Hide", 0.25)
			self:_pulse(GOLD, 0.2)
		end
	elseif notice.kind == "scan" then
		self:_sound("Scan", 0.45)
		self:_pulse(CYAN, 0.5)
	end
end

function EffectsController:Start()
	if self.started then
		return
	end
	self.started = true
	self.gui = Instance.new("ScreenGui")
	self.gui.Name = "CatchFeedback"
	self.gui.IgnoreGuiInset = true
	self.gui.ResetOnSpawn = false
	self.gui.DisplayOrder = 25
	self.gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self.gui.Parent = self.player:WaitForChild("PlayerGui")
	self:_buildDanger()
	self.worldEffects = Instance.new("Folder")
	self.worldEffects.Name = "CatchLocalEffects_" .. self.player.UserId
	self.worldEffects.Parent = workspace
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self.elapsed += dt
		if self.elapsed >= 0.1 then
			self.elapsed = 0
			self:_countdown()
			self:_sprintAudio()
			self:_dangerTick()
		end
	end))
	self:_music()
	self:OnState(self.ctx.State)
end

function EffectsController:Destroy()
	self.destroyed = true
	if self.landingConnection then self.landingConnection:Disconnect() self.landingConnection = nil end
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	table.clear(self.connections)
	for sound in pairs(self.sounds) do
		sound:Destroy()
	end
	table.clear(self.sounds)
	if self.music then
		self.music:Destroy()
	end
	if self.ambience then
		self.ambience:Destroy()
	end
	if self.sprintSound then
		self.sprintSound:Destroy()
	end
	if self.gui then
		self.gui:Destroy()
	end
	if self.worldEffects then
		self.worldEffects:Destroy()
	end
end

return EffectsController
