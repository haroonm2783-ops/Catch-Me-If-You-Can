--!nonstrict
-- CATCH MALL: a two-floor mall around a huge open atrium. Modules live in World/Mall and are
-- built in a fixed order so every floor, wall and prop agrees on the same layout numbers.
local Lighting = game:GetService("Lighting")

local MallBuilder = {}
local built
local MAP_VERSION = 2

local function load(name)
	if script then return require(script.Parent.Mall[name]) end
	return require("./Mall/" .. name)
end

-- Lighting: a warm, sunny afternoon that stays mid-tone. The previous preset stacked bright ambient, positive
-- exposure and a long haze over hundreds of studs of near-white floor, which washed everything out. Here ambient
-- is moderate so colors keep their saturation, the sun gives readable shadows, and bloom only catches real glow.
-- Lighting.Technology is not scriptable; tools/bake-place.luau sets it (ShadowMap) in the saved place.
local function applyLighting()
	Lighting.ClockTime = 15.4
	Lighting.GeographicLatitude = 28
	Lighting.Brightness = 2.1
	Lighting.Ambient = Color3.fromRGB(118, 116, 134)
	Lighting.OutdoorAmbient = Color3.fromRGB(132, 138, 160)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 236, 205)
	Lighting.ColorShift_Bottom = Color3.fromRGB(0, 0, 0)
	Lighting.ExposureCompensation = -0.05
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.25
	for _, name in ipairs({"CatchAtmosphere", "CatchBloom", "CatchColor", "CatchSunRays", "CatchSky"}) do
		local old = Lighting:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local sky = Instance.new("Sky")
	sky.Name = "CatchSky"
	sky.StarCount = 0
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 14
	sky.Parent = Lighting
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "CatchAtmosphere"
	atmosphere.Density = 0.1
	atmosphere.Offset = 0.05
	atmosphere.Color = Color3.fromRGB(190, 215, 250)
	atmosphere.Decay = Color3.fromRGB(255, 200, 150)
	atmosphere.Glare = 0
	atmosphere.Haze = 0.1
	atmosphere.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "CatchBloom"
	bloom.Intensity = 0.12
	bloom.Size = 18
	bloom.Threshold = 1.9
	bloom.Parent = Lighting
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "CatchColor"
	color.Contrast = 0.06
	color.Saturation = 0.14
	color.TintColor = Color3.fromRGB(255, 250, 244)
	color.Parent = Lighting
end

local function readBaked(model)
	local world = {Model = model, LobbySpawn = model:GetAttribute("LobbySpawn"), RunnerSpawns = {}, HunterSpawns = {}, Podiums = {},
		Bounds = {min = model:GetAttribute("BoundsMin"), max = model:GetAttribute("BoundsMax")}}
	for _, kind in ipairs({"Runner", "Hunter", "Podium"}) do
		local target = kind == "Podium" and world.Podiums or world[kind .. "Spawns"]
		for i = 1, model:GetAttribute(kind .. "Count") or 0 do
			table.insert(target, model:GetAttribute(kind .. "Spawn" .. i))
		end
	end
	return world
end

function MallBuilder.Build(options)
	if built and built.Model.Parent then return built end
	local existing = workspace:FindFirstChild("CatchMall")
	if existing and existing:GetAttribute("CatchMapVersion") == MAP_VERSION then
		built = readBaked(existing)
		applyLighting()
		return built
	elseif existing then existing:Destroy() end

	local Layout, Kit = load("Layout"), load("Kit")
	local model = Instance.new("Model")
	model.Name = "CatchMall"
	model:SetAttribute("MapName", "CATCH MALL")
	local kit = Kit.new(model)
	kit.style = load("Style").new(kit.P)
	local Fixtures, StoreShell = load("Fixtures"), load("StoreShell")
	local shell = load("Shell").build(kit, Layout)
	load("Atrium").build(kit, Layout)
	load("Service").build(kit, Layout, Fixtures)
	local storesFolder = kit.group("Stores")
	local defs = {}
	for _, moduleName in ipairs({"StoresA", "StoresB", "Zones"}) do
		for _, def in ipairs(load(moduleName).defs(kit.P, Fixtures)) do table.insert(defs, def) end
	end
	-- Local (x, z) positions inside each store for a coin and a runner spawn. Tests verify both are clear.
	local storeCoin = {
		N1_1 = {34, 38}, N2_1 = {0, 40}, N3_1 = {-8, 38}, S1_1 = {30, 38}, S2_1 = {0, 30}, S3_1 = {-20, 12},
		E1_1 = {0, 40}, E2_1 = {-10, 46}, E3_1 = {10, 42}, W1_1 = {0, 40}, W2_1 = {0, 34}, W3_1 = {0, 22},
		N1_2 = {0, 38}, N2_2 = {0, 32}, N3_2 = {-20, 42}, S1_2 = {0, 36}, S2_2 = {0, 36}, S3_2 = {0, 36},
		E2_2 = {0, 12}, E3_2 = {0, 40}, W1_2 = {0, 36}, W2_2 = {12, 40},
	}
	local storeSpawn = {
		N1_1 = {24, 34}, N3_1 = {-8, 44}, S1_1 = {30, 34}, S3_1 = {-20, 18}, W2_1 = {0, 40}, E2_1 = {10, 50},
		S2_2 = {0, 30}, N1_2 = {10, 38}, N3_2 = {-20, 46}, W2_2 = {16, 50}, E2_2 = {10, 46},
	}
	local spawnOrder = {"N1_1", "N3_1", "S1_1", "S3_1", "W2_1", "E2_1", "S2_2", "N1_2", "N3_2", "W2_2", "E2_2"}
	local spawnPoints = {}
	local function facing(position)
		return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
	end
	local peersByFloor = {{}, {}}
	for _, def in ipairs(defs) do peersByFloor[def.floor][def.slot] = def end
	for _, def in ipairs(defs) do
		local slot = Layout.SlotById[def.slot]
		local ctx = StoreShell.build(kit, Layout, slot, def.floor, def, storesFolder, peersByFloor[def.floor])
		local key = def.slot .. "_" .. def.floor
		local y = Layout.FloorY[def.floor]
		if storeCoin[key] then table.insert(kit.coins, ctx.f.pos(storeCoin[key][1], 3.2, storeCoin[key][2])) end
		if storeSpawn[key] then spawnPoints[key] = facing(ctx.f.pos(storeSpawn[key][1], 3.4, storeSpawn[key][2])) end
	end
	-- Public-space coins: risky open ground and elevated routes.
	for _, p in ipairs({{22, 0}, {-22, 0}, {0, 22}, {0, -22}, {16, 16}, {-16, -16}, {40, 52}, {-40, 52}, {40, -52}, {-40, -52},
		{70, 0}, {-70, 0}, {0, 76}, {0, -76}}) do
		table.insert(kit.coins, Vector3.new(p[1], 3.2, p[2]))
	end
	for _, p in ipairs({{0, 0}, {30, 0}, {-30, 0}, {0, 30}, {0, -30}, {78, 82}, {-78, 82}, {78, -82}, {-78, -82}, {0, 76}, {0, -76}}) do
		table.insert(kit.coins, Vector3.new(p[1], Layout.FloorY[2] + 3.2, p[2]))
	end
	for _, p in ipairs({{156, 146}, {-156, 146}, {156, -146}, {-156, -146}}) do
		table.insert(kit.coins, Vector3.new(p[1], 3.2, p[2]))
		table.insert(kit.coins, Vector3.new(p[1], Layout.FloorY[2] + 3.2, p[2]))
	end
	local coinFolder = kit.group("MallCoins")
	for i, position in ipairs(kit.coins) do
		local coin = kit.part(coinFolder, "MallCoin", Vector3.new(0.5, 2.8, 2.8), position, kit.P.gold, Enum.Material.Neon, false, {shape = "Cylinder", shadow = false})
		coin:SetAttribute("CoinId", i)
		local rim = kit.part(coin, "CoinInner", Vector3.new(0.6, 1.8, 1.8), position, Color3.fromRGB(255, 244, 170), Enum.Material.Neon, false, {shape = "Cylinder", shadow = false})
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = coin, rim
		weld.Parent = rim
	end
	model:SetAttribute("CoinCount", #kit.coins)

	local exterior = load("Exterior").build(kit, Layout, load("Decor"))
	local runnerSpawns = {}
	for _, key in ipairs(spawnOrder) do table.insert(runnerSpawns, spawnPoints[key]) end
	table.insert(runnerSpawns, facing(Vector3.new(0, Layout.FloorY[2] + 3.4, 76)))
	local hunterSpawns = {facing(Vector3.new(-24, 3.4, 0)), facing(Vector3.new(24, 3.4, 0))}
	local result = {kit = kit, shell = shell, defs = defs}

	applyLighting()
	model:SetAttribute("StaticPartCount", kit.count)
	model.Parent = workspace
	built = {Model = model, LobbySpawn = exterior.LobbySpawn, RunnerSpawns = runnerSpawns, HunterSpawns = hunterSpawns,
		Podiums = exterior.Podiums, Bounds = Layout.Bounds, Build = result}
	model:SetAttribute("CatchMapVersion", MAP_VERSION)
	model:SetAttribute("LobbySpawn", built.LobbySpawn)
	model:SetAttribute("BoundsMin", built.Bounds.min)
	model:SetAttribute("BoundsMax", built.Bounds.max)
	model:SetAttribute("HideSpotCount", #kit.hideSpots)
	model:SetAttribute("StoreCount", #defs)
	model:SetAttribute("LightCount", kit.lights)
	model:SetAttribute("DetailCount", kit.detail)
	model:SetAttribute("EmitterCount", kit.emitters)
	for _, kind in ipairs({"Runner", "Hunter", "Podium"}) do
		local values = kind == "Podium" and built.Podiums or built[kind .. "Spawns"]
		model:SetAttribute(kind .. "Count", #values)
		for i, transform in ipairs(values) do model:SetAttribute(kind .. "Spawn" .. i, transform) end
	end
	return built
end

return MallBuilder
