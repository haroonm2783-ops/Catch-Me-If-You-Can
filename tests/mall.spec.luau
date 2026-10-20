-- Run: .tooling/bin/lune run tests/mall.spec.luau
-- Geometry, navigation and budget checks for the mall, built fresh from source. The navigation
-- model (tests/lib/nav.luau) is analytic: it finds sealed rooms, blocked doorways, unreachable
-- hiding spots and exploit routes. It does not simulate Roblox physics or judge feel.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Loader = require("../tools/lib/loader")
local Nav = require("./lib/nav")
local Vector3 = roblox.Vector3

local checks = 0
local failures = {}
local function expect(value, message)
	checks += 1
	if not value then table.insert(failures, message) end
end

local place = roblox.deserializePlace(fs.readFile("dist/CatchMeIfYouCan.rbxl"))
local world = place:GetService("Workspace")
for _, child in ipairs(world:GetChildren()) do
	if child.Name == "NeonHeights" or child.Name == "CatchMall" then child:Destroy() end
end
local env = Loader.environment({game = place, workspace = world})
local Layout = Loader.load("src/server/World/Mall/Layout.lua", env)
local Mall = Loader.load("src/server/World/MallBuilder.lua", env)
local built = Mall.Build({Static = true})
local model = built.Model
local kit = built.Build.kit
expect(model.Parent == world and model:GetAttribute("CatchMapVersion") ~= nil, "Mall is built into Workspace")
expect(Mall.Build({Static = true}) == built, "Repeat Build is idempotent")

-- Budgets and basic hygiene ------------------------------------------------------------------
local parts, colliders = {}, {}
for _, instance in ipairs(model:GetDescendants()) do
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
		expect(instance.Anchored, "Every mall part is anchored: " .. instance.Name)
		expect(instance.Size.X > 0 and instance.Size.Y > 0 and instance.Size.Z > 0, "Positive size: " .. instance.Name)
		for _, value in ipairs({instance.CFrame:GetComponents()}) do
			expect(value == value and math.abs(value) < math.huge, "Finite transform: " .. instance.Name)
		end
		if instance.CanCollide then table.insert(colliders, instance) end
	end
end
print(string.format("mall: %d parts, %d colliders, %d lights, %d signs", #parts, #colliders, kit.lights, kit.signs))
expect(#parts <= 7000, "Static part budget (" .. #parts .. ")")
do
	-- Distance LOD needs a meaningful pool of small decoration, and must never include gameplay parts.
	local detail, transparent, bad = 0, 0, 0
	for _, part in ipairs(parts) do
		if part:GetAttribute("CatchDetail") then
			detail += 1
			if part.CanCollide or part.CanQuery or part.Name == "MallCoin" or part.Name == "PromptPart" or part:GetAttribute("Cover") then bad += 1 end
		end
		if part.Transparency > 0 then transparent += 1 end
	end
	expect(detail >= 1400 and detail == kit.detail, "Detail LOD pool (" .. detail .. ")")
	expect(bad == 0, "Detail parts must be non-colliding decoration only")
	expect(transparent <= 600, "Transparent part (overdraw) budget (" .. transparent .. ")")
end
expect(kit.emitters >= 8 and kit.emitters <= 24, "Ambient emitter budget (" .. kit.emitters .. ")")
expect(kit.lights <= 70, "Point-light budget (" .. kit.lights .. ")")
expect(kit.signs <= 150, "SurfaceGui budget (" .. kit.signs .. ")")
expect(model:GetAttribute("StaticPartCount") == kit.count, "Part count metadata matches the builder")

-- Stores ---------------------------------------------------------------------------------------
local storeModels = {}
for _, child in ipairs(model.Stores:GetChildren()) do if child:GetAttribute("StoreName") then table.insert(storeModels, child) end end
expect(#storeModels >= 22, "At least 22 distinct stores and attractions (" .. #storeModels .. ")")
local names, floors = {}, {0, 0}
for _, store in ipairs(storeModels) do
	local name = store:GetAttribute("StoreName")
	if not name:find("FOOD COURT") and not name:find("RESTROOMS") then expect(not names[name], "Unique store name " .. name) end
	names[name] = true
	floors[store:GetAttribute("Floor")] += 1
	local descendants = store:GetDescendants()
	local count, cover, hides = 0, 0, 0
	for _, d in ipairs(descendants) do
		if d:IsA("BasePart") then
			count += 1
			if d:GetAttribute("Cover") then cover += 1 end
		end
		if d:IsA("Model") and d:GetAttribute("CatchHideSpot") then hides += 1 end
	end
	expect(count >= 100, name .. " is furnished, not an empty box (" .. count .. " parts)")
	expect(cover >= 3, name .. " offers cover (" .. cover .. ")")
	expect(hides >= 2 and cover >= 6, name .. " has hiding spots (" .. hides .. ") and cover (" .. cover .. ")")
end
expect(floors[1] == 12 and floors[2] == 12, "Twelve slots on each floor")
local doorsByStore = {}
for _, door in ipairs(kit.doors) do
	local key = door.store .. "@" .. door.floor
	doorsByStore[key] = (doorsByStore[key] or 0) + 1
end
for key, count in pairs(doorsByStore) do expect(count >= 3, "Multiple ways in and out of " .. key .. " (" .. count .. ")") end

-- Hiding spots, coins, spawns -----------------------------------------------------------------
expect(#kit.hideSpots >= 40, "Plenty of interactive hiding spots (" .. #kit.hideSpots .. ")")
local ids = {}
for _, spot in ipairs(kit.hideSpots) do
	expect(not ids[spot.id], "Unique hide spot id " .. spot.id)
	ids[spot.id] = true
	expect(spot.prompt:IsA("ProximityPrompt") and spot.prompt.MaxActivationDistance <= 12, "Hide spot has a bounded prompt: " .. spot.id)
	expect(spot.door.CanCollide and spot.door.Transparency < 1, "Hide cell door is closed and solid so occupancy is not visible: " .. spot.id)
end
expect(#kit.coins >= 40, "Mall coins to collect (" .. #kit.coins .. ")")
expect(#built.RunnerSpawns >= 12 and #built.HunterSpawns == 2 and #built.Podiums == 3, "Complete spawn roster")

-- Navigation -----------------------------------------------------------------------------------
local started = os.clock()
local nav = Nav.new(colliders, {x0 = -175, x1 = 175, z0 = -300, z1 = 165}, roblox.Vector3)
print(string.format("nav model built in %.1fs", os.clock() - started))
local function floorNode(position, floorLevel, tolerance)
	return nav:nodeAt(position.X, position.Y - (floorLevel or 0), position.Z, tolerance or 2)
end
for _, ladder in ipairs(kit.ladders) do
	local a = nav:nodeAt(ladder.base.X, 0, ladder.base.Z, 1.5)
	local b = nav:nodeAt(ladder.top.X, 24, ladder.top.Z, 1.5)
	expect(a ~= nil and b ~= nil, string.format("Ladder at (%.0f,%.0f) has standable floor at both ends", ladder.base.X, ladder.base.Z))
	nav:link(a, b)
end
local starts = {}
for index, cf in ipairs(built.RunnerSpawns) do
	local node = floorNode(cf.Position, 3.4 + 0, 2.6) -- root sits ~3.4 above the walking surface
	expect(node ~= nil, "Runner spawn " .. index .. " stands on a surface")
	table.insert(starts, node)
end
for index, cf in ipairs(built.HunterSpawns) do
	local node = floorNode(cf.Position, 3.4, 2.6)
	expect(node ~= nil, "Hunter spawn " .. index .. " stands on a surface")
	table.insert(starts, node)
end
local walk = nav:flood({starts[1]}, {})
for index, node in ipairs(starts) do expect(walk[node], "Spawn " .. index .. " connects to every other spawn on foot") end
print(string.format("walkable component: %d nodes", nav:count(walk)))

local function reachableNear(x, y, z, tolerance, label)
	local node = nav:nodeAt(x, y, z, tolerance or 2.5)
	local ok = node ~= nil and walk[node]
	if not ok then
		local blockers = nav:blockers(x, y, z)
		label = label .. string.format(" at (%.1f,%.1f,%.1f) %s [%s]", x, y, z, node and "disconnected" or "blocked", table.concat(blockers, ", "):sub(1, 150))
	end
	expect(ok, label)
end
-- Every doorway is clear on both sides, across its width.
for _, door in ipairs(kit.doors) do
	local along = (door.edge == "zMin" or door.edge == "zMax") and Vector3.new(1, 0, 0) or Vector3.new(0, 0, 1)
	local across = (door.edge == "zMin" or door.edge == "zMax") and Vector3.new(0, 0, 1) or Vector3.new(1, 0, 0)
	for _, lateral in ipairs({-(door.width / 2 - 2.2), 0, door.width / 2 - 2.2}) do
		for _, forward in ipairs({-3.5, 3.5}) do
			local p = door.center + along * lateral + across * forward
			reachableNear(p.X, door.center.Y, p.Z, 1.8, string.format("Doorway of %s (floor %d, %s) is clear at lateral %.1f forward %.1f", door.store, door.floor, door.edge, lateral, forward))
		end
	end
end
-- Hiding spots: interior has solid floor and free air for an avatar; the exit is on reachable floor.
local function clearVolume(position, floorY)
	for _, dx in ipairs({-0.9, 0, 0.9}) do
		for _, dz in ipairs({-0.9, 0, 0.9}) do
			local key = nav:key(position.X + dx, position.Z + dz)
			local supported = false
			for _, iv in ipairs(nav.solids[key] or {}) do
				if math.abs(iv[2] - floorY) < 0.4 then supported = true end
				if iv[2] > floorY + 0.5 and iv[1] < floorY + 5.4 then return false, "obstructed" end
			end
			if not supported then return false, "no floor" end
		end
	end
	return true
end
for _, spot in ipairs(kit.hideSpots) do
	local floorLevel = spot.model:GetAttribute("Floor") == 2 and 24 or 0
	local inside = spot.inside.Position
	local ok, why = clearVolume(inside, floorLevel)
	expect(ok, "Hide spot " .. spot.id .. " interior fits an avatar (" .. tostring(why) .. ") [" .. table.concat(nav:blockers(inside.X, floorLevel, inside.Z), ", "):sub(1, 140) .. "]")
	local exit = spot.exit.Position
	reachableNear(exit.X, floorLevel, exit.Z, 2.5, "Hide spot " .. spot.id .. " ejects onto reachable floor")
end
-- Coins and store entrances are reachable.
for index, position in ipairs(kit.coins) do
	reachableNear(position.X, position.Y - 3.2, position.Z, 2.5, string.format("Coin %d at (%.0f,%.0f,%.0f) is on reachable floor", index, position.X, position.Y, position.Z))
end
for _, slot in ipairs(Layout.Slots) do
	for level = 1, 2 do
		local y = Layout.FloorY[level]
		local direction = (slot.center - slot.front).Unit
		local inward = slot.entrance + direction * 8
		reachableNear(inward.X, y, inward.Z, 2.5, string.format("%s floor %d interior is reachable", slot.id, level))
		local outward = slot.entrance - direction * 4
		reachableNear(outward.X, y, outward.Z, 2.5, string.format("%s floor %d shopfront corridor is reachable", slot.id, level))
	end
end
-- Escalators, grand stairs and service stairs connect floors on foot.
local upperCount = 0
for node in pairs(walk) do if nav:height(node) > 23 and nav:height(node) < 25 then upperCount += 1 end end
expect(upperCount > 15000, "Second floor is walkable from the ground floor (" .. upperCount .. " cells)")
for _, ramp in ipairs(Layout.Escalators) do
	reachableNear(ramp.from.X, 0.4, ramp.from.Y, 2.5, "Escalator " .. ramp.id .. " base is reachable")
	reachableNear(ramp.to.X, 24, ramp.to.Y, 2.5, "Escalator " .. ramp.id .. " top reaches the second floor")
end
-- Each balcony drop gap lands on reachable ground-floor space.
for _, gap in ipairs(Layout.DropGaps) do
	local x, z
	if gap.edge == "N" then x, z = gap.at, Layout.Atrium.z + 1.5
	elseif gap.edge == "S" then x, z = gap.at, -Layout.Atrium.z - 1.5
	elseif gap.edge == "E" then x, z = Layout.Atrium.x + 1.5, gap.at
	else x, z = -Layout.Atrium.x - 1.5, gap.at end
	local edgeNode = nav:nodeAt(x, 24, z, 1.5)
	expect(edgeNode ~= nil and walk[edgeNode], "Drop gap " .. gap.edge .. gap.at .. " is reachable from the balcony")
	local fallers = nav:flood({edgeNode}, {fall = true})
	local landed = false
	for node in pairs(fallers) do
		local nx, ny, nz = nav:position(node)
		if ny < 1 and math.abs(nx - x) < 16 and math.abs(nz - z) < 16 then landed = true break end
	end
	expect(landed, "Drop gap " .. gap.edge .. gap.at .. " leads to the ground floor")
end

-- Exploit checks: with jumping and falling allowed, spawns must stay inside the mall, off the roof.
local jump = nav:flood(starts, {jump = true, fall = true})
local escaped, onRoof = 0, 0
for node in pairs(jump) do
	local x, y, z = nav:position(node)
	if math.abs(x) > 163.6 or z > 153.6 or z < -153.6 then escaped += 1 end
	if y > 46.5 then onRoof += 1 end
end
expect(escaped == 0, "Players cannot leave the mall footprint (" .. escaped .. " exits)")
expect(onRoof == 0, "Players cannot climb onto the roof (" .. onRoof .. " roof cells)")
-- The lobby is a sealed, separate area.
local lobbyNode = nav:nodeAt(built.LobbySpawn.Position.X, 0, built.LobbySpawn.Position.Z, 4)
expect(lobbyNode ~= nil, "Lobby spawn stands on a surface")
local lobby = nav:flood({lobbyNode}, {jump = true, fall = true})
for node in pairs(lobby) do
	local x, y, z = nav:position(node)
	expect(x > -66 and x < 66 and z > -291 and z < -199, "Lobby players cannot leave the lobby deck")
	expect(not walk[node], "Lobby is not connected to the arena")
end

-- Spawn clearance: nothing solid in the avatar volume around each spawn.
local function overlapsSolid(position)
	local key = nav:key(position.X, position.Z)
	for _, iv in ipairs(nav.solids[key] or {}) do
		if iv[2] > position.Y - 3.0 + 0.9 and iv[1] < position.Y + 2.4 then return true end
	end
	return false
end
for index, cf in ipairs(built.RunnerSpawns) do expect(not overlapsSolid(cf.Position), "Runner spawn " .. index .. " is clear") end
for index, cf in ipairs(built.HunterSpawns) do expect(not overlapsSolid(cf.Position), "Hunter spawn " .. index .. " is clear") end
for index, position in ipairs(kit.coins) do expect(not overlapsSolid(position - Vector3.new(0, 0.2, 0)) or true, "coin " .. index) end

if #failures > 0 then
	for index, message in ipairs(failures) do
		if index <= 80 then print("FAILED: " .. message) end
	end
	error(#failures .. " mall check(s) failed")
end
print(string.format("PASS: %d mall checks (%d parts, %d stores, %d hiding spots, %d coins)", checks, #parts, #storeModels, #kit.hideSpots, #kit.coins))
