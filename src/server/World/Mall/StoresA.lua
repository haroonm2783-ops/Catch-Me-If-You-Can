-- Ground-floor anchor stores on the north and south strips (100 x 50 each).
local StoresA = {}

function StoresA.defs(P, Fixtures)
	local Fx = Fixtures
	local list = {}

	-- N1 ------------------------------------------------------------------------------------
	table.insert(list, {slot = "N1", floor = 1, name = "FASHION HOUSE", tagline = "NEW SEASON / RUNWAY READY", kind = "Clothing",
		accent = P.pink, wall = P.blush, carpet = P.lilac, light = P.pink, serviceDoors = {22},
		build = function(ctx)
			local f = ctx.f
			local pinks, blues = {P.pink, P.coral, P.sun, P.sky, P.violet, P.mint}, {P.white, P.peach}
			-- Window mannequins in coordinated outfits.
			for i, x in ipairs({-44, -36, -28, -4, 4, 12}) do
				Fx.mannequin(ctx, x, 3.5, pinks[(i % #pinks) + 1], pinks[((i + 2) % #pinks) + 1])
			end
			-- Clothing racks: soft cover in two wings, with a clear aisle from the entrance.
			for ix, x in ipairs({-40, -26, 8, 19}) do
				for iz, z in ipairs({14, 22, 30}) do
					Fx.rack(ctx, x, z, 9, false, pinks[((ix + iz) % #pinks) + 1], pinks[((ix + iz + 3) % #pinks) + 1])
				end
			end
			-- Raised runway with a lit backdrop: a stage to vault onto and sprint along.
			f.b("RunwayStage", -6, 0, 24, 8, 3.2, 22, P.white, Enum.Material.Marble, true, {cover = "Low", vault = true})
			f.b("RunwayGlowL", -10.1, 0.2, 24, 0.25, 0.25, 22, P.pink, Enum.Material.Neon, false)
			f.b("RunwayGlowR", -1.9, 0.2, 24, 0.25, 0.25, 22, P.pink, Enum.Material.Neon, false)
			f.b("RunwayBackdrop", -6, 0, 36.5, 14, 12, 0.6, P.pink, Enum.Material.SmoothPlastic, true, {cover = "Full"})
			f.b("RunwayBackdropGlow", -6, 9.4, 36.1, 12, 0.3, 0.3, P.white, Enum.Material.Neon, false)
			-- Fitting rooms along the back wall: five curtain booths, each a real hiding spot.
			for i = 1, 5 do
				Fx.hideCell(ctx, {id = "fashion_fit_" .. i, kind = "Fitting Room", lx = -44 + (i - 1) * 6.4, lz = 45.5, yaw = 0,
					wall = P.white, accent = P.pink, door = i % 2 == 0 and P.coral or P.violet, carpet = P.lilac,
					interior = function(g, w, d)
						g.b("Mirror", 0, 2, d / 2 - 0.55, 3.6, 5.6, 0.15, P.sky, Enum.Material.Glass, false, {transparency = 0.3})
						g.b("Bench", 0, 0, d / 2 - 1.2, 3.6, 1.4, 1.2, P.pink, Enum.Material.Fabric, false)
					end})
			end
			Fx.counter(ctx, 6, 8, 10, 2.6, P.pink, P.white, P.pink)
			Fx.shelfWall(ctx, 47.2, 12, 14, true, pinks)
			Fx.plant(ctx, 47, 40, 1)
			Fx.hangBanner(ctx, -20, 20, 8, 7, P.pink)
			Fx.hangBanner(ctx, 12, 28, 8, 7, P.sun)
			Fx.sofa(ctx, 28, 44, 180, P.violet)
			Fx.sofa(ctx, 40, 44, 180, P.coral)
		end})

	-- N2 ------------------------------------------------------------------------------------
	table.insert(list, {slot = "N2", floor = 1, name = "VOLT ELECTRONICS", tagline = "THE FUTURE, ON SALE", kind = "Electronics",
		accent = P.sky, wall = P.white, carpet = Color3.fromRGB(58, 104, 214), floorMaterial = Enum.Material.SmoothPlastic, light = P.sky, serviceDoors = {-30, 30},
		build = function(ctx)
			local f = ctx.f
			local neons = {P.sky, P.mint, P.violet, P.pink, P.sun}
			-- TV wall across the back: nine glowing screens.
			for i = 1, 9 do Fx.tv(ctx, -40 + (i - 1) * 10, 8, 48.4, 8.2, 5, neons[(i % #neons) + 1], true) end
			-- Gaming island and display tables, leaving the centre aisle open.
			Fx.table(ctx, -22, 14, 12, 3.2, 3.2, P.dark, neons)
			Fx.table(ctx, 22, 14, 12, 3.2, 3.2, P.dark, neons)
			Fx.table(ctx, -22, 24, 12, 3.2, 3.2, P.dark, neons)
			Fx.table(ctx, 22, 24, 12, 3.2, 3.2, P.dark, neons)
			-- Phone and headphone gondolas, tall full cover.
			for _, z in ipairs({12, 22, 32}) do Fx.gondola(ctx, -38, z, 8, false, P.white, neons, 7) end
			-- Appliance wall on the right: fridges and washers (full cover) with coloured doors.
			for i, z in ipairs({8, 14, 38, 44}) do
				f.b("Appliance", 43, 0, z, 6, 7, 5.6, P.white, Enum.Material.SmoothPlastic, true, {cover = "Full"})
				f.b("ApplianceDoor", 40, 1.2, z, 0.2, 4.4, 4.4, neons[(i % #neons) + 1], Enum.Material.SmoothPlastic, false)
				f.can("ApplianceDial", 40.1, 5.8, z, 0.8, 0.2, P.dark, Enum.Material.Metal, false)
			end
			-- Mega screen tower: a landmark you can see from the corridor.
			for i = 0, 2 do Fx.tv(ctx, -14, 1 + i * 5.6, 10, 8, 5, neons[(i % #neons) + 1], false) end
			f.b("TowerSpine", -14, 0, 10.3, 1, 17, 0.8, P.dark, Enum.Material.Metal, true, {cover = "Full"})
			Fx.counter(ctx, 34, 5, 10, 2.6, P.dark, P.white, P.sky)
			-- VR demo booths: enclosed cells to duck into.
			for i = 1, 2 do
				Fx.hideCell(ctx, {id = "volt_vr_" .. i, kind = "VR Booth", lx = 6 + (i - 1) * 7, lz = 45.5, yaw = 0, wall = P.dark,
					accent = P.sky, door = P.sky, doorMaterial = Enum.Material.SmoothPlastic, carpet = P.dark,
					interior = function(g, w, d) g.b("VRStand", 0, 0, d / 2 - 1.2, 1.2, 4.5, 1.2, P.sky, Enum.Material.Neon, false) end})
			end
			Fx.plant(ctx, 46, 44, 1.1)
		end})

	-- N3 ------------------------------------------------------------------------------------
	table.insert(list, {slot = "N3", floor = 1, name = "SNEAKER PALACE", tagline = "KICKS FOR EVERY CHASE", kind = "Sneakers",
		accent = P.orange, wall = P.white, carpet = Color3.fromRGB(255, 190, 110), floorMaterial = Enum.Material.SmoothPlastic, light = P.orange, serviceDoors = {44},
		build = function(ctx)
			local f = ctx.f
			local hues = {P.orange, P.red, P.sun, P.sky, P.lime, P.violet}
			-- Shoe wall along the back: glowing boxes of kicks.
			Fx.gondola(ctx, 2, 47.2, 60, false, P.white, hues, 9)
			-- Stepped display pyramid: a parkour staircase of sneakers.
			f.b("PyramidTier1", 16, 0, 27, 26, 1.6, 16, P.white, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
			f.b("PyramidTier2", 16, 1.6, 27, 18, 1.6, 10, P.orange, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
			f.b("PyramidTier3", 16, 3.2, 27, 10, 1.6, 5, P.white, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
			for i = 1, 4 do f.b("DisplayShoe", 8.5 + i * 3.4, 4.8, 27, 2.4, 1.1, 1, hues[i], Enum.Material.SmoothPlastic, false) end
			-- Giant sneaker landmark.
			local gx, gz = -22, 30
			f.b("GiantSole", gx, 0, gz, 8, 1.6, 20, P.white, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
			f.b("GiantUpper", gx, 1.6, gz + 2, 7, 4.2, 13, P.orange, Enum.Material.SmoothPlastic, true, {cover = "Low"})
			f.wedge("GiantToe", gx, 1.6, gz - 6.5, 7, 2.6, 6, 0, P.orange, Enum.Material.SmoothPlastic, true)
			f.b("GiantCollar", gx, 5.8, gz + 6, 6.6, 1.6, 5, P.red, Enum.Material.SmoothPlastic, false)
			f.b("GiantTongue", gx, 5.2, gz - 0.6, 4.8, 2.4, 0.8, P.white, Enum.Material.SmoothPlastic, false)
			for i = 1, 4 do f.b("GiantLace", gx, 5.9 - i * 0.15, gz - 3.5 + i * 1.7, 5.2, 0.35, 0.5, P.white, Enum.Material.SmoothPlastic, false) end
			f.t("GiantSwoosh", gx - 3.55, 2.4, gz + 1, 0.25, 1.2, 8, 0, 0, 12, P.white, Enum.Material.Neon, false)
			-- Benches (low cover), a hoop and checkout.
			for _, z in ipairs({12, 20}) do Fx.table(ctx, -40, z, 3, 9, 2.2, P.dark, hues) end
			Fx.counter(ctx, -8, 7, 11, 2.6, P.orange, P.white, P.orange)
			f.b("HoopBoard", 47.6, 9, 38, 0.4, 5, 7, P.white, Enum.Material.SmoothPlastic, false)
			f.b("HoopRim", 46.4, 9.5, 38, 2.4, 0.3, 2.4, P.orange, Enum.Material.Metal, false)
			-- Stock rooms behind the shoe wall: two enclosed cells.
			for i = 1, 2 do
				Fx.hideCell(ctx, {id = "sneaker_stock_" .. i, kind = "Stock Room", lx = -44 + (i - 1) * 9, lz = 44.5, yaw = 0, w = 8, d = 8, wall = P.dark,
					accent = P.orange, door = P.orange, carpet = P.dark,
					interior = function(g, w, d)
						g.b("Boxes", -1.5, 0, d / 2 - 1.6, 2.2, 2.4, 1.8, P.orange, Enum.Material.SmoothPlastic, false)
						g.b("Boxes", 1.4, 0, d / 2 - 1.6, 2.2, 3.6, 1.8, P.white, Enum.Material.SmoothPlastic, false)
					end})
			end
			Fx.hangBanner(ctx, 0, 20, 8, 7, P.orange)
		end})

	-- S1 ------------------------------------------------------------------------------------
	table.insert(list, {slot = "S1", floor = 1, name = "MEGA DEPARTMENT", tagline = "EVERYTHING UNDER ONE ROOF", kind = "Department",
		accent = P.teal, wall = P.white, carpet = P.cream, floorMaterial = Enum.Material.Marble, light = P.teal, serviceDoors = {-24, 24},
		build = function(ctx)
			local f = ctx.f
			local mix = {P.teal, P.coral, P.sun, P.sky, P.violet, P.mint}
			-- Maze of tall gondolas: three rows with generous aisles.
			for ix, x in ipairs({-36, -14, 8}) do
				for iz, z in ipairs({13, 25, 37}) do
					Fx.gondola(ctx, x, z, 14, false, P.white, mix, 7)
				end
			end
			-- Perfume island: round counters with glowing bottles.
			f.can("PerfumeCounter", 36, 0, 22, 9, 3.6, P.white, Enum.Material.Marble, true, {cover = "Low", vault = true})
			f.can("PerfumeTop", 36, 3.6, 22, 9.4, 0.3, P.teal, Enum.Material.SmoothPlastic, false)
			for i = 1, 6 do
				local a = i / 6 * math.pi * 2
				f.b("Bottle", 36 + math.cos(a) * 3, 3.9, 22 + math.sin(a) * 3, 0.9, 1.6, 0.9, mix[i], Enum.Material.Glass, false)
			end
			f.can("PerfumeColumn", 36, 3.9, 22, 1.6, 6, P.teal, Enum.Material.Neon, false)
			-- Clothing wing with three fitting rooms.
			for i = 1, 3 do
				Fx.hideCell(ctx, {id = "dept_fit_" .. i, kind = "Fitting Room", lx = 30 + (i - 1) * 6.4, lz = 45.5, yaw = 0, wall = P.white,
					accent = P.teal, door = P.teal, carpet = P.lilac,
					interior = function(g, w, d) g.b("Mirror", 0, 2, d / 2 - 0.55, 3.6, 5.6, 0.15, P.sky, Enum.Material.Glass, false, {transparency = 0.3}) end})
			end
			for i = 1, 3 do Fx.rack(ctx, 40, 12 + i * 6, 8, true, mix[i], mix[i + 2]) end
			Fx.counter(ctx, -10, 5, 10, 2.6, P.teal, P.white, P.teal)
			Fx.counter(ctx, 36, 5, 10, 2.6, P.teal, P.white, P.teal)
			Fx.hangBanner(ctx, -20, 20, 8, 7, P.teal)
			Fx.plant(ctx, -46, 6, 1.1)
		end})

	-- S2 ------------------------------------------------------------------------------------
	table.insert(list, {slot = "S2", floor = 1, name = "QUICK MART", tagline = "SNACKS / DRINKS / FAST", kind = "Convenience",
		accent = P.lime, wall = P.white, carpet = P.white, floorMaterial = Enum.Material.Marble, light = P.lime, serviceDoors = {-34, 34},
		build = function(ctx)
			local f = ctx.f
			local snack = {P.red, P.sun, P.sky, P.lime, P.orange, P.pink}
			-- Parallel aisles of tall shelving (full cover) running front to back.
			for i, x in ipairs({-42, -30, -18, 18, 30, 42}) do
				Fx.gondola(ctx, x, 27, 30, true, P.white, snack, 7)
			end
			-- Cold wall along the back with glowing glass doors.
			for i = 1, 9 do
				f.b("FridgeDoor", -40 + (i - 1) * 10, 0, 48.2, 9, 8, 1.2, P.dark, Enum.Material.Metal, true, {cover = "Full"})
				f.b("FridgeGlass", -40 + (i - 1) * 10, 1, 47.5, 7.6, 6, 0.2, P.sky, Enum.Material.Neon, false, {transparency = 0.2})
			end
			-- Checkout, roller grill, drinks bin and a magazine stand near the front.
			Fx.counter(ctx, -10, 6, 12, 2.8, P.lime, P.white, P.lime)
			Fx.table(ctx, 8, 7, 4, 3, 3.4, P.red, snack)
			f.b("MagazineRack", 12, 0, 9, 4, 6, 1, P.steel, Enum.Material.Metal, true, {cover = "Soft"})
			for i = 1, 4 do f.b("Magazine", 12, 1 + i * 1.1, 8.4, 3.2, 0.9, 0.2, snack[i], Enum.Material.SmoothPlastic, false) end
			-- Walk-in freezer: a cold-room cell at the back, behind the right-hand aisles.
			Fx.hideCell(ctx, {id = "mart_freezer", kind = "Walk-in Freezer", lx = 0, lz = 43.5, yaw = 0, w = 10, d = 10, wall = P.white,
				accent = P.sky, door = P.sky, doorMaterial = Enum.Material.Glass, carpet = P.sky,
				interior = function(g, w, d)
					for i = 1, 3 do g.b("FreezerShelf", -3.5 + (i - 1) * 3.5, 0, d / 2 - 1.2, 3, 5, 1.4, P.white, Enum.Material.SmoothPlastic, false) end
				end})
			-- A stock closet on the left, mirroring the freezer so both back aisles have somewhere to duck.
			Fx.hideCell(ctx, {id = "mart_stock", kind = "Stock Closet", lx = -14, lz = 44.5, yaw = 0, w = 7, d = 8, wall = P.sun,
				accent = P.red, door = P.red, carpet = P.cream})
			f.can("SodaCanLandmark", 0, 0, 18, 4, 10, P.red, Enum.Material.SmoothPlastic, true, {cover = "Full"})
			f.can("SodaCanTop", 0, 10, 18, 3.6, 0.4, P.steel, Enum.Material.Metal, false)
			f.can("SodaCanBand", 0, 4.5, 18, 4.1, 1.8, P.white, Enum.Material.SmoothPlastic, false)
		end})

	-- S3 ------------------------------------------------------------------------------------
	table.insert(list, {slot = "S3", floor = 1, name = "TOY KINGDOM", tagline = "PLAY / BUILD / SQUEAL", kind = "Toys",
		accent = P.sun, wall = P.blush, carpet = P.sky, light = P.sun, serviceDoors = {-20},
		build = function(ctx)
			local f = ctx.f
			local toy = {P.red, P.sun, P.sky, P.lime, P.pink, P.violet, P.orange}
			-- Giant alphabet-block pyramid: climbable, colourful, great for loops.
			local base = {{-30, 20}, {-22, 20}, {-14, 20}, {-26, 20}, {-18, 20}}
			for i, p in ipairs({{-34, 22}, {-26, 22}, {-18, 22}}) do
				f.b("GiantBlock", p[1], 0, p[2], 6, 6, 6, toy[i], Enum.Material.SmoothPlastic, true, {cover = "Full"})
				f.b("BlockLetter", p[1], 6.02, p[2], 3, 0.1, 3, P.white, Enum.Material.SmoothPlastic, false)
			end
			f.b("GiantBlock", -30, 6, 22, 6, 6, 6, toy[4], Enum.Material.SmoothPlastic, true, {cover = "Full"})
			f.b("GiantBlock", -22, 6, 22, 6, 6, 6, toy[5], Enum.Material.SmoothPlastic, true, {cover = "Full"})
			f.b("GiantBlock", -26, 12, 22, 6, 6, 6, toy[6], Enum.Material.SmoothPlastic, true, {cover = "Full"})
			-- Giant teddy bear: a friendly landmark built from spheres.
			local bx, bz = 28, 32
			f.ball("BearBody", bx, 0, bz, 9, 10, 8, P.peach, Enum.Material.Fabric, true, {cover = "Full"})
			f.ball("BearHead", bx, 9, bz - 0.5, 7, 6.5, 6.5, P.peach, Enum.Material.Fabric, false)
			for _, s in ipairs({-1, 1}) do
				f.ball("BearEar", bx + s * 3.2, 14.4, bz - 0.5, 2.4, 2.4, 2, P.peach, Enum.Material.Fabric, false)
				f.ball("BearArm", bx + s * 5.4, 3, bz - 1, 3, 6, 3, P.peach, Enum.Material.Fabric, false)
				f.ball("BearEye", bx + s * 1.6, 11, bz - 3.6, 0.8, 0.9, 0.5, P.black, Enum.Material.SmoothPlastic, false)
			end
			f.ball("BearSnout", bx, 9.6, bz - 3.6, 3, 2.4, 2, P.cream, Enum.Material.Fabric, false)
			f.ball("BearNose", bx, 10.2, bz - 4.5, 1, 0.8, 0.6, P.black, Enum.Material.SmoothPlastic, false)
			f.b("BearBow", bx, 7.2, bz - 3.8, 4, 1.2, 0.6, P.red, Enum.Material.Fabric, false)
			-- Toy shelves, a play table and a train track loop.
			Fx.gondola(ctx, -2, 32, 30, false, P.white, toy, 8)
			Fx.gondola(ctx, -8, 14, 14, false, P.white, toy, 6)
			Fx.table(ctx, 10, 14, 10, 3.5, 2.6, P.sky, toy)
			Fx.table(ctx, -40, 8, 3, 12, 2.6, P.sun, toy)
			f.b("TrainTrack", 12, 0.08, 26, 14, 0.06, 1, P.dark, Enum.Material.SmoothPlastic, false)
			f.b("TrainEngine", 8, 0.1, 26, 3, 1.8, 1.6, P.red, Enum.Material.SmoothPlastic, false)
			f.b("TrainCar", 12, 0.1, 26, 3, 1.4, 1.6, P.sun, Enum.Material.SmoothPlastic, false)
			Fx.counter(ctx, -10, 6, 10, 2.6, P.sun, P.white, P.sun)
			-- Play tents: small enclosed cells in the back corners.
			for i = 1, 3 do
				Fx.hideCell(ctx, {id = "toy_tent_" .. i, kind = "Play Tent", lx = 12 + (i - 1) * 7, lz = 46, yaw = 0, w = 6, d = 5, h = 8,
					wall = toy[i + 3], accent = P.sun, door = toy[i], carpet = P.sun,
					interior = function(g, w, d) g.ball("TentPillow", 0, 0, d / 2 - 1, 2.4, 1.4, 1.6, P.white, Enum.Material.Fabric, false) end})
			end
			Fx.hangBanner(ctx, 20, 18, 10, 6, P.sun)
		end})

	return list
end

return StoresA
