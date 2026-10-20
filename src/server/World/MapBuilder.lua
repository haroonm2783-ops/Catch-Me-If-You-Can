--!nonstrict
-- NEON MALL: a two-story competitive chase mall plus a separate Plaza hub.
-- Everything is authored geometry (no asset downloads). The original rooftop city is preserved
-- in CityMapBuilder.lua for a future map. Coordinates: X east, Z south, floors at y=0 and y=16.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local MapBuilder = {}
local built
local MAP_VERSION = 5
local MODEL_NAME = "CatchMall"
local F2 = 16 -- second-floor walking surface

local P = {
	white = Color3.fromRGB(222, 220, 230), marble = Color3.fromRGB(204, 192, 178), marble2 = Color3.fromRGB(178, 168, 160),
	cream = Color3.fromRGB(222, 200, 166), navy = Color3.fromRGB(44, 52, 96), ink = Color3.fromRGB(30, 32, 56),
	purple = Color3.fromRGB(128, 88, 220), magenta = Color3.fromRGB(238, 74, 190), cyan = Color3.fromRGB(70, 226, 238),
	blue = Color3.fromRGB(72, 142, 255), coral = Color3.fromRGB(255, 108, 114), gold = Color3.fromRGB(255, 198, 86),
	green = Color3.fromRGB(62, 182, 118), leaf = Color3.fromRGB(104, 204, 104), wood = Color3.fromRGB(164, 110, 68),
	teal = Color3.fromRGB(44, 190, 192), pink = Color3.fromRGB(255, 152, 202), glass = Color3.fromRGB(128, 186, 214),
	steel = Color3.fromRGB(150, 160, 178), red = Color3.fromRGB(214, 48, 70), orange = Color3.fromRGB(255, 152, 70),
	soil = Color3.fromRGB(70, 60, 54), yellow = Color3.fromRGB(240, 204, 80),
}

-- Tunable lighting preset. Values are deliberately restrained: surfaces keep their color,
-- neon stays an accent, and shaded interiors rely on warm point lights, not exposure.
local LIGHTING = {
	ClockTime = 15.6, Brightness = 1.7, Ambient = Color3.fromRGB(122, 118, 138), OutdoorAmbient = Color3.fromRGB(136, 130, 152),
	ColorShift_Top = Color3.fromRGB(255, 226, 190), ExposureCompensation = -0.1, EnvironmentDiffuseScale = 0.5, EnvironmentSpecularScale = 0.2,
	ShadowSoftness = 0.3, BloomIntensity = 0.12, BloomSize = 16, BloomThreshold = 2.2, Saturation = 0.04, Contrast = 0.06, Haze = 0.35, Density = 0.07,
}
local function applyLighting()
	local L = LIGHTING
	Lighting.ClockTime = L.ClockTime
	Lighting.Brightness = L.Brightness
	Lighting.Ambient = L.Ambient
	Lighting.OutdoorAmbient = L.OutdoorAmbient
	Lighting.ColorShift_Top = L.ColorShift_Top
	Lighting.ExposureCompensation = L.ExposureCompensation
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = L.ShadowSoftness
	Lighting.EnvironmentDiffuseScale = L.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = L.EnvironmentSpecularScale
	for _, name in ipairs({ "CatchAtmosphere", "CatchBloom", "CatchColor", "CatchSunRays", "CatchSky" }) do
		local old = Lighting:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "CatchAtmosphere"
	atmosphere.Density = L.Density
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(196, 190, 224)
	atmosphere.Decay = Color3.fromRGB(240, 170, 150)
	atmosphere.Glare = 0.05
	atmosphere.Haze = L.Haze
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "CatchBloom"
	bloom.Intensity = L.BloomIntensity
	bloom.Size = L.BloomSize
	bloom.Threshold = L.BloomThreshold
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "CatchColor"
	color.Contrast = L.Contrast
	color.Saturation = L.Saturation
	color.TintColor = Color3.fromRGB(255, 248, 242)
	color.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "CatchSunRays"
	rays.Intensity = 0.03
	rays.Spread = 0.5
	rays.Parent = Lighting
end

local function activateObstacles(model)
	if model:GetAttribute("CatchRuntimeStarted") then return end
	model:SetAttribute("CatchRuntimeStarted", true)
	local tweens = {}
	for _, gate in ipairs(model:GetDescendants()) do
		if gate:IsA("BasePart") and gate:GetAttribute("DynamicObstacle") then
			local closed = gate:GetAttribute("GateClosedCFrame") or gate.CFrame
			gate.CFrame = closed
			local tween = TweenService:Create(gate, TweenInfo.new(gate:GetAttribute("GateCycle") or 3,
				Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 1.5), { CFrame = closed + Vector3.new(0, 5.5, 0) })
			table.insert(tweens, tween)
			tween:Play()
		elseif gate:IsA("BasePart") and gate:GetAttribute("StripeShift") then
			-- Escalator treads: a periodic slide that loops without a visible seam.
			local start = gate.CFrame
			local shift = gate:GetAttribute("StripeShift")
			local tween = TweenService:Create(gate, TweenInfo.new(1.2, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1, false), { CFrame = start * CFrame.new(0, 0, shift) })
			table.insert(tweens, tween)
			tween:Play()
		elseif gate:IsA("BasePart") and gate:GetAttribute("Pulse") then
			local tween = TweenService:Create(gate, TweenInfo.new(1.6 + (gate:GetAttribute("Pulse") % 5) * 0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.55 })
			table.insert(tweens, tween)
			tween:Play()
		end
	end
	model.Destroying:Connect(function()
		for _, tween in ipairs(tweens) do tween:Cancel() end
	end)
end

local function readBaked(model)
	local world = { Model = model, LobbySpawn = model:GetAttribute("LobbySpawn"), RunnerSpawns = {}, HunterSpawns = {}, Podiums = {},
		Bounds = { min = model:GetAttribute("BoundsMin"), max = model:GetAttribute("BoundsMax") } }
	for _, kind in ipairs({ "Runner", "Hunter", "Podium" }) do
		local target = kind == "Podium" and world.Podiums or world[kind .. "Spawns"]
		for i = 1, model:GetAttribute(kind .. "Count") or 0 do
			table.insert(target, model:GetAttribute(kind .. "Spawn" .. i))
		end
	end
	return world
end

function MapBuilder.Build(options)
	if built and built.Model.Parent then return built end
	local static = options and options.Static == true
	local existing = workspace:FindFirstChild(MODEL_NAME)
	if existing and existing:GetAttribute("CatchMapVersion") == MAP_VERSION then
		built = readBaked(existing)
		applyLighting()
		if not static then activateObstacles(existing) end
		return built
	elseif existing then existing:Destroy() end
	for _, stale in ipairs({ "NeonHeights" }) do
		local old = workspace:FindFirstChild(stale)
		if old then old:Destroy() end
	end
	local model = Instance.new("Model")
	model.Name = MODEL_NAME
	model:SetAttribute("MapName", "NEON MALL")
	model:SetAttribute("ArtDirection", "Two-story glass-roofed mall / neon storefronts / palm atrium / Plaza hub")
	local partCount, lightCount = 0, 0
	local gates = {}
	local function group(name)
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = model
		return folder
	end
	local shell = group("MallShell")
	local floors = group("Floors")
	local atrium = group("Atrium")
	local storesF = group("Stores")
	local court = group("FoodCourt")
	local arcade = group("Arcade")
	local routes = group("ParkourRoutes")
	local decor = group("Decor")
	local hub = group("PlazaHub")
	local skyline = group("DistantSkyline")

	local function part(parent, name, size, cf, color, material, collide)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
		p.Color = color or P.white
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = collide ~= false
		p.CanTouch = false
		p.CanQuery = p.CanCollide
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = material ~= Enum.Material.Neon and material ~= Enum.Material.Glass
		p.Parent = parent
		partCount += 1
		return p
	end
	local function box(parent, name, x, y, z, sx, sy, sz, color, material, collide)
		return part(parent, name, Vector3.new(sx, sy, sz), Vector3.new(x, y, z), color, material, collide)
	end
	-- Art never collides, so visual polish cannot change chase physics or vault targets.
	local function art(parent, name, size, cf, color, material)
		local p = part(parent, name, size, cf, color, material, false)
		p:SetAttribute("VisualPolish", true)
		-- Small props never cast shadows: saves GPU time on phones with no visible loss.
		if size.Magnitude < 5 then p.CastShadow = false end
		return p
	end
	local function neon(parent, name, x, y, z, sx, sy, sz, color, pulse)
		local p = art(parent, name, Vector3.new(sx, sy, sz), Vector3.new(x, y, z), color, Enum.Material.Neon)
		if pulse then p:SetAttribute("Pulse", pulse) end
		return p
	end
	local function glassBox(parent, name, x, y, z, sx, sy, sz, alpha, collide, color)
		local p = part(parent, name, Vector3.new(sx, sy, sz), Vector3.new(x, y, z), color or P.glass, Enum.Material.Glass, collide)
		p.Transparency = alpha or 0.55
		if not collide then p:SetAttribute("VisualPolish", true) end
		return p
	end
	local function beamFrame(a, b)
		local direction = b - a
		assert(direction.Magnitude > 0.001, "Beam endpoints must differ")
		local up = math.abs(direction.Unit.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
		return CFrame.lookAt((a + b) / 2, b, up)
	end
	local function artBeam(parent, name, a, b, width, color, material)
		return art(parent, name, Vector3.new(width, width, (b - a).Magnitude), beamFrame(a, b), color, material)
	end
	local function cylinder(parent, name, center, diameter, height, color, material, collide)
		local p = part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), color, material, collide)
		p.Shape = Enum.PartType.Cylinder
		if collide == false then p:SetAttribute("VisualPolish", true) end
		return p
	end
	local function disc(parent, name, cf, diameter, thickness, color, material)
		local p = art(parent, name, Vector3.new(thickness, diameter, diameter), cf * CFrame.Angles(0, math.pi / 2, 0), color, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function sphere(parent, name, center, size, color, material)
		local p = part(parent, name, size, center, color, material or Enum.Material.SmoothPlastic, false)
		p.Shape = Enum.PartType.Ball
		p:SetAttribute("VisualPolish", true)
		return p
	end
	local function surfaceText(backing, face, text, color, ppu, scaleX, scaleY)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face or Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = ppu or 30
		gui.LightInfluence = 0
		gui.MaxDistance = 260
		gui.Parent = backing
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(scaleX or 0.94, scaleY or 0.82)
		label.Position = UDim2.fromScale((1 - (scaleX or 0.94)) / 2, (1 - (scaleY or 0.82)) / 2)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = color or P.white
		label.TextScaled = true
		label.FontFace = Font.fromEnum(Enum.Font.GothamBlack)
		label.Parent = gui
		return label
	end
	-- Hollow ring from short beams (parts cannot be hollow discs). frame = CFrame at the center,
	-- ring lies in its local XY plane.
	local function ring(parent, name, frame, radius, width, color, material, segments)
		segments = segments or 14
		for i = 1, segments do
			local a0, a1 = (i - 1) * 2 * math.pi / segments, i * 2 * math.pi / segments
			local p0 = frame * Vector3.new(math.cos(a0) * radius, math.sin(a0) * radius, 0)
			local p1 = frame * Vector3.new(math.cos(a1) * radius, math.sin(a1) * radius, 0)
			artBeam(parent, name, p0, p1, width, color, material)
		end
	end
	-- A lit sign: dark backing, glowing edge strips and a SurfaceGui on the +Z (Back) face at rotation 0.
	local function sign(parent, text, center, width, height, accent, rotation, textColor)
		local cf = CFrame.new(center) * CFrame.Angles(0, rotation or 0, 0)
		local backing = part(parent, "Sign_" .. text, Vector3.new(width, height, 0.4), cf, P.ink, Enum.Material.SmoothPlastic, false)
		backing:SetAttribute("VisualPolish", true)
		surfaceText(backing, Enum.NormalId.Back, text, textColor or accent or P.white, 34)
		for _, side in ipairs({ -1, 1 }) do
			art(parent, "SignEdge", Vector3.new(width + 0.3, 0.16, 0.2), cf * CFrame.new(0, side * height / 2, 0.15), accent, Enum.Material.Neon)
		end
		return backing
	end
	local function light(parent, center, color, brightness, range)
		lightCount += 1
		local bulb = art(parent, "Lamp", Vector3.new(1.2, 0.25, 1.2), center, color, Enum.Material.Neon)
		local point = Instance.new("PointLight")
		point.Color = color
		point.Brightness = brightness or 0.8
		point.Range = range or 22
		point.Shadows = false
		point.Parent = bulb
	end

	-- Solid rectangle with rectangular holes removed (stairwells, voids): sweeps horizontal bands.
	local function slab(parent, name, x1, x2, z1, z2, ytop, thick, color, material, holes)
		holes = holes or {}
		local zs = { z1, z2 }
		for _, h in ipairs(holes) do
			table.insert(zs, math.clamp(h[3], z1, z2))
			table.insert(zs, math.clamp(h[4], z1, z2))
		end
		table.sort(zs)
		for i = 1, #zs - 1 do
			local za, zb = zs[i], zs[i + 1]
			if zb - za > 0.01 then
				local mid = (za + zb) / 2
				local cuts = {}
				for _, h in ipairs(holes) do
					if mid > h[3] and mid < h[4] then table.insert(cuts, { h[1], h[2] }) end
				end
				table.sort(cuts, function(a, b) return a[1] < b[1] end)
				local cursor = x1
				local function emit(a, b)
					if b - a > 0.01 then
						box(parent, name, (a + b) / 2, ytop - thick / 2, mid, b - a, thick, zb - za, color, material)
					end
				end
				for _, cut in ipairs(cuts) do
					emit(cursor, math.min(cut[1], x2))
					cursor = math.max(cursor, cut[2])
				end
				emit(cursor, x2)
			end
		end
	end
	-- Axis-aligned wall with door openings. axis "x": wall runs along X at fixed z.
	local function wall(parent, name, axis, fixed, a1, a2, y0, y1, thick, color, material, gaps)
		gaps = gaps or {}
		table.sort(gaps, function(p, q) return p.c < q.c end)
		local function seg(s, e, ylo, yhi)
			if e - s < 0.05 or yhi - ylo < 0.05 then return end
			if axis == "x" then
				box(parent, name, (s + e) / 2, (ylo + yhi) / 2, fixed, e - s, yhi - ylo, thick, color, material)
			else
				box(parent, name, fixed, (ylo + yhi) / 2, (s + e) / 2, thick, yhi - ylo, e - s, color, material)
			end
		end
		local cursor = a1
		for _, gap in ipairs(gaps) do
			seg(cursor, gap.c - gap.w / 2, y0, y1)
			seg(gap.c - gap.w / 2, gap.c + gap.w / 2, y0 + gap.h, y1) -- lintel above the opening
			cursor = gap.c + gap.w / 2
		end
		seg(cursor, a2, y0, y1)
	end
	local function ceilingStrip(parent, x, y, z, sx, sz, color)
		neon(parent, "CeilingLight", x, y, z, sx, 0.2, sz, color or Color3.fromRGB(214, 190, 150))
	end

	-- Reusable dressing ----------------------------------------------------------------
	local function planter(parent, x, y, z, length, rot, bloom)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, rot or 0, 0)
		part(parent, "Planter", Vector3.new(length, 1.6, 3.4), cf * CFrame.new(0, 0.8, 0), P.cream, Enum.Material.Concrete)
		art(parent, "PlanterTrim", Vector3.new(length + 0.3, 0.2, 3.7), cf * CFrame.new(0, 1.6, 0), P.gold, Enum.Material.Metal)
		local n = math.max(2, math.floor(length / 2.8))
		for i = 1, n do
			local pos = (cf * CFrame.new(-length / 2 + i * length / (n + 1), 2.4, 0)).Position
			sphere(parent, "Shrub", pos, Vector3.new(2.6, 2.2, 2.4), i % 2 == 0 and P.green or P.leaf)
			if bloom then sphere(parent, "Blossom", pos + Vector3.new(0.3, 1, 0), Vector3.new(0.7, 0.6, 0.7), i % 2 == 0 and P.pink or P.gold) end
		end
	end
	local function palm(parent, x, y, z, scale, tilt)
		scale = scale or 1
		local base = Vector3.new(x, y, z)
		local lean = (tilt or 0.12)
		local top = base
		for i = 1, 3 do
			local nextTop = base + Vector3.new(lean * i * 2.2, i * 3.6 * scale, 0)
			local seg = part(parent, "PalmTrunk", Vector3.new(0.9 * scale, (nextTop - top).Magnitude + 0.1, 0.9 * scale),
				CFrame.lookAt((top + nextTop) / 2, nextTop) * CFrame.Angles(math.pi / 2, 0, 0), P.wood, Enum.Material.Wood, i == 1)
			seg.Shape = Enum.PartType.Cylinder
			seg.Size = Vector3.new((nextTop - top).Magnitude + 0.1, 0.9 * scale, 0.9 * scale)
			seg.CFrame = CFrame.lookAt((top + nextTop) / 2, nextTop) * CFrame.Angles(0, math.pi / 2, 0)
			if i > 1 then seg:SetAttribute("VisualPolish", true) end
			top = nextTop
		end
		for i = 1, 7 do
			local yaw = i * (math.pi * 2 / 7)
			local frond = art(parent, "PalmFrond", Vector3.new(0.7, 0.14, 7.4 * scale),
				CFrame.new(top) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-24), 0, 0) * CFrame.new(0, 0, -3.4 * scale), i % 2 == 0 and P.green or P.leaf, Enum.Material.Grass)
			frond.CastShadow = false
		end
		sphere(parent, "Coconuts", top + Vector3.new(0, -0.5, 0), Vector3.new(1.3, 1.1, 1.3) * scale, P.wood)
	end
	local function bench(parent, x, y, z, rot, color)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, rot or 0, 0)
		part(parent, "BenchSeat", Vector3.new(7, 0.6, 2.4), cf * CFrame.new(0, 1.4, 0), color or P.wood, Enum.Material.Wood)
		art(parent, "BenchBack", Vector3.new(7, 1.4, 0.3), cf * CFrame.new(0, 2.6, 1.1), color or P.wood, Enum.Material.Wood)
		for _, side in ipairs({ -1, 1 }) do part(parent, "BenchLeg", Vector3.new(0.4, 1.2, 2.2), cf * CFrame.new(side * 3, 0.6, 0), P.navy, Enum.Material.Metal) end
		neon(parent, "BenchGlow", x, y + 0.15, z, 6.6, 0.1, 0.2, P.cyan)
	end
	-- Low tables/counters tagged Vaultable stay below the 4.5 stud vault height.
	local function vaultTable(parent, x, y, z, sx, sz, color, rot, top)
		local cf = CFrame.new(x, y + 1.6, z) * CFrame.Angles(0, rot or 0, 0)
		local t = part(parent, "VaultTable", Vector3.new(sx, 3.2, sz), cf, color or P.wood, Enum.Material.Wood)
		t:SetAttribute("Vaultable", true)
		art(parent, "TableTop", Vector3.new(sx + 0.3, 0.2, sz + 0.3), cf * CFrame.new(0, 1.7, 0), top or P.white, Enum.Material.SmoothPlastic)
		return t
	end
	local function chair(parent, x, y, z, color, rot)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, rot or 0, 0)
		art(parent, "ChairSeat", Vector3.new(1.8, 0.3, 1.8), cf * CFrame.new(0, 1.5, 0), color, Enum.Material.SmoothPlastic)
		art(parent, "ChairBack", Vector3.new(1.8, 1.7, 0.25), cf * CFrame.new(0, 2.4, 0.8), color, Enum.Material.SmoothPlastic)
		art(parent, "ChairLeg", Vector3.new(0.3, 1.5, 0.3), cf * CFrame.new(0, 0.75, 0), P.steel, Enum.Material.Metal)
	end
	local function shelf(parent, x, y, z, sx, sz, height, color, accent, spine)
		local s = part(parent, "Shelf", Vector3.new(sx, height, sz), Vector3.new(x, y + height / 2, z), color, Enum.Material.SmoothPlastic)
		local alongX = sx > sz
		for row = 1, math.max(1, math.floor(height / 2.4)) do
			local yy = y + row * 2.3
			if alongX then
				neon(parent, "ShelfLight", x, yy, z + (sz / 2 + 0.06), sx - 0.6, 0.12, 0.08, accent)
				neon(parent, "ShelfLight", x, yy, z - (sz / 2 + 0.06), sx - 0.6, 0.12, 0.08, accent)
			else
				neon(parent, "ShelfLight", x + (sx / 2 + 0.06), yy, z, 0.08, 0.12, sz - 0.6, accent)
				neon(parent, "ShelfLight", x - (sx / 2 + 0.06), yy, z, 0.08, 0.12, sz - 0.6, accent)
			end
		end
		if spine then
			for i = 1, 4 do
				local pos = alongX and Vector3.new(x - sx / 2 + i * sx / 5, y + height * 0.6, z) or Vector3.new(x, y + height * 0.6, z - sz / 2 + i * sz / 5)
				art(parent, "Spine", alongX and Vector3.new(0.9, height * 0.5, sz + 0.12) or Vector3.new(sx + 0.12, height * 0.5, 0.9), pos, i % 2 == 0 and spine or accent)
			end
		end
		return s
	end
	local function mannequin(parent, x, y, z, color)
		cylinder(parent, "MannequinBase", Vector3.new(x, y + 0.15, z), 2.2, 0.3, P.ink, Enum.Material.Metal, false)
		art(parent, "MannequinBody", Vector3.new(1.5, 2.8, 0.9), Vector3.new(x, y + 2.2, z), color, Enum.Material.SmoothPlastic)
		art(parent, "MannequinLegs", Vector3.new(1.2, 1.9, 0.8), Vector3.new(x, y + 0.95, z), P.ink, Enum.Material.SmoothPlastic)
		sphere(parent, "MannequinHead", Vector3.new(x, y + 4.0, z), Vector3.new(1, 1.1, 1), P.marble)
	end

	-- =====================================================================================
	-- MALL SHELL, FLOORS, ROOF  (264 x 192 footprint; hall 144 x 112; stores 40 deep)
	-- =====================================================================================
	local OX, OZ = 132, 96 -- outer half extents
	local HX, HZ = 72, 56 -- hall half extents (wings lie beyond HX, store rows beyond HZ)
	local VX, VZ = 44, 34 -- atrium void half size
	local D = 40 -- store depth
	local TOP = 32 -- top of perimeter walls
	local stairHoles = { { -63, -53, -28, 10 }, { 53, 63, -10, 28 } }
	local voidHole = { -VX, VX, -VZ, VZ }
	local loungeHole = { -122, -82, -36, 36 }
	local ceil1 = F2 - 1.2

	box(floors, "Foundation", 0, -2.2, 0, 2 * OX + 4, 3.6, 2 * OZ + 4, P.navy, Enum.Material.Concrete)
	-- Ground floor: marble hall, wood food court, carpeted arcade and two store rows.
	box(floors, "HallMarble", 0, -0.2, 0, 2 * HX, 0.4, 2 * HZ, P.marble, Enum.Material.Marble)
	box(floors, "FoodCourtFloor", -(HX + OX) / 2, -0.2, 0, OX - HX, 0.4, 2 * HZ, Color3.fromRGB(196, 150, 104), Enum.Material.WoodPlanks)
	box(floors, "ArcadeFloor", (HX + OX) / 2, -0.2, 0, OX - HX, 0.4, 2 * HZ, P.navy, Enum.Material.SmoothPlastic)
	for _, zc in ipairs({ -(HZ + OZ) / 2, (HZ + OZ) / 2 }) do box(floors, "StoreRowFloor", 0, -0.2, zc, 2 * OX, 0.4, D, P.marble2, Enum.Material.Marble) end
	-- Checker tiles break up the hall floor so it never reads as one flat slab.
	for ix = -6, 5 do
		for iz = -4, 3 do
			if (ix + iz) % 2 == 0 then art(floors, "FloorTile", Vector3.new(11.8, 0.06, 13.8), Vector3.new((ix + 0.5) * 12, 0.03, (iz + 0.5) * 14), P.marble2, Enum.Material.Marble) end
		end
	end
	for i, d in ipairs({ 44, 36, 28 }) do
		art(floors, "InlayRing", Vector3.new(0.12, d + 12, d + 12), CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.pi / 2), i == 2 and P.gold or P.blue, i == 2 and Enum.Material.Metal or Enum.Material.SmoothPlastic).Shape = Enum.PartType.Cylinder
	end
	for _, z in ipairs({ -46, 46 }) do
		art(floors, "AisleInlay", Vector3.new(136, 0.1, 0.8), Vector3.new(0, 0.06, z), P.gold, Enum.Material.Metal)
		art(floors, "AisleInlay", Vector3.new(136, 0.1, 0.35), Vector3.new(0, 0.06, z + (z < 0 and 2 or -2)), P.cyan, Enum.Material.Neon)
	end
	-- Second floor slab, with the atrium void, stairwells, and lounge window cut away.
	local function floor2(name, x1, x2, z1, z2, color, material, holes)
		slab(floors, name, x1, x2, z1, z2, F2, 1.2, color, material, holes)
	end
	floor2("UpperStoreRow", -OX, OX, -OZ, -HZ, P.marble2, Enum.Material.Marble)
	floor2("UpperStoreRow", -OX, OX, HZ, OZ, P.marble2, Enum.Material.Marble)
	floor2("UpperHall", -HX, HX, -HZ, HZ, P.marble, Enum.Material.Marble, { voidHole, stairHoles[1], stairHoles[2] })
	floor2("UpperWestLounge", -OX, -HX, -HZ, HZ, Color3.fromRGB(196, 150, 104), Enum.Material.WoodPlanks, { loungeHole })
	floor2("UpperEastDept", HX, OX, -HZ, HZ, P.marble2, Enum.Material.Marble)
	for _, z in ipairs({ -VZ - 0.5, VZ + 0.5 }) do art(floors, "FasciaNeon", Vector3.new(2 * VX + 1, 0.25, 0.25), Vector3.new(0, F2 - 2.5, z), P.cyan, Enum.Material.Neon) end
	for _, x in ipairs({ -VX - 0.5, VX + 0.5 }) do art(floors, "FasciaNeon", Vector3.new(0.25, 0.25, 2 * VZ + 1), Vector3.new(x, F2 - 2.5, 0), P.magenta, Enum.Material.Neon) end
	for _, z in ipairs({ -VZ + 0.5, VZ - 0.5 }) do art(floors, "FasciaTrim", Vector3.new(2 * VX, 1.8, 0.8), Vector3.new(0, F2 - 1.5, z), P.white) end
	for _, x in ipairs({ -VX + 0.5, VX - 0.5 }) do art(floors, "FasciaTrim", Vector3.new(0.8, 1.8, 2 * VZ), Vector3.new(x, F2 - 1.5, 0), P.white) end
	for _, x in ipairs({ -58, 58 }) do for z = -48, 48, 16 do ceilingStrip(floors, x, F2 - 1.3, z, 6, 1.2) end end
	for _, z in ipairs({ -45, 45 }) do for x = -32, 32, 16 do ceilingStrip(floors, x, F2 - 1.3, z, 6, 1.2) end end

	-- Perimeter: solid walls with window bands; roof slabs over stores.
	local wallColor = P.cream
	for _, x in ipairs({ -(OX + 1), OX + 1 }) do box(shell, "OuterWall", x, TOP / 2, 0, 2, TOP, 2 * OZ, wallColor, Enum.Material.Concrete) end
	for _, z in ipairs({ -(OZ + 1), OZ + 1 }) do box(shell, "OuterWall", 0, TOP / 2, z, 2 * OX + 4, TOP, 2, wallColor, Enum.Material.Concrete) end
	for _, z in ipairs({ -(OZ - 0.2), OZ - 0.2 }) do
		for x = -110, 110, 22 do
			glassBox(shell, "LoftWindow", x, 24, z, 14, 5, 0.3, 0.45, false)
			glassBox(shell, "LoftWindow", x, 7.5, z, 14, 4, 0.3, 0.45, false)
		end
	end
	for _, x in ipairs({ -(OX - 0.2), OX - 0.2 }) do
		for z = -66, 66, 22 do glassBox(shell, "LoftWindow", x, 24, z, 0.3, 5, 14, 0.45, false) end
	end
	for _, zc in ipairs({ -(HZ + OZ) / 2, (HZ + OZ) / 2 }) do
		slab(shell, "StoreRowRoof", -OX, OX, zc - D / 2, zc + D / 2, 31.2, 1.2, P.white, Enum.Material.Concrete)
	end
	for _, z in ipairs({ -OZ, OZ }) do art(shell, "RoofNeon", Vector3.new(2 * OX, 0.3, 0.3), Vector3.new(0, TOP + 0.2, z), P.magenta, Enum.Material.Neon) end
	slab(shell, "WestWingRoofSolid", -OX, -HX, -HZ, HZ, 31.2, 1.2, P.white, Enum.Material.Concrete, { { -128, -76, -48, 48 } })
	slab(shell, "EastWingRoofSolid", HX, OX, -HZ, HZ, 31.2, 1.2, P.white, Enum.Material.Concrete, { { 76, 128, -48, 48 } })
	for _, side in ipairs({ -1, 1 }) do
		local cx = side * 102
		glassBox(shell, "WingSkylight", cx, 32.2, 0, 52, 0.3, 96, 0.5, false)
		for i = -2, 2 do artBeam(shell, "SkylightRib", Vector3.new(cx - 26, 32.7, i * 24), Vector3.new(cx + 26, 32.7, i * 24), 0.7, P.white, Enum.Material.Metal) end
		for i = -2, 2 do artBeam(shell, "SkylightRib", Vector3.new(cx + i * 13, 32.7, -48), Vector3.new(cx + i * 13, 32.7, 48), 0.5, P.white, Enum.Material.Metal) end
	end
	-- Hall barrel-vault roof: arched ribs and glass panels, peak at y=46.
	local rise, base = 14, 32
	local R = (HX * HX + rise * rise) / (2 * rise)
	local centerY = base + rise - R
	local segments = 12
	local halfAngle = math.asin(HX / R)
	for s = 0, segments - 1 do
		local a0 = -halfAngle + s * (2 * halfAngle / segments)
		local a1 = a0 + 2 * halfAngle / segments
		local p0 = Vector3.new(math.sin(a0) * R, centerY + math.cos(a0) * R, 0)
		local p1 = Vector3.new(math.sin(a1) * R, centerY + math.cos(a1) * R, 0)
		local mid = (p0 + p1) / 2
		local angle = math.atan2(p1.Y - p0.Y, p1.X - p0.X)
		local len = (p1 - p0).Magnitude
		local glass = glassBox(shell, "VaultGlass", mid.X, mid.Y, 0, len + 0.05, 0.3, 2 * HZ + 2, 0.5, false, P.glass)
		glass.CFrame = CFrame.new(mid) * CFrame.Angles(0, 0, angle)
		for _, z in ipairs({ -HZ, -28, 0, 28, HZ }) do
			local rib = artBeam(shell, "VaultRib", Vector3.new(p0.X, p0.Y + 0.1, z), Vector3.new(p1.X, p1.Y + 0.1, z), 0.7, P.white, Enum.Material.Metal)
			rib.Size = Vector3.new(0.9, 0.9, len + 0.05)
		end
		for _, z in ipairs({ -HZ, HZ }) do
			box(shell, "VaultGable", (p0.X + p1.X) / 2, (base + mid.Y) / 2, z, len + 0.05, math.max(mid.Y - base, 0.2), 0.6, P.white, Enum.Material.Concrete, false):SetAttribute("VisualPolish", true)
		end
	end
	for _, x in ipairs({ -HX, HX }) do art(shell, "VaultCornice", Vector3.new(1.4, 1.2, 2 * HZ), Vector3.new(x, base + 0.6, 0), P.gold, Enum.Material.Metal) end
	for s = -3, 3 do neon(shell, "VaultLight", s * 18, 45.2 - math.abs(s) * 0.5, 0, 0.3, 0.2, 100, Color3.fromRGB(214, 190, 150)) end

	-- Atrium columns, glass balcony railings with designated gaps, and the skybridge.
	for _, c in ipairs({ { -VX, -VZ }, { VX, -VZ }, { -VX, VZ }, { VX, VZ }, { -VX, -17 }, { -VX, 17 }, { VX, -17 }, { VX, 17 }, { 0, -VZ }, { 0, VZ } }) do
		cylinder(atrium, "Column", Vector3.new(c[1], 18.5, c[2]), 2.6, 37, P.white, Enum.Material.Marble)
		cylinder(atrium, "ColumnBase", Vector3.new(c[1], 0.6, c[2]), 3.6, 1.2, P.gold, Enum.Material.Metal, false)
		cylinder(atrium, "ColumnCollar", Vector3.new(c[1], F2 + 0.3, c[2]), 3.2, 0.6, P.gold, Enum.Material.Metal, false)
		neon(atrium, "ColumnLight", c[1], 10, c[2], 0.15, 12, 0.15, P.cyan)
	end
	for _, c in ipairs({ { -52, -46 }, { 52, 46 }, { -52, 46 }, { 52, -46 }, { 0, -46 }, { 0, 46 }, { -26, 0 }, { 26, 0 } }) do
		light(atrium, Vector3.new(c[1], F2 - 1.7, c[2]), P.white, 0.7, 36)
	end
	local RAIL = 7.2
	local function railing(axis, fixed, a1, a2, gaps)
		wall(atrium, "BalconyGlass", axis, fixed, a1, a2, F2, F2 + RAIL, 0.35, P.glass, Enum.Material.Glass, gaps)
		for _, g in ipairs(atrium:GetChildren()) do
			if g.Name == "BalconyGlass" and not g:GetAttribute("Tinted") then
				g:SetAttribute("Tinted", true)
				g.Transparency = 0.6
				g.CastShadow = false
			end
		end
		local cx = (a1 + a2) / 2
		if axis == "x" then art(atrium, "Handrail", Vector3.new(a2 - a1, 0.3, 0.6), Vector3.new(cx, F2 + RAIL, fixed), P.gold, Enum.Material.Metal)
		else art(atrium, "Handrail", Vector3.new(0.6, 0.3, a2 - a1), Vector3.new(fixed, F2 + RAIL, cx), P.gold, Enum.Material.Metal) end
	end
	railing("x", -VZ + 0.4, -VX, VX, { { c = -26, w = 14, h = 12 }, { c = 26, w = 12, h = 12 } })
	railing("x", VZ - 0.4, -VX, VX, { { c = 26, w = 14, h = 12 }, { c = -26, w = 12, h = 12 } })
	railing("z", -VX + 0.4, -VZ, VZ, { { c = 0, w = 12, h = 12 } })
	railing("z", VX - 0.4, -VZ, VZ, { { c = 0, w = 12, h = 12 } })
	for _, z in ipairs({ -VZ, VZ }) do neon(atrium, "DropZoneMarker", z < 0 and 26 or -26, F2 + 0.07, z + (z < 0 and 1.2 or -1.2), 10, 0.06, 0.5, P.yellow, 1) end
	slab(routes, "Skybridge", -VX, VX, -5, 5, F2, 1.2, P.marble2, Enum.Material.Marble)
	for _, z in ipairs({ -5.2, 5.2 }) do
		local g = part(routes, "BridgeGlass", Vector3.new(2 * VX, RAIL, 0.3), Vector3.new(0, F2 + RAIL / 2, z), P.glass, Enum.Material.Glass)
		g.Transparency = 0.6
		g.CastShadow = false
		art(routes, "BridgeRail", Vector3.new(2 * VX, 0.3, 0.6), Vector3.new(0, F2 + RAIL, z), P.gold, Enum.Material.Metal)
		neon(routes, "BridgeGlow", 0, F2 - 0.4, z * 0.9, 2 * VX, 0.2, 0.2, P.blue)
	end
	art(routes, "BridgeUnderside", Vector3.new(2 * VX, 0.8, 10.6), Vector3.new(0, F2 - 1.6, 0), P.white, Enum.Material.Metal)

	-- =====================================================================================
	-- VERTICAL ROUTES: two escalator ramps (walkable) and two stair runs
	-- =====================================================================================
	local function escalator(name, x, zLow, zTop, accent)
		local a, b = Vector3.new(x, 0, zLow), Vector3.new(x, F2, zTop)
		local length = (b - a).Magnitude
		local frame = CFrame.lookAt((a + b) / 2, b)
		local deck = part(routes, name, Vector3.new(10, 0.7, length), frame * CFrame.new(0, -0.35, 0), P.steel, Enum.Material.Metal)
		deck:SetAttribute("TraversalRoute", true)
		for i = 1, 16 do art(routes, "Tread", Vector3.new(9.2, 0.06, 0.5), frame * CFrame.new(0, 0.06, length / 2 - i * length / 17), P.ink, Enum.Material.Metal) end
		for i = 1, 6 do
			local chev = neon(routes, "Chevron", 0, 0, 0, 3.2, 0.08, 0.5, accent, i)
			chev.CFrame = frame * CFrame.new(0, 0.09, length / 2 - i * length / 7)
		end
		for _, side in ipairs({ -1, 1 }) do
			local rail = part(routes, "EscalatorGlass", Vector3.new(0.3, 4.2, length), frame * CFrame.new(side * 5.1, 2.1, 0), P.glass, Enum.Material.Glass)
			rail.Transparency = 0.5
			rail.CastShadow = false
			art(routes, "EscalatorHandrail", Vector3.new(0.5, 0.4, length), frame * CFrame.new(side * 5.1, 4.3, 0), accent, Enum.Material.Neon)
			art(routes, "EscalatorSkirt", Vector3.new(0.6, 1.2, length), frame * CFrame.new(side * 5.1, -0.7, 0), P.white, Enum.Material.Metal)
		end
		art(routes, "EscalatorUnderside", Vector3.new(10, 0.6, length), frame * CFrame.new(0, -1.1, 0), P.white, Enum.Material.Metal)
		return deck
	end
	escalator("EscalatorWest", -26, 4, -VZ, P.cyan)
	escalator("EscalatorEast", 26, -4, VZ, P.magenta)
	local function stair(name, x, zStart, zEnd, width, accent)
		local steps = 20
		local sign = zEnd > zStart and 1 or -1
		local run = math.abs(zEnd - zStart) / steps
		for i = 1, steps do
			local h = 0.8 * i
			local step = box(routes, name, x, h / 2, zStart + sign * run * (i - 0.5), width, h, run + 0.04, i % 2 == 0 and P.marble or P.marble2, Enum.Material.Marble)
			step:SetAttribute("StairStep", true)
		end
		for _, side in ipairs({ -1, 1 }) do
			local a = Vector3.new(x + side * (width / 2 + 0.25), 4.2, zStart)
			local b = Vector3.new(x + side * (width / 2 + 0.25), 4.2 + 16, zEnd)
			artBeam(routes, "StairHandrail", a, b, 0.4, accent, Enum.Material.Neon)
			local g = art(routes, "StairGlass", Vector3.new(0.25, 3.6, (b - a).Magnitude), beamFrame(a, b) * CFrame.new(0, -1.6, 0), P.glass, Enum.Material.Glass)
			g.Transparency = 0.6
			g.CastShadow = false
		end
	end
	stair("StairWest", -58, 10, -28, 10, P.gold)
	stair("StairEast", 58, -10, 28, 10, P.gold)
	sign(routes, "TO LEVEL 2", Vector3.new(-58, 12, 13), 12, 2.2, P.gold, 0)
	sign(routes, "TO LEVEL 2", Vector3.new(58, 12, -13), 12, 2.2, P.gold, math.pi)

	-- =====================================================================================
	-- ATRIUM CENTERPIECE: tiered fountain, palms, kiosks
	-- =====================================================================================
	cylinder(atrium, "FountainStep", Vector3.new(0, 0.4, 0), 31, 0.8, P.marble2, Enum.Material.Marble)
	cylinder(atrium, "FountainBasin", Vector3.new(0, 1.1, 0), 25, 1.8, P.white, Enum.Material.Marble)
	disc(atrium, "FountainWater", CFrame.new(0, 2.05, 0), 23, 0.1, P.blue, Enum.Material.Glass).Transparency = 0.35
	disc(atrium, "FountainGlow", CFrame.new(0, 0.9, 0), 32, 0.12, P.cyan, Enum.Material.Neon):SetAttribute("Pulse", 1)
	cylinder(atrium, "FountainPedestal", Vector3.new(0, 4.6, 0), 4.4, 5.6, P.white, Enum.Material.Marble)
	for i, tier in ipairs({ { 10, 8.4 }, { 6.6, 10.6 }, { 4, 12.2 } }) do
		cylinder(atrium, "FountainTier" .. i, Vector3.new(0, tier[2], 0), tier[1], 0.7, P.white, Enum.Material.Marble, false)
		disc(atrium, "TierWater", CFrame.new(0, tier[2] + 0.45, 0), tier[1] - 0.8, 0.08, P.cyan, Enum.Material.Glass).Transparency = 0.4
	end
	for i = 1, 8 do
		local angle = i * math.pi / 4
		artBeam(atrium, "WaterJet", Vector3.new(math.cos(angle) * 9, 2.3, math.sin(angle) * 9), Vector3.new(math.cos(angle) * 5.6, 5.8, math.sin(angle) * 5.6), 0.22, P.cyan, Enum.Material.Neon).Transparency = 0.35
		neon(atrium, "FountainLamp", math.cos(angle) * 14, 1.1, math.sin(angle) * 14, 0.5, 0.5, 0.5, i % 2 == 0 and P.magenta or P.cyan)
	end
	local crown = sphere(atrium, "FountainCrown", Vector3.new(0, 14, 0), Vector3.new(3, 3, 3), P.gold, Enum.Material.Metal)
	for i = 1, 4 do
		local angle = i * math.pi / 2 + math.pi / 4
		artBeam(atrium, "FountainSpike", Vector3.new(0, 14, 0), Vector3.new(math.cos(angle) * 2.2, 17.5, math.sin(angle) * 2.2), 0.3, P.gold, Enum.Material.Metal)
	end
	local spray = Instance.new("ParticleEmitter")
	spray.Name = "FountainSpray"
	spray.Rate = 22
	spray.Lifetime = NumberRange.new(1.2, 1.8)
	spray.Speed = NumberRange.new(5, 8)
	spray.SpreadAngle = Vector2.new(18, 18)
	spray.Acceleration = Vector3.new(0, -14, 0)
	spray.Size = NumberSequence.new(0.5, 0.1)
	spray.Transparency = NumberSequence.new(0.2, 1)
	spray.Color = ColorSequence.new(P.white, P.cyan)
	spray.LightEmission = 0.6
	spray.Parent = crown
	for _, c in ipairs({ { -36, -26 }, { 36, -26 }, { -36, 26 }, { 36, 26 } }) do
		cylinder(atrium, "PalmRing", Vector3.new(c[1], 0.7, c[2]), 8, 1.4, P.cream, Enum.Material.Concrete)
		cylinder(atrium, "PalmSoil", Vector3.new(c[1], 1.45, c[2]), 7, 0.1, P.soil, Enum.Material.Grass, false)
		palm(atrium, c[1], 1.4, c[2], 2.0, c[1] < 0 and 0.06 or -0.06)
	end
	for _, z in ipairs({ -19, 19 }) do bench(atrium, 0, 0, z, z < 0 and 0 or math.pi) end
	for _, c in ipairs({ { -VX + 3, -VZ + 1 }, { VX - 3, -VZ + 1 }, { -VX + 3, VZ - 1 }, { VX - 3, VZ - 1 } }) do
		local face = c[2] < 0 and 0 or math.pi
		local b = part(atrium, "AtriumBanner", Vector3.new(6, 18, 0.3), CFrame.new(c[1], 31, c[2]) * CFrame.Angles(0, face, 0), P.purple, Enum.Material.Fabric, false)
		b:SetAttribute("VisualPolish", true)
		surfaceText(b, Enum.NormalId.Back, "CATCH\nME IF\nYOU\nCAN", P.white, 30, 0.9, 0.9)
		neon(atrium, "BannerTrim", c[1], 22, c[2] + (c[2] < 0 and 0.2 or -0.2), 6.2, 0.2, 0.2, P.cyan)
	end
	for _, c in ipairs({ { -66, -39 }, { 66, 39 }, { -66, 39 }, { 66, -39 }, { -36, -50 }, { 36, 50 } }) do
		planter(decor, c[1], 0, c[2], 8, 0, true)
		palm(decor, c[1], 1.4, c[2], 1.2, 0.1)
	end
	for _, c in ipairs({ { -48, -39 }, { 48, 39 }, { -48, 39 }, { 48, -39 } }) do bench(decor, c[1], 0, c[2], c[2] < 0 and 0 or math.pi) end
	for _, c in ipairs({ { -58, 40, "SNACKS", P.coral }, { 58, -40, "TECH", P.cyan }, { -28, -50, "GIFTS", P.gold }, { 28, 50, "JUICE", P.green } }) do
		vaultTable(decor, c[1], 0, c[2], 8, 4, P.white, 0, c[4])
		sign(decor, c[3], Vector3.new(c[1], 6.4, c[2] + (c[2] < 0 and 2.8 or -2.8)), 6, 1.6, c[4], c[2] < 0 and 0 or math.pi)
		for _, dx in ipairs({ -3.6, 3.6 }) do art(decor, "CartPost", Vector3.new(0.25, 5, 0.25), Vector3.new(c[1] + dx, 4.1, c[2]), P.steel, Enum.Material.Metal) end
		art(decor, "CartCanopy", Vector3.new(9, 0.4, 5.4), Vector3.new(c[1], 7.2, c[2]), c[4], Enum.Material.Fabric)
	end
	for _, c in ipairs({ { -48, -53 }, { 48, 53 }, { -48, 53 }, { 48, -53 } }) do
		box(decor, "DirectoryPillar", c[1], 5, c[2], 1.2, 10, 3, P.navy, Enum.Material.Metal)
		sign(decor, "MALL MAP", Vector3.new(c[1] + (c[1] < 0 and 0.7 or -0.7), 5.5, c[2]), 2.6, 3.6, P.cyan, c[1] < 0 and math.pi / 2 or -math.pi / 2)
	end

	-- =====================================================================================
	-- STORES: ten enterable, themed shops. Each has a 20-stud front opening and offset side
	-- doors into its neighbours, so stores chain into loops and never trap a runner.
	-- =====================================================================================
	local boundariesX = { -132, -72, -24, 24, 72, 132 }
	local PAL = { P.coral, P.cyan, P.yellow, P.magenta, P.green, P.orange, P.blue, P.pink }
	local function storeCtx(def, folder)
		local north = def.row == "N"
		local fy = def.floor
		local c = { folder = folder, fy = fy, north = north, W = def.x2 - def.x1, D = D, accent = def.accent, color = def.color }
		function c.X(u) return def.x1 + u end
		function c.Z(v) return north and (-HZ - v) or (HZ + v) end
		function c.B(u, v, w, d, h, color, material, collide)
			return box(folder, "Prop", def.x1 + u, fy + h / 2, c.Z(v), w, h, d, color, material, collide)
		end
		function c.Vault(u, v, w, d, h, color, material)
			local p = c.B(u, v, w, d, h, color, material, true)
			p.Name = "VaultProp"
			p:SetAttribute("Vaultable", true)
			return p
		end
		function c.A(u, v, w, d, h, y, color, material)
			return art(folder, "Detail", Vector3.new(w, h, d), Vector3.new(def.x1 + u, fy + y, c.Z(v)), color, material)
		end
		-- Art box with an X-axis tilt and Y rotation (screens, ramps, lids).
		function c.R(u, v, y, w, d, h, tilt, color, material, yaw)
			return art(folder, "Detail", Vector3.new(w, h, d), CFrame.new(def.x1 + u, fy + y, c.Z(v)) * CFrame.Angles(0, yaw or 0, 0) * CFrame.Angles(math.rad(tilt or 0), 0, 0), color, material)
		end
		function c.N(u, v, w, d, h, y, color)
			return neon(folder, "Glow", def.x1 + u, fy + y, c.Z(v), w, h, d, color)
		end
		function c.Sphere(u, v, y, size, color, material)
			return sphere(folder, "Ball", Vector3.new(def.x1 + u, fy + y, c.Z(v)), Vector3.new(size, size, size), color, material)
		end
		function c.Cyl(u, v, y, dia, h, color, material, collide)
			return cylinder(folder, "Round", Vector3.new(def.x1 + u, fy + y, c.Z(v)), dia, h, color, material, collide)
		end
		function c.Shelf(u, v, sx, sz, h, color, accent, spine)
			return shelf(folder, def.x1 + u, fy, c.Z(v), sx, sz, h, color, accent, spine)
		end
		function c.Sign(text, u, v, y, w, h, color)
			return sign(folder, text, Vector3.new(def.x1 + u, fy + y, c.Z(v)), w, h, color, north and 0 or math.pi)
		end
		function c.Ring(u, v, y, radius, tiltX, color, segments)
			ring(folder, "Ring", CFrame.new(def.x1 + u, fy + y, c.Z(v)) * CFrame.Angles(math.rad(tiltX or 90), 0, 0), radius, 0.18, color, Enum.Material.Neon, segments or 14)
		end
		-- Merchandise models: every item is a handful of real shapes, never one block.
		function c.Sneaker(u, v, y, s, color, accent, yaw)
			local cf = CFrame.new(def.x1 + u, fy + y, c.Z(v)) * CFrame.Angles(0, yaw or 0, 0)
			art(folder, "SneakerSole", Vector3.new(0.95 * s, 0.22 * s, 2.7 * s), cf * CFrame.new(0, 0.11 * s, 0), P.white, Enum.Material.SmoothPlastic)
			art(folder, "SneakerUpper", Vector3.new(0.85 * s, 0.6 * s, 1.5 * s), cf * CFrame.new(0, 0.52 * s, 0.55 * s), color, Enum.Material.SmoothPlastic)
			sphere(folder, "SneakerToe", (cf * CFrame.new(0, 0.38 * s, -0.8 * s)).Position, Vector3.new(0.95 * s, 0.7 * s, 1.1 * s), color)
			art(folder, "SneakerStripe", Vector3.new(0.9 * s, 0.14 * s, 1.2 * s), cf * CFrame.new(0, 0.4 * s, 0.35 * s), accent, Enum.Material.Neon)
			art(folder, "SneakerTongue", Vector3.new(0.5 * s, 0.5 * s, 0.22 * s), cf * CFrame.new(0, 0.9 * s, 0.05 * s) * CFrame.Angles(math.rad(-25), 0, 0), P.white)
		end
		function c.Plush(u, v, y, s, color)
			c.Sphere(u, v, y + 0.9 * s, 1.8 * s, color)
			c.Sphere(u, v, y + 2.2 * s, 1.3 * s, color)
			c.Sphere(u - 0.55 * s, v, y + 2.9 * s, 0.5 * s, color)
			c.Sphere(u + 0.55 * s, v, y + 2.9 * s, 0.5 * s, color)
			c.Sphere(u, v + (north and 0.5 or -0.5) * s, y + 2.1 * s, 0.5 * s, P.white)
		end
		-- Colored book spines in rows on a shelf, running along "u" or "v".
		function c.Books(u, v, len, along, height, rows)
			rows = rows or math.floor(height / 2.4)
			local count = math.max(3, math.floor(len / 1.25))
			for r = 1, rows do
				for i = 1, count do
					local off = -len / 2 + (i - 0.5) * len / count
					local h = 1.4 + ((i * 7 + r * 3) % 5) * 0.18
					local color = PAL[(i + r * 3) % #PAL + 1]
					if along == "u" then
						art(folder, "Book", Vector3.new(len / count * 0.8, h, 1.0), Vector3.new(def.x1 + u + off, fy + r * 2.3 + h / 2 - 1.0, c.Z(v)), color, Enum.Material.SmoothPlastic)
					else
						art(folder, "Book", Vector3.new(1.0, h, len / count * 0.8), Vector3.new(def.x1 + u, fy + r * 2.3 + h / 2 - 1.0, c.Z(v + off)), color, Enum.Material.SmoothPlastic)
					end
				end
			end
		end
		function c.TV(u, v, y, w, h, color, yaw)
			local cf = CFrame.new(def.x1 + u, fy + y, c.Z(v)) * CFrame.Angles(0, yaw or 0, 0)
			art(folder, "TVFrame", Vector3.new(w + 0.3, h + 0.3, 0.4), cf, P.ink, Enum.Material.Metal)
			local screen = art(folder, "TVScreen", Vector3.new(w, h, 0.1), cf * CFrame.new(0, 0, 0.22), color, Enum.Material.Neon)
			screen.Transparency = 0.15
		end
		function c.Rack(u, v, len, along, colors)
			local cf = CFrame.new(def.x1 + u, fy, c.Z(v)) * CFrame.Angles(0, along == "v" and math.pi / 2 or 0, 0)
			art(folder, "RackBar", Vector3.new(len, 0.25, 0.25), cf * CFrame.new(0, 4.8, 0), P.steel, Enum.Material.Metal)
			for _, e in ipairs({ -len / 2, len / 2 }) do
				art(folder, "RackPost", Vector3.new(0.3, 4.8, 0.3), cf * CFrame.new(e, 2.4, 0), P.steel, Enum.Material.Metal)
				art(folder, "RackFoot", Vector3.new(0.4, 0.2, 1.8), cf * CFrame.new(e, 0.1, 0), P.ink, Enum.Material.Metal)
			end
			local n = math.floor(len / 1.1)
			for i = 1, n do
				art(folder, "Garment", Vector3.new(0.9, 2.4 + (i % 3) * 0.3, 0.35), cf * CFrame.new(-len / 2 + (i - 0.5) * len / n, 3.4, 0), colors[(i - 1) % #colors + 1], Enum.Material.Fabric)
			end
		end
		return c
	end

	local themes = {}
	function themes.sneaker(c)
		local W = c.W
		-- Product wall: four lit bays of sneakers on glowing ledges.
		for i = 0, 3 do
			local u = 6 + i * (W - 12) / 3
			c.Shelf(u, 39, 11, 1.4, 11, P.ink, i % 2 == 0 and P.cyan or P.magenta)
			for row = 1, 3 do
				c.A(u, 37.6, 10, 2, 0.2, row * 2.9, P.white, Enum.Material.SmoothPlastic)
				for k = 0, 2 do
					c.Sneaker(u - 3.2 + k * 3.2, 37.6, row * 2.9 + 0.1, 0.9, PAL[(i + row + k) % #PAL + 1], PAL[(i + k * 2) % #PAL + 1], math.pi)
				end
			end
		end
		-- Showcase podium with a giant hero sneaker and a halo ring.
		c.Cyl(W / 2, 22, 1.2, 10, 2.4, P.white, Enum.Material.Marble)
		c.Cyl(W / 2, 22, 2.45, 10.6, 0.12, P.cyan, Enum.Material.Neon, false)
		c.Sneaker(W / 2, 22, 2.5, 2.2, P.coral, P.yellow, math.rad(35))
		c.Ring(W / 2, 22, 7.5, 5.5, 90, P.cyan, 16)
		-- Benches and shoe-box crates: vault props with clear lanes between them.
		for _, u in ipairs({ 8, W - 8 }) do
			c.Vault(u, 20, 9, 2.8, 1.8, P.navy, Enum.Material.SmoothPlastic)
			c.A(u, 20, 9, 2.8, 0.4, 1.9, P.cream, Enum.Material.Fabric)
			c.Sneaker(u - 2, 20, 2.1, 0.8, PAL[(u) % #PAL + 1], P.white, math.rad(-20))
		end
		for _, spec in ipairs({ { 7, 33 }, { W - 7, 9 } }) do
			c.Vault(spec[1], spec[2], 4.6, 4.6, 3.2, P.orange, Enum.Material.SmoothPlastic)
			c.A(spec[1], spec[2], 4.7, 4.7, 0.5, 3.2, P.coral, Enum.Material.SmoothPlastic)
		end
		-- Side walls: shoe-box stacks and posters.
		for _, side in ipairs({ 0.9, W - 0.9 }) do
			local inward = side < 5 and 1 or -1
			for _, v in ipairs({ 10, 20, 30 }) do
				c.Shelf(side, v, 1.2, 7, 7.4, P.ink, P.cyan)
				for row = 0, 2 do for k = -1, 1 do
					c.A(side + inward * 1.2, v + k * 2.2, 1.3, 1.9, 0.8, row * 2.3 + 1.6, PAL[(row + k + v) % #PAL + 1], Enum.Material.SmoothPlastic)
				end end
			end
			c.A(side + inward * 0.2, 25, 0.2, 7, 5, 11.5, P.ink, Enum.Material.SmoothPlastic)
			c.N(side + inward * 0.35, 25, 0.1, 6.4, 4.4, 11.5, inward > 0 and P.magenta or P.cyan)
		end
		c.Sign("SNKR", W / 2, 39.2, 13.2, 14, 3, P.white)
	end

	function themes.clothing(c)
		local W = c.W
		local colors = { P.coral, P.cyan, P.white, P.ink, P.yellow, P.magenta }
		for _, v in ipairs({ 10, 22, 34 }) do
			c.Rack(4, v, 9, "v", colors)
			c.Rack(W - 4, v, 9, "v", { P.blue, P.white, P.coral, P.green })
		end
		c.Rack(W / 2 - 14, 30, 8, "u", { P.yellow, P.ink, P.cyan })
		c.Rack(W / 2 + 14, 30, 8, "u", { P.magenta, P.white, P.ink })
		for i, u in ipairs({ 9, 19, W - 19, W - 9 }) do
			mannequin(c.folder, c.X(u), c.fy, c.Z(37), colors[i])
			art(c.folder, "Jacket", Vector3.new(1.9, 1.4, 1.2), Vector3.new(c.X(u), c.fy + 2.7, c.Z(37)), PAL[i + 2], Enum.Material.Fabric)
		end
		for _, u in ipairs({ 19, W - 19 }) do
			c.Vault(u, 16, 10, 4.4, 3, P.white, Enum.Material.SmoothPlastic)
			for k = 0, 3 do c.A(u - 3.6 + k * 2.4, 16, 2, 2.6, 0.9 + (k % 2) * 0.4, 3.5, colors[(k + 1) % #colors + 1], Enum.Material.Fabric) end
		end
		for i = 0, 3 do
			local u = 8 + i * (W - 16) / 3
			c.A(u, 39.3, 4.6, 0.3, 8, 6, P.gold, Enum.Material.Metal)
			c.A(u, 39.0, 4.0, 0.2, 7.2, 6, P.glass, Enum.Material.Glass).Transparency = 0.35
		end
		for i = 0, 2 do
			c.A(1.5, 26 + i * 4.4, 0.3, 3.8, 7.6, 4.4, PAL[i + 3], Enum.Material.Fabric)
			c.A(1.5, 26 + i * 4.4 + 2.1, 0.5, 0.4, 8.2, 4.4, P.gold, Enum.Material.Metal)
		end
		c.Sign("NEXUS", W / 2, 39.3, 11.6, 14, 3, P.white)
	end

	function themes.electronics(c)
		local W = c.W
		for i = 0, 5 do c.TV(5 + i * (W - 10) / 5, 39.4, 8.2, 6.4, 3.8, ({ P.blue, P.cyan, P.magenta, P.green, P.purple, P.coral })[i + 1], c.north and 0 or math.pi) end
		for _, spec in ipairs({ { 9, 12 }, { W - 9, 12 }, { 9, 27 }, { W - 9, 27 } }) do
			local u, v = spec[1], spec[2]
			c.Vault(u, v, 8.4, 4.2, 3.2, P.white, Enum.Material.SmoothPlastic)
			for k = -1, 1, 2 do
				c.A(u + k * 2.2, v, 2.4, 1.7, 0.16, 3.3, P.steel, Enum.Material.Metal)
				c.R(u + k * 2.2, v + (c.north and -0.8 or 0.8), 4.1, 2.4, 0.1, 1.6, c.north and -15 or 15, P.cyan, Enum.Material.Neon)
			end
			for k = 0, 3 do
				c.A(u - 3 + k * 0.8, v + 1.4, 0.55, 1.0, 0.1, 3.3, P.ink, Enum.Material.SmoothPlastic)
				c.N(u - 3 + k * 0.8, v + 1.4, 0.45, 0.8, 0.05, 3.36, PAL[k + 1])
			end
			c.A(u + 2.8, v + 1.4, 1.6, 0.3, 0.25, 3.5, P.ink, Enum.Material.SmoothPlastic)
			c.Cyl(u + 2.1, v + 1.4, 3.7, 0.9, 0.4, P.magenta, Enum.Material.SmoothPlastic, false)
			c.Cyl(u + 3.5, v + 1.4, 3.7, 0.9, 0.4, P.magenta, Enum.Material.SmoothPlastic, false)
		end
		for _, u in ipairs({ 7, W - 7 }) do
			local inward = u < 20 and 1 or -1
			c.Vault(u, 35, 8, 3.6, 3, P.ink, Enum.Material.Metal)
			c.A(u, 35.8, 6, 0.4, 2.6, 5, P.ink, Enum.Material.Metal)
			c.A(u, 35.55, 5.6, 0.1, 2.2, 5, PAL[(u) % #PAL + 1], Enum.Material.Neon).Transparency = 0.1
			c.N(u, 33.9, 3.4, 0.9, 0.08, 3.1, P.magenta)
			c.A(u + inward * 3.4, 35.4, 1.3, 1.9, 2.6, 4.4, P.ink, Enum.Material.Metal)
			c.N(u + inward * 4.05, 35.4, 0.08, 1.4, 2.2, 4.4, P.cyan)
			c.A(u, 31, 2.2, 2.2, 0.4, 1.7, P.coral, Enum.Material.Fabric)
			c.A(u, 30.2, 2.2, 0.3, 2.4, 2.9, P.coral, Enum.Material.Fabric)
		end
		c.Cyl(W / 2, 21, 2.2, 5, 4.4, P.ink, Enum.Material.Metal)
		c.N(W / 2, 21, 5.2, 5.2, 0.1, 4.45, P.cyan)
		c.Ring(W / 2, 21, 7.5, 2.6, 80, P.cyan, 14)
		c.Sign("TECH+", W / 2, 39.3, 12.4, 14, 3, P.cyan)
	end

	function themes.toy(c)
		local W = c.W
		for i = 1, 7 do c.A(W / 2, 4 + i * 4.8, W - 4, 1.4, 0.08, 0.14, PAL[i], Enum.Material.SmoothPlastic) end
		-- Ball pit with a gap in its front wall.
		c.B(10, 24, 8, 0.8, 1.6, P.pink); c.B(10, 38, 14, 0.8, 1.6, P.pink)
		c.B(3.4, 31, 0.8, 14, 1.6, P.pink); c.B(16.6, 31, 0.8, 14, 1.6, P.pink)
		for i = 1, 16 do c.Sphere(5 + (i % 5) * 2.4, 26.5 + math.floor(i / 5) * 3, 1.3, 1.9, PAL[(i % #PAL) + 1]) end
		-- Alphabet blocks (vaultable) with real lettering.
		for i, spec in ipairs({ { 30, 12, "A" }, { 40, 22, "B" }, { 22, 10, "C" } }) do
			local block = c.Vault(spec[1], spec[2], 4, 4, 4, PAL[i * 2], Enum.Material.SmoothPlastic)
			surfaceText(block, Enum.NormalId.Front, spec[3], P.white, 40, 0.8, 0.8)
			surfaceText(block, Enum.NormalId.Back, spec[3], P.white, 40, 0.8, 0.8)
		end
		-- Plush shelves.
		for i = 0, 4 do
			local u = 6 + i * (W - 12) / 4
			c.Shelf(u, 39, 9, 1.4, 9.5, P.white, PAL[i + 1])
			for row = 1, 3 do c.A(u, 37.6, 8.6, 2, 0.2, row * 2.9, P.cream, Enum.Material.SmoothPlastic) for k = -1, 1 do c.Plush(u + k * 2.8, 37.6, row * 2.9 + 0.1, 0.55, PAL[(i + row + k) % #PAL + 1]) end end
		end
		-- Giant teddy bear landmark.
		c.Sphere(W - 9, 30, 3.4, 6.4, P.wood); c.Sphere(W - 9, 30, 7.4, 4.2, P.wood)
		c.Sphere(W - 10.9, 30, 9.5, 1.5, P.wood); c.Sphere(W - 7.1, 30, 9.5, 1.5, P.wood)
		c.Sphere(W - 9, 28.2, 7.1, 1.6, P.cream); c.Sphere(W - 9, 27.7, 7.3, 0.6, P.ink)
		c.Sphere(W - 12.5, 28.5, 4.4, 2.2, P.wood); c.Sphere(W - 5.5, 28.5, 4.4, 2.2, P.wood)
		-- Train set looping around a toy town.
		c.Ring(W - 14, 12, 0.5, 6, 90, P.wood, 16)
		for i = 0, 3 do c.A(W - 14 + 6, 12 - i * 2.2, 1.6, 2, 1.6, 1.3, PAL[i + 2], Enum.Material.SmoothPlastic) end
		-- Lollipop sculptures.
		for i, u in ipairs({ 21, 34, 46 }) do
			c.Cyl(u, 35, 3, 0.4, 6, P.white, Enum.Material.SmoothPlastic, false)
			local candy = c.Cyl(u, 35, 6.8, 3.4, 0.5, PAL[i + 3], Enum.Material.SmoothPlastic, false)
			c.Cyl(u, 35, 7.1, 2.2, 0.3, P.white, Enum.Material.SmoothPlastic, false)
			candy.Name = "Candy"
		end
		c.Sign("TOYS", W / 2, 39.3, 12.6, 15, 3, P.yellow)
	end

	function themes.book(c)
		local W = c.W
		for _, u in ipairs({ 9, W - 9 }) do
			c.Shelf(u, 19, 1.8, 24, 10, P.wood, P.gold)
			c.Books(u - 1.1, 19, 24, "v", 10, 4)
			c.Books(u + 1.1, 19, 24, "v", 10, 4)
		end
		for i = 0, 2 do
			local u = 8 + i * (W - 16) / 2
			c.Shelf(u, 39, 12, 1.6, 11.5, P.wood, P.gold)
			c.Books(u, 38.1, 11, "u", 11.5, 4)
		end
		-- Reading nook: round table (vaultable) with a lamp and two armchairs.
		c.Vault(W / 2, 28, 6, 6, 3.2, P.cream, Enum.Material.Wood)
		c.A(W / 2, 28, 5.6, 4, 0.2, 3.3, P.white, Enum.Material.SmoothPlastic)
		c.Cyl(W / 2 + 1.6, 28, 5.2, 0.3, 3.4, P.gold, Enum.Material.Metal, false)
		c.Cyl(W / 2 + 1.6, 28, 7.2, 1.8, 1.2, P.cream, Enum.Material.Fabric, false)
		for _, d in ipairs({ { -5.5, 28 }, { 5.5, 28 } }) do
			c.A(W / 2 + d[1], d[2], 3.2, 3.2, 1.2, 1.2, P.coral, Enum.Material.Fabric)
			c.A(W / 2 + d[1] + (d[1] < 0 and -1.4 or 1.4), d[2], 0.6, 3.2, 2.6, 2.3, P.coral, Enum.Material.Fabric)
		end
		-- Display island with face-out new releases.
		c.Vault(W / 2, 12, 9, 4, 3, P.wood, Enum.Material.Wood)
		for k = -2, 2 do c.R(W / 2 + k * 1.7, 12, 3.9, 1.4, 0.15, 2, 70, PAL[(k + 3) % #PAL + 1], Enum.Material.SmoothPlastic) end
		c.A(W - 8, 7, 2.4, 3, 9, 4.5, P.wood, Enum.Material.Wood)
		c.Sign("PAGES", W / 2, 39.3, 13.2, 12, 2.8, P.gold)
	end

	function themes.convenience(c)
		local W = c.W
		-- Glass-door refrigerators along the back wall, stocked with drinks.
		for i = 0, 3 do
			local u = 6 + i * (W - 12) / 3
			c.B(u, 39, 10, 2, 9, P.ink, Enum.Material.Metal)
			c.A(u, 37.9, 9, 0.2, 7.8, 4.6, P.glass, Enum.Material.Glass).Transparency = 0.55
			for row = 1, 3 do
				c.A(u, 38, 8.6, 1.2, 1.4, row * 2.2 + 0.4, ({ P.red, P.cyan, P.yellow, P.green })[(i + row) % 4 + 1], Enum.Material.SmoothPlastic)
				c.N(u, 37.6, 8.8, 0.1, 0.1, row * 2.2 - 0.5, P.white)
			end
		end
		-- Low snack aisles (vaultable) with product stripes and price tags.
		for _, spec in ipairs({ { 12, 16 }, { W - 12, 24 } }) do
			c.Vault(spec[1], spec[2], 13, 2.2, 4.2, P.white, Enum.Material.SmoothPlastic)
			for k = 0, 3 do c.A(spec[1] - 5 + k * 3.3, spec[2] + (c.north and 1.15 or -1.15), 2.8, 0.2, 1.1, 3.0, PAL[(k + spec[1]) % #PAL + 1], Enum.Material.SmoothPlastic) end
			c.N(spec[1], spec[2], 12.6, 2.4, 0.12, 4.25, P.yellow)
		end
		-- Checkout with register, candy rack and a basket stack.
		c.B(W - 7, 7, 9, 3, 3.4, P.white, Enum.Material.SmoothPlastic)
		c.A(W - 7, 7, 8.6, 2.6, 0.3, 3.5, P.ink, Enum.Material.SmoothPlastic)
		c.A(W - 9, 7, 1.8, 1.4, 1.2, 4.2, P.ink, Enum.Material.Metal)
		c.N(W - 9, 7 + (c.north and 0.7 or -0.7), 1.4, 0.05, 0.6, 4.4, P.green)
		for k = 0, 2 do c.A(W - 4.5, 7, 1.2, 1.2, 1.1, 4.0 + k * 0.5, PAL[k + 2], Enum.Material.SmoothPlastic) end
		-- Freezer chest and a slushie machine.
		c.Vault(6, 8, 6, 3.4, 2.4, P.cyan, Enum.Material.SmoothPlastic)
		c.A(6, 8, 5.6, 3, 0.2, 2.5, P.glass, Enum.Material.Glass).Transparency = 0.4
		c.B(6, 22, 3.2, 3.2, 6, P.ink, Enum.Material.Metal)
		for k = 0, 2 do c.A(6, 22, 2.6, 2.6, 1.3, 2 + k * 1.5, PAL[k * 2 + 1], Enum.Material.Neon).Transparency = 0.3 end
		c.N(W / 2, 39.1, 16, 0.1, 0.5, 11.4, P.red)
		c.Sign("QUIK", W / 2, 39.3, 13.2, 12, 3, P.yellow)
	end

	function themes.sports(c)
		local W = c.W
		-- Half basketball court with a hoop and a ball rack.
		c.A(W - 14, 24, 18, 15, 0.1, 0.12, P.orange, Enum.Material.SmoothPlastic)
		c.A(W - 14, 24, 17, 0.25, 0.12, 0.2, P.white, Enum.Material.SmoothPlastic)
		c.Ring(W - 14, 24, 0.25, 4, 90, P.white, 12)
		c.B(W - 3, 24, 0.8, 0.8, 10.4, P.steel, Enum.Material.Metal)
		c.A(W - 3.6, 24, 0.3, 6.4, 4, 11.2, P.white, Enum.Material.Glass).Transparency = 0.3
		c.Ring(W - 5.2, 24, 9.6, 1.1, 90, P.orange, 10)
		for i = 0, 5 do c.Sphere(7 + i * 1.9, 5, 0.9 + (i % 2) * 1.7, 1.8, P.orange) end
		c.Sphere(8, 5, 3.8, 1.8, P.orange)
		-- Jersey wall.
		for i = 0, 5 do
			local u = 6 + i * (W - 12) / 5
			c.A(u, 39.3, 4, 0.3, 5, 7, P.ink, Enum.Material.SmoothPlastic)
			c.A(u, 39.0, 3.2, 0.2, 4, 7, PAL[i + 1], Enum.Material.Fabric)
			c.A(u, 38.9, 1.2, 0.2, 4, 7, P.white, Enum.Material.Fabric)
		end
		-- Treadmills and parkour boxes (all vaultable).
		for _, v in ipairs({ 12, 26 }) do
			c.Vault(8, v, 4, 8, 3.2, P.ink, Enum.Material.Metal)
			c.N(8, v, 3.4, 7.4, 0.1, 3.25, P.cyan)
			c.A(8, v - 3.6, 3.6, 0.6, 2.2, 4.4, P.ink, Enum.Material.Metal)
		end
		for i, h in ipairs({ 2.2, 3.4, 4.4 }) do c.Vault(18 + i * 8, 10 + i * 5, 6.6, 5.4, h, i == 2 and P.orange or P.blue, Enum.Material.SmoothPlastic) end
		-- Climbing wall with colored holds, boxing bag, mannequins in team kit.
		c.A(20, 39.4, 22, 0.4, 10, 6.4, P.ink, Enum.Material.SmoothPlastic)
		for i = 1, 14 do c.Sphere(11 + (i * 7) % 20, 39.0, 2 + (i * 5) % 9, 0.9, PAL[i % #PAL + 1]) end
		c.Cyl(W - 8, 36, 7.4, 1.6, 4, P.red, Enum.Material.Fabric, false)
		artBeam(c.folder, "BagChain", Vector3.new(c.X(W - 8), c.fy + 14, c.Z(36)), Vector3.new(c.X(W - 8), c.fy + 9.4, c.Z(36)), 0.12, P.steel, Enum.Material.Metal)
		for i, u in ipairs({ 36, 44 }) do mannequin(c.folder, c.X(u), c.fy, c.Z(34), PAL[i + 4]) end
		c.Sign("APEX", W / 2, 39.4, 13.6, 14, 2.8, P.orange)
	end

	function themes.jewelry(c)
		local W = c.W
		-- Glass display cases with rings and necklaces (vaultable), arranged as a U.
		for i, spec in ipairs({ { 8, 10, 3, 10 }, { W - 8, 10, 3, 10 }, { W / 2 - 9, 30, 10, 3 }, { W / 2 + 9, 30, 10, 3 }, { 8, 28, 3, 8 }, { W - 8, 28, 3, 8 } }) do
			c.Vault(spec[1], spec[2], spec[3], spec[4], 3.4, P.white, Enum.Material.SmoothPlastic)
			c.A(spec[1], spec[2], spec[3] - 0.4, spec[4] - 0.4, 0.3, 3.7, P.glass, Enum.Material.Glass).Transparency = 0.45
			for k = 0, 2 do
				c.Sphere(spec[1] + (spec[3] > spec[4] and (k - 1) * 2.4 or 0), spec[2] + (spec[3] > spec[4] and 0 or (k - 1) * 2.4), 3.7, 0.7, i % 2 == 0 and P.cyan or P.pink, Enum.Material.Glass)
				c.Cyl(spec[1] + (spec[3] > spec[4] and (k - 1) * 2.4 or 0), spec[2] + (spec[3] > spec[4] and 0 or (k - 1) * 2.4), 3.55, 0.8, 0.2, P.gold, Enum.Material.Metal, false)
			end
			c.N(spec[1], spec[2], 0.8, 0.8, 0.12, 3.5, P.gold)
		end
		-- Chandelier: three neon rings with hanging crystals.
		for i, r in ipairs({ 6, 4, 2 }) do c.Ring(W / 2, 20, 11.6 - i * 0.7, r, 90, i == 2 and P.cyan or P.gold, 16) end
		for i = 1, 10 do
			local a = i * math.pi / 5
			c.A(W / 2 + math.cos(a) * 6, 20 + math.sin(a) * 6, 0.5, 0.5, 1.4, 10.4, P.glass, Enum.Material.Glass)
		end
		artBeam(c.folder, "ChandelierRod", Vector3.new(c.X(W / 2), c.fy + 14.6, c.Z(20)), Vector3.new(c.X(W / 2), c.fy + 11.2, c.Z(20)), 0.2, P.gold, Enum.Material.Metal)
		-- Display busts on pedestals along the back wall, velvet drapes and a mirror.
		for i, u in ipairs({ 7, 17, W - 17, W - 7 }) do
			c.Cyl(u, 38, 1.4, 2.6, 2.8, P.white, Enum.Material.Marble)
			c.Sphere(u, 38, 4, 1.8, P.cream)
			c.A(u, 38, 2.2, 0.4, 0.5, 3.2, P.gold, Enum.Material.Metal)
			c.Sphere(u, 38, 3.0, 0.7, i % 2 == 0 and P.cyan or P.pink, Enum.Material.Glass)
		end
		c.A(W / 2, 39.4, 12, 0.3, 10, 6.5, P.gold, Enum.Material.Metal)
		c.A(W / 2, 39.1, 11, 0.2, 9, 6.5, P.glass, Enum.Material.Glass).Transparency = 0.35
		for _, u in ipairs({ 2, W - 2 }) do c.A(u, 38, 2.6, 2, 11, 6.5, P.purple, Enum.Material.Fabric) end
		c.Sign("LUXE", W / 2, 39.4, 13.2, 12, 2.8, P.gold)
	end

	function themes.beauty(c)
		local W = c.W
		-- Vanity stations: counter, round lit mirror, stool.
		for _, u in ipairs({ 9, W / 2, W - 9 }) do
			c.Vault(u, 14, 7, 3.2, 3.2, P.pink, Enum.Material.SmoothPlastic)
			c.A(u, 14, 6.6, 2.8, 0.2, 3.3, P.white, Enum.Material.SmoothPlastic)
			c.Ring(u, 15.8, 6.4, 2.2, 0, P.magenta, 14)
			c.A(u, 15.9, 3.6, 0.2, 3.6, 6.4, P.glass, Enum.Material.Glass).Transparency = 0.3
			c.Cyl(u, 11, 1.2, 1.8, 2.4, P.coral, Enum.Material.Fabric, false)
			for k = -1, 1 do c.Cyl(u + k * 1.6, 14, 4.0, 0.6, 1.2, PAL[(k + u) % #PAL + 1], Enum.Material.Glass, false) end
		end
		-- Perfume wall: bottles in three rows.
		for i = 0, 3 do
			local u = 6 + i * (W - 12) / 3
			c.Shelf(u, 39, 10, 1.4, 10, P.white, P.magenta)
			for row = 1, 3 do
				c.A(u, 37.8, 9, 1.8, 0.2, row * 2.9, P.pink, Enum.Material.SmoothPlastic)
				for k = -1, 1 do
					local col = PAL[(i + row + k + 8) % #PAL + 1]
					c.Cyl(u + k * 2.8, 37.8, row * 2.9 + 1.0, 1.5, 1.8, col, Enum.Material.Glass, false)
					c.Cyl(u + k * 2.8, 37.8, row * 2.9 + 2.1, 0.7, 0.5, P.gold, Enum.Material.Metal, false)
				end
			end
		end
		-- Giant lipstick sculptures and pastel balloons.
		for i, u in ipairs({ 5, W - 5 }) do
			c.Cyl(u, 28, 3.4, 2.2, 6.8, P.magenta, Enum.Material.SmoothPlastic, true)
			c.Cyl(u, 28, 7.8, 1.8, 2.4, i == 1 and P.red or P.coral, Enum.Material.SmoothPlastic, false)
			c.Cyl(u, 28, 9.2, 1.8, 0.8, P.gold, Enum.Material.Metal, false)
		end
		for i = 1, 8 do c.Sphere(W / 2 - 14 + i * 3.4, 24 + (i % 3) * 3, 12.2 + (i % 2) * 0.8, 1.8, PAL[(i * 3) % #PAL + 1]) end
		c.Sign("GLOW", W / 2, 39.4, 13.2, 12, 2.8, P.pink)
	end

	local function buildStore(def)
		local folder = Instance.new("Folder")
		folder.Name = def.name
		folder.Parent = storesF
		local north = def.row == "N"
		local fy = def.floor
		local ceil = fy == 0 and F2 - 1.2 or 30
		local frontZ = north and -HZ or HZ
		local dir = north and -1 or 1
		local W = def.x2 - def.x1
		local cx = (def.x1 + def.x2) / 2
		local faceRot = north and 0 or math.pi
		if not def.enter then
			-- Dressed storefront: a solid block with glazing, display lighting, and a bold sign.
			box(folder, "ShopBlock", cx, fy + (ceil - fy) / 2, frontZ + dir * D / 2, W - 1, ceil - fy, D, P.white, Enum.Material.Concrete)
			box(folder, "ShopPlinth", cx, fy + 0.6, frontZ - dir * 0.5, W - 1, 1.2, 1.2, def.color, Enum.Material.Marble, false):SetAttribute("VisualPolish", true)
			local panes = W > 50 and 4 or 3
			for i = 0, panes - 1 do
				local gx = def.x1 + 4 + (i + 0.5) * (W - 8) / panes
				local pw = (W - 8) / panes - 2
				glassBox(folder, "DisplayGlass", gx, fy + 6.4, frontZ - dir * 0.2, pw, 9, 0.3, 0.35, false, P.glass)
				neon(folder, "DisplayGlow", gx, fy + 11.2, frontZ - dir * 0.55, pw, 0.2, 0.2, i % 2 == 0 and def.accent or P.gold)
				art(folder, "DisplayBox", Vector3.new(3, 3, 1), Vector3.new(gx, fy + 2.8, frontZ - dir * 1.4), def.color, Enum.Material.SmoothPlastic)
				mannequin(folder, gx, fy + 1.2, frontZ - dir * 2.2, i % 2 == 0 and def.accent or P.white)
			end
			sign(folder, def.sign, Vector3.new(cx, fy + 13, frontZ - dir * 0.6), math.min(W - 8, 24), 3.2, def.accent, faceRot)
			return folder
		end
		local c = storeCtx(def, folder)
		art(folder, "Carpet", Vector3.new(W - 1.2, 0.1, D - 1), Vector3.new(cx, fy + 0.1, frontZ + dir * D / 2), def.color:Lerp(P.white, 0.4), Enum.Material.Fabric)
		art(folder, "CarpetBorder", Vector3.new(W - 1.2, 0.12, 1), Vector3.new(cx, fy + 0.11, frontZ + dir * 3), def.accent, Enum.Material.SmoothPlastic)
		for i = 1, 4 do ceilingStrip(folder, cx, ceil - 0.2, frontZ + dir * (6 + i * 7.5), W - 8, 0.8, i % 2 == 0 and def.accent or nil) end
		-- Front: kick wall, glazing either side of the opening, and a header band.
		local open = 20
		for _, side in ipairs({ -1, 1 }) do
			local span = W / 2 - open / 2
			local mid = cx + side * (open / 2 + span / 2)
			box(folder, "KickWall", mid, fy + 0.6, frontZ, span, 1.2, 0.8, def.color, Enum.Material.Marble)
			glassBox(folder, "ShopWindow", mid, fy + 6.6, frontZ, span - 0.6, 10, 0.3, 0.45, true, P.glass)
			artBeam(folder, "Mullion", Vector3.new(mid, fy + 1.2, frontZ), Vector3.new(mid, fy + 11.6, frontZ), 0.3, def.accent, Enum.Material.Metal)
			neon(folder, "OpeningGlow", cx + side * (open / 2 + 0.2), fy + 6, frontZ, 0.2, 10.4, 0.5, def.accent)
		end
		neon(folder, "OpeningTopGlow", cx, fy + 11.4, frontZ, open + 0.6, 0.25, 0.5, def.accent)
		box(folder, "HeaderBand", cx, (fy + 11.6 + ceil) / 2, frontZ, W, ceil - fy - 11.6, 0.8, P.white, Enum.Material.Concrete)
		sign(folder, def.sign, Vector3.new(cx, fy + 13, frontZ - dir * 0.6), 18, 3.2, def.accent, faceRot)
		local blade = box(folder, "BladeSign", def.x1 + 1.5, fy + 8, frontZ - dir * 1.8, 0.4, 5, 3, P.ink, Enum.Material.SmoothPlastic, false)
		blade:SetAttribute("VisualPolish", true)
		surfaceText(blade, Enum.NormalId.Right, string.sub(def.sign, 1, 1), def.accent, 40, 0.9, 0.9)
		surfaceText(blade, Enum.NormalId.Left, string.sub(def.sign, 1, 1), def.accent, 40, 0.9, 0.9)
		light(folder, Vector3.new(cx, ceil - 0.4, frontZ + dir * 18), def.accent, 0.8, 44)
		local theme = themes[def.theme]
		if theme then theme(c) end
		return folder
	end

	local slotX = {}
	for i = 1, 5 do slotX[i] = { boundariesX[i], boundariesX[i + 1] } end
	local layout = {
		{ floor = 0, row = "N", list = {
			{ "TOYS", "TOYS", "toy", P.coral, P.yellow, true }, { "SNKR", "SNKR", "sneaker", P.navy, P.cyan, true },
			{ "TECH", "TECH+", "electronics", P.ink, P.blue, true }, { "VOLT", "VOLT", nil, P.purple, P.cyan, false },
			{ "AURORA", "AURORA", nil, P.teal, P.gold, false } } },
		{ floor = 0, row = "S", list = {
			{ "NEXUS", "NEXUS", "clothing", P.navy, P.white, true }, { "PAGES", "PAGES", "book", P.wood, P.gold, true },
			{ "QUIK", "QUIK", "convenience", P.cream, P.coral, true }, { "NOVA", "NOVA", nil, P.magenta, P.cyan, false },
			{ "MINT", "MINT", nil, P.green, P.white, false } } },
		{ floor = F2, row = "N", list = {
			{ "APEX", "APEX", "sports", P.blue, P.orange, true }, { "LUXE", "LUXE", "jewelry", P.purple, P.gold, true },
			{ "GLOW", "GLOW", "beauty", P.pink, P.magenta, true }, { "PRIME", "PRIME", nil, P.ink, P.white, false },
			{ "DRIP", "DRIP", nil, P.coral, P.white, false } } },
		{ floor = F2, row = "S", list = {
			{ "ORBIT", "ORBIT", nil, P.teal, P.white, false }, { "PULSE", "PULSE", nil, P.magenta, P.yellow, false },
			{ "ECHO", "ECHO", nil, P.navy, P.cyan, false }, { "HALO", "HALO", nil, P.gold, P.white, false },
			{ "AXIS", "AXIS", nil, P.green, P.cyan, false } } },
	}
	for _, rowDef in ipairs(layout) do
		local fy, north = rowDef.floor, rowDef.row == "N"
		local ceil = fy == 0 and F2 - 1.2 or 30
		local z1, z2 = north and -OZ or HZ, north and -HZ or OZ
		local stores = {}
		for i, entry in ipairs(rowDef.list) do
			local def = { name = rowDef.row .. fy .. "_" .. entry[1], sign = entry[2], theme = entry[3], color = entry[4], accent = entry[5], enter = entry[6],
				x1 = slotX[i][1], x2 = slotX[i][2], floor = fy, row = rowDef.row }
			stores[i] = def
			buildStore(def)
		end
		-- Dividing walls: enterable neighbours connect with an offset door (alternating depth).
		for i = 2, 5 do
			local x = boundariesX[i]
			local gaps = {}
			if stores[i - 1].enter and stores[i].enter then
				local v = (i % 2 == 0) and 10 or 30
				local zc = north and (-HZ - v) or (HZ + v)
				table.insert(gaps, { c = zc, w = 10, h = 11 })
				neon(storesF, "DoorGlow", x, fy + 11.2, zc, 0.3, 0.2, 10.4, stores[i].accent)
			end
			wall(storesF, "DividerWall", "z", x, z1, z2, fy, ceil, 0.8, P.white, Enum.Material.Concrete, gaps)
		end
	end
	for index, spec in ipairs({ { -24, -HZ - 30, P.cyan }, { -24, HZ + 30, P.magenta } }) do
		local x, z, accent = spec[1], spec[2], spec[3]
		local gate = box(routes, "MovingShortcutGate", x, 2.25, z, 0.7, 4.5, 9.6, accent, Enum.Material.Metal)
		gate:SetAttribute("DynamicObstacle", true)
		gate:SetAttribute("MovementTolerance", 8)
		gate:SetAttribute("GateClosedCFrame", gate.CFrame)
		gate:SetAttribute("GateCycle", 2.4 + index * 0.3)
		table.insert(gates, gate)
	end

	-- =====================================================================================
	-- FOOD COURT (west wing, ground floor): stalls, dining sets, open on three sides
	-- =====================================================================================
	for _, z in ipairs({ -48, -32, -16, 0, 16, 32, 48 }) do
		cylinder(court, "CourtPillar", Vector3.new(-HX, ceil1 / 2, z), 2.4, ceil1, P.white, Enum.Material.Marble)
		cylinder(court, "PillarRing", Vector3.new(-HX, 0.5, z), 3.4, 1, P.gold, Enum.Material.Metal, false)
		neon(court, "PillarGlow", -HX, 10, z, 0.2, 8, 0.2, P.orange)
	end
	local stalls = { { -44, "RAMEN", P.red }, { -22, "PIZZA", P.orange }, { 0, "SUSHI", P.teal }, { 22, "BURGER", P.yellow }, { 44, "TACO", P.green } }
	for si, s in ipairs(stalls) do
		local z, name, color = s[1], s[2], s[3]
		-- Solid stall frontage: counter block, glowing menu board, canopy and food models.
		box(court, "StallBlock", -128, 1.9, z, 8, 3.8, 17, P.white, Enum.Material.Concrete)
		art(court, "StallCounterTop", Vector3.new(8.4, 0.3, 17.4), Vector3.new(-128, 3.95, z), color, Enum.Material.SmoothPlastic)
		box(court, "StallBack", -131.2, 7.4, z, 1.6, 14.8, 17.6, color, Enum.Material.Concrete)
		art(court, "StallCanopy", Vector3.new(7, 0.4, 17.4), CFrame.new(-127.6, 10.2, z) * CFrame.Angles(0, 0, math.rad(-6)), color, Enum.Material.Fabric)
		sign(court, name, Vector3.new(-130.2, 11.6, z), 13, 3.2, color, math.pi / 2)
		art(court, "MenuBoard", Vector3.new(0.2, 3.6, 12), Vector3.new(-130.3, 7.4, z), P.ink, Enum.Material.SmoothPlastic)
		for row = 0, 2 do neon(court, "MenuLine", -130.1, 8.6 - row * 1.1, z, 0.1, 0.22, 8 - row * 1.5, P.white) end
		for i = -1, 1 do art(court, "StallLamp", Vector3.new(0.5, 0.5, 0.5), Vector3.new(-123.6, 5.6, z + i * 5), P.gold, Enum.Material.Neon) end
		-- Food on the counter: stacked burgers, pizza discs, sushi trays, sauce bottles.
		for k = -1, 1 do
			local fz = z + k * 4.4
			if name == "BURGER" then
				cylinder(court, "BunBottom", Vector3.new(-126.2, 4.3, fz), 1.8, 0.4, P.orange, Enum.Material.SmoothPlastic, false)
				cylinder(court, "Patty", Vector3.new(-126.2, 4.65, fz), 1.7, 0.3, P.wood, Enum.Material.SmoothPlastic, false)
				cylinder(court, "BunTop", Vector3.new(-126.2, 5.0, fz), 1.8, 0.5, P.orange, Enum.Material.SmoothPlastic, false)
			elseif name == "PIZZA" then
				cylinder(court, "Pizza", Vector3.new(-126.2, 4.2, fz), 2.8, 0.2, P.yellow, Enum.Material.SmoothPlastic, false)
				cylinder(court, "Pepperoni", Vector3.new(-126.2, 4.35, fz), 0.8, 0.1, P.red, Enum.Material.SmoothPlastic, false)
			elseif name == "SUSHI" then
				art(court, "SushiTray", Vector3.new(2.4, 0.2, 1.4), Vector3.new(-126.2, 4.2, fz), P.ink, Enum.Material.SmoothPlastic)
				art(court, "SushiRice", Vector3.new(0.7, 0.5, 0.7), Vector3.new(-126.6, 4.5, fz), P.white, Enum.Material.SmoothPlastic)
				art(court, "SushiFish", Vector3.new(0.7, 0.3, 0.8), Vector3.new(-125.6, 4.45, fz), P.coral, Enum.Material.SmoothPlastic)
			else
				cylinder(court, "FoodBowl", Vector3.new(-126.2, 4.4, fz), 1.9, 0.7, color, Enum.Material.SmoothPlastic, false)
				sphere(court, "FoodScoop", Vector3.new(-126.2, 4.9, fz), Vector3.new(1.4, 0.8, 1.4), P.cream)
			end
		end
	end
	for _, col in ipairs({ -112, -92 }) do
		for _, z in ipairs({ -42, -14, 14, 42 }) do
			local color = ({ P.coral, P.teal, P.gold, P.purple })[(z > 0 and 1 or 0) + (col == -112 and 1 or 3)]
			vaultTable(court, col, 0, z, 6, 4, P.wood, 0, color)
			cylinder(court, "TableNumber", Vector3.new(col, 3.7, z), 0.8, 0.3, color, Enum.Material.Neon, false)
			for _, c in ipairs({ { -4.4, 0 }, { 4.4, 0 } }) do chair(court, col + c[1], 0, z + c[2], color, c[1] < 0 and -math.pi / 2 or math.pi / 2) end
			for _, c in ipairs({ { 0, -3.6 }, { 0, 3.6 } }) do chair(court, col + c[1], 0, z + c[2], color, c[2] < 0 and math.pi or 0) end
		end
	end
	for _, z in ipairs({ -30, 0, 30 }) do
		for _, ring in ipairs({ { 9, 0.3 }, { 6, 0.5 } }) do
			art(court, "PendantRing", Vector3.new(0.3, ring[1], ring[1]), CFrame.new(-100, 12.4 - ring[2], z) * CFrame.Angles(0, 0, math.pi / 2), ring[2] < 0.4 and P.orange or P.yellow, Enum.Material.Neon).Shape = Enum.PartType.Cylinder
		end
		artBeam(court, "PendantWire", Vector3.new(-100, 12.4, z), Vector3.new(-100, ceil1, z), 0.1, P.ink)
	end
	sign(court, "FOOD COURT", Vector3.new(-HX + 0.2, 12.6, 0), 24, 3.6, P.orange, math.pi / 2)
	for _, z in ipairs({ -30, 30 }) do light(court, Vector3.new(-100, ceil1 - 0.4, z), P.orange, 0.7, 36) end
	for _, z in ipairs({ -52, 52 }) do
		planter(court, -98, 0, z, 16, 0, true)
		palm(court, -102, 1.4, z, 1.2, 0.1)
	end

	-- =====================================================================================
	-- ARCADE (east wing, ground floor): cabinets, racing sims, prize counter, 3 entrances
	-- =====================================================================================
	wall(arcade, "ArcadeWall", "z", HX, -HZ, HZ, 0, ceil1, 0.8, P.navy, Enum.Material.Concrete,
		{ { c = -36, w = 16, h = 11 }, { c = 0, w = 16, h = 11 }, { c = 36, w = 16, h = 11 } })
	for _, z in ipairs({ -36, 0, 36 }) do
		neon(arcade, "EntranceGlow", HX, 11.4, z, 0.4, 0.25, 16.6, P.magenta)
		for _, side in ipairs({ -1, 1 }) do neon(arcade, "EntranceGlow", HX, 5.5, z + side * 8.3, 0.4, 11, 0.25, P.cyan) end
	end
	sign(arcade, "ARCADE", Vector3.new(HX - 0.6, 13, -18), 14, 2.4, P.magenta, -math.pi / 2)
	sign(arcade, "PLAY", Vector3.new(HX - 0.6, 13, 18), 14, 2.4, P.cyan, -math.pi / 2)
	local cabColors = { P.magenta, P.cyan, P.yellow, P.green, P.coral, P.purple }
	local function cabinet(x, z, facing, i)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, facing, 0)
		local color = cabColors[i % 6 + 1]
		part(arcade, "Cabinet", Vector3.new(3.2, 6.6, 2.6), cf * CFrame.new(0, 3.3, 0), P.ink, Enum.Material.SmoothPlastic)
		neon(arcade, "CabScreen", 0, 0, 0, 2.4, 2.2, 0.1, color).CFrame = cf * CFrame.new(0, 4.4, -1.35)
		neon(arcade, "CabMarquee", 0, 0, 0, 3.2, 0.8, 0.1, color).CFrame = cf * CFrame.new(0, 6.2, -1.35)
		art(arcade, "CabPanel", Vector3.new(3, 0.6, 1.2), cf * CFrame.new(0, 2.8, -1.5) * CFrame.Angles(math.rad(-20), 0, 0), color, Enum.Material.SmoothPlastic)
		art(arcade, "CabStick", Vector3.new(0.3, 0.6, 0.3), cf * CFrame.new(-0.5, 3.3, -1.7), P.white, Enum.Material.Metal)
	end
	for i = 0, 8 do cabinet(130.2, -50 + i * 12.5, math.pi / 2, i) end
	local idx = 0
	for _, z0 in ipairs({ -46, 22 }) do
		for k = 0, 3 do
			idx += 1
			cabinet(112, z0 + k * 6.4, -math.pi / 2, idx)
			cabinet(115.4, z0 + k * 6.4, math.pi / 2, idx + 2)
		end
	end
	-- Racing sims: a low cockpit (vaultable) with a seat, wheel and wide screen.
	for _, z in ipairs({ -14, 14 }) do
		local cockpit = box(arcade, "VaultSim", 94, 1.7, z, 6, 3.4, 8, P.ink, Enum.Material.SmoothPlastic)
		cockpit:SetAttribute("Vaultable", true)
		art(arcade, "SimSeat", Vector3.new(2.4, 0.5, 2.4), Vector3.new(95.4, 3.7, z), P.red, Enum.Material.Fabric)
		art(arcade, "SimSeatBack", Vector3.new(2.4, 2.4, 0.5), Vector3.new(96.8, 4.7, z), P.red, Enum.Material.Fabric)
		art(arcade, "SimWheel", Vector3.new(0.3, 1.5, 1.5), CFrame.new(92.8, 4.2, z) * CFrame.Angles(0, 0, math.rad(25)), P.steel, Enum.Material.Metal)
		neon(arcade, "SimScreen", 91.2, 6.0, z, 0.2, 2.6, 6, z < 0 and P.cyan or P.magenta)
		art(arcade, "SimScreenFrame", Vector3.new(0.4, 3, 6.6), Vector3.new(91.0, 6.0, z), P.ink, Enum.Material.Metal)
	end
	for _, z in ipairs({ -48, 48 }) do
		vaultTable(arcade, 86, 0, z, 9, 5, P.ink, 0, P.cyan)
		neon(arcade, "HockeyLine", 86, 3.5, z, 0.2, 0.1, 5, P.magenta)
		cylinder(arcade, "HockeyPuck", Vector3.new(86, 3.5, z), 0.6, 0.2, P.yellow, Enum.Material.Neon, false)
	end
	-- Prize counter with plush wall and claw machines against the south wall.
	box(arcade, "PrizeCounter", 120, 1.9, 52, 20, 3.8, 3, P.purple, Enum.Material.SmoothPlastic)
	art(arcade, "PrizeTop", Vector3.new(20.4, 0.3, 3.4), Vector3.new(120, 3.95, 52), P.gold, Enum.Material.Metal)
	for k = 0, 5 do
		sphere(arcade, "PrizeBall", Vector3.new(112 + k * 3.2, 5.0, 52), Vector3.new(2, 2, 2), cabColors[k % 6 + 1])
		sphere(arcade, "PrizeBallTop", Vector3.new(112 + k * 3.2, 6.6, 52), Vector3.new(1.4, 1.4, 1.4), cabColors[(k + 2) % 6 + 1])
	end
	sign(arcade, "PRIZES", Vector3.new(120, 10, 53.4), 14, 2.6, P.yellow, math.pi)
	for _, x in ipairs({ 92, 98 }) do
		part(arcade, "ClawMachine", Vector3.new(4.6, 7, 4.6), Vector3.new(x, 3.5, 52), P.ink, Enum.Material.SmoothPlastic)
		glassBox(arcade, "ClawGlass", x, 4.2, 49.6, 4, 4.4, 0.2, 0.55, false)
		sphere(arcade, "ClawPrize", Vector3.new(x, 2.4, 52), Vector3.new(1.6, 1.6, 1.6), cabColors[x % 6 + 1])
		neon(arcade, "ClawLight", x, 7.2, 52, 4.4, 0.2, 4.4, P.magenta)
	end
	-- Rhythm stage with a step all round.
	box(arcade, "DanceStage", 100, 0.4, 0, 16, 0.8, 16, P.ink, Enum.Material.SmoothPlastic)
	for i = -1, 1 do for j = -1, 1 do neon(arcade, "DanceTile", 100 + i * 5, 0.85, j * 5, 4.2, 0.08, 4.2, (i + j) % 2 == 0 and P.magenta or P.cyan) end end
	for z = -52, 52, 13 do for x = 80, 124, 14 do
		art(arcade, "CarpetZig", Vector3.new(7, 0.06, 0.6), CFrame.new(x, 0.1, z) * CFrame.Angles(0, math.rad(35), 0), (x + z) % 2 == 0 and P.magenta or P.cyan, Enum.Material.Neon)
	end end
	for x = 80, 124, 11 do ceilingStrip(arcade, x, ceil1 - 0.2, 0, 0.6, 104, x % 22 == 0 and P.magenta or P.cyan) end
	sign(arcade, "INSERT COIN", Vector3.new(131.4, 10, 0), 24, 3, P.yellow, -math.pi / 2)
	light(arcade, Vector3.new(102, ceil1 - 0.4, -30), P.magenta, 0.8, 38)
	light(arcade, Vector3.new(102, ceil1 - 0.4, 30), P.cyan, 0.8, 38)

	-- =====================================================================================
	-- SECOND FLOOR WINGS: Department store (east) and Sky Lounge (west)
	-- =====================================================================================
	wall(storesF, "DeptWall", "z", HX, -HZ, HZ, F2, 30, 0.8, P.white, Enum.Material.Concrete,
		{ { c = -36, w = 16, h = 12 }, { c = 0, w = 16, h = 12 }, { c = 36, w = 16, h = 12 } })
	for _, z in ipairs({ -36, 0, 36 }) do neon(storesF, "DeptDoorGlow", HX, F2 + 12.2, z, 0.4, 0.25, 16.6, P.gold) end
	sign(storesF, "ZENITH", Vector3.new(HX - 0.6, F2 + 14.6, 0), 28, 3.6, P.gold, -math.pi / 2)
	art(storesF, "DeptCarpet", Vector3.new(58, 0.1, 108), Vector3.new(102, F2 + 0.1, 0), P.cream:Lerp(P.coral, 0.2), Enum.Material.Fabric)
	cylinder(storesF, "MannequinStage", Vector3.new(102, F2 + 0.5, 0), 18, 1, P.white, Enum.Material.Marble)
	for i = 1, 6 do
		local a = i * math.pi / 3
		mannequin(storesF, 102 + math.cos(a) * 6, F2 + 1, math.sin(a) * 6, PAL[i])
		art(storesF, "StageJacket", Vector3.new(1.9, 1.4, 1.2), Vector3.new(102 + math.cos(a) * 6, F2 + 3.7, math.sin(a) * 6), PAL[i + 2 > #PAL and 1 or i + 2], Enum.Material.Fabric)
	end
	cylinder(storesF, "StageGlow", Vector3.new(102, F2 + 1.05, 0), 18.4, 0.08, P.gold, Enum.Material.Neon, false)
	for _, spec in ipairs({ { 86, -40 }, { 118, -40 }, { 86, 40 }, { 118, 40 }, { 86, -18 }, { 118, 18 } }) do
		vaultTable(storesF, spec[1], F2, spec[2], 10, 4.4, P.white, 0, P.pink)
		for k = 0, 2 do art(storesF, "FoldedStack", Vector3.new(2.6, 0.8 + (k % 2) * 0.5, 2.6), Vector3.new(spec[1] - 3 + k * 3, F2 + 3.9, spec[2]), PAL[(k + spec[1]) % #PAL + 1], Enum.Material.Fabric) end
	end
	for _, z in ipairs({ -52, 52 }) do for _, x in ipairs({ 84, 102, 120 }) do
		box(storesF, "RackSection", x, F2 + 3.5, z, 8, 7, 1.4, P.ink, Enum.Material.SmoothPlastic)
		neon(storesF, "RackGlow", x, F2 + 5, z + (z < 0 and 0.75 or -0.75), 7, 0.15, 0.1, P.gold)
		for k = -2, 2 do art(storesF, "HangingTop", Vector3.new(1.1, 2, 0.3), Vector3.new(x + k * 1.5, F2 + 4, z + (z < 0 and 0.95 or -0.95)), PAL[(k + x) % #PAL + 1], Enum.Material.Fabric) end
	end end
	sign(storesF, "ZENITH", Vector3.new(OX - 1.4, F2 + 12, 0), 30, 4, P.gold, -math.pi / 2)
	-- Sky Lounge window onto the food court: railing around the cutaway.
	local lx1, lx2, lz1, lz2 = loungeHole[1], loungeHole[2], loungeHole[3], loungeHole[4]
	local function loungeRail(axis, fixed, a1, a2)
		wall(atrium, "LoungeGlass", axis, fixed, a1, a2, F2, F2 + RAIL, 0.35, P.glass, Enum.Material.Glass)
		if axis == "x" then art(atrium, "Handrail", Vector3.new(a2 - a1, 0.3, 0.6), Vector3.new((a1 + a2) / 2, F2 + RAIL, fixed), P.gold, Enum.Material.Metal)
		else art(atrium, "Handrail", Vector3.new(0.6, 0.3, a2 - a1), Vector3.new(fixed, F2 + RAIL, (a1 + a2) / 2), P.gold, Enum.Material.Metal) end
	end
	loungeRail("x", lz1 + 0.4, lx1, lx2); loungeRail("x", lz2 - 0.4, lx1, lx2)
	loungeRail("z", lx1 + 0.4, lz1, lz2); loungeRail("z", lx2 - 0.4, lz1, lz2)
	for _, child in ipairs(atrium:GetChildren()) do
		if child.Name == "LoungeGlass" then child.Transparency = 0.6; child.CastShadow = false end
	end
	sign(storesF, "SKY LOUNGE", Vector3.new(-(OX - 1.4), F2 + 14, 0), 24, 3.4, P.cyan, math.pi / 2)
	for _, spec in ipairs({ { -128, -46 }, { -128, 46 }, { -76, -46 }, { -76, 46 }, { -102, -50 }, { -102, 50 } }) do
		planter(decor, spec[1], F2, spec[2], 8, math.pi / 2, true)
		palm(decor, spec[1], F2 + 1.4, spec[2], 1.1, 0.1)
	end
	for _, spec in ipairs({ { -128, 0 }, { -76, 0 }, { -128, -22 }, { -128, 22 } }) do bench(decor, spec[1], F2, spec[2], spec[1] < -100 and math.pi / 2 or -math.pi / 2) end
	for _, z in ipairs({ -48, -32, -16, 0, 16, 32, 48 }) do
		cylinder(court, "UpperPillar", Vector3.new(-HX, F2 + 7.4, z), 2.2, 14.8, P.white, Enum.Material.Marble)
	end
	for _, spec in ipairs({ { -58, 46 }, { 58, -46 }, { -58, -46 }, { 58, 46 } }) do
		planter(decor, spec[1], F2, spec[2], 10, 0, true)
		bench(decor, spec[1] + (spec[1] < 0 and 14 or -14), F2, spec[2], spec[2] < 0 and 0 or math.pi)
	end
	for _, spec in ipairs({ { -66, 24 }, { 66, -24 } }) do palm(decor, spec[1], F2, spec[2], 1.3, 0.1) end

	-- =====================================================================================
	-- SPAWNS (runners spread over both floors; hunters start on the ground floor)
	-- =====================================================================================
	local function spawnFacing(x, y, z)
		return CFrame.lookAt(Vector3.new(x, y + 3.3, z), Vector3.new(0, y + 3.3, 0))
	end
	local runnerSpawns = {
		spawnFacing(-102, F2, -66), spawnFacing(-48, F2, -66), spawnFacing(0, F2, -66), spawnFacing(-102, F2, -42),
		spawnFacing(108, F2, -26), spawnFacing(108, F2, 30), spawnFacing(0, F2, 46), spawnFacing(-58, F2, 34),
		spawnFacing(104, 0, -30), spawnFacing(-104, 0, 28), spawnFacing(-102, 0, 68), spawnFacing(0, 0, 68),
	}
	local hunterSpawns = { spawnFacing(-8, 0, -46), spawnFacing(8, 0, 46) }

	-- =====================================================================================
	-- PLAZA HUB: a separate, safe social area. Nobody is chased here.
	-- =====================================================================================
	local HC = 262 -- hub center Z
	box(hub, "HubIsland", 0, -5, HC, 164, 9, 132, P.navy, Enum.Material.Concrete)
	box(hub, "PlazaFloor", 0, -0.2, HC, 156, 0.4, 124, P.marble, Enum.Material.Marble)
	for i, d in ipairs({ 44, 34, 24 }) do
		local ring = art(hub, "PlazaInlay", Vector3.new(0.12, d, d), CFrame.new(0, 0.08, 248) * CFrame.Angles(0, 0, math.pi / 2), i == 2 and P.gold or (i == 1 and P.magenta or P.blue), i == 2 and Enum.Material.Metal or Enum.Material.Neon)
		ring.Shape = Enum.PartType.Cylinder
		if i ~= 2 then ring.Transparency = 0.25 end
	end
	for i = -3, 3 do
		art(hub, "PlazaStripe", Vector3.new(0.3, 0.1, 118), Vector3.new(i * 20, 0.06, HC), i % 2 == 0 and P.marble2 or P.cream, Enum.Material.Marble)
	end
	-- Backdrop: the mall entrance building with a recessed PLAY entrance.
	local bz1, bz2 = 196, 212
	box(hub, "EntranceBlock", -42.5, 15, 204, 71, 30, 16, P.cream, Enum.Material.Concrete)
	box(hub, "EntranceBlock", 42.5, 15, 204, 71, 30, 16, P.cream, Enum.Material.Concrete)
	box(hub, "EntranceBack", 0, 15, 200, 14, 30, 8, P.cream, Enum.Material.Concrete)
	box(hub, "EntranceLintel", 0, 21, 208, 14, 18, 8, P.cream, Enum.Material.Concrete)
	box(hub, "EntranceTower", 0, 45, 205, 66, 30, 12, P.white, Enum.Material.Concrete)
	for _, side in ipairs({ -1, 1 }) do
		box(hub, "TowerWing", side * 52, 38, 205, 22, 16, 12, P.white, Enum.Material.Concrete)
		art(hub, "TowerFin", Vector3.new(1.2, 32, 2), Vector3.new(side * 33.5, 46, 211.4), P.gold, Enum.Material.Metal)
	end
	for i = -6, 6 do
		if math.abs(i) > 1 then
			glassBox(hub, "ShopFront", i * 11.5, 6.5, 212.2, 8.6, 9.5, 0.3, 0.45, false, P.glass)
			neon(hub, "ShopFrontGlow", i * 11.5, 11.6, 212.4, 8.8, 0.25, 0.25, i % 2 == 0 and P.cyan or P.magenta)
			art(hub, "ShopFrontWarm", Vector3.new(8.2, 8.6, 0.3), Vector3.new(i * 11.5, 6.2, 211.6), P.gold, Enum.Material.Neon).Transparency = 0.55
		end
		glassBox(hub, "UpperWindow", i * 11.5, 21, 212.2, 8.6, 6.5, 0.3, 0.4, false, P.glass)
		art(hub, "UpperWarm", Vector3.new(8.2, 6, 0.3), Vector3.new(i * 11.5, 21, 211.7), P.cream, Enum.Material.Neon).Transparency = 0.7
	end
	art(hub, "RoofNeon", Vector3.new(156, 0.3, 0.3), Vector3.new(0, 30.4, 212.3), P.magenta, Enum.Material.Neon)
	art(hub, "RoofNeon", Vector3.new(66, 0.3, 0.3), Vector3.new(0, 60.4, 211.3), P.cyan, Enum.Material.Neon)
	-- Recess glow, red carpet, and the arch.
	art(hub, "RecessGlow", Vector3.new(13, 11, 0.3), Vector3.new(0, 6, 196.4), P.gold, Enum.Material.Neon).Transparency = 0.35
	art(hub, "RedCarpet", Vector3.new(9, 0.1, 62), Vector3.new(0, 0.1, 232), P.red, Enum.Material.Fabric)
	for _, z in ipairs({ 203, 224, 245 }) do art(hub, "CarpetStud", Vector3.new(9.6, 0.12, 0.5), Vector3.new(0, 0.12, z), P.gold, Enum.Material.Metal) end
	for _, side in ipairs({ -1, 1 }) do
		box(hub, "ArchPylon", side * 9.5, 8, 216, 3, 16, 3, P.ink, Enum.Material.Metal)
		neon(hub, "ArchGlow", side * 8, 8, 214.4, 0.25, 15, 0.25, P.cyan)
		neon(hub, "ArchGlow", side * 11, 8, 214.4, 0.25, 15, 0.25, P.magenta)
	end
	box(hub, "ArchHeader", 0, 17, 216, 24, 5, 3.4, P.ink, Enum.Material.Metal)
	sign(hub, "PLAY", Vector3.new(0, 17.6, 217.9), 11, 3.6, P.white, 0, P.white)
	sign(hub, "ENTER THE MALL", Vector3.new(0, 15, 217.9), 11, 1.4, P.cyan, 0)
	for _, side in ipairs({ -1, 1 }) do neon(hub, "ArchArrow", side * 9.3, 17.2, 217.9, 0.8, 2.2, 0.2, P.cyan) end
	neon(hub, "ArchTopGlow", 0, 19.7, 216, 24, 0.3, 3.5, P.magenta)
	-- PLAY portal: a shimmering field plus a prompt and a touch trigger.
	local portal = part(hub, "PlayPortal", Vector3.new(14, 11, 0.4), Vector3.new(0, 6, 211), P.cyan, Enum.Material.Neon, false)
	portal.Transparency = 0.7
	portal.CanTouch = true
	portal.CanQuery = false
	portal.CastShadow = false
	portal:SetAttribute("Pulse", 3)
	portal:SetAttribute("HubTouch", "Play")
	local function addPrompt(host, action, actionText, objectText, distance)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = actionText
		prompt.ObjectText = objectText
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = distance or 14
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt:SetAttribute("HubAction", action)
		prompt.Parent = host
		return prompt
	end
	addPrompt(portal, "Play", "PLAY", "Enter the mall", 22)
	-- Giant title sign above the entrance, with a neon runner.
	local title1 = part(hub, "TitleTop", Vector3.new(58, 11, 1.6), Vector3.new(0, 49, 211.6), P.ink, Enum.Material.SmoothPlastic, false)
	local title2 = part(hub, "TitleBottom", Vector3.new(58, 11, 1.6), Vector3.new(0, 38.6, 211.6), P.ink, Enum.Material.SmoothPlastic, false)
	title1:SetAttribute("VisualPolish", true); title2:SetAttribute("VisualPolish", true)
	surfaceText(title1, Enum.NormalId.Back, "CATCH ME", P.cyan, 28, 0.74, 0.92)
	surfaceText(title2, Enum.NormalId.Back, "IF YOU CAN", P.coral, 28, 0.74, 0.92)
	neon(hub, "TitleFrame", 0, 54.6, 212.5, 58.6, 0.4, 0.3, P.blue)
	neon(hub, "TitleFrame", 0, 33.0, 212.5, 58.6, 0.4, 0.3, P.magenta)
	for _, side in ipairs({ -1, 1 }) do neon(hub, "TitleFrame", side * 29.2, 43.8, 212.5, 0.4, 22, 0.3, side < 0 and P.blue or P.magenta) end
	-- Neon runner pictogram.
	local rx, ry = 24, 44
	local function limb(a, b) artBeam(hub, "RunnerLimb", Vector3.new(rx + a[1], ry + a[2], 212.6), Vector3.new(rx + b[1], ry + b[2], 212.6), 0.9, P.white, Enum.Material.Neon) end
	sphere(hub, "RunnerHead", Vector3.new(rx + 1.5, ry + 6, 212.6), Vector3.new(2.2, 2.2, 2.2), P.white, Enum.Material.Neon)
	limb({ 0, 3 }, { -1, -1 }); limb({ -1, -1 }, { -4, -4.5 }); limb({ -1, -1 }, { 2.5, -4 }); limb({ 2.5, -4 }, { 2, -7 })
	limb({ 0, 3 }, { 3.5, 1 }); limb({ 0, 3 }, { -3, 1.5 })
	-- Side billboards.
	local function billboard(cx, title, subtitle, accent)
		local b = part(hub, "Billboard", Vector3.new(38, 17, 1), Vector3.new(cx, 22, 212.9), P.ink, Enum.Material.SmoothPlastic, false)
		b:SetAttribute("VisualPolish", true)
		local gui = surfaceText(b, Enum.NormalId.Back, title, P.white, 28, 0.9, 0.46)
		gui.Position = UDim2.fromScale(0.05, 0.08)
		local sub = surfaceText(b, Enum.NormalId.Back, subtitle, accent, 28, 0.9, 0.2)
		sub.Position = UDim2.fromScale(0.05, 0.62)
		sub.Size = UDim2.fromScale(0.9, 0.22)
		for _, s in ipairs({ -1, 1 }) do
			neon(hub, "BillboardFrame", cx, 22 + s * 8.6, 213.3, 38.6, 0.35, 0.3, accent)
			neon(hub, "BillboardFrame", cx + s * 19.2, 22, 213.3, 0.35, 17.2, 0.3, accent)
		end
	end
	-- Back-facing SurfaceGuis face the plaza (-Z side of a part is "Back" when unrotated: use Back).
	billboard(-52, "NEW SKINS", "COLLECT. UNLOCK. STAND OUT.", P.cyan)
	billboard(52, "DAILY REWARDS", "PLAY. EARN. UNLOCK.", P.gold)
	for _, x in ipairs({ -26, 26 }) do
		for k = 0, 1 do
			local banner = part(hub, "Banner", Vector3.new(5, 20, 0.3), Vector3.new(x + (x < 0 and -5 or 5) * k, 26, 213.4), P.purple, Enum.Material.Fabric, false)
			banner:SetAttribute("VisualPolish", true)
			surfaceText(banner, Enum.NormalId.Back, k == 0 and "PLAY" or "RUN", P.white, 30, 0.9, 0.3)
			neon(hub, "BannerGlow", banner.CFrame.Position.X, 16.2, 213.6, 5, 0.25, 0.25, P.cyan)
		end
	end
	-- Fountain centerpiece with a running statue.
	local FZ = 248
	cylinder(hub, "HubFountainStep", Vector3.new(0, 0.4, FZ), 28, 0.8, P.marble2, Enum.Material.Marble)
	cylinder(hub, "HubFountainBasin", Vector3.new(0, 1.2, FZ), 22, 2, P.white, Enum.Material.Marble)
	disc(hub, "HubFountainWater", CFrame.new(0, 2.25, FZ), 20, 0.1, P.blue, Enum.Material.Glass).Transparency = 0.3
	disc(hub, "HubFountainRing", CFrame.new(0, 2.4, FZ), 21.4, 0.1, P.cyan, Enum.Material.Neon):SetAttribute("Pulse", 2)
	disc(hub, "HubFountainRing", CFrame.new(0, 0.9, FZ), 29.5, 0.12, P.magenta, Enum.Material.Neon):SetAttribute("Pulse", 4)
	cylinder(hub, "StatuePedestal", Vector3.new(0, 4.6, FZ), 8, 5, P.ink, Enum.Material.Metal)
	cylinder(hub, "StatueCap", Vector3.new(0, 7.3, FZ), 8.6, 0.5, P.gold, Enum.Material.Metal, false)
	sign(hub, "CATCH ME IF YOU CAN", Vector3.new(0, 4.8, FZ + 4.3), 6.4, 1.8, P.cyan, 0)
	-- Heroic runner statue assembled from metal blocks.
	local sx, sy = 0, 7.6
	local statue = { { 0, 3.2, 0, 2.6, 3.4, 1.5 }, { 0, 5.6, 0.3, 1.8, 1.8, 1.8 }, { -1.6, 1.2, -1.0, 1.1, 3.4, 1.1 }, { 1.1, 1.0, 1.1, 1.1, 3.6, 1.1 },
		{ -2.1, 3.6, 1.4, 0.9, 3, 0.9 }, { 2.3, 4.2, -1.1, 0.9, 3, 0.9 } }
	for i, s in ipairs(statue) do
		local piece = part(hub, "StatuePiece", Vector3.new(s[4], s[5], s[6]), CFrame.new(sx + s[1], sy + s[2], FZ + s[3]) * CFrame.Angles(math.rad(i == 1 and -14 or 0), 0, math.rad((i - 3) * 4)), P.steel, Enum.Material.Metal, false)
		piece:SetAttribute("VisualPolish", true)
	end
	for i = 1, 3 do
		ring(hub, "StatueOrbit", CFrame.new(0, sy + 3 + i * 1.3, FZ) * CFrame.Angles(math.rad(14 * i), math.rad(i * 40), 0), 6 + i * 1.8, 0.25, i == 2 and P.magenta or P.cyan, Enum.Material.Neon, 16)
	end
	for i = 1, 8 do
		local a = i * math.pi / 4
		neon(hub, "HubFountainLamp", math.cos(a) * 12.4, 1.2, FZ + math.sin(a) * 12.4, 0.5, 0.5, 0.5, i % 2 == 0 and P.magenta or P.cyan)
	end
	local hubSpray = Instance.new("ParticleEmitter")
	hubSpray.Name = "HubFountainSpray"
	hubSpray.Rate = 26
	hubSpray.Lifetime = NumberRange.new(1.2, 1.8)
	hubSpray.Speed = NumberRange.new(5, 8)
	hubSpray.SpreadAngle = Vector2.new(25, 25)
	hubSpray.Acceleration = Vector3.new(0, -14, 0)
	hubSpray.Size = NumberSequence.new(0.5, 0.1)
	hubSpray.Transparency = NumberSequence.new(0.2, 1)
	hubSpray.Color = ColorSequence.new(P.white, P.cyan)
	hubSpray.LightEmission = 0.6
	hubSpray.Parent = hub:FindFirstChild("StatueCap")

	-- Interactive displays ------------------------------------------------------------
	local function console(x, z, width, color, rot)
		local c = box(hub, "Console", x, 1.6, z, width, 3.2, 2.4, P.ink, Enum.Material.Metal)
		c.CFrame = CFrame.new(x, 1.6, z) * CFrame.Angles(0, rot or 0, 0)
		neon(hub, "ConsoleGlow", x, 3.3, z, width - 0.4, 0.14, 2.2, color)
		return c
	end
	-- SKINS booth (west): four lit pedestals with real outfit previews.
	box(hub, "SkinsBackWall", -72, 8, 248, 2, 16, 52, P.ink, Enum.Material.Concrete)
	box(hub, "SkinsRoof", -66, 16.6, 248, 14, 0.8, 52, P.navy, Enum.Material.Metal, false):SetAttribute("VisualPolish", true)
	sign(hub, "SKINS", Vector3.new(-70.6, 13.4, 248), 20, 4, P.cyan, math.pi / 2)
	neon(hub, "SkinsFrame", -70.8, 16, 248, 0.2, 0.3, 52, P.cyan)
	neon(hub, "SkinsFrame", -70.8, 0.4, 248, 0.2, 0.3, 52, P.cyan)
	local showcase = {
		{ "skin_courier", "mask_street" }, { "skin_golden", "mask_skull" }, { "skin_neon", "mask_visor" }, { "skin_crimson", "mask_kitsune" },
	}
	local Appearance = options and options.Appearance
	if not Appearance then
		local okAppearance, module = pcall(function() return require(game:GetService("ReplicatedStorage").CatchShared.Appearance) end)
		if okAppearance then Appearance = module end
	end
	for i, look in ipairs(showcase) do
		local z = 230 + (i - 1) * 12
		cylinder(hub, "SkinPedestal", Vector3.new(-62, 0.9, z), 6.4, 1.8, P.white, Enum.Material.Marble)
		cylinder(hub, "SkinPedestalGlow", Vector3.new(-62, 1.85, z), 6.8, 0.12, i % 2 == 0 and P.magenta or P.cyan, Enum.Material.Neon, false)
		light(hub, Vector3.new(-66, 12, z), P.white, 1.2, 18)
		if Appearance then
			local ok, rig = pcall(Appearance.BuildPreview, look[1], look[2], {})
			if ok and rig then
				rig.Name = "SkinShowcase_" .. look[1]
				local humanoid = rig:FindFirstChildOfClass("Humanoid")
				if humanoid then humanoid:Destroy() end
				local root = rig:FindFirstChild("HumanoidRootPart")
				local target = CFrame.new(-62, 1.8 + 3.1, z) * CFrame.Angles(0, -math.pi / 2, 0)
				if root then
					local inverse = root.CFrame:Inverse()
					for _, descendant in ipairs(rig:GetDescendants()) do
						if descendant:IsA("BasePart") then descendant.CFrame = target * (inverse * descendant.CFrame) end
					end
				end
				for _, descendant in ipairs(rig:GetDescendants()) do
					if descendant:IsA("BasePart") then
						descendant.Anchored = true
						descendant.CanCollide = false
						descendant.CanQuery = false
						descendant.CanTouch = false
						descendant.CastShadow = false
						partCount += 1
					elseif descendant:IsA("Script") or descendant:IsA("LocalScript") then
						descendant:Destroy()
					end
				end
				rig.Parent = hub
			end
		end
	end
	local skinsKiosk = console(-57, 248, 6, P.cyan, math.pi / 2)
	skinsKiosk.Name = "SkinsKiosk"
	addPrompt(skinsKiosk, "Locker", "OPEN LOCKER", "Skins & masks", 16)
	sign(hub, "LOCKER", Vector3.new(-57, 5.2, 248), 5, 1.2, P.cyan, math.pi / 2)
	-- SHOP (east): three glowing vending pods.
	box(hub, "ShopBackWall", 72, 8, 248, 2, 16, 52, P.ink, Enum.Material.Concrete)
	box(hub, "ShopRoof", 66, 16.6, 248, 14, 0.8, 52, P.navy, Enum.Material.Metal, false):SetAttribute("VisualPolish", true)
	sign(hub, "SHOP", Vector3.new(70.6, 13.4, 248), 20, 4, P.magenta, -math.pi / 2)
	neon(hub, "ShopFrame", 70.8, 16, 248, 0.2, 0.3, 52, P.magenta)
	neon(hub, "ShopFrame", 70.8, 0.4, 248, 0.2, 0.3, 52, P.magenta)
	for i, pod in ipairs({ { "GAMEPASSES", P.purple }, { "COINS", P.gold }, { "EFFECTS", P.cyan } }) do
		local z = 232 + (i - 1) * 16
		local base = box(hub, "ShopPod", 64, 2, z, 7, 4, 9, P.ink, Enum.Material.Metal)
		art(hub, "PodScreen", Vector3.new(0.3, 9, 9), Vector3.new(60.4, 8.4, z), P.ink, Enum.Material.SmoothPlastic)
		neon(hub, "PodGlow", 60.2, 8.4, z, 0.15, 8.4, 8.4, pod[2]).Transparency = 0.35
		if i == 1 then
			for k = -1, 1 do art(hub, "CrownSpike", Vector3.new(0.4, 3 + (k == 0 and 1.4 or 0), 1.4), Vector3.new(60, 8 + (k == 0 and 0.7 or 0), z + k * 2.2), P.gold, Enum.Material.Neon) end
			art(hub, "CrownBand", Vector3.new(0.4, 1.2, 6), Vector3.new(60, 6.2, z), P.gold, Enum.Material.Neon)
		elseif i == 2 then
			for k = 0, 2 do disc(hub, "ShopCoin", CFrame.new(59.9, 6.4 + k * 1.2, z) * CFrame.Angles(0, math.pi / 2, 0) , 4.6 - k * 0.4, 0.5, P.gold, Enum.Material.Neon) end
		else
			for _, d in ipairs({ { 0, 8.4, 4.5 }, { 2.6, 6, 2 }, { -2.6, 10.8, 2 } }) do
				art(hub, "Sparkle", Vector3.new(0.4, d[3], d[3]), CFrame.new(60, d[2], z + d[1]) * CFrame.Angles(math.pi / 4, 0, 0), P.cyan, Enum.Material.Neon)
			end
		end
		sign(hub, pod[1], Vector3.new(60.3, 3.1, z), 8, 1.4, pod[2], -math.pi / 2)
		addPrompt(base, "Shop", "BROWSE", pod[1] == "COINS" and "Coin items" or (pod[1] == "EFFECTS" and "Trails & effects" or "Game passes"), 16)
	end
	-- QUESTS board and LEADERBOARD board flank the PLAY arch.
	local questBoard = part(hub, "QuestBoard", Vector3.new(19, 11, 0.6), Vector3.new(-34, 9.5, 220), P.ink, Enum.Material.SmoothPlastic, false)
	questBoard:SetAttribute("VisualPolish", true)
	local qtitle = surfaceText(questBoard, Enum.NormalId.Back, "QUESTS", P.gold, 30, 0.8, 0.26)
	qtitle.Parent.Name = "QuestGui"
	qtitle.Position = UDim2.fromScale(0.1, 0.06)
	for i, line in ipairs({ "Play 3 rounds", "Tag 5 runners", "Win 1 round" }) do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.fromScale(0.84, 0.15)
		row.Position = UDim2.fromScale(0.08, 0.3 + i * 0.19)
		row.BackgroundTransparency = 1
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextScaled = true
		row.Text = "*  " .. line
		row.TextColor3 = P.white
		row.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		row.Parent = qtitle.Parent
	end
	local qhint = Instance.new("TextLabel")
	qhint.Size = UDim2.fromScale(0.84, 0.09)
	qhint.Position = UDim2.fromScale(0.08, 0.9)
	qhint.BackgroundTransparency = 1
	qhint.Text = "NEW CHALLENGES EVERY DAY"
	qhint.TextColor3 = P.cyan
	qhint.TextScaled = true
	qhint.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	qhint.Parent = qtitle.Parent
	for _, s in ipairs({ -1, 1 }) do
		neon(hub, "QuestFrame", -34, 9.5 + s * 5.6, 219.6, 19.6, 0.3, 0.3, P.gold)
		neon(hub, "QuestFrame", -34 + s * 9.8, 9.5, 219.6, 0.3, 11.2, 0.3, P.gold)
	end
	for _, x in ipairs({ -42, -26 }) do box(hub, "BoardLeg", x, 2.2, 220, 0.8, 4.4, 0.8, P.ink, Enum.Material.Metal) end
	local questConsole = console(-34, 224, 8, P.gold)
	questConsole.Name = "QuestsKiosk"
	addPrompt(questConsole, "Quests", "OPEN QUESTS", "Daily dispatch", 16)
	-- Leaderboard: rows are updated by HubService from the live server roster.
	local board = part(hub, "LeaderboardBoard", Vector3.new(21, 11.5, 0.6), Vector3.new(34, 9.7, 220), P.ink, Enum.Material.SmoothPlastic, false)
	board:SetAttribute("VisualPolish", true)
	local gui = surfaceText(board, Enum.NormalId.Back, "LEADERBOARD", P.cyan, 30, 0.84, 0.2)
	gui.Position = UDim2.fromScale(0.08, 0.04)
	for i = 1, 5 do
		local name = Instance.new("TextLabel")
		name.Name = "Row" .. i
		name.Size = UDim2.fromScale(0.56, 0.13)
		name.Position = UDim2.fromScale(0.08, 0.2 + (i - 1) * 0.15)
		name.BackgroundTransparency = 1
		name.TextXAlignment = Enum.TextXAlignment.Left
		name.TextScaled = true
		name.Text = i .. "  ---"
		name.TextColor3 = i == 1 and P.gold or P.white
		name.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		name.Parent = gui.Parent
		local score = Instance.new("TextLabel")
		score.Name = "Score" .. i
		score.Size = UDim2.fromScale(0.28, 0.13)
		score.Position = UDim2.fromScale(0.64, 0.2 + (i - 1) * 0.15)
		score.BackgroundTransparency = 1
		score.TextXAlignment = Enum.TextXAlignment.Right
		score.TextScaled = true
		score.Text = ""
		score.TextColor3 = P.cyan
		score.FontFace = Font.fromEnum(Enum.Font.GothamBold)
		score.Parent = gui.Parent
	end
	for _, s in ipairs({ -1, 1 }) do
		neon(hub, "BoardFrame", 34, 9.7 + s * 5.9, 219.6, 21.6, 0.3, 0.3, P.cyan)
		neon(hub, "BoardFrame", 34 + s * 10.8, 9.7, 219.6, 0.3, 12.2, 0.3, P.cyan)
	end
	for _, x in ipairs({ 25, 43 }) do box(hub, "BoardLeg", x, 2, 220, 0.8, 4, 0.8, P.ink, Enum.Material.Metal) end
	local boardConsole = console(34, 224, 8, P.cyan)
	boardConsole.Name = "LeaderboardKiosk"
	addPrompt(boardConsole, "Roster", "VIEW CREW", "Server leaderboard", 16)
	-- Daily rewards gift kiosk.
	local gift = box(hub, "RewardsKiosk", 56, 2, 226, 6, 4, 6, P.red, Enum.Material.SmoothPlastic)
	art(hub, "GiftRibbon", Vector3.new(6.2, 4.2, 1), Vector3.new(56, 2, 226), P.gold, Enum.Material.Neon)
	art(hub, "GiftRibbon", Vector3.new(1, 4.2, 6.2), Vector3.new(56, 2, 226), P.gold, Enum.Material.Neon)
	box(hub, "GiftLid", 56, 4.5, 226, 6.8, 1, 6.8, P.red, Enum.Material.SmoothPlastic, false):SetAttribute("VisualPolish", true)
	art(hub, "GiftBowL", Vector3.new(3, 1.5, 0.8), CFrame.new(54.6, 5.7, 226) * CFrame.Angles(0, 0, math.rad(30)), P.gold, Enum.Material.Neon)
	art(hub, "GiftBowR", Vector3.new(3, 1.5, 0.8), CFrame.new(57.4, 5.7, 226) * CFrame.Angles(0, 0, math.rad(-30)), P.gold, Enum.Material.Neon)
	sign(hub, "DAILY GIFT", Vector3.new(56, 8.4, 226), 8, 1.6, P.gold, 0)
	addPrompt(gift, "Rewards", "CLAIM REWARD", "7-day streak", 16)
	-- Winner podiums face the arrival point; CosmeticService stages the champions here.
	box(hub, "PodiumStage", 0, 0.7, 292, 48, 1.4, 14, P.navy, Enum.Material.Concrete)
	neon(hub, "PodiumStageGlow", 0, 1.45, 285.2, 48, 0.12, 0.3, P.magenta)
	local podiums = {}
	for i, item in ipairs({ { 0, 2.4, "1", P.gold }, { -14, 1.4, "2", P.cyan }, { 14, 0.9, "3", P.pink } }) do
		local x, h, numeral, accent = item[1], item[2], item[3], item[4]
		cylinder(hub, "WinnerPodium_" .. numeral, Vector3.new(x, 1.4 + h / 2, 292), 10.5, h, P.steel, Enum.Material.Metal)
		cylinder(hub, "PodiumLight", Vector3.new(x, 1.45 + h, 292), 10.6, 0.12, accent, Enum.Material.Neon, false)
		sign(hub, numeral, Vector3.new(x, 2.6, 286.4), 3, 1.4, accent, 0)
		podiums[i] = CFrame.lookAt(Vector3.new(x, 4.6 + h, 292), Vector3.new(x, 4.6 + h, 310))
	end
	sign(hub, "CHAMPIONS", Vector3.new(0, 12, 298.6), 24, 3.6, P.gold, math.pi)
	for _, x in ipairs({ -26, 26 }) do box(hub, "StagePole", x, 6, 298.6, 0.6, 12, 0.6, P.steel, Enum.Material.Metal) end
	-- Social lounges: seating clusters, planters, palms. Plenty of room to hang out.
	for _, spot in ipairs({ { -44, 290 }, { 44, 290 }, { -50, 270 }, { 50, 270 } }) do
		local x, z = spot[1], spot[2]
		cylinder(hub, "LoungeRug", Vector3.new(x, 0.12, z), 16, 0.1, x < 0 and P.purple or P.teal, Enum.Material.Fabric, false)
		cylinder(hub, "LoungeTable", Vector3.new(x, 1, z), 3, 2, P.white, Enum.Material.Marble)
		neon(hub, "LoungeTableGlow", x, 2.05, z, 2.6, 0.08, 2.6, P.cyan).Shape = Enum.PartType.Cylinder
		bench(hub, x, 0, z - 5, 0, P.coral)
		bench(hub, x, 0, z + 5, math.pi, P.coral)
		planter(hub, x + (x < 0 and -9 or 9), 0, z, 8, math.pi / 2, true)
	end
	local palmSpots = { { -66, 205 }, { 66, 205 }, { -66, 232 }, { 66, 232 }, { -20, 214 }, { 20, 214 }, { -66, 300 }, { 66, 300 }, { -30, 316 }, { 30, 316 }, { -18, 262 }, { 18, 262 }, { -66, 316 }, { 66, 316 }, { -12, 230 }, { 12, 230 } }
	for _, spot in ipairs(palmSpots) do
		cylinder(hub, "PalmRing", Vector3.new(spot[1], 0.6, spot[2]), 6, 1.2, P.cream, Enum.Material.Concrete)
		palm(hub, spot[1], 1.2, spot[2], 1.7 + (spot[2] % 3) * 0.1, spot[1] < 0 and 0.08 or -0.08)
	end
	-- Light poles with warm lamps and string lights across the plaza.
	for _, spot in ipairs({ { -30, 236 }, { 30, 236 }, { -30, 282 }, { 30, 282 }, { -62, 214 }, { 62, 214 }, { -62, 312 }, { 62, 312 } }) do
		box(hub, "LightPole", spot[1], 6, spot[2], 0.5, 12, 0.5, P.ink, Enum.Material.Metal)
		sphere(hub, "LightGlobe", Vector3.new(spot[1], 12.6, spot[2]), Vector3.new(1.8, 1.8, 1.8), P.gold, Enum.Material.Neon)
		light(hub, Vector3.new(spot[1], 11.8, spot[2]), P.gold, 0.9, 26)
	end
	for _, z in ipairs({ 236, 282 }) do
		for i = -8, 8 do
			local x = i * 3.6
			sphere(hub, "StringBulb", Vector3.new(x, 12.2 - (1 - (i / 8) ^ 2) * 1.2 * -1 - 1.2, z), Vector3.new(0.6, 0.6, 0.6), i % 2 == 0 and P.gold or P.pink, Enum.Material.Neon)
		end
	end
	-- Plaza edge: low wall, neon curb and invisible containment.
	for _, e in ipairs({ { -78, HC, 2, 124 }, { 78, HC, 2, 124 }, { 0, 324, 154, 2 } }) do
		box(hub, "PlazaWall", e[1], 1.6, e[2], e[3], 3.2, e[4], P.navy, Enum.Material.Concrete)
		neon(hub, "PlazaWallGlow", e[1], 3.3, e[2], e[3] > 3 and e[3] or 0.3, 0.16, e[4] > 3 and e[4] or 0.3, P.cyan)
	end
	for _, e in ipairs({ { -80, HC, 2, 130 }, { 80, HC, 2, 130 }, { 0, 326, 162, 2 }, { 0, 194, 162, 2 } }) do
		local w = box(hub, "HubBoundary", e[1], 30, e[2], e[3], 60, e[4], P.ink)
		w.Transparency = 1
		w.CastShadow = false
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(0, 0.1, 312)
	spawn.Transparency = 1
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub
	partCount += 1
	cylinder(hub, "SpawnRing", Vector3.new(0, 0.1, 312), 22, 0.1, P.cyan, Enum.Material.Neon, false):SetAttribute("Pulse", 2)
	sign(hub, "WELCOME TO THE PLAZA", Vector3.new(0, 6, 322.8), 24, 2.4, P.white, math.pi)
	local lobbySpawn = CFrame.lookAt(Vector3.new(0, 3.4, 312), Vector3.new(0, 3.4, 215))

	-- =====================================================================================
	-- SKYLINE: distant towers frame the mall and the Plaza. No collision, no shadows.
	-- =====================================================================================
	box(skyline, "CityBelow", 0, -30, 130, 1100, 8, 1100, P.ink, Enum.Material.Concrete, false)
	local towers = {
		{ -170, -110, 40, 44, 95, P.navy }, { -168, -30, 38, 44, 70, P.purple }, { -172, 60, 42, 42, 110, P.teal }, { -170, 150, 40, 40, 80, P.navy },
		{ 172, -105, 40, 44, 105, P.purple }, { 170, -20, 40, 42, 75, P.navy }, { 168, 70, 42, 44, 120, P.teal }, { 172, 150, 40, 40, 85, P.purple },
		{ -90, -140, 42, 40, 90, P.teal }, { 0, -150, 46, 40, 120, P.navy }, { 90, -140, 42, 40, 80, P.purple },
		{ -130, 190, 36, 40, 65, P.purple }, { 130, 190, 36, 40, 75, P.teal }, { -140, 270, 40, 42, 100, P.navy }, { 140, 270, 40, 42, 90, P.purple },
		{ -100, 370, 44, 40, 110, P.teal }, { 0, 380, 48, 40, 130, P.navy }, { 100, 370, 44, 40, 95, P.purple },
	}
	for i, t in ipairs(towers) do
		local x, z, w, d, h, c = table.unpack(t)
		box(skyline, "Tower", x, h / 2 - 30, z, w, h, d, c, Enum.Material.Concrete, false).CastShadow = false
		box(skyline, "TowerSetback", x + w * 0.1, h - 26, z, w * 0.7, 8, d * 0.7, P.white, Enum.Material.Concrete, false).CastShadow = false
		for row = 1, math.floor(h / 22) do
			local glow = (row + i) % 3 == 0 and P.gold or ((row + i) % 3 == 1 and P.cyan or P.magenta)
			local band = box(skyline, "WindowBand", x, row * 18 - 22, z + ((z < 100) and 1 or -1) * (d / 2 + 0.1), w - 6, 0.7, 0.12, glow, Enum.Material.Neon, false)
			band.CastShadow = false
		end
	end
	for _, scenery in ipairs(skyline:GetChildren()) do
		if scenery:IsA("BasePart") then scenery.CastShadow = false end
	end

	-- =====================================================================================
	-- FINISH: metadata, spawns, bounds
	-- =====================================================================================
	applyLighting()
	model:SetAttribute("StaticPartCount", partCount)
	model:SetAttribute("ElevatedRouteCount", 6)
	model:SetAttribute("DynamicObstacleCount", #gates)
	model:SetAttribute("StoreCount", 10)
	model.Parent = workspace
	built = {
		Model = model,
		LobbySpawn = lobbySpawn,
		RunnerSpawns = runnerSpawns,
		HunterSpawns = hunterSpawns,
		Podiums = podiums,
		Bounds = { min = Vector3.new(-140, -25, -104), max = Vector3.new(140, 70, 104) },
	}
	model:SetAttribute("CatchMapVersion", MAP_VERSION)
	model:SetAttribute("LobbySpawn", built.LobbySpawn)
	model:SetAttribute("BoundsMin", built.Bounds.min)
	model:SetAttribute("BoundsMax", built.Bounds.max)
	for _, kind in ipairs({ "Runner", "Hunter", "Podium" }) do
		local values = kind == "Podium" and built.Podiums or built[kind .. "Spawns"]
		model:SetAttribute(kind .. "Count", #values)
		for i, transform in ipairs(values) do model:SetAttribute(kind .. "Spawn" .. i, transform) end
	end
	if not static then activateObstacles(model) end
	return built
end

return MapBuilder
