-- Back of house: the service corridor ring on both floors. It links every store's rear door,
-- gives chasers and runners loops that bypass the public corridors, and holds staff lockers.
local Service = {}

function Service.build(kit, Layout, Fx)
	local P = kit.P
	local folder = kit.group("BackOfHouse")
	local SX, SZ = Layout.Service.x, Layout.Service.z
	local StX, StZ = Layout.Stores.x, Layout.Stores.z
	local mid = (StZ + SZ) / 2
	local midX = (StX + SX) / 2

	for level = 1, 2 do
		local y = Layout.FloorY[level]
		-- Floor inlay (industrial grey with yellow guide lines) and light strips.
		for _, z in ipairs({mid, -mid}) do
			kit.box(folder, "ServiceFloor", 0, y + 0.03, z, SX * 2 - 2, 0.05, Layout.ServiceWidth - 1, P.grey, Enum.Material.Concrete, false)
			kit.box(folder, "ServiceGuide", 0, y + 0.07, z, SX * 2 - 4, 0.05, 0.5, P.sun, Enum.Material.SmoothPlastic, false)
			kit.box(folder, "ServiceLight", 0, y + 21.7, z, SX * 2 - 6, 0.3, 0.8, P.white, Enum.Material.Neon, false)
		end
		for _, x in ipairs({midX, -midX}) do
			kit.box(folder, "ServiceFloor", x, y + 0.03, 0, Layout.ServiceWidth - 1, 0.05, SZ * 2 - 2, P.grey, Enum.Material.Concrete, false)
			kit.box(folder, "ServiceGuide", x, y + 0.07, 0, 0.5, 0.05, SZ * 2 - 4, P.sun, Enum.Material.SmoothPlastic, false)
			kit.box(folder, "ServiceLight", x, y + 21.7, 0, 0.8, 0.3, SZ * 2 - 6, P.white, Enum.Material.Neon, false)
		end
		-- Pipes along the outer walls (visual only) and "STAFF ONLY" signs by the stairs.
		for _, z in ipairs({SZ - 0.8, -SZ + 0.8}) do
			kit.box(folder, "Pipe", 0, y + 17, z, SX * 2 - 4, 0.7, 0.7, level == 1 and P.coral or P.sky, Enum.Material.Metal, false)
			kit.box(folder, "PipeLow", 0, y + 13, z, SX * 2 - 4, 0.5, 0.5, P.steel, Enum.Material.Metal, false)
		end
		for _, x in ipairs({SX - 0.8, -SX + 0.8}) do
			kit.box(folder, "Pipe", x, y + 17, 0, 0.7, 0.7, SZ * 2 - 4, level == 1 and P.coral or P.sky, Enum.Material.Metal, false)
		end
		-- Crate stacks: 2-high vaultable cover, always leaving a clear 6-stud lane.
		local crates = {
			{-110, mid + 3.5}, {-55, mid - 3.5}, {0, mid + 3.5}, {95, mid - 3.5}, {120, mid + 3.5},
			{-100, -mid - 3.5}, {-55, -mid + 3.5}, {0, -mid - 3.5}, {75, -mid + 3.5}, {140, -mid - 3.5},
			{midX + 3.5, 40}, {midX - 3.5, -30}, {midX + 3.5, 110}, {midX - 3.5, -115},
			{-midX - 3.5, -45}, {-midX + 3.5, 45}, {-midX - 3.5, 110}, {-midX + 3.5, -115},
		}
		for i, c in ipairs(crates) do
			local color = ({P.wood, P.orange, P.sky, P.mint})[(i % 4) + 1]
			kit.box(folder, "CrateLarge", c[1], y + 1.8, c[2], 3.6, 3.6, 3.6, color, Enum.Material.Wood, true, {cover = "Low", vault = true})
			kit.box(folder, "CrateSmall", c[1], y + 4.4, c[2], 2.4, 1.6, 2.4, P.wood, Enum.Material.Wood, true)
			kit.box(folder, "CrateStrap", c[1], y + 1.8, c[2], 3.7, 0.3, 3.7, P.dark, Enum.Material.SmoothPlastic, false)
		end
		-- Staff lockers (hiding cells) in groups along the outer walls.
		local ctx = {P = P, kit = kit, parent = folder, floor = level, name = "Back of House"}
		function ctx.sub(wx, wz, yawDeg, par) return kit.frame(par or folder, Vector3.new(wx, y, wz), math.rad(yawDeg or 0), y) end
		local groups = {
			{-135, SZ - 2.4, 0, "N"}, {70, SZ - 2.4, 0, "N"}, {-70, -SZ + 2.4, 180, "S"}, {135, -SZ + 2.4, 180, "S"},
			{SX - 2.4, 60, 90, "E"}, {-SX + 2.4, -60, -90, "W"},
		}
		for gi, g in ipairs(groups) do
			for i = 1, 3 do
				local ox, oz = 0, 0
				if g[4] == "N" or g[4] == "S" then ox = (i - 1) * 4.4 * (g[4] == "N" and 1 or -1) else oz = (i - 1) * 4.4 * (g[4] == "E" and -1 or 1) end
				ctx.name = "Back of House"
				local spotId = string.format("staff_l%d_%s%d_%d", level, g[4], gi, i)
				local localCtx = setmetatable({}, {__index = ctx})
				Fx.hideCell(localCtx, {id = spotId, kind = "Staff Locker", lx = g[1] + ox, lz = g[2] + oz, yaw = g[3], w = 3.8, d = 4, h = 8,
					wall = P.steel, accent = P.orange, door = P.dark, doorMaterial = Enum.Material.Metal, carpet = P.dark, doorGap = 0.6})
			end
		end
	end
	-- Loading-dock roll-up doors (decor) at the four corners of the ground floor.
	for _, c in ipairs({{SX - 0.4, SZ - 6, -1, 0}, {-SX + 0.4, SZ - 6, 1, 0}, {SX - 0.4, -SZ + 6, -1, 0}, {-SX + 0.4, -SZ + 6, 1, 0}}) do
		kit.box(folder, "DockDoor", c[1], 6, c[2], 0.6, 10, 10, P.steel, Enum.Material.Metal, false)
		for i = 1, 5 do kit.box(folder, "DockSlat", c[1] + c[3] * 0.4, 1.5 + i * 1.6, c[2], 0.2, 0.2, 9.6, P.grey, Enum.Material.Metal, false) end
	end
end

return Service
