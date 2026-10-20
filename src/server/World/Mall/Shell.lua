-- Mall structure: foundation, upper deck, roof, atrium, escalators, stairs, bridges, railings.
local Shell = {}

-- Straight stairs. `from`/`to` are plan points (Vector2) at floor level and deck level.
local function stairs(kit, parent, name, from, to, width, rise, color, y0)
	local direction = (to - from)
	local run = direction.Magnitude
	local dir = direction.Unit
	local steps = math.ceil(rise / 0.8)
	local base = y0 or 0
	for i = 1, steps do
		local h = rise * i / steps
		local along = run * (i - 0.5) / steps
		local center = from + dir * along
		local cf = CFrame.lookAt(Vector3.new(center.X, base + h / 2, center.Y), Vector3.new(center.X + dir.X, base + h / 2, center.Y + dir.Y))
		kit.part(parent, name, Vector3.new(width, h, run / steps + 0.06), cf, color, Enum.Material.Concrete, true)
	end
	return run
end

-- Rail with glass infill and a coloured handrail. Axis-aligned segment from a to b (plan points).
local function railing(kit, parent, a, b, y, color, height)
	height = height or 3.6
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.5 then return end
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, y + height / 2, mid.Y), Vector3.new(mid.X + delta.X, y + height / 2, mid.Y + delta.Y))
	-- Glass is solid so nobody slides through it, but low enough to be jumped.
	kit.part(parent, "RailGlass", Vector3.new(0.3, height - 0.6, length), cf * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.new(0, -0.3, 0), kit.P.glass, Enum.Material.Glass, true, {transparency = 0.55, shadow = false})
	kit.part(parent, "RailTop", Vector3.new(0.6, 0.3, length), cf * CFrame.new(0, height / 2 - 0.15, 0), color, Enum.Material.SmoothPlastic, false)
	local posts = math.max(2, math.floor(length / 10) + 1)
	for i = 0, posts - 1 do
		local p = a + delta * (i / (posts - 1))
		kit.box(parent, "RailPost", p.X, y + height / 2, p.Y, 0.5, height, 0.5, color, Enum.Material.Metal, false)
	end
end

function Shell.build(kit, Layout)
	local P = kit.P
	local model = kit.model
	local structure = kit.group("Structure")
	local floors = kit.group("Floors")
	local routes = kit.group("Routes")
	local details = kit.group("Architecture")
	local AX, AZ = Layout.Atrium.x, Layout.Atrium.z
	local SX, SZ = Layout.Service.x, Layout.Service.z
	local RX, RZ = Layout.Ring.x, Layout.Ring.z
	local Y2 = Layout.FloorY[2]

	-- Foundation: the whole ground floor is one marble slab; carpets and lanes are inlays.
	kit.box(floors, "GroundSlab", 0, -1.5, 0, SX * 2, 3, SZ * 2, P.stone, Enum.Material.Marble, true)
	kit.box(floors, "OutsideLot", 0, -3.2, 0, 900, 4, 900, Color3.fromRGB(120, 126, 142), Enum.Material.Asphalt, true)

	-- Holes through the second-floor deck: the atrium void plus the head of every ramp/stair.
	local holes = {Layout.Rect(-AX, AX, -AZ, AZ)}
	local ramps = {}
	local half = Layout.EscalatorWidth / 2 + 0.5
	for _, e in ipairs(Layout.Escalators) do
		local a, b = e.from, e.to
		local dir = (b - a).Unit
		local headStart = a + (b - a) * 0.6
		local lo = Vector2.new(math.min(headStart.X, b.X), math.min(headStart.Y, b.Y))
		local hi = Vector2.new(math.max(headStart.X, b.X), math.max(headStart.Y, b.Y))
		if math.abs(dir.X) > 0.5 then
			table.insert(holes, Layout.Rect(lo.X, hi.X, a.Y - half, a.Y + half))
		else
			table.insert(holes, Layout.Rect(a.X - half, a.X + half, lo.Y, hi.Y))
		end
		table.insert(ramps, e)
	end
	-- Corner ladders connect the back-of-house corridors of both floors (a vertical shortcut).
	local ladders = {
		{x = SX - 1.5, z = SZ - 1.5, dir = -1}, {x = -SX + 1.5, z = SZ - 1.5, dir = 1},
		{x = SX - 1.5, z = -SZ + 1.5, dir = -1}, {x = -SX + 1.5, z = -SZ + 1.5, dir = 1},
	}
	for _, l in ipairs(ladders) do
		table.insert(holes, Layout.Rect(math.min(l.x, l.x - l.dir * 2.5) - 0.5, math.max(l.x, l.x - l.dir * 2.5) + 0.5, l.z - 1.5, l.z + 1.5))
	end
	local slabBase = Layout.Rect(-SX, SX, -SZ, SZ)
	for _, r in ipairs(Layout.Subtract(slabBase, holes)) do
		kit.span(structure, "UpperDeck", r.x0, r.x1, Layout.SlabBottom, Layout.SlabTop, r.z0, r.z1, P.stone, Enum.Material.Marble, true)
	end

	-- Roof with skylight strips; the atrium gets a tall glass clerestory and roof.
	local skylights = {
		Layout.Rect(-80, 80, 70, 80), Layout.Rect(-80, 80, -80, -70),
		Layout.Rect(70, 80, -60, 60), Layout.Rect(-80, -70, -60, 60),
	}
	local roofHoles = {Layout.Rect(-AX, AX, -AZ, AZ)}
	for _, r in ipairs(skylights) do table.insert(roofHoles, r) end
	for _, r in ipairs(Layout.Subtract(Layout.Rect(-SX - 1.5, SX + 1.5, -SZ - 1.5, SZ + 1.5), roofHoles)) do
		kit.span(structure, "Roof", r.x0, r.x1, Layout.RoofBottom, Layout.RoofTop, r.z0, r.z1, P.cream, Enum.Material.Concrete, true)
	end
	for _, r in ipairs(skylights) do
		kit.span(structure, "Skylight", r.x0, r.x1, Layout.RoofBottom + 0.4, Layout.RoofBottom + 0.7, r.z0, r.z1, P.glass, Enum.Material.Glass, true, {transparency = 0.6, shadow = false})
		for x = r.x0 + 10, r.x1 - 1, 20 do
			if r.x1 - r.x0 > 30 then kit.span(structure, "SkylightBeam", x - 0.4, x + 0.4, Layout.RoofBottom, Layout.RoofBottom + 1, r.z0, r.z1, P.white, Enum.Material.Metal, false) end
		end
	end
	local topY = Layout.AtriumRoofY
	kit.span(structure, "AtriumRoofGlass", -AX - 1, AX + 1, topY, topY + 0.5, -AZ - 1, AZ + 1, P.glass, Enum.Material.Glass, true, {transparency = 0.55, shadow = false})
	for _, sign in ipairs({-1, 1}) do
		kit.span(structure, "ClerestoryGlassX", sign * AX - 0.3, sign * AX + 0.3, Layout.RoofTop, topY, -AZ, AZ, P.glass, Enum.Material.Glass, true, {transparency = 0.6, shadow = false})
		kit.span(structure, "ClerestoryGlassZ", -AX, AX, Layout.RoofTop, topY, sign * AZ - 0.3, sign * AZ + 0.3, P.glass, Enum.Material.Glass, true, {transparency = 0.6, shadow = false})
	end
	for x = -AX, AX, AX / 2.5 do
		kit.span(structure, "AtriumRib", x - 0.6, x + 0.6, Layout.RoofTop, topY + 0.8, -AZ - 1, AZ + 1, P.white, Enum.Material.Metal, false)
	end
	for z = -AZ, AZ, AZ / 2 do
		kit.span(structure, "AtriumPurlin", -AX - 1, AX + 1, topY - 0.2, topY + 0.8, z - 0.5, z + 0.5, P.white, Enum.Material.Metal, false)
	end

	-- Exterior shell walls, both floors, with a coloured band so facades read from the lobby.
	local T = 1.5
	local function shellWall(name, x0, x1, z0, z1)
		kit.span(structure, name, x0, x1, -1, Layout.RoofTop, z0, z1, P.cream, Enum.Material.Concrete, true)
	end
	shellWall("ShellWest", -SX - T, -SX, -SZ - T, SZ + T)
	shellWall("ShellEast", SX, SX + T, -SZ - T, SZ + T)
	shellWall("ShellSouth", -SX, SX, -SZ - T, -SZ)
	shellWall("ShellNorth", -SX, SX, SZ, SZ + T)

	-- Colour bands and window pretend-glass on the exterior and service-corridor faces.
	for _, level in ipairs({1, 2}) do
		local y = Layout.FloorY[level]
		for _, z in ipairs({-SZ, SZ}) do
			local s = z > 0 and 1 or -1
			for x = -SX + 20, SX - 20, 26 do
				kit.box(details, "ShellWindow", x, y + 11, z + s * (T + 0.1), 16, 8, 0.2, P.sky, Enum.Material.Glass, false, {transparency = 0.3})
				kit.box(details, "ShellWindowInside", x, y + 11, z - s * 0.1, 16, 8, 0.2, P.sky, Enum.Material.Glass, false, {transparency = 0.3})
			end
		end
		for _, x in ipairs({-SX, SX}) do
			local s = x > 0 and 1 or -1
			for z = -SZ + 20, SZ - 20, 26 do
				kit.box(details, "ShellWindow", x + s * (T + 0.1), y + 11, z, 0.2, 8, 16, P.sky, Enum.Material.Glass, false, {transparency = 0.3})
				kit.box(details, "ShellWindowInside", x - s * 0.1, y + 11, z, 0.2, 8, 16, P.sky, Enum.Material.Glass, false, {transparency = 0.3})
			end
		end
	end

	-- Ramps ("escalators"). Solid skirt panels close the space beneath so there is no hiding nook.
	for _, e in ipairs(ramps) do
		local a3 = Vector3.new(e.from.X, 0, e.from.Y)
		local b3 = Vector3.new(e.to.X, Y2, e.to.Y)
		local width = Layout.EscalatorWidth
		local cf = CFrame.lookAt((a3 + b3) / 2, b3)
		local length = (b3 - a3).Magnitude
		local deck = kit.part(routes, "Escalator_" .. e.id, Vector3.new(width, 1, length), cf * CFrame.new(0, -0.5, 0), P.steel, Enum.Material.Metal, true, {attrs = {TraversalRoute = true}})
		deck:SetAttribute("TraversalRoute", true)
		-- Treads: thin ridges, visual only.
		for i = 1, math.floor(length / 2.2) do
			kit.part(routes, "Tread", Vector3.new(width - 0.6, 0.12, 0.25), cf * CFrame.new(0, 0.07, -length / 2 + i * 2.2), P.dark, Enum.Material.SmoothPlastic, false)
		end
		local dir = (b3 - a3) * Vector3.new(1, 0, 1)
		local dirUnit = dir.Unit
		local mid = (a3 + b3) / 2
		for _, side in ipairs({-1, 1}) do
			local right = Vector3.new(-dirUnit.Z, 0, dirUnit.X) * side * (width / 2 + 0.3)
			local wedgeCF = CFrame.lookAt(Vector3.new(mid.X + right.X, Y2 / 2, mid.Z + right.Z), Vector3.new(mid.X + right.X - dirUnit.X, Y2 / 2, mid.Z + right.Z - dirUnit.Z))
			kit.part(routes, "EscalatorSkirt", Vector3.new(0.6, Y2, dir.Magnitude), wedgeCF, P.white, Enum.Material.SmoothPlastic, true, {shape = "Wedge"})
			-- Handrail above the skirt, following the slope.
			local railA = a3 + right + Vector3.new(0, 3.2, 0)
			local railB = b3 + right + Vector3.new(0, 3.2, 0)
			kit.beam(routes, "EscalatorHandrail", railA, railB, 0.4, e.id:find("A") and P.teal or P.coral, Enum.Material.Metal, false)
		end
		local frontPoint = a3 + (b3 - a3) * 0.24
		kit.part(routes, "EscalatorFront", Vector3.new(width + 1.4, 5.8, 0.6), CFrame.lookAt(Vector3.new(frontPoint.X, 2.9, frontPoint.Z), Vector3.new(frontPoint.X + dirUnit.X, 2.9, frontPoint.Z + dirUnit.Z)), P.white, Enum.Material.SmoothPlastic, true)
		-- Guard on the open edges of the deck hole so nobody falls into the notch.
		local headStart = a3 + (b3 - a3) * 0.6
		for _, side in ipairs({-1, 1}) do
			local right = Vector3.new(-dirUnit.Z, 0, dirUnit.X) * side * (width / 2 + 0.6)
			railing(kit, routes, Vector2.new(headStart.X + right.X, headStart.Z + right.Z), Vector2.new(b3.X + right.X, b3.Z + right.Z), Y2, e.id:find("A") and P.teal or P.coral, 3.4)
		end
	end

	-- Grand staircases rise inside the atrium void to the balcony; a wide, readable climb.
	local grand = {
		{from = Vector2.new(-17, 20), to = Vector2.new(-17, AZ), color = P.coral},
		{from = Vector2.new(17, -20), to = Vector2.new(17, -AZ), color = P.teal},
		{from = Vector2.new(22, 17), to = Vector2.new(AX, 17), color = P.sun},
		{from = Vector2.new(-22, -17), to = Vector2.new(-AX, -17), color = P.violet},
	}
	for i, g in ipairs(grand) do
		stairs(kit, routes, "GrandStair" .. i, g.from, g.to, 14, Y2, P.white, 0)
		local dir = (g.to - g.from).Unit
		local perp = Vector2.new(-dir.Y, dir.X)
		for _, side in ipairs({-1, 1}) do
			local a = g.from + perp * side * 7.3
			local b = g.to + perp * side * 7.3
			kit.beam(routes, "StairBanister", Vector3.new(a.X, 3.2, a.Y), Vector3.new(b.X, Y2 + 3.2, b.Y), 0.5, g.color, Enum.Material.Metal, false)
			kit.beam(routes, "StairNeon", Vector3.new(a.X, 0.3, a.Y), Vector3.new(b.X, Y2 + 0.3, b.Y), 0.25, g.color, Enum.Material.Neon, false)
		end
	end
	-- Ladders: climbable trusses through a deck opening; each is a deliberate risk/reward shortcut.
	kit.ladders = {}
	for i, l in ipairs(ladders) do
		local truss = Instance.new("TrussPart")
		truss.Name = "ServiceLadder"
		truss.Size = Vector3.new(2, Y2 + 3, 2)
		truss.CFrame = CFrame.new(l.x, (Y2 + 3) / 2, l.z)
		truss.Color = P.orange
		truss.Material = Enum.Material.Metal
		truss.Anchored = true
		truss.CanTouch = false
		truss.Parent = routes
		kit.count += 1
		kit.box(routes, "LadderSign", l.x + l.dir * -0.1, 8, l.z - (l.z > 0 and 2 or -2), 0.2, 0.2, 0.2, P.sun, Enum.Material.Neon, false)
		local standX = l.x + l.dir * 3.2
		table.insert(kit.ladders, {base = Vector3.new(standX, 0, l.z), top = Vector3.new(standX, Y2, l.z)})
	end
	-- Two skybridges cross the void; the second is split around the crossing.
	local function bridge(name, x0, x1, z0, z1)
		kit.span(routes, name, x0, x1, Y2 - 1.5, Y2, z0, z1, P.white, Enum.Material.Marble, true, {attrs = {TraversalRoute = true}})
		kit.span(routes, name .. "Underglow", x0 + 0.5, x1 - 0.5, Y2 - 1.6, Y2 - 1.45, z0 + 0.5, z1 - 0.5, P.sky, Enum.Material.Neon, false)
	end
	bridge("SkybridgeEW", -AX, AX, -7, 7)
	bridge("SkybridgeNS_S", -7, 7, -AZ, -7)
	bridge("SkybridgeNS_N", -7, 7, 7, AZ)
	for _, side in ipairs({-1, 1}) do
		railing(kit, routes, Vector2.new(-AX, side * 7), Vector2.new(-7, side * 7), Y2, P.sky, 3.6)
		railing(kit, routes, Vector2.new(7, side * 7), Vector2.new(AX, side * 7), Y2, P.sky, 3.6)
		railing(kit, routes, Vector2.new(side * 7, -AZ), Vector2.new(side * 7, -7), Y2, P.sky, 3.6)
		railing(kit, routes, Vector2.new(side * 7, 7), Vector2.new(side * 7, AZ), Y2, P.sky, 3.6)
	end

	-- Balcony railing around the void. Openings: grand-stair landings, skybridge landings, and
	-- deliberate drop gaps (vertical escapes with yellow marker posts).
	local openings = {
		N = {{-24, -10, "stair"}, {-7, 7, "bridge"}},
		S = {{10, 24, "stair"}, {-7, 7, "bridge"}},
		E = {{10, 24, "stair"}, {-7, 7, "bridge"}},
		W = {{-24, -10, "stair"}, {-7, 7, "bridge"}},
	}
	for _, g in ipairs(Layout.DropGaps) do
		table.insert(openings[g.edge], {g.at - Layout.DropGapWidth / 2, g.at + Layout.DropGapWidth / 2, "drop"})
	end
	local function edgeRailing(edge, from, to, fixed, horizontal)
		local list = openings[edge]
		table.sort(list, function(a, b) return a[1] < b[1] end)
		local function rail(a, b)
			if b - a < 0.8 then return end
			if horizontal then railing(kit, routes, Vector2.new(a, fixed), Vector2.new(b, fixed), Y2, P.coral, 3.6)
			else railing(kit, routes, Vector2.new(fixed, a), Vector2.new(fixed, b), Y2, P.coral, 3.6) end
		end
		local cursor = from
		for _, o in ipairs(list) do
			rail(cursor, o[1])
			cursor = o[2]
			if o[3] == "drop" then
				for _, at in ipairs({o[1], o[2]}) do
					if horizontal then kit.box(routes, "DropPost", at, Y2 + 2, fixed, 0.8, 4, 0.8, P.sun, Enum.Material.Metal, false)
					else kit.box(routes, "DropPost", fixed, Y2 + 2, at, 0.8, 4, 0.8, P.sun, Enum.Material.Metal, false) end
				end
				local mid = (o[1] + o[2]) / 2
				if horizontal then kit.box(routes, "DropStrip", mid, Y2 + 0.05, fixed, o[2] - o[1], 0.1, 1.2, P.sun, Enum.Material.Neon, false)
				else kit.box(routes, "DropStrip", fixed, Y2 + 0.05, mid, 1.2, 0.1, o[2] - o[1], P.sun, Enum.Material.Neon, false) end
			end
		end
		rail(cursor, to)
	end
	edgeRailing("N", -AX, AX, AZ, true)
	edgeRailing("S", -AX, AX, -AZ, true)
	edgeRailing("E", -AZ, AZ, AX, false)
	edgeRailing("W", -AZ, AZ, -AX, false)

	-- Columns around the atrium on both floors: sturdy partial cover with colour bands.
	local colors = {P.coral, P.teal, P.sun, P.violet}
	local index = 0
	local function nearRamp(x, z)
		for _, e in ipairs(ramps) do
			local x0, x1 = math.min(e.from.X, e.to.X) - 7, math.max(e.from.X, e.to.X) + 7
			local z0, z1 = math.min(e.from.Y, e.to.Y) - 7, math.max(e.from.Y, e.to.Y) + 7
			if x >= x0 and x <= x1 and z >= z0 and z <= z1 then return true end
		end
		return false
	end
	local function column(x, z)
		if nearRamp(x, z) then return end
		index += 1
		local color = colors[(index % #colors) + 1]
		for _, level in ipairs({1, 2}) do
			local y = Layout.FloorY[level]
			kit.can(structure, "Column", x, y + 11, z, 3, 22, P.white, Enum.Material.Marble, true, {cover = "Full"})
			kit.can(details, "ColumnBand", x, y + 4, z, 3.4, 1.2, color, Enum.Material.SmoothPlastic, false)
			kit.can(details, "ColumnCollar", x, y + 21, z, 3.6, 1, color, Enum.Material.SmoothPlastic, false)
		end
	end
	for _, z in ipairs({-45, -22, 22, 45}) do column(-AX - 6, z) column(AX + 6, z) end
	for _, x in ipairs({-42, -22, 22, 42}) do column(x, -AZ - 6) column(x, AZ + 6) end

	-- Ceiling light strips under the deck and roof, bright warm white.
	for _, level in ipairs({1, 2}) do
		local ceiling = level == 1 and Layout.SlabBottom or Layout.RoofBottom
		local rows = level == 1 and {66, 76, 86} or {64, 86}
		for _, z in ipairs(rows) do
			kit.span(details, "CeilingStrip", -82, 82, ceiling - 0.25, ceiling, z - 0.4, z + 0.4, P.white, Enum.Material.Neon, false)
			kit.span(details, "CeilingStrip", -82, 82, ceiling - 0.25, ceiling, -z - 0.4, -z + 0.4, P.white, Enum.Material.Neon, false)
		end
		local cols = level == 1 and {62, 72, 82} or {64, 84}
		for _, x in ipairs(cols) do
			kit.span(details, "CeilingStrip", x - 0.4, x + 0.4, ceiling - 0.25, ceiling, -58, 58, P.white, Enum.Material.Neon, false)
			kit.span(details, "CeilingStrip", -x - 0.4, -x + 0.4, ceiling - 0.25, ceiling, -58, 58, P.white, Enum.Material.Neon, false)
		end
	end
	return {ramps = ramps, grand = grand}
end

return Shell
