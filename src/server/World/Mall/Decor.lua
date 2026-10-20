-- Reusable decoration pieces (cheap, chunky and cheerful). Everything is built from the kit's primitives, so the
-- art direction (palette, neon policy) stays in one place. Decor never blocks gameplay routes: trunks and
-- planters collide, everything else is visual only.
local Decor = {}

-- A round, chunky cartoon tree: tapered trunk and three overlapping crowns.
function Decor.tree(kit, parent, x, y, z, scale, palette)
	local P = kit.P
	scale = scale or 1
	palette = palette or {P.leaf, P.lime, P.mint}
	kit.can(parent, "TreeTrunk", x, y + 3.4 * scale, z, 1.5 * scale, 6.8 * scale, P.darkwood, Enum.Material.Wood, true, {shadow = false})
	kit.ball(parent, "TreeCrown", x, y + 9 * scale, z, 8 * scale, 6.6 * scale, 8 * scale, palette[1], Enum.Material.SmoothPlastic, false)
	kit.ball(parent, "TreeCrown", x - 2.2 * scale, y + 7.6 * scale, z + 0.8 * scale, 5.4 * scale, 4.6 * scale, 5.4 * scale, palette[2], Enum.Material.SmoothPlastic, false)
	kit.ball(parent, "TreeCrown", x + 2 * scale, y + 11 * scale, z - 0.6 * scale, 5 * scale, 4.4 * scale, 5 * scale, palette[3], Enum.Material.SmoothPlastic, false)
end

-- A palm: leaning trunk segments and six drooping fronds. A cheerful vacation-mall landmark.
function Decor.palm(kit, parent, x, y, z, scale)
	local P = kit.P
	scale = scale or 1
	local lean = 0.35 * scale
	for i = 1, 3 do
		kit.can(parent, "PalmTrunk", x + lean * i * 0.6, y + (i - 0.5) * 2.4 * scale, z, (1.5 - i * 0.12) * scale, 2.5 * scale, i % 2 == 0 and P.wood or P.darkwood, Enum.Material.Wood, i == 1, {shadow = false})
	end
	local topX, topY = x + lean * 3 * 0.6, y + 7.4 * scale
	for i = 0, 5 do
		local yaw = i * math.pi / 3
		local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
		local length = 5.6 * scale
		local center = Vector3.new(topX, topY, z) + dir * (length * 0.45) - Vector3.new(0, length * 0.12, 0)
		local cf = CFrame.lookAt(center, center + dir) * CFrame.Angles(math.rad(-16), 0, 0)
		kit.part(parent, "PalmFrond", Vector3.new(1.8 * scale, 0.25, length), cf, i % 2 == 0 and P.leaf or P.lime, Enum.Material.SmoothPlastic, false, {shadow = false})
	end
	kit.ball(parent, "Coconut", topX + 0.5 * scale, topY - 0.7 * scale, z, 0.9 * scale, 0.9 * scale, 0.9 * scale, P.darkwood, Enum.Material.SmoothPlastic, false)
	kit.ball(parent, "Coconut", topX - 0.5 * scale, topY - 0.7 * scale, z + 0.4 * scale, 0.9 * scale, 0.9 * scale, 0.9 * scale, P.darkwood, Enum.Material.SmoothPlastic, false)
end

-- A planter box with a flower border; `plant` adds a tree/palm on top.
function Decor.planterBox(kit, parent, x, y, z, sx, sz, flower)
	local P = kit.P
	kit.box(parent, "PlanterBox", x, y + 1.2, z, sx, 2.4, sz, P.terracotta, Enum.Material.Concrete, true, {cover = "Low", vault = true})
	kit.box(parent, "PlanterSoil", x, y + 2.45, z, sx - 0.8, 0.2, sz - 0.8, P.soil, Enum.Material.SmoothPlastic, false)
	local count = math.max(3, math.floor(math.max(sx, sz) / 2.6))
	for i = 1, count do
		local t = (i - 0.5) / count - 0.5
		local px = sx >= sz and x + t * (sx - 2) or x
		local pz = sx >= sz and z or z + t * (sz - 2)
		kit.ball(parent, "Blossom", px, y + 2.9, pz, 1.2, 1, 1.2, i % 2 == 0 and flower or P.sun, Enum.Material.SmoothPlastic, false)
	end
end

function Decor.bench(kit, parent, x, y, z, yaw, color)
	local P = kit.P
	local f = kit.frame(parent, Vector3.new(x, y, z), yaw, y)
	f.b("BenchSeat", 0, 1.4, 0, 6.4, 0.5, 2, color or P.sun, Enum.Material.SmoothPlastic, false)
	f.b("BenchBack", 0, 2.4, 0.9, 6.4, 1.6, 0.4, color or P.sun, Enum.Material.SmoothPlastic, false)
	for _, s in ipairs({-1, 1}) do f.b("BenchLeg", s * 2.8, 0, 0, 0.5, 1.4, 1.8, P.dark, Enum.Material.Metal, false) end
end

-- A lamp post with a round shade. `lit` adds one budgeted point light.
function Decor.lampPost(kit, parent, x, y, z, color, lit)
	local P = kit.P
	kit.can(parent, "LampPole", x, y + 6, z, 0.7, 12, P.dark, Enum.Material.Metal, false)
	kit.can(parent, "LampBase", x, y + 0.6, z, 1.6, 1.2, P.dark, Enum.Material.Metal, false)
	kit.ball(parent, "LampShade", x, y + 12.6, z, 2.4, 2.4, 2.4, color or P.cream, Enum.Material.SmoothPlastic, false)
	if lit then kit.lamp(parent, Vector3.new(x, y + 12.6, z), color or P.sun, 0.7, 34) end
end

-- A string of triangular pennants between two points (decor only).
function Decor.bunting(kit, parent, a, b, count, colors)
	local P = kit.P
	local line = b - a
	kit.beam(parent, "BuntingLine", a, b, 0.12, P.dark, Enum.Material.SmoothPlastic, false)
	for i = 1, count do
		local t = (i - 0.5) / count
		local p = a + line * t - Vector3.new(0, math.sin(t * math.pi) * 1.2, 0)
		kit.part(parent, "Pennant", Vector3.new(1.4, 1.8, 0.12), CFrame.new(p - Vector3.new(0, 0.9, 0)), colors[(i % #colors) + 1], Enum.Material.Fabric, false, {shadow = false})
	end
end

-- A semicircle balloon arch in the XY plane at (x, y, z).
function Decor.balloonArch(kit, parent, x, y, z, radius, colors)
	for i = 0, 10 do
		local a = i / 10 * math.pi
		local bx, by = x + math.cos(a) * radius, y + math.sin(a) * radius
		kit.ball(parent, "Balloon", bx, by + 2, z, 2.8, 3.2, 2.8, colors[(i % #colors) + 1], Enum.Material.SmoothPlastic, false, {shadow = false})
	end
	for _, side in ipairs({-1, 1}) do
		kit.can(parent, "BalloonPost", x + side * radius, y + 1, z, 2.4, 2, colors[1], Enum.Material.SmoothPlastic, false)
	end
end

-- A striped fabric canopy tilted down toward -Z (outward from a wall). Returns nothing; visual only.
function Decor.awning(kit, parent, cx, cy, cz, width, depth, a, b, stripe)
	local tilt = CFrame.Angles(math.rad(-18), 0, 0)
	kit.part(parent, "AwningBase", Vector3.new(width, 0.4, depth), CFrame.new(cx, cy, cz) * tilt, a, Enum.Material.Fabric, false, {shadow = false})
	stripe = stripe or 4
	for i = 0, math.floor(width / stripe) - 1 do
		if i % 2 == 1 then
			kit.part(parent, "AwningStripe", Vector3.new(stripe, 0.44, depth + 0.02), CFrame.new(cx - width / 2 + stripe * (i + 0.5), cy + 0.02, cz) * tilt, b, Enum.Material.Fabric, false, {shadow = false})
		end
	end
end

return Decor
