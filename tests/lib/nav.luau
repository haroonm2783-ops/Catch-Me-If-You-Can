-- Heightfield navigation model for geometry checks. Solid parts become obstacles in a 1-stud
-- grid; standable surfaces need head room and clear neighbours; a flood fill finds what an
-- avatar can walk to. This is an analytic approximation of Humanoid movement, not a physics
-- simulation: it proves the map has no sealed rooms, blocked doors or exploit routes, not that
-- the chase feels good.
local Nav = {}
Nav.__index = Nav

local CELL = 1
local HEADROOM = 5.4
local STEP = 1.45         -- walkable rise per cell (stairs are 0.8, ramps about 0.55 per stud)
local JUMP = 5.2          -- standing jump height (JumpPower 48, gravity 196.2)
local FALL = 40
Nav.JUMP = JUMP

local function axisRange(o, d, h)
	if math.abs(d) < 1e-9 then
		if math.abs(o) <= h then return -math.huge, math.huge end
		return nil
	end
	local a, b = (-h - o) / d, (h - o) / d
	if a > b then a, b = b, a end
	return a, b
end

-- Solve sum(((o + t d) / r)^2) <= 1 for t.
local function ellipsoid(components)
	local a, b, c = 0, 0, -1
	for _, comp in ipairs(components) do
		local o, d = comp[1] / comp[3], comp[2] / comp[3]
		a += d * d
		b += 2 * o * d
		c += o * o
	end
	if a < 1e-12 then
		if c <= 0 then return -math.huge, math.huge end
		return nil
	end
	local disc = b * b - 4 * a * c
	if disc < 0 then return nil end
	local root = math.sqrt(disc)
	return (-b - root) / (2 * a), (-b + root) / (2 * a)
end

-- World-Y interval where the vertical line through a column centre passes through the part.
local function verticalInterval(part, o, d)
	local half = part.Size / 2
	local lo, hi = -math.huge, math.huge
	local shape = part:IsA("Part") and part.Shape.Name or "Block"
	if shape == "Cylinder" then
		local a, b = axisRange(o.X, d.X, half.X)
		if not a then return nil end
		lo, hi = a, b
		local qa, qb = ellipsoid({{o.Y, d.Y, half.Y}, {o.Z, d.Z, half.Z}})
		if not qa then return nil end
		lo, hi = math.max(lo, qa), math.min(hi, qb)
	elseif shape == "Ball" then
		local qa, qb = ellipsoid({{o.X, d.X, half.X}, {o.Y, d.Y, half.Y}, {o.Z, d.Z, half.Z}})
		if not qa then return nil end
		lo, hi = qa, qb
	else
		for _, axis in ipairs({"X", "Y", "Z"}) do
			local a, b = axisRange(o[axis], d[axis], half[axis])
			if not a then return nil end
			lo, hi = math.max(lo, a), math.min(hi, b)
		end
	end
	if lo > hi then return nil end
	return lo, hi
end

function Nav.new(parts, domain, vector3)
	local self = setmetatable({}, Nav)
	self.x0, self.x1, self.z0, self.z1 = domain.x0, domain.x1, domain.z0, domain.z1
	self.nx = math.ceil((self.x1 - self.x0) / CELL)
	self.nz = math.ceil((self.z1 - self.z0) / CELL)
	local columns = {}
	for _, part in ipairs(parts) do
		if part.CanCollide then
			local cf = part.CFrame
			local half = part.Size / 2
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for sx = -1, 1, 2 do for sy = -1, 1, 2 do for sz = -1, 1, 2 do
				local corner = cf:PointToWorldSpace(vector3.new(sx * half.X, sy * half.Y, sz * half.Z))
				minX, maxX = math.min(minX, corner.X), math.max(maxX, corner.X)
				minZ, maxZ = math.min(minZ, corner.Z), math.max(maxZ, corner.Z)
			end end end
			local ix0 = math.max(0, math.floor((minX - self.x0) / CELL))
			local ix1 = math.min(self.nx - 1, math.floor((maxX - self.x0) / CELL))
			local iz0 = math.max(0, math.floor((minZ - self.z0) / CELL))
			local iz1 = math.min(self.nz - 1, math.floor((maxZ - self.z0) / CELL))
			local d = cf:VectorToObjectSpace(vector3.new(0, 1, 0))
			for ix = ix0, ix1 do
				for iz = iz0, iz1 do
					local x, z = self.x0 + (ix + 0.5) * CELL, self.z0 + (iz + 0.5) * CELL
					local lo, hi = verticalInterval(part, cf:PointToObjectSpace(vector3.new(x, 0, z)), d)
					if lo and hi - lo > 0.02 then
						local key = ix * self.nz + iz
						local list = columns[key]
						if not list then list = {} columns[key] = list end
						list[#list + 1] = {lo, hi, part}
					end
				end
			end
		end
	end
	self.raw = columns
	-- Merge intervals per column.
	self.solids = {}
	for key, list in pairs(columns) do
		table.sort(list, function(a, b) return a[1] < b[1] end)
		local merged = {}
		for _, iv in ipairs(list) do
			local last = merged[#merged]
			if last and iv[1] <= last[2] + 0.05 then last[2] = math.max(last[2], iv[2])
			else merged[#merged + 1] = {iv[1], iv[2]} end
		end
		self.solids[key] = merged
	end
	-- Standable surfaces: a top with head room whose four neighbours have no wall above step height.
	self.surfaces = {}
	for key, merged in pairs(self.solids) do
		local ix, iz = key // self.nz, key % self.nz
		for index, iv in ipairs(merged) do
			local top = iv[2]
			local nextBottom = merged[index + 1] and merged[index + 1][1] or math.huge
			if nextBottom - top >= HEADROOM and top > -50 and top < 90 then
				local clear = true
				for _, offset in ipairs({{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) do
					local nkey = (ix + offset[1]) * self.nz + (iz + offset[2])
					for _, niv in ipairs(self.solids[nkey] or {}) do
						if niv[2] > top + STEP + 0.05 and niv[1] < top + HEADROOM - 0.4 then clear = false break end
					end
					if not clear then break end
				end
				if clear then
					local list = self.surfaces[key]
					if not list then list = {} self.surfaces[key] = list end
					list[#list + 1] = top
				end
			end
		end
	end
	return self
end

-- Names of solid parts within one cell of a point that would obstruct standing at floorY.
function Nav:blockers(x, floorY, z)
	local names, seen = {}, {}
	local key = self:key(x, z)
	if not key then return names end
	local ix, iz = key // self.nz, key % self.nz
	for dx = -1, 1 do
		for dz = -1, 1 do
			for _, iv in ipairs(self.raw[(ix + dx) * self.nz + (iz + dz)] or {}) do
				if iv[2] > floorY + 1.5 and iv[1] < floorY + 5 and not seen[iv[3]] then
					seen[iv[3]] = true
					local path = iv[3].Name
					local parent = iv[3].Parent
					if parent then path = parent.Name .. "/" .. path end
					table.insert(names, path)
				end
			end
		end
	end
	return names
end

-- Ladders and other special connections: both nodes become mutually reachable.
function Nav:link(a, b)
	if not a or not b then return end
	self.links = self.links or {}
	self.links[a] = self.links[a] or {}
	self.links[b] = self.links[b] or {}
	table.insert(self.links[a], b)
	table.insert(self.links[b], a)
end

function Nav:key(x, z)
	local ix, iz = math.floor((x - self.x0) / CELL), math.floor((z - self.z0) / CELL)
	if ix < 0 or iz < 0 or ix >= self.nx or iz >= self.nz then return nil end
	return ix * self.nz + iz
end

-- Node id: key * 16 + surface index. Returns nil when no standable surface within `tolerance`.
function Nav:nodeAt(x, feetY, z, tolerance)
	local key = self:key(x, z)
	local list = key and self.surfaces[key]
	if not list then return nil end
	local best, bestDistance
	for index, top in ipairs(list) do
		local distance = math.abs(top - feetY)
		if distance <= (tolerance or 2) and (not bestDistance or distance < bestDistance) then best, bestDistance = index, distance end
	end
	return best and (key * 16 + best) or nil
end

function Nav:height(node) return self.surfaces[node // 16][node % 16] end
function Nav:position(node)
	local key = node // 16
	local ix, iz = key // self.nz, key % self.nz
	return self.x0 + (ix + 0.5) * CELL, self:height(node), self.z0 + (iz + 0.5) * CELL
end

-- Flood fill. opts.jump allows hopping up to JUMP studs; opts.fall allows dropping off ledges.
function Nav:flood(starts, opts)
	opts = opts or {}
	local up = opts.jump and JUMP or STEP
	local visited, queue, head = {}, {}, 1
	for _, node in ipairs(starts) do
		if node and not visited[node] then visited[node] = true queue[#queue + 1] = node end
	end
	local nz = self.nz
	while head <= #queue do
		local node = queue[head]
		head += 1
		local key = node // 16
		local ix, iz = key // nz, key % nz
		local top = self.surfaces[key][node % 16]
		for _, other in ipairs(self.links and self.links[node] or {}) do
			if not visited[other] then visited[other] = true queue[#queue + 1] = other end
		end
		for dx = -1, 1 do
			for dz = -1, 1 do
				if dx ~= 0 or dz ~= 0 then
					local nkey = (ix + dx) * nz + (iz + dz)
					local list = self.surfaces[nkey]
					if list then
						for index, other in ipairs(list) do
							local dy = other - top
							local ok = dy <= up and (dy >= -STEP or (opts.fall and dy >= -FALL))
							if ok then
								local id = nkey * 16 + index
								if not visited[id] then visited[id] = true queue[#queue + 1] = id end
							end
						end
					end
				end
			end
		end
	end
	return visited
end

function Nav:count(visited)
	local n = 0
	for _ in pairs(visited) do n += 1 end
	return n
end

return Nav
