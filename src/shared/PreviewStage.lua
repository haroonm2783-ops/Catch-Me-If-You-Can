-- The Shop / Locker showroom. One stage owns one preview model inside a ViewportFrame's WorldModel and drives:
--   skin, bundle   a gently posed avatar framed head to toe (framing comes from the model's real bounds)
--   mask           a close-up of the head and everything on it
--   emote, victory the emote's pose function playing on the preview avatar, looping, with a replay
--   trail          the avatar running laps on a short circular track with the trail drawn behind it
--   tag            the catch burst, replayable
-- Viewports do not draw Trail or ParticleEmitter objects, so trails are shown with Trails.Emulator, which is fed the
-- same definition table that builds the live trail. The camera orbits the model; drag, buttons and replay call
-- Rotate / SetAngle / Replay. Cosmetic only; nothing here reaches the server.
local Poses = require(script.Parent:WaitForChild("Poses"))
local Emotes = require(script.Parent:WaitForChild("Emotes"))
local Trails = require(script.Parent:WaitForChild("Trails"))

local PreviewStage = {}
PreviewStage.__index = PreviewStage

local A = Poses.Angles
local FLOOR = -3.0               -- the avatar's feet when the root sits at the origin
local TRACK_RADIUS = 3.1
local RUN_SPEED = 9.5
local IDLE = {LeftShoulder = A(0, 0, -5), RightShoulder = A(0, 0, 5)}

-- Catch-burst colors, mirroring EffectsController (a test keeps this list in step with the catalog).
local BURST = {
	tag_spark = {{81, 231, 240}, {255, 255, 255}},
	tag_bloom = {{255, 128, 174}, {255, 220, 235}},
	tag_star = {{255, 208, 64}, {255, 255, 255}},
	tag_confetti = {{255, 208, 64}, {255, 128, 120}, {81, 231, 240}, {255, 255, 255}, {150, 110, 255}, {110, 235, 150}},
}
PreviewStage.BurstPalettes = BURST

function PreviewStage.Kind(item)
	if not item then return "skin" end
	local category = item.category
	if category == "masks" then return "mask"
	elseif category == "trails" then return "trail"
	elseif category == "emotes" or category == "victories" then return "emote"
	elseif category == "tagEffects" then return "tag" end
	return "skin"
end

-- Where an avatar's feet are (a Y relative to its root); falls back to the standard R15 value.
function PreviewStage.FloorOf(rig)
	local feet = {}
	for _, name in ipairs({"LeftFoot", "RightFoot", "Left Leg", "Right Leg"}) do
		local foot = rig:FindFirstChild(name)
		if foot and foot:IsA("BasePart") then table.insert(feet, foot.CFrame.Position.Y - foot.Size.Y / 2) end
	end
	if #feet > 0 then return math.min(table.unpack(feet)) end
	return FLOOR
end

-- World-space bounds of the visible parts of a model (optionally only what is attached to the head).
local function attachedToHead(part)
	if part.Name == "Head" then return true end
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("WeldConstraint") or child:IsA("Weld") then
			local other = child.Part0 == part and child.Part1 or child.Part0
			if other and other.Name == "Head" then return true end
		end
	end
	return false
end

function PreviewStage.Bounds(rig, headOnly)
	local lo = Vector3.new(math.huge, math.huge, math.huge)
	local hi = Vector3.new(-math.huge, -math.huge, -math.huge)
	local found = false
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 0.98 and part.Name ~= "HumanoidRootPart" and (not headOnly or attachedToHead(part)) then
			local half = part.Size / 2
			for sx = -1, 1, 2 do
				for sy = -1, 1, 2 do
					for sz = -1, 1, 2 do
						local corner = part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz))
						lo = Vector3.new(math.min(lo.X, corner.X), math.min(lo.Y, corner.Y), math.min(lo.Z, corner.Z))
						hi = Vector3.new(math.max(hi.X, corner.X), math.max(hi.Y, corner.Y), math.max(hi.Z, corner.Z))
						found = true
					end
				end
			end
		end
	end
	if not found then return Vector3.new(-2, -3, -1), Vector3.new(2, 3, 1) end
	return lo, hi
end

local function widen(lo, hi, point)
	return Vector3.new(math.min(lo.X, point.X), math.min(lo.Y, point.Y), math.min(lo.Z, point.Z)),
		Vector3.new(math.max(hi.X, point.X), math.max(hi.Y, point.Y), math.max(hi.Z, point.Z))
end

-- Camera distance that fits bounds (lo, hi) in a viewport of the given aspect (width / height) with a margin.
function PreviewStage.Fit(lo, hi, fov, aspect, margin)
	local halfHeight = (hi.Y - lo.Y) / 2
	local halfWidth = math.max(hi.X - lo.X, hi.Z - lo.Z) / 2
	local tanV = math.tan(math.rad(fov) / 2)
	local tanH = tanV * math.max(0.3, aspect)
	return margin * math.max(halfHeight / tanV, halfWidth / tanH) + halfWidth * 0.7
end

-- opts: world (parent of the model and effects), camera, rig, kind, id, motion (false = hold a still key pose),
--       aspect (viewport width / height), fov, origin (Vector3: where in the world the stage stands; default the origin),
--       realEffects (true when the stage lives in the real workspace, where the rig's own Trail and ParticleEmitter
--       objects draw: no emulation, just footprints and clearing on replay)
function PreviewStage.new(opts)
	local self = setmetatable({
		world = opts.world, camera = opts.camera, rig = opts.rig, kind = opts.kind or "skin", id = opts.id,
		motion = opts.motion ~= false, aspect = opts.aspect or 0.9, fov = opts.fov or 38,
		time = 0, angle = opts.angle or 0.18, targetAngle = opts.angle or 0.18, burstClock = 0, bursts = {},
	}, PreviewStage)
	self.pose = Poses.Preview(self.rig)
	self.root = self.pose and self.pose.restRoot or CFrame.new()
	self.realEffects = opts.realEffects == true
	self.origin = opts.origin or Vector3.zero
	-- Self-test: a pose must actually move the avatar. If it cannot (a rig without joints), say so instead of
	-- silently showing a frozen model.
	if not self.pose then
		self.problem = "the avatar has no HumanoidRootPart to pose"
	else
		local probe = self.rig:FindFirstChild("RightHand") or self.rig:FindFirstChild("Right Arm")
		if probe then
			self.pose:Set({}, self.root)
			local before = probe.CFrame.Position
			self.pose:Set({RightShoulder = A(0, 0, 90), LeftShoulder = A(0, 0, -90)}, self.root)
			local moved = (probe.CFrame.Position - before).Magnitude
			self.pose:Set({}, self.root)
			if moved < 0.5 then self.problem = "the avatar's joints do not respond to poses" end
		end
	end
	-- The floor is where this avatar's feet actually are (taller or shorter bodies differ).
	self.floor = PreviewStage.FloorOf(self.rig)
	self.pitch, self.margin = 0.08, 1.14
	local lo, hi
	if self.kind == "mask" then
		lo, hi = PreviewStage.Bounds(self.rig, true)
		self.fov, self.margin, self.pitch = 30, 1.5, 0.05
	elseif self.kind == "emote" and self.pose and Emotes.Has(self.id) then
		lo, hi = PreviewStage.Bounds(self.rig)
		-- Frame everything the emote does: flips, floor faints and wide arms.
		local def = Emotes.Defs[self.id]
		local samples = 20
		for step = 0, samples do
			self.pose:Set(Emotes.Sample(self.id, def.duration * step / samples, true) or {}, self.root)
			local slo, shi = PreviewStage.Bounds(self.rig)
			lo, hi = widen(lo, hi, slo)
			lo, hi = widen(lo, hi, shi)
		end
		self.pose:Set(IDLE, self.root)
		self.margin = 1.05
	elseif self.kind == "trail" then
		lo, hi = PreviewStage.Bounds(self.rig)
		lo = Vector3.new(-TRACK_RADIUS - 1.2, math.min(lo.Y, self.floor - 0.2), -TRACK_RADIUS - 1.2)
		hi = Vector3.new(TRACK_RADIUS + 1.2, hi.Y + 0.4, TRACK_RADIUS + 1.2)
		self.pitch, self.margin, self.fov = 0.42, 0.78, 42
	else
		lo, hi = PreviewStage.Bounds(self.rig)
	end
	self.bounds = {lo, hi}
	self.center = (lo + hi) / 2
	if self.kind == "trail" then self.center = Vector3.new(0, (lo.Y + hi.Y) / 2 - 0.4, 0) end
	self.focus = self.center + self.origin
	self.distance = PreviewStage.Fit(lo, hi, self.fov, self.aspect, self.margin)
	if self.camera then self.camera.FieldOfView = self.fov end
	if self.kind == "trail" and Trails.Has(self.id) then
		if self.realEffects then
			local def = Trails.Defs[self.id]
			if def.footprints then self.footprints = Trails.Footprints.new(self.world, def.footprints) end
		else
			self.emulator = Trails.Emulator.new(self.id, self.world)
			if self.emulator then self.emulator.camera = Vector3.new(0, 0, 1) end
		end
	end
	self:Replay()
	return self
end

function PreviewStage:_place(clock)
	-- Poses and the runner are a pure function of the stage clock, so Replay is exact and tests are deterministic.
	if not self.pose then return end
	if self.kind == "emote" and Emotes.Has(self.id) then
		local at = self.motion and clock or Emotes.Defs[self.id].duration * 0.4
		self.pose:Set(Emotes.Sample(self.id, at, true) or {}, CFrame.new(self.origin) * self.root)
	elseif self.kind == "trail" then
		local angular = RUN_SPEED / TRACK_RADIUS
		local theta = clock * angular
		local position = Vector3.new(math.sin(theta) * TRACK_RADIUS, 0, -math.cos(theta) * TRACK_RADIUS) + self.origin
		local tangent = Vector3.new(math.cos(theta), 0, math.sin(theta))
		local frame = CFrame.lookAt(position, position + tangent)
		self.pose:Set(Poses.Run(clock), frame)
		self.runnerFrame, self.runnerVelocity = frame, tangent * RUN_SPEED
	else
		local sway = self.motion and math.sin(clock * 1.4) * 1.2 or 0
		self.pose:Set({LeftShoulder = A(0, 0, -5 - sway), RightShoulder = A(0, 0, 5 + sway), Neck = A(0, sway * 2, 0)}, CFrame.new(self.origin) * self.root)
	end
end

function PreviewStage:_burst(at)
	at = at + self.origin
	local palette = BURST[self.id] or {{255, 255, 255}}
	for index = 1, 22 do
		local part = Instance.new("Part")
		part.Name = "Burst" .. index
		part.Shape = Enum.PartType.Ball
		part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
		part.Material = Enum.Material.SmoothPlastic
		local color = palette[(index % #palette) + 1]
		part.Color = Color3.fromRGB(color[1], color[2], color[3])
		part.Size = Vector3.new(0.3, 0.3, 0.3)
		local angle = index * 2.399
		local lift = ((index * 37) % 11) / 10
		local velocity = Vector3.new(math.cos(angle), 0.4 + lift, math.sin(angle)) * (3 + (index % 5))
		part.CFrame = CFrame.new(at)
		part.Parent = self.world
		table.insert(self.bursts, {part = part, born = self.time, velocity = velocity, origin = at})
	end
end

function PreviewStage:_updateBursts()
	for index = #self.bursts, 1, -1 do
		local burst = self.bursts[index]
		local age = self.time - burst.born
		if age > 0.9 then
			burst.part:Destroy()
			table.remove(self.bursts, index)
		else
			local position = burst.origin + burst.velocity * age + Vector3.new(0, -4 * age * age, 0)
			burst.part.CFrame = CFrame.new(position)
			burst.part.Transparency = math.clamp((age - 0.35) / 0.55, 0, 1)
			local size = 0.34 * (1 - age / 1.2)
			burst.part.Size = Vector3.new(size, size, size)
		end
	end
end

-- Start the demonstration over: the emote restarts, the runner returns to the start and the trail clears.
function PreviewStage:Replay()
	self.time = 0
	self.burstClock = 0
	for _, burst in ipairs(self.bursts) do burst.part:Destroy() end
	table.clear(self.bursts)
	if self.emulator then self.emulator:Reset() end
	if self.footprints then self.footprints:Clear() end
	if self.realEffects then
		-- Real engine effects keep their own history; clear it so the lap truly starts over.
		for _, item in ipairs(self.rig:GetDescendants()) do
			if item:IsA("Trail") or item:IsA("ParticleEmitter") then pcall(function() item:Clear() end) end
		end
	end
	self.replays = (self.replays or 0) + 1
	self:_place(0)
	if self.kind == "trail" and self.emulator and not self.motion then
		-- Reduced motion: show the finished trail once, then hold it.
		for step = 1, 40 do
			self.time = step / 30
			self:_place(self.time)
			self.emulator:Step(1 / 30, self.runnerFrame, self.runnerVelocity, self.floor + self.origin.Y)
		end
	elseif self.kind == "tag" then
		self:_burst(Vector3.new(0, 0.5, 0))
	end
	self:_aim()
end

function PreviewStage:_aim()
	if not self.camera then return end
	local sway = self.motion and self.kind ~= "trail" and self.kind ~= "emote"
	local a = self.angle + (sway and math.sin(self.time * 0.38) * 0.12 or 0)
	local direction = Vector3.new(math.sin(a) * math.cos(self.pitch), math.sin(self.pitch), -math.cos(a) * math.cos(self.pitch))
	self.camera.CFrame = CFrame.lookAt(self.focus + direction * self.distance, self.focus)
	if self.emulator then self.emulator.camera = self.camera.CFrame.LookVector end
end

function PreviewStage:Update(dt)
	dt = math.clamp(dt, 0, 0.1)
	-- Ease toward the requested angle so the arrow buttons turn the model smoothly.
	local delta = self.targetAngle - self.angle
	if math.abs(delta) > 0.001 then self.angle += delta * math.min(1, dt * 10) else self.angle = self.targetAngle end
	if self.motion then
		self.time += dt
		self:_place(self.time)
		if self.emulator and self.runnerFrame then self.emulator:Step(dt, self.runnerFrame, self.runnerVelocity, self.floor + self.origin.Y) end
		if self.footprints and self.runnerFrame then
			local at = self.runnerFrame.Position
			self.footprints:Step(dt, Vector3.new(at.X, self.floor + self.origin.Y + 0.04, at.Z), self.runnerFrame.LookVector, self.runnerVelocity.Magnitude)
		end
		if self.kind == "tag" then
			self.burstClock += dt
			if self.burstClock > 2.6 then self.burstClock = 0 self:_burst(Vector3.new(0, 0.5, 0)) end
			self:_updateBursts()
		end
	elseif self.kind == "tag" then
		self:_updateBursts()
	end
	self:_aim()
end

-- Reduced motion (or back to full motion) restarts the demonstration in its still or animated form.
function PreviewStage:SetMotion(on)
	on = on ~= false
	if on == self.motion then return end
	self.motion = on
	self:Replay()
end

function PreviewStage:Rotate(delta) self.targetAngle += delta end
function PreviewStage:SetAngle(angle) self.angle, self.targetAngle = angle, angle self:_aim() end
function PreviewStage:Front() self.targetAngle = 0 end
function PreviewStage:Back() self.targetAngle = math.pi end

function PreviewStage:Destroy()
	for _, burst in ipairs(self.bursts) do burst.part:Destroy() end
	table.clear(self.bursts)
	if self.footprints then self.footprints:Destroy() self.footprints = nil end
	if self.emulator then self.emulator:Destroy() self.emulator = nil end
end

return PreviewStage
