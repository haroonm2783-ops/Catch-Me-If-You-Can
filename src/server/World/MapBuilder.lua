--!nonstrict
-- NEON HEIGHTS: a deliberately composed six-rooftop chase circuit.
-- All route endpoints are walking-surface coordinates. No asset downloads required.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local MapBuilder = {}
local built
local P = {
	ink = Color3.fromRGB(19, 29, 48),
	navy = Color3.fromRGB(30, 48, 70),
	steel = Color3.fromRGB(68, 88, 105),
	concrete = Color3.fromRGB(128, 143, 153),
	cream = Color3.fromRGB(240, 222, 186),
	white = Color3.fromRGB(228, 238, 233),
	teal = Color3.fromRGB(53, 161, 165),
	cyan = Color3.fromRGB(77, 239, 229),
	coral = Color3.fromRGB(232, 115, 117),
	pink = Color3.fromRGB(250, 113, 174),
	gold = Color3.fromRGB(255, 198, 100),
	purple = Color3.fromRGB(114, 104, 168),
	green = Color3.fromRGB(83, 150, 121),
	leaf = Color3.fromRGB(123, 184, 133),
	soil = Color3.fromRGB(57, 59, 61),
	road = Color3.fromRGB(36, 46, 62),
	glass = Color3.fromRGB(46, 86, 105),
}

local function applyLighting()
	Lighting.ClockTime = 18.6
	Lighting.Brightness = 2.3
	Lighting.Ambient = Color3.fromRGB(91, 91, 119)
	Lighting.OutdoorAmbient = Color3.fromRGB(111, 118, 146)
	Lighting.ExposureCompensation = 0.12
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4
	Lighting.EnvironmentDiffuseScale = 0.55
	Lighting.EnvironmentSpecularScale = 0.65
	for _, name in ipairs({ "CatchAtmosphere", "CatchBloom", "CatchColor" }) do
		local old = Lighting:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "CatchAtmosphere"
	atmosphere.Density = 0.29
	atmosphere.Offset = 0.12
	atmosphere.Color = Color3.fromRGB(182, 196, 227)
	atmosphere.Decay = Color3.fromRGB(101, 90, 132)
	atmosphere.Glare = 0.15
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "CatchBloom"
	bloom.Intensity = 0.25
	bloom.Size = 28
	bloom.Threshold = 1.3
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "CatchColor"
	color.Contrast = 0.1
	color.Saturation = -0.025
	color.TintColor = Color3.fromRGB(255, 245, 237)
	color.Parent = Lighting
end

function MapBuilder.Build()
	if built and built.Model.Parent then return built end
	local model = Instance.new("Model")
	model.Name = "NeonHeights"
	model:SetAttribute("MapName", "NEON HEIGHTS")
	model:SetAttribute("ArtDirection", "Twilight couriers / warm concrete / electric mint")
	local partCount = 0
	local tweens = {}
	local function group(name)
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = model
		return folder
	end
	local terrain = group("StreetsAndPlaza")
	local district = group("Architecture")
	local routes = group("ParkourRoutes")
	local props = group("StreetLife")
	local skyline = group("DistantSkyline")
	local lobby = group("SocialDeck")
	local function part(parent, name, size, cf, color, material, collide)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
		p.Color = color or P.concrete
		p.Material = material or Enum.Material.SmoothPlastic
		p.Anchored = true
		p.CanCollide = collide ~= false
		p.CanTouch = false
		p.CanQuery = p.CanCollide
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CastShadow = material ~= Enum.Material.Neon
		p.Parent = parent
		partCount += 1
		return p
	end
	local function box(parent, name, x, y, z, sx, sy, sz, color, material, collide)
		return part(parent, name, Vector3.new(sx, sy, sz), Vector3.new(x, y, z), color, material, collide)
	end
	local function beam(parent, name, a, b, width, color, material, collide)
		local delta = b - a
		return part(parent, name, Vector3.new(width, width, delta.Magnitude), CFrame.lookAt((a + b) / 2, b), color, material, collide)
	end
	local function cylinder(parent, name, center, diameter, height, color, material, collide)
		local p = part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), color, material, collide)
		p.Shape = Enum.PartType.Cylinder
		return p
	end
	local function sphere(parent, name, center, size, color)
		local p = part(parent, name, size, center, color, Enum.Material.SmoothPlastic, false)
		p.Shape = Enum.PartType.Ball
		return p
	end
	local function sign(parent, text, center, width, height, accent, rotation)
		local cf = CFrame.new(center) * CFrame.Angles(0, rotation or 0, 0)
		local backing = part(parent, "Sign_" .. text, Vector3.new(width, height, 0.35), cf, P.ink, nil, false)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 34
		gui.LightInfluence = 0
		gui.MaxDistance = 210
		gui.Parent = backing
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.94, 0.82)
		label.Position = UDim2.fromScale(0.03, 0.09)
		label.BackgroundTransparency = 1
		label.Text = text
		label.TextColor3 = accent or P.white
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.Parent = gui
		for _, side in ipairs({ -1, 1 }) do
			part(parent, "SignEdge", Vector3.new(width, 0.14, 0.16), cf * CFrame.new(0, side * height / 2, -0.22), accent, Enum.Material.Neon, false)
		end
		return backing
	end
	local function light(parent, center, color, brightness, range)
		local bulb = box(parent, "Lamp", center.X, center.Y, center.Z, 1.3, 0.25, 1.3, color, Enum.Material.Neon, false)
		local point = Instance.new("PointLight")
		point.Color = color
		point.Brightness = brightness or 0.6
		point.Range = range or 16
		point.Shadows = false
		point.Parent = bulb
	end
	local function route(name, a, b, width, color, rails)
		-- These broad, continuous surfaces stay below the default humanoid slope limit.
		local cf = CFrame.lookAt((a + b) / 2, b)
		local length = (b - a).Magnitude
		local deck = part(routes, name, Vector3.new(width, 0.7, length + 0.4), cf * CFrame.new(0, -0.35, 0), P.steel, Enum.Material.Metal)
		deck:SetAttribute("TraversalRoute", true)
		for _, side in ipairs({ -1, 1 }) do
			part(routes, name .. "_Edge", Vector3.new(0.18, 0.08, length), cf * CFrame.new(side * (width / 2 - 0.25), 0.07, 0), color or P.cyan, Enum.Material.Neon, false)
			if rails then
				part(routes, "Handrail", Vector3.new(0.18, 0.18, length), cf * CFrame.new(side * (width / 2 - 0.25), 2.8, 0), P.white, Enum.Material.Metal, false)
				for _, along in ipairs({ -length * 0.45, 0, length * 0.45 }) do
					part(routes, "RailPost", Vector3.new(0.2, 2.8, 0.2), cf * CFrame.new(side * (width / 2 - 0.25), 1.4, along), P.steel, Enum.Material.Metal, false)
				end
			end
		end
		return deck
	end
	local function stair(name, origin, width, rise, run, direction)
		local steps = math.ceil(rise / 0.8)
		local cf = CFrame.new(origin) * CFrame.Angles(0, direction or 0, 0)
		for i = 1, steps do
			local h = rise * i / steps
			part(routes, name, Vector3.new(width, h, run / steps + 0.05), cf * CFrame.new(0, h / 2, -run * (i - 0.5) / steps), P.concrete, Enum.Material.Concrete)
		end
	end
	local function ladder(x, z, roof, rotation)
		local cf = CFrame.new(x, roof / 2 + 0.25, z) * CFrame.Angles(0, rotation or 0, 0)
		local climb = Instance.new("TrussPart")
		climb.Name = "ServiceLadder"
		climb.Size = Vector3.new(2, roof + 2.5, 2)
		climb.CFrame = cf
		climb.Color = P.gold
		climb.Material = Enum.Material.Metal
		climb.Style = Enum.Style.BridgeStyleSupports
		climb.Anchored = true
		climb.CanTouch = false
		climb.Parent = routes
		partCount += 1
	end
	local function planter(parent, x, y, z, length, orientation, flowers)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, orientation or 0, 0)
		part(parent, "Planter", Vector3.new(length, 1.5, 3), cf * CFrame.new(0, 0.75, 0), P.cream, Enum.Material.Concrete)
		part(parent, "PlantingSoil", Vector3.new(length - 0.5, 0.15, 2.5), cf * CFrame.new(0, 1.55, 0), P.soil, nil, false)
		for i = 1, math.max(2, math.floor(length / 2.6)) do
			local offset = -length / 2 + i * length / (math.floor(length / 2.6) + 1)
			local pos = (cf * CFrame.new(offset, 2.1, 0)).Position
			sphere(parent, "ClippedShrub", pos, Vector3.new(2.6, 2.2, 2.3), i % 2 == 0 and P.green or P.leaf)
			if flowers then sphere(parent, "Blossom", pos + Vector3.new(0.3, 0.9, 0), Vector3.new(0.6, 0.55, 0.6), i % 2 == 0 and P.pink or P.gold) end
		end
	end
	local function tree(parent, x, y, z, scale)
		scale = scale or 1
		cylinder(parent, "TreeWell", Vector3.new(x, y + 0.25, z), 7 * scale, 0.5, P.cream, Enum.Material.Concrete)
		cylinder(parent, "TreeTrunk", Vector3.new(x, y + 4 * scale, z), 0.85 * scale, 8 * scale, P.soil, Enum.Material.Wood)
		sphere(parent, "TreeCrown", Vector3.new(x, y + 9 * scale, z), Vector3.new(8, 7, 8) * scale, P.green)
		sphere(parent, "TreeCrownLight", Vector3.new(x - 1.8 * scale, y + 10.5 * scale, z - 0.8 * scale), Vector3.new(6, 5, 6) * scale, P.leaf)
	end
	local function bench(parent, x, y, z, rotation)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, rotation or 0, 0)
		for _, offset in ipairs({ -2.7, 2.7 }) do
			part(parent, "BenchLeg", Vector3.new(0.5, 1.4, 2.5), cf * CFrame.new(offset, 0.7, 0), P.navy, Enum.Material.Metal)
		end
		for i = 1, 3 do
			part(parent, "BenchSlat", Vector3.new(7, 0.3, 0.6), cf * CFrame.new(0, 1.5, -1.1 + i * 0.7), P.cream, Enum.Material.Wood)
		end
		part(parent, "BenchBack", Vector3.new(7, 1.6, 0.3), cf * CFrame.new(0, 2.65, 1.1), P.cream, Enum.Material.Wood)
	end
	local function acUnit(x, y, z, rotation)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, rotation or 0, 0)
		part(props, "ClimateUnit", Vector3.new(6, 2.8, 4), cf * CFrame.new(0, 1.4, 0), P.concrete, Enum.Material.Metal)
		part(props, "VentPanel", Vector3.new(5.2, 2, 0.12), cf * CFrame.new(0, 1.5, -2.07), P.ink, Enum.Material.Metal, false)
		for i = 1, 5 do
			part(props, "VentLouvre", Vector3.new(5, 0.12, 0.16), cf * CFrame.new(0, 0.5 + i * 0.32, -2.2), P.steel, Enum.Material.Metal, false)
		end
		cylinder(props, "FanRim", (cf * CFrame.new(0, 2.85, 0)).Position, 2.6, 0.2, P.ink, Enum.Material.Metal, false)
		for _, angle in ipairs({ 0, math.pi / 2 }) do
			part(props, "FanBlade", Vector3.new(2.3, 0.08, 0.5), cf * CFrame.new(0, 3, 0) * CFrame.Angles(0, angle, 0), P.steel, Enum.Material.Metal, false)
		end
	end
	local function pipe(a, b, color)
		beam(props, "ServicePipe", a, b, 0.65, color or P.coral, Enum.Material.Metal, false)
	end
	local function canopy(parent, x, y, z, width, depth, color, rotation)
		local cf = CFrame.new(x, y, z) * CFrame.Angles(0, rotation or 0, 0)
		part(parent, "Canopy", Vector3.new(width, 0.4, depth), cf * CFrame.Angles(math.rad(-8), 0, 0), color, Enum.Material.Fabric, false)
		part(parent, "CanopyValance", Vector3.new(width, 0.9, 0.2), cf * CFrame.new(0, -0.6, -depth / 2), color, Enum.Material.Fabric, false)
		local sections = math.floor(width / 3)
		for i = 1, sections, 2 do
			part(parent, "CanopyStripe", Vector3.new(width / sections, 0.04, depth), cf * CFrame.Angles(math.rad(-8), 0, 0) * CFrame.new(-width / 2 + (i - 0.5) * width / sections, 0.24, 0), P.cream, Enum.Material.Fabric, false)
		end
	end
	local function building(name, x, z, w, d, h, color, accent)
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = district
		box(folder, "Foundation", x, 0.7, z, w + 1.4, 1.4, d + 1.4, P.navy, Enum.Material.Concrete)
		box(folder, "Facade", x, h / 2 - 0.2, z, w, h - 0.4, d, color, Enum.Material.Concrete)
		box(folder, "GroundFloorBand", x, 4.2, z, w + 0.4, 6.4, d + 0.4, P.ink, Enum.Material.Brick)
		box(folder, "StringCourse", x, 7.6, z, w + 0.8, 0.6, d + 0.8, P.cream, Enum.Material.Concrete)
		box(folder, "RoofCornice", x, h - 0.6, z, w + 1.6, 1.2, d + 1.6, P.cream, Enum.Material.Concrete)
		box(folder, "WalkingRoof", x, h - 0.15, z, w, 0.3, d, P.navy, Enum.Material.Concrete)
		for _, side in ipairs({ -1, 1 }) do
			-- Layered corner pilasters and restrained neon cornices give every block depth.
			for _, endSide in ipairs({ -1, 1 }) do
				box(folder, "Pilaster", x + side * (w / 2 - 1.2), h / 2, z + endSide * (d / 2 + 0.25), 2.4, h - 1.2, 0.9, color, Enum.Material.Concrete)
			end
			box(folder, "CorniceLight", x, h - 1.35, z + side * (d / 2 + 0.85), w - 5, 0.13, 0.12, accent, Enum.Material.Neon, false)
			local columns = math.floor((w - 8) / 10)
			for i = 1, columns do
				local wx = x - w / 2 + 5 + (i - 0.5) * (w - 10) / columns
				box(folder, "ShopGlass", wx, 4.3, z + side * (d / 2 + 0.25), 6.2, 4.6, 0.2, P.glass, Enum.Material.Glass, false)
				box(folder, "WarmDisplay", wx, 5.9, z + side * (d / 2 + 0.4), 5.2, 0.14, 0.12, i % 3 == 0 and accent or P.gold, Enum.Material.Neon, false)
				if h > 15 then
					box(folder, "UpperWindow", wx, h - 5.3, z + side * (d / 2 + 0.2), 4.6, 5.4, 0.22, P.glass, Enum.Material.Glass, false)
					box(folder, "WindowSill", wx, h - 8.1, z + side * (d / 2 + 0.5), 5, 0.35, 0.8, P.cream, nil, false)
					box(folder, "WindowMullion", wx, h - 5.3, z + side * (d / 2 + 0.35), 0.2, 5.4, 0.14, P.cream, nil, false)
				end
			end
			for i = 1, math.floor(d / 12) do
				local wz = z - d / 2 + 5 + (i - 0.5) * (d - 10) / math.floor(d / 12)
				box(folder, "SideWindow", x + side * (w / 2 + 0.2), h > 15 and h - 5.3 or 4.4, wz, 0.2, 4.6, 5.6, P.glass, Enum.Material.Glass, false)
				box(folder, "SideWindowGlow", x + side * (w / 2 + 0.32), h > 15 and h - 3.3 or 6.4, wz, 0.15, 0.13, 5, accent, Enum.Material.Neon, false)
			end
		end
		-- Corner parapets leave the middle of every edge open for bridges and ladders.
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				box(folder, "CornerParapet", x + sx * (w / 2 - 7), h + 0.9, z + sz * (d / 2 - 0.25), 13, 1.8, 0.65, color, Enum.Material.Concrete)
				box(folder, "CornerParapet", x + sx * (w / 2 - 0.25), h + 0.9, z + sz * (d / 2 - 7), 0.65, 1.8, 13, color, Enum.Material.Concrete)
			end
		end
		return folder
	end

	-- The arena is a raised city island. Streets form a cross plus a complete outer loop.
	box(terrain, "CityIsland", 0, -3, 0, 310, 6, 280, P.navy, Enum.Material.Concrete)
	box(terrain, "Asphalt", 0, -0.15, 0, 302, 0.3, 272, P.road, Enum.Material.Asphalt)
	box(terrain, "PlazaPaving", 0, 0.08, -1, 40, 0.16, 36, P.concrete, Enum.Material.Concrete)
	for _, x in ipairs({ -138, 138 }) do
		box(terrain, "OuterFootpath", x, 0.15, 0, 12, 0.3, 268, P.concrete, Enum.Material.Concrete)
	end
	for _, z in ipairs({ -126, 126 }) do
		box(terrain, "OuterFootpath", 0, 0.15, z, 288, 0.3, 12, P.concrete, Enum.Material.Concrete)
	end
	for i = -6, 6 do
		if math.abs(i) > 1 then
			box(terrain, "RoadDash", i * 20, 0.025, -7, 7, 0.05, 0.24, P.gold, nil, false)
			box(terrain, "RoadDash", 7, 0.025, i * 19, 0.24, 0.05, 6, P.gold, nil, false)
		end
	end
	for _, x in ipairs({ -27, 27 }) do
		for i = -3, 3 do box(terrain, "Crosswalk", x, 0.04, i * 2.3 - 1, 7, 0.07, 1.1, P.cream, nil, false) end
	end
	for _, x in ipairs({ -151, 151 }) do
		box(terrain, "IslandWall", x, 2.2, 0, 2, 4.4, 276, P.navy, Enum.Material.Concrete)
		box(terrain, "IslandLight", x, 4.45, 0, 0.22, 0.12, 276, P.cyan, Enum.Material.Neon, false)
	end
	for _, z in ipairs({ -137, 137 }) do
		box(terrain, "IslandWall", 0, 2.2, z, 302, 4.4, 2, P.navy, Enum.Material.Concrete)
		box(terrain, "IslandLight", 0, 4.45, z, 302, 0.12, 0.22, P.cyan, Enum.Material.Neon, false)
	end
	for _, edge in ipairs({ { -154, 0, 2, 280 }, { 154, 0, 2, 280 }, { 0, -139, 310, 2 }, { 0, 139, 310, 2 } }) do
		local wall = box(terrain, "ArenaBoundary", edge[1], 45, edge[2], edge[3], 100, edge[4], P.ink)
		wall.Transparency = 1
		wall.CastShadow = false
	end

	local arcade = building("01_CitrusArcade", -84, -79, 72, 58, 16, P.teal, P.cyan)
	local noodle = building("02_MoonNoodle", -85, 53, 70, 64, 20, P.coral, P.pink)
	local greenhouse = building("03_CloudGarden", 81, -78, 82, 60, 24, P.cream, P.cyan)
	local laundry = building("04_PolarLaundry", 86, 58, 72, 66, 14, P.purple, P.cyan)
	local market = building("05_EmberMarket", 0, 78, 50, 52, 14, P.cream, P.gold)
	-- Signs face both the chase streets and the outside loop for instant orientation.
	sign(arcade, "CITRUS / ARCADE", Vector3.new(-84, 11.3, -49.45), 35, 4.4, P.cyan, math.pi)
	sign(noodle, "MOON NOODLE", Vector3.new(-85, 13.3, 20.45), 35, 4.6, P.gold)
	sign(greenhouse, "CLOUD GARDEN", Vector3.new(81, 11.3, -47.4), 38, 4.8, P.cyan, math.pi)
	sign(laundry, "POLAR / LAUNDRY", Vector3.new(86, 9.9, 24.4), 40, 4.3, P.cyan)
	sign(market, "EMBER MARKET", Vector3.new(0, 10.2, 51.4), 36, 4.2, P.gold)
	canopy(noodle, -85, 8, 17.3, 47, 6, P.coral)
	canopy(arcade, -84, 7.5, -46.5, 44, 6, P.teal, math.pi)
	canopy(market, 0, 7.6, 48.5, 40, 6, P.coral)
	canopy(laundry, 86, 7.5, 21.8, 49, 5.5, P.purple)

	-- A sixth traversable roof is the station under the signature clock crown.
	local clock = building("06_MeridianStation", 0, -81, 38, 48, 24, P.navy, P.gold)
	sign(clock, "MERIDIAN", Vector3.new(0, 11.2, -56.5), 28, 4.4, P.gold, math.pi)
	box(clock, "ClockPillar", 0, 35, -91, 12, 22, 12, P.teal, Enum.Material.Concrete)
	box(clock, "ClockCollar", 0, 44.5, -91, 15, 2, 15, P.cream, Enum.Material.Concrete)
	box(clock, "ClockHousing", 0, 50, -91, 15, 9, 15, P.navy, Enum.Material.Metal)
	box(clock, "ClockCrown", 0, 55.2, -91, 19, 1.4, 19, P.gold, Enum.Material.Metal)
	box(clock, "CrownLight", 0, 56, -91, 17.5, 0.18, 17.5, P.gold, Enum.Material.Neon, false)
	box(clock, "Spire", 0, 60, -91, 1.3, 8, 1.3, P.gold, Enum.Material.Metal, false)
	sphere(clock, "SpireBeacon", Vector3.new(0, 64, -91), Vector3.new(2.8, 2.8, 2.8), P.gold)
	for _, turn in ipairs({ 0, math.pi / 2, math.pi, -math.pi / 2 }) do
		local cf = CFrame.new(0, 50, -91) * CFrame.Angles(0, turn, 0) * CFrame.new(0, 0, -7.6)
		local dial = part(clock, "ClockDial", Vector3.new(6.7, 6.7, 0.15), cf, P.cream, Enum.Material.Neon, false)
		for tick = 1, 12 do
			local angle = tick * math.pi / 6
			part(clock, "HourMark", Vector3.new(0.23, 0.6, 0.08), cf * CFrame.new(math.sin(angle) * 2.7, math.cos(angle) * 2.7, -0.13) * CFrame.Angles(0, 0, -angle), P.navy, nil, false)
		end
		part(clock, "MinuteHand", Vector3.new(0.2, 2.5, 0.1), dial.CFrame * CFrame.new(0, 1.1, -0.18), P.navy, nil, false)
		part(clock, "HourHand", Vector3.new(1.8, 0.28, 0.1), dial.CFrame * CFrame.new(0.75, 0, -0.2), P.navy, nil, false)
	end

	-- Complete elevated loop, with a north cross route and a southern interception route.
	route("CitrusToMoon", Vector3.new(-85, 16, -51), Vector3.new(-85, 20, 22), 12, P.pink, true)
	route("GardenToPolar", Vector3.new(86, 24, -49), Vector3.new(86, 14, 26), 12, P.cyan, true)
	route("MoonToEmber", Vector3.new(-51, 20, 67), Vector3.new(-24, 14, 67), 12, P.gold, true)
	route("EmberToPolar", Vector3.new(24, 14, 78), Vector3.new(51, 14, 78), 12, P.cyan, true)
	route("CitrusToMeridian", Vector3.new(-49, 16, -75), Vector3.new(-18, 24, -75), 12, P.gold, true)
	route("MeridianToGarden", Vector3.new(18, 24, -75), Vector3.new(41, 24, -75), 12, P.cyan, true)
	-- Ground-access ramps: around the west arcade, garden's north facade, and south market.
	route("WestStreetRamp", Vector3.new(-126, 0.4, -36), Vector3.new(-126, 16, -82), 11, P.cyan, true)
	route("WestRampLanding", Vector3.new(-126, 16, -82), Vector3.new(-115, 16, -82), 11, P.cyan, false)
	route("GardenStreetRamp", Vector3.new(43, 0.4, -116), Vector3.new(98, 24, -116), 11, P.cyan, true)
	route("GardenRampLanding", Vector3.new(98, 24, -116), Vector3.new(98, 24, -103), 11, P.cyan, false)
	route("MarketStreetRamp", Vector3.new(36, 0.4, 111), Vector3.new(0, 14, 111), 11, P.gold, true)
	route("MarketRampLanding", Vector3.new(0, 14, 111), Vector3.new(0, 14, 100), 11, P.gold, false)
	ladder(-51, 40, 20, math.pi / 2)
	ladder(123, 58, 14, math.pi / 2)
	ladder(48, -63, 24, math.pi / 2)
	ladder(-84, -109, 16)
	ladder(-20, -64, 24, math.pi / 2)
	ladder(-26, 89, 14, math.pi / 2)
	-- Visible footings carry the long bridges without obstructing the central streets.
	for _, x in ipairs({ -89.5, -80.5, 81.5, 90.5 }) do
		box(routes, "BridgePier", x, 8.5, -25, 1.1, 17, 1.1, P.steel, Enum.Material.Metal)
		box(routes, "BridgePier", x, 9.2, 7, 1.1, 18.4, 1.1, P.steel, Enum.Material.Metal)
	end
	-- Roof-level vent jumps are optional; broad routes stay clear through every roof.
	acUnit(-108, 16, -93)
	acUnit(-100, 16, -93)
	acUnit(-104, 20, 72)
	acUnit(111, 14, 42, math.pi / 2)
	acUnit(111, 14, 52, math.pi / 2)
	acUnit(13, 14, 94)
	pipe(Vector3.new(-111, 17, -91), Vector3.new(-111, 17, -61))
	pipe(Vector3.new(-111, 17, -61), Vector3.new(-111, 2, -48))
	pipe(Vector3.new(108, 15, 44), Vector3.new(108, 15, 77), P.cyan)
	pipe(Vector3.new(108, 15, 77), Vector3.new(124, 15, 77), P.cyan)

	-- Citrus roof: illuminated arcade marquee, tiered water tank, and generous chase lanes.
	box(arcade, "RoofMarqueeFrame", -101, 22, -104, 30, 8, 0.8, P.ink, Enum.Material.Metal, false)
	sign(arcade, "PLAY / RUN / REPEAT", Vector3.new(-101, 22, -103.4), 28, 6, P.cyan, math.pi)
	for _, x in ipairs({ -113, -89 }) do box(arcade, "MarqueeLeg", x, 19, -104, 0.6, 6, 0.6, P.steel, Enum.Material.Metal) end
	cylinder(arcade, "WaterTankBase", Vector3.new(-60, 17, -93), 11, 2, P.steel, Enum.Material.Metal)
	cylinder(arcade, "WaterTank", Vector3.new(-60, 21.5, -93), 9, 7, P.teal, Enum.Material.Metal)
	for _, h in ipairs({ 18.8, 23.8 }) do cylinder(arcade, "TankBand", Vector3.new(-60, h, -93), 9.3, 0.3, P.cream, Enum.Material.Metal) end
	cylinder(arcade, "TankLid", Vector3.new(-60, 25.2, -93), 10, 0.4, P.navy, Enum.Material.Metal)
	planter(arcade, -106, 16, -58, 14, 0, true)
	box(arcade, "VaultVent", -69, 17.35, -60, 9, 2.7, 3, P.steel, Enum.Material.Metal)

	-- Moon rooftop: a lantern restaurant terrace with a climbable central pergola deck.
	box(noodle, "TerraceDeck", -86, 20.15, 49, 27, 0.3, 20, P.soil, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -98, -74 }) do
		for _, z in ipairs({ 40, 58 }) do box(noodle, "PergolaPost", x, 24.5, z, 0.55, 9, 0.55, P.navy, Enum.Material.Wood) end
	end
	for i = 0, 6 do box(noodle, "PergolaLath", -99 + i * 4.3, 29, 49, 0.8, 0.6, 23, P.coral, Enum.Material.Wood, false) end
	for _, z in ipairs({ 39, 59 }) do box(noodle, "PergolaBeam", -86, 28.8, z, 30, 0.8, 0.7, P.cream, Enum.Material.Wood, false) end
	for _, x in ipairs({ -95, -86, -77 }) do
		cylinder(noodle, "PaperLantern", Vector3.new(x, 27.3, 41), 2.2, 2.4, P.gold, Enum.Material.Neon, false)
	end
	planter(noodle, -111, 20, 44, 14, math.pi / 2, true)
	planter(noodle, -60, 20, 44, 14, math.pi / 2, true)
	bench(noodle, -92, 20, 58)
	bench(noodle, -79, 20, 58)
	-- A large bowl silhouette makes Moon readable from the skyline, without asset meshes.
	cylinder(noodle, "BowlFoot", Vector3.new(-105, 22, 27), 3.7, 3, P.cream, Enum.Material.SmoothPlastic)
	cylinder(noodle, "NoodleBowl", Vector3.new(-105, 25, 27), 9, 3.5, P.coral, Enum.Material.SmoothPlastic)
	cylinder(noodle, "BowlRim", Vector3.new(-105, 27, 27), 10, 0.5, P.cream, Enum.Material.SmoothPlastic)
	beam(noodle, "Chopstick", Vector3.new(-108, 27.4, 27), Vector3.new(-102, 33, 27), 0.3, P.gold, Enum.Material.Wood, false)
	beam(noodle, "Chopstick", Vector3.new(-106, 27.4, 27.8), Vector3.new(-100, 33, 27.8), 0.3, P.gold, Enum.Material.Wood, false)

	-- Cloud Garden: transparent pitched greenhouse plus an open, planted running circuit.
	box(greenhouse, "GardenPaving", 81, 24.13, -78, 76, 0.26, 54, P.concrete, Enum.Material.Concrete)
	local gx, gz = 80, -85
	for _, x in ipairs({ gx - 13, gx + 13 }) do
		for _, z in ipairs({ gz - 12, gz, gz + 12 }) do box(greenhouse, "GreenhousePost", x, 28, z, 0.4, 8, 0.4, P.cream, Enum.Material.Metal, false) end
		local glass = box(greenhouse, "GreenhouseGlass", x, 28, gz, 0.15, 7.6, 24, P.cyan, Enum.Material.Glass, false)
		glass.Transparency = 0.76
		beam(greenhouse, "GreenhouseEave", Vector3.new(x, 32, gz - 12), Vector3.new(x, 32, gz + 12), 0.45, P.cream, Enum.Material.Metal, false)
	end
	beam(greenhouse, "GreenhouseRidge", Vector3.new(gx, 37, gz - 12), Vector3.new(gx, 37, gz + 12), 0.5, P.cream, Enum.Material.Metal, false)
	for _, z in ipairs({ gz - 12, gz, gz + 12 }) do
		for _, x in ipairs({ gx - 13, gx + 13 }) do beam(greenhouse, "GreenhouseRafter", Vector3.new(x, 32, z), Vector3.new(gx, 37, z), 0.4, P.cream, Enum.Material.Metal, false) end
	end
	for _, side in ipairs({ -1, 1 }) do
		local roof = part(greenhouse, "GreenhouseRoof", Vector3.new(13.9, 0.14, 24), CFrame.new(gx + side * 6.5, 34.5, gz) * CFrame.Angles(0, 0, -side * math.atan(5 / 13)), P.cyan, Enum.Material.Glass, false)
		roof.Transparency = 0.82
	end
	planter(greenhouse, 71, 24, -85, 16, math.pi / 2, true)
	planter(greenhouse, 89, 24, -85, 16, math.pi / 2, true)
	planter(greenhouse, 53, 24, -96, 14, 0, true)
	planter(greenhouse, 109, 24, -96, 12, 0, true)
	planter(greenhouse, 108, 24, -59, 15, 0, true)
	bench(greenhouse, 56, 24, -58)
	tree(greenhouse, 109, 24, -79, 0.75)
	box(greenhouse, "GardenVault", 64, 25.3, -61, 8, 2.6, 2.2, P.green, Enum.Material.Concrete)
	sign(greenhouse, "BREATHE / THEN RUN", Vector3.new(80, 34, -72.5), 20, 2.7, P.cyan, math.pi)

	-- Polar roof: blue water reservoir and laundry lines, all cloth above head height.
	box(laundry, "ReservoirFoot", 69, 14.3, 46, 18, 0.6, 14, P.concrete, Enum.Material.Concrete)
	box(laundry, "Reservoir", 69, 16, 46, 16, 3.2, 12, P.teal, Enum.Material.Metal)
	box(laundry, "ReservoirInset", 69, 17.65, 46, 14.8, 0.08, 10.8, P.cyan, Enum.Material.Glass, false)
	for _, x in ipairs({ 64, 101 }) do box(laundry, "LaundryMast", x, 18.5, 83, 0.3, 9, 0.3, P.cream, Enum.Material.Metal, false) end
	beam(laundry, "LaundryLine", Vector3.new(64, 22.6, 83), Vector3.new(101, 22.6, 83), 0.08, P.ink, nil, false)
	for i = 1, 6 do box(laundry, "HangingBanner", 65 + i * 5.1, 20.9, 83, 3.1, 3.2, 0.08, i % 2 == 0 and P.cream or P.coral, Enum.Material.Fabric, false) end
	planter(laundry, 102, 14, 70, 11, math.pi / 2, false)
	box(laundry, "VaultDuct", 89, 15.35, 53, 3, 2.7, 11, P.steel, Enum.Material.Metal)
	sign(laundry, "SPIN / CITY", Vector3.new(116, 21, 87), 19, 4, P.pink, math.pi)

	-- Ember roof: miniature food garden and solar pergola leave a broad east-west shortcut.
	planter(market, -15, 14, 93, 12, 0, true)
	planter(market, 15, 14, 59, 10, 0, true)
	for _, x in ipairs({ -17, 17 }) do box(market, "SolarPost", x, 18.5, 86, 0.5, 9, 0.5, P.steel, Enum.Material.Metal, false) end
	part(market, "SolarCanopy", Vector3.new(37, 0.4, 7), CFrame.new(0, 23, 86) * CFrame.Angles(math.rad(-10), 0, 0), P.navy, Enum.Material.Metal, false)
	for i = -3, 3 do part(market, "SolarCell", Vector3.new(4.4, 0.05, 6), CFrame.new(i * 5, 23.3, 86) * CFrame.Angles(math.rad(-10), 0, 0), P.glass, Enum.Material.Glass, false) end

	-- Central landmark: a dry fountain ring with a clear crossing, four district wayfinders.
	cylinder(terrain, "CompassInset", Vector3.new(0, 0.2, 0), 22, 0.3, P.navy, Enum.Material.Concrete)
	cylinder(terrain, "CompassCenter", Vector3.new(0, 0.4, 0), 13, 0.3, P.teal, Enum.Material.Concrete)
	for _, angle in ipairs({ 0, math.pi / 2, math.pi, -math.pi / 2 }) do
		part(terrain, "CompassSpoke", Vector3.new(0.25, 0.06, 18), CFrame.new(0, 0.59, 0) * CFrame.Angles(0, angle + math.pi / 4, 0), P.gold, Enum.Material.Neon, false)
	end
	for _, item in ipairs({ { -22, -23, "CITRUS", P.cyan }, { 24, -23, "GARDEN", P.cyan }, { -22, 25, "MOON", P.pink }, { 24, 25, "POLAR", P.cyan } }) do
		box(props, "WayfindingPost", item[1], 5, item[2], 0.4, 10, 0.4, P.navy, Enum.Material.Metal)
		sign(props, item[3], Vector3.new(item[1], 9, item[2]), 9, 2.7, item[4])
	end
	-- A little street life anchors scale without obstructing the primary routes.
	for _, point in ipairs({ { -139, -99 }, { -139, 42 }, { 138, -24 }, { 138, 98 }, { -46, 125 }, { 70, 125 }, { -29, -119 } }) do
		tree(props, point[1], 0.3, point[2], 0.85)
	end
	for _, point in ipairs({ { -36, -15 }, { 37, 12 }, { -131, 8 }, { 131, -87 }, { -12, 120 }, { 123, 115 }, { -121, -119 }, { 119, -119 } }) do
		box(props, "StreetLampPole", point[1], 7, point[2], 0.35, 14, 0.35, P.navy, Enum.Material.Metal, false)
		box(props, "StreetLampHead", point[1], 14, point[2], 3.2, 0.35, 1.8, P.navy, Enum.Material.Metal, false)
		light(props, Vector3.new(point[1], 13.7, point[2]), P.gold, 0.75, 19)
	end
	bench(props, -139, 0.3, 68, math.pi / 2)
	bench(props, 139, 0.3, 4, -math.pi / 2)
	bench(props, -64, 0.3, 126)
	-- Low service obstacles teach vaulting; each has more than ten studs of side clearance.
	for _, position in ipairs({ Vector3.new(-43, 1.35, 2), Vector3.new(41, 1.35, -4), Vector3.new(-31, 1.35, 107), Vector3.new(130, 1.35, 31) }) do
		local obstacle = part(props, "VaultBarrier", Vector3.new(9, 2.7, 2.2), position, P.teal, Enum.Material.Concrete)
		obstacle:SetAttribute("Vaultable", true)
		part(props, "VaultHighlight", Vector3.new(8.7, 0.1, 2.1), position + Vector3.new(0, 1.4, 0), P.cyan, Enum.Material.Neon, false)
	end
	-- Optional timing shortcuts: shutters lift; the open street around them always remains.
	for index, gateInfo in ipairs({ { -34, 39, P.pink }, { 34, -37, P.cyan } }) do
		local x, z, accent = gateInfo[1], gateInfo[2], gateInfo[3]
		for _, dx in ipairs({ -6.2, 6.2 }) do box(routes, "TimingGatePost", x + dx, 5, z, 0.65, 10, 0.65, P.navy, Enum.Material.Metal) end
		box(routes, "TimingGateHeader", x, 10, z, 13, 0.6, 0.9, P.navy, Enum.Material.Metal)
		local gate = box(routes, "MovingShortcutGate", x, 2.5, z, 11.8, 4.5, 0.7, accent, Enum.Material.Metal)
		gate:SetAttribute("DynamicObstacle", true)
		gate:SetAttribute("MovementTolerance", 8)
		sign(routes, "TIMING / BYPASS", Vector3.new(x, 11.5, z - 0.1), 12.5, 2, accent)
		local tween = TweenService:Create(gate, TweenInfo.new(2.4 + index * 0.3, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 1.5), { CFrame = gate.CFrame + Vector3.new(0, 5, 0) })
		table.insert(tweens, tween)
	end

	-- Carefully placed silhouettes frame the arena, with restrained lit-window bands.
	box(skyline, "CityBelow", 0, -18, -25, 950, 8, 950, P.ink, Enum.Material.Concrete)
	local towers = {
		{ -218, -163, 40, 44, 90, P.navy }, { -165, -187, 37, 46, 120, P.purple },
		{ -103, -191, 38, 42, 73, P.teal }, { -48, -206, 35, 45, 105, P.steel },
		{ 14, -209, 48, 47, 82, P.navy }, { 77, -190, 36, 40, 118, P.purple },
		{ 136, -191, 40, 43, 79, P.teal }, { 206, -158, 43, 45, 102, P.navy },
		{ -205, -63, 38, 46, 65, P.steel }, { -215, 24, 42, 48, 88, P.navy },
		{ -204, 109, 42, 39, 54, P.purple }, { 206, -64, 42, 38, 79, P.navy },
		{ 211, 21, 39, 45, 104, P.teal }, { 207, 112, 45, 44, 61, P.navy },
	}
	for i, t in ipairs(towers) do
		local x, z, w, d, h, c = table.unpack(t)
		box(skyline, "Tower", x, h / 2 - 14, z, w, h, d, c, Enum.Material.Concrete, false)
		box(skyline, "TowerCrown", x, h - 13, z, w + 2, 2, d + 2, P.steel, Enum.Material.Metal, false)
		box(skyline, "TowerSetback", x, h - 8, z, w * 0.65, 10, d * 0.65, c, Enum.Material.Concrete, false)
		for row = 1, math.floor(h / 13) do
			local y = row * 11 - 7
			local glow = (row + i) % 3 == 0 and P.gold or P.cyan
			box(skyline, "SkylineWindowBand", x, y, z + d / 2 + 0.1, w - 8, 0.55, 0.12, glow, Enum.Material.Neon, false)
			box(skyline, "SkylineWindowBand", x - w / 2 - 0.1, y, z, 0.12, 0.55, d - 8, glow, Enum.Material.Neon, false)
		end
	end

	-- Social deck: a separate, safe viewing terrace with a stage and welcoming little rooms.
	box(lobby, "SocialIsland", 0, 1.5, 245, 114, 9, 88, P.navy, Enum.Material.Concrete)
	box(lobby, "SocialDeck", 0, 6.15, 245, 108, 0.3, 82, P.concrete, Enum.Material.Concrete)
	box(lobby, "DeckInlay", 0, 6.33, 251, 58, 0.06, 43, P.ink, Enum.Material.Concrete, false)
	for _, x in ipairs({ -53, 53 }) do
		box(lobby, "SocialRail", x, 8, 245, 0.8, 3.7, 80, P.navy, Enum.Material.Metal)
		box(lobby, "SocialRailLight", x, 10, 245, 0.2, 0.12, 80, P.cyan, Enum.Material.Neon, false)
	end
	for _, z in ipairs({ 205, 285 }) do
		box(lobby, "SocialRail", 0, 8, z, 106, 3.7, 0.8, P.navy, Enum.Material.Metal)
		box(lobby, "SocialRailLight", 0, 10, z, 106, 0.12, 0.2, P.cyan, Enum.Material.Neon, false)
	end
	box(lobby, "PodiumStage", 0, 6.7, 224, 47, 1.1, 19, P.navy, Enum.Material.Concrete)
	stair("StageStair", Vector3.new(0, 6.3, 237), 38, 1, 4, 0)
	local podiums = {}
	for i, item in ipairs({ { 0, 2.3, "01", P.gold }, { -14, 1.3, "02", P.cyan }, { 14, 0.8, "03", P.pink } }) do
		local x, height, numeral, accent = table.unpack(item)
		cylinder(lobby, "WinnerPodium_" .. numeral, Vector3.new(x, 7.25 + height / 2, 224), 10.5, height, P.steel, Enum.Material.Metal)
		cylinder(lobby, "PodiumLight", Vector3.new(x, 7.3 + height, 224), 10.6, 0.12, accent, Enum.Material.Neon, false)
		sign(lobby, numeral, Vector3.new(x, 8.1, 229.4), 4, 1.7, accent, math.pi)
		podiums[i] = CFrame.lookAt(Vector3.new(x, 10.4 + height, 224), Vector3.new(x, 10.4 + height, 260))
	end
	sign(lobby, "THE ROOFTOPS ARE YOURS", Vector3.new(0, 16.5, 213), 47, 4.4, P.cream, math.pi)
	for _, x in ipairs({ -25, 25 }) do box(lobby, "StageBannerPole", x, 12, 213, 0.5, 11.5, 0.5, P.steel, Enum.Material.Metal, false) end
	-- Rear entry arch and typography compose the first spawn camera's backdrop.
	for _, x in ipairs({ -29, 29 }) do box(lobby, "EntryPylon", x, 13.5, 280, 1.6, 15, 1.6, P.teal, Enum.Material.Metal) end
	box(lobby, "EntryHeader", 0, 21, 280, 60, 1.1, 2.5, P.teal, Enum.Material.Metal)
	sign(lobby, "CATCH ME IF YOU CAN", Vector3.new(0, 17.7, 279), 55, 5, P.cyan)
	sign(lobby, "NEON HEIGHTS / SOCIAL DECK", Vector3.new(0, 13.4, 279), 36, 2, P.cream)
	for _, x in ipairs({ -40, 40 }) do
		planter(lobby, x, 6.3, 277, 18, 0, true)
		tree(lobby, x, 6.3, 213, 0.85)
		bench(lobby, x, 6.3, 246, x < 0 and math.pi / 2 or -math.pi / 2)
		bench(lobby, x, 6.3, 259, x < 0 and math.pi / 2 or -math.pi / 2)
		light(lobby, Vector3.new(x, 15, 248), P.cyan, 0.65, 22)
	end
	cylinder(lobby, "EmoteCircle", Vector3.new(0, 6.4, 252), 18, 0.12, P.teal, Enum.Material.SmoothPlastic, false)
	cylinder(lobby, "EmoteCircleInset", Vector3.new(0, 6.5, 252), 16.5, 0.08, P.navy, Enum.Material.SmoothPlastic, false)
	sign(lobby, "YOUR NEXT GREAT ESCAPE", Vector3.new(0, 7.2, 265), 27, 1.7, P.cream)
	local lobbySpawn = CFrame.lookAt(Vector3.new(0, 10, 264), Vector3.new(0, 10, 223))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SocialSpawn"
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(0, 6.5, 264)
	spawn.Transparency = 1
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = lobby
	partCount += 1
	-- Lobby containment is transparent above the visible rail; reset remains a safe escape.
	for _, edge in ipairs({ { -55, 245, 2, 84 }, { 55, 245, 2, 84 }, { 0, 203, 112, 2 }, { 0, 287, 112, 2 } }) do
		local wall = box(lobby, "SocialBoundary", edge[1], 28, edge[2], edge[3], 50, edge[4], P.ink)
		wall.Transparency = 1
		wall.CastShadow = false
	end

	applyLighting()
	model:SetAttribute("StaticPartCount", partCount)
	model:SetAttribute("ElevatedRouteCount", 12)
	model:SetAttribute("DynamicObstacleCount", #tweens)
	model.Parent = workspace
	for _, tween in ipairs(tweens) do tween:Play() end
	model.Destroying:Connect(function()
		for _, tween in ipairs(tweens) do tween:Cancel() end
	end)
	local function spawnFacing(x, y, z)
		return CFrame.lookAt(Vector3.new(x, y + 3.3, z), Vector3.new(0, y + 3.3, 0))
	end
	built = {
		Model = model,
		LobbySpawn = lobbySpawn,
		RunnerSpawns = {
			spawnFacing(-84, 16, -80), spawnFacing(-103, 16, -72),
			spawnFacing(-84, 20, 32), spawnFacing(-68, 20, 72),
			spawnFacing(51, 24, -77), spawnFacing(100, 24, -65),
			spawnFacing(97, 14, 38), spawnFacing(68, 14, 69),
			spawnFacing(-12, 14, 78), spawnFacing(12, 14, 70),
			spawnFacing(-9, 24, -65), spawnFacing(9, 24, -76),
		},
		HunterSpawns = { spawnFacing(-6, 0.6, 0), spawnFacing(6, 0.6, 0) },
		Podiums = podiums,
		Bounds = { min = Vector3.new(-155, -25, -140), max = Vector3.new(155, 100, 145) },
	}
	return built
end

return MapBuilder
