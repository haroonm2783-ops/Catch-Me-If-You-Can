-- Avatar-first cosmetics, shared by live characters and viewport previews.
--
-- Players keep their OWN Roblox avatar: body, face, proportions and Roblox's standard animations are never
-- replaced. A skin is an optional costume of chunky welded, massless, non-colliding pieces built from plain
-- parts (so it needs no uploaded assets): body-conforming shells for the torso, arms and legs, plus hats, hoods,
-- capes, wings, tails and boots. The player's own hair, hats and layered clothing are hidden while a costume is
-- worn and restored exactly afterwards. Epic and Legendary skins add an ambient aura.
-- Cosmetic only: nothing here touches collision, speed, hitboxes or tag raycasts.
local Trails = require(script.Parent:WaitForChild("Trails"))

local Appearance = {Version = 5}

local C = Color3.fromRGB
local SIDES = {{"Left", -1}, {"Right", 1}}

-- Default R15 part sizes. Pieces are authored in studs against these and scaled per rig,
-- so BodyScale, R6 fitting and Rthro-ish proportions keep the same relative fit.
local nominal = {
	Head = Vector3.new(1.2, 1.2, 1.2), UpperTorso = Vector3.new(2, 1.6, 1), LowerTorso = Vector3.new(2, 0.4, 1),
	LeftUpperArm = Vector3.new(1, 1.2, 1), RightUpperArm = Vector3.new(1, 1.2, 1),
	LeftLowerArm = Vector3.new(1, 1.05, 1), RightLowerArm = Vector3.new(1, 1.05, 1),
	LeftHand = Vector3.new(1, 0.3, 1), RightHand = Vector3.new(1, 0.3, 1),
	LeftUpperLeg = Vector3.new(1, 1.2, 1), RightUpperLeg = Vector3.new(1, 1.2, 1),
	LeftLowerLeg = Vector3.new(1, 1.2, 1), RightLowerLeg = Vector3.new(1, 1.2, 1),
	LeftFoot = Vector3.new(1, 0.3, 1), RightFoot = Vector3.new(1, 0.3, 1),
	HumanoidRootPart = Vector3.new(2, 2, 1),
}
local function mul(a, b) return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z) end
local function offset(x, y, z, rx, ry, rz)
	return CFrame.new(x, y, z) * CFrame.Angles(math.rad(rx or 0), math.rad(ry or 0), math.rad(rz or 0))
end

-- Experience avatar settings can override a place's R15 preference. Fit the same
-- authored outfit to R6 limb sections without replacing joints or the character.
local r6Segments = {
	UpperTorso = {"Torso", Vector3.new(2, 1.6, 1), Vector3.new(0, 0.2, 0)},
	LowerTorso = {"Torso", Vector3.new(2, 0.4, 1), Vector3.new(0, -0.8, 0)},
}
for _, side in ipairs({"Left", "Right"}) do
	r6Segments[side .. "UpperArm"] = {side .. " Arm", Vector3.new(1, 0.8, 1), Vector3.new(0, 0.6, 0)}
	r6Segments[side .. "LowerArm"] = {side .. " Arm", Vector3.new(1, 0.7, 1), Vector3.new(0, -0.15, 0)}
	r6Segments[side .. "Hand"] = {side .. " Arm", Vector3.new(1, 0.5, 1), Vector3.new(0, -0.75, 0)}
	r6Segments[side .. "UpperLeg"] = {side .. " Leg", Vector3.new(1, 0.8, 1), Vector3.new(0, 0.6, 0)}
	r6Segments[side .. "LowerLeg"] = {side .. " Leg", Vector3.new(1, 0.7, 1), Vector3.new(0, -0.15, 0)}
	r6Segments[side .. "Foot"] = {side .. " Leg", Vector3.new(1, 0.5, 1), Vector3.new(0, -0.75, 0)}
end
local function bodyPart(rig, name)
	local actual = rig:FindFirstChild(name)
	if actual and actual:IsA("BasePart") then return actual end
	local segment = r6Segments[name]
	local limb = segment and rig:FindFirstChild(segment[1])
	if not limb or not limb:IsA("BasePart") then return nil end
	local standard = segment[1] == "Torso" and Vector3.new(2, 2, 1) or Vector3.new(1, 2, 1)
	local scale = Vector3.new(limb.Size.X / standard.X, limb.Size.Y / standard.Y, limb.Size.Z / standard.Z)
	return {Name = name, Size = mul(segment[2], scale), CFrame = limb.CFrame * CFrame.new(mul(segment[3], scale)), Anchored = limb.Anchored, Part = limb}
end
function Appearance.IsRigReady(rig)
	if not rig or not rig:IsA("Model") then return false end
	for name in pairs(nominal) do if not bodyPart(rig, name) then return false end end
	return rig:FindFirstChildOfClass("Humanoid") ~= nil
end

-- Heads are scaled uniformly from their visible size so classic (2x1x1 + head mesh) and
-- modern mesh heads both keep hats in proportion.
local function headUnit(head)
	local mesh = head:FindFirstChildOfClass("SpecialMesh")
	local factor = mesh and mesh.Scale.Y or 1
	return math.clamp(head.Size.Y * factor / 1.2, 0.6, 2)
end

local function attach(folder, target, name, size, cf, color, material, shape, opts)
	if not target then return nil end
	local scale
	if target.Name == "Head" then
		local unit = headUnit(target)
		scale = Vector3.new(unit, unit, unit)
	else
		local base = nominal[target.Name] or target.Size
		scale = Vector3.new(target.Size.X / base.X, target.Size.Y / base.Y, target.Size.Z / base.Z)
	end
	local part = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	part.Name = name
	-- Roblox cylinders run along their X axis. "Disc" faces forward (authored width, height,
	-- thickness) and "Can" stands upright (authored width, height, depth), so pieces read naturally.
	local axisFix = CFrame.new()
	local scaled = mul(size, scale)
	if shape == "Disc" then
		scaled = Vector3.new(scaled.Z, scaled.X, scaled.Y)
		axisFix = CFrame.Angles(0, math.rad(90), 0)
		shape = "Cylinder"
	elseif shape == "Can" then
		scaled = Vector3.new(scaled.Y, scaled.X, scaled.Z)
		axisFix = CFrame.Angles(0, 0, math.rad(90))
		shape = "Cylinder"
	end
	part.Size = scaled
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape == "Ball" then part.Shape = Enum.PartType.Ball end
	if shape == "Cylinder" then part.Shape = Enum.PartType.Cylinder end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = false
	part.Massless = true
	if opts and opts.transparency then part.Transparency = opts.transparency end
	-- Live roots are temporarily anchored by head starts and vaults. A welded
	-- cosmetic must never keep that avatar anchored after the move ends.
	part.Anchored = folder.Parent:GetAttribute("CatchPreview") == true and target.Anchored
	part.CFrame = target.CFrame * CFrame.new(mul(cf.Position, scale)) * (cf - cf.Position) * axisFix
	part.Parent = folder
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = type(target) == "table" and target.Part or target, part
	weld.Parent = part
	return part
end

-- Stable per-player tone and shirt color for the fallback mannequin only. Live avatars keep their own.
local MANNEQUIN_TONES = {C(255, 224, 205), C(240, 196, 150), C(222, 164, 112), C(190, 128, 84), C(140, 90, 62), C(250, 214, 96)}
local function toneFor(identity)
	return MANNEQUIN_TONES[(math.abs(identity and identity.userId or 0) % #MANNEQUIN_TONES) + 1]
end
function Appearance.IdentityColor(userId)
	local hue = ((math.abs(tonumber(userId) or 0) * 37) % 360) / 360
	return Color3.fromHSV(hue, 0.65, 1)
end


-- ---------------------------------------------------------------------------------------
-- Skins. Each definition may declare:
--   hides      "hair" (hats/hoods) or "outfit" (a full costume) hides the player's own hair, hats and layered
--              clothing so nothing clips through the costume (restored exactly when the look changes)
--   headwear   true when the look sits on the head; masks then leave their "Top..." pieces off so nothing collides
--   tint       full-body recolor (the gold statue), reversible
--   aura       ambient particles for Epic and Legendary looks
--   build      the overlay parts
-- A costume is made of body-conforming "shells" (slightly larger than the avatar's own limbs, so every
-- player's face, head and proportions still show) plus props: hats, hoods, capes, wings, boots, scarves.
-- Shapes are bold and simple so they read at a distance on a phone.
-- ---------------------------------------------------------------------------------------
local skins = {}
local M = Enum.Material
local V = Vector3.new

local function wristbands(k, color, material)
	for _, s in ipairs(SIDES) do
		k.p(s[1] .. "LowerArm", "Wristband_" .. s[1], V(1.1, 0.24, 1.1), offset(0, -0.34, 0), color, material)
	end
end

-- A body-conforming shell: the avatar's own part, grown a little, in a costume color.
local function shell(k, target, name, color, grow, material, shift, shape)
	return k.p(target, name, nominal[target] + (grow or V(0.12, 0.04, 0.12)), shift or offset(0, 0, 0), color, material, shape)
end

-- Complete clothing in one call. Every field is optional, so short sleeves, bare hands and shorts are easy.
--   torso hips sleeve forearm glove thigh shin shoe sole   colors (a field may be {Left = c, Right = c})
--   mat     material of the cloth pieces (default Fabric), shoeMat/gloveMat default SmoothPlastic
local function suit(k, o)
	local cloth = o.mat or M.Fabric
	local function side(value, name) if type(value) == "table" and value.Left then return value[name] end return value end
	if o.torso then shell(k, "UpperTorso", "Shirt", o.torso, V(0.14, 0.06, 0.14), cloth) end
	if o.hips then shell(k, "LowerTorso", "Hips", o.hips, V(0.14, 0.06, 0.14), cloth) end
	for _, s in ipairs(SIDES) do
		local n = s[1]
		if o.sleeve then shell(k, n .. "UpperArm", "Sleeve_" .. n, side(o.sleeve, n), V(0.12, 0.04, 0.12), cloth) end
		if o.forearm then shell(k, n .. "LowerArm", "Forearm_" .. n, side(o.forearm, n), V(0.12, 0.04, 0.12), cloth) end
		if o.glove then shell(k, n .. "Hand", "Glove_" .. n, side(o.glove, n), V(0.14, 0.14, 0.14), o.gloveMat, offset(0, -0.04, 0)) end
		if o.thigh then shell(k, n .. "UpperLeg", "Thigh_" .. n, side(o.thigh, n), V(0.12, 0.04, 0.12), cloth) end
		if o.shin then shell(k, n .. "LowerLeg", "Shin_" .. n, side(o.shin, n), V(0.12, 0.04, 0.12), cloth) end
		if o.shoe then
			k.p(n .. "Foot", "Shoe_" .. n, V(1.14, 0.46, 1.3), offset(0, 0.06, -0.12), side(o.shoe, n), o.shoeMat)
			if o.sole then k.p(n .. "Foot", "Sole_" .. n, V(1.18, 0.14, 1.34), offset(0, -0.14, -0.12), side(o.sole, n)) end
		end
	end
end

-- A ring that wraps a limb or the torso: cuffs, stripes, belts, hems.
local function ring(k, target, name, color, y, height, grow, material)
	return k.p(target, name, V(nominal[target].X + grow, height, nominal[target].Z + grow), offset(0, y, 0), color, material)
end

-- Default: nothing is changed. The player's own avatar is the starting look.
skins.skin_courier = {build = function() end}

-- COMMON ---------------------------------------------------------------------------------
skins.skin_rooftop = { -- Skate Kid
	hides = "outfit", headwear = true,
	build = function(k)
		local yellow, white, red, denim, ink = C(255, 208, 40), C(250, 250, 250), C(236, 60, 70), C(58, 104, 206), C(40, 40, 52)
		suit(k, {torso = yellow, hips = yellow, sleeve = yellow, forearm = yellow, thigh = denim, shin = denim, shoe = white, sole = red})
		-- Beanie with a fold, a stripe and a pompom.
		k.p("Head", "Beanie", V(1.4, 0.95, 1.4), offset(0, 0.56, 0.02), yellow, nil, "Ball")
		k.p("Head", "BeanieFold", V(1.42, 0.26, 1.42), offset(0, 0.4, 0.02), white, nil, "Can")
		k.p("Head", "BeanieStripe", V(1.36, 0.12, 1.36), offset(0, 0.78, 0.02), red, nil, "Can")
		k.p("Head", "Pompom", V(0.42, 0.42, 0.42), offset(0, 1.12, 0.02), red, nil, "Ball")
		-- Hoodie pocket and drawstrings, knee pads.
		k.p("UpperTorso", "HoodiePocket", V(1.2, 0.5, 0.06), offset(0, -0.45, -0.6), C(236, 176, 24))
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "Drawstring_" .. s[1], V(0.07, 0.5, 0.07), offset(s[2] * 0.2, 0.42, -0.6), white)
			k.p(s[1] .. "LowerLeg", "KneePad_" .. s[1], V(1.2, 0.36, 1.2), offset(0, 0.46, -0.04), red, M.SmoothPlastic)
		end
		-- A deck on the back gives a clear silhouette from behind.
		k.p("UpperTorso", "SkateDeck", V(1.0, 2.7, 0.14), offset(0, -0.1, 0.66, 0, 0, 12), C(140, 80, 230))
		k.p("UpperTorso", "DeckGrip", V(0.9, 2.5, 0.05), offset(0, -0.1, 0.74, 0, 0, 12), ink)
		for _, y in ipairs({-1.0, 0.8}) do
			for _, x in ipairs({-0.32, 0.32}) do
				k.p("UpperTorso", "SkateWheel", V(0.26, 0.26, 0.26), offset(x - y * 0.06, y, 0.84), white, nil, "Ball")
			end
		end
	end,
}

skins.skin_pizza = { -- Pizza Courier
	hides = "outfit", headwear = true,
	build = function(k)
		local red, white, cheese, pepperoni, black = C(230, 50, 50), C(255, 255, 255), C(255, 196, 60), C(200, 40, 40), C(40, 40, 52)
		-- Short-sleeve polo (forearms stay yours), black work pants, white sneakers.
		suit(k, {torso = red, hips = red, sleeve = red, thigh = black, shin = black, shoe = white, sole = red})
		for _, s in ipairs(SIDES) do
			ring(k, s[1] .. "UpperArm", "SleeveHem_" .. s[1], white, -0.5, 0.14, 0.18)
			k.p("UpperTorso", "CollarFlap_" .. s[1], V(0.5, 0.3, 0.1), offset(s[2] * 0.32, 0.72, -0.56, 0, 0, s[2] * 22), white)
		end
		k.p("UpperTorso", "NameTag", V(0.4, 0.4, 0.06), offset(0.55, 0.2, -0.6), cheese, nil, "Disc")
		-- Delivery cap.
		k.p("Head", "CapCrown", V(1.38, 0.8, 1.38), offset(0, 0.56, 0.02), red, nil, "Ball")
		k.p("Head", "CapBrim", V(1.1, 0.09, 0.7), offset(0, 0.46, -0.82, 10), white)
		k.p("Head", "CapBadge", V(0.44, 0.44, 0.06), offset(0, 0.7, -0.66, -20), cheese, nil, "Disc")
		k.p("Head", "CapPepperoni", V(0.14, 0.14, 0.06), offset(0.06, 0.72, -0.7, -20), pepperoni, nil, "Disc")
		-- A big flat delivery box carried on the back, with a pizza circle on the lid.
		k.p("UpperTorso", "PizzaBox", V(2.0, 2.0, 0.4), offset(0, 0.0, 0.72), white)
		k.p("UpperTorso", "BoxStripe", V(2.04, 0.3, 0.42), offset(0, 0.62, 0.72), red)
		k.p("UpperTorso", "PizzaDisc", V(1.3, 1.3, 0.06), offset(0, -0.2, 0.95), cheese, nil, "Disc")
		for i, p in ipairs({{-0.3, 0.0}, {0.3, -0.1}, {0, -0.55}}) do
			k.p("UpperTorso", "PizzaPepperoni" .. i, V(0.26, 0.26, 0.06), offset(p[1], p[2] - 0.2, 0.99), pepperoni, nil, "Disc")
		end
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "BoxStrap_" .. s[1], V(0.2, 1.7, 0.06), offset(s[2] * 0.62, 0, -0.62), red)
		end
	end,
}

-- RARE -----------------------------------------------------------------------------------
skins.skin_bunny = { -- Bunny Hop
	hides = "outfit", headwear = true,
	build = function(k)
		local white, pink, deep = C(252, 250, 250), C(255, 160, 205), C(255, 100, 170)
		suit(k, {torso = white, hips = white, sleeve = white, forearm = white, glove = pink, thigh = white, shin = white, shoe = white, sole = pink})
		k.p("UpperTorso", "BellyPatch", V(1.1, 1.0, 0.06), offset(0, -0.1, -0.6), pink, nil, "Disc")
		-- Floppy ears on a hood band.
		k.p("Head", "BunnyBand", V(1.3, 0.12, 1.3), offset(0, 0.52, 0.02), pink, nil, "Can")
		for _, s in ipairs(SIDES) do
			k.p("Head", "BunnyEar_" .. s[1], V(0.46, 1.7, 0.3), offset(s[2] * 0.3, 1.3, 0.05, 0, 0, s[2] * -9), white, M.Fabric, "Ball")
			k.p("Head", "BunnyEarInner_" .. s[1], V(0.26, 1.35, 0.16), offset(s[2] * 0.32, 1.28, -0.07, 0, 0, s[2] * -9), pink, nil, "Ball")
			-- Slipper toe pads.
			k.p(s[1] .. "Foot", "ToePad_" .. s[1], V(0.7, 0.1, 0.5), offset(0, 0.3, -0.5), pink, nil, "Can")
		end
		k.p("LowerTorso", "BunnyTail", V(0.78, 0.78, 0.78), offset(0, 0.0, 0.62), white, M.Fabric, "Ball")
		-- Big ribbon collar.
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "BowWing_" .. s[1], V(0.56, 0.4, 0.14), offset(s[2] * 0.34, 0.7, -0.6, 0, 0, s[2] * 14), deep)
		end
		k.p("UpperTorso", "BowKnot", V(0.26, 0.26, 0.2), offset(0, 0.7, -0.62), deep, nil, "Ball")
	end,
}

skins.skin_panda = { -- Bamboo Panda
	hides = "outfit", headwear = true,
	build = function(k)
		local white, black, green, dark = C(250, 250, 250), C(34, 34, 40), C(110, 200, 90), C(70, 150, 60)
		suit(k, {torso = white, hips = white, sleeve = black, forearm = black, glove = black, thigh = black, shin = black, shoe = black, sole = white})
		k.p("UpperTorso", "PandaBelly", V(1.2, 1.0, 0.06), offset(0, -0.1, -0.6), C(236, 236, 236), nil, "Disc")
		-- Hood sits behind the face plane, so the player's own face stays visible.
		k.p("Head", "PandaHood", V(1.62, 1.46, 1.54), offset(0, 0.14, 0.2), white, M.Fabric, "Ball")
		for _, s in ipairs(SIDES) do
			k.p("Head", "PandaEar_" .. s[1], V(0.62, 0.62, 0.34), offset(s[2] * 0.56, 0.86, 0.12), black, nil, "Ball")
			k.p("Head", "PandaCheek_" .. s[1], V(0.26, 0.9, 0.7), offset(s[2] * 0.7, -0.04, -0.02), white)
		end
		k.p("Head", "PandaBrow", V(1.3, 0.32, 0.8), offset(0, 0.62, -0.3, -12), white)
		-- Bamboo stalks tied to the back.
		for i, x in ipairs({-0.55, 0, 0.55}) do
			local tall = 2.5 + (i % 2) * 0.5
			k.p("UpperTorso", "Bamboo" .. i, V(0.3, tall, 0.3), offset(x, 0.35 + (tall - 2.5) / 2, 0.74, 0, 0, (i - 2) * 8), green, nil, "Can")
			k.p("UpperTorso", "BambooRing" .. i, V(0.36, 0.1, 0.36), offset(x + (i - 2) * 0.1, 0.5, 0.74, 0, 0, (i - 2) * 8), dark, nil, "Can")
		end
		k.p("UpperTorso", "BambooTie", V(1.8, 0.14, 0.5), offset(0, 0.1, 0.62), C(230, 190, 120))
		k.p("LowerTorso", "PandaTail", V(0.6, 0.6, 0.6), offset(0, -0.05, 0.62), white, M.Fabric, "Ball")
	end,
}

-- EPIC -----------------------------------------------------------------------------------
skins.skin_streetwear = { -- Street Legend
	hides = "outfit", headwear = true,
	aura = {kind = "dust", color = {C(255, 230, 130), C(255, 190, 60)}, mount = "UpperTorso", at = offset(0, 0.2, 0.4)},
	build = function(k)
		local gold, red, blue, cream, navy, grey = C(255, 200, 40), C(235, 50, 60), C(40, 90, 220), C(255, 244, 214), C(24, 40, 110), C(92, 98, 112)
		-- Varsity jacket (cream body, blue sleeves), baggy cargo pants, chunky red-and-white sneakers.
		suit(k, {torso = cream, hips = navy, sleeve = blue, forearm = blue, thigh = grey, shin = grey, shoe = red, sole = cream})
		ring(k, "LowerTorso", "JacketHem", navy, -0.04, 0.24, 0.2, M.Fabric)
		ring(k, "UpperTorso", "JacketCollar", navy, 0.72, 0.2, 0.2, M.Fabric)
		for _, s in ipairs(SIDES) do
			ring(k, s[1] .. "LowerArm", "RibbedCuff_" .. s[1], navy, -0.42, 0.24, 0.2, M.Fabric)
			ring(k, s[1] .. "UpperArm", "SleeveStripe_" .. s[1], cream, 0.1, 0.12, 0.2, M.Fabric)
			k.p(s[1] .. "UpperLeg", "CargoPocket_" .. s[1], V(0.4, 0.5, 0.2), offset(s[2] * 0.52, -0.1, -0.2), C(76, 82, 96))
			ring(k, s[1] .. "LowerLeg", "CargoCuff_" .. s[1], C(60, 64, 76), -0.42, 0.24, 0.2, M.Fabric)
		end
		-- Gold star patch, chunky chain with a pendant, crossbody bag.
		k.p("UpperTorso", "StarPatch", V(0.62, 0.62, 0.06), offset(0.5, 0.2, -0.62), gold, M.Metal, "Disc")
		k.p("UpperTorso", "StarPatchCore", V(0.3, 0.3, 0.06), offset(0.5, 0.2, -0.67), red, nil, "Disc")
		local chain = {{-0.5, 0.58}, {-0.32, 0.34}, {0, 0.24}, {0.32, 0.34}, {0.5, 0.58}}
		for i, c in ipairs(chain) do
			k.p("UpperTorso", "ChainLink" .. i, V(0.17, 0.17, 0.17), offset(c[1], c[2], -0.62), gold, M.Metal, "Ball")
		end
		k.p("UpperTorso", "ChainPendant", V(0.46, 0.46, 0.1), offset(0, -0.1, -0.66), gold, M.Metal, "Disc")
		k.p("UpperTorso", "BagStrap", V(0.2, 2.2, 0.08), offset(0, 0, -0.62, 0, 0, -38), C(30, 30, 40))
		k.p("LowerTorso", "BagBody", V(0.9, 0.8, 0.44), offset(-0.85, -0.2, -0.4), C(30, 30, 40))
		k.p("LowerTorso", "BagFlap", V(0.92, 0.26, 0.46), offset(-0.85, 0.06, -0.4), gold, M.Metal)
		-- Bucket hat.
		k.p("Head", "BucketCrown", V(1.34, 0.7, 1.34), offset(0, 0.88, 0.02), cream, nil, "Can")
		k.p("Head", "BucketTop", V(1.2, 0.1, 1.2), offset(0, 1.24, 0.02), cream, nil, "Can")
		k.p("Head", "BucketBrim", V(2.0, 0.1, 2.0), offset(0, 0.56, 0.02), red, nil, "Can")
		k.p("Head", "BucketBand", V(1.4, 0.18, 1.4), offset(0, 0.68, 0.02), gold, M.Metal, "Can")
	end,
}

skins.skin_cyber = { -- Jet Runner
	hides = "outfit", headwear = true,
	aura = {kind = "jet", color = {C(255, 200, 80), C(255, 100, 30)}, mount = "UpperTorso", at = offset(0, -1.1, 0.98)},
	build = function(k)
		local steel, orange, teal, dark, leather = C(200, 210, 224), C(255, 140, 40), C(60, 200, 220), C(60, 70, 90), C(112, 78, 52)
		-- Orange flight suit with steel gloves and boots.
		suit(k, {torso = orange, hips = orange, sleeve = orange, forearm = orange, glove = steel, gloveMat = M.Metal, thigh = orange, shin = orange, shoe = dark, shoeMat = M.Metal, sole = orange})
		k.p("UpperTorso", "ChestPanel", V(1.1, 0.9, 0.1), offset(0, 0.2, -0.62), steel, M.Metal)
		k.p("UpperTorso", "ChestLight", V(0.36, 0.36, 0.06), offset(0, 0.2, -0.69), teal, M.Metal, "Disc")
		ring(k, "LowerTorso", "FlightBelt", dark, 0.04, 0.28, 0.2, M.Leather)
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "ShoulderPad_" .. s[1], V(0.95, 0.34, 1.2), offset(s[2] * 1.0, 0.84, 0, 0, 0, s[2] * 12), steel, M.Metal)
			k.p(s[1] .. "UpperLeg", "KneeGuard_" .. s[1], V(1.2, 0.34, 1.0), offset(0, -0.52, -0.1), steel, M.Metal)
			ring(k, s[1] .. "LowerArm", "Gauntlet_" .. s[1], steel, -0.2, 0.34, 0.24, M.Metal)
		end
		-- Jet pack with two tanks and nozzles.
		k.p("UpperTorso", "JetBody", V(1.5, 1.3, 0.55), offset(0, 0.1, 0.78), steel, M.Metal)
		k.p("UpperTorso", "JetStripe", V(1.54, 0.2, 0.58), offset(0, 0.4, 0.78), orange)
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "JetTank_" .. s[1], V(0.58, 1.5, 0.58), offset(s[2] * 0.5, -0.1, 0.98), orange, M.Metal, "Can")
			k.p("UpperTorso", "JetNozzle_" .. s[1], V(0.44, 0.3, 0.44), offset(s[2] * 0.5, -0.95, 0.98), dark, M.Metal, "Can")
		end
		-- Aviator cap and goggles.
		k.p("Head", "AviatorCap", V(1.38, 0.8, 1.38), offset(0, 0.5, 0.04), leather, M.Leather, "Ball")
		k.p("Head", "GoggleStrap", V(1.4, 0.2, 1.4), offset(0, 0.46, 0.02), dark, nil, "Can")
		for _, s in ipairs(SIDES) do
			k.p("Head", "GoggleRim_" .. s[1], V(0.52, 0.52, 0.12), offset(s[2] * 0.3, 0.66, -0.62), orange, M.Metal, "Disc")
			k.p("Head", "GoggleLens_" .. s[1], V(0.38, 0.38, 0.1), offset(s[2] * 0.3, 0.66, -0.68), teal, M.Glass, "Disc", {transparency = 0.25})
			k.p("Head", "EarFlap_" .. s[1], V(0.16, 0.5, 0.5), offset(s[2] * 0.7, 0.1, 0.1), leather, M.Leather)
		end
	end,
}

skins.skin_ninja = { -- Shadow Runner
	hides = "outfit", headwear = true,
	aura = {kind = "smoke", color = {C(46, 34, 74), C(120, 84, 190)}, mount = "LowerTorso", at = offset(0, -0.4, 0.5)},
	build = function(k)
		local charcoal, ink, violet, wrap, steel, deep = C(38, 38, 54), C(24, 24, 34), C(150, 90, 235), C(86, 88, 110), C(190, 204, 220), C(66, 46, 120)
		-- Stealth parkour kit: charcoal hooded jacket, wrapped forearms and shins, split-sole boots.
		suit(k, {torso = charcoal, hips = ink, sleeve = charcoal, forearm = wrap, glove = ink, thigh = ink, shin = wrap, shoe = ink, sole = violet})
		for _, s in ipairs(SIDES) do
			ring(k, s[1] .. "UpperArm", "SleeveTrim_" .. s[1], violet, -0.3, 0.1, 0.2, M.Fabric)
			ring(k, s[1] .. "LowerArm", "WrapBand_" .. s[1], violet, 0.1, 0.08, 0.2, M.Fabric)
			k.p(s[1] .. "UpperLeg", "SideStripe_" .. s[1], V(0.07, 1.0, 0.5), offset(s[2] * 0.54, 0, 0), violet)
			k.p(s[1] .. "LowerLeg", "KneeGuard_" .. s[1], V(1.2, 0.4, 1.2), offset(0, 0.44, -0.02), deep, M.SmoothPlastic)
			k.p("UpperTorso", "ShoulderPlate_" .. s[1], V(1.0, 0.3, 1.2), offset(s[2] * 1.0, 0.8, 0, 0, 0, s[2] * 14), deep, M.SmoothPlastic)
		end
		-- Chest straps, belt and a kunai pouch.
		k.p("UpperTorso", "ChestStrap", V(0.18, 2.1, 0.08), offset(0, 0, -0.62, 0, 0, 38), ink)
		k.p("UpperTorso", "StrapBuckle", V(0.28, 0.28, 0.1), offset(0, 0, -0.66, 0, 0, 38), steel, M.Metal)
		ring(k, "LowerTorso", "Belt", ink, 0.04, 0.26, 0.2, M.Leather)
		k.p("LowerTorso", "BeltBuckle", V(0.34, 0.26, 0.08), offset(0, 0.04, -0.62), violet)
		k.p("RightUpperLeg", "KunaiPouch", V(0.4, 0.7, 0.32), offset(0.5, 0.1, -0.1), charcoal, M.Leather)
		-- Hood (face stays open for the mask) and a long streaming scarf.
		k.p("Head", "HoodShell", V(1.64, 1.48, 1.56), offset(0, 0.14, 0.2), charcoal, M.Fabric, "Ball")
		k.p("Head", "HoodPoint", V(0.5, 0.8, 0.6), offset(0, 0.72, 0.48, 18), charcoal, M.Fabric, "Wedge")
		k.p("Head", "HoodBrow", V(1.34, 0.3, 0.8), offset(0, 0.62, -0.3, -12), charcoal, M.Fabric)
		ring(k, "UpperTorso", "ScarfRing", violet, 0.76, 0.3, 0.3, M.Fabric)
		for i = 1, 3 do
			k.p("UpperTorso", "ScarfTail" .. i, V(0.5, 0.34, 0.9), offset(-0.35 + (i % 2) * 0.1, 0.66 - i * 0.22, 0.76 + (i - 1) * 0.78, 10 + i * 8), i % 2 == 1 and violet or deep, M.Fabric)
			k.p("UpperTorso", "ScarfFlap" .. i, V(0.4, 0.3, 0.8), offset(0.4 - (i % 2) * 0.1, 0.5 - i * 0.2, 0.9 + (i - 1) * 0.74, 8 + i * 7), i % 2 == 1 and deep or violet, M.Fabric)
		end
	end,
}

skins.skin_neonphantom = { -- Mall Phantom
	hides = "outfit", headwear = true,
	aura = {kind = "wisps", color = {C(235, 225, 255), C(150, 120, 230)}, mount = "UpperTorso", at = offset(0, -0.6, 0.7)},
	build = function(k)
		local black, white, red, gold, ink = C(24, 24, 34), C(250, 248, 244), C(196, 36, 60), C(255, 205, 70), C(14, 14, 22)
		-- Black tailcoat with a white shirt front, red cravat, white gloves, spats.
		suit(k, {torso = black, hips = black, sleeve = black, forearm = black, glove = white, thigh = ink, shin = ink, shoe = ink, shoeMat = M.SmoothPlastic, sole = white})
		k.p("UpperTorso", "ShirtFront", V(0.82, 1.34, 0.06), offset(0, -0.1, -0.62), white)
		k.p("UpperTorso", "ShirtButtonA", V(0.12, 0.12, 0.06), offset(0, 0.1, -0.67), gold, M.Metal, "Disc")
		k.p("UpperTorso", "ShirtButtonB", V(0.12, 0.12, 0.06), offset(0, -0.3, -0.67), gold, M.Metal, "Disc")
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "Lapel_" .. s[1], V(0.46, 1.2, 0.1), offset(s[2] * 0.62, 0.0, -0.6, 0, 0, s[2] * -8), red)
			k.p("UpperTorso", "Cravat_" .. s[1], V(0.4, 0.32, 0.12), offset(s[2] * 0.2, 0.62, -0.66, 0, 0, s[2] * -22), red)
			ring(k, s[1] .. "LowerArm", "WhiteCuff_" .. s[1], white, -0.4, 0.22, 0.2, M.Fabric)
			ring(k, s[1] .. "Foot", "Spat_" .. s[1], white, 0.12, 0.2, 0.16)
			k.p(s[1] .. "UpperLeg", "TrouserStripe_" .. s[1], V(0.06, 1.1, 0.4), offset(s[2] * 0.54, 0, 0), white)
			-- Long coat tails with a crimson lining.
			k.p("LowerTorso", "CoatTail_" .. s[1], V(0.9, 1.7, 0.14), offset(s[2] * 0.5, -0.9, 0.58, 10, 0, s[2] * 6), black, M.Fabric)
			k.p("LowerTorso", "TailLining_" .. s[1], V(0.7, 1.5, 0.06), offset(s[2] * 0.5, -0.9, 0.5, 10, 0, s[2] * 6), red, M.Fabric)
		end
		k.p("UpperTorso", "CravatKnot", V(0.24, 0.24, 0.2), offset(0, 0.62, -0.66), red, nil, "Ball")
		-- Opera cape: black outside, red lining, high collar and a gold clasp.
		k.p("UpperTorso", "Cape", V(2.1, 2.7, 0.12), offset(0, -0.5, 0.64, 8, 0, 0), black, M.Fabric)
		k.p("UpperTorso", "CapeLining", V(1.9, 2.5, 0.06), offset(0, -0.5, 0.57, 8, 0, 0), red, M.Fabric)
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "CapeCollar_" .. s[1], V(0.5, 0.9, 0.16), offset(s[2] * 0.66, 0.9, 0.5, 0, 0, s[2] * -12), black, M.Fabric)
			k.p("UpperTorso", "CapeClasp_" .. s[1], V(0.26, 0.26, 0.12), offset(s[2] * 0.7, 0.66, -0.2), gold, M.Metal, "Ball")
		end
		-- Short top hat.
		k.p("Head", "HatBrim", V(1.7, 0.1, 1.7), offset(0, 0.56, 0.02), black, nil, "Can")
		k.p("Head", "HatCrown", V(1.2, 0.9, 1.2), offset(0, 1.02, 0.02), black, nil, "Can")
		k.p("Head", "HatBand", V(1.24, 0.2, 1.24), offset(0, 0.72, 0.02), red, nil, "Can")
	end,
}

skins.skin_trickster = { -- Royal Trickster
	hides = "outfit", headwear = true,
	aura = {kind = "confetti", color = {C(255, 120, 200), C(255, 210, 60)}, mount = "UpperTorso", at = offset(0, 0.6, 0.3)},
	build = function(k)
		local purple, gold, pink, white, ink = C(132, 66, 224), C(255, 196, 40), C(255, 96, 170), C(252, 250, 250), C(30, 26, 44)
		-- Harlequin motley: every limb and half of the torso swap purple and gold.
		suit(k, {
			sleeve = {Left = gold, Right = purple}, forearm = {Left = purple, Right = gold}, glove = white,
			thigh = {Left = purple, Right = gold}, shin = {Left = gold, Right = purple}, shoe = {Left = pink, Right = pink}, sole = {Left = gold, Right = gold},
		})
		k.p("UpperTorso", "ShirtHalf_Left", V(1.08, 1.66, 1.14), offset(-0.52, 0, 0), purple, M.Fabric)
		k.p("UpperTorso", "ShirtHalf_Right", V(1.08, 1.66, 1.14), offset(0.52, 0, 0), gold, M.Fabric)
		k.p("LowerTorso", "HipsHalf_Left", V(1.08, 0.46, 1.14), offset(-0.52, 0, 0), gold, M.Fabric)
		k.p("LowerTorso", "HipsHalf_Right", V(1.08, 0.46, 1.14), offset(0.52, 0, 0), purple, M.Fabric)
		-- Diamond patches, belt and buckle.
		for i, p in ipairs({{-0.55, 0.35, gold}, {0.55, 0.35, purple}, {-0.55, -0.35, pink}, {0.55, -0.35, pink}}) do
			k.p("UpperTorso", "Diamond" .. i, V(0.34, 0.34, 0.06), offset(p[1], p[2], -0.62, 0, 0, 45), p[3])
		end
		ring(k, "LowerTorso", "Belt", ink, 0.04, 0.2, 0.22, M.Leather)
		k.p("LowerTorso", "BeltDiamond", V(0.4, 0.4, 0.08), offset(0, 0.04, -0.62, 0, 0, 45), gold, M.Metal)
		-- Ruffled collar.
		for i = 0, 5 do
			local a = math.rad(i * 60 + 30)
			k.p("UpperTorso", "Ruffle" .. i, V(0.5, 0.5, 0.5), offset(math.sin(a) * 0.72, 0.84, math.cos(a) * 0.5), white, M.Fabric, "Ball")
		end
		-- Curled shoes with bells.
		for _, s in ipairs(SIDES) do
			k.p(s[1] .. "Foot", "ShoeCurl_" .. s[1], V(0.4, 0.5, 0.5), offset(0, 0.26, -0.82, -30), pink, nil, "Wedge")
			k.p(s[1] .. "Foot", "ShoeBell_" .. s[1], V(0.26, 0.26, 0.26), offset(0, 0.54, -0.96), gold, M.Metal, "Ball")
		end
		-- Three-horned jester crown with bells: each horn is two chained segments that curve outward.
		k.p("Head", "CrownBand", V(1.36, 0.28, 1.36), offset(0, 0.58, 0.02), gold, M.Metal, "Can")
		local horns = {{-1, purple, 18, 48}, {0, pink, 0, 0}, {1, gold, 18, 48}}
		for i, h in ipairs(horns) do
			local side, color = h[1], h[2]
			local a1, a2 = math.rad(h[3]), math.rad(h[4])
			local base = V(side * 0.42, 0.72, 0.04)
			local d1 = V(side * math.sin(a1), math.cos(a1), 0)
			local d2 = V(side * math.sin(a2), math.cos(a2), 0)
			local lowCenter = base + d1 * 0.31
			local tip1 = base + d1 * 0.62
			local highCenter = tip1 + d2 * 0.3
			local tip2 = tip1 + d2 * 0.6
			local bell = tip2 + d2 * 0.1
			k.p("Head", "HornLow" .. i, V(0.42, 0.62, 0.42), offset(lowCenter.X, lowCenter.Y, lowCenter.Z, 0, 0, -side * h[3]), color, M.Fabric, "Can")
			k.p("Head", "HornHigh" .. i, V(0.3, 0.6, 0.3), offset(highCenter.X, highCenter.Y, highCenter.Z, 0, 0, -side * h[4]), color, M.Fabric, "Can")
			k.p("Head", "HornBell" .. i, V(0.28, 0.28, 0.28), offset(bell.X, bell.Y, bell.Z), white, M.Metal, "Ball")
		end
	end,
}

skins.skin_candy = { -- Candy Pop
	hides = "outfit", headwear = true,
	aura = {kind = "sprinkles", color = {C(255, 140, 200), C(120, 235, 200)}, mount = "UpperTorso", at = offset(0, 0.9, 0)},
	build = function(k)
		local pink, mint, cone, cherry, white, blue = C(255, 140, 200), C(120, 235, 200), C(236, 180, 100), C(230, 40, 60), C(255, 255, 255), C(150, 210, 255)
		-- Peppermint outfit: pink top, mint pants with polka dots, mint sneakers.
		suit(k, {torso = pink, hips = white, sleeve = pink, forearm = white, glove = white, thigh = mint, shin = mint, shoe = mint, sole = pink})
		for i = 0, 2 do
			k.p("UpperTorso", "CandyStripe" .. i, V(0.2, 1.6, 0.06), offset(-0.55 + i * 0.55, 0, -0.62), white)
		end
		for i, p in ipairs({{0.4, 0.2}, {-0.4, -0.15}}) do
			k.p("RightUpperLeg", "PolkaDot_R" .. i, V(0.3, 0.3, 0.06), offset(p[1] * 0.4, p[2], -0.58), white, nil, "Disc")
			k.p("LeftUpperLeg", "PolkaDot_L" .. i, V(0.3, 0.3, 0.06), offset(p[1] * 0.4, p[2], -0.58), white, nil, "Disc")
		end
		-- Cotton-candy shoulder puffs.
		k.p("UpperTorso", "PuffPink", V(0.72, 0.72, 0.72), offset(-1.12, 0.78, 0), pink, nil, "Ball")
		k.p("UpperTorso", "PuffBlue", V(0.72, 0.72, 0.72), offset(1.12, 0.78, 0), blue, nil, "Ball")
		-- Ice-cream hat: waffle band, two scoops, a cherry and sprinkles.
		k.p("Head", "WaffleBand", V(1.4, 0.34, 1.4), offset(0, 0.56, 0.02), cone, nil, "Can")
		k.p("Head", "ScoopPink", V(1.55, 1.1, 1.55), offset(0, 1.06, 0.02), pink, nil, "Ball")
		k.p("Head", "ScoopMint", V(1.1, 0.8, 1.1), offset(0, 1.66, 0.02), mint, nil, "Ball")
		k.p("Head", "Cherry", V(0.34, 0.34, 0.34), offset(0, 2.1, 0.02), cherry, nil, "Ball")
		for i, p in ipairs({{-0.5, 1.2, -0.5}, {0.4, 0.9, -0.62}, {0.55, 1.3, 0.2}}) do
			k.p("Head", "Sprinkle" .. i, V(0.18, 0.08, 0.08), offset(p[1], p[2], p[3], 0, i * 40, 0), white)
		end
		-- Giant lollipop on the back.
		k.p("UpperTorso", "LollipopStick", V(0.14, 2.8, 0.14), offset(0.5, -0.1, 0.7, 0, 0, -14), white, nil, "Can")
		k.p("UpperTorso", "LollipopSwirl", V(1.5, 1.5, 0.16), offset(0.95, 1.35, 0.7), pink, nil, "Disc")
		k.p("UpperTorso", "LollipopRing", V(1.0, 1.0, 0.18), offset(0.95, 1.35, 0.74), white, nil, "Disc")
		k.p("UpperTorso", "LollipopCore", V(0.5, 0.5, 0.2), offset(0.95, 1.35, 0.78), mint, nil, "Disc")
	end,
}

-- LEGENDARY ------------------------------------------------------------------------------
skins.skin_galaxy = { -- Galaxy Escape Artist
	hides = "outfit", headwear = true,
	aura = {kind = "stardust", color = {C(140, 210, 255), C(255, 150, 230)}, mount = "UpperTorso", at = offset(0, 0.2, 0.5)},
	build = function(k)
		local night, violet, teal, gold, white, deep = C(26, 24, 78), C(104, 70, 200), C(60, 190, 210), C(255, 205, 70), C(250, 250, 255), C(18, 16, 52)
		-- A midnight-blue magician's suit patterned with golden stars.
		suit(k, {torso = night, hips = deep, sleeve = night, forearm = night, glove = white, thigh = deep, shin = deep, shoe = deep, shoeMat = M.SmoothPlastic, sole = gold})
		local stars = {{"UpperTorso", -0.5, 0.3, -0.62}, {"UpperTorso", 0.45, -0.3, -0.62}, {"LeftUpperLeg", 0.1, 0.1, -0.58}, {"RightUpperLeg", -0.1, -0.2, -0.58},
			{"LeftUpperArm", -0.1, 0.1, -0.58}, {"RightUpperArm", 0.1, -0.1, -0.58}}
		for i, star in ipairs(stars) do
			k.p(star[1], "StarPatch" .. i, V(0.3, 0.3, 0.06), offset(star[2], star[3], star[4], 0, 0, 45 + i * 9), gold, M.Metal, "Disc")
		end
		ring(k, "UpperTorso", "GoldTrim", gold, -0.7, 0.1, 0.2, M.Metal)
		for _, s in ipairs(SIDES) do
			ring(k, s[1] .. "LowerArm", "GoldCuff_" .. s[1], gold, -0.4, 0.2, 0.2, M.Metal)
			k.p("UpperTorso", "Epaulette_" .. s[1], V(1.0, 0.24, 1.2), offset(s[2] * 1.0, 0.84, 0, 0, 0, s[2] * 12), gold, M.Metal)
		end
		-- Three-layer cosmic cape: opaque night, glassy violet, wisp of teal, with a crescent clasp.
		k.p("UpperTorso", "CapeNight", V(2.1, 3.1, 0.1), offset(0, -0.9, 0.62, 7, 0, 0), night, M.Fabric)
		k.p("UpperTorso", "CapeNebula", V(2.0, 2.9, 0.08), offset(0, -0.9, 0.7, 7, 0, 0), violet, M.Fabric, nil, {transparency = 0.3})
		k.p("UpperTorso", "CapeWisp", V(1.7, 2.5, 0.06), offset(0, -0.8, 0.78, 7, 0, 0), teal, M.Fabric, nil, {transparency = 0.5})
		for i, p in ipairs({{-0.6, -0.4}, {0.5, -0.9}, {-0.2, -1.5}, {0.65, -1.9}, {-0.65, -2.1}, {0.1, 0.3}}) do
			k.p("UpperTorso", "CapeStar" .. i, V(0.2, 0.2, 0.05), offset(p[1], p[2], 0.86 + i * 0.012, 7, 0, i * 30), gold, M.Metal, "Disc")
		end
		k.p("UpperTorso", "MoonClasp", V(0.5, 0.5, 0.1), offset(0, 0.7, -0.64), gold, M.Metal, "Disc")
		k.p("UpperTorso", "MoonCut", V(0.42, 0.42, 0.12), offset(0.12, 0.74, -0.7), night, nil, "Disc")
		-- Top hat with a golden star band and a tiny ringed planet.
		k.p("Head", "HatBrim", V(1.8, 0.1, 1.8), offset(0, 0.56, 0.02), night, nil, "Can")
		k.p("Head", "HatCrown", V(1.26, 1.0, 1.26), offset(0, 1.06, 0.02), night, nil, "Can")
		k.p("Head", "HatBand", V(1.3, 0.22, 1.3), offset(0, 0.72, 0.02), gold, M.Metal, "Can")
		k.p("Head", "HatStar", V(0.36, 0.36, 0.06), offset(0.28, 0.74, -0.68, 0, 0, 45), white, nil, "Disc")
		k.p("Head", "Planet", V(0.46, 0.46, 0.46), offset(0, 1.82, 0.02), violet, nil, "Ball")
		k.p("Head", "PlanetRing", V(0.94, 0.06, 0.94), offset(0, 1.82, 0.02, 0, 0, 18), gold, M.Metal, "Can")
	end,
}

skins.skin_golden = { -- Golden Champion
	hides = "outfit", headwear = true,
	tint = {color = C(255, 200, 50), material = M.Metal, stashClothes = true},
	aura = {kind = "gold", color = {C(255, 240, 150), C(255, 190, 40)}, mount = "UpperTorso", at = offset(0, 0, 0)},
	build = function(k)
		local gold, ruby, purple, white = C(255, 210, 70), C(230, 40, 70), C(110, 50, 200), C(255, 255, 255)
		-- Crown with five bold points and gems.
		k.p("Head", "CrownBand", V(1.36, 0.3, 1.36), offset(0, 0.62, 0.02), gold, M.Metal, "Can")
		for i, x in ipairs({-0.52, -0.26, 0, 0.26, 0.52}) do
			local tall = i == 3 and 0.74 or 0.52
			k.p("Head", "CrownSpike" .. i, V(0.3, tall, 0.2), offset(x, 0.76 + tall / 2, -0.5 + math.abs(x) * 0.5), gold, M.Metal, "Wedge")
			k.p("Head", "CrownJewel" .. i, V(0.14, 0.14, 0.06), offset(x, 0.62, -0.7 + math.abs(x) * 0.2), i % 2 == 0 and white or ruby, nil, "Disc")
		end
		-- Champion armor: chest plate, gauntlets, greaves and boots (the avatar underneath turns solid gold).
		shell(k, "UpperTorso", "ChestPlate", gold, V(0.18, 0.08, 0.18), M.Metal)
		k.p("UpperTorso", "ChestRuby", V(0.5, 0.5, 0.08), offset(0, 0.2, -0.64), ruby, nil, "Disc")
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "Epaulette_" .. s[1], V(1.0, 0.24, 1.2), offset(s[2] * 1.0, 0.84, 0, 0, 0, s[2] * 12), gold, M.Metal)
			k.p("UpperTorso", "CapeFur_" .. s[1], V(0.7, 0.4, 0.5), offset(s[2] * 0.56, 0.78, 0.5), white, M.Fabric, "Ball")
			ring(k, s[1] .. "LowerArm", "Gauntlet_" .. s[1], gold, -0.16, 0.5, 0.24, M.Metal)
			ring(k, s[1] .. "LowerLeg", "Greave_" .. s[1], gold, -0.1, 0.8, 0.2, M.Metal)
			k.p(s[1] .. "Foot", "Boot_" .. s[1], V(1.14, 0.46, 1.3), offset(0, 0.06, -0.12), gold, M.Metal)
		end
		k.p("UpperTorso", "Cape", V(2.1, 3.0, 0.12), offset(0, -0.9, 0.62, 7, 0, 0), purple, M.Fabric)
		k.p("UpperTorso", "CapeTrim", V(2.14, 0.2, 0.18), offset(0, -2.38, 0.84, 7, 0, 0), gold, M.Metal)
		k.p("LowerTorso", "ChampionBelt", V(2.16, 0.38, 1.16), offset(0, 0.04, 0), gold, M.Metal)
		k.p("LowerTorso", "BeltPlaque", V(0.96, 0.6, 0.1), offset(0, 0.04, -0.6), purple)
		k.p("LowerTorso", "BeltJewel", V(0.4, 0.4, 0.08), offset(0, 0.04, -0.67), ruby, nil, "Disc")
	end,
}

skins.skin_dragon = { -- Dragon Racer
	hides = "outfit", headwear = true,
	aura = {kind = "embers", color = {C(255, 210, 90), C(255, 80, 30)}, mount = "UpperTorso", at = offset(0, 0.2, 0.5)},
	build = function(k)
		local red, bone, orange, dark, ash = C(215, 50, 40), C(250, 236, 206), C(255, 140, 40), C(120, 24, 30), C(60, 28, 32)
		-- Scale-armor suit: red body with orange belly plates, dark limbs, claw gloves and spiked boots.
		suit(k, {torso = red, hips = dark, sleeve = dark, forearm = red, glove = ash, gloveMat = M.Slate, thigh = dark, shin = red, shoe = ash, shoeMat = M.Slate, sole = bone, mat = M.Slate})
		for i = 0, 3 do
			k.p("UpperTorso", "BellyPlate" .. i, V(1.5, 0.22, 0.1), offset(0, 0.55 - i * 0.38, -0.62), orange, nil)
		end
		for _, s in ipairs(SIDES) do
			ring(k, s[1] .. "UpperArm", "ArmScales_" .. s[1], red, 0.2, 0.2, 0.2, M.Slate)
			ring(k, s[1] .. "UpperLeg", "LegScales_" .. s[1], red, 0.2, 0.2, 0.2, M.Slate)
			k.p(s[1] .. "Hand", "Claw_" .. s[1], V(0.7, 0.14, 0.4), offset(0, -0.1, -0.66), bone, nil, "Wedge")
			k.p(s[1] .. "Foot", "ToeClaw_" .. s[1], V(0.7, 0.16, 0.44), offset(0, 0.0, -0.9), bone, nil, "Wedge")
		end
		-- Swept-back horns and a spiny crest.
		for _, s in ipairs(SIDES) do
			k.p("Head", "HornBase_" .. s[1], V(0.34, 0.5, 0.34), offset(s[2] * 0.4, 0.7, 0.1, -14, 0, s[2] * -12), bone, nil, "Can")
			k.p("Head", "HornTip_" .. s[1], V(0.26, 0.7, 0.26), offset(s[2] * 0.52, 1.18, 0.34, -40, 0, s[2] * -20), orange, nil, "Can")
		end
		for i = 1, 3 do
			k.p("UpperTorso", "BackSpike" .. i, V(0.34, 0.5, 0.34), offset(0, 0.9 - i * 0.5, 0.62, 25, 0, 0), bone, nil, "Wedge")
		end
		-- Wings: a bone spar and four fanned feather panels per side, so the V reads from behind.
		for _, s in ipairs(SIDES) do
			local x = s[2]
			local function fan(name, angle, length, width, color, material)
				local a = math.rad(angle)
				local base = V(x * 0.55, 0.45, 0.72)
				local center = base + V(x * math.sin(a), math.cos(a), 0) * (length / 2)
				return k.p("UpperTorso", name .. "_" .. s[1], V(width, length, 0.1), offset(center.X, center.Y, center.Z, 0, 0, -x * angle), color, material)
			end
			fan("WingSpar", 38, 3.1, 0.22, bone)
			fan("WingFeatherA", 14, 2.3, 0.7, red)
			fan("WingFeatherB", 36, 2.9, 0.7, dark)
			fan("WingFeatherC", 58, 2.6, 0.7, red)
			fan("WingFeatherD", 80, 2.0, 0.7, dark)
			k.p("UpperTorso", "WingClaw_" .. s[1], V(0.22, 0.5, 0.22), offset(x * 2.5, 2.75, 0.76, 0, 0, -x * 38), orange, nil, "Wedge")
		end
		-- Tapering tail with a flame tip.
		k.p("LowerTorso", "TailA", V(0.6, 0.6, 1.0), offset(0, -0.1, 0.9, -12, 0, 0), red)
		k.p("LowerTorso", "TailB", V(0.46, 0.46, 1.0), offset(0, -0.34, 1.78, -22, 0, 0), red)
		k.p("LowerTorso", "TailC", V(0.3, 0.3, 0.9), offset(0, -0.72, 2.5, -30, 0, 0), dark)
		k.p("LowerTorso", "TailFlame", V(0.5, 0.6, 0.5), offset(0, -1.0, 3.0, -30, 0, 0), orange, nil, "Wedge")
	end,
}

Appearance.SkinOrder = {"skin_courier", "skin_rooftop", "skin_pizza", "skin_bunny", "skin_panda", "skin_streetwear", "skin_cyber",
	"skin_ninja", "skin_neonphantom", "skin_trickster", "skin_candy", "skin_galaxy", "skin_golden", "skin_dragon"}
function Appearance.HasSkin(id) return skins[id] ~= nil end
function Appearance.SkinInfo(id) return skins[id] end

-- Presentational mood is a replicated attribute only. Roblox's own animations and face are untouched.
Appearance.Moods = {Idle = "idle", Run = "run", Hunt = "hunt", Scared = "scared", Hide = "hide", Win = "win", Lose = "lose"}
function Appearance.SetMood(rig, mood)
	if not rig then return false end
	rig:SetAttribute("CatchMood", Appearance.Moods[mood] and mood or "Idle")
	return true
end

-- ---------------------------------------------------------------------------------------
-- Masks sit in front of the player's real face (the head's front plane is z = -0.6). Bold, simple shapes, a
-- little metal, no glow. Pieces named "Top..." sit above the head (ears, stems, rings) and are left off when the
-- skin already has headwear, so masks and hats never collide. Every mask works with every skin.
-- ---------------------------------------------------------------------------------------
local masks = {
	mask_street = true, mask_visor = true, mask_smile = true, mask_cat = true, mask_ninja = true, mask_pumpkin = true,
	mask_jester = true, mask_pixel = true, mask_phantom = true, mask_kitsune = true, mask_skull = true, mask_astral = true,
}
function Appearance.HasMask(id) return masks[id] ~= nil end
Appearance.MaskOrder = {"mask_street", "mask_visor", "mask_smile", "mask_cat", "mask_ninja", "mask_pumpkin", "mask_jester", "mask_pixel",
	"mask_phantom", "mask_kitsune", "mask_skull", "mask_astral"}

local function buildMask(k, maskId)
	local white, ink, gold = C(250, 246, 240), C(30, 30, 44), C(255, 205, 60)
	local function m(name, size, cf, color, material, shape, opts)
		if k.headwear and string.sub(name, 1, 3) == "Top" then return nil end
		return k.p("Head", name, size, cf, color, material, shape, opts)
	end
	if maskId == "mask_street" then
		local teal, light = C(30, 190, 200), C(255, 255, 255)
		m("BandanaCloth", V(1.34, 0.56, 0.24), offset(0, -0.26, -0.6), teal, M.Fabric)
		m("BandanaPoint", V(0.6, 0.34, 0.24), offset(0, -0.62, -0.58, 0, 0, 180), teal, M.Fabric, "Wedge")
		m("BandanaTopEdge", V(1.34, 0.08, 0.26), offset(0, -0.02, -0.61), light)
		for _, x in ipairs({-0.4, 0, 0.4}) do m("BandanaDot", V(0.12, 0.12, 0.05), offset(x, -0.3, -0.73), light, nil, "Disc") end
		m("BandanaKnot", V(0.4, 0.34, 0.34), offset(0.3, -0.2, 0.66), teal, M.Fabric, "Ball")
		m("BandanaStrap", V(1.28, 0.2, 1.28), offset(0, -0.2, 0.0), teal, M.Fabric, "Can")
	elseif maskId == "mask_visor" then
		-- Cool shades: opaque lenses, hot-pink frame, a glint on each lens.
		local frame = C(255, 90, 160)
		m("ShadesBridge", V(1.32, 0.12, 0.16), offset(0, 0.14, -0.64), frame)
		for _, s in ipairs(SIDES) do
			m("ShadesLens_" .. s[1], V(0.54, 0.4, 0.14), offset(s[2] * 0.3, 0.1, -0.66), ink, M.Glass, nil, {transparency = 0.1})
			m("ShadesRim_" .. s[1], V(0.6, 0.46, 0.1), offset(s[2] * 0.3, 0.1, -0.63), frame)
			m("ShadesShine_" .. s[1], V(0.14, 0.06, 0.06), offset(s[2] * 0.4, 0.2, -0.74, 0, 0, 20), white)
			m("ShadesArm_" .. s[1], V(0.1, 0.12, 1.0), offset(s[2] * 0.62, 0.14, -0.1), frame)
		end
	elseif maskId == "mask_smile" then
		-- Cartoon smiley: yellow face disc, oval eyes, rosy cheeks, a huge curved grin.
		local yellow = C(255, 214, 40)
		m("SmileFace", V(1.12, 1.12, 0.14), offset(0, -0.02, -0.66), yellow, nil, "Disc")
		for _, s in ipairs(SIDES) do
			m("SmileEye_" .. s[1], V(0.16, 0.3, 0.05), offset(s[2] * 0.25, 0.2, -0.75), ink, nil, "Disc")
			m("SmileCheek_" .. s[1], V(0.22, 0.14, 0.04), offset(s[2] * 0.42, -0.12, -0.74), C(255, 130, 130), nil, "Disc")
		end
		for i = -2, 2 do
			local x = i * 0.15
			m("SmileGrin" .. i, V(0.17, 0.08, 0.05), offset(x, -0.26 + (i * i) * 0.035, -0.75, 0, 0, i * -12), ink)
		end
	elseif maskId == "mask_cat" then
		-- Cartoon cat: orange face, cream muzzle, big eyes, pink nose, whiskers, pointed ears.
		local orange, cream, pink = C(255, 156, 52), C(255, 240, 214), C(255, 128, 168)
		m("CatFace", V(1.12, 1.04, 0.14), offset(0, -0.02, -0.66), orange, nil, "Disc")
		m("CatMuzzle", V(0.62, 0.42, 0.06), offset(0, -0.24, -0.75), cream, nil, "Disc")
		m("CatNose", V(0.2, 0.14, 0.06), offset(0, -0.12, -0.79, 0, 0, 180), pink, nil, "Wedge")
		for _, s in ipairs(SIDES) do
			m("CatEye_" .. s[1], V(0.26, 0.3, 0.05), offset(s[2] * 0.26, 0.16, -0.75), white, nil, "Disc")
			m("CatPupil_" .. s[1], V(0.1, 0.24, 0.05), offset(s[2] * 0.26, 0.16, -0.79), ink, nil, "Disc")
			for i = 1, 2 do
				m("CatWhisker" .. i .. "_" .. s[1], V(0.5, 0.03, 0.03), offset(s[2] * 0.62, -0.2 - (i - 1.5) * 0.12, -0.74, 0, 0, s[2] * (i - 1.5) * 14), ink)
			end
			m("TopCatEar_" .. s[1], V(0.44, 0.4, 0.18), offset(s[2] * 0.4, 0.74, -0.3, 0, 0, s[2] * -8), orange, nil, "Wedge")
			m("TopCatEarInner_" .. s[1], V(0.22, 0.24, 0.08), offset(s[2] * 0.4, 0.7, -0.4, 0, 0, s[2] * -8), pink, nil, "Wedge")
		end
	elseif maskId == "mask_ninja" then
		local cloth, wrap = C(40, 44, 70), C(230, 40, 50)
		m("WrapLower", V(1.34, 0.62, 0.24), offset(0, -0.22, -0.6), cloth, M.Fabric)
		m("WrapNose", V(0.5, 0.24, 0.26), offset(0, 0.06, -0.62), cloth, M.Fabric, "Wedge")
		m("WrapStrap", V(1.3, 0.24, 1.3), offset(0, -0.1, 0.0), cloth, M.Fabric, "Can")
		m("WrapStripe", V(1.36, 0.08, 0.26), offset(0, -0.46, -0.6), wrap)
		m("WrapTail", V(0.24, 0.9, 0.08), offset(0.4, -0.4, 0.68, 12, 0, -8), wrap, M.Fabric)
	elseif maskId == "mask_pumpkin" then
		-- Jack-o'-lantern: a squashed orange pumpkin with carved eyes and a jagged grin, a green stem on top.
		local orange, dark, green, glow = C(255, 132, 30), C(200, 90, 20), C(80, 170, 70), C(255, 226, 120)
		m("PumpkinBody", V(1.2, 1.08, 0.5), offset(0, -0.02, -0.68), orange, nil, "Ball")
		for _, x in ipairs({-0.36, 0.36}) do m("PumpkinRib", V(0.1, 0.96, 0.1), offset(x, -0.02, -0.9), dark, nil, "Ball") end
		for _, s in ipairs(SIDES) do
			m("PumpkinEyeHole_" .. s[1], V(0.3, 0.3, 0.1), offset(s[2] * 0.26, 0.16, -0.9), ink, nil, "Wedge")
			m("PumpkinEyeGlow_" .. s[1], V(0.16, 0.16, 0.06), offset(s[2] * 0.26, 0.12, -0.95), glow, nil, "Wedge")
		end
		m("PumpkinNose", V(0.16, 0.16, 0.08), offset(0, -0.06, -0.93, 0, 0, 180), ink, nil, "Wedge")
		for i = -2, 2 do
			m("PumpkinTooth" .. i, V(0.14, 0.18 + (i % 2 == 0 and 0.06 or 0), 0.08), offset(i * 0.17, -0.34, -0.93), glow)
		end
		m("TopPumpkinStem", V(0.2, 0.4, 0.2), offset(0.05, 0.68, -0.5, 14, 0, -10), green, nil, "Can")
		m("TopPumpkinLeaf", V(0.4, 0.06, 0.22), offset(0.3, 0.7, -0.5, 0, 0, -20), green)
	elseif maskId == "mask_jester" then
		local purple, pink = C(150, 80, 230), C(236, 70, 100)
		m("JesterFace", V(1.06, 0.84, 0.2), offset(0, -0.02, -0.62), white)
		m("JesterHalf", V(0.53, 0.84, 0.21), offset(0.265, -0.02, -0.63), purple)
		for _, s in ipairs(SIDES) do
			m("JesterEye_" .. s[1], V(0.32, 0.24, 0.06), offset(s[2] * 0.26, 0.14, -0.74, 0, 0, s[2] * 18), ink)
			m("JesterBrowPoint_" .. s[1], V(0.4, 0.36, 0.22), offset(s[2] * 0.46, 0.52, -0.58, 0, 0, s[2] * -28), s[1] == "Left" and white or purple, nil, "Wedge")
			m("TopJesterBell_" .. s[1], V(0.26, 0.26, 0.26), offset(s[2] * 0.74, 0.8, -0.58), gold, M.Metal, "Ball")
			m("JesterDiamond_" .. s[1], V(0.12, 0.12, 0.05), offset(s[2] * 0.42, -0.06, -0.74, 0, 0, 45), s[1] == "Left" and purple or pink)
		end
		m("JesterGrin", V(0.74, 0.22, 0.06), offset(0, -0.26, -0.74), ink)
		for x = -0.24, 0.24, 0.12 do m("JesterTooth", V(0.07, 0.15, 0.06), offset(x, -0.24, -0.78), white) end
		m("JesterNose", V(0.22, 0.22, 0.22), offset(0, -0.06, -0.78), pink, nil, "Ball")
	elseif maskId == "mask_pixel" then
		-- Retro bot: a monitor face with a pixel smile.
		local screen, glow, frame = C(34, 40, 66), C(80, 235, 160), C(100, 110, 150)
		m("PixelScreen", V(1.1, 0.9, 0.22), offset(0, -0.02, -0.62), screen, M.Metal)
		m("PixelFrame", V(1.18, 0.98, 0.14), offset(0, -0.02, -0.58), frame, M.Metal)
		for _, s in ipairs(SIDES) do
			m("PixelEye_" .. s[1], V(0.26, 0.26, 0.06), offset(s[2] * 0.25, 0.14, -0.74), glow)
			m("PixelCheek_" .. s[1], V(0.12, 0.12, 0.06), offset(s[2] * 0.36, -0.2, -0.74), C(255, 120, 190))
			m("PixelBolt_" .. s[1], V(0.12, 0.12, 0.08), offset(s[2] * 0.54, 0.4, -0.66), frame, M.Metal, "Ball")
		end
		for i, x in ipairs({-0.3, -0.15, 0, 0.15, 0.3}) do
			m("PixelMouth" .. i, V(0.12, 0.12, 0.06), offset(x, i % 2 == 0 and -0.34 or -0.28, -0.74), glow)
		end
		m("TopPixelAntenna", V(0.06, 0.44, 0.06), offset(0, 0.78, -0.2), frame, M.Metal)
		m("TopPixelAntennaTip", V(0.18, 0.18, 0.18), offset(0, 1.02, -0.2), glow, nil, "Ball")
	elseif maskId == "mask_phantom" then
		-- Half-face opera mask over the right side, gold trim and a music note.
		m("PhantomPlate", V(0.66, 0.92, 0.2), offset(0.27, -0.02, -0.62), white)
		m("PhantomBridge", V(0.5, 0.34, 0.2), offset(-0.04, 0.14, -0.62), white)
		m("PhantomNose", V(0.18, 0.3, 0.2), offset(0, -0.1, -0.76, 0, 0, 180), white, nil, "Wedge")
		m("PhantomEye", V(0.32, 0.14, 0.06), offset(0.28, 0.14, -0.74, 0, 0, 10), ink)
		m("PhantomBrow", V(0.4, 0.06, 0.06), offset(0.28, 0.28, -0.75, 0, 0, 10), gold, M.Metal)
		m("PhantomTrim", V(0.06, 0.9, 0.07), offset(-0.06, -0.02, -0.74), gold, M.Metal)
		m("PhantomNoteHead", V(0.12, 0.1, 0.05), offset(0.42, -0.2, -0.74), gold, M.Metal, "Disc")
		m("PhantomNoteStem", V(0.03, 0.26, 0.05), offset(0.47, -0.08, -0.74), gold, M.Metal)
		m("PhantomEyebrowFlourish", V(0.22, 0.05, 0.05), offset(-0.3, 0.2, -0.7, 0, 0, -14), gold, M.Metal)
	elseif maskId == "mask_kitsune" then
		local vermilion = C(226, 70, 70)
		m("FoxFace", V(1.06, 0.82, 0.22), offset(0, -0.02, -0.63), white)
		for _, s in ipairs(SIDES) do
			m("TopFoxEar_" .. s[1], V(0.4, 0.84, 0.2), offset(s[2] * 0.44, 0.66, -0.5, 0, 0, s[2] * -18), white, nil, "Wedge")
			m("TopFoxEarInner_" .. s[1], V(0.2, 0.5, 0.06), offset(s[2] * 0.45, 0.64, -0.62, 0, 0, s[2] * -18), vermilion, nil, "Wedge")
			m("FoxEye_" .. s[1], V(0.34, 0.1, 0.06), offset(s[2] * 0.26, 0.1, -0.75, 0, 0, s[2] * 20), vermilion)
			m("FoxCheekMark_" .. s[1], V(0.3, 0.08, 0.06), offset(s[2] * 0.34, -0.14, -0.75, 0, 0, s[2] * -25), vermilion)
			m("FoxCheekMarkB_" .. s[1], V(0.26, 0.07, 0.06), offset(s[2] * 0.36, -0.26, -0.75, 0, 0, s[2] * -25), vermilion)
		end
		m("FoxMuzzle", V(0.42, 0.28, 0.26), offset(0, -0.26, -0.78), white)
		m("FoxNose", V(0.16, 0.1, 0.06), offset(0, -0.19, -0.92), ink)
		m("FoxForeheadSeal", V(0.2, 0.26, 0.05), offset(0, 0.28, -0.75, 0, 0, 45), vermilion)
	elseif maskId == "mask_skull" then
		m("SkullForehead", V(1.08, 0.54, 0.24), offset(0, 0.2, -0.62), gold, M.Metal)
		for _, s in ipairs(SIDES) do
			m("SkullCheek_" .. s[1], V(0.34, 0.4, 0.18), offset(s[2] * 0.4, -0.14, -0.66, 0, 0, s[2] * 18), gold, M.Metal)
			m("SkullSocket_" .. s[1], V(0.36, 0.3, 0.08), offset(s[2] * 0.27, 0.1, -0.78, 0, 0, s[2] * 9), ink)
			m("SkullEye_" .. s[1], V(0.12, 0.12, 0.05), offset(s[2] * 0.27, 0.1, -0.83), C(255, 90, 90), nil, "Disc")
			m("SkullBrowRidge_" .. s[1], V(0.4, 0.08, 0.08), offset(s[2] * 0.27, 0.3, -0.76, 0, 0, s[2] * 10), C(214, 160, 40), M.Metal)
		end
		m("SkullJaw", V(0.7, 0.3, 0.22), offset(0, -0.34, -0.64), gold, M.Metal)
		m("SkullNasal", V(0.15, 0.19, 0.06), offset(0, -0.1, -0.8, 0, 0, 180), ink, nil, "Wedge")
		for x = -0.24, 0.24, 0.12 do m("ToothGap", V(0.04, 0.17, 0.04), offset(x, -0.34, -0.77), ink) end
	elseif maskId == "mask_astral" then
		-- Astral visor: a wraparound glass lens full of stars, golden frame, temple modules and a tiny ringed planet.
		local night, violet, teal = C(20, 22, 66), C(120, 80, 220), C(70, 200, 220)
		m("VisorGlass", V(0.86, 0.46, 0.12), offset(0, 0.1, -0.7), night, M.Glass, nil, {transparency = 0.08})
		for _, s in ipairs(SIDES) do
			m("VisorWing_" .. s[1], V(0.46, 0.46, 0.12), offset(s[2] * 0.62, 0.1, -0.52, 0, s[2] * 60, 0), night, M.Glass, nil, {transparency = 0.08})
			m("VisorModule_" .. s[1], V(0.2, 0.34, 0.34), offset(s[2] * 0.7, 0.1, -0.1), violet, M.Metal, "Can")
		end
		m("VisorFrameTop", V(1.3, 0.08, 0.08), offset(0, 0.36, -0.66), gold, M.Metal)
		m("VisorFrameBottom", V(1.0, 0.08, 0.08), offset(0, -0.14, -0.74), gold, M.Metal)
		m("VisorBridge", V(0.14, 0.34, 0.14), offset(0, 0.1, -0.76), gold, M.Metal)
		for i, p in ipairs({{-0.3, 0.2}, {0.2, 0.0}, {0.34, 0.26}}) do m("VisorStar" .. i, V(0.07, 0.07, 0.04), offset(p[1], p[2], -0.78), C(255, 244, 190), nil, "Disc") end
		m("TopPlanetStem", V(0.05, 0.34, 0.05), offset(0, 0.76, -0.1), gold, M.Metal, "Can")
		m("TopPlanet", V(0.34, 0.34, 0.34), offset(0, 1.0, -0.1), teal, nil, "Ball")
		m("TopPlanetRing", V(0.72, 0.05, 0.72), offset(0, 1.0, -0.1, 0, 0, 16), gold, M.Metal, "Can")
	end
end

-- ---------------------------------------------------------------------------------------
-- Effects: sprint trails and rarity auras. Both are tiny and switched off by distance LOD elsewhere.
-- ---------------------------------------------------------------------------------------
local function trailEnabled(rig, root, humanoid)
	return rig:GetAttribute("CatchPreview") == true or (humanoid ~= nil and humanoid.Health > 0
		and not root.Anchored and rig:GetAttribute("RoundFrozen") ~= true
		and rig:GetAttribute("Sprinting") == true
		and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 3)
end

local function addTrail(folder, rig, id)
	if not Trails.Has(id) then return end
	local root = rig:FindFirstChild("HumanoidRootPart")
	local mount = attach(folder, root, "TrailMount", Vector3.new(0.05, 0.05, 0.05), offset(0, -0.55, 0.6), Color3.new())
	if not mount then return end
	mount.Transparency = 1
	Trails.Populate(mount, id, trailEnabled(rig, root, rig:FindFirstChildOfClass("Humanoid")))
	rig:SetAttribute("CatchTrail", id)
end

-- Ambient auras: one small emitter per Epic/Legendary skin. `kind` shapes the motion. Particle budget: at most
-- 16 per second, one emitter per avatar.
local AURA_TEXTURES = {
	sparkles = "rbxasset://textures/particles/sparkles_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}
local AURAS = {
	gold = {rate = 7, life = {1.0, 1.8}, speed = {0.5, 1.5}, spread = 180, accel = V(0, 0.8, 0), size = {0.5, 0}, emission = 0.5},
	stars = {rate = 7, life = {1.0, 1.8}, speed = {0.5, 1.5}, spread = 180, accel = V(0, 0.8, 0), size = {0.5, 0}, emission = 0.5},
	sprinkles = {rate = 7, life = {1.0, 1.8}, speed = {0.5, 1.5}, spread = 180, accel = V(0, 0.8, 0), size = {0.5, 0}, emission = 0.5},
	dust = {rate = 5, life = {0.8, 1.4}, speed = {0.4, 1.2}, spread = 180, accel = V(0, 0.5, 0), size = {0.4, 0}, emission = 0.5},
	confetti = {rate = 9, life = {1.0, 1.6}, speed = {1, 3}, spread = 180, accel = V(0, -1.5, 0), size = {0.4, 0.2}, emission = 0.3},
	stardust = {rate = 10, life = {1.2, 2.0}, speed = {0.4, 1.4}, spread = 180, accel = V(0, 0.5, 0), size = {0.55, 0}, emission = 0.8},
	embers = {rate = 9, life = {0.9, 1.6}, speed = {1.5, 3}, spread = 30, accel = V(0, 4, 0), size = {0.4, 0}, emission = 0.6},
	jet = {rate = 14, life = {0.25, 0.45}, speed = {5, 8}, spread = 8, accel = V(0, -6, 0), size = {0.5, 0}, emission = 0.7},
	wisps = {rate = 6, life = {1.2, 2.0}, speed = {0.8, 1.6}, spread = 60, accel = V(0, 1.2, 0), size = {0.7, 0.1}, emission = 0.3},
	smoke = {rate = 5, life = {1.0, 1.6}, speed = {0.3, 0.9}, spread = 80, accel = V(0, 0.6, 0), size = {0.8, 1.8}, emission = 0, texture = "smoke", alpha = 0.5},
}
Appearance.AuraKinds = AURAS

local function addAura(folder, rig, definition)
	local aura = definition.aura
	if not aura then return end
	local spec = AURAS[aura.kind] or AURAS.wisps
	local target = bodyPart(rig, aura.mount or "UpperTorso")
	local mount = attach(folder, target, "AuraMount", V(0.2, 0.2, 0.2), aura.at or offset(0, 0, 0), Color3.new())
	if not mount then return end
	mount.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Name = "Aura_" .. aura.kind
	e.Color = ColorSequence.new(aura.color[1], aura.color[2])
	e.LockedToPart = aura.kind == "jet"
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.Texture = AURA_TEXTURES[spec.texture or "sparkles"]
	e.Rate = spec.rate
	e.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
	e.Speed = NumberRange.new(spec.speed[1], spec.speed[2])
	e.SpreadAngle = Vector2.new(spec.spread, spec.spread)
	e.Acceleration = spec.accel
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, spec.size[1]), NumberSequenceKeypoint.new(1, spec.size[2])})
	e.LightEmission = spec.emission
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, spec.alpha or 0.2), NumberSequenceKeypoint.new(1, 1)})
	e.Enabled = true
	e.Parent = mount
end

-- ---------------------------------------------------------------------------------------
-- Reversible changes to the player's own avatar (hair hiding and full-body tint).
-- ---------------------------------------------------------------------------------------
local function restoreAvatar(rig)
	for _, descendant in ipairs(rig:GetDescendants()) do
		if descendant:IsA("BasePart") then
			local transparency = descendant:GetAttribute("CatchOriginalTransparency")
			if transparency ~= nil then
				descendant.Transparency = transparency
				descendant:SetAttribute("CatchOriginalTransparency", nil)
			end
			local color = descendant:GetAttribute("CatchOriginalColor")
			if color ~= nil then
				descendant.Color = color
				descendant:SetAttribute("CatchOriginalColor", nil)
				local material = descendant:GetAttribute("CatchOriginalMaterial")
				if material ~= nil then descendant.Material = Enum.Material[material] or descendant.Material end
				descendant:SetAttribute("CatchOriginalMaterial", nil)
			end
		end
	end
	local stash = rig:FindFirstChild("CatchStash")
	if stash then
		for _, item in ipairs(stash:GetChildren()) do item.Parent = rig end
		stash:Destroy()
	end
end

local TINT_PARTS = {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand",
	"LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}

-- Accessory kinds hidden while a costume is worn. "hair" is just hair and hats; "outfit" also hides layered clothing,
-- back/shoulder/waist items and shoes so nothing pokes through the costume shells.
local HIDDEN = {
	hair = {Hair = true, Hat = true},
	outfit = {Hair = true, Hat = true, Neck = true, Shoulder = true, Front = true, Back = true, Waist = true, TShirt = true, Shirt = true,
		Pants = true, Jacket = true, Sweater = true, Shorts = true, LeftShoe = true, RightShoe = true, DressSkirt = true},
	face = {Face = true},
}

local function hideWorn(rig, mode)
	local kinds = HIDDEN[mode]
	if not kinds then return end
	for _, child in ipairs(rig:GetChildren()) do
		if child:IsA("Accessory") then
			local ok, kindName = pcall(function() return child.AccessoryType.Name end)
			if ok and kinds[kindName] then
				for _, part in ipairs(child:GetDescendants()) do
					if part:IsA("BasePart") then
						if part:GetAttribute("CatchOriginalTransparency") == nil then part:SetAttribute("CatchOriginalTransparency", part.Transparency) end
						part.Transparency = 1
					end
				end
			end
		end
	end
end

local function stashClothes(rig)
	local stash = rig:FindFirstChild("CatchStash")
	if not stash then
		stash = Instance.new("Folder")
		stash.Name = "CatchStash"
		stash.Parent = rig
	end
	for _, child in ipairs(rig:GetChildren()) do
		if child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") or child:IsA("CharacterMesh") then child.Parent = stash end
	end
end

local function tintAvatar(rig, tint)
	for _, name in ipairs(TINT_PARTS) do
		local part = rig:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			if part:GetAttribute("CatchOriginalColor") == nil then
				part:SetAttribute("CatchOriginalColor", part.Color)
				part:SetAttribute("CatchOriginalMaterial", part.Material.Name)
			end
			part.Color, part.Material = tint.color, tint.material
		end
	end
	if tint.stashClothes then stashClothes(rig) end
end

function Appearance.Apply(rig, skinId, maskId, equipped, identity)
	-- CharacterAdded can fire before all limb parts arrive. Do not replace a good
	-- outfit or claim success until every authored attachment has a valid target.
	if not Appearance.IsRigReady(rig) then return nil end
	local old = rig:FindFirstChild("CatchAppearance")
	if old then old:Destroy() end
	restoreAvatar(rig)
	skinId = skins[skinId] and skinId or "skin_courier"
	maskId = masks[maskId] and maskId or ""
	local definition = skins[skinId]
	if definition.hides then
		hideWorn(rig, definition.hides)
		if definition.hides == "outfit" then stashClothes(rig) end
	end
	if maskId ~= "" then hideWorn(rig, "face") end
	if definition.tint then tintAvatar(rig, definition.tint) end
	local folder = Instance.new("Folder")
	folder.Name = "CatchAppearance"
	folder.Parent = rig
	local kit = {isR6 = rig:FindFirstChild("UpperTorso") == nil, headwear = definition.headwear == true}
	kit.p = function(targetName, name, size, cf, color, material, shape, opts)
		return attach(folder, bodyPart(rig, targetName), name, size, cf, color, material, shape, opts)
	end
	definition.build(kit)
	buildMask(kit, maskId)
	addAura(folder, rig, definition)
	rig:SetAttribute("CatchTrail", nil)
	if equipped then addTrail(folder, rig, equipped.trails) end
	folder:SetAttribute("AppearanceVersion", Appearance.Version)
	folder:SetAttribute("SkinId", skinId)
	folder:SetAttribute("MaskId", maskId)
	rig:SetAttribute("CatchAppearanceVersion", Appearance.Version)
	rig:SetAttribute("CatchAppearanceSkinId", skinId)
	rig:SetAttribute("CatchAppearanceRig", kit.isR6 and "R6" or "R15")
	return folder
end

-- Temporary team identity is separate from persistent ownership/equipment. It never replaces a chosen
-- mask or skin and is removed on spectator/lobby roles. Hunters get cuffs, a badge and a red outline.
function Appearance.ApplyRole(rig, role)
	if not Appearance.IsRigReady(rig) then return nil end
	local old = rig:FindFirstChild("CatchRoleAppearance")
	if old then old:Destroy() end
	rig:SetAttribute("CatchAppearanceRole", role or "Lobby")
	if role ~= "Hunter" then return nil end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "CatchRoleAppearance", rig
	local coral, dark = C(255, 84, 70), C(60, 24, 34)
	for _, side in ipairs({"Left", "Right"}) do
		local arm = bodyPart(rig, side .. "LowerArm")
		attach(folder, arm, "HunterCuff", Vector3.new(1.16, 0.3, 1.16), offset(0, 0.3, 0), dark)
		attach(folder, arm, "HunterCuffStripe", Vector3.new(1.2, 0.1, 1.2), offset(0, 0.3, 0), coral)
	end
	local chest = bodyPart(rig, "UpperTorso")
	-- A bold diagonal sash, readable from the front and the back at a distance.
	attach(folder, chest, "HunterSashFront", Vector3.new(0.42, 2.4, 0.1), offset(0, 0, -0.54, 0, 0, -38), coral)
	attach(folder, chest, "HunterSashBack", Vector3.new(0.42, 2.4, 0.1), offset(0, 0, 0.54, 0, 0, 38), coral)
	attach(folder, chest, "HunterBadge", Vector3.new(0.5, 0.5, 0.08), offset(0.55, 0.4, -0.54), coral, nil, "Disc")
	attach(folder, chest, "HunterBadgeCore", Vector3.new(0.24, 0.24, 0.06), offset(0.55, 0.4, -0.6), C(255, 235, 235), nil, "Disc")
	local highlight = Instance.new("Highlight")
	highlight.Name, highlight.Adornee = "HunterSilhouette", rig
	highlight.FillTransparency = 1
	highlight.OutlineColor, highlight.OutlineTransparency = coral, 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = folder
	return folder
end

-- ---------------------------------------------------------------------------------------
-- Previews. The best preview is the player's real avatar (built from their HumanoidDescription),
-- so what is shown is exactly what equipping produces. A neutral mannequin is the fallback.
-- ---------------------------------------------------------------------------------------
local function anchorPreview(rig)
	rig:SetAttribute("CatchPreview", true)
	for _, descendant in ipairs(rig:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide, descendant.CanTouch, descendant.CanQuery = false, false, false
		elseif descendant:IsA("BaseScript") or descendant:IsA("Sound") or descendant:IsA("BillboardGui") or descendant:IsA("ForceField")
			or descendant:IsA("Highlight") then
			descendant:Destroy()
		end
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.AutoRotate = false
	end
end

-- Re-derive every part's position from the model's own joints and welds (Motor6D, Weld, ManualWeld) starting at the
-- HumanoidRootPart, with every joint at rest. A model that has never been simulated (a freshly built or cloned avatar
-- that is not in the workspace yet) can have accessory handles sitting wherever they were created, which shows up as
-- hair floating beside the head. Solving the joints puts every handle exactly where the engine's weld says it goes.
function Appearance.SolveRig(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then return 0 end
	local joints = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if (descendant:IsA("Motor6D") or descendant:IsA("Weld") or descendant:IsA("ManualWeld")) and descendant.Part0 and descendant.Part1
			and descendant.Part0:IsA("BasePart") and descendant.Part1:IsA("BasePart") then
			if descendant:IsA("Motor6D") then descendant.Transform = CFrame.new() end
			table.insert(joints, descendant)
		end
	end
	local placed, solved = {[root] = true}, 0
	local progress = true
	while progress do
		progress = false
		for _, joint in ipairs(joints) do
			local first, second = joint.Part0, joint.Part1
			if placed[first] and not placed[second] then
				second.CFrame = first.CFrame * joint.C0 * joint.C1:Inverse()
				placed[second] = true
				solved += 1
				progress = true
			elseif placed[second] and not placed[first] then
				first.CFrame = second.CFrame * joint.C1 * joint.C0:Inverse()
				placed[first] = true
				solved += 1
				progress = true
			end
		end
	end
	return solved
end

-- Checks that every accessory handle sits where its weld says it should. An accessory that cannot be placed
-- correctly is HIDDEN (never shown floating) and reported. Returns the list of problems (empty when all is well).
function Appearance.AuditRig(model)
	local problems = {}
	local root = model:FindFirstChild("HumanoidRootPart")
	for _, accessory in ipairs(model:GetChildren()) do
		if accessory:IsA("Accessory") then
			local handle = accessory:FindFirstChild("Handle")
			local drift
			if handle and handle:IsA("BasePart") then
				local checked = false
				for _, child in ipairs(handle:GetChildren()) do
					if (child:IsA("Weld") or child:IsA("ManualWeld")) and child.Part0 and child.Part1 then
						local expected
						if child.Part1 == handle then expected = child.Part0.CFrame * child.C0 * child.C1:Inverse()
						elseif child.Part0 == handle then expected = child.Part1.CFrame * child.C1 * child.C0:Inverse() end
						if expected then
							drift = (expected.Position - handle.CFrame.Position).Magnitude
							checked = true
						end
					end
				end
				-- No weld at all: it can only be judged by how far it is from the body.
				if not checked and root then drift = math.max(0, (handle.CFrame.Position - root.CFrame.Position).Magnitude - 6) end
			end
			if drift and drift > 0.15 then
				table.insert(problems, string.format("%s is %.1f studs off its attachment and was hidden", accessory.Name, drift))
				for _, part in ipairs(accessory:GetDescendants()) do
					if part:IsA("BasePart") then
						if part:GetAttribute("CatchOriginalTransparency") == nil then part:SetAttribute("CatchOriginalTransparency", part.Transparency) end
						part.Transparency = 1
					end
				end
			end
		end
	end
	return problems
end

-- Turns an avatar model into a posable showroom base: costume leftovers removed, the player's own hair and clothes
-- restored, every joint solved, accessories verified, parts anchored and the root placed at the origin facing -Z.
local function finalizeBase(model)
	for _, name in ipairs({"CatchAppearance", "CatchRoleAppearance"}) do
		local folder = model:FindFirstChild(name)
		if folder then folder:Destroy() end
	end
	restoreAvatar(model)
	Appearance.SolveRig(model)
	local problems = Appearance.AuditRig(model)
	anchorPreview(model)
	if not model.PrimaryPart then model.PrimaryPart = model:FindFirstChild("HumanoidRootPart") end
	-- Same frame as the mannequin: root at the origin, facing -Z, so previews can share cameras.
	pcall(function() model:PivotTo(CFrame.new()) end)
	model:SetAttribute("CatchPreviewReport", #problems == 0 and "ok" or table.concat(problems, "; "))
	return model, problems
end

-- Build a standing model of a real avatar from a HumanoidDescription (yields; wrap in pcall + task.spawn).
function Appearance.BuildAvatar(description, rigType)
	if description == nil then return nil end
	local ok, model = pcall(function()
		return game:GetService("Players"):CreateHumanoidModelFromDescription(description, rigType or Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then return nil end
	model.Name = "CatchAvatarBase"
	return finalizeBase(model)
end

-- The most faithful base: a clone of the player's own assembled character, so every accessory, body scale and
-- texture is exactly what the engine already built for them. Costume parts are stripped and their hidden hair and
-- clothes restored. Returns nil when the character is missing, incomplete or not cloneable.
function Appearance.BuildAvatarFromCharacter(character)
	if not character or not character:IsA("Model") then return nil end
	if not character:FindFirstChildOfClass("Humanoid") or not character:FindFirstChild("HumanoidRootPart") then return nil end
	local archivable = character.Archivable
	pcall(function() character.Archivable = true end)
	local ok, clone = pcall(function() return character:Clone() end)
	pcall(function() character.Archivable = archivable end)
	if not ok or not clone then return nil end
	clone.Name = "CatchAvatarBase"
	return finalizeBase(clone)
end

-- Neutral classic-proportion mannequin with the engine's stock face. Used when no real avatar is available.
function Appearance.BuildMannequin(identity)
	local rig = Instance.new("Model")
	rig.Name = "CatchPreview"
	rig:SetAttribute("CatchPreview", true)
	local tone = toneFor(identity)
	local shirt = Appearance.IdentityColor(identity and identity.userId or 0)
	local pants = C(60, 72, 110)
	local positions = {
		HumanoidRootPart = Vector3.new(0, 0, 0), LowerTorso = Vector3.new(0, -0.1, 0), UpperTorso = Vector3.new(0, 0.9, 0),
		Head = Vector3.new(0, 2.35, 0),
		LeftUpperArm = Vector3.new(-1.5, 1.1, 0), RightUpperArm = Vector3.new(1.5, 1.1, 0),
		LeftLowerArm = Vector3.new(-1.5, 0, 0), RightLowerArm = Vector3.new(1.5, 0, 0),
		LeftHand = Vector3.new(-1.5, -0.7, 0), RightHand = Vector3.new(1.5, -0.7, 0),
		LeftUpperLeg = Vector3.new(-0.5, -0.9, 0), RightUpperLeg = Vector3.new(0.5, -0.9, 0),
		LeftLowerLeg = Vector3.new(-0.5, -2.1, 0), RightLowerLeg = Vector3.new(0.5, -2.1, 0),
		LeftFoot = Vector3.new(-0.5, -2.85, 0), RightFoot = Vector3.new(0.5, -2.85, 0),
	}
	local colors = {
		UpperTorso = shirt, LowerTorso = shirt, LeftUpperArm = shirt, RightUpperArm = shirt,
		LeftLowerArm = tone, RightLowerArm = tone, LeftHand = tone, RightHand = tone, Head = tone,
		LeftUpperLeg = pants, RightUpperLeg = pants, LeftLowerLeg = pants, RightLowerLeg = pants,
		LeftFoot = C(40, 40, 52), RightFoot = C(40, 40, 52),
	}
	for name, position in pairs(positions) do
		local part = Instance.new("Part")
		part.Name = name
		part.Size = name == "Head" and Vector3.new(2, 1, 1) or nominal[name]
		part.CFrame = CFrame.new(position)
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Massless = true
		part.Color = colors[name] or tone
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if name == "HumanoidRootPart" then part.Transparency = 1 end
		if name == "Head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			mesh.Parent = part
			local face = Instance.new("Decal")
			face.Name = "face"
			face.Texture = "rbxasset://textures/face.png"
			face.Face = Enum.NormalId.Front
			face.Parent = part
		end
		part.Parent = rig
	end
	rig.PrimaryPart = rig:FindFirstChild("HumanoidRootPart")
	-- Preview joints make the model recognizable to avatar tools without live physics.
	local joints = {
		{"Root", "HumanoidRootPart", "LowerTorso"}, {"Waist", "LowerTorso", "UpperTorso"}, {"Neck", "UpperTorso", "Head"},
		{"LeftShoulder", "UpperTorso", "LeftUpperArm"}, {"RightShoulder", "UpperTorso", "RightUpperArm"},
		{"LeftElbow", "LeftUpperArm", "LeftLowerArm"}, {"RightElbow", "RightUpperArm", "RightLowerArm"},
		{"LeftWrist", "LeftLowerArm", "LeftHand"}, {"RightWrist", "RightLowerArm", "RightHand"},
		{"LeftHip", "LowerTorso", "LeftUpperLeg"}, {"RightHip", "LowerTorso", "RightUpperLeg"},
		{"LeftKnee", "LeftUpperLeg", "LeftLowerLeg"}, {"RightKnee", "RightUpperLeg", "RightLowerLeg"},
		{"LeftAnkle", "LeftLowerLeg", "LeftFoot"}, {"RightAnkle", "RightLowerLeg", "RightFoot"},
	}
	for _, spec in ipairs(joints) do
		local joint = Instance.new("Motor6D")
		joint.Name, joint.Part0, joint.Part1 = spec[1], rig:FindFirstChild(spec[2]), rig:FindFirstChild(spec[3])
		joint.C0 = joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame)
		joint.Parent = joint.Part0
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.AutoRotate = false
	humanoid.Parent = rig
	return rig
end

-- `base` is an optional avatar model from BuildAvatar (cached by the caller). It is cloned, never modified.
function Appearance.BuildPreview(skinId, maskId, extra, identity, base)
	local rig
	if base and base:IsA("Model") then
		local ok, copy = pcall(function() return base:Clone() end)
		if ok and copy then
			rig = copy
			rig.Name = "CatchPreview"
			rig:SetAttribute("CatchPreview", true)
		end
	end
	rig = rig or Appearance.BuildMannequin(identity)
	Appearance.Apply(rig, skinId, maskId, extra, identity)
	return rig
end

return Appearance
