-- Ground-floor stores on the east and west strips (60 wide x 65 deep, entrance centred).
local StoresB = {}

function StoresB.defs(P, Fx)
	local list = {}

	-- E1 ------------------------------------------------------------------------------------
	table.insert(list, {slot = "E1", floor = 1, name = "SPARKLE & CO", tagline = "DIAMONDS / WATCHES / GOLD", kind = "Jewelry",
		accent = P.violet, wall = P.lilac, carpet = Color3.fromRGB(122, 70, 170), light = P.gold, serviceDoors = {-6},
		build = function(ctx)
			local f = ctx.f
			local gems = {P.sky, P.pink, P.mint, P.sun, P.red}
			-- Glass display cases: solid so you can't walk through them, but low and vaultable.
			for _, z in ipairs({14, 24, 34}) do
				for _, x in ipairs({-17, 17}) do
					f.b("CaseBase", x, 0, z, 10, 2.6, 3, P.dark, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
					f.b("CaseGlass", x, 2.6, z, 10, 1.4, 3, P.glass, Enum.Material.Glass, true, {transparency = 0.45, shadow = false, vault = true})
					for i = 1, 4 do f.b("Gem", x - 3.6 + (i - 1) * 2.4, 2.7, z, 0.9, 0.9, 0.9, gems[((i + z) % #gems) + 1], Enum.Material.Neon, false) end
				end
			end
			-- Giant diamond on a lit plinth: the store's landmark, visible from the atrium.
			f.can("DiamondPlinth", 0, 0, 52, 9, 2.2, P.white, Enum.Material.Marble, true, {cover = "Low", vault = true})
			f.t("DiamondCore", 0, 2.4, 52, 5, 5, 5, 0, 45, 45, P.sky, Enum.Material.Neon, false, {transparency = 0.25})
			f.wedge("DiamondTopA", 0, 7.2, 52, 5, 2.4, 3.5, 0, P.white, Enum.Material.Glass, false, {transparency = 0.2})
			f.wedge("DiamondTopB", 0, 7.2, 52, 5, 2.4, 3.5, 180, P.white, Enum.Material.Glass, false, {transparency = 0.2})
			f.can("DiamondGlow", 0, 2.25, 52, 8, 0.2, P.sky, Enum.Material.Neon, false)
			-- Chandelier ring.
			f.can("ChandelierRing", 0, 17, 30, 10, 0.5, P.gold, Enum.Material.Metal, false)
			for i = 1, 8 do
				local a = i / 8 * math.pi * 2
				f.ball("ChandelierBulb", math.cos(a) * 4.8, 16, 30 + math.sin(a) * 4.8, 0.9, 1.2, 0.9, P.white, Enum.Material.Neon, false)
			end
			f.b("ChandelierChain", 0, 17.5, 30, 0.2, 4.5, 0.2, P.gold, Enum.Material.Metal, false)
			Fx.sofa(ctx, -22, 46, 180, P.violet)
			Fx.sofa(ctx, 22, 46, 180, P.violet)
			Fx.counter(ctx, 22, 6, 10, 2.6, P.dark, P.gold, P.gold)
			-- Vault and private viewing room: enclosed cells.
			Fx.hideCell(ctx, {id = "sparkle_vault", kind = "Vault", lx = -24, lz = 58, yaw = 0, w = 8, d = 8, wall = P.steel, accent = P.gold,
				door = P.steel, doorMaterial = Enum.Material.Metal, carpet = P.dark,
				interior = function(g, w, d) g.b("SafeBoxes", 0, 0, d / 2 - 1.2, 5, 4, 1.4, P.gold, Enum.Material.Metal, false) end})
			Fx.hideCell(ctx, {id = "sparkle_viewing", kind = "Viewing Room", lx = 24, lz = 58, yaw = 0, w = 8, d = 8, wall = P.violet, accent = P.gold,
				door = P.violet, carpet = P.lilac})
		end})

	-- E2 ------------------------------------------------------------------------------------
	table.insert(list, {slot = "E2", floor = 1, name = "SPORTS ZONE", tagline = "TRAIN / PLAY / WIN", kind = "Sports",
		accent = P.lime, wall = P.white, carpet = Color3.fromRGB(70, 160, 100), light = P.lime, serviceDoors = {18},
		build = function(ctx)
			local f = ctx.f
			local jerseys = {P.red, P.sky, P.sun, P.lime, P.orange}
			-- Half court inlay with a hoop: a clear playground in the middle.
			f.b("CourtInlay", 0, 0.1, 26, 26, 0.04, 28, P.orange, Enum.Material.SmoothPlastic, false)
			f.b("CourtLineA", 0, 0.14, 26, 26, 0.03, 0.4, P.white, Enum.Material.SmoothPlastic, false)
			f.can("CourtCircle", 0, 0.14, 26, 8, 0.03, P.white, Enum.Material.SmoothPlastic, false)
			f.can("CourtCircleInner", 0, 0.16, 26, 7.4, 0.03, P.orange, Enum.Material.SmoothPlastic, false)
			f.b("HoopPole", 0, 0, 42, 0.8, 11, 0.8, P.steel, Enum.Material.Metal, true, {cover = "Soft"})
			f.b("HoopBackboard", 0, 8, 41.4, 6, 4, 0.4, P.white, Enum.Material.SmoothPlastic, false)
			f.can("HoopRim", 0, 8.4, 40, 2.4, 0.25, P.orange, Enum.Material.Metal, false)
			-- Treadmills line the right wall.
			for i, z in ipairs({12, 20, 28, 36}) do
				f.b("TreadmillBase", 22, 0, z, 3, 1.2, 6, P.dark, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
				f.b("TreadmillBelt", 22, 1.2, z, 2.4, 0.1, 5.2, P.black, Enum.Material.SmoothPlastic, false)
				f.b("TreadmillPost", 22, 1.2, z + 2.6, 0.5, 3.8, 0.5, P.steel, Enum.Material.Metal, false)
				f.b("TreadmillConsole", 22, 4.6, z + 2.6, 2.2, 0.9, 0.6, P.lime, Enum.Material.Neon, false)
			end
			-- Dumbbell and jersey gondolas on the left; barbell racks (soft cover) near the back.
			Fx.gondola(ctx, -26, 18, 14, true, P.white, jerseys, 7)
			Fx.rack(ctx, -14, 12, 9, false, P.red, P.sky)
			Fx.rack(ctx, -14, 20, 9, false, P.sun, P.lime)
			for i = 1, 3 do
				f.b("BarbellRack", -6 + (i - 1) * 8, 0, 56, 6, 3, 0.8, P.dark, Enum.Material.Metal, true, {cover = "Low", vault = true})
				f.b("BarbellBar", -6 + (i - 1) * 8, 3.2, 55.6, 7, 0.3, 0.3, P.steel, Enum.Material.Metal, false)
				for _, s in ipairs({-1, 1}) do f.can("Plate", -6 + (i - 1) * 8 + s * 3.2, 2.4, 55.6, 2.4, 0.5, P.red, Enum.Material.SmoothPlastic, false) end
			end
			-- Climbing wall: a tall coloured panel studded with holds.
			f.b("ClimbingWall", 18, 0, 59, 18, 14, 1.4, P.sky, Enum.Material.SmoothPlastic, true, {cover = "Full"})
			for i = 1, 16 do f.b("Hold", 10 + (i % 8) * 2.2, 1.5 + math.floor(i / 8) * 4 + (i % 3), 58.2, 1, 0.8, 0.6, jerseys[(i % #jerseys) + 1], Enum.Material.SmoothPlastic, false) end
			Fx.counter(ctx, 22, 6, 10, 2.6, P.lime, P.white, P.lime)
			-- Locker room: four enclosed lockers.
			for i = 1, 4 do
				Fx.hideCell(ctx, {id = "sports_locker_" .. i, kind = "Locker", lx = -27 + (i - 1) * 4.2, lz = 60.5, yaw = 0, w = 3.8, d = 4, h = 8,
					wall = P.sky, accent = P.lime, door = P.sky, doorMaterial = Enum.Material.Metal, carpet = P.dark, doorGap = 0.6})
			end
		end})

	-- E3 ------------------------------------------------------------------------------------
	table.insert(list, {slot = "E3", floor = 1, name = "GLOW BEAUTY BAR", tagline = "SHINE / SPARKLE / REPEAT", kind = "Beauty",
		accent = P.coral, wall = P.blush, carpet = Color3.fromRGB(255, 205, 214), light = P.pink, serviceDoors = {18},
		build = function(ctx)
			local f = ctx.f
			local tints = {P.coral, P.pink, P.red, P.violet, P.peach}
			-- Vanity stations with bulb-lined mirrors along the left wall.
			for i, z in ipairs({9, 20, 45, 56}) do
				Fx.counter(ctx, -25, z, 2.8, 8, P.white, P.blush, P.pink)
				f.b("VanityMirror", -28, 3.8, z, 0.3, 6, 7, P.sky, Enum.Material.Glass, false, {transparency = 0.25})
				for k = 1, 4 do f.ball("MirrorBulb", -27.7, 4.4 + (k - 1) * 1.6, z - 3.4, 0.5, 0.5, 0.5, P.sun, Enum.Material.Neon, false) end
			end
			-- Nail bar with stools.
			Fx.counter(ctx, 12, 24, 3, 18, P.pink, P.white, P.pink)
			for i = 1, 5 do f.can("Stool", 16, 0, 16 + (i - 1) * 4, 1.8, 2.2, P.coral, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true}) end
			-- Perfume tower (full cover) and a giant lipstick landmark.
			f.can("PerfumeTower", 0, 0, 36, 5, 10, P.white, Enum.Material.Marble, true, {cover = "Full"})
			for i = 1, 6 do
				local a = i / 6 * math.pi * 2
				f.b("Bottle", math.cos(a) * 2.8, 2 + (i % 3) * 2.4, 36 + math.sin(a) * 2.8, 0.9, 1.6, 0.9, tints[(i % #tints) + 1], Enum.Material.Glass, false)
			end
			f.can("LipstickBase", 20, 0, 48, 4.4, 5, P.gold, Enum.Material.Metal, true, {cover = "Full"})
			f.can("LipstickBody", 20, 5, 48, 3.6, 5, P.red, Enum.Material.SmoothPlastic, true, {cover = "Full"})
			f.wedge("LipstickTip", 20, 10, 48, 3.6, 2.4, 3.6, 0, P.red, Enum.Material.SmoothPlastic, false)
			Fx.rack(ctx, 6, 12, 8, false, P.pink, P.white)
			Fx.counter(ctx, 22, 6, 10, 2.6, P.coral, P.white, P.coral)
			-- Makeover pods and a photo booth: enclosed cells in the back.
			Fx.hideCell(ctx, {id = "beauty_pod_1", kind = "Makeover Pod", lx = -8, lz = 60, yaw = 0, wall = P.white, accent = P.coral, door = P.pink, carpet = P.blush,
				interior = function(g, w, d) g.b("PodChair", 0, 0, d / 2 - 1.6, 2.4, 2.2, 2.4, P.coral, Enum.Material.Fabric, false) end})
			Fx.hideCell(ctx, {id = "beauty_pod_2", kind = "Makeover Pod", lx = 0, lz = 60, yaw = 0, wall = P.white, accent = P.coral, door = P.violet, carpet = P.blush})
			Fx.hideCell(ctx, {id = "beauty_photo", kind = "Photo Booth", lx = 8, lz = 60, yaw = 0, wall = P.coral, accent = P.sun, door = P.sun, carpet = P.sun})
		end})

	-- W1 ------------------------------------------------------------------------------------
	table.insert(list, {slot = "W1", floor = 1, name = "BOOKWORM BOOKS", tagline = "STORIES YOU CAN HIDE IN", kind = "Books",
		accent = P.wood, wall = P.cream, carpet = Color3.fromRGB(176, 110, 90), light = P.orange, serviceDoors = {0},
		build = function(ctx)
			local f = ctx.f
			local covers = {P.red, P.sky, P.sun, P.lime, P.violet, P.coral, P.teal}
			-- Bookcase maze: tall shelves in staggered rows with 5-stud aisles.
			for i, x in ipairs({-20, -10, 10, 20}) do Fx.bookcase(ctx, x, 30, 34, true, P.darkwood, covers) end
			Fx.bookcase(ctx, -4, 52, 14, false, P.darkwood, covers)
			Fx.bookcase(ctx, 4, 12, 12, false, P.darkwood, covers)
			Fx.bookcase(ctx, -17, 62, 22, false, P.darkwood, covers)
			-- Reading nook: sofas, a low table and a rug.
			f.b("Rug", -22, 0.08, 10, 12, 0.05, 9, P.red, Enum.Material.Fabric, false)
			Fx.sofa(ctx, -22, 15, 180, P.teal)
			Fx.table(ctx, -22, 9, 5, 3, 2.2, P.darkwood, covers)
			-- Giant open book landmark.
			f.b("BookCoverBase", 22, 0, 8, 10, 0.8, 7, P.red, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
			f.wedge("BookPageL", 17.4, 0.8, 8, 4.6, 2.2, 6.4, 90, P.white, Enum.Material.SmoothPlastic, false)
			f.wedge("BookPageR", 26.6, 0.8, 8, 4.6, 2.2, 6.4, -90, P.white, Enum.Material.SmoothPlastic, false)
			Fx.counter(ctx, 22, 6, 10, 2.6, P.darkwood, P.wood, P.orange)
			-- Library ladder (decor) and a secret reading room behind a bookcase door.
			f.b("LadderRail", -28.5, 0, 45, 0.4, 9, 0.4, P.wood, Enum.Material.Wood, false)
			f.b("LadderRail", -27, 0, 45, 0.4, 9, 0.4, P.wood, Enum.Material.Wood, false)
			Fx.hideCell(ctx, {id = "books_secret", kind = "Secret Reading Room", lx = 22, lz = 58, yaw = 0, w = 8, d = 8, wall = P.darkwood, accent = P.orange,
				door = P.darkwood, doorMaterial = Enum.Material.Wood, carpet = P.red,
				interior = function(g, w, d) g.b("Armchair", 0, 0, d / 2 - 1.6, 3, 2.4, 2.6, P.coral, Enum.Material.Fabric, false) end})
			Fx.hideCell(ctx, {id = "books_nook", kind = "Reading Booth", lx = 12, lz = 58, yaw = 0, w = 6, d = 6, wall = P.darkwood, accent = P.orange,
				door = P.orange, carpet = P.red})
		end})

	-- W2 ------------------------------------------------------------------------------------
	table.insert(list, {slot = "W2", floor = 1, name = "COZY NEST HOME", tagline = "MAKE ROOM FOR FUN", kind = "Furniture",
		accent = P.mint, wall = P.cream, carpet = P.wood, floorMaterial = Enum.Material.WoodPlanks, light = P.sun, serviceDoors = {18},
		build = function(ctx)
			local f = ctx.f
			local soft = {P.mint, P.sky, P.coral, P.sun, P.violet}
			-- Living room: rug, sofas, coffee table and a TV unit.
			f.b("LivingRug", -20, 0.08, 14, 14, 0.05, 10, P.sky, Enum.Material.Fabric, false)
			Fx.sofa(ctx, -20, 20, 180, P.coral)
			Fx.sofa(ctx, -26, 12, 90, P.mint)
			Fx.table(ctx, -20, 12, 5, 3, 1.8, P.darkwood, soft)
			f.b("TVUnit", -24, 0, 4, 8, 2, 1.6, P.darkwood, Enum.Material.Wood, true, {cover = "Low", vault = true})
			Fx.tv(ctx, -24, 2.8, 4.2, 6, 3.4, P.sky, false)
			-- Bedroom: bed, headboard, bedside tables.
			f.b("BedFrame", 14, 0, 26, 9, 1.8, 11, P.darkwood, Enum.Material.Wood, true, {cover = "Low", vault = true})
			f.b("Mattress", 14, 1.8, 25, 8.4, 1.2, 10, P.white, Enum.Material.Fabric, false)
			f.b("Duvet", 14, 3, 27, 8.6, 0.5, 6, P.mint, Enum.Material.Fabric, false)
			f.b("Headboard", 14, 1.8, 31.6, 9, 4.4, 0.8, P.darkwood, Enum.Material.Wood, true, {cover = "Low"})
			for _, s in ipairs({-1, 1}) do f.b("Bedside", 14 + s * 6, 0, 30.4, 2.2, 2.6, 2.2, P.darkwood, Enum.Material.Wood, true, {cover = "Low", vault = true}) end
			-- Kitchen island and dining set along the back.
			f.b("IslandBody", 0, 0, 46, 14, 3.6, 4, P.white, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
			f.b("IslandTop", 0, 3.6, 46, 14.4, 0.3, 4.4, P.darkwood, Enum.Material.Wood, true, {vault = true})
			for i = 1, 4 do f.can("BarStool", -5 + (i - 1) * 3.4, 0, 42.4, 1.6, 2.8, P.mint, Enum.Material.SmoothPlastic, false) end
			f.b("DiningTable", 18, 0, 46, 8, 2.8, 5, P.wood, Enum.Material.Wood, true, {cover = "Low", vault = true})
			-- Giant floor lamp landmark.
			f.b("LampPole", 24, 0, 16, 0.5, 11, 0.5, P.steel, Enum.Material.Metal, false)
			f.can("LampShade", 24, 8, 16, 4, 4, P.sun, Enum.Material.Neon, false, {transparency = 0.2})
			f.can("LampBase", 24, 0, 16, 2.4, 0.5, P.dark, Enum.Material.Metal, false)
			Fx.counter(ctx, 22, 6, 10, 2.6, P.mint, P.white, P.mint)
			Fx.plant(ctx, -26, 48, 1.2)
			-- Wardrobes you can step into: enclosed cells.
			for i = 1, 3 do
				Fx.hideCell(ctx, {id = "nest_wardrobe_" .. i, kind = "Wardrobe", lx = -22 + (i - 1) * 5.6, lz = 61, yaw = 0, w = 5, d = 4.2, h = 9.5,
					wall = P.darkwood, accent = P.mint, door = P.wood, doorMaterial = Enum.Material.Wood, carpet = P.darkwood, doorGap = 0.5})
			end
		end})

	-- W3 ------------------------------------------------------------------------------------
	table.insert(list, {slot = "W3", floor = 1, name = "NOIR & GOLD", tagline = "LUXURY BOUTIQUE", kind = "Luxury",
		accent = P.gold, wall = Color3.fromRGB(240, 230, 214), carpet = P.black, floorMaterial = Enum.Material.Marble, light = P.gold, serviceDoors = {0},
		build = function(ctx)
			local f = ctx.f
			-- Round pedestals with glass domes and handbags.
			for i, p in ipairs({{-16, 14}, {16, 14}, {-16, 28}, {16, 28}, {-16, 42}, {16, 42}}) do
				f.can("Pedestal", p[1], 0, p[2], 6, 2.6, P.white, Enum.Material.Marble, true, {cover = "Low", vault = true})
				f.b("Handbag", p[1], 2.7, p[2], 2.6, 1.8, 1.2, i % 2 == 0 and P.red or P.black, Enum.Material.Fabric, false)
				f.b("BagStrap", p[1], 4.4, p[2], 1.4, 0.3, 0.3, P.gold, Enum.Material.Metal, false)
				f.can("Dome", p[1], 2.6, p[2], 5.4, 3.6, P.glass, Enum.Material.Glass, false, {transparency = 0.7, shadow = false})
			end
			-- Mannequins in gowns along the walls.
			for i, z in ipairs({10, 20, 30, 40, 50}) do
				Fx.mannequin(ctx, -27.5, z, P.black, P.gold)
				Fx.mannequin(ctx, 27.5, z, P.gold, P.black)
			end
			-- Grand chandelier and velvet ropes leading to the sofa lounge.
			f.can("ChandelierRing", 0, 16, 34, 14, 0.6, P.gold, Enum.Material.Metal, false)
			for i = 1, 12 do
				local a = i / 12 * math.pi * 2
				f.ball("ChandelierBulb", math.cos(a) * 6.8, 14.8, 34 + math.sin(a) * 6.8, 1, 1.4, 1, P.white, Enum.Material.Neon, false)
			end
			f.b("ChandelierChain", 0, 16.5, 34, 0.3, 5.5, 0.3, P.gold, Enum.Material.Metal, false)
			Fx.sofa(ctx, 0, 52, 180, P.red)
			Fx.counter(ctx, 22, 6, 12, 2.6, P.black, P.gold, P.gold)
			-- Private fitting suites: roomy enclosed cells.
			for i = 1, 2 do
				Fx.hideCell(ctx, {id = "noir_suite_" .. i, kind = "Private Suite", lx = -20 + (i - 1) * 40, lz = 59, yaw = 0, w = 8, d = 8, h = 10,
					wall = P.black, accent = P.gold, door = P.red, carpet = P.red,
					interior = function(g, w, d) g.b("SuiteMirror", 0, 2, d / 2 - 0.55, 5, 6, 0.15, P.sky, Enum.Material.Glass, false, {transparency = 0.3}) end})
			end
		end})

	return list
end

return StoresB
