-- Second-floor attractions: arcade, cinema, kids zone, food court, pets, photo studio, music,
-- gym and restrooms. They use the same slots as the ground-floor stores.
local Zones = {}

local function cabinet(ctx, lx, lz, yawDeg, body, screen, marquee)
	local g = ctx.sub(lx, lz, yawDeg)
	local P = ctx.P
	g.b("CabinetBody", 0, 0, 0, 3.4, 6.2, 2.8, body, Enum.Material.SmoothPlastic, true, {cover = "Full"})
	g.b("CabinetScreen", 0, 2.8, -1.45, 2.6, 2, 0.15, screen, Enum.Material.Neon, false)
	g.b("CabinetDeck", 0, 1.8, -1.6, 3, 0.5, 1, P.dark, Enum.Material.SmoothPlastic, false)
	g.b("CabinetMarquee", 0, 5.3, -1.45, 3.2, 0.8, 0.15, marquee, Enum.Material.Neon, false)
end

local function seatRow(ctx, lx, lz, len, y0, color)
	local f, P = ctx.f, ctx.P
	f.b("SeatBase", lx, y0, lz, len, 1.2, 2, color, Enum.Material.Fabric, true, {cover = "Low", vault = true})
	f.b("SeatBack", lx, y0 + 1.2, lz + 0.8, len, 1.6, 0.5, color, Enum.Material.Fabric, false)
	for i = 1, math.floor(len / 6) do f.b("Armrest", lx - len / 2 + i * 6, y0 + 1.2, lz, 0.4, 0.8, 1.6, P.dark, Enum.Material.SmoothPlastic, false) end
end

local function foodStall(ctx, lx, name, color, prop)
	local f, P = ctx.f, ctx.P
	local depth = ctx.D
	f.b("StallCounter", lx, 0, depth - 8, 14, 3.6, 3, P.white, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
	f.b("StallTop", lx, 3.6, depth - 8, 14.3, 0.3, 3.3, color, Enum.Material.SmoothPlastic, false)
	local kitchen = f.b("StallKitchen", lx, 0, depth - 3.5, 14, 11, 2, P.dark, Enum.Material.SmoothPlastic, true, {cover = "Full"})
	ctx.kit.emitter(kitchen, "steam")
	f.b("StallMenu", lx, 6.5, depth - 4.6, 11, 4.2, 0.3, P.white, Enum.Material.SmoothPlastic, false)
	f.sign(name, lx, 12.2, depth - 5.2, 13, 3.4, P.white, color, true, {pixels = 26})
	for i = 1, 4 do f.b("MenuLine", lx, 7.4 + (i - 1) * 0.9, depth - 4.8, 8 - (i % 2) * 2, 0.3, 0.15, color, Enum.Material.SmoothPlastic, false) end
	f.b("StallCanopy", lx, 10.8, depth - 8, 14.6, 0.5, 4.2, color, Enum.Material.Fabric, false)
	for i = 0, 6 do f.b("CanopyStripe", lx - 6.5 + i * 2.17, 10.85, depth - 8, 1.08, 0.52, 4.3, P.white, Enum.Material.Fabric, false) end
	if prop then prop(f, lx, depth - 8) end
end

local function diningIsland(ctx, lx, lz, color)
	local f, P = ctx.f, ctx.P
	f.can("DiningTable", lx, 0, lz, 4.6, 2.8, P.white, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
	f.can("DiningTop", lx, 2.8, lz, 5, 0.25, color, Enum.Material.SmoothPlastic, false)
	for i = 0, 3 do
		local a = i * math.pi / 2 + math.pi / 4
		f.can("Stool", lx + math.cos(a) * 3.4, 0, lz + math.sin(a) * 3.4, 1.6, 1.8, color, Enum.Material.SmoothPlastic, false)
	end
end

function Zones.defs(P, Fx)
	local list = {}

	-- N1 L2: ARCADE --------------------------------------------------------------------------
	table.insert(list, {slot = "N1", floor = 2, name = "GAME ZONE ARCADE", tagline = "INSERT COIN / CHASE HIGH SCORE", kind = "Arcade",
		accent = P.violet, wall = P.dark, carpet = P.black, floorMaterial = Enum.Material.SmoothPlastic, light = P.violet, serviceDoors = {22},
		build = function(ctx)
			local f = ctx.f
			local glow = {P.pink, P.sky, P.mint, P.sun, P.violet, P.coral}
			-- Back-to-back cabinet pairs form long full-cover walls with open aisles between.
			for r, z in ipairs({16, 30}) do
				for i = 1, 8 do
					local x = -44 + (i - 1) * 4
					cabinet(ctx, x, z, 0, P.dark, glow[(i + r) % #glow + 1], glow[(i + r + 2) % #glow + 1])
					cabinet(ctx, x, z + 3, 180, P.dark, glow[(i + r + 1) % #glow + 1], glow[(i + r + 3) % #glow + 1])
				end
			end
			for i = 1, 5 do cabinet(ctx, -44 + (i - 1) * 4, 46, 0, P.violet, glow[i], glow[(i + 1) % #glow + 1]) end
			-- Neon floor strips and a dance platform.
			for _, z in ipairs({8, 24, 40}) do f.b("FloorNeon", 0, 0.12, z, 90, 0.05, 0.5, glow[(z % 5) + 1], Enum.Material.Neon, false) end
			f.b("DancePlatform", 24, 0, 28, 14, 1, 14, P.dark, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
			for i = 0, 3 do for j = 0, 3 do f.b("DanceTile", 24 - 5.25 + i * 3.5, 1.02, 28 - 5.25 + j * 3.5, 3.2, 0.06, 3.2, glow[((i + j) % #glow) + 1], Enum.Material.Neon, false) end end
			-- Air hockey tables (low) and a giant claw machine landmark.
			for i, z in ipairs({12, 20}) do
				f.b("AirHockey", 40, 0, z, 6, 2.8, 9, P.sky, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
				f.b("AirHockeyGlow", 40, 2.85, z, 5, 0.1, 8, P.white, Enum.Material.Neon, false)
			end
			f.b("ClawBody", 40, 0, 40, 10, 5, 10, P.pink, Enum.Material.SmoothPlastic, true, {cover = "Full"})
			f.b("ClawGlass", 40, 5, 40, 9, 7, 9, P.glass, Enum.Material.Glass, true, {transparency = 0.6, shadow = false, cover = "Full"})
			f.b("ClawArm", 40, 8.4, 40, 0.5, 3.4, 0.5, P.steel, Enum.Material.Metal, false)
			for i = 1, 6 do f.ball("ClawPrize", 37.5 + (i % 3) * 2.4, 5.1, 37.5 + math.floor(i / 3) * 3, 1.8, 1.8, 1.8, glow[i], Enum.Material.SmoothPlastic, false) end
			f.b("ClawTopLight", 40, 12, 40, 10, 0.5, 10, P.violet, Enum.Material.Neon, false)
			Fx.counter(ctx, -8, 6, 12, 2.6, P.violet, P.white, P.pink)
			-- Photo booths and the prize room.
			for i = 1, 2 do
				Fx.hideCell(ctx, {id = "arcade_booth_" .. i, kind = "Photo Booth", lx = 8 + (i - 1) * 7, lz = 46, yaw = 0, w = 6, d = 6, wall = P.violet, accent = P.sun,
					door = P.sun, carpet = P.black})
			end
			Fx.hideCell(ctx, {id = "arcade_prize", kind = "Prize Room", lx = -4, lz = 44.5, yaw = 0, w = 8, d = 8, wall = P.pink, accent = P.sun, door = P.pink, carpet = P.violet,
				interior = function(g, w, d) g.b("PrizeShelf", 0, 0, d / 2 - 1.2, 6, 5, 1.4, P.white, Enum.Material.SmoothPlastic, false) end})
		end})

	-- N2 L2: CINEMA --------------------------------------------------------------------------
	table.insert(list, {slot = "N2", floor = 2, name = "STARLIGHT CINEMA", tagline = "NOW SHOWING: THE GREAT CHASE", kind = "Cinema",
		accent = P.red, wall = Color3.fromRGB(70, 40, 70), carpet = Color3.fromRGB(150, 40, 70), light = P.sun, serviceDoors = {-34, 34},
		build = function(ctx)
			local f = ctx.f
			-- Lobby: ticket counters, long concession bar, popcorn landmark and poster wall.
			Fx.counter(ctx, -26, 7, 14, 2.6, P.red, P.gold, P.sun)
			Fx.counter(ctx, 26, 7, 14, 2.6, P.red, P.gold, P.sun)
			f.b("ConcessionBar", 0, 0, 16, 26, 3.6, 3, P.dark, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
			f.b("ConcessionTop", 0, 3.6, 16, 26.4, 0.3, 3.4, P.gold, Enum.Material.Metal, false)
			f.b("ConcessionMenu", 0, 7, 17.8, 20, 3, 0.3, P.white, Enum.Material.Neon, false)
			f.can("PopcornBucket", 0, 0, 24, 5, 6, P.white, Enum.Material.SmoothPlastic, true, {cover = "Full"})
			for i = 0, 4 do f.b("BucketStripe", math.cos(i * 1.2566) * 2.2, 0, 24 + math.sin(i * 1.2566) * 2.2, 0.8, 6, 0.8, P.red, Enum.Material.SmoothPlastic, false) end
			for i = 1, 7 do f.ball("Popcorn", math.cos(i) * 1.6, 6 + (i % 3) * 0.6, 24 + math.sin(i) * 1.6, 1.8, 1.6, 1.8, P.cream, Enum.Material.SmoothPlastic, false) end
			for i = 1, 6 do f.b("Poster", -42 + (i - 1) * 17, 5, 1.8, 7, 9, 0.2, ({P.red, P.sky, P.sun, P.violet, P.coral, P.teal})[i], Enum.Material.Neon, false) end
			-- Theatre hall: stepped seating facing a glowing screen at the back-left.
			f.b("ScreenWall", 0, 0, 48.6, 70, 18, 0.6, P.white, Enum.Material.Neon, false)
			f.b("ScreenFrame", 0, 0, 48.3, 72, 19, 0.5, P.dark, Enum.Material.SmoothPlastic, true, {cover = "Full"})
			for i = 1, 4 do
				local y0 = (i - 1) * 1.2
				seatRow(ctx, -18, 28 + (i - 1) * 3, 28, y0, P.red)
				seatRow(ctx, 18, 28 + (i - 1) * 3, 28, y0, P.red)
			end
			f.b("TheatreRiser", -18, 0, 36, 30, 1.2, 12, P.dark, Enum.Material.Fabric, true)
			f.b("TheatreRiser", 18, 0, 36, 30, 1.2, 12, P.dark, Enum.Material.Fabric, true)
			Fx.hideCell(ctx, {id = "cinema_booth", kind = "Projection Booth", lx = 0, lz = 42.5, yaw = 0, w = 8, d = 8, wall = P.dark, accent = P.sun, door = P.red, carpet = P.dark,
				interior = function(g, w, d) g.b("Projector", 0, 0, d / 2 - 1.2, 2.4, 2.8, 1.6, P.steel, Enum.Material.Metal, false) end})
			Fx.hideCell(ctx, {id = "cinema_usher", kind = "Usher Closet", lx = 42, lz = 14, yaw = 0, w = 5, d = 5, wall = P.red, accent = P.sun, door = P.dark, carpet = P.dark})
			Fx.hideCell(ctx, {id = "cinema_usher_2", kind = "Usher Closet", lx = -42, lz = 14, yaw = 0, w = 5, d = 5, wall = P.red, accent = P.sun, door = P.dark, carpet = P.dark})
		end})

	-- N3 L2: KIDS ZONE -----------------------------------------------------------------------
	table.insert(list, {slot = "N3", floor = 2, name = "JUNGLE JUMP KIDS", tagline = "BOUNCE / SLIDE / GIGGLE", kind = "Play",
		accent = P.lime, wall = P.mint, carpet = P.sun, light = P.lime, serviceDoors = {40},
		build = function(ctx)
			local f = ctx.f
			local pop = {P.red, P.sun, P.sky, P.pink, P.lime, P.violet}
			-- Ball pit: a sunken-looking inlay filled with coloured balls (no collision).
			f.b("BallPitFloor", 22, 0.1, 22, 28, 0.06, 20, P.sky, Enum.Material.SmoothPlastic, false)
			for i = 1, 40 do
				local a = i * 2.399
				f.ball("PitBall", 22 + math.cos(a) * (i % 9) * 1.4, 0.2, 22 + math.sin(a) * (i % 7) * 1.35, 1.6, 1.6, 1.6, pop[(i % #pop) + 1], Enum.Material.SmoothPlastic, false)
			end
			-- Slide tower with stairs and a wedge slide.
			f.b("TowerBase", -30, 0, 14, 8, 8, 8, P.lime, Enum.Material.SmoothPlastic, true, {cover = "Full"})
			for i = 1, 5 do f.b("TowerStep", -30, 0, 22 + i * 1.6, 8, i * 1.4, 1.6, pop[i], Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true}) end
			f.wedge("SlideWedge", -22, 0, 14, 4, 8, 14, 90, P.red, Enum.Material.SmoothPlastic, true)
			-- Foam blocks and mushroom seats: soft low cover.
			for i = 1, 6 do f.b("FoamBlock", -10 + (i % 3) * 6, 0, 30 + math.floor(i / 3) * 6, 4, 2.4 + (i % 2), 4, pop[i], Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true}) end
			for i = 1, 4 do
				f.can("MushroomStem", 38, 0, 38 - (i - 1) * 6, 1.4, 2, P.white, Enum.Material.SmoothPlastic, false)
				f.can("MushroomCap", 38, 2, 38 - (i - 1) * 6, 4, 1.2, pop[i], Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
			end
			-- Giant jungle gym frame.
			for _, x in ipairs({-8, 8}) do for _, z in ipairs({40, 52}) do f.b("GymPost", x, 0, z - 2, 0.6, 10, 0.6, P.orange, Enum.Material.Metal, false) end end
			f.b("GymBar", 0, 9.4, 38, 16.6, 0.6, 0.6, P.orange, Enum.Material.Metal, false)
			f.b("GymBar", 0, 6, 38, 16.6, 0.6, 0.6, P.orange, Enum.Material.Metal, false)
			Fx.counter(ctx, 4, 6, 10, 2.6, P.lime, P.white, P.lime)
			for i = 1, 2 do
				Fx.hideCell(ctx, {id = "kids_tunnel_" .. i, kind = "Play Tunnel", lx = 8 + (i - 1) * 8, lz = 47, yaw = 0, w = 6, d = 6, h = 6, wall = pop[i + 2], accent = P.sun, door = pop[i], carpet = P.sun})
			end
			Fx.hideCell(ctx, {id = "kids_house", kind = "Play House", lx = -40, lz = 46, yaw = 0, w = 7, d = 7, h = 9, wall = P.pink, accent = P.sun, door = P.sun, carpet = P.peach})
		end})

	-- S1/S2/S3 L2: FOOD COURT ----------------------------------------------------------------
	local stalls = {
		S1 = {{-34, "BURGER BARN", P.red}, {0, "PIZZA PLANET", P.orange}, {34, "NOODLE MOON", P.coral}},
		S2 = {{-34, "TACO TOWN", P.lime}, {0, "SUSHI SPIN", P.sky}, {34, "ICE CREAM LAB", P.pink}},
		S3 = {{-34, "BUBBLE TEA", P.violet}, {0, "FRY STATION", P.sun}, {34, "DONUT DEN", P.peach}},
	}
	for _, id in ipairs({"S1", "S2", "S3"}) do
		table.insert(list, {slot = id, floor = 2, name = id == "S2" and "FOOD COURT" or "FOOD COURT " .. (id == "S1" and "WEST" or "EAST"), tagline = id == "S2" and "EAT / REGROUP / RUN" or nil,
			kind = "Food", accent = P.orange, wall = P.cream, carpet = P.cream, floorMaterial = Enum.Material.Marble, light = P.orange, wideDoor = true, serviceDoors = {-17, 17},
			build = function(ctx)
				local f = ctx.f
				local cols = {P.red, P.sun, P.sky, P.lime, P.pink, P.violet}
				for i, s in ipairs(stalls[id]) do
					local prop
					if s[2] == "BURGER BARN" then
						prop = function(g, x, z)
							g.can("BurgerBun", x - 7.5, 12.6, z, 3.4, 1.2, P.orange, Enum.Material.SmoothPlastic, false)
							g.can("BurgerPatty", x - 7.5, 11.8, z, 3.6, 0.8, P.darkwood, Enum.Material.SmoothPlastic, false)
							g.can("BurgerLettuce", x - 7.5, 11.2, z, 3.8, 0.5, P.lime, Enum.Material.SmoothPlastic, false)
						end
					elseif s[2] == "ICE CREAM LAB" then
						prop = function(g, x, z)
							g.wedge("ConeWedge", x - 7.5, 11, z, 1.8, 3, 1.8, 0, P.peach, Enum.Material.SmoothPlastic, false)
							g.ball("Scoop", x - 7.5, 13.6, z, 2.6, 2.4, 2.6, P.pink, Enum.Material.SmoothPlastic, false)
						end
					elseif s[2] == "DONUT DEN" then
						prop = function(g, x, z)
							g.can("DonutBase", x - 7.5, 11.6, z, 3.4, 1, P.peach, Enum.Material.SmoothPlastic, false)
							g.can("DonutIcing", x - 7.5, 12.5, z, 3.4, 0.4, P.pink, Enum.Material.SmoothPlastic, false)
						end
					end
					foodStall(ctx, s[1], s[2], s[3], prop)
				end
				-- Dining islands across the hall, leaving three open lanes.
				for i, x in ipairs({-42, -26, -10, 10, 26, 42}) do
					for j, z in ipairs({12, 24}) do
						if not (id == "S2" and math.abs(x) < 12 and z == 12) then diningIsland(ctx, x, z, cols[((i + j) % #cols) + 1]) end
					end
				end
				-- A staff room and a walk-in cooler behind the stalls, in every food court.
				Fx.hideCell(ctx, {id = "food_staff_" .. id, kind = "Staff Room", lx = 45.5, lz = 43.5, yaw = 0, w = 7, d = 7, wall = P.white, accent = P.orange, door = P.orange, carpet = P.cream,
					interior = function(g, w, d) g.b("StaffLocker", 0, 0, d / 2 - 1, 5, 6, 1, P.steel, Enum.Material.Metal, false) end})
				if id == "S3" then
					Fx.hideCell(ctx, {id = "food_cooler_" .. id, kind = "Walk-in Cooler", lx = -45.5, lz = 43.5, yaw = 0, w = 7, d = 7, wall = P.sky, accent = P.sky, door = P.sky, doorMaterial = Enum.Material.Glass, carpet = P.sky})
				else
					Fx.hideCell(ctx, {id = "food_pantry_" .. id, kind = "Mascot Closet", lx = -26, lz = 36, yaw = 0, w = 5, d = 5, wall = P.sun, accent = P.orange, door = P.sky, carpet = P.cream})
				end
			end})
	end

	-- E1 L2: RESTROOMS -----------------------------------------------------------------------
	local function restroom(slot, name)
		return {slot = slot, floor = 2, name = name, tagline = "FRESHEN UP", kind = "Restroom", accent = P.sky, wall = P.sky, carpet = P.white, floorMaterial = Enum.Material.Marble,
			light = P.sky, serviceDoors = {24},
			build = function(ctx)
				local f = ctx.f
				-- Sink counters with mirrors on the left; stalls on the right and back.
				for i, z in ipairs({9, 16, 23}) do
					Fx.counter(ctx, -24, z, 3, 6, P.white, P.sky, P.sky)
					f.b("SinkMirror", -28.5, 4, z, 0.3, 5.6, 6, P.sky, Enum.Material.Glass, false, {transparency = 0.3})
				end
				for i = 1, 5 do
					Fx.hideCell(ctx, {id = slot:lower() .. "_stall_" .. i, kind = "Restroom Stall", lx = -18 + (i - 1) * 7.6, lz = 60.5, yaw = 0, w = 6.4, d = 4.4, h = 8.5,
						wall = P.white, accent = P.sky, door = P.sky, doorMaterial = Enum.Material.SmoothPlastic, carpet = P.white, doorGap = 1.4,
						interior = function(g, w, d)
							g.b("Toilet", 0, 0, d / 2 - 1.1, 1.8, 2.2, 1.6, P.white, Enum.Material.SmoothPlastic, false)
							g.b("TankBack", 0, 2.2, d / 2 - 0.8, 1.8, 1.4, 0.6, P.white, Enum.Material.SmoothPlastic, false)
						end})
				end
				for i = 1, 3 do
					Fx.hideCell(ctx, {id = slot:lower() .. "_stall_r_" .. i, kind = "Restroom Stall", lx = 6 + (i - 1) * 7.6, lz = 44.5, yaw = 0, w = 6.4, d = 4.4, h = 8.5,
						wall = P.white, accent = P.sky, door = P.coral, doorMaterial = Enum.Material.SmoothPlastic, carpet = P.white, doorGap = 1.4})
				end
				Fx.sofa(ctx, 20, 12, 180, P.sky)
				Fx.plant(ctx, 26, 18, 1.1)
				f.b("HandDryer", 12, 3, 1.8, 2, 1.6, 0.8, P.steel, Enum.Material.Metal, false)
			end}
	end
	table.insert(list, restroom("E1", "RESTROOMS EAST"))
	table.insert(list, restroom("W3", "RESTROOMS WEST"))

	-- E2 L2: PET PALACE ----------------------------------------------------------------------
	table.insert(list, {slot = "E2", floor = 2, name = "PET PALACE", tagline = "FRIENDS WITH FUR AND FINS", kind = "Pets",
		accent = P.orange, wall = P.peach, carpet = Color3.fromRGB(190, 220, 160), light = P.orange, serviceDoors = {18},
		build = function(ctx)
			local f = ctx.f
			local fur = {P.orange, P.cream, P.darkwood, P.grey, P.sun}
			-- Giant aquarium: a solid glass tank with swimming blobs and rocks.
			f.b("TankBase", 0, 0, 34, 18, 3, 8, P.dark, Enum.Material.SmoothPlastic, true, {cover = "Full"})
			f.b("TankGlass", 0, 3, 34, 18, 7, 8, P.sky, Enum.Material.Glass, true, {transparency = 0.55, shadow = false, cover = "Full"})
			f.b("TankLid", 0, 10, 34, 18.4, 0.5, 8.4, P.dark, Enum.Material.SmoothPlastic, false)
			for i = 1, 8 do f.ball("Fish", -7 + (i % 4) * 4.6, 4.5 + (i % 3) * 1.7, 33 + (i % 2) * 2, 1.6, 0.8, 0.5, ({P.orange, P.sun, P.pink, P.mint})[(i % 4) + 1], Enum.Material.SmoothPlastic, false) end
			for i = 1, 4 do f.ball("TankRock", -6 + i * 3, 3.2, 34, 2.2, 1.4, 2, P.grey, Enum.Material.Slate, false) end
			-- Pet cages: low units with cuddly residents.
			for i, z in ipairs({10, 18, 26}) do
				f.b("CageUnit", -25, 0, z, 4, 3.4, 6, P.white, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
				f.b("CageGlass", -25, 3.4, z, 4, 1.6, 6, P.glass, Enum.Material.Glass, false, {transparency = 0.6})
				f.ball("Pet", -25, 3.4, z, 2, 1.4, 2, fur[(i % #fur) + 1], Enum.Material.Fabric, false)
			end
			-- Cat tree: stepped platforms to climb.
			f.can("CatPole", 20, 0, 12, 1.4, 9, P.wood, Enum.Material.Wood, true, {cover = "Soft"})
			for i = 1, 3 do f.b("CatShelf", 20, i * 2.6, 12, 5, 0.6, 5, P.mint, Enum.Material.Fabric, i == 1, {cover = "Low", vault = true}) end
			Fx.gondola(ctx, 24, 40, 16, false, P.white, fur, 7)
			Fx.rack(ctx, 12, 22, 8, false, P.coral, P.sun)
			Fx.counter(ctx, 22, 6, 10, 2.6, P.orange, P.white, P.orange)
			for i = 1, 3 do Fx.hideCell(ctx, {id = "pet_carrier_" .. i, kind = "Pet Carrier", lx = -18 + (i - 1) * 6, lz = 60, yaw = 0, w = 5, d = 4.5, h = 7, wall = P.orange, accent = P.sun, door = P.sun, carpet = P.peach, doorMaterial = Enum.Material.Metal}) end
		end})

	-- E3 L2: PHOTO STUDIO --------------------------------------------------------------------
	table.insert(list, {slot = "E3", floor = 2, name = "SNAP STUDIO", tagline = "SAY CHEESE / THEN RUN", kind = "Photo",
		accent = P.pink, wall = P.white, carpet = P.lilac, light = P.pink, serviceDoors = {-12},
		build = function(ctx)
			local f = ctx.f
			local sets = {P.pink, P.sky, P.sun, P.mint, P.violet}
			-- Backdrop panels: tall full-cover sets to weave between.
			for i = 1, 4 do
				local x = -21 + (i - 1) * 14
				f.b("Backdrop", x, 0, 20 + (i % 2) * 10, 12, 11, 0.8, sets[i], Enum.Material.SmoothPlastic, true, {cover = "Full"})
				f.b("BackdropFoot", x, 0, 20.9 + (i % 2) * 10, 12, 0.6, 2.4, P.dark, Enum.Material.SmoothPlastic, false)
			end
			-- Giant frame, flower wall and neon sign.
			f.b("FrameTop", 0, 11, 50, 18, 1, 1, P.gold, Enum.Material.Metal, false)
			f.b("FrameL", -8.5, 1, 50, 1, 10, 1, P.gold, Enum.Material.Metal, false)
			f.b("FrameR", 8.5, 1, 50, 1, 10, 1, P.gold, Enum.Material.Metal, false)
			f.b("FrameBottom", 0, 0, 50, 18, 1, 1, P.gold, Enum.Material.Metal, false)
			for i = 1, 10 do f.ball("Flower", -26 + (i % 5) * 3, 1.5 + math.floor(i / 5) * 3, 62.4, 2.4, 2.4, 1, sets[(i % #sets) + 1], Enum.Material.SmoothPlastic, false) end
			f.sign("SMILE", 0, 7, 62.8, 12, 4, P.white, P.pink, true, {material = Enum.Material.Neon})
			-- Ring-light stands (soft cover) and props.
			for i = 1, 4 do
				f.b("LightStand", -22 + (i - 1) * 14, 0, 40, 0.3, 6.6, 0.3, P.dark, Enum.Material.Metal, false)
				f.can("RingLight", -22 + (i - 1) * 14, 6.2, 40, 2.6, 0.4, P.white, Enum.Material.Neon, false)
			end
			Fx.sofa(ctx, -20, 8, 180, P.pink)
			Fx.sofa(ctx, 20, 8, 180, P.violet)
			Fx.counter(ctx, 22, 5, 10, 2.6, P.pink, P.white, P.pink)
			for i = 1, 3 do Fx.hideCell(ctx, {id = "snap_booth_" .. i, kind = "Selfie Booth", lx = 6 + (i - 1) * 7.4, lz = 60, yaw = 0, wall = sets[i], accent = P.sun, door = P.white, carpet = P.white}) end
		end})

	-- W1 L2: MUSIC ---------------------------------------------------------------------------
	table.insert(list, {slot = "W1", floor = 2, name = "BEAT BOX MUSIC", tagline = "VINYL / GUITARS / DROPS", kind = "Music",
		accent = P.coral, wall = Color3.fromRGB(80, 60, 110), carpet = Color3.fromRGB(60, 40, 90), light = P.coral, serviceDoors = {18},
		build = function(ctx)
			local f = ctx.f
			local discs = {P.coral, P.sun, P.sky, P.mint, P.violet}
			-- Record bins: low crates full of sleeves.
			for i, z in ipairs({12, 20, 28}) do
				for _, x in ipairs({-16, 16}) do
					f.b("RecordBin", x, 0, z, 12, 2.8, 3, P.darkwood, Enum.Material.Wood, true, {cover = "Low", vault = true})
					for k = 1, 6 do f.b("Sleeve", x - 5 + (k - 1) * 2, 2.8, z, 1.6, 2, 0.3, discs[(k + i) % #discs + 1], Enum.Material.SmoothPlastic, false) end
				end
			end
			-- Stage with drum kit and speaker stacks.
			f.b("Stage", 0, 0, 52, 22, 2, 12, P.dark, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
			for _, x in ipairs({-8, 8}) do
				f.b("Speaker", x, 2, 54, 4, 8, 3, P.black, Enum.Material.SmoothPlastic, true, {cover = "Full"})
				f.can("Woofer", x, 3, 52.4, 2.6, 0.4, P.steel, Enum.Material.Metal, false)
			end
			f.can("BassDrum", 0, 2, 52, 4, 3, P.red, Enum.Material.SmoothPlastic, false)
			for i = 1, 3 do f.can("Cymbal", -4 + i * 3, 5.5, 53, 2.6, 0.2, P.gold, Enum.Material.Metal, false) end
			-- Guitar wall: a row of colourful guitars on the left.
			for i = 1, 6 do
				local z = 10 + (i - 1) * 6
				f.ball("GuitarBody", -28, 5, z, 0.8, 3.4, 2.6, discs[(i % #discs) + 1], Enum.Material.Wood, false)
				f.b("GuitarNeck", -28, 6.8, z, 0.4, 4, 0.5, P.darkwood, Enum.Material.Wood, false)
			end
			-- Giant headphone landmark.
			f.can("HeadphoneBand", 20, 0, 40, 6, 0.8, P.coral, Enum.Material.SmoothPlastic, false)
			for _, s in ipairs({-1, 1}) do f.can("Earcup", 20 + s * 3, 0, 40, 2.4, 6, P.dark, Enum.Material.SmoothPlastic, true, {cover = "Full"}) end
			Fx.counter(ctx, 22, 6, 10, 2.6, P.coral, P.white, P.coral)
			Fx.hideCell(ctx, {id = "beat_dj", kind = "DJ Booth", lx = -22, lz = 58, yaw = 0, w = 8, d = 7, wall = P.dark, accent = P.coral, door = P.coral, carpet = P.dark,
				interior = function(g, w, d) g.b("Decks", 0, 0, d / 2 - 1.2, 5, 3, 1.6, P.steel, Enum.Material.Metal, false) end})
			Fx.hideCell(ctx, {id = "beat_booth", kind = "Listening Booth", lx = 24, lz = 58, yaw = 0, w = 6, d = 6, wall = P.violet, accent = P.coral, door = P.coral, carpet = P.dark})
		end})

	-- W2 L2: GYM -----------------------------------------------------------------------------
	table.insert(list, {slot = "W2", floor = 2, name = "FIT ZONE GYM", tagline = "PUSH / PULL / SPRINT", kind = "Gym",
		accent = P.sky, wall = P.white, carpet = P.dark, floorMaterial = Enum.Material.SmoothPlastic, light = P.sky, serviceDoors = {-14},
		build = function(ctx)
			local f = ctx.f
			local mat = {P.sky, P.coral, P.lime, P.sun}
			-- Machines in rows: low cover with colourful pads.
			for i, z in ipairs({12, 22, 32}) do
				for k, x in ipairs({-18, -6, 6, 18}) do
					f.b("Machine", x, 0, z, 4, 4.4, 5, P.dark, Enum.Material.Metal, true, {cover = "Low", vault = true})
					f.b("MachinePad", x, 1.6, z + 1.8, 3, 2.4, 0.6, mat[(i + k) % #mat + 1], Enum.Material.SmoothPlastic, false)
					f.b("MachineStack", x, 4.4, z - 1.6, 1.6, 2.6, 1.2, P.steel, Enum.Material.Metal, false)
				end
			end
			-- Boxing ring: roped platform in the back.
			f.b("RingPlatform", 0, 0, 52, 18, 1.4, 18, P.sky, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
			for _, x in ipairs({-8.4, 8.4}) do for _, z in ipairs({43.6, 60.4}) do f.b("RingPost", x, 1.4, z, 0.6, 4, 0.6, P.red, Enum.Material.Metal, false) end end
			for _, y in ipairs({2.6, 3.6, 4.6}) do
				f.b("RingRope", 0, y, 43.6, 17, 0.2, 0.2, P.red, Enum.Material.SmoothPlastic, false)
				f.b("RingRope", 0, y, 60.4, 17, 0.2, 0.2, P.red, Enum.Material.SmoothPlastic, false)
			end
			-- Heavy bags and a plate wall.
			for i = 1, 3 do
				f.b("BagChain", -24 + (i - 1) * 6, 11, 40, 0.2, 7, 0.2, P.steel, Enum.Material.Metal, false)
				f.can("HeavyBag", -24 + (i - 1) * 6, 3.4, 40, 2.4, 5.6, P.red, Enum.Material.Fabric, true, {cover = "Soft"})
			end
			Fx.counter(ctx, 22, 6, 10, 2.6, P.sky, P.white, P.sky)
			for i = 1, 3 do Fx.hideCell(ctx, {id = "gym_locker_" .. i, kind = "Locker", lx = 12 + (i - 1) * 4.4, lz = 61, yaw = 0, w = 3.8, d = 4, h = 8, wall = P.sky, accent = P.lime, door = P.dark, doorMaterial = Enum.Material.Metal, carpet = P.dark, doorGap = 0.6}) end
		end})

	return list
end

return Zones
