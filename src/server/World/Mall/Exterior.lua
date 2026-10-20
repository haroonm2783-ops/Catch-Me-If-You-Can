-- Outside the arena: the parking lot, mall facade sign, skyline, and the separate lobby plaza
-- where players wait and winners take the podium. The lobby is outside the arena so spectators
-- can never body-block a chase.
local Exterior = {}

function Exterior.build(kit, Layout)
	local P = kit.P
	local lot = kit.group("ParkingLot")
	local lobby = kit.group("Lobby")
	local sky = kit.group("Skyline")
	local SZ = Layout.Service.z

	-- Facade: huge sign and colour bands on the south wall that the lobby looks at.
	local zFace = -SZ - 1.6
	kit.box(lot, "FacadeBand", 0, 30, zFace, 324, 5, 0.6, P.coral, Enum.Material.SmoothPlastic, false)
	kit.box(lot, "FacadeBandTeal", 0, 24, zFace, 324, 2.5, 0.6, P.teal, Enum.Material.SmoothPlastic, false)
	kit.sign(lot, "CATCH MALL", CFrame.new(0, 40, zFace - 0.5) , 150, 16, P.white, P.ink, {material = Enum.Material.SmoothPlastic, pixels = 24, distance = 600})
	kit.box(lot, "SignGlowTop", 0, 48.3, zFace - 0.4, 150, 0.6, 0.6, P.sun, Enum.Material.Neon, false)
	kit.box(lot, "SignGlowBottom", 0, 31.7, zFace - 0.4, 150, 0.6, 0.6, P.sun, Enum.Material.Neon, false)
	kit.sign(lot, "ENTER THE CHASE", CFrame.new(0, 17, zFace - 0.5), 70, 6, P.sun, P.ink, {pixels = 24, distance = 400})
	for _, x in ipairs({-110, -70, 70, 110}) do
		kit.box(lot, "BannerPole", x, 20, zFace - 1, 0.6, 40, 0.6, P.steel, Enum.Material.Metal, false)
		kit.box(lot, "FacadeBanner", x, 22, zFace - 2, 8, 24, 0.3, ({P.pink, P.sky, P.sun, P.mint})[(x // 40 % 4) + 1], Enum.Material.Fabric, false)
	end
	for x = -150, 150, 30 do kit.box(lot, "FacadeWindow", x, 12, zFace - 0.2, 20, 8, 0.2, P.sky, Enum.Material.Glass, false, {transparency = 0.3}) end

	-- Parking lot: painted bays, a few cars, lamp posts and trees. Decoration only (no collision).
	for i = -10, 10 do kit.box(lot, "BayLine", i * 12, 0.02 - 1.2, -190, 0.5, 0.05, 26, P.white, Enum.Material.SmoothPlastic, false) end
	local carColors = {P.red, P.sky, P.sun, P.mint, P.violet, P.orange, P.white, P.coral}
	for i = -9, 9, 3 do
		kit.box(lot, "CarBody", i * 12 + 6, 1.2, -190, 5, 2, 12, carColors[(i % #carColors) + 1], Enum.Material.SmoothPlastic, false)
		kit.box(lot, "CarCabin", i * 12 + 6, 2.9, -190.5, 4.2, 1.6, 6, P.glass, Enum.Material.Glass, false, {transparency = 0.2})
		for _, w in ipairs({{-2.4, -4}, {2.4, -4}, {-2.4, 4}, {2.4, 4}}) do kit.can(lot, "Wheel", i * 12 + 6 + w[1], 0.5, -190 + w[2], 1.6, 1.0, P.black, Enum.Material.SmoothPlastic, false, {shape = nil}) end
	end
	for i = -6, 6 do
		kit.box(lot, "LampPole", i * 24, 7, -172, 0.5, 14, 0.5, P.dark, Enum.Material.Metal, false)
		kit.box(lot, "LampHead", i * 24, 14.2, -172, 2.4, 0.4, 1.4, P.sun, Enum.Material.Neon, false)
	end
	for i = -8, 8 do
		local x = i * 26
		kit.can(lot, "TreeTrunk", x, 3, -178 - (i % 2) * 6, 1.2, 6, P.darkwood, Enum.Material.Wood, false)
		kit.ball(lot, "TreeCrown", x, 8.5, -178 - (i % 2) * 6, 7, 6, 7, P.leaf, Enum.Material.SmoothPlastic, false)
	end

	-- Skyline: simple tinted towers and hills far beyond the lot.
	for i = 1, 26 do
		local a = i / 26 * math.pi * 2
		local r = 520 + (i % 3) * 60
		local h = 70 + (i * 37) % 140
		local w = 40 + (i * 13) % 40
		local x, z = math.cos(a) * r, math.sin(a) * r
		kit.box(sky, "Tower", x, h / 2 - 4, z, w, h, w, ({P.sky, P.lilac, P.mint, P.peach, P.steel})[(i % 5) + 1], Enum.Material.SmoothPlastic, false, {shadow = false})
		for k = 1, 4 do kit.box(sky, "TowerWindows", x, 10 + k * (h / 5), z - w / 2 - 0.1, w * 0.8, 3, 0.2, P.white, Enum.Material.Neon, false, {shadow = false}) end
	end

	-- Lobby plaza (outside the arena): stage and podiums face the spawn; the mall sign backs the stage.
	local ly = 0
	kit.box(lobby, "LobbyDeck", 0, ly - 1, -245, 130, 2, 90, P.stone, Enum.Material.Marble, true)
	kit.box(lobby, "LobbyInlay", 0, ly + 0.03, -262, 70, 0.05, 40, P.sky, Enum.Material.SmoothPlastic, false)
	kit.can(lobby, "LobbyMedallion", 0, ly + 0.05, -262, 30, 0.05, P.sun, Enum.Material.SmoothPlastic, false)
	kit.can(lobby, "LobbyMedallionInner", 0, ly + 0.07, -262, 24, 0.05, P.white, Enum.Material.SmoothPlastic, false)
	-- Stage with three podium steps.
	kit.box(lobby, "PodiumStage", 0, ly + 0.6, -214, 56, 1.2, 14, P.navy or P.dark, Enum.Material.Marble, true)
	local podiums = {}
	for i, spec in ipairs({{0, 2.6, "1", P.gold}, {-14, 1.6, "2", P.sky}, {14, 1.0, "3", P.coral}}) do
		local x, h, numeral, accent = spec[1], spec[2], spec[3], spec[4]
		kit.can(lobby, "WinnerPodium_" .. numeral, x, ly + 1.2 + h / 2, -214, 10, h, P.white, Enum.Material.Marble, true)
		kit.can(lobby, "PodiumGlow", x, ly + 1.25 + h, -214, 10.2, 0.2, accent, Enum.Material.Neon, false)
		kit.sign(lobby, numeral, CFrame.new(x, ly + 2.2, -220.6), 3, 2.4, P.white, accent)
		podiums[i] = CFrame.lookAt(Vector3.new(x, ly + 1.2 + h + 3.1, -214), Vector3.new(x, ly + 1.2 + h + 3.1, -250))
	end
	kit.sign(lobby, "WINNERS", CFrame.new(0, 14, -206), 36, 5, P.sun, P.ink)
	for _, x in ipairs({-24, 24}) do
		kit.box(lobby, "StagePylon", x, 8, -206, 1.2, 16, 1.2, P.teal, Enum.Material.Metal, false)
		kit.box(lobby, "StageBanner", x, 9, -206.8, 5, 12, 0.3, x < 0 and P.pink or P.sky, Enum.Material.Fabric, false)
	end
	-- Entry arch and fountains.
	for _, x in ipairs({-30, 30}) do kit.box(lobby, "EntryPylon", x, 11, -285, 1.8, 22, 1.8, P.coral, Enum.Material.Metal, false) end
	kit.box(lobby, "EntryHeader", 0, 22, -285, 62, 2.4, 2.4, P.coral, Enum.Material.Metal, false)
	kit.sign(lobby, "WELCOME TO CATCH MALL", CFrame.new(0, 18, -286.4), 52, 5, P.white, P.ink)
	kit.sign(lobby, "CATCH ME IF YOU CAN", CFrame.new(0, 13.4, -286.4), 40, 3.4, P.sun, P.ink)
	for _, x in ipairs({-46, 46}) do
		kit.can(lobby, "LobbyPlanter", x, ly + 1.2, -250, 10, 2.4, P.white, Enum.Material.Marble, true)
		kit.can(lobby, "LobbyTrunk", x, ly + 5, -250, 1.2, 6, P.darkwood, Enum.Material.Wood, false)
		kit.ball(lobby, "LobbyCrown", x, ly + 9, -250, 9, 6, 9, P.leaf, Enum.Material.SmoothPlastic, false)
		kit.can(lobby, "LobbyBench", x, ly + 0.8, -272, 3, 1.6, P.wood, Enum.Material.Wood, false)
	end
	for _, x in ipairs({-52, 52}) do kit.lamp(lobby, Vector3.new(x, 12, -245), P.sun, 0.8, 40) end
	-- Invisible walls keep the lobby self-contained (reset is always available).
	for _, e in ipairs({{-66, -245, 2, 94}, {66, -245, 2, 94}, {0, -291, 134, 2}, {0, -199, 134, 2}}) do
		local wall = kit.box(lobby, "LobbyBoundary", e[1], 25, e[2], e[3], 50, e[4], P.ink, Enum.Material.SmoothPlastic, true, {shadow = false})
		wall.Transparency = 1
	end
	local lobbySpawn = CFrame.lookAt(Vector3.new(0, 3.2, -272), Vector3.new(0, 3.2, -214))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(8, 0.2, 8)
	spawn.CFrame = CFrame.new(0, ly + 0.1, -272)
	spawn.Transparency = 1
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = lobby
	kit.count += 1
	return {LobbySpawn = lobbySpawn, Podiums = podiums}
end

return Exterior
