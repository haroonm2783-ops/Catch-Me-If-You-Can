-- Sprint trails. One definition table per trail drives BOTH renderers, so what you preview is what you wear:
--
--   Trails.Populate(mount, id)       real Trail + ParticleEmitter instances for the live character
--   Trails.Emulator.new(id, parent)  the same ribbons and particles drawn with plain parts, for ViewportFrame
--                                    previews (viewports do not draw Trails or ParticleEmitters)
--   Trails.Footprints.new(...)       stamped gold footprints (parts), used live by the client and in previews
--
-- Colors and numbers are plain data: {t, r, g, b} and {t, value} keypoints, ribbons are {x, y, hw ...}.
-- Budgets (enforced by tests): at most 3 ribbons and 2 emitters per trail, at most 20 particles per second.
-- Only built-in particle textures are used, so there are no asset IDs to configure.
local Trails = {}

local TEXTURES = {
	sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
}
Trails.Textures = TEXTURES

local defs = {}

defs.trail_cyan = {
	name = "Aqua Dash",
	ribbons = {{x = 0, y = 0, hw = 0.5, lifetime = 0.33,
		color = {{0, 59, 236, 228}, {1, 85, 123, 239}}, alpha = {{0, 0.3}, {1, 1}}, width = {{0, 0.72}, {1, 0}}, emission = 0.4}},
}

defs.trail_streaks = {
	name = "Speed Streaks",
	ribbons = {
		{x = 0, y = 0.5, hw = 0.17, lifetime = 0.5, color = {{0, 255, 96, 96}, {1, 255, 150, 80}}, alpha = {{0, 0.1}, {1, 1}}, width = {{0, 1}, {1, 0}}, emission = 0.3},
		{x = 0, y = 0, hw = 0.17, lifetime = 0.58, color = {{0, 255, 218, 70}, {1, 255, 176, 60}}, alpha = {{0, 0.1}, {1, 1}}, width = {{0, 1}, {1, 0}}, emission = 0.3},
		{x = 0, y = -0.5, hw = 0.17, lifetime = 0.5, color = {{0, 80, 196, 255}, {1, 110, 120, 255}}, alpha = {{0, 0.1}, {1, 1}}, width = {{0, 1}, {1, 0}}, emission = 0.3},
	},
}

defs.trail_flame = {
	name = "Hot Foot",
	ribbons = {{x = 0, y = 0, hw = 0.5, lifetime = 0.34,
		color = {{0, 255, 226, 100}, {0.5, 255, 140, 40}, {1, 220, 50, 30}}, alpha = {{0, 0.15}, {1, 1}}, width = {{0, 0.8}, {1, 0}}, emission = 0.6}},
	emitters = {{name = "Embers", texture = "fire", rate = 10, life = {0.4, 0.8}, speed = {1, 3}, spread = 25, accel = {0, 4, 0},
		size = {{0, 0.7}, {1, 0}}, color = {{0, 255, 220, 90}, {1, 240, 70, 30}}, alpha = {{0, 0.2}, {1, 1}}, emission = 0.6}},
}

defs.trail_candy = {
	name = "Candy Swirl",
	ribbons = {
		{x = -0.2, y = 0.12, hw = 0.3, lifetime = 0.42, color = {{0, 255, 140, 200}, {1, 255, 190, 230}}, alpha = {{0, 0.15}, {1, 1}}, width = {{0, 0.9}, {1, 0}}, emission = 0.25},
		{x = 0.2, y = -0.12, hw = 0.3, lifetime = 0.42, color = {{0, 120, 235, 200}, {1, 190, 255, 235}}, alpha = {{0, 0.15}, {1, 1}}, width = {{0, 0.9}, {1, 0}}, emission = 0.25},
	},
	emitters = {{name = "Sprinkles", texture = "sparkles", rate = 9, life = {0.7, 1.2}, speed = {0.6, 2}, spread = 70, accel = {0, -1.5, 0},
		size = {{0, 0.38}, {1, 0}}, color = {{0, 255, 140, 200}, {0.5, 255, 255, 255}, {1, 120, 235, 200}}, alpha = {{0, 0}, {1, 1}}, emission = 0.4}},
}

defs.trail_rainbow = {
	name = "Prism Streak",
	ribbons = {{x = 0, y = 0, hw = 0.5, lifetime = 0.4,
		color = {{0, 255, 90, 120}, {0.35, 255, 220, 90}, {0.7, 90, 240, 160}, {1, 100, 150, 255}}, alpha = {{0, 0.25}, {1, 1}}, width = {{0, 0.8}, {1, 0}}, emission = 0.4}},
}

defs.trail_sunset = {
	name = "Sunset Glide",
	ribbons = {{x = 0, y = 0, hw = 0.5, lifetime = 0.38,
		color = {{0, 255, 196, 91}, {1, 246, 86, 135}}, alpha = {{0, 0.25}, {1, 1}}, width = {{0, 0.8}, {1, 0}}, emission = 0.4}},
	emitters = {{name = "Glints", texture = "sparkles", rate = 6, life = {0.6, 1.0}, speed = {0.5, 1.5}, spread = 60, accel = {0, 1, 0},
		size = {{0, 0.4}, {1, 0}}, color = {{0, 255, 220, 140}, {1, 255, 120, 160}}, alpha = {{0, 0.1}, {1, 1}}, emission = 0.5}},
}

defs.trail_sparks = {
	name = "Electric Sparks",
	ribbons = {{x = 0, y = 0, hw = 0.32, lifetime = 0.3,
		color = {{0, 255, 250, 190}, {0.5, 130, 200, 255}, {1, 90, 120, 255}}, alpha = {{0, 0.1}, {0.5, 0.4}, {1, 1}}, width = {{0, 1}, {1, 0}}, emission = 0.7}},
	emitters = {
		{name = "Sparks", texture = "sparkles", rate = 16, life = {0.2, 0.4}, speed = {6, 12}, spread = 80, accel = {0, -10, 0},
			size = {{0, 0.5}, {1, 0}}, color = {{0, 255, 255, 255}, {1, 255, 230, 90}}, alpha = {{0, 0}, {1, 1}}, emission = 0.9},
		{name = "Arcs", texture = "sparkles", rate = 4, life = {0.3, 0.5}, speed = {1, 3}, spread = 120, accel = {0, 0, 0},
			size = {{0, 0.6}, {0.5, 0.25}, {1, 0}}, color = {{0, 140, 200, 255}, {1, 255, 255, 255}}, alpha = {{0, 0.2}, {1, 1}}, emission = 1},
	},
}

defs.trail_shadow = {
	name = "Shadow Smoke",
	ribbons = {{x = 0, y = 0, hw = 0.5, lifetime = 0.45,
		color = {{0, 40, 28, 66}, {1, 90, 60, 140}}, alpha = {{0, 0.35}, {1, 1}}, width = {{0, 0.8}, {1, 0.2}}, emission = 0}},
	emitters = {{name = "Smoke", texture = "smoke", rate = 11, life = {0.6, 1.0}, speed = {0.5, 1.6}, spread = 40, accel = {0, 0.8, 0},
		size = {{0, 1.0}, {1, 2.6}}, color = {{0, 40, 30, 62}, {1, 96, 66, 150}}, alpha = {{0, 0.35}, {1, 1}}, emission = 0, rot = {0, 360}}},
}

defs.trail_stardust = {
	name = "Cosmic Stardust",
	ribbons = {{x = 0, y = 0, hw = 0.3, lifetime = 0.5,
		color = {{0, 110, 190, 255}, {0.5, 170, 110, 255}, {1, 255, 130, 220}}, alpha = {{0, 0.3}, {1, 1}}, width = {{0, 1}, {1, 0}}, emission = 0.6}},
	emitters = {
		{name = "Stars", texture = "sparkles", rate = 14, life = {0.8, 1.4}, speed = {0.5, 2}, spread = 90, accel = {0, 0.4, 0},
			size = {{0, 0}, {0.25, 0.5}, {0.6, 0.3}, {1, 0}}, color = {{0, 150, 220, 255}, {0.5, 255, 255, 255}, {1, 255, 150, 230}}, alpha = {{0, 0}, {1, 1}}, emission = 0.9},
		{name = "Nebula", texture = "smoke", rate = 4, life = {0.8, 1.2}, speed = {0.2, 0.8}, spread = 60, accel = {0, 0, 0},
			size = {{0, 0.8}, {1, 2.0}}, color = {{0, 90, 80, 220}, {1, 200, 90, 220}}, alpha = {{0, 0.6}, {1, 1}}, emission = 0.5, rot = {0, 360}},
	},
}

defs.trail_gold = {
	name = "Golden Footsteps",
	ribbons = {{x = 0, y = -0.3, hw = 0.3, lifetime = 0.3,
		color = {{0, 255, 226, 120}, {1, 255, 180, 50}}, alpha = {{0, 0.5}, {1, 1}}, width = {{0, 0.8}, {1, 0}}, emission = 0.5}},
	emitters = {{name = "Glitter", texture = "sparkles", rate = 8, life = {0.6, 1.1}, speed = {0.5, 1.8}, spread = 70, accel = {0, 1.2, 0},
		size = {{0, 0.45}, {1, 0}}, color = {{0, 255, 240, 160}, {1, 255, 190, 50}}, alpha = {{0, 0}, {1, 1}}, emission = 0.7}},
	footprints = {color = {255, 200, 60}, rim = {255, 238, 150}, life = 1.8, stride = 3.4},
}

Trails.Defs = defs
Trails.Order = {"trail_cyan", "trail_streaks", "trail_flame", "trail_candy", "trail_rainbow", "trail_sunset", "trail_sparks", "trail_shadow", "trail_stardust", "trail_gold"}
function Trails.Has(id) return defs[id] ~= nil end

-- Total particles per second a trail may emit (used by the performance budget test).
function Trails.ParticleRate(id)
	local total = 0
	for _, emitter in ipairs(defs[id] and defs[id].emitters or {}) do total += emitter.rate end
	return total
end

-- ---------------------------------------------------------------------------------------
-- Sampling plain keypoint tables (used by the emulator; the real renderer builds engine sequences from the same data)
-- ---------------------------------------------------------------------------------------
local function sampleNumbers(points, t)
	if t <= points[1][1] then return points[1][2] end
	for i = 2, #points do
		local b = points[i]
		if t <= b[1] then
			local a = points[i - 1]
			local span = b[1] - a[1]
			local f = span > 0 and (t - a[1]) / span or 1
			return a[2] + (b[2] - a[2]) * f
		end
	end
	return points[#points][2]
end

local function sampleColor(points, t)
	if t <= points[1][1] then return Color3.fromRGB(points[1][2], points[1][3], points[1][4]) end
	for i = 2, #points do
		local b = points[i]
		if t <= b[1] then
			local a = points[i - 1]
			local span = b[1] - a[1]
			local f = span > 0 and (t - a[1]) / span or 1
			return Color3.new((a[2] + (b[2] - a[2]) * f) / 255, (a[3] + (b[3] - a[3]) * f) / 255, (a[4] + (b[4] - a[4]) * f) / 255)
		end
	end
	local last = points[#points]
	return Color3.fromRGB(last[2], last[3], last[4])
end
Trails.SampleNumbers, Trails.SampleColor = sampleNumbers, sampleColor

local function colorSequence(points)
	local keys = {}
	for _, p in ipairs(points) do table.insert(keys, ColorSequenceKeypoint.new(p[1], Color3.fromRGB(p[2], p[3], p[4]))) end
	return ColorSequence.new(keys)
end
local function numberSequence(points)
	local keys = {}
	for _, p in ipairs(points) do table.insert(keys, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(keys)
end

-- ---------------------------------------------------------------------------------------
-- Live instances
-- ---------------------------------------------------------------------------------------
-- Builds the engine objects inside `mount` (a small massless part welded to the character's root).
-- Returns the list of created Trail / ParticleEmitter objects (all start disabled until `enabled` is true).
function Trails.Populate(mount, id, enabled)
	local def = defs[id]
	if not def then return {} end
	local created = {}
	for index, ribbon in ipairs(def.ribbons or {}) do
		local a, b = Instance.new("Attachment"), Instance.new("Attachment")
		a.Name, b.Name = "TrailA" .. index, "TrailB" .. index
		a.Position = Vector3.new(ribbon.x - ribbon.hw, ribbon.y, 0)
		b.Position = Vector3.new(ribbon.x + ribbon.hw, ribbon.y, 0)
		a.Parent, b.Parent = mount, mount
		local trail = Instance.new("Trail")
		trail.Name = index == 1 and id or (id .. "_" .. index)
		trail.Attachment0, trail.Attachment1 = a, b
		trail.Color = colorSequence(ribbon.color)
		trail.Transparency = numberSequence(ribbon.alpha)
		trail.WidthScale = numberSequence(ribbon.width)
		trail.Lifetime = ribbon.lifetime
		trail.MinLength = 0.08
		trail.FaceCamera = true
		trail.LightEmission = ribbon.emission or 0
		trail.Enabled = enabled == true
		trail.Parent = mount
		table.insert(created, trail)
	end
	for _, spec in ipairs(def.emitters or {}) do
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name = "Trail_" .. spec.name
		emitter.Texture = TEXTURES[spec.texture] or TEXTURES.sparkles
		emitter.Rate = spec.rate
		emitter.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
		emitter.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
		emitter.SpreadAngle = Vector2.new(spec.spread, spec.spread)
		emitter.Acceleration = Vector3.new(spec.accel[1], spec.accel[2], spec.accel[3])
		emitter.Size = numberSequence(spec.size)
		emitter.Color = colorSequence(spec.color)
		emitter.Transparency = numberSequence(spec.alpha)
		emitter.LightEmission = spec.emission or 0
		emitter.EmissionDirection = Enum.NormalId.Back
		emitter.LockedToPart = false
		if spec.rot then emitter.Rotation = NumberRange.new(spec.rot[1], spec.rot[2]) end
		emitter.Enabled = enabled == true
		emitter.Parent = mount
		table.insert(created, emitter)
	end
	return created
end

-- Turn every trail object under a CatchAppearance folder on or off (called while sprinting).
function Trails.SetActive(folder, active)
	local mount = folder and folder:FindFirstChild("TrailMount")
	if not mount then return end
	for _, effect in ipairs(mount:GetChildren()) do
		if (effect:IsA("Trail") or (effect:IsA("ParticleEmitter") and string.sub(effect.Name, 1, 6) == "Trail_")) and effect.Enabled ~= active then
			effect.Enabled = active
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Footprints (parts): a sole, a heel and three toes per print, fading out. Works anywhere parts do.
-- ---------------------------------------------------------------------------------------
local Footprints = {}
Footprints.__index = Footprints
Trails.Footprints = Footprints

local POOL = 8

local function printPart(container, name, size, color, shape)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.SmoothPlastic
	part.Shape = shape or Enum.PartType.Cylinder
	part.Size = size
	part.Color = color
	part.Transparency = 1
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.CFrame = CFrame.new(0, -500, 0)
	part.Parent = container
	return part
end

function Footprints.new(container, spec)
	local color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
	local rim = Color3.fromRGB(spec.rim[1], spec.rim[2], spec.rim[3])
	local folder = Instance.new("Folder")
	folder.Name = "CatchFootprints"
	folder.Parent = container
	local self = setmetatable({folder = folder, prints = {}, life = spec.life, stride = spec.stride, travelled = 0, side = 1, next = 1, clock = 0}, Footprints)
	for index = 1, POOL do
		-- A flat cylinder's axis is X; Size = (thickness, width, length) gives an oval lying on the floor after a 90-degree roll.
		table.insert(self.prints, {
			parts = {
				printPart(folder, "Sole" .. index, Vector3.new(0.06, 0.5, 0.86), color),
				printPart(folder, "Heel" .. index, Vector3.new(0.05, 0.36, 0.36), color),
				printPart(folder, "ToeA" .. index, Vector3.new(0.05, 0.16, 0.16), rim),
				printPart(folder, "ToeB" .. index, Vector3.new(0.05, 0.16, 0.16), rim),
				printPart(folder, "ToeC" .. index, Vector3.new(0.05, 0.14, 0.14), rim),
			},
			born = nil,
		})
	end
	return self
end

local OFFSETS = {
	{Vector3.new(0, 0, -0.1), nil}, {Vector3.new(0, 0, 0.52), nil},
	{Vector3.new(-0.17, 0, -0.62), nil}, {Vector3.new(0.02, 0, -0.68), nil}, {Vector3.new(0.19, 0, -0.62), nil},
}

function Footprints:_stamp(position, direction, side)
	local entry = self.prints[self.next]
	self.next = self.next % #self.prints + 1
	entry.born = self.clock
	local forward = Vector3.new(direction.X, 0, direction.Z)
	if forward.Magnitude < 1e-3 then forward = Vector3.new(0, 0, -1) end
	forward = forward.Unit
	local right = Vector3.new(-forward.Z, 0, forward.X)
	-- Face -Z along travel; roll the cylinder so its axis points up.
	local base = CFrame.fromMatrix(position + right * (0.42 * side), right, Vector3.new(0, 1, 0), -forward)
	entry.base = base
	for index, part in ipairs(entry.parts) do
		part.CFrame = base * CFrame.new(OFFSETS[index][1]) * CFrame.Angles(0, 0, math.rad(90))
		part.Transparency = 0.1
	end
end

-- `position`: the point on the floor under the runner, `direction`: travel direction, `speed`: studs/second.
function Footprints:Step(dt, position, direction, speed)
	self.clock += dt
	if speed > 2 then
		self.travelled += speed * dt
		if self.travelled >= self.stride then
			self.travelled = 0
			self.side = -self.side
			self:_stamp(position, direction, self.side)
		end
	end
	for _, entry in ipairs(self.prints) do
		if entry.born then
			local age = (self.clock - entry.born) / self.life
			if age >= 1 then
				entry.born = nil
				for _, part in ipairs(entry.parts) do part.Transparency = 1 part.CFrame = CFrame.new(0, -500, 0) end
			else
				local fade = 0.1 + 0.9 * math.max(0, (age - 0.35) / 0.65)
				for _, part in ipairs(entry.parts) do part.Transparency = fade end
			end
		end
	end
end

function Footprints:Clear()
	for _, entry in ipairs(self.prints) do
		entry.born = nil
		for _, part in ipairs(entry.parts) do part.Transparency = 1 part.CFrame = CFrame.new(0, -500, 0) end
	end
	self.travelled = 0
end

function Footprints:Destroy() self.folder:Destroy() end

function Footprints:Visible()
	local count = 0
	for _, entry in ipairs(self.prints) do if entry.born then count += 1 end end
	return count
end

-- ---------------------------------------------------------------------------------------
-- Part-based emulation of the same ribbons and emitters, for ViewportFrame previews.
-- ---------------------------------------------------------------------------------------
local Emulator = {}
Emulator.__index = Emulator
Trails.Emulator = Emulator

local MAX_SEGMENTS = 14   -- ribbon pieces per ribbon: smoother than 1/24 s sampling, still tiny
local MAX_PARTICLES = 36
local function sampleInterval(ribbon) return math.max(1 / 40, ribbon.lifetime / MAX_SEGMENTS) end

local function quad(parent, name)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	part.Transparency = 1
	part.Size = Vector3.new(0.1, 0.05, 0.1)
	part.CFrame = CFrame.new(0, -500, 0)
	part.Parent = parent
	return part
end

function Emulator.new(id, parent)
	local def = defs[id]
	if not def then return nil end
	local folder = Instance.new("Folder")
	folder.Name = "CatchTrailPreview"
	folder.Parent = parent
	local self = setmetatable({
		id = id, def = def, folder = folder, clock = 0, sampleClock = 0, seed = 7919, camera = Vector3.new(0, 0, -1),
		ribbons = {}, particles = {}, spawn = {}, free = {},
	}, Emulator)
	for index, ribbon in ipairs(def.ribbons or {}) do
		local maxSegments = math.ceil(ribbon.lifetime / sampleInterval(ribbon)) + 1
		local segments = {}
		for s = 1, maxSegments do
			local piece = quad(folder, "Ribbon" .. index .. "_" .. s)
			-- Glowing ribbons read as light in a viewport the way the real trail's LightEmission does.
			if (ribbon.emission or 0) >= 0.3 then piece.Material = Enum.Material.Neon end
			table.insert(segments, piece)
		end
		table.insert(self.ribbons, {spec = ribbon, samples = {}, segments = segments, clock = 0, interval = sampleInterval(ribbon)})
	end
	local budget = MAX_PARTICLES
	for index, emitter in ipairs(def.emitters or {}) do
		local capacity = math.min(budget, math.ceil(emitter.rate * emitter.life[2]) + 2)
		budget -= capacity
		self.spawn[index] = 0
		for p = 1, capacity do
			local part = quad(folder, "Particle" .. index .. "_" .. p)
			part.Shape = Enum.PartType.Ball
			if (emitter.emission or 0) >= 0.4 then part.Material = Enum.Material.Neon end
			table.insert(self.particles, {part = part, emitter = emitter, index = index, alive = false})
		end
	end
	if def.footprints then self.footprints = Footprints.new(folder, def.footprints) end
	return self
end

function Emulator:_random()
	self.seed = (self.seed * 1103515245 + 12345) % 2147483648
	return self.seed / 2147483648
end

function Emulator:_cone(direction, degrees)
	local half = math.rad(math.min(degrees, 180))
	local angle = half * math.sqrt(self:_random())
	local around = self:_random() * math.pi * 2
	local up = math.abs(direction.Y) > 0.95 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local side = direction:Cross(up).Unit
	local other = direction:Cross(side)
	return (direction * math.cos(angle) + (side * math.cos(around) + other * math.sin(around)) * math.sin(angle)).Unit
end

-- root: the runner's HumanoidRootPart CFrame, velocity: its movement in studs/second, floorY for footprints.
function Emulator:Step(dt, root, velocity, floorY)
	dt = math.clamp(dt, 0, 0.1)
	self.clock += dt
	self.sampleClock += dt
	local mount = root * CFrame.new(0, -0.55, 0.6)
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	-- Ribbons
	for _, ribbon in ipairs(self.ribbons) do
		ribbon.clock += dt
		if ribbon.clock >= ribbon.interval - 1e-6 then
			ribbon.clock = 0
			local spec = ribbon.spec
			local sample = {a = (mount * CFrame.new(spec.x - spec.hw, spec.y, 0)).Position, b = (mount * CFrame.new(spec.x + spec.hw, spec.y, 0)).Position, born = self.clock}
			table.insert(ribbon.samples, 1, sample)
			while #ribbon.samples > #ribbon.segments + 1 do table.remove(ribbon.samples) end
		end
	end
	for _, ribbon in ipairs(self.ribbons) do
		local spec, samples = ribbon.spec, ribbon.samples
		while #samples > 0 and self.clock - samples[#samples].born > spec.lifetime do table.remove(samples) end
		for s, part in ipairs(ribbon.segments) do
			local newer, older = samples[s], samples[s + 1]
			if not (newer and older) or speed < 1 then
				part.Transparency = 1
			else
				local c1, c2 = (newer.a + newer.b) / 2, (older.a + older.b) / 2
				local span = c1 - c2
				if span.Magnitude < 1e-3 then
					part.Transparency = 1
				else
					local age = math.clamp((self.clock - (newer.born + older.born) / 2) / spec.lifetime, 0, 1)
					local width = (newer.b - newer.a).Magnitude * sampleNumbers(spec.width, age)
					local forward = span.Unit
					local facing = -self.camera
					local across = forward:Cross(facing)
					if across.Magnitude < 1e-3 then across = Vector3.new(0, 1, 0):Cross(forward) end
					across = across.Unit
					local normal = forward:Cross(across)
					part.Size = Vector3.new(math.max(0.12, width), 0.05, span.Magnitude + 0.04)
					part.CFrame = CFrame.fromMatrix((c1 + c2) / 2, across, normal, forward)
					part.Color = sampleColor(spec.color, age)
					part.Transparency = math.clamp(sampleNumbers(spec.alpha, age), 0, 1)
				end
			end
		end
	end
	-- Particles
	local behind = mount:VectorToWorldSpace(Vector3.new(0, 0, 1))
	for index, emitter in ipairs(self.def.emitters or {}) do
		self.spawn[index] += emitter.rate * dt * (speed >= 1 and 1 or 0)
	end
	for _, particle in ipairs(self.particles) do
		local emitter = particle.emitter
		if not particle.alive and self.spawn[particle.index] >= 1 then
			self.spawn[particle.index] -= 1
			particle.alive = true
			particle.age = 0
			particle.life = emitter.life[1] + (emitter.life[2] - emitter.life[1]) * self:_random()
			local jitter = Vector3.new(self:_random() - 0.5, self:_random() - 0.5, self:_random() - 0.5) * 0.3
			particle.position = mount.Position + jitter
			local direction = self:_cone(behind, emitter.spread)
			particle.velocity = direction * (emitter.speed[1] + (emitter.speed[2] - emitter.speed[1]) * self:_random())
			particle.spin = emitter.rot and (self:_random() * 360) or 0
		end
		if particle.alive then
			particle.age += dt
			if particle.age >= particle.life then
				particle.alive = false
				particle.part.Transparency = 1
				particle.part.CFrame = CFrame.new(0, -500, 0)
			else
				local u = particle.age / particle.life
				particle.velocity += Vector3.new(emitter.accel[1], emitter.accel[2], emitter.accel[3]) * dt
				particle.position += particle.velocity * dt
				local size = math.max(0.02, sampleNumbers(emitter.size, u))
				particle.part.Size = Vector3.new(size, size, size)
				particle.part.CFrame = CFrame.new(particle.position)
				particle.part.Color = sampleColor(emitter.color, u)
				particle.part.Transparency = math.clamp(sampleNumbers(emitter.alpha, u), 0, 1)
			end
		end
	end
	if self.footprints then
		self.footprints:Step(dt, Vector3.new(root.Position.X, floorY + 0.04, root.Position.Z), root.LookVector, speed)
	end
end

-- Count of currently visible emulated pieces (ribbon segments + particles + footprints); used by tests.
function Emulator:Visible()
	local count = 0
	for _, ribbon in ipairs(self.ribbons) do
		for _, part in ipairs(ribbon.segments) do if part.Transparency < 1 then count += 1 end end
	end
	for _, particle in ipairs(self.particles) do if particle.alive then count += 1 end end
	if self.footprints then count += self.footprints:Visible() end
	return count
end

function Emulator:Reset()
	self.clock, self.sampleClock = 0, 0
	for _, ribbon in ipairs(self.ribbons) do
		ribbon.clock = 0
		table.clear(ribbon.samples)
		for _, part in ipairs(ribbon.segments) do part.Transparency = 1 end
	end
	for _, particle in ipairs(self.particles) do
		particle.alive = false
		particle.part.Transparency = 1
		particle.part.CFrame = CFrame.new(0, -500, 0)
	end
	for index in pairs(self.spawn) do self.spawn[index] = 0 end
	if self.footprints then self.footprints:Clear() end
end

function Emulator:Destroy() self.folder:Destroy() end

return Trails
