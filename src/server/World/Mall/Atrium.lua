-- The public spaces: the central fountain plaza, kiosks, planters, seating, wayfinding and the
-- second-floor balcony. Obstacles here form loops around the fountain and planters, with every
-- drop landing and escalator mouth kept clear (checked by tests/mall.spec.luau).
local Atrium = {}

local function bench(kit, parent, x, y, z, yaw, color)
	local f = kit.frame(parent, Vector3.new(x, y, z), yaw, y)
	local P = kit.P
	f.b("BenchSeat", 0, 1.4, 0, 6.4, 0.5, 2, color or P.wood, Enum.Material.Wood, true, {cover = "Low", vault = true})
	f.b("BenchBack", 0, 2.4, 0.9, 6.4, 1.6, 0.4, color or P.wood, Enum.Material.Wood, false)
	for _, s in ipairs({-1, 1}) do f.b("BenchLeg", s * 2.8, 0, 0, 0.5, 1.4, 1.8, P.dark, Enum.Material.Metal, false) end
end

local function planter(kit, parent, x, y, z, radius, flower)
	local P = kit.P
	kit.can(parent, "PlanterWall", x, y + 1.1, z, radius * 2, 2.2, P.white, Enum.Material.Marble, true, {cover = "Low", vault = true})
	kit.can(parent, "PlanterSoil", x, y + 2.25, z, radius * 2 - 1, 0.2, P.soil, Enum.Material.SmoothPlastic, false)
	kit.can(parent, "PlanterRim", x, y + 2.2, z, radius * 2 + 0.3, 0.3, flower, Enum.Material.SmoothPlastic, false)
	kit.can(parent, "TreeTrunk", x, y + 5.5, z, 1.2, 7, P.darkwood, Enum.Material.Wood, true, {cover = "Soft"})
	kit.ball(parent, "TreeCrown", x, y + 10, z, radius * 1.8, 6, radius * 1.8, P.leaf, Enum.Material.SmoothPlastic, false, {cover = "Soft"})
	kit.ball(parent, "TreeCrownTop", x + 0.8, y + 12.5, z - 0.5, radius * 1.1, 3.4, radius * 1.1, P.lime, Enum.Material.SmoothPlastic, false)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		kit.ball(parent, "Blossom", x + math.cos(a) * (radius - 1.2), y + 2.6, z + math.sin(a) * (radius - 1.2), 1, 0.8, 1, flower, Enum.Material.SmoothPlastic, false)
	end
end

local function kiosk(kit, parent, x, y, z, yaw, color, label)
	local f = kit.frame(parent, Vector3.new(x, y, z), yaw, y)
	local P = kit.P
	f.b("KioskBase", 0, 0, 0, 7, 3.6, 4, P.white, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
	f.b("KioskTop", 0, 3.6, 0, 7.4, 0.3, 4.4, color, Enum.Material.SmoothPlastic, false)
	for _, sx in ipairs({-3.2, 3.2}) do f.b("KioskPole", sx, 3.9, 0, 0.3, 4.4, 0.3, P.steel, Enum.Material.Metal, false) end
	f.b("KioskCanopy", 0, 8.2, 0, 8.6, 0.5, 5.6, color, Enum.Material.Fabric, false)
	for i = 0, 3 do f.b("CanopyStripe", -3.2 + i * 2.1, 8.25, 0, 1, 0.52, 5.7, P.white, Enum.Material.Fabric, false) end
	f.sign(label, 0, 5.2, -2.3, 6, 1.8, P.white, color, false, {pixels = 24})
	for i = 1, 4 do f.b("Goods", -2.4 + (i - 1) * 1.6, 3.9, 0.2, 1, 1 + (i % 2) * 0.6, 1, ({P.red, P.sun, P.sky, P.pink})[i], Enum.Material.SmoothPlastic, false) end
end

function Atrium.build(kit, Layout)
	local P = kit.P
	local plaza = kit.group("Atrium")
	local balcony = kit.group("Balcony")
	local Y2 = Layout.FloorY[2]

	-- Centre: fountain with tiered column, jets and a colour medallion beneath.
	for i, d in ipairs({50, 44, 38}) do
		kit.can(plaza, "Medallion", 0, 0.03 + i * 0.015, 0, d, 0.04, ({P.sky, P.white, P.sun})[i], Enum.Material.SmoothPlastic, false)
	end
	kit.can(plaza, "FountainBasin", 0, 1.3, 0, 34, 2.6, P.white, Enum.Material.Marble, true, {cover = "Low", vault = true})
	kit.can(plaza, "FountainWater", 0, 2.3, 0, 31.4, 0.5, P.sky, Enum.Material.Glass, false, {transparency = 0.35})
	kit.can(plaza, "FountainRim", 0, 2.7, 0, 34.6, 0.3, P.gold, Enum.Material.Metal, false)
	kit.can(plaza, "FountainTier1", 0, 3.8, 0, 10, 2.4, P.white, Enum.Material.Marble, true, {cover = "Full"})
	kit.can(plaza, "FountainTier2", 0, 7, 0, 6, 4, P.white, Enum.Material.Marble, true, {cover = "Full"})
	kit.can(plaza, "FountainBowl", 0, 9.4, 0, 12, 0.6, P.sky, Enum.Material.Glass, false, {transparency = 0.3})
	kit.can(plaza, "FountainTopRing", 0, 10.2, 0, 3.4, 1.2, P.gold, Enum.Material.Metal, false)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		kit.can(plaza, "FountainJet", math.cos(a) * 11, 5, math.sin(a) * 11, 0.9, 5, P.white, Enum.Material.Glass, false, {transparency = 0.5})
		kit.ball(plaza, "FountainSplash", math.cos(a) * 11, 7.6, math.sin(a) * 11, 1.6, 1.2, 1.6, P.white, Enum.Material.Glass, false, {transparency = 0.45})
	end
	-- Water leaps from the top ring and the eight jets; sparkles hang over the basin.
	kit.emitter(plaza:FindFirstChild("FountainTopRing"), "spray")
	for _, child in ipairs(plaza:GetChildren()) do
		if child.Name == "FountainJet" then kit.emitter(child, "spray").Rate = 8 end
	end
	kit.emitter(plaza:FindFirstChild("FountainWater"), "sparkle")
	kit.lamp(plaza, Vector3.new(0, 12.4, 0), P.sky, 1.0, 40)

	-- Planter islands in the four quadrants, clear of stairs, ramps and drop landings.
	planter(kit, plaza, 30, 0, 34, 5.5, P.pink)
	planter(kit, plaza, -30, 0, 36, 5.5, P.sun)
	planter(kit, plaza, -30, 0, -34, 5.5, P.coral)
	planter(kit, plaza, 30, 0, -34, 5.5, P.violet)

	-- Kiosks along the ring corridors (clear of the escalator mouths).
	local kiosks = {
		{30, 75, 0, P.coral, "PRETZELS"}, {58, 75, 0, P.sky, "PHONE CASES"},
		{-30, -75, 180, P.sun, "LEMONADE"}, {-58, -75, 180, P.mint, "PLUSHIES"},
		{70, -25, 90, P.pink, "CANDY"}, {70, -45, 90, P.violet, "TEA"},
		{-70, 25, -90, P.orange, "CHURROS"}, {-70, 45, -90, P.teal, "SUNGLASSES"},
	}
	for _, k in ipairs(kiosks) do kiosk(kit, plaza, k[1], 0, k[2], math.rad(k[3]), k[4], k[5]) end

	-- Information desk (round) and directory boards.
	kit.can(plaza, "InfoDesk", -2, 1.8, -40, 9, 3.6, P.teal, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
	kit.can(plaza, "InfoDeskTop", -2, 3.7, -40, 9.6, 0.3, P.white, Enum.Material.Marble, false)
	kit.can(plaza, "InfoDeskPillar", -2, 8, -40, 1.6, 8, P.white, Enum.Material.SmoothPlastic, false)
	kit.sign(plaza, "INFO", CFrame.new(-2, 12.4, -40), 6, 2.2, P.white, P.teal)
	local boards = {{50, 2, "MALL MAP / LEVEL 1"}, {-50, -2, "MALL MAP / LEVEL 1"}, {2, 50, "TODAY: STORES + ARCADE"}, {-2, -52, "EAT UPSTAIRS!"}}
	for i, b in ipairs(boards) do
		kit.box(plaza, "BoardFrame", b[1], 4.2, b[2], 7, 8.4, 0.8, P.dark, Enum.Material.SmoothPlastic, true, {cover = "Full"})
		kit.sign(plaza, b[3], CFrame.new(b[1], 5.2, b[2] - 0.5), 6, 3, P.white, P.sky, {pixels = 20})
		for k = 1, 4 do kit.box(plaza, "BoardStripe", b[1], 1.4 + k * 0.6, b[2] - 0.45, 5.6 - k * 0.5, 0.25, 0.1, ({P.coral, P.sun, P.mint, P.violet})[k], Enum.Material.SmoothPlastic, false) end
	end
	-- Benches with clear ends: pairs facing the fountain and others along the corridors.
	bench(kit, plaza, 8, 0, 28, math.pi, P.wood)
	bench(kit, plaza, -8, 0, -28, 0, P.wood)
	bench(kit, plaza, 78, 0, 0, -math.pi / 2, P.wood)
	bench(kit, plaza, -78, 0, 0, math.pi / 2, P.wood)
	bench(kit, plaza, 40, 0, 66, math.pi, P.teal)
	bench(kit, plaza, -40, 0, -66, 0, P.teal)

	-- Hanging mega screen above the bridge crossing, a landmark from every direction.
	local cubeY = 36
	kit.box(plaza, "MegaCube", 0, cubeY, 0, 12, 8, 12, P.dark, Enum.Material.SmoothPlastic, false, {shadow = false})
	local faces = {{0, -6.2, 0, "CATCH ME"}, {0, 6.2, math.pi, "IF YOU CAN"}, {6.2, 0, -math.pi / 2, "CATCH MALL"}, {-6.2, 0, math.pi / 2, "RUN! RUN!"}}
	for i, face in ipairs(faces) do
		local cf = CFrame.new(face[1], cubeY, face[2]) * CFrame.Angles(0, face[3], 0)
		kit.sign(plaza, face[4], cf, 11, 7, P.white, ({P.coral, P.sky, P.violet, P.teal})[i], {material = Enum.Material.Neon, pixels = 28, distance = 250})
	end
	for _, c in ipairs({{-5, -5}, {5, -5}, {-5, 5}, {5, 5}}) do
		kit.box(plaza, "MegaCable", c[1], (cubeY + 4 + Layout.AtriumRoofY) / 2, c[2], 0.25, Layout.AtriumRoofY - cubeY - 4, 0.25, P.steel, Enum.Material.Metal, false)
	end
	-- Banners hanging from the roof ribs.
	local banners = {P.coral, P.sun, P.sky, P.mint, P.violet, P.pink}
	for i = 1, 12 do
		local a = i / 12 * math.pi * 2
		local x, z = math.cos(a) * 46, math.sin(a) * 52
		kit.box(plaza, "HangingBanner", math.max(-52, math.min(52, x)), 52, math.max(-57, math.min(57, z)), 3, 9, 0.3, banners[(i % #banners) + 1], Enum.Material.Fabric, false, {shadow = false})
	end

	-- Pennant strings across the ring corridors on level one.
	for _, z in ipairs({-76, 76}) do
		for i = 0, 15 do
			kit.box(plaza, "Pennant", -75 + i * 10, 19.2, z, 1.6, 2.2, 0.15, banners[(i % #banners) + 1], Enum.Material.Fabric, false, {shadow = false})
		end
		kit.box(plaza, "PennantLine", 0, 20.3, z, 160, 0.1, 0.1, P.dark, Enum.Material.SmoothPlastic, false)
	end

	-- Second floor balcony: benches by the rail, planters and kiosks on the ring.
	-- Benches sit beside, never in front of, the stair landings, bridge landings and drop gaps.
	for _, x in ipairs({-30, 30, -58, 58}) do
		bench(kit, balcony, x, Y2, 63.5, 0, P.coral)
		bench(kit, balcony, x, Y2, -63.5, math.pi, P.sky)
	end
	for _, z in ipairs({-24, -50}) do bench(kit, balcony, 58.5, Y2, z, -math.pi / 2, P.mint) end
	for _, z in ipairs({24, 50}) do bench(kit, balcony, -58.5, Y2, z, math.pi / 2, P.violet) end
	for _, p in ipairs({{70, 75}, {-70, 75}, {70, -75}, {-70, -75}}) do planter(kit, balcony, p[1], Y2, p[2], 4.5, P.pink) end
	kiosk(kit, balcony, 30, Y2, 78, 0, P.sky, "SMOOTHIES")
	kiosk(kit, balcony, -30, Y2, -78, math.pi, P.coral, "COOKIES")
	kiosk(kit, balcony, 72, Y2, -30, math.pi / 2, P.sun, "BALLOONS")
	kiosk(kit, balcony, -72, Y2, 30, -math.pi / 2, P.mint, "GADGETS")
	-- Pennants over the second-floor corridors.
	for _, z in ipairs({-76, 76}) do
		for i = 0, 15 do kit.box(balcony, "Pennant", -75 + i * 10, Y2 + 19.2, z, 1.6, 2.2, 0.15, banners[((i + 2) % #banners) + 1], Enum.Material.Fabric, false, {shadow = false}) end
	end
end

return Atrium
