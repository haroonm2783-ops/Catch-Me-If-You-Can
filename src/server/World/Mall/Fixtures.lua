-- Reusable interior fixtures. Every function works in a store-local frame (`ctx.f`):
-- local +Z runs from the front wall into the store, local X across it, bottoms sit at y0.
-- Cover rules: gondolas, bookcases and wardrobes are full cover (7+ studs); racks are soft cover
-- (walk-through fabric); counters and tables are low (vaultable, <= 4 studs); hide cells are
-- interactive and enclosed.
local Fx = {}

local function pick(list, i) return list[((i - 1) % #list) + 1] end

-- Axis helpers: a fixture may run along local X ("h") or local Z ("v").
local function dims(len, depth, vertical)
	if vertical then return depth, len end
	return len, depth
end

function Fx.gondola(ctx, lx, lz, len, vertical, bodyColor, itemColors, height)
	local f, P = ctx.f, ctx.P
	height = height or 7
	local sx, sz = dims(len, 2.6, vertical)
	f.b("GondolaBody", lx, 0, lz, sx, height, sz, bodyColor, Enum.Material.SmoothPlastic, true, {cover = "Full"})
	f.b("GondolaCap", lx, height, lz, sx + 0.2, 0.4, sz + 0.2, P.white, Enum.Material.SmoothPlastic, false)
	-- Merchandise on both faces: three tiers of coloured product blocks.
	-- Wider product blocks (fewer parts) still read as stocked shelves in three colored tiers.
	local count = math.max(2, math.floor(len / 9))
	for tier = 1, 3 do
		local y0 = 0.9 + (tier - 1) * 2.1
		for i = 1, count do
			local along = -len / 2 + (i - 0.5) * len / count
			local color = pick(itemColors, i + tier)
			for _, face in ipairs({-1, 1}) do
				local px, pz
				if vertical then px, pz = lx + face * 1.45, lz + along else px, pz = lx + along, lz + face * 1.45 end
				local bx, bz
				if vertical then bx, bz = 0.5, len / count - 0.5 else bx, bz = len / count - 0.5, 0.5 end
				f.b("Product", px, y0, pz, bx, 1.4, bz, color, Enum.Material.SmoothPlastic, false)
			end
		end
	end
end

-- Soft cover: a hanging rail of clothes. Garments do not collide, so runners can slip inside.
function Fx.rack(ctx, lx, lz, len, vertical, colorA, colorB)
	local f, P = ctx.f, ctx.P
	local sx, sz = dims(len, 0.4, vertical)
	for _, end_ in ipairs({-1, 1}) do
		local px, pz = lx, lz
		if vertical then pz += end_ * (len / 2 - 0.2) else px += end_ * (len / 2 - 0.2) end
		f.b("RackPost", px, 0, pz, 0.4, 5.6, 0.4, P.steel, Enum.Material.Metal, true)
		f.b("RackFoot", px, 0, pz, vertical and 3 or 0.4, 0.3, vertical and 0.4 or 3, P.steel, Enum.Material.Metal, false)
	end
	f.b("RackRail", lx, 5.4, lz, sx, 0.3, sz, P.steel, Enum.Material.Metal, false)
	local count = math.max(2, math.floor(len / 2.4))
	for i = 1, count do
		local along = -len / 2 + (i - 0.5) * len / count
		local bx, bz = lx, lz
		if vertical then bz += along else bx += along end
		local w = len / count - 0.15
		f.b("Garment", bx, 1.6, bz, vertical and 1.2 or w, 3.8, vertical and w or 1.2, i % 2 == 0 and colorA or colorB, Enum.Material.Fabric, false, {cover = "Soft"})
	end
end

function Fx.counter(ctx, lx, lz, w, d, bodyColor, topColor, screenColor)
	local f, P = ctx.f, ctx.P
	f.b("CounterBody", lx, 0, lz, w, 3.6, d, bodyColor, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
	f.b("CounterTop", lx, 3.6, lz, w + 0.3, 0.3, d + 0.3, topColor or P.white, Enum.Material.Marble, true, {cover = "Low", vault = true})
	f.b("Register", lx - w / 4, 3.9, lz, 1.8, 1.2, 1.4, P.dark, Enum.Material.Metal, false)
	f.b("RegisterScreen", lx - w / 4, 5.1, lz, 1.4, 0.9, 0.2, screenColor or P.mint, Enum.Material.Neon, false)
	f.b("CounterGlow", lx, 0.15, lz - d / 2 - 0.05, w - 0.6, 0.15, 0.1, screenColor or P.mint, Enum.Material.Neon, false)
end

-- Low display table: vaultable, with coloured products.
function Fx.table(ctx, lx, lz, sx, sz, height, color, itemColors)
	local f, P = ctx.f, ctx.P
	f.b("DisplayTable", lx, 0, lz, sx, height, sz, color, Enum.Material.SmoothPlastic, true, {cover = "Low", vault = true})
	f.b("DisplayTop", lx, height, lz, sx + 0.2, 0.2, sz + 0.2, P.white, Enum.Material.SmoothPlastic, false)
	local nx, nz = math.max(1, math.floor(sx / 2.6)), math.max(1, math.floor(sz / 2.6))
	local n = 0
	for ix = 1, nx do
		for iz = 1, nz do
			n += 1
			f.b("Item", lx - sx / 2 + (ix - 0.5) * sx / nx, height + 0.2, lz - sz / 2 + (iz - 0.5) * sz / nz, 1.5, 1 + (n % 3) * 0.4, 1.5, pick(itemColors, n), Enum.Material.SmoothPlastic, false)
		end
	end
end

function Fx.mannequin(ctx, lx, lz, outfit, accent)
	local f, P = ctx.f, ctx.P
	f.b("MannequinBase", lx, 0, lz, 2, 0.3, 2, P.dark, Enum.Material.Metal, false)
	f.b("MannequinLegs", lx, 0.3, lz, 0.9, 2.6, 0.7, outfit, Enum.Material.Fabric, false)
	f.b("MannequinTorso", lx, 2.9, lz, 1.7, 2.2, 0.9, accent, Enum.Material.Fabric, false)
	f.ball("MannequinHead", lx, 5.1, lz, 0.95, 1.05, 0.95, P.white, Enum.Material.SmoothPlastic, false)
	f.b("MannequinPole", lx, 0.3, lz + 0.8, 0.2, 5, 0.2, P.steel, Enum.Material.Metal, false)
end

function Fx.plant(ctx, lx, lz, scale)
	local f, P = ctx.f, ctx.P
	scale = scale or 1
	f.can("PlantPot", lx, 0, lz, 2.6 * scale, 2 * scale, P.coral, Enum.Material.SmoothPlastic, true, {cover = "Soft"})
	f.ball("Foliage", lx, 2 * scale, lz, 3.4 * scale, 3 * scale, 3.4 * scale, P.leaf, Enum.Material.SmoothPlastic, false, {cover = "Soft"})
	f.ball("FoliageHigh", lx + 0.4 * scale, 3.6 * scale, lz, 2.4 * scale, 2.2 * scale, 2.4 * scale, P.lime, Enum.Material.SmoothPlastic, false)
end

function Fx.sofa(ctx, lx, lz, yawDeg, color)
	local g = ctx.sub(lx, lz, yawDeg or 0)
	local P = ctx.P
	g.b("SofaSeat", 0, 0.4, 0, 6.4, 1.6, 2.8, color, Enum.Material.Fabric, true, {cover = "Low", vault = true})
	g.b("SofaBack", 0, 2, 1.1, 6.4, 2.6, 0.8, color, Enum.Material.Fabric, true, {cover = "Low"})
	for _, s in ipairs({-1, 1}) do g.b("SofaArm", s * 3.2, 0.4, 0, 0.8, 2.6, 2.8, color, Enum.Material.Fabric, true) end
	g.b("SofaCushion", -1.4, 2, -0.1, 2.6, 0.6, 2, P.white, Enum.Material.Fabric, false)
	g.b("SofaCushion", 1.4, 2, -0.1, 2.6, 0.6, 2, P.cream, Enum.Material.Fabric, false)
end

function Fx.tv(ctx, lx, y0, lz, w, h, color, inward)
	local f, P = ctx.f, ctx.P
	f.b("TVFrame", lx, y0, lz, w + 0.5, h + 0.5, 0.3, P.black, Enum.Material.Metal, false)
	f.b("TVScreen", lx, y0 + 0.25, lz + (inward and -0.2 or 0.2), w, h, 0.2, color, Enum.Material.Neon, false)
end

function Fx.bookcase(ctx, lx, lz, len, vertical, color, bookColors)
	local f, P = ctx.f, ctx.P
	local sx, sz = dims(len, 1.8, vertical)
	f.b("BookcaseBody", lx, 0, lz, sx, 9, sz, color, Enum.Material.Wood, true, {cover = "Full"})
	local rows = 3
	local count = math.max(3, math.floor(len / 4.6))
	for r = 1, rows do
		for i = 1, count do
			local along = -len / 2 + (i - 0.5) * len / count
			for _, face in ipairs({-1, 1}) do
				local px, pz = lx + (vertical and face * 0.95 or along), lz + (vertical and along or face * 0.95)
				f.b("Books", px, 0.7 + (r - 1) * 2.7, pz, vertical and 0.3 or len / count - 0.3, 1.6, vertical and len / count - 0.3 or 0.3, pick(bookColors, i + r), Enum.Material.SmoothPlastic, false)
			end
		end
	end
end

-- Sub-frame helper for rotated furniture (degrees).
function Fx.shelfWall(ctx, lx, lz, len, vertical, colors)
	-- Wall units hug a wall: tall, shallow, collidable, packed with colour.
	Fx.gondola(ctx, lx, lz, len, vertical, ctx.P.white, colors, 9)
end

function Fx.hangBanner(ctx, lx, lz, w, h, color)
	local f = ctx.f
	f.b("Banner", lx, 20 - h, lz, w, h, 0.2, color, Enum.Material.Fabric, false)
	f.b("BannerRod", lx, 20, lz, w + 0.6, 0.3, 0.3, ctx.P.dark, Enum.Material.Metal, false)
end

-- Enclosed hide cell: fitting room, restroom stall, locker, booth. The cell is built in a sub-frame
-- whose local +Z is the back wall and whose opening faces -Z. Returns the registered spot data.
function Fx.hideCell(ctx, opts)
	local P, kit = ctx.P, ctx.kit
	local model = Instance.new("Model")
	model.Name = "HideSpot_" .. opts.id
	model.Parent = ctx.parent
	local g = ctx.sub(opts.lx, opts.lz, opts.yaw or 0, model)
	local w, d, h = opts.w or 6, opts.d or 6, opts.h or 9
	local wall = opts.wall or P.blush
	-- Walls and roof (collidable so the hunter cannot see or tag through them).
	g.b("CellBack", 0, 0, d / 2 - 0.25, w, h, 0.5, wall, Enum.Material.SmoothPlastic, true)
	g.b("CellLeft", -w / 2 + 0.25, 0, 0, 0.5, h, d, wall, Enum.Material.SmoothPlastic, true)
	g.b("CellRight", w / 2 - 0.25, 0, 0, 0.5, h, d, wall, Enum.Material.SmoothPlastic, true)
	g.b("CellRoof", 0, h - 0.4, 0, w, 0.4, d, opts.roof or wall, Enum.Material.SmoothPlastic, true)
	if opts.interior then opts.interior(g, w, d, h) end
	local decorate = opts.decor
	-- The door is always closed and solid. Whether someone hides inside is deliberately not visible
	-- from the door itself: hunters get tells (feet under the gap, a scan pulse) and a fair Search.
	local doorY = opts.doorGap or 1.2
	local door = g.b("Door", 0, doorY, -d / 2 + 0.2, w - 0.6, h - doorY - 1.4, 0.3, opts.door or P.pink, opts.doorMaterial or Enum.Material.Fabric, true)
	door:SetAttribute("HideDoor", true)
	g.b("DoorHandle", w / 2 - 1, doorY + 2.4, -d / 2 - 0.1, 0.3, 0.9, 0.2, P.steel, Enum.Material.Metal, false)
	if decorate then decorate(g, w, d, h, doorY) end
	local promptPart = g.b("PromptPart", 0, 2.2, -d / 2 - 0.4, 3, 3, 0.3, P.white, Enum.Material.SmoothPlastic, false)
	promptPart.Transparency = 1
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HidePrompt"
	prompt.ActionText = "Hide"
	prompt.ObjectText = opts.kind
	prompt.HoldDuration = 0.35
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = promptPart
	local rootY = 3.1
	local inside = g.base * CFrame.new(0, rootY, 0)
	local facing = g.base:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local insideCF = CFrame.lookAt(inside.Position, inside.Position + facing)
	local exitPos = g.base:PointToWorldSpace(Vector3.new(0, rootY, -d / 2 - 4.5))
	local exitCF = CFrame.lookAt(exitPos, exitPos + facing)
	model:SetAttribute("CatchHideSpot", true)
	model:SetAttribute("SpotId", opts.id)
	model:SetAttribute("Kind", opts.kind)
	model:SetAttribute("InsideCFrame", insideCF)
	model:SetAttribute("ExitCFrame", exitCF)
	model:SetAttribute("Floor", ctx.floor)
	local spot = {id = opts.id, kind = opts.kind, model = model, door = door, prompt = prompt, inside = insideCF, exit = exitCF, store = ctx.name}
	table.insert(kit.hideSpots, spot)
	return spot
end

return Fx
