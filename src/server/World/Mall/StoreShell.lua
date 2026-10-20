-- Builds the walls, entrance, signage, floor and lighting of one store or zone on one floor.
-- Walls are generated in world space from the slot rectangle, so neighbouring stores get
-- matching door openings and nothing overlaps. Interiors are built by `def.build(ctx)`.
local StoreShell = {}

local DOOR_W, DOOR_H = 9, 11
local SERVICE_W, SERVICE_H = 8, 11

-- Wall run along one axis with rectangular openings. Segments above openings become headers.
local function wallRun(kit, parent, axis, fixedLo, fixedHi, from, to, y0, height, openings, color, material, windows)
	table.sort(openings, function(a, b) return a.center < b.center end)
	local function piece(a, b, yLo, yHi, name, pieceColor, pieceMaterial, collide, opts)
		if b - a < 0.05 or yHi - yLo < 0.05 then return end
		if axis == "x" then
			return kit.span(parent, name, a, b, y0 + yLo, y0 + yHi, fixedLo, fixedHi, pieceColor or color, pieceMaterial or material, collide ~= false, opts)
		end
		return kit.span(parent, name, fixedLo, fixedHi, y0 + yLo, y0 + yHi, a, b, pieceColor or color, pieceMaterial or material, collide ~= false, opts)
	end
	local function solid(a, b)
		if not windows then piece(a, b, 0, height, "Wall") return end
		-- Shopfront: knee wall, display glass, sign band. Glass blocks movement and tagging but not sight.
		local va, vb = math.max(a, windows.from), math.min(b, windows.to)
		if vb - va < 6 then piece(a, b, 0, height, "Wall") return end
		piece(a, va, 0, height, "Wall")
		piece(vb, b, 0, height, "Wall")
		piece(va, vb, 0, 3.5, "KneeWall", windows.knee, nil)
		piece(va, vb, 3.5, 12, "ShopGlass", kit.P.glass, Enum.Material.Glass, true, {transparency = 0.5, shadow = false})
		piece(va, vb, 12, height, "SignBand", color)
		local mullions = math.max(1, math.floor((vb - va) / 10))
		for i = 0, mullions do
			local at = va + (vb - va) * i / mullions
			piece(at - 0.3, at + 0.3, 3.5, 12, "Mullion", windows.accent, Enum.Material.Metal, false)
		end
	end
	local cursor = from
	for _, o in ipairs(openings) do
		local a, b = o.center - o.width / 2, o.center + o.width / 2
		solid(cursor, a)
		piece(a, b, o.height, height, "Header", color)
		cursor = b
	end
	solid(cursor, to)
end

local function alongCoordinate(edge, point)
	if edge == "zMin" or edge == "zMax" then return point.X end
	return point.Z
end

function StoreShell.build(kit, Layout, slot, floor, def, storesFolder, peers)
	local P = kit.P
	local y0 = Layout.FloorY[floor]
	local H = Layout.StoreHeight
	local T = Layout.WallThickness
	local model = Instance.new("Model")
	model.Name = "Store_" .. (def.name:gsub("[^%w]", ""))
	model.Parent = storesFolder
	model:SetAttribute("StoreName", def.name)
	model:SetAttribute("Floor", floor)
	model:SetAttribute("SlotId", slot.id)
	model:SetAttribute("Kind", def.kind or "Store")

	-- Art direction: each shop gets its own bold colors, awning and icon (see Style.lua).
	local theme = kit.style and kit.style.themeFor(def.name)
	local trim = theme and theme.trim or def.accent
	if theme then
		def.wall, def.carpet, def.floorMaterial, def.light = theme.wall, theme.floor, theme.mat, theme.light
	end

	local frontEdge = ({N = "zMin", S = "zMax", E = "xMin", W = "xMax"})[slot.side]
	local backEdge = ({zMin = "zMax", zMax = "zMin", xMin = "xMax", xMax = "xMin"})[frontEdge]
	local openings = {zMin = {}, zMax = {}, xMin = {}, xMax = {}}

	local frame = kit.frame(model, slot.front, slot.yaw, y0)
	local ctx = {kit = kit, P = P, f = frame, parent = model, W = slot.width, D = slot.depth, floor = floor,
		name = def.name, slot = slot, y0 = y0, H = H, accent = def.accent}
	function ctx.sub(lx, lz, yawDeg, parentOverride)
		return kit.frame(parentOverride or model, frame.pos(lx, 0, lz), slot.yaw + math.rad(yawDeg or 0), y0)
	end

	-- Entrance (front wall).
	local entranceWorld = frame.pos(slot.entranceX, 0, 0)
	table.insert(openings[frontEdge], {center = alongCoordinate(frontEdge, entranceWorld), width = def.entranceWidth or slot.entranceWidth, height = Layout.EntranceHeight})
	-- Service doors in the back wall (local x offsets), leading to the back-of-house corridor.
	for _, lx in ipairs(def.serviceDoors or {-slot.width / 4}) do
		local world = frame.pos(lx, 0, slot.depth)
		table.insert(openings[backEdge], {center = alongCoordinate(backEdge, world), width = SERVICE_W, height = SERVICE_H})
	end
	-- Doors to every neighbouring store on this floor, so routes loop through interiors.
	local sealed = {}
	for _, edge in ipairs(def.sealed or {}) do sealed[edge] = true end
	for _, other in ipairs(Layout.Slots) do
		if other ~= slot then
			local function door(edge, lo, hi)
				if sealed[edge] or hi - lo < 14 then return end
				local peer = peers and peers[other.id]
				if def.wideDoor and peer and peer.wideDoor then
					table.insert(openings[edge], {center = (lo + hi) / 2, width = hi - lo - 10, height = 15})
				else
					table.insert(openings[edge], {center = (lo + hi) / 2, width = DOOR_W, height = DOOR_H})
				end
			end
			local zLo, zHi = math.max(slot.z0, other.z0), math.min(slot.z1, other.z1)
			local xLo, xHi = math.max(slot.x0, other.x0), math.min(slot.x1, other.x1)
			if slot.x1 == other.x0 and zHi > zLo then door("xMax", zLo, zHi)
			elseif slot.x0 == other.x1 and zHi > zLo then door("xMin", zLo, zHi)
			elseif slot.z1 == other.z0 and xHi > xLo then door("zMax", xLo, xHi)
			elseif slot.z0 == other.z1 and xHi > xLo then door("zMin", xLo, xHi) end
		end
	end
	-- Door registry for clearance tests and navigation checks (world-space centre at floor level).
	for edge, list in pairs(openings) do
		for _, o in ipairs(list) do
			local center
			if edge == "zMin" then center = Vector3.new(o.center, y0, slot.z0 + T / 2)
			elseif edge == "zMax" then center = Vector3.new(o.center, y0, slot.z1 - T / 2)
			elseif edge == "xMin" then center = Vector3.new(slot.x0 + T / 2, y0, o.center)
			else center = Vector3.new(slot.x1 - T / 2, y0, o.center) end
			table.insert(kit.doors, {store = def.name, edge = edge, center = center, width = o.width, height = o.height, floor = floor})
		end
	end
	local wallColor = def.wall or P.cream
	local wallMaterial = Enum.Material.SmoothPlastic
	-- Visible shopfront range (the part of the front wall that faces the public corridor).
	local windows
	do
		local from, to
		if slot.side == "N" or slot.side == "S" then from, to = math.max(slot.x0, -Layout.Ring.x), math.min(slot.x1, Layout.Ring.x)
		else from, to = slot.z0, slot.z1 end
		windows = {from = from, to = to, knee = def.accent, accent = def.accent}
	end
	local function run(edge)
		local isFront = edge == frontEdge
		if edge == "zMin" then wallRun(kit, model, "x", slot.z0, slot.z0 + T, slot.x0, slot.x1, y0, H, openings[edge], wallColor, wallMaterial, isFront and windows)
		elseif edge == "zMax" then wallRun(kit, model, "x", slot.z1 - T, slot.z1, slot.x0, slot.x1, y0, H, openings[edge], wallColor, wallMaterial, isFront and windows)
		elseif edge == "xMin" then wallRun(kit, model, "z", slot.x0, slot.x0 + T, slot.z0, slot.z1, y0, H, openings[edge], wallColor, wallMaterial, isFront and windows)
		else wallRun(kit, model, "z", slot.x1 - T, slot.x1, slot.z0, slot.z1, y0, H, openings[edge], wallColor, wallMaterial, isFront and windows) end
	end
	for _, edge in ipairs({"zMin", "zMax", "xMin", "xMax"}) do run(edge) end

	-- Floor: coloured carpet inlay with a guiding stripe from the entrance.
	local W, D = slot.width, slot.depth
	frame.b("Carpet", 0, 0.03, D / 2, W - 2 * T - 0.4, 0.05, D - 2 * T - 0.4, def.carpet or P.blush, def.floorMaterial or Enum.Material.Fabric, false)
	frame.b("EntranceStripe", slot.entranceX, 0.09, D * 0.25, 5, 0.05, D * 0.5, def.accent, Enum.Material.SmoothPlastic, false)
	frame.b("Threshold", slot.entranceX, 0.1, 0.5, (def.entranceWidth or slot.entranceWidth) - 1, 0.05, 1.2, trim, Enum.Material.SmoothPlastic, false)

	-- Door frames and the big sign. The sign plate faces the corridor (local -Z).
	local ew = def.entranceWidth or slot.entranceWidth
	for _, s in ipairs({-1, 1}) do
		frame.b("DoorPost", slot.entranceX + s * (ew / 2 + 0.4), 0, -0.4, 1.2, Layout.EntranceHeight, 1.6, trim, Enum.Material.SmoothPlastic, false)
	end
	frame.b("DoorLintel", slot.entranceX, Layout.EntranceHeight, -0.4, ew + 2.4, 1.0, 1.6, trim, Enum.Material.SmoothPlastic, false)
	local signWidth = math.min(36, ew + 12)
	frame.sign(def.name, slot.entranceX, 15, -0.3, signWidth, 5, P.white, def.accent, false, {material = Enum.Material.SmoothPlastic, stroke = P.ink})
	frame.b("SignTrimTop", slot.entranceX, 20.2, -0.3, signWidth, 0.4, 0.4, trim, Enum.Material.SmoothPlastic, false)
	frame.b("SignTrimBottom", slot.entranceX, 14.7, -0.3, signWidth, 0.4, 0.4, trim, Enum.Material.SmoothPlastic, false)
	if def.tagline then
		frame.sign(def.tagline, slot.entranceX, 12.4, -0.3, signWidth * 0.7, 1.9, def.accent, P.white, false, {pixels = 24})
	end

	-- Ceiling: two warm lights, each under a colored pendant shade (no glowing panels).
	local lampTint = def.light or P.white
	for _, lx in ipairs({-W / 4, W / 4}) do
		frame.b("PendantStem", lx, H - 4.2, D * 0.5, 0.2, 2.8, 0.2, P.dark, Enum.Material.Metal, false)
		frame.ball("PendantShade", lx, H - 5.8, D * 0.5, 3.2, 2.2, 3.2, trim, Enum.Material.SmoothPlastic, false)
		frame.lamp(lx, H - 1.5, D * 0.5, lampTint, 0.8, 38)
	end

	-- Interior trim: baseboard, cornice and one painted band around the three inside walls.
	local inner = T + 0.15
	for _, spec in ipairs({
		{"Back", 0, D - inner, W - 2 * T, 0.3, true},
		{"West", -W / 2 + inner, D / 2, 0.3, D - 2 * T, false},
		{"East", W / 2 - inner, D / 2, 0.3, D - 2 * T, false},
	}) do
		local lenX = spec[6] and (W - 2 * T) or 0.3
		local lenZ = spec[6] and 0.3 or (D - 2 * T)
		frame.b("Baseboard" .. spec[1], spec[2], 0, spec[3], lenX, 0.9, lenZ, trim, Enum.Material.SmoothPlastic, false)
		frame.b("Cornice" .. spec[1], spec[2], H - 1.2, spec[3], lenX, 1.0, lenZ, trim, Enum.Material.SmoothPlastic, false)
		frame.b("Band" .. spec[1], spec[2], 7.2, spec[3], lenX, 1.3, lenZ, def.accent, Enum.Material.SmoothPlastic, false)
	end

	-- Storefront dressing: a striped awning over the display windows and a projecting blade sign with the
	-- shop's icon, readable from along the corridor.
	local awning = math.min(W - 6, ew + 14)
	local stripeA, stripeB = def.accent, P.white
	if theme then stripeA, stripeB = theme.awning[1], theme.awning[2] end
	frame.t("AwningBase", slot.entranceX, 12.4, -1.7, awning, 0.35, 3.6, -18, 0, 0, stripeA, Enum.Material.Fabric, false)
	local stripe = 5
	for i = 0, math.floor(awning / stripe) - 1 do
		if i % 2 == 1 then
			frame.t("AwningStripe", slot.entranceX - awning / 2 + stripe * (i + 0.5), 12.45, -1.7, stripe, 0.4, 3.62, -18, 0, 0, stripeB, Enum.Material.Fabric, false)
		end
	end
	local bladeX = slot.entranceX - awning / 2 - 3.4
	if bladeX < -W / 2 + 4 then bladeX = slot.entranceX + awning / 2 + 3.4 end
	frame.b("BladeArm", bladeX, 18.6, -1.6, 0.35, 0.35, 3.2, P.dark, Enum.Material.Metal, false)
	for _, face in ipairs({{-1, 90}, {1, -90}}) do
		local cf = frame.cf(bladeX + face[1] * 0.3, 15.4, -3.4, 0, face[2], 0)
		kit.sign(model, theme and theme.icon or "⭐", cf, 5.2, 5.2, P.white, def.accent, {pixels = 40, distance = 160, noStroke = true})
	end

	if def.build then def.build(ctx) end
	return ctx
end

return StoreShell
