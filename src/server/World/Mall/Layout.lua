-- Shared constants for the mall: every module reads the same numbers so floors, walls,
-- stores, hiding spots and spawns always agree. All units are studs; X east, Z north.
local Layout = {}

Layout.FloorY = {[1] = 0, [2] = 24}      -- walking surface of each floor
Layout.SlabBottom, Layout.SlabTop = 22, 24 -- first-floor ceiling / second-floor deck
Layout.RoofBottom, Layout.RoofTop = 46, 48
Layout.AtriumRoofY = 64
Layout.StoreHeight = 22                  -- clear height of every level (floor to ceiling)

Layout.Atrium = {x = 55, z = 60}         -- half extents of the open atrium void
Layout.Ring = {x = 85, z = 90}           -- outer half extents of the public ring corridor
Layout.Stores = {x = 150, z = 140}       -- outer half extents of the store zone
Layout.Service = {x = 162, z = 152}      -- outer half extents of the back-of-house ring (and shell)
Layout.ServiceWidth = 12

Layout.WallThickness = 1
Layout.EntranceHeight = 14
Layout.Bounds = {min = Vector3.new(-175, -12, -165), max = Vector3.new(175, 75, 165)}

-- Store slots. Index runs west->east (N,S) or north->south (E,W). `origin` is the centre of the
-- front wall at floor level and `yaw` turns local +Z (into the store) toward the interior.
local function slot(id, side, rect, entrance)
	return {id = id, side = side, x0 = rect[1], x1 = rect[2], z0 = rect[3], z1 = rect[4], entrance = entrance}
end
Layout.Slots = {
	slot("N1", "N", {-150, -50, 90, 140}, Vector3.new(-67.5, 0, 90)),
	slot("N2", "N", {-50, 50, 90, 140}, Vector3.new(0, 0, 90)),
	slot("N3", "N", {50, 150, 90, 140}, Vector3.new(67.5, 0, 90)),
	slot("S1", "S", {-150, -50, -140, -90}, Vector3.new(-67.5, 0, -90)),
	slot("S2", "S", {-50, 50, -140, -90}, Vector3.new(0, 0, -90)),
	slot("S3", "S", {50, 150, -140, -90}, Vector3.new(67.5, 0, -90)),
	slot("E1", "E", {85, 150, 30, 90}, Vector3.new(85, 0, 60)),
	slot("E2", "E", {85, 150, -30, 30}, Vector3.new(85, 0, 0)),
	slot("E3", "E", {85, 150, -90, -30}, Vector3.new(85, 0, -60)),
	slot("W1", "W", {-150, -85, 30, 90}, Vector3.new(-85, 0, 60)),
	slot("W2", "W", {-150, -85, -30, 30}, Vector3.new(-85, 0, 0)),
	slot("W3", "W", {-150, -85, -90, -30}, Vector3.new(-85, 0, -60)),
}
Layout.SlotById = {}
local YAW = {N = 0, S = math.pi, E = math.pi / 2, W = -math.pi / 2}
for _, s in ipairs(Layout.Slots) do
	Layout.SlotById[s.id] = s
	s.yaw = YAW[s.side]
	s.center = Vector3.new((s.x0 + s.x1) / 2, 0, (s.z0 + s.z1) / 2)
	-- Width runs along the entrance wall, depth into the store.
	if s.side == "N" or s.side == "S" then s.width, s.depth = s.x1 - s.x0, s.z1 - s.z0
	else s.width, s.depth = s.z1 - s.z0, s.x1 - s.x0 end
	local front
	if s.side == "N" then front = Vector3.new(s.center.X, 0, s.z0)
	elseif s.side == "S" then front = Vector3.new(s.center.X, 0, s.z1)
	elseif s.side == "E" then front = Vector3.new(s.x0, 0, s.center.Z)
	else front = Vector3.new(s.x1, 0, s.center.Z) end
	s.front = front
	local frame = CFrame.new(front) * CFrame.Angles(0, s.yaw, 0)
	s.entranceX = frame:PointToObjectSpace(s.entrance).X
	s.entranceWidth = (s.id == "N2" or s.id == "S2") and 40 or (s.width > 80 and 30 or 28)
end

-- Scenic rectangles that must stay free of obstacles on level one (drop landings, ramps).
Layout.Escalators = {
	-- Each ramp: base (L1) and top (L2) in plan view. Pairs run opposite directions and sit in the
	-- 30-stud gaps between storefront entrances so they never block a shop door.
	{id = "NA", from = Vector2.new(-51, 76), to = Vector2.new(-21, 76)},
	{id = "NB", from = Vector2.new(-21, 66), to = Vector2.new(-51, 66)},
	{id = "SA", from = Vector2.new(51, -76), to = Vector2.new(21, -76)},
	{id = "SB", from = Vector2.new(21, -66), to = Vector2.new(51, -66)},
	{id = "EA", from = Vector2.new(74, 16), to = Vector2.new(74, 45)},
	{id = "EB", from = Vector2.new(64, 45), to = Vector2.new(64, 16)},
	{id = "WA", from = Vector2.new(-74, -16), to = Vector2.new(-74, -45)},
	{id = "WB", from = Vector2.new(-64, -45), to = Vector2.new(-64, -16)},
}
Layout.EscalatorWidth = 8
Layout.DropGaps = {
	{edge = "N", at = 21}, {edge = "N", at = 43}, {edge = "S", at = -21}, {edge = "S", at = -43},
	{edge = "E", at = -35}, {edge = "E", at = 35}, {edge = "W", at = -35}, {edge = "W", at = 35},
}
Layout.DropGapWidth = 10

function Layout.Rect(x0, x1, z0, z1) return {x0 = x0, x1 = x1, z0 = z0, z1 = z1} end
-- Subtract hole rectangles from a base rectangle, returning the remaining axis-aligned pieces.
function Layout.Subtract(base, holes)
	local pieces = {base}
	for _, hole in ipairs(holes) do
		local nextPieces = {}
		for _, r in ipairs(pieces) do
			if hole.x1 <= r.x0 or hole.x0 >= r.x1 or hole.z1 <= r.z0 or hole.z0 >= r.z1 then
				table.insert(nextPieces, r)
			else
				if hole.z0 > r.z0 then table.insert(nextPieces, Layout.Rect(r.x0, r.x1, r.z0, hole.z0)) end
				if hole.z1 < r.z1 then table.insert(nextPieces, Layout.Rect(r.x0, r.x1, hole.z1, r.z1)) end
				local z0, z1 = math.max(r.z0, hole.z0), math.min(r.z1, hole.z1)
				if hole.x0 > r.x0 then table.insert(nextPieces, Layout.Rect(r.x0, hole.x0, z0, z1)) end
				if hole.x1 < r.x1 then table.insert(nextPieces, Layout.Rect(hole.x1, r.x1, z0, z1)) end
			end
		end
		pieces = nextPieces
	end
	return pieces
end

return Layout
