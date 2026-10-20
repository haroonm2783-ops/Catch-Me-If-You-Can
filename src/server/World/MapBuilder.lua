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
	white = Color3.fromRGB(246, 246, 250), marble = Color3.fromRGB(238, 230, 220), marble2 = Color3.fromRGB(214, 204, 196),
	cream = Color3.fromRGB(248, 234, 208), navy = Color3.fromRGB(38, 48, 92), ink = Color3.fromRGB(24, 28, 52),
	purple = Color3.fromRGB(128, 88, 220), magenta = Color3.fromRGB(238, 74, 190), cyan = Color3.fromRGB(70, 226, 238),
	blue = Color3.fromRGB(72, 142, 255), coral = Color3.fromRGB(255, 108, 114), gold = Color3.fromRGB(255, 198, 86),
	green = Color3.fromRGB(62, 182, 118), leaf = Color3.fromRGB(104, 204, 104), wood = Color3.fromRGB(164, 110, 68),
	teal = Color3.fromRGB(44, 190, 192), pink = Color3.fromRGB(255, 152, 202), glass = Color3.fromRGB(156, 216, 242),
	steel = Color3.fromRGB(150, 160, 178), red = Color3.fromRGB(214, 48, 70), orange = Color3.fromRGB(255, 152, 70),
	soil = Color3.fromRGB(70, 60, 54), yellow = Color3.fromRGB(255, 226, 96),
}

local function applyLighting()
	-- Bright golden hour streaming through the skylights; neon is accent, never the only light.
	Lighting.ClockTime = 16.2
	Lighting.Brightness = 2.8
	Lighting.Ambient = Color3.fromRGB(168, 164, 190)
	Lighting.OutdoorAmbient = Color3.fromRGB(186, 178, 204)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 232, 205)
	Lighting.ExposureCompensation = 0.35
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.7
	for _, name in ipairs({ "CatchAtmosphere", "CatchBloom", "CatchColor", "CatchSunRays", "CatchSky" }) do
		local old = Lighting:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "CatchAtmosphere"
	atmosphere.Density = 0.16
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(206, 196, 238)
	atmosphere.Decay = Color3.fromRGB(255, 170, 160)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 0.6
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "CatchBloom"
	bloom.Intensity = 0.38
	bloom.Size = 28
	bloom.Threshold = 1.15
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "CatchColor"
	color.Contrast = 0.1
	color.Saturation = 0.26
	color.TintColor = Color3.fromRGB(255, 246, 240)
	color.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Name = "CatchSunRays"
	rays.Intensity = 0.08
	rays.Spread = 0.6
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
		neon(parent, "CeilingLight", x, y, z, sx, 0.2, sz, color or P.white)
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
	-- MALL SHELL, FLOORS, ROOF
	-- =====================================================================================
	local VX, VZ = 36, 28 -- atrium void half-size
	local HX, HZ = 64, 48 -- hall half-size (wings and store rows lie outside)
	local TOP = 32 -- top of perimeter walls
	local stairHoles = { { -55, -45, -30, 8 }, { 45, 55, -8, 30 } }
	local voidHole = { -VX, VX, -VZ, VZ }
	local loungeHole = { -100, -76, -30, 30 }

	box(floors, "Foundation", 0, -2.2, 0, 236, 3.6, 172, P.navy, Enum.Material.Concrete)
	-- Ground floor: marble hall, tiled food court, carpeted arcade and two store rows.
	box(floors, "HallMarble", 0, -0.2, 0, 2 * HX, 0.4, 2 * HZ, P.marble, Enum.Material.Marble)
	box(floors, "FoodCourtFloor", -88, -0.2, 0, 48, 0.4, 96, Color3.fromRGB(246, 218, 178), Enum.Material.Marble)
	box(floors, "ArcadeFloor", 88, -0.2, 0, 48, 0.4, 96, P.navy, Enum.Material.SmoothPlastic)
	for _, zc in ipairs({ -64, 64 }) do box(floors, "StoreRowFloor", 0, -0.2, zc, 224, 0.4, 32, P.marble2, Enum.Material.Marble) end
	-- Hall inlay: concentric rings and diagonal bands give the marble a designed pattern.
	for i, d in ipairs({ 36, 28, 20 }) do
		art(floors, "InlayRing", Vector3.new(0.12, d + 12, d + 12), CFrame.new(0, 0.07, 0) * CFrame.Angles(0, 0, math.pi / 2), i == 2 and P.gold or P.blue, i == 2 and Enum.Material.Metal or Enum.Material.SmoothPlastic).Shape = Enum.PartType.Cylinder
	end
	for _, z in ipairs({ -40, 40 }) do
		art(floors, "AisleInlay", Vector3.new(120, 0.1, 0.8), Vector3.new(0, 0.06, z), P.gold, Enum.Material.Metal)
		art(floors, "AisleInlay", Vector3.new(120, 0.1, 0.35), Vector3.new(0, 0.06, z + (z < 0 and 2 or -2)), P.cyan, Enum.Material.Neon)
	end
	-- Second floor slab, with the atrium void, stairwells, and lounge window cut away.
	local function floor2(name, x1, x2, z1, z2, color, material, holes)
		slab(floors, name, x1, x2, z1, z2, F2, 1.2, color, material, holes)
	end
	floor2("UpperStoreRow", -112, 112, -80, -48, P.marble2, Enum.Material.Marble)
	floor2("UpperStoreRow", -112, 112, 48, 80, P.marble2, Enum.Material.Marble)
	local ringHoles = { voidHole, stairHoles[1], stairHoles[2] }
	floor2("UpperHall", -HX, HX, -HZ, HZ, P.marble, Enum.Material.Marble, ringHoles)
	floor2("UpperWestLounge", -112, -HX, -HZ, HZ, Color3.fromRGB(246, 218, 178), Enum.Material.Marble, { loungeHole })
	floor2("UpperEastDept", HX, 112, -HZ, HZ, P.marble2, Enum.Material.Marble)
	-- Trim and underside lights on the balcony edge, visible from the whole ground floor.
	local function edgeTrim(x1, x2, z1, z2)
		local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
		art(floors, "BalconyFascia", Vector3.new(x2 - x1 + 1, 1.8, z2 - z1 + 1), Vector3.new(cx, F2 - 1.6, cz), P.white, Enum.Material.SmoothPlastic)
	end
	for _, z in ipairs({ -VZ - 0.5, VZ + 0.5 }) do art(floors, "FasciaNeon", Vector3.new(2 * VX + 1, 0.25, 0.25), Vector3.new(0, F2 - 2.5, z), P.cyan, Enum.Material.Neon) end
	for _, x in ipairs({ -VX - 0.5, VX + 0.5 }) do art(floors, "FasciaNeon", Vector3.new(0.25, 0.25, 2 * VZ + 1), Vector3.new(x, F2 - 2.5, 0), P.magenta, Enum.Material.Neon) end
	for _, z in ipairs({ -VZ + 0.5, VZ - 0.5 }) do art(floors, "FasciaTrim", Vector3.new(2 * VX, 1.8, 0.8), Vector3.new(0, F2 - 1.5, z), P.white) end
	for _, x in ipairs({ -VX + 0.5, VX - 0.5 }) do art(floors, "FasciaTrim", Vector3.new(0.8, 1.8, 2 * VZ), Vector3.new(x, F2 - 1.5, 0), P.white) end
	-- Ground-floor ceiling lights under the second-floor ring.
	for _, x in ipairs({ -56, 56 }) do for z = -40, 40, 16 do ceilingStrip(floors, x, F2 - 1.3, z, 6, 1.2, P.white) end end
	for _, z in ipairs({ -40, 40 }) do for x = -24, 24, 16 do ceilingStrip(floors, x, F2 - 1.3, z, 6, 1.2, P.white) end end

	-- Perimeter: solid walls with window bands and pilasters, roof slabs over stores.
	local wallColor = P.cream
	for _, x in ipairs({ -113, 113 }) do box(shell, "OuterWall", x, TOP / 2, 0, 2, TOP, 160, wallColor, Enum.Material.Concrete) end
	for _, z in ipairs({ -81, 81 }) do box(shell, "OuterWall", 0, TOP / 2, z, 228, TOP, 2, wallColor, Enum.Material.Concrete) end
	for _, z in ipairs({ -79.8, 79.8 }) do
		for x = -100, 100, 25 do
			glassBox(shell, "LoftWindow", x, 24, z, 14, 5, 0.3, 0.45, false)
			glassBox(shell, "LoftWindow", x, 7.5, z, 14, 4, 0.3, 0.45, false)
		end
	end
	for _, x in ipairs({ -111.8, 111.8 }) do
		for z = -60, 60, 30 do
			glassBox(shell, "LoftWindow", x, 24, z, 0.3, 5, 14, 0.45, false)
		end
	end
	for _, zc in ipairs({ -64, 64 }) do
		slab(shell, "StoreRowRoof", -112, 112, zc - 16, zc + 16, 31.2, 1.2, P.white, Enum.Material.Concrete)
	end
	-- Mall perimeter parapet cap and neon skyline line.
	for _, z in ipairs({ -80, 80 }) do art(shell, "RoofNeon", Vector3.new(224, 0.3, 0.3), Vector3.new(0, TOP + 0.2, z), P.magenta, Enum.Material.Neon) end
	slab(shell, "WestWingRoofSolid", -112, -HX, -HZ, HZ, 31.2, 1.2, P.white, Enum.Material.Concrete,
		{ { -108, -68, -42, 42 } })
	slab(shell, "EastWingRoofSolid", HX, 112, -HZ, HZ, 31.2, 1.2, P.white, Enum.Material.Concrete,
		{ { 68, 108, -42, 42 } })
	-- Wing skylights: glass between ribs, letting daylight reach the food court and department store.
	for _, side in ipairs({ -1, 1 }) do
		local cx = side * 88
		glassBox(shell, "WingSkylight", cx, 32.2, 0, 40, 0.3, 84, 0.5, false)
		for i = -2, 2 do artBeam(shell, "SkylightRib", Vector3.new(cx - 20, 32.7, i * 21), Vector3.new(cx + 20, 32.7, i * 21), 0.7, P.white, Enum.Material.Metal) end
		for i = -2, 2 do artBeam(shell, "SkylightRib", Vector3.new(cx + i * 10, 32.7, -42), Vector3.new(cx + i * 10, 32.7, 42), 0.5, P.white, Enum.Material.Metal) end
	end
	-- Hall barrel-vault roof: arched ribs and glass panels, peak at y=44.
	local R, rise, base = 176.7, 12, 32
	local centerY = base + rise - R
	local segments = 11
	local halfAngle = math.asin(HX / R)
	for s = 0, segments - 1 do
		local a0 = -halfAngle + s * (2 * halfAngle / segments)
		local a1 = a0 + 2 * halfAngle / segments
		local p0 = Vector3.new(math.sin(a0) * R, centerY + math.cos(a0) * R, 0)
		local p1 = Vector3.new(math.sin(a1) * R, centerY + math.cos(a1) * R, 0)
		local mid = (p0 + p1) / 2
		local angle = -math.atan2(p1.Y - p0.Y, p1.X - p0.X) * -1
		local len = (p1 - p0).Magnitude
		local glass = glassBox(shell, "VaultGlass", mid.X, mid.Y, 0, len + 0.05, 0.3, 2 * HZ + 2, 0.5, false, P.glass)
		glass.CFrame = CFrame.new(mid) * CFrame.Angles(0, 0, angle)
		for _, z in ipairs({ -HZ, -24, 0, 24, HZ }) do
			local rib = artBeam(shell, "VaultRib", Vector3.new(p0.X, p0.Y + 0.1, z), Vector3.new(p1.X, p1.Y + 0.1, z), 0.7, P.white, Enum.Material.Metal)
			rib.Size = Vector3.new(0.9, 0.9, len + 0.05)
		end
		for _, z in ipairs({ -HZ, HZ }) do
			box(shell, "VaultGable", (p0.X + p1.X) / 2, (base + mid.Y) / 2, z, len + 0.05, math.max(mid.Y - base, 0.2), 0.6, P.white, Enum.Material.Concrete, false):SetAttribute("VisualPolish", true)
		end
	end
	for _, x in ipairs({ -HX, HX }) do
		art(shell, "VaultCornice", Vector3.new(1.4, 1.2, 2 * HZ), Vector3.new(x, base + 0.6, 0), P.gold, Enum.Material.Metal)
	end
	for s = -3, 3 do
		neon(shell, "VaultLight", s * 16, 43.2 - math.abs(s) * 0.4 * 0.5, 0, 0.3, 0.2, 90, P.white)
	end

	-- Support columns on the balcony edge and glass balcony railings with designated gaps.
	local columns = {}
	for _, z in ipairs({ -VZ, -14, 14, VZ }) do for _, x in ipairs({ -VX, VX }) do table.insert(columns, { x, z }) end end
	for _, z in ipairs({ -VZ, VZ }) do table.insert(columns, { 0, z }) end
	for _, c in ipairs(columns) do
		cylinder(atrium, "Column", Vector3.new(c[1], 17.5, c[2]), 2.4, 35, P.white, Enum.Material.Marble)
		cylinder(atrium, "ColumnBase", Vector3.new(c[1], 0.6, c[2]), 3.4, 1.2, P.gold, Enum.Material.Metal, false)
		cylinder(atrium, "ColumnCollar", Vector3.new(c[1], F2 + 0.3, c[2]), 3, 0.6, P.gold, Enum.Material.Metal, false)
		neon(atrium, "ColumnLight", c[1], 10, c[2], 0.15, 12, 0.15, P.cyan)
	end
	local RAIL = 7.2
	local function railing(axis, fixed, a1, a2, gaps)
		local pieces = {}
		wall(atrium, "BalconyGlass", axis, fixed, a1, a2, F2, F2 + RAIL, 0.35, P.glass, Enum.Material.Glass, gaps)
		for _, g in ipairs(atrium:GetChildren()) do
			if g.Name == "BalconyGlass" and not g:GetAttribute("Tinted") then
				g:SetAttribute("Tinted", true)
				g.Transparency = 0.6
				g.CastShadow = false
			end
		end
		-- Metal handrail along the full run (gaps leave openings below only).
		local cx = (a1 + a2) / 2
		if axis == "x" then art(atrium, "Handrail", Vector3.new(a2 - a1, 0.3, 0.6), Vector3.new(cx, F2 + RAIL, fixed), P.gold, Enum.Material.Metal)
		else art(atrium, "Handrail", Vector3.new(0.6, 0.3, a2 - a1), Vector3.new(fixed, F2 + RAIL, cx), P.gold, Enum.Material.Metal) end
	end
	railing("x", -VZ + 0.4, -VX, VX, { { c = -20, w = 13, h = 12 }, { c = 20, w = 11, h = 12 } }) -- escalator top / drop zone
	railing("x", VZ - 0.4, -VX, VX, { { c = 20, w = 13, h = 12 }, { c = -20, w = 11, h = 12 } })
	railing("z", -VX + 0.4, -VZ, VZ, { { c = 0, w = 11, h = 12 } }) -- skybridge entrance
	railing("z", VX - 0.4, -VZ, VZ, { { c = 0, w = 11, h = 12 } })
	for _, z in ipairs({ -VZ, VZ }) do neon(atrium, "DropZoneMarker", z < 0 and 20 or -20, F2 + 0.07, z + (z < 0 and 1.2 or -1.2), 9, 0.06, 0.5, P.yellow, 1) end
	-- Skybridge across the atrium, directly over the fountain.
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
		-- Tread bands and pulsing chevrons mark the direction of travel without moving collision.
		for i = 1, 14 do
			art(routes, "Tread", Vector3.new(9.2, 0.06, 0.5), frame * CFrame.new(0, 0.06, length / 2 - i * length / 15), P.ink, Enum.Material.Metal)
		end
		for i = 1, 5 do
			local chev = neon(routes, "Chevron", 0, 0, 0, 3.2, 0.08, 0.5, accent, i)
			chev.CFrame = frame * CFrame.new(0, 0.09, length / 2 - i * length / 6)
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
	escalator("EscalatorWest", -20, 2, -VZ, P.cyan)
	escalator("EscalatorEast", 20, -2, VZ, P.magenta)
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
	stair("StairWest", -50, 8, -30, 10, P.gold)
	stair("StairEast", 50, -8, 30, 10, P.gold)
	sign(routes, "TO LEVEL 2", Vector3.new(-50, 12, 11), 12, 2.2, P.gold, 0)
	sign(routes, "TO LEVEL 2", Vector3.new(50, 12, -11), 12, 2.2, P.gold, math.pi)

	-- =====================================================================================
	-- ATRIUM CENTERPIECE: tiered fountain, palms, kiosks
	-- =====================================================================================
	cylinder(atrium, "FountainStep", Vector3.new(0, 0.4, 0), 27, 0.8, P.marble2, Enum.Material.Marble)
	cylinder(atrium, "FountainBasin", Vector3.new(0, 1.1, 0), 22, 1.8, P.white, Enum.Material.Marble)
	disc(atrium, "FountainWater", CFrame.new(0, 2.05, 0), 20, 0.1, P.blue, Enum.Material.Glass).Transparency = 0.35
	disc(atrium, "FountainGlow", CFrame.new(0, 0.9, 0), 28, 0.12, P.cyan, Enum.Material.Neon):SetAttribute("Pulse", 1)
	cylinder(atrium, "FountainPedestal", Vector3.new(0, 4.6, 0), 4, 5.6, P.white, Enum.Material.Marble)
	for i, tier in ipairs({ { 9, 8.4 }, { 6, 10.6 }, { 3.6, 12.2 } }) do
		cylinder(atrium, "FountainTier" .. i, Vector3.new(0, tier[2], 0), tier[1], 0.7, P.white, Enum.Material.Marble, false)
		disc(atrium, "TierWater", CFrame.new(0, tier[2] + 0.45, 0), tier[1] - 0.8, 0.08, P.cyan, Enum.Material.Glass).Transparency = 0.4
	end
	for i = 1, 8 do
		local angle = i * math.pi / 4
		local top = Vector3.new(math.cos(angle) * 8, 2.3, math.sin(angle) * 8)
		artBeam(atrium, "WaterJet", top, Vector3.new(math.cos(angle) * 5.2, 5.8, math.sin(angle) * 5.2), 0.22, P.cyan, Enum.Material.Neon).Transparency = 0.35
		neon(atrium, "FountainLamp", math.cos(angle) * 12.4, 1.1, math.sin(angle) * 12.4, 0.5, 0.5, 0.5, i % 2 == 0 and P.magenta or P.cyan)
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
	-- Corner palms planted in marble rings, rising toward the second-floor balcony.
	for _, c in ipairs({ { -30, -21 }, { 30, -21 }, { -30, 21 }, { 30, 21 } }) do
		cylinder(atrium, "PalmRing", Vector3.new(c[1], 0.7, c[2]), 7, 1.4, P.cream, Enum.Material.Concrete)
		cylinder(atrium, "PalmSoil", Vector3.new(c[1], 1.45, c[2]), 6, 0.1, P.soil, Enum.Material.Grass, false)
		palm(atrium, c[1], 1.4, c[2], 1.9, c[1] < 0 and 0.06 or -0.06)
	end
	for _, z in ipairs({ -16, 16 }) do bench(atrium, 0, 0, z * 1.05 + (z < 0 and -1 or 1) * 0.0, z < 0 and 0 or math.pi) end
	-- Banners hang from the roof ribs; they stay above second-floor head height.
	for _, c in ipairs({ { -VX + 3, -VZ + 1 }, { VX - 3, -VZ + 1 }, { -VX + 3, VZ - 1 }, { VX - 3, VZ - 1 } }) do
		local face = c[2] < 0 and 0 or math.pi
		local b = part(atrium, "AtriumBanner", Vector3.new(6, 18, 0.3), CFrame.new(c[1], 31, c[2]) * CFrame.Angles(0, face, 0), P.purple, Enum.Material.Fabric, false)
		b:SetAttribute("VisualPolish", true)
		surfaceText(b, Enum.NormalId.Back, "CATCH\nME IF\nYOU\nCAN", P.white, 30, 0.9, 0.9)
		neon(atrium, "BannerTrim", c[1], 22, c[2] + (c[2] < 0 and 0.2 or -0.2), 6.2, 0.2, 0.2, P.cyan)
	end
	-- Perimeter palms and benches along the ground-floor corridors.
	for _, c in ipairs({ { -60, -33 }, { 60, 33 }, { -60, 33 }, { 60, -33 }, { -30, -44 }, { 30, 44 } }) do
		planter(decor, c[1], 0, c[2], 8, 0, true)
		palm(decor, c[1], 1.4, c[2], 1.1, 0.1)
	end
	for _, c in ipairs({ { -40, -33 }, { 40, 33 }, { -40, 33 }, { 40, -33 } }) do bench(decor, c[1], 0, c[2], c[2] < 0 and 0 or math.pi) end
	-- Kiosks: vaultable carts with parasol canopies, placed clear of every ramp and stair.
	for _, c in ipairs({ { -50, 34, "SNACKS", P.coral }, { 50, -34, "TECH", P.cyan }, { -22, -42, "GIFTS", P.gold }, { 22, 42, "JUICE", P.green } }) do
		local cart = vaultTable(decor, c[1], 0, c[2], 8, 4, P.white, 0, c[4])
		sign(decor, c[3], Vector3.new(c[1], 6.4, c[2] + (c[2] < 0 and 2.8 or -2.8)), 6, 1.6, c[4], c[2] < 0 and 0 or math.pi)
		for _, dx in ipairs({ -3.6, 3.6 }) do art(decor, "CartPost", Vector3.new(0.25, 5, 0.25), Vector3.new(c[1] + dx, 4.1, c[2]), P.steel, Enum.Material.Metal) end
		art(decor, "CartCanopy", Vector3.new(9, 0.4, 5.4), Vector3.new(c[1], 7.2, c[2]), c[4], Enum.Material.Fabric)
	end
	-- Wayfinding screens double as pillars of color on the long corridors.
	for _, c in ipairs({ { -42, -45 }, { 42, 45 }, { -42, 45 }, { 42, -45 } }) do
		local pillar = box(decor, "DirectoryPillar", c[1], 5, c[2], 1.2, 10, 3, P.navy, Enum.Material.Metal)
		sign(decor, "MALL MAP", Vector3.new(c[1] + (c[1] < 0 and 0.7 or -0.7), 5.5, c[2]), 2.6, 3.6, P.cyan, c[1] < 0 and math.pi / 2 or -math.pi / 2)
	end

	-- =====================================================================================
	-- STORES: ten enterable shops with two or more exits each, plus dressed storefronts.
	-- =====================================================================================
	local boundariesX = { -112, -64, -21, 21, 64, 112 }
	local function storeCtx(def, folder)
		local north = def.row == "N"
		local fy = def.floor
		local ctx = { folder = folder, fy = fy, north = north, W = def.x2 - def.x1, accent = def.accent, color = def.color }
		function ctx.X(u) return def.x1 + u end
		function ctx.Z(v) return north and (-48 - v) or (48 + v) end
		function ctx.B(u, v, w, d, h, color, material, collide)
			return box(folder, "Prop", def.x1 + u, fy + h / 2, ctx.Z(v), w, h, d, color, material, collide)
		end
		function ctx.Vault(u, v, w, d, h, color, material)
			local p = ctx.B(u, v, w, d, h, color, material, true)
			p.Name = "VaultProp"
			p:SetAttribute("Vaultable", true)
			return p
		end
		function ctx.A(u, v, w, d, h, y, color, material)
			return art(folder, "Detail", Vector3.new(w, h, d), Vector3.new(def.x1 + u, fy + y, ctx.Z(v)), color, material)
		end
		function ctx.N(u, v, w, d, h, y, color)
			return neon(folder, "Glow", def.x1 + u, fy + y, ctx.Z(v), w, h, d, color)
		end
		function ctx.Sphere(u, v, y, size, color)
			return sphere(folder, "Ball", Vector3.new(def.x1 + u, fy + y, ctx.Z(v)), Vector3.new(size, size, size), color)
		end
		function ctx.Cyl(u, v, y, dia, h, color, material, collide)
			return cylinder(folder, "Round", Vector3.new(def.x1 + u, fy + y, ctx.Z(v)), dia, h, color, material, collide)
		end
		function ctx.Shelf(u, v, sx, sz, h, color, accent, spine)
			return shelf(folder, def.x1 + u, fy, ctx.Z(v), sx, sz, h, color, accent, spine)
		end
		function ctx.Sign(text, u, v, y, w, h, color, backWall)
			-- Faces the storefront opening.
			return sign(folder, text, Vector3.new(def.x1 + u, fy + y, ctx.Z(v)), w, h, color, north and 0 or math.pi)
		end
		return ctx
	end

	local themes = {}
	function themes.toy(c)
		local rainbow = { P.coral, P.orange, P.yellow, P.green, P.cyan, P.purple }
		for i = 1, 6 do c.A(c.W / 2, 8 + i * 3.2, 30, 1.2, 0.08, 0.14, rainbow[i], Enum.Material.SmoothPlastic) end
		-- Ball pit with low walls and spheres.
		c.B(9, 24, 13, 0.8, 1.6, P.pink); c.B(9, 30.5, 13, 0.8, 1.6, P.pink)
		c.B(2.6, 27, 0.8, 5.8, 1.6, P.pink)
		for i = 1, 10 do c.Sphere(4 + (i % 5) * 2.4, 25 + math.floor(i / 5) * 3, 1.3, 1.8, rainbow[(i % 6) + 1]) end
		-- Big alphabet blocks (vaultable) and a teddy landmark.
		for i, spec in ipairs({ { 36, 11, P.coral }, { 41, 21, P.cyan }, { 11, 9, P.yellow } }) do
			local block = c.Vault(spec[1], spec[2], 3.6, 3.6, 3.6, spec[3], Enum.Material.SmoothPlastic)
			c.N(spec[1], spec[2] - 1.85, 2.4, 0.1, 2.4, 1.8, P.white)
		end
		c.Sphere(40, 28, 3.4, 5.6, P.wood); c.Sphere(40, 28, 7, 3.6, P.wood)
		c.Sphere(38.7, 28, 8.6, 1.3, P.wood); c.Sphere(41.3, 28, 8.6, 1.3, P.wood)
		for i = 0, 3 do c.Shelf(14 + i * 9.5, 31, 8, 1.4, 6, P.white, rainbow[i + 1], rainbow[i + 3]) end
		c.Sign("TOYS", c.W / 2, 30.2, 8.5, 12, 3, P.yellow)
	end
	function themes.sneaker(c)
		c.Cyl(c.W / 2, 20, 1.1, 7.5, 2.2, P.white, Enum.Material.Marble)
		c.N(c.W / 2, 20, 8, 8, 0.1, 2.25, P.cyan)
		c.A(c.W / 2, 20, 4, 2, 1.3, 3, P.coral, Enum.Material.SmoothPlastic)
		c.A(c.W / 2 + 1.3, 20, 1.8, 2, 2, 3.4, P.white, Enum.Material.SmoothPlastic)
		for _, u in ipairs({ 8, 35 }) do c.B(u, 14, 8, 2.4, 1.4, P.navy, Enum.Material.SmoothPlastic); c.A(u, 14, 8, 2.4, 0.4, 1.5, P.cream, Enum.Material.Fabric) end
		c.Vault(7, 26, 4, 3, 3.2, P.orange, Enum.Material.SmoothPlastic)
		c.Vault(36, 8.5, 4, 3, 3.2, P.orange, Enum.Material.SmoothPlastic)
		for i = 0, 3 do c.Shelf(8 + i * 9, 31, 8, 1.4, 8, P.ink, i % 2 == 0 and P.cyan or P.magenta) end
		for _, v in ipairs({ 14, 21 }) do
			c.Shelf(0.7, v + 4, 1.2, 8, 7, P.ink, P.cyan)
			c.Shelf(c.W - 0.7, v + 4, 1.2, 8, 7, P.ink, P.magenta)
		end
		c.Sign("SNKR", c.W / 2, 30.2, 11, 14, 3.2, P.white)
	end
	function themes.electronics(c)
		for _, u in ipairs({ 9, 34 }) do for _, v in ipairs({ 11, 23 }) do
			local t = c.Vault(u, v, 8, 4, 3.2, P.white, Enum.Material.SmoothPlastic)
			c.A(u, v, 3.2, 0.2, 1.8, 4.1, P.blue, Enum.Material.Neon)
		end end
		for i = 0, 4 do c.N(5 + i * 8.2, 31.2, 7, 0.15, 4.4, 7.5, i % 2 == 0 and P.blue or P.cyan) end
		c.Vault(c.W / 2, 28, 12, 3, 3.4, P.ink, Enum.Material.Metal)
		c.Shelf(0.7, 20, 1.2, 12, 7, P.ink, P.blue); c.Shelf(c.W - 0.7, 20, 1.2, 12, 7, P.ink, P.blue)
		c.Sign("TECH+", c.W / 2, 30.2, 11.4, 14, 3, P.cyan)
	end
	function themes.clothing(c)
		for i, spec in ipairs({ { 7, 9 }, { 7, 17 }, { 39, 9 }, { 39, 17 } }) do
			c.A(spec[1], spec[2], 6, 0.3, 0.3, 4.4, P.steel, Enum.Material.Metal)
			for k = 0, 3 do c.A(spec[1] - 2 + k * 1.3, spec[2], 1, 0.5, 2.6, 3, ({ P.coral, P.cyan, P.white, P.ink })[(k + i) % 4 + 1], Enum.Material.Fabric) end
			c.A(spec[1] - 2.8, spec[2], 0.2, 0.2, 4.4, 2.2, P.steel, Enum.Material.Metal); c.A(spec[1] + 2.8, spec[2], 0.2, 0.2, 4.4, 2.2, P.steel, Enum.Material.Metal)
		end
		for _, u in ipairs({ 14, 24, 34 }) do mannequin(c.folder, c.X(u), c.fy, c.Z(26), u == 24 and P.coral or P.white) end
		c.Vault(14, 14.5, 10, 4, 3, P.white, Enum.Material.SmoothPlastic)
		c.Vault(34, 20, 10, 4, 3, P.white, Enum.Material.SmoothPlastic)
		for i = 0, 2 do c.B(c.W - 1.6, 8 + i * 4.2, 1.2, 4, 8, P.navy, Enum.Material.SmoothPlastic); c.A(c.W - 2.3, 8 + i * 4.2, 0.2, 3.6, 7, 4, P.purple, Enum.Material.Fabric) end
		c.Sign("NEXUS", c.W / 2, 30.2, 11, 14, 3, P.white)
	end
	function themes.book(c)
		-- Tall shelving forms lanes at least six studs wide.
		for _, u in ipairs({ 7, 36 }) do c.Shelf(u, 17, 1.6, 20, 9.5, P.wood, P.gold, P.coral) end
		for _, u in ipairs({ 11, 32 }) do c.Shelf(u, 24, 6, 1.6, 8, P.wood, P.gold, P.teal) end
		for i = 0, 3 do c.Shelf(7 + i * 9.8, 31, 8, 1.4, 11, P.wood, P.gold, P.purple) end
		c.Vault(c.W / 2, 20, 6, 6, 3, P.cream, Enum.Material.Wood)
		for _, d in ipairs({ { 17.5, 17 }, { 25.5, 23 } }) do c.A(d[1], d[2], 2.5, 2.5, 1.4, 1, P.coral, Enum.Material.Fabric) end
		c.Sign("PAGES", c.W / 2, 30.2, 12.2, 12, 2.8, P.gold)
	end
	function themes.convenience(c)
		for i = 0, 3 do
			c.B(6 + i * 9.4, 31, 8, 1.6, 7.6, P.white, Enum.Material.Metal)
			c.N(6 + i * 9.4, 30.1, 7.2, 0.1, 6.8, 4, P.cyan)
		end
		c.Vault(12, 15, 12, 2, 4.2, P.coral, Enum.Material.SmoothPlastic)
		c.Vault(32, 21, 12, 2, 4.2, P.yellow, Enum.Material.SmoothPlastic)
		c.Vault(c.W - 6, 6, 8, 3, 3.4, P.white, Enum.Material.SmoothPlastic)
		c.A(c.W - 6, 6, 1.4, 1.2, 1, 3.8, P.cyan, Enum.Material.Neon)
		c.Sign("QUIK", c.W / 2, 30.2, 11, 12, 3, P.yellow)
	end
	function themes.sports(c)
		for i, h in ipairs({ 2.2, 3.4, 4.4 }) do c.Vault(8 + i * 8, 14 + (i % 2) * 5, 6, 5, h, i == 2 and P.orange or P.blue, Enum.Material.SmoothPlastic) end
		c.B(c.W - 3, 24, 1, 8, 7, P.ink, Enum.Material.SmoothPlastic)
		for i = 1, 6 do c.A(c.W - 3.7, 21 + i * 1.1, 0.3, 1.1, 1.1, 2 + i * 0.9, ({ P.coral, P.yellow, P.cyan })[i % 3 + 1], Enum.Material.SmoothPlastic) end
		-- Basketball hoop on the back wall.
		c.A(c.W / 2, 31.4, 5, 0.3, 3.4, 11, P.white, Enum.Material.SmoothPlastic)
		c.Cyl(c.W / 2, 29.8, 10, 2.2, 0.15, P.orange, Enum.Material.Neon, false)
		for _, v in ipairs({ 14, 22 }) do c.Shelf(0.9, v, 1.2, 6, 6, P.ink, P.orange) end
		c.Sign("APEX", c.W / 2, 31.4, 13.5, 12, 2.8, P.orange)
	end
	function themes.jewelry(c)
		for _, spec in ipairs({ { 8, 10, 3, 10 }, { c.W - 8, 10, 3, 10 }, { c.W / 2, 25, 14, 3 } }) do
			local case = c.Vault(spec[1], spec[2], spec[3], spec[4], 3.4, P.white, Enum.Material.SmoothPlastic)
			c.A(spec[1], spec[2], spec[3] - 0.4, spec[4] - 0.4, 0.2, 3.6, P.glass, Enum.Material.Glass).Transparency = 0.5
			c.N(spec[1], spec[2], 0.8, 0.8, 0.12, 3.8, P.gold)
		end
		c.Cyl(c.W / 2, 17, 11.6, 9, 0.3, P.gold, Enum.Material.Neon, false)
		c.Cyl(c.W / 2, 17, 11.2, 5.5, 0.3, P.cyan, Enum.Material.Neon, false)
		c.Sphere(c.W / 2, 17, 10.2, 2, P.glass)
		c.A(c.W / 2, 31.4, 20, 0.3, 8, 7, P.purple, Enum.Material.Fabric)
		c.Sign("LUXE", c.W / 2, 30.9, 12.2, 12, 2.8, P.gold)
	end
	function themes.beauty(c)
		for _, spec in ipairs({ { 9, 11 }, { c.W - 9, 11 }, { c.W / 2, 23 } }) do
			c.Vault(spec[1], spec[2], 5, 5, 3.2, P.pink, Enum.Material.SmoothPlastic)
			c.Cyl(spec[1], spec[2], 3.4, 4.2, 0.2, P.white, Enum.Material.Metal, false)
			c.N(spec[1], spec[2], 0.7, 0.7, 0.4, 3.8, P.magenta)
		end
		for i = 0, 3 do
			local mirror = disc(c.folder, "Mirror", CFrame.new(c.X(7 + i * 9.4), c.fy + 8, c.Z(31.3)) * CFrame.Angles(0, c.north and 0 or math.pi, 0), 4.6, 0.3, P.white, Enum.Material.Glass)
			neon(c.folder, "MirrorGlow", c.X(7 + i * 9.4), c.fy + 8, c.Z(31.0), 5, 5, 0.1, P.pink)
		end
		c.Cyl(c.W - 4, 27, 3.6, 1.8, 7.2, P.magenta, Enum.Material.SmoothPlastic, true)
		c.Cyl(c.W - 4, 27, 8.2, 1.6, 2.6, P.red, Enum.Material.SmoothPlastic, false)
		c.Sign("GLOW", c.W / 2, 30.2, 12.2, 12, 2.8, P.pink)
	end

	local function buildStore(def)
		local folder = Instance.new("Folder")
		folder.Name = def.name
		folder.Parent = storesF
		local north = def.row == "N"
		local fy = def.floor
		local ceil = fy == 0 and F2 - 1.2 or 30
		local frontZ = north and -48 or 48
		local dir = north and -1 or 1
		local W = def.x2 - def.x1
		local cx = (def.x1 + def.x2) / 2
		local faceRot = north and 0 or math.pi
		if not def.enter then
			-- Dressed storefront: a solid block with glazing, display lighting, and a bold sign.
			box(folder, "ShopBlock", cx, fy + (ceil - fy) / 2, frontZ + dir * 16, W - 1, ceil - fy, 32, P.white, Enum.Material.Concrete)
			box(folder, "ShopPlinth", cx, fy + 0.6, frontZ - dir * 0.5, W - 1, 1.2, 1.2, def.color, Enum.Material.Marble, false):SetAttribute("VisualPolish", true)
			for i = 0, 2 do
				local gx = def.x1 + 5 + i * (W - 10) / 3 + (W - 10) / 6
				glassBox(folder, "DisplayGlass", gx, fy + 6.4, frontZ - dir * 0.2, (W - 12) / 3, 9, 0.3, 0.35, false, P.glass)
				neon(folder, "DisplayGlow", gx, fy + 11.2, frontZ - dir * 0.55, (W - 12) / 3, 0.2, 0.2, i % 2 == 0 and def.accent or P.gold)
				art(folder, "DisplayBox", Vector3.new(3, 3, 1), Vector3.new(gx, fy + 2.8, frontZ - dir * 1.4), def.color, Enum.Material.SmoothPlastic)
			end
			sign(folder, def.sign, Vector3.new(cx, fy + 13, frontZ - dir * 0.6), math.min(W - 8, 24), 3.2, def.accent, faceRot)
			return folder
		end
		local ctx = storeCtx(def, folder)
		-- Carpet and ceiling lights.
		art(folder, "Carpet", Vector3.new(W - 1.2, 0.1, 31), Vector3.new(cx, fy + 0.1, frontZ + dir * 16.2), def.color, Enum.Material.Fabric)
		art(folder, "CarpetBorder", Vector3.new(W - 1.2, 0.12, 1), Vector3.new(cx, fy + 0.11, frontZ + dir * 3), def.accent, Enum.Material.SmoothPlastic)
		for i = 1, 3 do ceilingStrip(folder, cx, ceil - 0.2, frontZ + dir * (6 + i * 7.5), W - 8, 0.8, i % 2 == 0 and def.accent or P.white) end
		-- Front: kick wall, glazing either side of a 16 stud opening, and a header band.
		local open = 16
		for _, side in ipairs({ -1, 1 }) do
			local mid = cx + side * (open / 2 + (W / 2 - open / 2) / 2)
			local span = W / 2 - open / 2
			box(folder, "KickWall", mid, fy + 0.6, frontZ, span, 1.2, 0.8, def.color, Enum.Material.Marble)
			glassBox(folder, "ShopWindow", mid, fy + 6.6, frontZ, span - 0.6, 10, 0.3, 0.45, true, P.glass)
			artBeam(folder, "Mullion", Vector3.new(mid, fy + 1.2, frontZ), Vector3.new(mid, fy + 11.6, frontZ), 0.3, def.accent, Enum.Material.Metal)
			neon(folder, "OpeningGlow", cx + side * (open / 2 + 0.2), fy + 6, frontZ, 0.2, 10.4, 0.5, def.accent)
		end
		neon(folder, "OpeningTopGlow", cx, fy + 11.4, frontZ, open + 0.6, 0.25, 0.5, def.accent)
		box(folder, "HeaderBand", cx, (fy + 11.6 + ceil) / 2, frontZ, W, ceil - fy - 11.6, 0.8, P.white, Enum.Material.Concrete)
		sign(folder, def.sign, Vector3.new(cx, fy + 13, frontZ - dir * 0.6), 18, 3.2, def.accent, faceRot)
		-- Projecting blade sign for sightlines along the corridor.
		local blade = box(folder, "BladeSign", def.x1 + 1.5, fy + 8, frontZ - dir * 1.8, 0.4, 5, 3, P.ink, Enum.Material.SmoothPlastic, false)
		blade:SetAttribute("VisualPolish", true)
		surfaceText(blade, Enum.NormalId.Right, string.sub(def.sign, 1, 1), def.accent, 40, 0.9, 0.9)
		surfaceText(blade, Enum.NormalId.Left, string.sub(def.sign, 1, 1), def.accent, 40, 0.9, 0.9)
		local theme = themes[def.theme]
		if theme then theme(ctx) end
		return folder
	end

	-- Row layouts: slot index -> store definition.
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
	local storeCount = 0
	for _, rowDef in ipairs(layout) do
		local fy, north = rowDef.floor, rowDef.row == "N"
		local ceil = fy == 0 and F2 - 1.2 or 30
		local z1, z2 = north and -80 or 48, north and -48 or 80
		local stores = {}
		for i, entry in ipairs(rowDef.list) do
			local def = { name = rowDef.row .. fy .. "_" .. entry[1], sign = entry[2], theme = entry[3], color = entry[4], accent = entry[5], enter = entry[6],
				x1 = slotX[i][1], x2 = slotX[i][2], floor = fy, row = rowDef.row }
			stores[i] = def
			if def.enter then
				buildStore(def)
				storeCount += 1
			else
				buildStore(def)
			end
		end
		-- Dividing walls: enterable neighbours connect with an offset side door, so stores chain into loops.
		for i = 2, 5 do
			local x = boundariesX[i]
			local gaps = {}
			if stores[i - 1].enter and stores[i].enter then
				local v = (i % 2 == 0) and 8 or 24
				local zc = north and (-48 - v) or (48 + v)
				table.insert(gaps, { c = zc, w = 8, h = 10 })
				neon(storesF, "DoorGlow", x, fy + 10.2, zc, 0.3, 0.2, 8.4, stores[i].accent)
				if i == 3 or i == 4 then
					-- Timing shutter on the chain's inner door: a low barrier that lifts periodically.
				end
			end
			wall(storesF, "DividerWall", "z", x, z1, z2, fy, ceil, 0.8, P.white, Enum.Material.Concrete, gaps)
		end
	end
	-- The two shutters sit in the Sneaker/Electronics and Bookstore/Convenience connecting doors.
	for index, spec in ipairs({ { -21, -48 - 24, P.cyan }, { -21, 48 + 24, P.magenta } }) do
		local x, z, accent = spec[1], spec[2], spec[3]
		local gate = box(routes, "MovingShortcutGate", x, 2.25, z, 0.7, 4.5, 7.6, accent, Enum.Material.Metal)
		gate:SetAttribute("DynamicObstacle", true)
		gate:SetAttribute("MovementTolerance", 8)
		gate:SetAttribute("GateClosedCFrame", gate.CFrame)
		gate:SetAttribute("GateCycle", 2.4 + index * 0.3)
		table.insert(gates, gate)
	end

	-- =====================================================================================
	-- FOOD COURT (west wing, ground floor): stalls, dining sets, three open sides
	-- =====================================================================================
	local ceil1 = F2 - 1.2
	for _, z in ipairs({ -40, -24, -8, 8, 24, 40 }) do
		cylinder(court, "CourtPillar", Vector3.new(-64, ceil1 / 2, z), 2.4, ceil1, P.white, Enum.Material.Marble)
		cylinder(court, "PillarRing", Vector3.new(-64, 0.5, z), 3.4, 1, P.gold, Enum.Material.Metal, false)
		neon(court, "PillarGlow", -64, 10, z, 0.2, 8, 0.2, P.orange)
	end
	local stalls = { { -36, "RAMEN", P.red }, { -18, "PIZZA", P.orange }, { 0, "SUSHI", P.teal }, { 18, "BURGER", P.yellow }, { 36, "TACO", P.green } }
	for _, s in ipairs(stalls) do
		local z, name, color = s[1], s[2], s[3]
		box(court, "StallBlock", -108, 1.9, z, 8, 3.8, 14.4, P.white, Enum.Material.Concrete)
		art(court, "StallCounterTop", Vector3.new(8.4, 0.3, 14.8), Vector3.new(-108, 3.95, z), color, Enum.Material.SmoothPlastic)
		box(court, "StallBack", -111.2, 7.4, z, 1.6, 14.8, 15, color, Enum.Material.Concrete)
		art(court, "StallCanopy", Vector3.new(7, 0.4, 14.8), CFrame.new(-107.6, 10.2, z) * CFrame.Angles(0, 0, math.rad(-6)), color, Enum.Material.Fabric)
		sign(court, name, Vector3.new(-110.2, 11.4, z), 12, 3.2, color, math.pi / 2)
		neon(court, "StallMenuGlow", -110.3, 7.2, z, 0.15, 3.4, 11, P.white)
		for i = -1, 1 do art(court, "StallLamp", Vector3.new(0.5, 0.5, 0.5), Vector3.new(-103.6, 5.4, z + i * 4.5), P.gold, Enum.Material.Neon) end
	end
	for _, col in ipairs({ -94, -76 }) do
		for _, z in ipairs({ -32, -11, 11, 32 }) do
			local color = ({ P.coral, P.teal, P.gold, P.purple })[(z > 0 and 1 or 0) + (col == -94 and 1 or 3)]
			vaultTable(court, col, 0, z, 6, 4, P.wood, 0, color)
			for _, c in ipairs({ { -4.4, 0 }, { 4.4, 0 } }) do chair(court, col + c[1], 0, z + c[2], color, c[1] < 0 and -math.pi / 2 or math.pi / 2) end
			for _, c in ipairs({ { 0, -3.6 }, { 0, 3.6 } }) do chair(court, col + c[1], 0, z + c[2], color, c[2] < 0 and math.pi or 0) end
		end
	end
	for _, z in ipairs({ -24, 0, 24 }) do
		for _, ring in ipairs({ { 9, 0.3 }, { 6, 0.5 } }) do
			art(court, "PendantRing", Vector3.new(0.3, ring[1], ring[1]), CFrame.new(-86, 12.4 - ring[2], z) * CFrame.Angles(0, 0, math.pi / 2), ring[2] < 0.4 and P.orange or P.yellow, Enum.Material.Neon).Shape = Enum.PartType.Cylinder
		end
		artBeam(court, "PendantWire", Vector3.new(-86, 12.4, z), Vector3.new(-86, ceil1, z), 0.1, P.ink)
	end
	sign(court, "FOOD COURT", Vector3.new(-66.2, 12.6, 0), 22, 3.6, P.orange, math.pi / 2)
	for _, z in ipairs({ -46, 46 }) do
		planter(court, -84, 0, z, 16, 0, true)
		palm(court, -88, 1.4, z, 1.1, 0.1)
	end
	for _, c in ipairs({ { -104, -44 }, { -104, 44 } }) do palm(court, c[1], 0, c[2], 1.0, 0.1) end

	-- =====================================================================================
	-- ARCADE (east wing, ground floor): neon cabinets, three entrances
	-- =====================================================================================
	wall(arcade, "ArcadeWall", "z", HX, -HZ, HZ, 0, ceil1, 0.8, P.navy, Enum.Material.Concrete,
		{ { c = -30, w = 14, h = 11 }, { c = 0, w = 14, h = 11 }, { c = 30, w = 14, h = 11 } })
	for _, z in ipairs({ -30, 0, 30 }) do
		neon(arcade, "EntranceGlow", HX, 11.4, z, 0.4, 0.25, 14.6, P.magenta)
		for _, side in ipairs({ -1, 1 }) do neon(arcade, "EntranceGlow", HX, 5.5, z + side * 7.3, 0.4, 11, 0.25, P.cyan) end
	end
	sign(arcade, "ARCADE", Vector3.new(HX - 0.6, 13, -15), 14, 2.4, P.magenta, -math.pi / 2)
	sign(arcade, "PLAY", Vector3.new(HX - 0.6, 13, 15), 14, 2.4, P.cyan, -math.pi / 2)
	local cabColors = { P.magenta, P.cyan, P.yellow, P.green, P.coral, P.purple }
	local function cabinet(x, z, facing, i)
		local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, facing, 0)
		local color = cabColors[i % 6 + 1]
		part(arcade, "Cabinet", Vector3.new(3.2, 6.6, 2.6), cf * CFrame.new(0, 3.3, 0), P.ink, Enum.Material.SmoothPlastic)
		neon(arcade, "CabScreen", 0, 0, 0, 2.4, 2.2, 0.1, color).CFrame = cf * CFrame.new(0, 4.4, -1.35)
		neon(arcade, "CabMarquee", 0, 0, 0, 3.2, 0.8, 0.1, color).CFrame = cf * CFrame.new(0, 6.2, -1.35)
		art(arcade, "CabPanel", Vector3.new(3, 0.6, 1.2), cf * CFrame.new(0, 2.8, -1.5) * CFrame.Angles(math.rad(-20), 0, 0), color, Enum.Material.SmoothPlastic)
	end
	for i = 0, 7 do cabinet(110.2, -42 + i * 12, math.pi / 2, i) end
	local idx = 0
	for _, z0 in ipairs({ -36, 16 }) do
		for k = 0, 3 do
			idx += 1
			cabinet(98, z0 + k * 6.4, -math.pi / 2, idx)
			cabinet(101.4, z0 + k * 6.4, math.pi / 2, idx + 2)
		end
	end
	for _, z in ipairs({ -42, 42 }) do
		vaultTable(arcade, 80, 0, z, 9, 5, P.ink, 0, P.cyan)
		neon(arcade, "HockeyLine", 80, 3.5, z, 0.2, 0.1, 5, P.magenta)
	end
	-- Rhythm stage: a low neon platform with a step all round.
	box(arcade, "DanceStage", 82, 0.4, 0, 14, 0.8, 14, P.ink, Enum.Material.SmoothPlastic)
	for i = -1, 1 do for j = -1, 1 do neon(arcade, "DanceTile", 82 + i * 4.4, 0.85, j * 4.4, 3.6, 0.08, 3.6, (i + j) % 2 == 0 and P.magenta or P.cyan) end end
	for z = -44, 44, 11 do for x = 72, 108, 12 do
		art(arcade, "CarpetZig", Vector3.new(7, 0.06, 0.6), CFrame.new(x, 0.1, z) * CFrame.Angles(0, math.rad(35), 0), (x + z) % 2 == 0 and P.magenta or P.cyan, Enum.Material.Neon)
	end end
	for x = 72, 108, 12 do ceilingStrip(arcade, x, ceil1 - 0.2, 0, 0.6, 90, x % 24 == 0 and P.magenta or P.cyan) end
	sign(arcade, "INSERT COIN", Vector3.new(110.4, 10, 0), 22, 3, P.yellow, -math.pi / 2)

	-- =====================================================================================
	-- SECOND FLOOR WINGS: Department store (east) and Sky Lounge (west)
	-- =====================================================================================
	wall(storesF, "DeptWall", "z", HX, -HZ, HZ, F2, 30, 0.8, P.white, Enum.Material.Concrete,
		{ { c = -30, w = 14, h = 12 }, { c = 0, w = 14, h = 12 }, { c = 30, w = 14, h = 12 } })
	for _, z in ipairs({ -30, 0, 30 }) do
		neon(storesF, "DeptDoorGlow", HX, F2 + 12.2, z, 0.4, 0.25, 14.6, P.gold)
	end
	sign(storesF, "ZENITH", Vector3.new(HX - 0.6, F2 + 14.6, 0), 26, 3.6, P.gold, -math.pi / 2)
	art(storesF, "DeptCarpet", Vector3.new(46, 0.1, 94), Vector3.new(88, F2 + 0.1, 0), P.cream, Enum.Material.Fabric)
	cylinder(storesF, "MannequinStage", Vector3.new(88, F2 + 0.5, 0), 15, 1, P.white, Enum.Material.Marble)
	for i = 1, 6 do
		local a = i * math.pi / 3
		mannequin(storesF, 88 + math.cos(a) * 5, F2 + 1, math.sin(a) * 5, i % 2 == 0 and P.coral or P.blue)
	end
	cylinder(storesF, "StageGlow", Vector3.new(88, F2 + 1.05, 0), 15.4, 0.08, P.gold, Enum.Material.Neon, false)
	for _, spec in ipairs({ { 76, -30 }, { 100, -30 }, { 76, 30 }, { 100, 30 }, { 76, -12 }, { 100, 12 } }) do
		vaultTable(storesF, spec[1], F2, spec[2], 10, 4, P.white, 0, P.pink)
		art(storesF, "FoldedStack", Vector3.new(7, 0.8, 2.6), Vector3.new(spec[1], F2 + 3.8, spec[2]), ({ P.coral, P.cyan, P.gold })[(spec[2] > 0 and 1 or 2) + (spec[1] > 80 and 1 or 0)], Enum.Material.Fabric)
	end
	for _, z in ipairs({ -42, 42 }) do for _, x in ipairs({ 74, 88, 102 }) do
		box(storesF, "RackSection", x, F2 + 3.5, z, 8, 7, 1.4, P.ink, Enum.Material.SmoothPlastic)
		neon(storesF, "RackGlow", x, F2 + 5, z + (z < 0 and 0.75 or -0.75), 7, 0.15, 0.1, P.gold)
	end end
	for _, z in ipairs({ -42, 42 }) do for x = -1, 1 do mannequin(storesF, 88 + x * 8, F2, z + (z < 0 and 1.6 or -1.6), P.white) end end
	sign(storesF, "ZENITH", Vector3.new(111, F2 + 12, 0), 28, 4, P.gold, -math.pi / 2)
	-- Sky Lounge window onto the food court: railing around the cutaway.
	local lx1, lx2, lz1, lz2 = loungeHole[1], loungeHole[2], loungeHole[3], loungeHole[4]
	local function loungeRail(axis, fixed, a1, a2)
		local g = wall(atrium, "LoungeGlass", axis, fixed, a1, a2, F2, F2 + RAIL, 0.35, P.glass, Enum.Material.Glass)
		if axis == "x" then art(atrium, "Handrail", Vector3.new(a2 - a1, 0.3, 0.6), Vector3.new((a1 + a2) / 2, F2 + RAIL, fixed), P.gold, Enum.Material.Metal)
		else art(atrium, "Handrail", Vector3.new(0.6, 0.3, a2 - a1), Vector3.new(fixed, F2 + RAIL, (a1 + a2) / 2), P.gold, Enum.Material.Metal) end
	end
	loungeRail("x", lz1 + 0.4, lx1, lx2); loungeRail("x", lz2 - 0.4, lx1, lx2)
	loungeRail("z", lx1 + 0.4, lz1, lz2); loungeRail("z", lx2 - 0.4, lz1, lz2)
	for _, child in ipairs(atrium:GetChildren()) do
		if child.Name == "LoungeGlass" then child.Transparency = 0.6; child.CastShadow = false end
	end
	sign(storesF, "SKY LOUNGE", Vector3.new(-111.4, F2 + 14, 0), 22, 3.4, P.cyan, math.pi / 2)
	for _, spec in ipairs({ { -106, -38 }, { -106, 38 }, { -70, -38 }, { -70, 38 } }) do
		planter(decor, spec[1], F2, spec[2], 8, spec[1] < -90 and math.pi / 2 or math.pi / 2, true)
		palm(decor, spec[1], F2 + 1.4, spec[2], 1.0, 0.1)
	end
	for _, spec in ipairs({ { -106, 0 }, { -70, 0 } }) do bench(decor, spec[1], F2, spec[2], spec[1] < -90 and math.pi / 2 or -math.pi / 2) end
	for _, x in ipairs({ -64 }) do
		for _, z in ipairs({ -40, -24, -8, 8, 24, 40 }) do
			cylinder(court, "UpperPillar", Vector3.new(x, F2 + 7.4, z), 2.2, 14.8, P.white, Enum.Material.Marble)
		end
	end
	-- Upper hall furniture: benches and planters on the balcony ring.
	for _, spec in ipairs({ { -50, 40 }, { 50, -40 }, { -50, -40 }, { 50, 40 } }) do
		planter(decor, spec[1], F2, spec[2], 10, 0, true)
		bench(decor, spec[1] + (spec[1] < 0 and 12 or -12), F2, spec[2], spec[2] < 0 and 0 or math.pi)
	end
	for _, spec in ipairs({ { -58, 20 }, { 58, -20 } }) do palm(decor, spec[1], F2 + 0, spec[2], 1.2, 0.1) end

	-- =====================================================================================
	-- SPAWNS (runners spread over both floors; hunters start on the ground floor)
	-- =====================================================================================
	local function spawnFacing(x, y, z)
		return CFrame.lookAt(Vector3.new(x, y + 3.3, z), Vector3.new(0, y + 3.3, 0))
	end
	local runnerSpawns = {
		spawnFacing(-88, F2, -55), spawnFacing(-42, F2, -55), spawnFacing(0, F2, -55), spawnFacing(-88, F2, -34),
		spawnFacing(88, F2, -22), spawnFacing(88, F2, 30), spawnFacing(0, F2, 38), spawnFacing(-58, F2, 28),
		spawnFacing(88, 0, -24), spawnFacing(-88, 0, 26), spawnFacing(-88, 0, 66), spawnFacing(0, 0, 66),
	}
	local hunterSpawns = { spawnFacing(-8, 0, -38), spawnFacing(8, 0, 38) }

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
		Bounds = { min = Vector3.new(-122, -25, -92), max = Vector3.new(122, 70, 92) },
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
