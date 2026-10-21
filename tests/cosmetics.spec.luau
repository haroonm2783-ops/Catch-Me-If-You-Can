-- Run: .tooling/bin/lune run tests/cosmetics.spec.luau
-- Audits EVERY cosmetic against the real shared modules on real Roblox Instances and CFrames: skins, masks, trails,
-- emotes, collections and the showroom camera. This proves geometry, poses, budgets and data contracts; it does not
-- render, so how things LOOK still needs Studio (docs/TESTING.md).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Catalog = require("../src/shared/Catalog")
local V3, CF = roblox.Vector3, roblox.CFrame
local checks = 0
local function expect(value, message)
	checks += 1
	assert(value, message)
end
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end

local environment = {}
for key, value in pairs(roblox) do environment[key] = value end
local modules = {}
local function loadModule(name)
	local scoped = table.clone(environment)
	scoped.script = {Parent = {WaitForChild = function(_, sibling) return sibling end}}
	scoped.require = function(sibling) return assert(modules[sibling], "unknown sibling " .. tostring(sibling)) end
	modules[name] = luau.load(fs.readFile("src/shared/" .. name .. ".lua"), {environment = scoped, debugName = name})()
	return modules[name]
end
local Trails, Poses, Emotes = loadModule("Trails"), loadModule("Poses"), loadModule("Emotes")
local Appearance = loadModule("Appearance")
local PreviewStage = loadModule("PreviewStage")

local function partCount(model)
	local count = 0
	for _, item in ipairs(model:GetDescendants()) do if item:IsA("BasePart") then count += 1 end end
	return count
end
local function overlayCount(rig)
	local count = 0
	for _, part in ipairs(rig.CatchAppearance:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "TrailMount" and part.Name ~= "AuraMount" then count += 1 end
	end
	return count
end

-- ---------------------------------------------------------------------------------------
-- Every catalog cosmetic is implemented, and nothing is implemented without being sold.
-- ---------------------------------------------------------------------------------------
local defs = {HasSkin = Appearance.HasSkin, HasMask = Appearance.HasMask, HasTrail = Trails.Has, HasEmote = Emotes.Has}
for _, item in pairs(Catalog.Items) do
	expect(Catalog.IsReady(item, defs), "Every cosmetic in the catalog is implemented and previewable: " .. item.id)
end
local missing = table.clone(defs)
missing.HasTrail = function() return false end
expect(not Catalog.IsReady(Catalog.Get("trail_cyan"), missing) and not Catalog.IsReady(Catalog.Get("bundle_galaxy"), missing), "A missing implementation makes an item (and any collection containing it) not ready")
expect(not Catalog.IsReady(nil, defs) and not Catalog.IsReady({category = "bundles", id = "x", grants = {}}, defs), "Empty or missing items are never ready")
for _, id in ipairs(Appearance.SkinOrder) do expect(Catalog.Get(id) and Catalog.Get(id).category == "skins", "Implemented skin is sold: " .. id) end
for _, id in ipairs(Appearance.MaskOrder) do expect(Catalog.Get(id) and Catalog.Get(id).category == "masks", "Implemented mask is sold: " .. id) end
for _, id in ipairs(Trails.Order) do expect(Catalog.Get(id) and Catalog.Get(id).category == "trails", "Implemented trail is sold: " .. id) end
for _, id in ipairs(Emotes.Order) do expect(Catalog.Get(id) and Catalog.Get(id).category == "emotes", "Implemented emote is sold: " .. id) end
for _, id in ipairs(Emotes.VictoryOrder) do expect(Catalog.Get(id) and Catalog.Get(id).category == "victories", "Implemented victory pose is sold: " .. id) end
expect(#Appearance.SkinOrder == #Catalog.ForCategory("skins") and #Appearance.MaskOrder == #Catalog.ForCategory("masks") and #Trails.Order == #Catalog.ForCategory("trails")
	and #Emotes.Order == #Catalog.ForCategory("emotes") and #Emotes.VictoryOrder == #Catalog.ForCategory("victories"), "No catalog entry lacks an implementation")
-- Tag-effect previews cover every catch effect.
for _, item in ipairs(Catalog.ForCategory("tagEffects")) do expect(PreviewStage.BurstPalettes[item.id] ~= nil, "Catch effect has a preview palette: " .. item.id) end

-- ---------------------------------------------------------------------------------------
-- Emotes: every one is a real, finite, expressive, grounded pose function.
-- ---------------------------------------------------------------------------------------
local JOINTS = {Root = true, Waist = true, Neck = true, LeftShoulder = true, RightShoulder = true, LeftElbow = true, RightElbow = true,
	LeftHip = true, RightHip = true, LeftKnee = true, RightKnee = true}
local mannequin = Appearance.BuildMannequin({userId = 1})
local preview = Poses.Preview(mannequin)
expect(preview ~= nil, "A mannequin can be posed")
local function key(rig)
	return {rig.Head.CFrame.Position, rig.LeftHand.CFrame.Position, rig.RightHand.CFrame.Position, rig.LeftFoot.CFrame.Position, rig.RightFoot.CFrame.Position, rig.UpperTorso.CFrame.Position}
end
local rest = (function() preview:Set({}, CF.new()) return key(mannequin) end)()
local allEmotes = {}
for _, id in ipairs(Emotes.Order) do table.insert(allEmotes, id) end
for _, id in ipairs(Emotes.VictoryOrder) do table.insert(allEmotes, id) end
for _, id in ipairs(allEmotes) do
	local def = Emotes.Defs[id]
	local item = Catalog.Get(id)
	expect(def.duration > 0.5 and def.duration < 8 and type(def.name) == "string" and def.name == item.name, "Emote metadata matches the catalog: " .. id)
	expect(Emotes.Duration(id) == def.duration and Emotes.IsLoop(id) == (def.loop == true), "Emote accessors agree: " .. id)
	local travelled, lowest = {0, 0, 0, 0, 0, 0}, 0
	local steps = 48
	for step = 0, steps do
		local t = def.duration * step / steps
		local pose = Emotes.Sample(id, t, true)
		expect(type(pose) == "table", "Emote pose exists at every moment: " .. id)
		for name, delta in pairs(pose) do
			expect(JOINTS[name], "Emote drives only real joints: " .. id .. "/" .. name)
			for _, n in ipairs({delta:GetComponents()}) do expect(finite(n), "Emote pose is finite: " .. id) end
		end
		preview:Set(pose, CF.new())
		local now = key(mannequin)
		for index, position in ipairs(now) do
			expect(finite(position.X) and finite(position.Y) and finite(position.Z), "Posed body is finite: " .. id)
			travelled[index] = math.max(travelled[index], (position - rest[index]).Magnitude)
		end
		lowest = math.min(lowest, math.min(mannequin.LeftFoot.CFrame.Position.Y, mannequin.RightFoot.CFrame.Position.Y) - 0.15)
	end
	local moving = 0
	for _, distance in ipairs(travelled) do if distance >= 0.8 then moving += 1 end end
	expect(moving >= ((id == "emote_wave" or id == "victory_wave") and 1 or 2), "Emote visibly moves the body (not a static icon): " .. id .. " moved " .. moving .. " body points")
	expect(lowest >= -3.45, "Emote keeps the avatar's feet near the floor: " .. id .. " reached " .. string.format("%.2f", lowest))
	-- Smooth start; loops are seamless; one-shots end and replay cleanly.
	preview:Set(Emotes.Sample(id, 0, true), CF.new())
	local start = key(mannequin)
	for index, position in ipairs(start) do expect((position - rest[index]).Magnitude < 0.06, "Emote begins from the neutral stance: " .. id) end
	if def.loop then
		preview:Set(def.pose(0), CF.new()) local a = key(mannequin)
		preview:Set(def.pose(def.duration), CF.new()) local b = key(mannequin)
		for index = 1, #a do expect((a[index] - b[index]).Magnitude < 0.05, "Looping emote repeats seamlessly: " .. id) end
		expect(Emotes.Sample(id, def.duration * 3.3) ~= nil, "Looping emotes never run out: " .. id)
	else
		expect(Emotes.Sample(id, def.duration + 0.01) == nil, "A one-shot emote ends: " .. id)
		local tail = Emotes.Sample(id, def.duration - 0.005)
		preview:Set(tail, CF.new())
		for index, position in ipairs(key(mannequin)) do expect((position - rest[index]).Magnitude < 0.15, "A one-shot emote finishes back at rest: " .. id) end
		expect(next(Emotes.Sample(id, def.duration + Emotes.Gap / 2, true)) == nil, "Preview replay rests between plays: " .. id)
	end
end
expect(Emotes.Sample("nope", 1) == nil and Emotes.Sample("emote_wave", -1) == nil and Emotes.Sample("emote_wave", 0 / 0) == nil, "Bad emote requests return nothing")
-- Specific, readable gestures.
local function pose(id, t) preview:Set(Emotes.Sample(id, t, true), CF.new()) end
pose("emote_wave", 1.1)
expect(mannequin.RightHand.CFrame.Position.Y > mannequin.Head.CFrame.Position.Y, "The wave raises a hand above the head")
pose("emote_flip", 0.7)
expect(mannequin.Head.CFrame.Position.Y < mannequin.UpperTorso.CFrame.Position.Y, "The flip turns the avatar upside down in the air")
expect(mannequin.UpperTorso.CFrame.Position.Y > 1, "The flip leaves the ground")
pose("emote_flip", 1.55)
expect(mannequin.LeftHand.CFrame.Position.Y > mannequin.Head.CFrame.Position.Y and mannequin.RightHand.CFrame.Position.Y > mannequin.Head.CFrame.Position.Y, "The flip lands with both arms up")
pose("emote_drama", 2.9)
expect(mannequin.Head.CFrame.Position.Y < -0.5 and mannequin.UpperTorso.CFrame.Position.Y < -1, "The dramatic faint ends up lying down")
pose("emote_tiptoe", 0.6)
expect((mannequin.RightHand.CFrame.Position - mannequin.Head.CFrame.Position).Magnitude < 1.6, "Sneaky Tiptoe raises a finger to the face")
pose("emote_royal", 1.0)
expect((mannequin.LeftHand.CFrame.Position - mannequin.RightHand.CFrame.Position).Magnitude > 1.5, "Royal Twirl keeps the arms out while spinning")
for _, id in ipairs(Emotes.Order) do
	local item = Catalog.Get(id)
	if item.rarity == "Legendary" or id == "emote_flip" then expect(Emotes.Defs[id].fx ~= nil, "Big emotes finish with a cosmetic burst: " .. id) end
end

-- Live characters: a pose moves real joints and restores them exactly. R6 works too.
do
	local live = Poses.Live(mannequin)
	local before = {}
	for _, d in ipairs(mannequin:GetDescendants()) do if d:IsA("Motor6D") then before[d] = d.C0 end end
	live:Apply(Emotes.Sample("emote_dance", 0.7))
	local changed = 0
	for motor, c0 in pairs(before) do if motor.C0 ~= c0 then changed += 1 end end
	expect(changed >= 5, "A live emote moves several joints, changed " .. changed)
	live:Restore()
	for motor, c0 in pairs(before) do expect(motor.C0 == c0, "Restore returns every joint exactly: " .. motor.Name) end
	live:Apply(Emotes.Sample("emote_wave", 1.0), 0.5)
	local half = 0
	for motor, c0 in pairs(before) do if motor.C0 ~= c0 then half += 1 end end
	expect(half >= 2, "Blended poses still move joints")
	live:Restore()
	-- R6 naming: "Right Shoulder" and "RootJoint" map to the same canonical joints.
	expect(Poses.JointName("Right Shoulder") == "RightShoulder" and Poses.JointName("RootJoint") == "Root" and Poses.JointName("Left Hip") == "LeftHip", "R6 joint names normalize")
	local r6 = roblox.Instance.new("Model")
	local torso = roblox.Instance.new("Part") torso.Name, torso.Parent = "Torso", r6
	local arm = roblox.Instance.new("Part") arm.Name, arm.Parent = "Right Arm", r6
	local shoulder = roblox.Instance.new("Motor6D")
	shoulder.Name, shoulder.Part0, shoulder.Part1, shoulder.C0, shoulder.Parent = "Right Shoulder", torso, arm, CF.new(1, 0.5, 0), torso
	local r6live = Poses.Live(r6)
	r6live:Apply(Emotes.Sample("emote_wave", 1.0))
	expect(shoulder.C0 ~= CF.new(1, 0.5, 0), "R6 shoulders respond to emotes")
	r6live:Restore()
	expect(shoulder.C0 == CF.new(1, 0.5, 0), "R6 shoulder restores exactly")
end

-- The preview moves the costume with the body: every overlay stays glued to its limb through a flip.
do
	local look = Appearance.BuildPreview("skin_dragon", "mask_astral", {trails = "trail_stardust"})
	local pv = Poses.Preview(look)
	local carriers = {}
	for _, part in ipairs(look.CatchAppearance:GetChildren()) do
		local weld = part:IsA("BasePart") and part:FindFirstChildOfClass("WeldConstraint")
		if weld then carriers[part] = {weld.Part0, weld.Part0.CFrame:ToObjectSpace(part.CFrame)} end
	end
	for _, id in ipairs({"emote_flip", "emote_dance", "emote_royal"}) do
		pv:Set(Emotes.Sample(id, Emotes.Defs[id].duration * 0.45, true), CF.new(4, 1, -2))
		for part, info in pairs(carriers) do
			local moved = info[1].CFrame:ToObjectSpace(part.CFrame)
			expect((moved.Position - info[2].Position).Magnitude < 1e-3, "Costume pieces stay glued to their body part during " .. id .. ": " .. part.Name)
		end
	end
	pv:Reset()
	local hand = look.RightHand.CFrame.Position
	pv:Set(Emotes.Sample("emote_wave", 1.1, true), CF.new())
	expect(look.RightHand.CFrame.Position ~= hand, "The preview avatar's arm moves under its costume")
	pv:Reset()
	expect((look.RightHand.CFrame.Position - hand).Magnitude < 1e-3, "Reset returns the avatar to rest")
	look:Destroy()
end

-- ---------------------------------------------------------------------------------------
-- Trails: one definition drives the live engine objects AND the preview emulation.
-- ---------------------------------------------------------------------------------------
local function near(a, b) return math.abs(a - b) < 0.004 end
local tierScore = {Rare = {}, Epic = {}, Legendary = {}}
for _, id in ipairs(Trails.Order) do
	local def = Trails.Defs[id]
	local item = Catalog.Get(id)
	expect(def.name == item.name, "Trail name matches the catalog: " .. id)
	local ribbons, emitters = #(def.ribbons or {}), #(def.emitters or {})
	expect(ribbons >= 1 and ribbons <= 3 and emitters <= 2 and Trails.ParticleRate(id) <= 20, "Trail stays inside the mobile budget: " .. id)
	-- Live objects
	local mount = roblox.Instance.new("Part")
	local created = Trails.Populate(mount, id, false)
	local trailObjects, emitterObjects = {}, {}
	for _, object in ipairs(created) do
		if object:IsA("Trail") then table.insert(trailObjects, object) else table.insert(emitterObjects, object) end
		expect(not object.Enabled, "Trails start off until the runner sprints: " .. id)
	end
	expect(#trailObjects == ribbons and #emitterObjects == emitters, "Every ribbon and emitter becomes a real engine object: " .. id)
	for index, ribbon in ipairs(def.ribbons) do
		local trail = trailObjects[index]
		expect(near(trail.Lifetime, ribbon.lifetime) and trail.FaceCamera and trail.Attachment0 ~= nil and trail.Attachment1 ~= nil, "Trail ribbon has its lifetime and ends: " .. id)
		local keypoints = trail.Color.Keypoints
		expect(#keypoints == #ribbon.color, "Trail color has every keypoint: " .. id)
		for step, point in ipairs(ribbon.color) do
			expect(near(keypoints[step].Time, point[1]) and near(keypoints[step].Value.R, point[2] / 255) and near(keypoints[step].Value.G, point[3] / 255) and near(keypoints[step].Value.B, point[4] / 255), "The live trail color matches the definition the preview uses: " .. id)
		end
		local alphas = trail.Transparency.Keypoints
		for step, point in ipairs(ribbon.alpha) do expect(near(alphas[step].Value, point[2]), "The live trail fade matches the definition: " .. id) end
		local widths = trail.WidthScale.Keypoints
		for step, point in ipairs(ribbon.width) do expect(near(widths[step].Value, point[2]), "The live trail taper matches the definition: " .. id) end
	end
	for index, spec in ipairs(def.emitters or {}) do
		local emitter = emitterObjects[index]
		expect(emitter.Name == "Trail_" .. spec.name and emitter.Rate == spec.rate and near(emitter.Lifetime.Min, spec.life[1]) and near(emitter.Lifetime.Max, spec.life[2]) and not emitter.LockedToPart, "Trail emitter has its rate and lifetime: " .. id)
		expect(near(emitter.Speed.Min, spec.speed[1]) and near(emitter.Size.Keypoints[1].Value, spec.size[1][2]) and near(emitter.Color.Keypoints[1].Value.R, spec.color[1][2] / 255), "Trail emitter speed, size and color match the definition: " .. id)
		expect(emitter.Texture:match("^rbxasset://textures/particles/") ~= nil, "Trails use only built-in particle textures: " .. id)
	end
	mount:Destroy()
	-- Emulation
	local world = roblox.Instance.new("Model")
	local emulator = Trails.Emulator.new(id, world)
	expect(emulator ~= nil and partCount(world) <= 80, "The preview emulation stays small: " .. id .. " uses " .. partCount(world) .. " parts")
	local theta, seen, maxSeen = 0, 0, 0
	for step = 1, 150 do
		theta += 0.05
		local root = CF.lookAt(V3.new(math.sin(theta) * 3, 0, -math.cos(theta) * 3), V3.new(math.sin(theta) * 3 + math.cos(theta), 0, -math.cos(theta) * 3 + math.sin(theta)))
		emulator:Step(1 / 30, root, root.LookVector * 9.5, -3)
		maxSeen = math.max(maxSeen, emulator:Visible())
		seen = emulator:Visible()
		for _, part in ipairs(world:GetDescendants()) do
			if part:IsA("BasePart") then
				for _, n in ipairs({part.Size.X, part.Size.Y, part.Size.Z, part.CFrame.Position.X, part.CFrame.Position.Y, part.CFrame.Position.Z}) do expect(finite(n), "Emulated pieces stay finite: " .. id) end
				expect(part.Size.X < 6 and part.Size.Y < 6 and part.Size.Z < 8, "Emulated pieces stay bounded: " .. id)
			end
		end
	end
	expect(maxSeen >= 6, "The emulated trail is visible while running: " .. id .. " (" .. maxSeen .. ")")
	emulator:Reset()
	expect(emulator:Visible() == 0, "Reset clears the emulated trail: " .. id)
	-- A standing runner leaves nothing new behind.
	for _ = 1, 60 do emulator:Step(1 / 30, CF.new(), V3.zero, -3) end
	expect(emulator:Visible() == 0, "A runner who stops leaves no trail: " .. id)
	emulator:Destroy()
	local score = ribbons + 2 * emitters + (def.footprints and 3 or 0)
	local tier = tierScore[item.rarity]
	if tier then table.insert(tier, score) end
end
local function average(list) local sum = 0 for _, n in ipairs(list) do sum += n end return sum / math.max(1, #list) end
expect(average(tierScore.Rare) < average(tierScore.Epic) and average(tierScore.Epic) < average(tierScore.Legendary), "Trails get more elaborate with rarity (Rare " .. average(tierScore.Rare) .. ", Epic " .. average(tierScore.Epic) .. ", Legendary " .. average(tierScore.Legendary) .. ")")
-- The named concepts exist: speed streaks, electric sparks, cosmic stardust, shadow smoke, golden footprints.
expect(#Trails.Defs.trail_streaks.ribbons == 3 and Trails.Defs.trail_sparks.emitters[1].name == "Sparks" and Trails.Defs.trail_stardust.emitters[1].name == "Stars"
	and Trails.Defs.trail_shadow.emitters[1].texture == "smoke" and Trails.Defs.trail_gold.footprints ~= nil, "Streaks, sparks, stardust, shadow smoke and golden footprints are all implemented")
-- Footprints stamp as you run, alternate feet, are bounded and fade away.
do
	local world = roblox.Instance.new("Model")
	local prints = Trails.Footprints.new(world, Trails.Defs.trail_gold.footprints)
	expect(partCount(world) == 40 and prints:Visible() == 0, "Footprints are a fixed pool")
	local x = 0
	local sides = {}
	for _ = 1, 240 do
		x += 9.5 / 30
		prints:Step(1 / 30, V3.new(x, -2.96, 0), V3.new(1, 0, 0), 9.5)
	end
	expect(prints:Visible() >= 4 and prints:Visible() <= 8, "Footprints appear behind a running character and stay within the pool")
	local lastZ
	for _, entry in ipairs(prints.prints) do
		if entry.born then
			local z = entry.parts[1].CFrame.Position.Z
			expect(math.abs(z) > 0.2 and math.abs(z) < 0.7, "Footprints alternate left and right of the path")
			expect(math.abs(entry.parts[1].CFrame.Position.Y + 2.96) < 0.01, "Footprints lie on the floor")
		end
	end
	for _ = 1, 150 do prints:Step(1 / 30, V3.new(x, -2.96, 0), V3.new(1, 0, 0), 0) end
	expect(prints:Visible() == 0, "Footprints fade away once the runner stops")
	prints:Destroy()
end
-- A character wearing a trail gets the objects, the footprint marker and on/off control.
do
	local rig = Appearance.BuildPreview("skin_courier", "", {trails = "trail_streaks"})
	local mount = rig.CatchAppearance.TrailMount
	local count = 0
	for _, child in ipairs(mount:GetChildren()) do if child:IsA("Trail") then count += 1 end end
	expect(count == 3 and rig:GetAttribute("CatchTrail") == "trail_streaks", "Speed Streaks builds three live ribbons and announces itself")
	rig:SetAttribute("CatchPreview", false)
	Trails.SetActive(rig.CatchAppearance, true)
	for _, child in ipairs(mount:GetChildren()) do if child:IsA("Trail") then expect(child.Enabled, "Sprint switches every ribbon on") end end
	Trails.SetActive(rig.CatchAppearance, false)
	for _, child in ipairs(mount:GetChildren()) do if child:IsA("Trail") then expect(not child.Enabled, "Stopping switches every ribbon off") end end
	local before = rig:GetAttribute("CatchTrail")
	Appearance.Apply(rig, "skin_courier", "", {trails = ""})
	expect(rig:GetAttribute("CatchTrail") == nil and rig.CatchAppearance:FindFirstChild("TrailMount") == nil, "Removing a trail removes its objects and marker")
	rig:Destroy()
	local gold = Appearance.BuildPreview("skin_courier", "", {trails = "trail_gold"})
	local emitters = 0
	for _, child in ipairs(gold.CatchAppearance.TrailMount:GetChildren()) do if child:IsA("ParticleEmitter") then emitters += 1 end end
	expect(emitters == 1 and gold:GetAttribute("CatchTrail") == "trail_gold", "Golden Footsteps adds glitter and tells the client to stamp footprints")
	gold:Destroy()
end

-- ---------------------------------------------------------------------------------------
-- Skins and masks: full costumes, fitted, balanced, no clipping, no floating pieces, no gameplay effect.
-- ---------------------------------------------------------------------------------------
local tiers = {Common = {}, Rare = {}, Epic = {}, Legendary = {}}
local function box(part)
	local half = part.Size / 2
	local lo, hi = V3.new(math.huge, math.huge, math.huge), V3.new(-math.huge, -math.huge, -math.huge)
	for sx = -1, 1, 2 do for sy = -1, 1, 2 do for sz = -1, 1, 2 do
		local c = part.CFrame:PointToWorldSpace(V3.new(half.X * sx, half.Y * sy, half.Z * sz))
		lo = V3.new(math.min(lo.X, c.X), math.min(lo.Y, c.Y), math.min(lo.Z, c.Z))
		hi = V3.new(math.max(hi.X, c.X), math.max(hi.Y, c.Y), math.max(hi.Z, c.Z))
	end end end
	local center, size = (lo + hi) / 2, (hi - lo) * 0.8
	return center - size / 2, center + size / 2
end
local function overlap(a, b)
	local alo, ahi = box(a)
	local blo, bhi = box(b)
	local x, y, z = math.min(ahi.X, bhi.X) - math.max(alo.X, blo.X), math.min(ahi.Y, bhi.Y) - math.max(alo.Y, blo.Y), math.min(ahi.Z, bhi.Z) - math.max(alo.Z, blo.Z)
	return (x > 0 and y > 0 and z > 0) and x * y * z or 0
end
local function headPieces(rig)
	local list = {}
	for _, part in ipairs(rig.CatchAppearance:GetChildren()) do
		local weld = part:IsA("BasePart") and part:FindFirstChildOfClass("WeldConstraint")
		if weld and weld.Part0 and weld.Part0.Name == "Head" then list[part.Name] = part end
	end
	return list
end
for _, id in ipairs(Appearance.SkinOrder) do
	local item = Catalog.Get(id)
	local rig = Appearance.BuildPreview(id, "", {})
	local count = overlayCount(rig)
	if id ~= "skin_courier" then
		table.insert(tiers[item.rarity], count)
		local def = Appearance.SkinInfo(id)
		expect(def.hides == "outfit", "A costume tucks away the player's own hair, hats and layered clothing so nothing clips: " .. id)
		expect(def.headwear == true, "Costumes declare their headwear so masks can stay clear of it: " .. id)
		-- Fitted to the avatar: shells for torso, arms and legs.
		local shells = 0
		for _, part in ipairs(rig.CatchAppearance:GetChildren()) do
			local weld = part:IsA("BasePart") and part:FindFirstChildOfClass("WeldConstraint")
			if weld and weld.Part0 and (weld.Part0.Name:match("Torso") or weld.Part0.Name:match("Arm") or weld.Part0.Name:match("Leg") or weld.Part0.Name:match("Foot")) then shells += 1 end
		end
		expect(shells >= 8, "A costume covers the body, not just the head: " .. id .. " has " .. shells .. " body pieces")
		if item.rarity == "Epic" or item.rarity == "Legendary" then expect(def.aura ~= nil, "Epic and Legendary costumes shimmer: " .. id) end
	end
	local carrier = {}
	for _, part in ipairs(rig.CatchAppearance:GetChildren()) do
		if part:IsA("BasePart") then
			local weld = part:FindFirstChildOfClass("WeldConstraint")
			expect(weld and weld.Part0 and weld.Part0.Parent == rig, "Every piece is welded to a real body part: " .. id .. "/" .. part.Name)
			expect(weld.Part0.CFrame.Position:Lerp(part.CFrame.Position, 1) ~= nil and (part.CFrame.Position - weld.Part0.CFrame.Position).Magnitude < 6.5, "No piece floats away from its body part: " .. id .. "/" .. part.Name)
			if part.Name ~= "TrailMount" and part.Name ~= "AuraMount" then
				expect(part.Transparency < 0.9, "No piece is invisible: " .. id .. "/" .. part.Name)
				expect(part.Material ~= roblox.Enum.Material.Neon, "No neon: " .. id .. "/" .. part.Name)
			end
		end
	end
	rig:Destroy()
end
expect(average(tiers.Common) < average(tiers.Rare) + 4 and average(tiers.Rare) < average(tiers.Epic) and average(tiers.Epic) < average(tiers.Legendary) + 6,
	"Premium costumes are visibly more elaborate (Common " .. average(tiers.Common) .. ", Rare " .. average(tiers.Rare) .. ", Epic " .. average(tiers.Epic) .. ", Legendary " .. average(tiers.Legendary) .. ")")
expect(average(tiers.Epic) > average(tiers.Common) * 1.25 and average(tiers.Legendary) > average(tiers.Common) * 1.4, "Epic and Legendary costumes have clearly more pieces than the basic ones")
-- Masks never collide with costumes (touching edges only), and ear-style masks leave the top of the head to the costume.
local maskPieces = {}
for _, id in ipairs(Appearance.MaskOrder) do
	local rig = Appearance.BuildPreview("skin_courier", id, {})
	local plain = Appearance.BuildPreview("skin_courier", "", {})
	local count = overlayCount(rig)
	expect(count >= 5 and count <= 18, "Mask has real geometry but stays light: " .. id .. " " .. count)
	maskPieces[id] = headPieces(rig)
	local face = rig.Head.CFrame
	for name, part in pairs(maskPieces[id]) do
		local local_ = face:ToObjectSpace(part.CFrame).Position
		expect(local_.Z < 0.55 or name:match("Strap") or name:match("Tail") or name:match("Knot") or name:match("Arm_") or name:match("Module") or name:match("^Top"), "Mask pieces sit on the front of the face: " .. id .. "/" .. name)
		expect(math.abs(local_.X) < 1.1 and local_.Y > -0.9 and local_.Y < 2.2, "Mask pieces stay around the head: " .. id .. "/" .. name)
	end
	rig:Destroy() plain:Destroy()
end
local worstOverlap, clippedCombos = 0, 0
for _, skinId in ipairs(Appearance.SkinOrder) do
	local skinRig = Appearance.BuildPreview(skinId, "", {})
	local skinHead = headPieces(skinRig)
	for _, maskId in ipairs(Appearance.MaskOrder) do
		local both = Appearance.BuildPreview(skinId, maskId, {})
		local bothHead = headPieces(both)
		local withTop = 0
		for name in pairs(bothHead) do if name:match("^Top") then withTop += 1 end end
		if skinId ~= "skin_courier" then expect(withTop == 0, "Costumes with headwear never get mask ears, stems or rings on top: " .. skinId .. "/" .. maskId) end
		for maskName in pairs(maskPieces[maskId]) do
			for skinName in pairs(skinHead) do
				local a, b = bothHead[maskName], bothHead[skinName]
				if a and b and not maskName:match("Strap$") then
					local volume = overlap(a, b)
					worstOverlap = math.max(worstOverlap, volume)
					if volume > 0.03 then clippedCombos += 1 end
				end
			end
		end
		both:Destroy()
	end
	skinRig:Destroy()
end
expect(clippedCombos == 0, "No mask piece clips a costume piece (worst overlap " .. string.format("%.3f", worstOverlap) .. " cubic studs, " .. clippedCombos .. " clipping combinations)")
-- The ear/ring pieces do show on the plain avatar.
local cat = Appearance.BuildPreview("skin_courier", "mask_cat", {})
expect(headPieces(cat)["TopCatEar_Left"] ~= nil, "Cat ears show when no headwear is worn")
cat:Destroy()
-- A mask hides face accessories so glasses never poke through it; the untouched look keeps them.
do
	local rig = Appearance.BuildPreview("skin_courier", "")
	local glasses = roblox.Instance.new("Accessory")
	glasses.Name, glasses.AccessoryType, glasses.Parent = "Glasses", roblox.Enum.AccessoryType.Face, rig
	local handle = roblox.Instance.new("Part") handle.Name, handle.Parent = "Handle", glasses
	Appearance.Apply(rig, "skin_courier", "", {})
	expect(handle.Transparency == 0, "Face accessories stay visible without a mask")
	Appearance.Apply(rig, "skin_courier", "mask_smile", {})
	expect(handle.Transparency == 1 and handle:GetAttribute("CatchOriginalTransparency") == 0, "A mask hides face accessories instead of clipping through them")
	Appearance.Apply(rig, "skin_courier", "", {})
	expect(handle.Transparency == 0, "Face accessories come back when the mask comes off")
	rig:Destroy()
end
-- Layered clothing, shoes and shoulder items are hidden by costumes and restored afterwards.
do
	local rig = Appearance.BuildPreview("skin_courier", "")
	local kinds = {Jacket = roblox.Enum.AccessoryType.Jacket, Shoulder = roblox.Enum.AccessoryType.Shoulder, LeftShoe = roblox.Enum.AccessoryType.LeftShoe, Waist = roblox.Enum.AccessoryType.Waist}
	local handles = {}
	for name, kind in pairs(kinds) do
		local accessory = roblox.Instance.new("Accessory")
		accessory.Name, accessory.AccessoryType, accessory.Parent = name, kind, rig
		local handle = roblox.Instance.new("Part") handle.Name, handle.Parent = "Handle", accessory
		handles[name] = handle
	end
	Appearance.Apply(rig, "skin_streetwear", "", {})
	for name, handle in pairs(handles) do expect(handle.Transparency == 1, "A costume hides the player's own " .. name .. " accessory") end
	Appearance.Apply(rig, "skin_courier", "", {})
	for name, handle in pairs(handles) do expect(handle.Transparency == 0, "The player's " .. name .. " accessory is restored") end
	rig:Destroy()
end

-- The named showpieces exist as full designs.
local function names(skinId)
	local rig = Appearance.BuildPreview(skinId, "", {})
	local set = {}
	for _, part in ipairs(rig.CatchAppearance:GetChildren()) do set[part.Name] = true end
	rig:Destroy()
	return set
end
do
	local shadow, phantom, street, trickster, galaxy = names("skin_ninja"), names("skin_neonphantom"), names("skin_streetwear"), names("skin_trickster"), names("skin_galaxy")
	expect(Catalog.Get("skin_ninja").name == "Shadow Runner" and shadow.HoodShell and shadow.ScarfTail1 and shadow.Sleeve_Left and shadow.Thigh_Right and shadow.Sole_Left, "Shadow Runner: hooded kit, scarf, sleeves, trousers and boots")
	expect(Catalog.Get("skin_neonphantom").name == "Mall Phantom" and phantom.Cape and phantom.CapeLining and phantom.CoatTail_Left and phantom.HatCrown and phantom.WhiteCuff_Left and phantom.ShirtFront, "Mall Phantom: tailcoat, lined cape, top hat and gloves")
	expect(Catalog.Get("skin_streetwear").name == "Street Legend" and street.JacketCollar and street.CargoPocket_Left and street.BucketBrim and street.ChainPendant and street.BagBody and street.Shoe_Left, "Street Legend: varsity jacket, cargo pants, bucket hat, chain, bag and sneakers")
	expect(Catalog.Get("skin_trickster").name == "Royal Trickster" and trickster.ShirtHalf_Left and trickster.ShirtHalf_Right and trickster.Ruffle0 and trickster.HornBell2 and trickster.ShoeCurl_Left and trickster.Forearm_Right, "Royal Trickster: motley suit, ruffle, three-horned crown and curled shoes")
	expect(Catalog.Get("skin_galaxy").name == "Galaxy Escape Artist" and galaxy.CapeNight and galaxy.CapeNebula and galaxy.CapeWisp and galaxy.Planet and galaxy.PlanetRing and galaxy.StarPatch1 and galaxy.MoonClasp, "Galaxy Escape Artist: star suit, three-layer cosmic cape, planet hat and moon clasp")
end
-- Rarity tiers exist and every name is distinct.
do
	local counts, seen = {Common = 0, Rare = 0, Epic = 0, Legendary = 0}, {}
	for _, id in ipairs(Appearance.SkinOrder) do
		local item = Catalog.Get(id)
		counts[item.rarity] += 1
		expect(not seen[item.name], "Distinct skin names: " .. item.name)
		seen[item.name] = true
	end
	for _, id in ipairs(Appearance.MaskOrder) do
		local item = Catalog.Get(id)
		expect(not seen[item.name], "Distinct mask names: " .. item.name)
		seen[item.name] = true
	end
	expect(counts.Common >= 2 and counts.Rare >= 3 and counts.Epic >= 5 and counts.Legendary >= 3, "Skins span Common, Rare, Epic and Legendary")
end

-- ---------------------------------------------------------------------------------------
-- Collections: complete matching sets, fairly priced, honestly configured.
-- ---------------------------------------------------------------------------------------
local collections = {"bundle_shadow", "bundle_phantom", "bundle_trickster", "bundle_galaxy", "vip_founder"}
for _, id in ipairs(collections) do
	local item = Catalog.Get(id)
	local categories, robux, coins = {}, 0, 0
	for _, grantedId in ipairs(item.grants) do
		local granted = Catalog.Get(grantedId)
		categories[granted.category] = (categories[granted.category] or 0) + 1
		if granted.currency == "Robux" then robux += granted.price elseif granted.currency == "Coins" then coins += granted.price end
	end
	expect(categories.skins == 1 and categories.masks == 1 and categories.trails == 1 and categories.emotes == 1 and #item.grants == 4, "A collection is an outfit, a mask, a trail and an emote: " .. id)
	expect(Catalog.IsReady(item, defs), "Every piece of a collection is implemented: " .. id)
	expect(item.currency == "Robux" and item.gamePassId == 0, "Collections are unconfigured Robux items until a real pass ID is entered: " .. id)
	expect(item.price <= robux + coins * 0.12, "A collection never costs more than its pieces would: " .. id)
	expect(item.price >= (robux + coins * 0.098) * 0.4, "Collections are a discount, not a giveaway: " .. id)
	expect(not item.description:lower():find("limited") and not item.description:lower():find("only today") and not item.description:lower():find("last chance"), "No fake scarcity in collection copy: " .. id)
end
-- Nothing is locked: every item can be obtained today (free, earned, or bought with coins), and collections are a
-- discount on the coin prices of their pieces too.
for _, item in pairs(Catalog.Items) do
	local coins = Catalog.CoinPrice(item)
	expect(item.currency == "Free" or item.currency == "Milestone" or (coins ~= nil and coins > 0 and coins % 1 == 0), "Every cosmetic can be obtained right now: " .. item.id)
	expect(item.currency ~= "Robux" or Catalog.RobuxConfigured(item) == (item.gamePassId > 0), "Robux checkout exists only with a real pass ID: " .. item.id)
end
for _, id in ipairs(collections) do
	local item = Catalog.Get(id)
	local sum, highest = 0, 0
	for _, grantedId in ipairs(item.grants) do
		local price = Catalog.CoinPrice(Catalog.Get(grantedId))
		expect(price ~= nil, "Every collection piece has a coin price: " .. grantedId)
		sum += price
		highest = math.max(highest, price)
	end
	local coins = Catalog.CoinPrice(item)
	expect(coins < sum and coins >= sum * 0.6 and coins > highest, "A collection costs less in coins than its pieces but more than its best piece: " .. id .. " " .. coins .. " vs " .. sum)
end
do
	local function average(category, rarity)
		local total, count = 0, 0
		for _, item in ipairs(Catalog.ForCategory(category)) do
			local coins = Catalog.CoinPrice(item)
			if item.rarity == rarity and coins then total += coins count += 1 end
		end
		return count > 0 and total / count or 0
	end
	expect(average("skins", "Legendary") > average("skins", "Epic") and average("skins", "Epic") > average("skins", "Rare") and average("skins", "Rare") > average("skins", "Common"), "Skin coin prices climb with rarity")
	expect(Catalog.CoinPrice(Catalog.Get("skin_galaxy")) <= 8000 and Catalog.CoinPrice(Catalog.Get("skin_ninja")) <= 3500, "Premium coin prices stay reachable")
end
for _, item in pairs(Catalog.Items) do
	if item.currency == "Robux" then expect(item.gamePassId == 0, "No fake product IDs ship in the catalog: " .. item.id) end
	local text = (item.description or ""):lower()
	expect(not text:find("faster") and not text:find("speed boost") and not text:find("advantage") or text:find("no ") ~= nil or text:find("never") ~= nil, "Cosmetic copy promises no gameplay advantage: " .. item.id)
end

-- ---------------------------------------------------------------------------------------
-- The showroom: auto-framed cameras show the whole model for every skin, mask, trail and emote.
-- ---------------------------------------------------------------------------------------
local world = roblox.Instance.new("WorldModel")
local function frameCheck(stage, aspect, label)
	local lo, hi = stage.bounds[1], stage.bounds[2]
	local tan = math.tan(math.rad(stage.fov) / 2)
	expect(stage.distance * tan >= (hi.Y - lo.Y) / 2 - 1e-6 and stage.distance * tan * aspect >= math.max(hi.X - lo.X, hi.Z - lo.Z) / 2 - 1e-6, "The whole model fits the camera: " .. label)
	expect(finite(stage.distance) and stage.distance > 4 and stage.distance < 40, "Sensible camera distance: " .. label)
end
for _, aspect in ipairs({0.45, 0.9, 1.6}) do
	for _, id in ipairs(Appearance.SkinOrder) do
		local rig = Appearance.BuildPreview(id, "mask_astral", {})
		rig.Parent = world
		local camera = roblox.Instance.new("Camera")
		local stage = PreviewStage.new({world = world, camera = camera, rig = rig, kind = "skin", id = id, aspect = aspect})
		frameCheck(stage, aspect, id .. " @" .. aspect)
		stage:Update(0.1)
		expect((camera.CFrame.Position - stage.center).Magnitude > stage.distance * 0.99, "The camera orbits at the framed distance: " .. id)
		stage:Destroy() rig:Destroy()
	end
end
for _, id in ipairs(Appearance.MaskOrder) do
	local rig = Appearance.BuildPreview("skin_courier", id, {})
	rig.Parent = world
	local stage = PreviewStage.new({world = world, camera = roblox.Instance.new("Camera"), rig = rig, kind = "mask", id = id, aspect = 0.9})
	frameCheck(stage, 0.9, "mask " .. id)
	local lo, hi = stage.bounds[1], stage.bounds[2]
	expect(hi.Y - lo.Y < 3.4 and hi.Y > 2.2, "Mask previews are a head close-up: " .. id)
	stage:Destroy() rig:Destroy()
end
for _, id in ipairs(Emotes.Order) do
	local rig = Appearance.BuildPreview("skin_dragon", "", {})
	rig.Parent = world
	local stage = PreviewStage.new({world = world, camera = roblox.Instance.new("Camera"), rig = rig, kind = "emote", id = id, aspect = 0.9})
	local lo, hi = stage.bounds[1], stage.bounds[2]
	local seenLowest, seenHighest = math.huge, -math.huge
	-- Everything the emote does, including the dragon's wings, fits the frame.
	local pv = Poses.Preview(rig)
	for step = 0, 24 do
		pv:Set(Emotes.Sample(id, Emotes.Defs[id].duration * step / 24, true), CF.new())
		local slo, shi = PreviewStage.Bounds(rig)
		seenLowest, seenHighest = math.min(seenLowest, slo.Y), math.max(seenHighest, shi.Y)
		expect(slo.Y >= lo.Y - 1.0 and shi.Y <= hi.Y + 1.0, "The emote preview frame holds the whole performance: " .. id)
	end
	frameCheck(stage, 0.9, "emote " .. id)
	stage:Destroy() rig:Destroy()
end
for _, id in ipairs(Trails.Order) do
	local rig = Appearance.BuildPreview("skin_courier", "", {trails = id})
	rig.Parent = world
	local camera = roblox.Instance.new("Camera")
	local stage = PreviewStage.new({world = world, camera = camera, rig = rig, kind = "trail", id = id, aspect = 1.2})
	frameCheck(stage, 1.2, "trail " .. id)
	for _ = 1, 100 do stage:Update(1 / 30) end
	local runner = stage.runnerFrame.Position
	expect(math.abs(runner.X) <= 3.3 and math.abs(runner.Z) <= 3.3 and math.abs(runner.Y) < 0.01, "The runner stays on its looping track: " .. id)
	-- The runner is always inside the camera's view cone.
	local toRunner = (runner - camera.CFrame.Position).Unit
	expect(toRunner:Dot(camera.CFrame.LookVector) > math.cos(math.rad(stage.fov)), "The runner is always in view: " .. id)
	expect(stage.emulator:Visible() >= 6, "The trail draws behind the runner: " .. id)
	local before = stage.replays
	stage:Replay()
	expect(stage.replays == before + 1 and stage.time == 0 and stage.emulator:Visible() == 0, "Replay restarts the lap and clears the trail: " .. id)
	stage:SetMotion(false)
	expect(stage.emulator:Visible() >= 4, "Reduced motion shows a finished trail frozen in place: " .. id)
	local frozen = stage.emulator:Visible()
	stage:Update(0.5)
	expect(stage.emulator:Visible() == frozen, "A frozen trail stays put: " .. id)
	stage:Destroy() rig:Destroy()
end
-- Catch effects burst, replay and clean up.
do
	local rig = Appearance.BuildPreview("skin_courier", "", {})
	rig.Parent = world
	local stage = PreviewStage.new({world = world, camera = roblox.Instance.new("Camera"), rig = rig, kind = "tag", id = "tag_confetti", aspect = 1})
	local function pieces() local n = 0 for _, p in ipairs(world:GetChildren()) do if p.Name:match("^Burst") then n += 1 end end return n end
	expect(pieces() == 22, "A catch effect bursts as soon as it is selected")
	for _ = 1, 40 do stage:Update(1 / 30) end
	expect(pieces() == 0, "The burst fades away")
	stage:Replay()
	expect(pieces() == 22, "Replay triggers the burst again")
	stage:Destroy()
	expect(pieces() == 0, "Closing the preview removes the effect")
	rig:Destroy()
end
-- Stage controls.
do
	local rig = Appearance.BuildPreview("skin_dragon", "", {})
	rig.Parent = world
	local camera = roblox.Instance.new("Camera")
	local stage = PreviewStage.new({world = world, camera = camera, rig = rig, kind = "skin", aspect = 0.9, angle = 0})
	stage:Rotate(math.pi / 4)
	for _ = 1, 40 do stage:Update(0.05) end
	expect(math.abs(stage.angle - math.pi / 4) < 0.01, "Rotate eases to the requested angle")
	stage:Back()
	for _ = 1, 60 do stage:Update(0.05) end
	local toCamera = (camera.CFrame.Position - stage.center)
	expect(toCamera.Z > stage.distance * 0.9, "Back view puts the camera behind the character (wings and cape in view)")
	stage:Front()
	for _ = 1, 60 do stage:Update(0.05) end
	expect((camera.CFrame.Position - stage.center).Z < -stage.distance * 0.9, "Front view faces the character")
	stage:SetAngle(1.0)
	expect(stage.angle == 1.0 and stage.targetAngle == 1.0, "SetAngle jumps and holds")
	stage:Destroy() rig:Destroy()
end

print("Cosmetics audit passed: " .. checks .. " checks across " .. #Appearance.SkinOrder .. " skins, " .. #Appearance.MaskOrder .. " masks, " .. #Trails.Order .. " trails, " .. #Emotes.Order .. " emotes, " .. #Emotes.VictoryOrder .. " victory poses and " .. #collections .. " collections")
