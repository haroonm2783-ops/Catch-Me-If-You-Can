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
	Vault = { path = "action_jump.mp3", pitch = 1.08, gain = 0.5 },
	Tag = { path = "electronicpingshort.wav", pitch = 1.25, gain = 0.55 },
	Win = { path = "electronicpingshort.wav", pitch = 1.4, gain = 0.6 },
	Lose = { path = "electronicpingshort.wav", pitch = 0.72, gain = 0.35 },
	Level = { path = "electronicpingshort.wav", pitch = 1.5, gain = 0.55 },
	Countdown = { path = "electronicpingshort.wav", pitch = 1, gain = 0.45 },
	Final = { path = "electronicpingshort.wav", pitch = 0.85, gain = 0.5 },
	Purchase = { path = "electronicpingshort.wav", pitch = 1.3, gain = 0.45 },
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

function EffectsController:_play(sound, predicate)
	local source = sound.SoundId
	if self.audioAvailability[source] == false or self.pendingSounds[sound] then
		return
	end
	local function playIfAllowed()
		if not self.destroyed and sound.Parent and self:_settings().sfx ~= false
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

function EffectsController:_sound(name, volume)
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
	sound.PlaybackSpeed = pitch
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

function EffectsController:_music()
	if not self.music then
		local id = tonumber((self.ctx.Config.Audio or {}).Music)
		if not id or id <= 0 or id == math.huge or id ~= math.floor(id) then
			return
		end
		self.music = Instance.new("Sound")
		self.music.Name = "CatchMusic"
		self.music.SoundId = "rbxassetid://" .. tostring(id)
		self.music.Looped = true
		self.music.Volume = 0.18
		self.music.Parent = SoundService
	end
	if self:_settings().music == false then
		self.music:Pause()
	elseif not self.music.IsPlaying then
		if self.music.TimePosition > 0 then
			self.music:Resume()
		else
			self.music:Play()
		end
	end
end

function EffectsController:_sprintAudio()
	local character = self.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local active = self:_settings().sfx ~= false and character
		and character:GetAttribute("Sprinting") == true and humanoid
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
	label.Position = UDim2.fromScale(0.5, 0.32)
	label.Size = UDim2.new(0.85, 0, 0, large and 110 or 42)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = color
	label.TextSize = large and 82 or 25
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

function EffectsController:_worldBurst(position, color, bloom)
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
		spark.Color = index % 3 == 0 and WHITE or color
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
		end
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
	self.worldEffects = Instance.new("Folder")
	self.worldEffects.Name = "CatchLocalEffects_" .. self.player.UserId
	self.worldEffects.Parent = workspace
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self.elapsed += dt
		if self.elapsed >= 0.1 then
			self.elapsed = 0
			self:_countdown()
			self:_sprintAudio()
		end
	end))
	self:_music()
	self:OnState(self.ctx.State)
end

function EffectsController:Destroy()
	self.destroyed = true
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
