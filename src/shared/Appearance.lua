-- Original, asset-free character presentation shared by live avatars and viewport previews.
-- Every outfit is built from the body itself (direct limb colors) plus welded, massless,
-- non-colliding detail parts. Faces are real geometry driven by a mood, so emotions replicate.
-- Cosmetic only: nothing here touches collision, speed, hitboxes or tag raycasts.
local Appearance = {Version = 3}

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
-- modern mesh heads both keep faces and hats in proportion.
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
	if opts then
		if opts.hair then part:SetAttribute("CatchHair", true) end
		if opts.expr then part:SetAttribute("CatchExpr", opts.expr) end
	end
	return part
end

-- Skin tones and hair colors are free personalization, independent of the outfit.
Appearance.Tones = {
	tone_porcelain = C(255, 224, 205), tone_sand = C(240, 196, 150), tone_honey = C(222, 164, 112),
	tone_amber = C(190, 128, 84), tone_cocoa = C(140, 90, 62), tone_ebony = C(92, 58, 44),
}
Appearance.ToneOrder = {"tone_porcelain", "tone_sand", "tone_honey", "tone_amber", "tone_cocoa", "tone_ebony"}
Appearance.HairColors = {
	hair_black = C(34, 30, 38), hair_brown = C(112, 70, 44), hair_blonde = C(246, 208, 108),
	hair_ginger = C(224, 104, 58), hair_pink = C(255, 120, 190), hair_blue = C(72, 140, 255),
	hair_mint = C(80, 224, 180), hair_white = C(240, 240, 250),
}
Appearance.HairOrder = {"hair_black", "hair_brown", "hair_blonde", "hair_ginger", "hair_pink", "hair_blue", "hair_mint", "hair_white"}

local function toneFor(identity, equipped)
	local id = equipped and equipped.tones
	if id and Appearance.Tones[id] then return Appearance.Tones[id] end
	-- "Auto" gives every player a stable, distinct tone derived from their user id.
	local index = (math.abs(identity and identity.userId or 0) % #Appearance.ToneOrder) + 1
	return Appearance.Tones[Appearance.ToneOrder[index]]
end
function Appearance.IdentityColor(userId)
	local hue = ((math.abs(tonumber(userId) or 0) * 37) % 360) / 360
	return Color3.fromHSV(hue, 0.65, 1)
end

-- ---------------------------------------------------------------------------------------
-- Skins. Each definition lists limb colors and a builder of detail parts.
-- ---------------------------------------------------------------------------------------
local skins = {}

local function shoes(k, st)
	for _, s in ipairs(SIDES) do
		local side, sx = s[1], s[2]
		if k.isR6 then k.p(side .. "Foot", "ShoeUpper_" .. side, Vector3.new(1.02, 0.34, 1.04), offset(0, 0.02, 0), st.upper) end
		k.p(side .. "Foot", "ShoeSole_" .. side, Vector3.new(1.08, 0.12, 1.2), offset(0, -0.1, -0.04), st.sole, st.soleMat)
		k.p(side .. "Foot", "ShoeToe_" .. side, Vector3.new(0.98, 0.2, 0.42), offset(0, 0.06, -0.4), st.toe or st.upper)
		k.p(side .. "Foot", "ShoeStripe_" .. side, Vector3.new(0.05, 0.2, 0.66), offset(sx * 0.52, 0.05, 0.04), st.accent, st.stripeMat)
		if st.high then
			k.p(side .. "LowerLeg", "ShoeCuff_" .. side, Vector3.new(1.08, 0.38, 1.08), offset(0, -0.4, 0), st.upper)
			k.p(side .. "LowerLeg", "ShoeCuffRim_" .. side, Vector3.new(1.1, 0.07, 1.1), offset(0, -0.2, 0), st.accent, st.stripeMat)
		end
	end
end

local function wristbands(k, color, material)
	for _, s in ipairs(SIDES) do
		k.p(s[1] .. "LowerArm", "Wristband_" .. s[1], Vector3.new(1.08, 0.2, 1.08), offset(0, -0.34, 0), color, material)
	end
end

skins.skin_courier = {
	paint = {top = C(255, 108, 92), waist = C(66, 112, 196), upperArm = C(255, 108, 92), lowerArm = C(255, 108, 92),
		upperLeg = C(66, 112, 196), lowerLeg = C(66, 112, 196), foot = C(250, 250, 252)},
	iris = C(88, 62, 40), hair = C(98, 62, 40),
	build = function(k)
		local navy, coral, dark = C(38, 54, 112), C(255, 108, 92), C(214, 78, 66)
		-- Forward cap with hair peeking out the sides.
		k.p("Head", "CapCrown", Vector3.new(1.34, 0.8, 1.34), offset(0, 0.56, 0.02), navy, nil, "Ball")
		k.p("Head", "CapBand", Vector3.new(1.3, 0.14, 1.3), offset(0, 0.46, 0.02), navy)
		k.p("Head", "CapBrim", Vector3.new(1.0, 0.07, 0.62), offset(0, 0.48, -0.8, 8), navy)
		k.p("Head", "CapButton", Vector3.new(0.14, 0.1, 0.14), offset(0, 0.96, 0.02), coral, nil, "Ball")
		k.p("Head", "CapLogo", Vector3.new(0.3, 0.3, 0.05), offset(0, 0.7, -0.66, 0, 0, 45), coral)
		for _, s in ipairs(SIDES) do
			k.p("Head", "SideLock_" .. s[1], Vector3.new(0.2, 0.46, 0.5), offset(s[2] * 0.6, 0.14, 0.12), k.hair, nil, "Ball", {hair = true})
		end
		k.p("Head", "BackHair", Vector3.new(1.1, 0.5, 0.3), offset(0, 0.0, 0.6), k.hair, nil, "Ball", {hair = true})
		-- Hoodie: hood, pocket, drawstrings, ribbed hem and cuffs.
		k.p("UpperTorso", "HoodBack", Vector3.new(1.5, 0.62, 0.7), offset(0, 0.7, 0.55), coral, nil, "Ball")
		k.p("UpperTorso", "HoodieLogo", Vector3.new(0.34, 0.34, 0.05), offset(0.5, 0.35, -0.53), C(255, 255, 255), nil, "Disc")
		k.p("UpperTorso", "HoodiePocket", Vector3.new(1.3, 0.5, 0.1), offset(0, -0.3, -0.54), dark)
		for _, x in ipairs({-0.2, 0.2}) do k.p("UpperTorso", "Drawstring", Vector3.new(0.06, 0.5, 0.05), offset(x, 0.45, -0.53), C(250, 250, 250)) end
		k.p("LowerTorso", "HoodieHem", Vector3.new(2.08, 0.16, 1.08), offset(0, 0.06, 0), dark)
		for _, s in ipairs(SIDES) do
			k.p(s[1] .. "LowerArm", "SleeveCuff_" .. s[1], Vector3.new(1.08, 0.18, 1.08), offset(0, -0.4, 0), dark)
			k.p(s[1] .. "LowerLeg", "JeanCuff_" .. s[1], Vector3.new(1.06, 0.14, 1.06), offset(0, -0.48, 0), C(150, 190, 245))
			k.p(s[1] .. "UpperLeg", "JeanPocket_" .. s[1], Vector3.new(0.05, 0.4, 0.4), offset(s[2] * 0.52, 0.1, 0.0), C(48, 88, 160))
		end
		shoes(k, {upper = C(250, 250, 252), sole = C(255, 108, 92), toe = C(236, 238, 245), accent = navy})
	end,
}

skins.skin_rooftop = {
	paint = {top = C(46, 196, 190), waist = C(240, 176, 56), upperArm = C(46, 196, 190), lowerArm = "skin",
		upperLeg = C(240, 176, 56), lowerLeg = "skin", foot = C(30, 30, 38)},
	iris = C(40, 120, 90), hair = C(236, 120, 58),
	build = function(k)
		local yellow, white, red, purple = C(255, 214, 64), C(250, 250, 252), C(236, 70, 80), C(138, 92, 214)
		-- Slouchy beanie with a fold, stripe and pompom; messy hair bursting out below.
		k.p("Head", "Beanie", Vector3.new(1.34, 0.9, 1.34), offset(0, 0.58, 0.02), yellow, nil, "Ball")
		k.p("Head", "BeanieFold", Vector3.new(1.36, 0.22, 1.36), offset(0, 0.5, 0.02), white)
		k.p("Head", "BeanieStripe", Vector3.new(1.3, 0.1, 1.3), offset(0, 0.76, 0.02), red)
		k.p("Head", "Pompom", Vector3.new(0.34, 0.34, 0.34), offset(0, 1.1, 0.02), red, nil, "Ball")
		for _, s in ipairs(SIDES) do
			k.p("Head", "MessyTuft_" .. s[1], Vector3.new(0.3, 0.5, 0.45), offset(s[2] * 0.62, 0.05, -0.05, 0, 0, s[2] * -12), k.hair, nil, "Ball", {hair = true})
		end
		k.p("Head", "FringeTuft", Vector3.new(0.5, 0.2, 0.2), offset(0.2, 0.5, -0.6, 0, 0, -10), k.hair, nil, "Ball", {hair = true})
		-- Oversized graphic tee with a star badge; cargo shorts with socks.
		k.p("UpperTorso", "TeeStripe", Vector3.new(2.06, 0.26, 1.06), offset(0, 0.2, 0), white)
		k.p("UpperTorso", "StarBadge", Vector3.new(0.4, 0.4, 0.05), offset(0, -0.3, -0.53), yellow, nil, "Disc")
		k.p("UpperTorso", "StarCore", Vector3.new(0.18, 0.18, 0.05), offset(0, -0.3, -0.57), red, nil, "Disc")
		for _, s in ipairs(SIDES) do
			k.p(s[1] .. "UpperArm", "SleeveHem_" .. s[1], Vector3.new(1.08, 0.12, 1.08), offset(0, -0.52, 0), white)
			k.p(s[1] .. "UpperLeg", "ShortsHem_" .. s[1], Vector3.new(1.08, 0.14, 1.08), offset(0, -0.5, 0), C(200, 140, 30))
			k.p(s[1] .. "UpperLeg", "CargoPocket_" .. s[1], Vector3.new(0.14, 0.5, 0.64), offset(s[2] * 0.54, -0.1, 0), C(200, 140, 30))
			k.p(s[1] .. "LowerLeg", "Sock_" .. s[1], Vector3.new(1.06, 0.62, 1.06), offset(0, -0.25, 0), white)
			k.p(s[1] .. "LowerLeg", "SockBand_" .. s[1], Vector3.new(1.08, 0.1, 1.08), offset(0, -0.1, 0), red)
		end
		-- Deck on the back: a real silhouette from the side and behind.
		k.p("UpperTorso", "SkateDeck", Vector3.new(0.9, 2.5, 0.12), offset(0, -0.2, 0.64, 0, 0, 14), purple)
		k.p("UpperTorso", "DeckGrip", Vector3.new(0.84, 2.3, 0.04), offset(0, -0.2, 0.7, 0, 0, 14), C(34, 34, 40))
		for _, y in ipairs({-1.1, 0.7}) do
			for _, x in ipairs({-0.3, 0.3}) do
				k.p("UpperTorso", "SkateWheel", Vector3.new(0.22, 0.22, 0.22), offset(x - y * 0.07, y, 0.78), white, nil, "Ball")
			end
		end
		wristbands(k, red)
		shoes(k, {upper = C(30, 30, 38), sole = white, toe = white, accent = white})
	end,
}

skins.skin_streetwear = {
	paint = {top = C(248, 238, 214), waist = C(28, 28, 34), upperArm = C(26, 26, 32), lowerArm = C(26, 26, 32),
		upperLeg = C(28, 28, 34), lowerLeg = C(28, 28, 34), foot = C(250, 250, 252)},
	iris = C(120, 74, 40), hair = C(40, 28, 24),
	build = function(k)
		local gold, red, black, cream = C(255, 200, 60), C(232, 60, 70), C(26, 26, 32), C(248, 238, 214)
		-- Bucket hat over curly hair, gold hoops.
		k.p("Head", "BucketCrown", Vector3.new(1.3, 0.62, 1.3), offset(0, 0.86, 0.02), black, nil, "Can")
		k.p("Head", "BucketCrownTop", Vector3.new(1.2, 0.1, 1.2), offset(0, 1.2, 0.02), black, nil, "Can")
		k.p("Head", "BucketBrim", Vector3.new(1.9, 0.07, 1.9), offset(0, 0.56, 0.02), black, nil, "Can")
		k.p("Head", "BucketBand", Vector3.new(1.34, 0.14, 1.34), offset(0, 0.64, 0.02), gold, Enum.Material.Metal, "Can")
		for _, s in ipairs(SIDES) do
			k.p("Head", "CurlPuff_" .. s[1], Vector3.new(0.34, 0.4, 0.5), offset(s[2] * 0.62, 0.02, 0.1), k.hair, nil, "Ball", {hair = true})
			k.p("Head", "Hoop_" .. s[1], Vector3.new(0.05, 0.3, 0.3), offset(s[2] * 0.66, -0.2, -0.04), gold, Enum.Material.Metal, "Cylinder")
		end
		-- Varsity jacket: ribbed collar/hem, gold sleeve stripes, patch, chunky chains.
		k.p("UpperTorso", "VarsityCollar", Vector3.new(1.3, 0.2, 1.0), offset(0, 0.78, 0.02), black)
		k.p("LowerTorso", "VarsityHem", Vector3.new(2.08, 0.16, 1.08), offset(0, 0.08, 0), black)
		k.p("UpperTorso", "VarsityPlacket", Vector3.new(0.1, 1.3, 0.05), offset(0, -0.05, -0.53), black)
		k.p("UpperTorso", "VarsityPatch", Vector3.new(0.44, 0.44, 0.05), offset(-0.55, 0.2, -0.53), red, nil, "Disc")
		k.p("UpperTorso", "VarsityPatchRim", Vector3.new(0.5, 0.5, 0.04), offset(-0.55, 0.2, -0.52), gold, Enum.Material.Metal, "Disc")
		for _, s in ipairs(SIDES) do
			k.p(s[1] .. "UpperArm", "SleeveStripe_" .. s[1], Vector3.new(1.06, 0.1, 1.06), offset(0, 0.2, 0), gold, Enum.Material.Metal)
			k.p(s[1] .. "UpperLeg", "TrackStripe_" .. s[1], Vector3.new(0.05, 1.18, 0.2), offset(s[2] * 0.52, 0, 0), red)
			k.p(s[1] .. "LowerLeg", "TrackStripeLow_" .. s[1], Vector3.new(0.05, 1.18, 0.2), offset(s[2] * 0.52, 0, 0), red)
		end
		local chain = {{-0.5, 0.6}, {-0.34, 0.38}, {-0.14, 0.24}, {0.14, 0.24}, {0.34, 0.38}, {0.5, 0.6}}
		for i, c in ipairs(chain) do
			k.p("UpperTorso", "ChainLink" .. i, Vector3.new(0.13, 0.13, 0.13), offset(c[1], c[2], -0.56), gold, Enum.Material.Metal, "Ball")
		end
		k.p("UpperTorso", "ChainPendant", Vector3.new(0.34, 0.34, 0.07), offset(0, -0.02, -0.57), gold, Enum.Material.Metal, "Disc")
		k.p("UpperTorso", "ChainGem", Vector3.new(0.16, 0.16, 0.05), offset(0, -0.02, -0.62), red, Enum.Material.Neon, "Disc")
		-- Crossbody bag.
		k.p("UpperTorso", "BagStrap", Vector3.new(0.14, 2.1, 0.05), offset(0, 0, -0.53, 0, 0, -38), red)
		k.p("LowerTorso", "BagBody", Vector3.new(0.7, 0.62, 0.34), offset(-0.85, -0.15, -0.3), red)
		k.p("LowerTorso", "BagFlap", Vector3.new(0.72, 0.2, 0.36), offset(-0.85, 0.05, -0.3), black)
		wristbands(k, gold, Enum.Material.Metal)
		shoes(k, {upper = C(250, 250, 252), sole = gold, soleMat = Enum.Material.Metal, toe = red, accent = red, high = true})
	end,
}

skins.skin_neonphantom = {
	paint = {top = C(26, 22, 44), waist = C(22, 18, 38), upperArm = C(26, 22, 44), lowerArm = C(26, 22, 44),
		upperLeg = C(22, 18, 38), lowerLeg = C(22, 18, 38), foot = C(28, 24, 44)},
	iris = C(255, 70, 210), hair = C(255, 70, 210),
	build = function(k)
		local neon, cyan, dark = C(255, 70, 210), C(70, 240, 255), C(32, 26, 54)
		local N = Enum.Material.Neon
		-- Hood up with a glowing rim; the face stays readable inside.
		k.p("Head", "HoodShell", Vector3.new(1.58, 1.4, 1.5), offset(0, 0.14, 0.18), dark, nil, "Ball")
		for _, s in ipairs(SIDES) do
			k.p("Head", "HoodCheek_" .. s[1], Vector3.new(0.26, 1.0, 0.9), offset(s[2] * 0.68, -0.02, -0.02), dark)
			k.p("Head", "HoodRimSide_" .. s[1], Vector3.new(0.06, 0.9, 0.06), offset(s[2] * 0.62, 0.02, -0.5), neon, N)
		end
		k.p("Head", "HoodBrow", Vector3.new(1.3, 0.34, 0.9), offset(0, 0.62, -0.28, -12), dark)
		k.p("Head", "HoodRimTop", Vector3.new(1.2, 0.06, 0.06), offset(0, 0.45, -0.7), neon, N)
		k.p("Head", "FringeGlow", Vector3.new(0.7, 0.18, 0.2), offset(0.2, 0.4, -0.55, 0, 0, -8), k.hair, nil, "Ball", {hair = true})
		-- Light piping on a black techwear hoodie.
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "FrontPiping_" .. s[1], Vector3.new(0.07, 1.5, 0.05), offset(s[2] * 0.52, 0, -0.53), neon, N)
			k.p(s[1] .. "UpperArm", "ArmPiping_" .. s[1], Vector3.new(0.06, 1.1, 0.2), offset(s[2] * 0.52, 0, 0), neon, N)
			k.p(s[1] .. "LowerArm", "ForearmPiping_" .. s[1], Vector3.new(0.06, 0.9, 0.2), offset(s[2] * 0.52, 0, 0), neon, N)
			k.p(s[1] .. "UpperLeg", "LegPiping_" .. s[1], Vector3.new(0.06, 1.1, 0.16), offset(s[2] * 0.52, 0, 0), cyan, N)
			k.p(s[1] .. "LowerLeg", "ShinPiping_" .. s[1], Vector3.new(0.06, 1.0, 0.16), offset(s[2] * 0.52, 0, 0), cyan, N)
			k.p(s[1] .. "LowerLeg", "AnkleCuff_" .. s[1], Vector3.new(1.08, 0.22, 1.08), offset(0, -0.45, 0), dark)
		end
		k.p("UpperTorso", "ChestGlyph", Vector3.new(0.4, 0.4, 0.05), offset(0, 0.28, -0.53, 0, 0, 45), neon, N)
		k.p("UpperTorso", "ChestGlyphCore", Vector3.new(0.18, 0.18, 0.06), offset(0, 0.28, -0.56, 0, 0, 45), dark)
		k.p("LowerTorso", "UtilityBelt", Vector3.new(2.08, 0.16, 1.08), offset(0, 0.08, 0), dark)
		k.p("LowerTorso", "BeltBuckle", Vector3.new(0.3, 0.14, 0.06), offset(0, 0.08, -0.56), cyan, N)
		-- Two phantom ribbons trailing behind.
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "PhantomRibbon_" .. s[1], Vector3.new(0.34, 2.2, 0.08), offset(s[2] * 0.5, -0.9, 0.7, 14, 0, s[2] * -6), neon, N, nil, {transparency = 0.25})
		end
		wristbands(k, cyan, N)
		shoes(k, {upper = C(28, 24, 44), sole = cyan, soleMat = N, toe = dark, accent = neon, stripeMat = N})
	end,
}

skins.skin_ninja = {
	paint = {top = C(40, 46, 70), waist = C(40, 46, 70), upperArm = C(40, 46, 70), lowerArm = C(40, 46, 70),
		upperLeg = C(34, 38, 60), lowerLeg = C(34, 38, 60), foot = C(24, 24, 32)},
	iris = C(235, 50, 60), hair = C(28, 26, 34),
	build = function(k)
		local red, steel, wrap = C(226, 48, 58), C(180, 196, 214), C(214, 208, 192)
		-- Headband with a steel plate, topknot and trailing tails.
		k.p("Head", "NinjaHair", Vector3.new(1.3, 0.6, 1.3), offset(0, 0.56, 0.06), k.hair, nil, "Ball", {hair = true})
		k.p("Head", "Topknot", Vector3.new(0.4, 0.4, 0.4), offset(0, 0.82, 0.3), k.hair, nil, "Ball", {hair = true})
		k.p("Head", "Headband", Vector3.new(1.28, 0.2, 1.28), offset(0, 0.5, 0.02), red)
		k.p("Head", "HeadbandPlate", Vector3.new(0.56, 0.3, 0.06), offset(0, 0.5, -0.66), steel, Enum.Material.Metal)
		k.p("Head", "HeadbandMark", Vector3.new(0.18, 0.18, 0.05), offset(0, 0.5, -0.7, 0, 0, 45), red)
		for _, s in ipairs(SIDES) do
			k.p("Head", "HeadbandTail_" .. s[1], Vector3.new(0.18, 0.9, 0.06), offset(s[2] * 0.2, -0.2, 0.7, 14, 0, s[2] * -8), red)
		end
		-- Crossed gi, wide sash, forearm and shin wraps.
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "GiLapel_" .. s[1], Vector3.new(0.2, 1.4, 0.06), offset(s[2] * 0.22, 0.05, -0.53, 0, 0, s[2] * -22), C(214, 218, 232))
			k.p(s[1] .. "LowerArm", "ForearmWrap_" .. s[1], Vector3.new(1.1, 0.7, 1.1), offset(0, -0.12, 0), wrap)
			k.p(s[1] .. "LowerLeg", "ShinWrap_" .. s[1], Vector3.new(1.08, 0.7, 1.08), offset(0, -0.1, 0), wrap)
			k.p(s[1] .. "LowerLeg", "ShinWrapKnot_" .. s[1], Vector3.new(0.2, 0.2, 0.06), offset(s[2] * 0.1, 0.0, -0.55), red)
		end
		k.p("LowerTorso", "Sash", Vector3.new(2.1, 0.34, 1.1), offset(0, 0.04, 0), red)
		k.p("LowerTorso", "SashKnot", Vector3.new(0.4, 0.4, 0.14), offset(-0.5, 0.02, -0.58), red, nil, "Ball")
		k.p("LowerTorso", "SashTailA", Vector3.new(0.22, 0.9, 0.06), offset(-0.55, -0.45, -0.6, 8, 0, 8), red)
		k.p("LowerTorso", "SashTailB", Vector3.new(0.22, 0.8, 0.06), offset(-0.4, -0.42, -0.6, 8, 0, -10), red)
		-- Katana across the back, shuriken at the hip.
		k.p("UpperTorso", "KatanaSheath", Vector3.new(0.18, 2.5, 0.16), offset(0, 0, 0.62, 0, 0, 38), C(30, 30, 36))
		k.p("UpperTorso", "KatanaHandle", Vector3.new(0.2, 0.55, 0.2), offset(-0.82, 0.88, 0.62, 0, 0, 38), red)
		k.p("UpperTorso", "KatanaGuard", Vector3.new(0.5, 0.08, 0.3), offset(-0.64, 0.62, 0.62, 0, 0, 38), C(255, 200, 60), Enum.Material.Metal)
		k.p("LowerTorso", "ShurikenA", Vector3.new(0.5, 0.08, 0.08), offset(0.85, 0, -0.56), steel, Enum.Material.Metal)
		k.p("LowerTorso", "ShurikenB", Vector3.new(0.08, 0.5, 0.08), offset(0.85, 0, -0.57), steel, Enum.Material.Metal)
		k.p("UpperTorso", "ChestStrap", Vector3.new(0.12, 1.9, 0.05), offset(0, 0, -0.53, 0, 0, 38), C(30, 30, 36))
		shoes(k, {upper = C(24, 24, 32), sole = C(60, 60, 72), toe = C(24, 24, 32), accent = red})
	end,
}

skins.skin_cyber = {
	paint = {top = C(236, 244, 252), waist = C(60, 72, 96), upperArm = C(236, 244, 252), lowerArm = C(60, 72, 96),
		upperLeg = C(236, 244, 252), lowerLeg = C(60, 72, 96), foot = C(236, 244, 252)},
	iris = C(40, 220, 255), hair = C(110, 140, 255),
	build = function(k)
		local cyan, teal, dark = C(70, 240, 255), C(30, 190, 200), C(50, 60, 84)
		local N = Enum.Material.Neon
		-- Spiked hair, comm headset and mic boom.
		for i, x in ipairs({-0.34, 0, 0.34}) do
			k.p("Head", "HairSpike" .. i, Vector3.new(0.4, 0.6, 0.5), offset(x, 0.5, -0.04, 0, 0, x * -40), k.hair, nil, "Ball", {hair = true})
		end
		k.p("Head", "HairBase", Vector3.new(1.26, 0.4, 1.2), offset(0, 0.4, 0.06), k.hair, nil, "Ball", {hair = true})
		for _, s in ipairs(SIDES) do
			k.p("Head", "EarCup_" .. s[1], Vector3.new(0.18, 0.5, 0.5), offset(s[2] * 0.68, -0.02, 0.06), dark, Enum.Material.Metal, "Cylinder")
			k.p("Head", "EarGlow_" .. s[1], Vector3.new(0.04, 0.3, 0.3), offset(s[2] * 0.78, -0.02, 0.06), cyan, N, "Cylinder")
		end
		k.p("Head", "HeadsetBand", Vector3.new(1.46, 0.08, 0.14), offset(0, 0.62, 0.06), dark, Enum.Material.Metal)
		k.p("Head", "MicBoom", Vector3.new(0.05, 0.05, 0.6), offset(-0.7, -0.3, -0.36, 0, 24, 0), dark)
		k.p("Head", "MicTip", Vector3.new(0.12, 0.12, 0.12), offset(-0.56, -0.3, -0.66), cyan, N, "Ball")
		-- Armor plates, glowing core and panel seams.
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "ShoulderPlate_" .. s[1], Vector3.new(0.9, 0.3, 1.2), offset(s[2] * 1.0, 0.82, 0, 0, 0, s[2] * 14), teal, Enum.Material.Metal)
			k.p("UpperTorso", "ShoulderRim_" .. s[1], Vector3.new(0.9, 0.06, 1.24), offset(s[2] * 1.0, 0.66, 0, 0, 0, s[2] * 14), cyan, N)
			k.p("UpperTorso", "ChestSeam_" .. s[1], Vector3.new(0.06, 1.2, 0.05), offset(s[2] * 0.62, -0.05, -0.53), teal)
			k.p(s[1] .. "LowerArm", "ForearmGlow_" .. s[1], Vector3.new(0.05, 0.8, 0.3), offset(s[2] * 0.52, 0, 0), cyan, N)
			k.p(s[1] .. "LowerArm", "Gauntlet_" .. s[1], Vector3.new(1.08, 0.5, 1.08), offset(0, -0.2, 0), dark, Enum.Material.Metal)
			k.p(s[1] .. "LowerLeg", "ShinGlow_" .. s[1], Vector3.new(0.05, 0.9, 0.2), offset(s[2] * 0.52, 0, 0), cyan, N)
			k.p(s[1] .. "UpperLeg", "KneeGuard_" .. s[1], Vector3.new(1.06, 0.3, 1.06), offset(0, -0.45, 0), teal, Enum.Material.Metal)
		end
		k.p("UpperTorso", "CoreRing", Vector3.new(0.62, 0.62, 0.06), offset(0, 0.25, -0.53), dark, Enum.Material.Metal, "Disc")
		k.p("UpperTorso", "CoreGlow", Vector3.new(0.4, 0.4, 0.06), offset(0, 0.25, -0.58), cyan, N, "Disc")
		k.p("LowerTorso", "TechBelt", Vector3.new(2.08, 0.16, 1.08), offset(0, 0.08, 0), dark, Enum.Material.Metal)
		-- Thruster pack.
		k.p("UpperTorso", "ThrusterPack", Vector3.new(1.3, 1.1, 0.4), offset(0, 0.15, 0.72), dark, Enum.Material.Metal)
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "Thruster_" .. s[1], Vector3.new(0.4, 0.5, 0.4), offset(s[2] * 0.4, -0.55, 0.78), teal, Enum.Material.Metal, "Can")
			k.p("UpperTorso", "ThrusterGlow_" .. s[1], Vector3.new(0.34, 0.12, 0.34), offset(s[2] * 0.4, -0.84, 0.78), cyan, N, "Can")
		end
		shoes(k, {upper = C(236, 244, 252), sole = cyan, soleMat = N, toe = teal, accent = teal})
	end,
}

skins.skin_golden = {
	paint = {top = C(30, 30, 36), waist = C(30, 30, 36), upperArm = C(30, 30, 36), lowerArm = C(30, 30, 36),
		upperLeg = C(30, 30, 36), lowerLeg = C(30, 30, 36), foot = C(255, 200, 60)},
	iris = C(150, 96, 30), hair = C(30, 26, 26),
	build = function(k)
		local gold, jewel, black = C(255, 200, 60), C(232, 40, 70), C(30, 30, 36)
		local M = Enum.Material.Metal
		-- Laurel crown with a ruby; slicked hair.
		k.p("Head", "SlickHair", Vector3.new(1.3, 0.5, 1.3), offset(0, 0.44, 0.06), k.hair, nil, "Ball", {hair = true})
		k.p("Head", "CrownBand", Vector3.new(1.32, 0.16, 1.32), offset(0, 0.56, 0.02), gold, M)
		for i, x in ipairs({-0.5, -0.25, 0, 0.25, 0.5}) do
			local tall = i == 3 and 0.46 or 0.3
			k.p("Head", "CrownSpike" .. i, Vector3.new(0.24, tall, 0.14), offset(x, 0.64 + tall / 2, -0.58 + math.abs(x) * 0.25), gold, M, "Wedge")
		end
		k.p("Head", "CrownRuby", Vector3.new(0.14, 0.14, 0.08), offset(0, 0.6, -0.68, 0, 0, 45), jewel, Enum.Material.Neon)
		-- Tracksuit with gold collar, epaulettes and side stripes.
		k.p("UpperTorso", "JacketCollar", Vector3.new(1.3, 0.22, 1.0), offset(0, 0.78, 0.02), gold, M)
		k.p("UpperTorso", "ZipLine", Vector3.new(0.08, 1.4, 0.05), offset(0, 0, -0.53), gold, M)
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "Epaulette_" .. s[1], Vector3.new(0.9, 0.16, 1.1), offset(s[2] * 1.0, 0.82, 0, 0, 0, s[2] * 12), gold, M)
			k.p("UpperTorso", "EpauletteFringe_" .. s[1], Vector3.new(0.84, 0.18, 0.06), offset(s[2] * 1.06, 0.7, -0.56, 0, 0, s[2] * 12), gold, M)
			k.p(s[1] .. "UpperArm", "SleeveStripe_" .. s[1], Vector3.new(0.06, 1.1, 0.2), offset(s[2] * 0.52, 0, 0), gold, M)
			k.p(s[1] .. "LowerArm", "ForearmStripe_" .. s[1], Vector3.new(0.06, 0.9, 0.2), offset(s[2] * 0.52, 0, 0), gold, M)
			k.p(s[1] .. "UpperLeg", "TrackStripe_" .. s[1], Vector3.new(0.06, 1.1, 0.2), offset(s[2] * 0.52, 0, 0), gold, M)
			k.p(s[1] .. "LowerLeg", "AnkleBand_" .. s[1], Vector3.new(1.08, 0.2, 1.08), offset(0, -0.45, 0), gold, M)
		end
		-- Champion medal and a wide belt plaque.
		k.p("UpperTorso", "MedalRibbon", Vector3.new(0.5, 0.6, 0.05), offset(0, 0.45, -0.53), jewel)
		k.p("UpperTorso", "MedalDisc", Vector3.new(0.5, 0.5, 0.07), offset(0, -0.02, -0.56), gold, M, "Disc")
		k.p("UpperTorso", "MedalCore", Vector3.new(0.26, 0.26, 0.05), offset(0, -0.02, -0.61), jewel, Enum.Material.Neon, "Disc")
		k.p("LowerTorso", "ChampionBelt", Vector3.new(2.1, 0.3, 1.1), offset(0, 0.06, 0), gold, M)
		k.p("LowerTorso", "BeltPlaque", Vector3.new(0.9, 0.46, 0.08), offset(0, 0.04, -0.58), black, M)
		k.p("LowerTorso", "BeltJewel", Vector3.new(0.3, 0.3, 0.06), offset(0, 0.04, -0.64), jewel, Enum.Material.Neon, "Disc")
		-- Cape: black outside, gold inside edge.
		k.p("UpperTorso", "Cape", Vector3.new(1.9, 2.5, 0.1), offset(0, -0.7, 0.62, 8, 0, 0), black)
		k.p("UpperTorso", "CapeTrim", Vector3.new(1.9, 0.12, 0.12), offset(0, -1.92, 0.76, 8, 0, 0), gold, M)
		wristbands(k, gold, M)
		shoes(k, {upper = gold, sole = black, toe = C(255, 226, 120), accent = black, high = false})
	end,
}

skins.skin_midnight = {
	paint = {top = C(40, 34, 84), waist = C(28, 24, 58), upperArm = C(40, 34, 84), lowerArm = C(40, 34, 84),
		upperLeg = C(28, 24, 58), lowerLeg = C(28, 24, 58), foot = C(22, 20, 36), hand = C(24, 22, 40)},
	iris = C(190, 110, 255), hair = C(70, 50, 120),
	build = function(k)
		local silver, moon, coat, deep = C(214, 220, 240), C(255, 236, 160), C(40, 34, 84), C(26, 22, 56)
		local M = Enum.Material.Metal
		-- Fedora with a moon charm; long swept hair behind.
		k.p("Head", "HatBrim", Vector3.new(2.0, 0.07, 2.0), offset(0, 0.56, 0.02), deep, nil, "Can")
		k.p("Head", "HatCrown", Vector3.new(1.3, 0.62, 1.3), offset(0, 0.88, 0.02), deep, nil, "Can")
		k.p("Head", "HatBand", Vector3.new(1.34, 0.18, 1.34), offset(0, 0.66, 0.02), C(150, 90, 230), nil, "Can")
		k.p("Head", "HatMoon", Vector3.new(0.3, 0.3, 0.05), offset(0.34, 0.66, -0.68), moon, Enum.Material.Neon, "Disc")
		k.p("Head", "HatMoonCut", Vector3.new(0.26, 0.26, 0.06), offset(0.42, 0.7, -0.7), deep, nil, "Disc")
		k.p("Head", "LongHairBack", Vector3.new(1.2, 1.3, 0.4), offset(0, -0.2, 0.62), k.hair, nil, "Ball", {hair = true})
		for _, s in ipairs(SIDES) do
			k.p("Head", "HairLock_" .. s[1], Vector3.new(0.2, 0.9, 0.3), offset(s[2] * 0.62, -0.1, -0.18, 0, 0, s[2] * -6), k.hair, nil, "Ball", {hair = true})
		end
		-- High collar, silver buttons, moon brooch, scarf.
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "HighCollar_" .. s[1], Vector3.new(0.4, 0.5, 0.9), offset(s[2] * 0.42, 0.88, 0.04, 0, 0, s[2] * -14), coat)
			k.p("UpperTorso", "CoatLapel_" .. s[1], Vector3.new(0.5, 1.3, 0.07), offset(s[2] * 0.4, 0.0, -0.53, 0, 0, s[2] * -12), deep)
			k.p(s[1] .. "UpperLeg", "CoatSkirtFront_" .. s[1], Vector3.new(1.08, 1.1, 0.2), offset(0, -0.05, -0.56), coat)
			k.p(s[1] .. "UpperLeg", "CoatSkirtBack_" .. s[1], Vector3.new(1.08, 1.4, 0.2), offset(0, -0.1, 0.56), coat)
			k.p(s[1] .. "LowerArm", "GloveCuff_" .. s[1], Vector3.new(1.08, 0.24, 1.08), offset(0, -0.38, 0), silver, M)
			k.p(s[1] .. "LowerLeg", "BootTop_" .. s[1], Vector3.new(1.08, 0.5, 1.08), offset(0, -0.35, 0), C(22, 20, 36))
			k.p(s[1] .. "LowerLeg", "BootBuckle_" .. s[1], Vector3.new(0.06, 0.18, 0.18), offset(s[2] * 0.54, -0.25, 0), silver, M)
		end
		for i = 1, 3 do k.p("UpperTorso", "CoatButton" .. i, Vector3.new(0.12, 0.12, 0.06), offset(0, 0.45 - i * 0.4, -0.56), silver, M, "Disc") end
		k.p("UpperTorso", "MoonBrooch", Vector3.new(0.4, 0.4, 0.06), offset(-0.62, 0.4, -0.57), moon, Enum.Material.Neon, "Disc")
		k.p("UpperTorso", "MoonBroochCut", Vector3.new(0.34, 0.34, 0.07), offset(-0.52, 0.45, -0.6), coat, nil, "Disc")
		k.p("UpperTorso", "ScarfLoop", Vector3.new(1.4, 0.3, 1.1), offset(0, 0.72, -0.02), C(176, 108, 240))
		k.p("UpperTorso", "ScarfTail", Vector3.new(0.34, 1.7, 0.08), offset(0.45, 0.05, -0.58, 0, 0, -6), C(176, 108, 240))
		k.p("UpperTorso", "CoatBackPanel", Vector3.new(1.9, 1.5, 0.1), offset(0, -0.1, 0.56), deep)
		k.p("LowerTorso", "CoatBelt", Vector3.new(2.06, 0.16, 1.06), offset(0, 0.08, 0), silver, M)
		shoes(k, {upper = C(22, 20, 36), sole = C(150, 90, 230), toe = silver, accent = silver})
	end,
}

Appearance.SkinOrder = {"skin_courier", "skin_rooftop", "skin_streetwear", "skin_neonphantom", "skin_ninja", "skin_cyber", "skin_golden", "skin_midnight"}
function Appearance.HasSkin(id) return skins[id] ~= nil end

-- ---------------------------------------------------------------------------------------
-- Faces. Expression sets are separate geometry toggled by transparency (cheap, replicates).
-- ---------------------------------------------------------------------------------------
Appearance.Moods = {Idle = "smile", Run = "determined", Hunt = "grin", Scared = "scared", Hide = "scared", Win = "joy", Lose = "sad"}
local EXPRESSIONS = {"smile", "determined", "grin", "scared", "joy", "sad"}

local function face(k, iris, covers)
	local ink, white, blush = C(34, 30, 42), C(255, 255, 255), C(255, 130, 150)
	if covers ~= "full" and covers ~= "eyes" then
		for _, s in ipairs(SIDES) do
			local sx = s[2]
			k.p("Head", "EyeWhite_" .. s[1], Vector3.new(0.32, 0.32, 0.05), offset(sx * 0.23, 0.1, -0.6), white, nil, "Disc")
			k.p("Head", "EyeIris_" .. s[1], Vector3.new(0.22, 0.22, 0.05), offset(sx * 0.23, 0.09, -0.63), iris, nil, "Disc")
			k.p("Head", "EyePupil_" .. s[1], Vector3.new(0.12, 0.12, 0.05), offset(sx * 0.23, 0.09, -0.66), ink, nil, "Disc")
			k.p("Head", "EyeShine_" .. s[1], Vector3.new(0.07, 0.07, 0.05), offset(sx * 0.23 + 0.04, 0.15, -0.69), white, nil, "Disc")
		end
	end
	if covers ~= "full" then
		for _, s in ipairs(SIDES) do
			k.p("Head", "Blush_" .. s[1], Vector3.new(0.17, 0.17, 0.04), offset(s[2] * 0.4, -0.16, -0.6), blush, nil, "Disc", {transparency = 0.45})
		end
	end
	local browsOn = covers ~= "full" and covers ~= "eyes"
	local mouthOn = covers ~= "full" and covers ~= "lower"
	local function brows(expr, y, tilt, lift)
		if not browsOn then return end
		for _, s in ipairs(SIDES) do
			k.p("Head", "Brow_" .. expr .. "_" .. s[1], Vector3.new(0.26, 0.06, 0.05), offset(s[2] * 0.23, y + (lift or 0), -0.61, 0, 0, s[2] * tilt), ink, nil, nil, {expr = expr, transparency = expr == "smile" and 0 or 1})
		end
	end
	local function mouth(expr, name, size, x, y, rz, material, color, shape)
		if not mouthOn then return end
		k.p("Head", name .. "_" .. expr, size, offset(x, y, -0.61, 0, 0, rz or 0), color or ink, material, shape, {expr = expr, transparency = expr == "smile" and 0 or 1})
	end
	brows("smile", 0.36, 8, 0)
	brows("determined", 0.34, -22, 0)
	brows("grin", 0.34, -26, 0)
	brows("scared", 0.42, 18, 0.04)
	brows("joy", 0.44, 6, 0.04)
	brows("sad", 0.36, 20, 0)
	-- Smile: wide friendly curve.
	mouth("smile", "Mouth", Vector3.new(0.26, 0.06, 0.05), 0, -0.3, 0)
	mouth("smile", "MouthL", Vector3.new(0.12, 0.06, 0.05), -0.17, -0.26, -35)
	mouth("smile", "MouthR", Vector3.new(0.12, 0.06, 0.05), 0.17, -0.26, 35)
	-- Determined: small flat smirk.
	mouth("determined", "Mouth", Vector3.new(0.3, 0.06, 0.05), 0.02, -0.3, 6)
	-- Grin: hunter's toothy grin.
	mouth("grin", "Mouth", Vector3.new(0.5, 0.17, 0.05), 0, -0.29, 0, nil, ink)
	mouth("grin", "Teeth", Vector3.new(0.42, 0.07, 0.05), 0, -0.25, 0, nil, white)
	-- Scared: round open mouth + sweat drop.
	mouth("scared", "Mouth", Vector3.new(0.2, 0.2, 0.05), 0, -0.32, 0, nil, ink, "Disc")
	if mouthOn or browsOn then
		k.p("Head", "Sweat_scared", Vector3.new(0.12, 0.2, 0.1), offset(0.5, 0.3, -0.5), C(130, 210, 255), nil, "Ball", {expr = "scared", transparency = 1})
	end
	-- Joy: open smile with a tongue.
	mouth("joy", "Mouth", Vector3.new(0.44, 0.24, 0.05), 0, -0.3, 0, nil, ink)
	mouth("joy", "Tongue", Vector3.new(0.22, 0.09, 0.05), 0, -0.37, 0, nil, C(255, 110, 130))
	mouth("joy", "Teeth", Vector3.new(0.38, 0.06, 0.05), 0, -0.21, 0, nil, white)
	-- Sad: downturned mouth.
	mouth("sad", "Mouth", Vector3.new(0.24, 0.06, 0.05), 0, -0.34, 0)
	mouth("sad", "MouthL", Vector3.new(0.1, 0.06, 0.05), -0.15, -0.3, 35)
	mouth("sad", "MouthR", Vector3.new(0.1, 0.06, 0.05), 0.15, -0.3, -35)
end

function Appearance.SetMood(rig, mood)
	if not rig then return false end
	local folder = rig:FindFirstChild("CatchAppearance")
	if not folder then return false end
	local expression = Appearance.Moods[mood] or "smile"
	if folder:GetAttribute("CatchMood") == mood then return true end
	folder:SetAttribute("CatchMood", mood)
	for _, part in ipairs(folder:GetChildren()) do
		local expr = part:IsA("BasePart") and part:GetAttribute("CatchExpr")
		if expr then
			local target = expr == expression and 0 or 1
			if part.Transparency ~= target then part.Transparency = target end
		end
	end
	return true
end

-- ---------------------------------------------------------------------------------------
-- Masks (each declares what part of the face it covers: "lower", "eyes" or "full").
-- ---------------------------------------------------------------------------------------
local masks = {
	mask_street = {covers = "lower"}, mask_visor = {covers = "eyes"}, mask_phantom = {covers = "full"},
	mask_kitsune = {covers = "full"}, mask_skull = {covers = "full"}, mask_ninja = {covers = "lower"},
	mask_jester = {covers = "full"}, mask_pixel = {covers = "full"},
}
function Appearance.HasMask(id) return masks[id] ~= nil end
Appearance.MaskOrder = {"mask_street", "mask_visor", "mask_ninja", "mask_jester", "mask_phantom", "mask_kitsune", "mask_skull", "mask_pixel"}

local function buildMask(k, maskId)
	local white, ink, gold = C(246, 242, 236), C(28, 29, 42), C(255, 200, 60)
	local m = function(name, size, cf, color, material, shape, opts) return k.p("Head", name, size, cf, color, material, shape, opts) end
	if maskId == "mask_street" then
		local teal, light = C(40, 196, 190), C(255, 255, 255)
		m("BandanaCloth", Vector3.new(1.3, 0.5, 0.2), offset(0, -0.26, -0.58), teal)
		m("BandanaPoint", Vector3.new(0.5, 0.3, 0.2), offset(0, -0.58, -0.56, 0, 0, 180), teal, nil, "Wedge")
		m("BandanaTopEdge", Vector3.new(1.3, 0.07, 0.22), offset(0, -0.02, -0.59), light)
		for _, x in ipairs({-0.4, 0, 0.4}) do m("BandanaDot", Vector3.new(0.1, 0.1, 0.05), offset(x, -0.3, -0.7), light, nil, "Disc") end
		m("BandanaKnot", Vector3.new(0.34, 0.3, 0.3), offset(0.3, -0.2, 0.66), teal, nil, "Ball")
		m("BandanaStrap", Vector3.new(1.26, 0.18, 1.26), offset(0, -0.2, 0.0), teal)
	elseif maskId == "mask_visor" then
		m("VisorFrame", Vector3.new(1.36, 0.46, 0.26), offset(0, 0.1, -0.62), ink, Enum.Material.Metal)
		m("VisorLensA", Vector3.new(0.62, 0.3, 0.06), offset(-0.32, 0.1, -0.78), C(255, 90, 210), Enum.Material.Neon)
		m("VisorLensB", Vector3.new(0.62, 0.3, 0.06), offset(0.32, 0.1, -0.78), C(70, 230, 255), Enum.Material.Neon)
		m("VisorShine", Vector3.new(0.14, 0.05, 0.06), offset(-0.46, 0.2, -0.82, 0, 0, 20), white)
		for _, s in ipairs(SIDES) do m("VisorTemple_" .. s[1], Vector3.new(0.18, 0.2, 0.9), offset(s[2] * 0.7, 0.1, -0.2), ink) end
	elseif maskId == "mask_ninja" then
		local cloth, wrap = C(34, 38, 60), C(226, 48, 58)
		m("WrapLower", Vector3.new(1.3, 0.55, 0.2), offset(0, -0.25, -0.58), cloth)
		m("WrapNose", Vector3.new(0.44, 0.2, 0.22), offset(0, 0.02, -0.6), cloth, nil, "Wedge")
		m("WrapStrap", Vector3.new(1.28, 0.2, 1.26), offset(0, -0.12, 0.0), cloth)
		m("WrapStripe", Vector3.new(1.32, 0.06, 0.22), offset(0, -0.46, -0.58), wrap)
		m("WrapTail", Vector3.new(0.2, 0.8, 0.06), offset(0.4, -0.4, 0.68, 12, 0, -8), wrap)
	elseif maskId == "mask_jester" then
		local purple, mint = C(150, 90, 230), C(255, 200, 60)
		m("JesterFace", Vector3.new(1.0, 0.8, 0.18), offset(0, -0.02, -0.62), white)
		m("JesterHalf", Vector3.new(0.5, 0.8, 0.19), offset(0.25, -0.02, -0.63), purple)
		for _, s in ipairs(SIDES) do
			m("JesterEye_" .. s[1], Vector3.new(0.3, 0.22, 0.06), offset(s[2] * 0.26, 0.14, -0.74, 0, 0, s[2] * 18), ink)
			m("JesterBrowPoint_" .. s[1], Vector3.new(0.34, 0.3, 0.2), offset(s[2] * 0.46, 0.5, -0.58, 0, 0, s[2] * -28), s[1] == "Left" and white or purple, nil, "Wedge")
			m("JesterBell_" .. s[1], Vector3.new(0.2, 0.2, 0.2), offset(s[2] * 0.72, 0.76, -0.58), mint, Enum.Material.Metal, "Ball")
		end
		m("JesterGrin", Vector3.new(0.7, 0.2, 0.06), offset(0, -0.26, -0.74), ink)
		for x = -0.24, 0.24, 0.12 do m("JesterTooth", Vector3.new(0.06, 0.14, 0.06), offset(x, -0.24, -0.78), white) end
		m("JesterNose", Vector3.new(0.18, 0.18, 0.18), offset(0, -0.06, -0.78), C(236, 70, 80), nil, "Ball")
	elseif maskId == "mask_phantom" then
		m("PhantomCeramic", Vector3.new(1.0, 0.86, 0.18), offset(0, -0.02, -0.62), white)
		for _, s in ipairs(SIDES) do
			m("PhantomCheek_" .. s[1], Vector3.new(0.34, 0.4, 0.14), offset(s[2] * 0.36, -0.3, -0.68, 0, 0, s[2] * 20), white, nil, "Wedge")
			m("PhantomEye_" .. s[1], Vector3.new(0.3, 0.12, 0.06), offset(s[2] * 0.26, 0.12, -0.74, 0, 0, s[2] * 10), ink)
			m("PhantomGoldBrow_" .. s[1], Vector3.new(0.34, 0.05, 0.06), offset(s[2] * 0.26, 0.25, -0.75, 0, 0, s[2] * 10), gold, Enum.Material.Metal)
			m("PhantomFiligree_" .. s[1], Vector3.new(0.07, 0.34, 0.06), offset(s[2] * 0.47, -0.03, -0.75, 0, 0, s[2] * 18), gold, Enum.Material.Metal)
		end
		m("PhantomNose", Vector3.new(0.14, 0.26, 0.18), offset(0, -0.06, -0.78, 0, 0, 180), white, nil, "Wedge")
		m("PhantomMouth", Vector3.new(0.24, 0.05, 0.04), offset(0, -0.3, -0.75), ink)
	elseif maskId == "mask_kitsune" then
		local vermilion = C(226, 70, 70)
		m("FoxFace", Vector3.new(1.0, 0.78, 0.2), offset(0, -0.02, -0.63), white)
		for _, s in ipairs(SIDES) do
			m("FoxEar_" .. s[1], Vector3.new(0.34, 0.7, 0.18), offset(s[2] * 0.44, 0.58, -0.5, 0, 0, s[2] * -18), white, nil, "Wedge")
			m("FoxEarInner_" .. s[1], Vector3.new(0.16, 0.4, 0.05), offset(s[2] * 0.45, 0.56, -0.62, 0, 0, s[2] * -18), vermilion, nil, "Wedge")
			m("FoxEye_" .. s[1], Vector3.new(0.3, 0.08, 0.06), offset(s[2] * 0.26, 0.1, -0.75, 0, 0, s[2] * 20), vermilion)
			m("FoxCheekMark_" .. s[1], Vector3.new(0.26, 0.07, 0.06), offset(s[2] * 0.34, -0.14, -0.75, 0, 0, s[2] * -25), vermilion)
			m("FoxCheekFacet_" .. s[1], Vector3.new(0.26, 0.32, 0.12), offset(s[2] * 0.48, -0.16, -0.68, 0, 0, s[2] * 28), white, nil, "Wedge")
		end
		m("FoxMuzzle", Vector3.new(0.38, 0.24, 0.24), offset(0, -0.26, -0.78), white)
		m("FoxNose", Vector3.new(0.14, 0.09, 0.06), offset(0, -0.19, -0.92), ink)
		m("FoxForeheadSeal", Vector3.new(0.17, 0.22, 0.05), offset(0, 0.26, -0.75, 0, 0, 45), vermilion)
	elseif maskId == "mask_skull" then
		m("SkullForehead", Vector3.new(1.04, 0.5, 0.22), offset(0, 0.2, -0.62), gold, Enum.Material.Metal)
		for _, s in ipairs(SIDES) do
			m("SkullCheek_" .. s[1], Vector3.new(0.3, 0.36, 0.16), offset(s[2] * 0.4, -0.14, -0.66, 0, 0, s[2] * 18), gold, Enum.Material.Metal)
			m("SkullSocket_" .. s[1], Vector3.new(0.32, 0.26, 0.07), offset(s[2] * 0.27, 0.1, -0.78, 0, 0, s[2] * 9), ink)
			m("SkullSocketGlow_" .. s[1], Vector3.new(0.1, 0.1, 0.05), offset(s[2] * 0.27, 0.1, -0.82), C(255, 80, 80), Enum.Material.Neon, "Disc")
		end
		m("SkullJaw", Vector3.new(0.66, 0.26, 0.2), offset(0, -0.34, -0.64), gold, Enum.Material.Metal)
		m("SkullNasal", Vector3.new(0.13, 0.17, 0.06), offset(0, -0.1, -0.8, 0, 0, 180), ink, nil, "Wedge")
		for x = -0.24, 0.24, 0.12 do m("ToothGap", Vector3.new(0.03, 0.15, 0.04), offset(x, -0.34, -0.76), ink) end
	elseif maskId == "mask_pixel" then
		local screen, glow = C(24, 30, 52), C(80, 255, 170)
		m("PixelScreen", Vector3.new(1.06, 0.86, 0.2), offset(0, -0.02, -0.62), screen, Enum.Material.Metal)
		m("PixelFrame", Vector3.new(1.14, 0.94, 0.12), offset(0, -0.02, -0.58), C(70, 80, 110), Enum.Material.Metal)
		for _, s in ipairs(SIDES) do
			m("PixelEye_" .. s[1], Vector3.new(0.24, 0.24, 0.05), offset(s[2] * 0.25, 0.14, -0.74), glow, Enum.Material.Neon)
			m("PixelCheek_" .. s[1], Vector3.new(0.1, 0.1, 0.05), offset(s[2] * 0.36, -0.2, -0.74), C(255, 120, 190), Enum.Material.Neon)
			m("PixelEar_" .. s[1], Vector3.new(0.16, 0.5, 0.4), offset(s[2] * 0.68, 0.0, 0.02), C(70, 80, 110), Enum.Material.Metal)
		end
		for i, x in ipairs({-0.3, -0.15, 0, 0.15, 0.3}) do
			m("PixelMouth" .. i, Vector3.new(0.1, 0.1, 0.05), offset(x, i % 2 == 0 and -0.34 or -0.28, -0.74), glow, Enum.Material.Neon)
		end
		m("PixelAntenna", Vector3.new(0.05, 0.4, 0.05), offset(0, 0.76, -0.2), C(70, 80, 110), Enum.Material.Metal)
		m("PixelAntennaTip", Vector3.new(0.14, 0.14, 0.14), offset(0, 0.98, -0.2), glow, Enum.Material.Neon, "Ball")
	end
end

local function addTrail(folder, rig, id)
	if id ~= "trail_cyan" and id ~= "trail_sunset" and id ~= "trail_rainbow" then return end
	local root = rig:FindFirstChild("HumanoidRootPart")
	local mount = attach(folder, root, "TrailMount", Vector3.new(0.05, 0.05, 0.05), offset(0, -0.55, 0.6), Color3.new())
	if not mount then return end
	mount.Transparency = 1
	local a, b = Instance.new("Attachment"), Instance.new("Attachment")
	a.Position, b.Position = Vector3.new(-0.5, 0, 0), Vector3.new(0.5, 0, 0)
	a.Parent, b.Parent = mount, mount
	local trail = Instance.new("Trail")
	trail.Name = id
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	trail.Enabled = rig:GetAttribute("CatchPreview") == true or (humanoid ~= nil and humanoid.Health > 0
		and not root.Anchored and rig:GetAttribute("RoundFrozen") ~= true
		and rig:GetAttribute("Sprinting") == true
		and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 3)
	trail.Attachment0, trail.Attachment1 = a, b
	if id == "trail_cyan" then trail.Color = ColorSequence.new(C(59, 236, 228), C(85, 123, 239))
	elseif id == "trail_sunset" then trail.Color = ColorSequence.new(C(255, 196, 91), C(246, 86, 135))
	else
		trail.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, C(255, 90, 120)), ColorSequenceKeypoint.new(0.35, C(255, 220, 90)),
			ColorSequenceKeypoint.new(0.7, C(90, 240, 160)), ColorSequenceKeypoint.new(1, C(100, 150, 255))})
	end
	trail.Lifetime = 0.33
	trail.MinLength = 0.08
	trail.FaceCamera = true
	trail.LightEmission = 0.65
	trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)})
	trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 0)})
	trail.Parent = folder
end

local function paintBody(rig, definition, tone)
	local paint = definition.paint
	local function resolve(value) return value == "skin" and tone or value end
	local assignments = {
		Head = tone, UpperTorso = paint.top, LowerTorso = paint.waist,
		LeftUpperArm = resolve(paint.upperArm), RightUpperArm = resolve(paint.upperArm),
		LeftLowerArm = resolve(paint.lowerArm), RightLowerArm = resolve(paint.lowerArm),
		LeftHand = paint.hand or tone, RightHand = paint.hand or tone,
		LeftUpperLeg = resolve(paint.upperLeg), RightUpperLeg = resolve(paint.upperLeg),
		LeftLowerLeg = resolve(paint.lowerLeg), RightLowerLeg = resolve(paint.lowerLeg),
		LeftFoot = paint.foot, RightFoot = paint.foot,
		-- R6 single limbs take the dominant (upper) color.
		Torso = paint.top, ["Left Arm"] = resolve(paint.upperArm), ["Right Arm"] = resolve(paint.upperArm),
		["Left Leg"] = resolve(paint.upperLeg), ["Right Leg"] = resolve(paint.upperLeg),
	}
	for name, color in pairs(assignments) do
		local body = rig:FindFirstChild(name)
		if body and body:IsA("BasePart") then
			if body:GetAttribute("CatchOriginalColor") == nil then body:SetAttribute("CatchOriginalColor", body.Color) end
			body.Color = color
			body.Material = Enum.Material.SmoothPlastic
		end
	end
	local colors = rig:FindFirstChildOfClass("BodyColors")
	if colors then
		colors.HeadColor3, colors.TorsoColor3 = tone, paint.top
		colors.LeftArmColor3, colors.RightArmColor3 = resolve(paint.upperArm), resolve(paint.upperArm)
		colors.LeftLegColor3, colors.RightLegColor3 = resolve(paint.upperLeg), resolve(paint.upperLeg)
	end
end

function Appearance.Apply(rig, skinId, maskId, equipped, identity)
	-- CharacterAdded can fire before all limb parts arrive. Do not replace a good
	-- outfit or claim success until every authored attachment has a valid target.
	if not Appearance.IsRigReady(rig) then return nil end
	local old = rig:FindFirstChild("CatchAppearance")
	local previousMood = old and old:GetAttribute("CatchMood")
	if old then old:Destroy() end
	skinId = skins[skinId] and skinId or "skin_courier"
	maskId = masks[maskId] and maskId or ""
	local definition = skins[skinId]
	local tone = toneFor(identity, equipped)
	local hairColor = equipped and equipped.hairColors and Appearance.HairColors[equipped.hairColors] or definition.hair
	paintBody(rig, definition, tone)
	for _, body in ipairs(rig:GetChildren()) do
		if body:IsA("Accessory") then
			for _, part in ipairs(body:GetDescendants()) do
				if part:IsA("BasePart") then
					if part:GetAttribute("CatchOriginalTransparency") == nil then part:SetAttribute("CatchOriginalTransparency", part.Transparency) end
					part.Transparency = 1
				end
			end
		elseif body.Name == "Head" then
			-- Hide the stock decal face; ours is geometry that can change expression.
			for _, decal in ipairs(body:GetChildren()) do
				if decal:IsA("Decal") then
					if decal:GetAttribute("CatchOriginalTransparency") == nil then decal:SetAttribute("CatchOriginalTransparency", decal.Transparency) end
					decal.Transparency = 1
				end
			end
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "CatchAppearance"
	folder.Parent = rig
	local kit = {isR6 = rig:FindFirstChild("UpperTorso") == nil, hair = hairColor}
	kit.p = function(targetName, name, size, cf, color, material, shape, opts)
		local target = bodyPart(rig, targetName)
		local part = attach(folder, target, name, size, cf, color, material, shape, opts)
		if part and part:GetAttribute("CatchHair") then part.Color = hairColor end
		return part
	end
	definition.build(kit)
	face(kit, definition.iris, masks[maskId] and masks[maskId].covers or "none")
	buildMask(kit, maskId)
	if equipped then addTrail(folder, rig, equipped.trails) end
	folder:SetAttribute("AppearanceVersion", Appearance.Version)
	folder:SetAttribute("SkinId", skinId)
	folder:SetAttribute("MaskId", maskId)
	rig:SetAttribute("CatchAppearanceVersion", Appearance.Version)
	rig:SetAttribute("CatchAppearanceSkinId", skinId)
	rig:SetAttribute("CatchAppearanceRig", kit.isR6 and "R6" or "R15")
	Appearance.SetMood(rig, previousMood or rig:GetAttribute("CatchMood") or "Idle")
	return folder
end

-- Temporary team identity is separate from persistent ownership/equipment. It
-- never replaces a chosen mask or skin and is removed on spectator/lobby roles.
function Appearance.ApplyRole(rig, role)
	if not Appearance.IsRigReady(rig) then return nil end
	local old = rig:FindFirstChild("CatchRoleAppearance")
	if old then old:Destroy() end
	rig:SetAttribute("CatchAppearanceRole", role or "Lobby")
	if role ~= "Hunter" then return nil end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "CatchRoleAppearance", rig
	local coral, dark = C(255, 84, 70), C(66, 24, 34)
	for _, side in ipairs({"Left", "Right"}) do
		local arm = bodyPart(rig, side .. "LowerArm")
		attach(folder, arm, "HunterSignalCuff", Vector3.new(1.14, 0.18, 1.14), offset(0, 0.28, 0), dark)
		attach(folder, arm, "HunterSignalLight", Vector3.new(0.6, 0.085, 0.06), offset(0, 0.28, -0.58), coral, Enum.Material.Neon)
	end
	local chest = bodyPart(rig, "UpperTorso")
	attach(folder, chest, "HunterBadge", Vector3.new(0.34, 0.34, 0.05), offset(0.55, 0.38, -0.54, 0, 0, 45), coral, Enum.Material.Neon)
	local highlight = Instance.new("Highlight")
	highlight.Name, highlight.Adornee = "HunterSilhouette", rig
	highlight.FillTransparency = 1
	highlight.OutlineColor, highlight.OutlineTransparency = coral, 0.25
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = folder
	return folder
end

function Appearance.BuildPreview(skinId, maskId, extra, identity)
	local rig = Instance.new("Model")
	rig.Name = "CatchPreview"
	rig:SetAttribute("CatchPreview", true)
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
	for name, position in pairs(positions) do
		local part = Instance.new("Part")
		part.Name = name
		part.Size = name == "Head" and Vector3.new(2, 1, 1) or nominal[name]
		part.CFrame = CFrame.new(position)
		part.Anchored = true
		part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
		part.Massless = true
		part.Color = C(190, 146, 112)
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if name == "HumanoidRootPart" then part.Transparency = 1 end
		if name == "Head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = Vector3.new(1.25, 1.25, 1.25)
			mesh.Parent = part
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
	Appearance.Apply(rig, skinId, maskId, extra, identity)
	return rig
end

-- Anchored showroom models cannot rely on live Motor6D physics. Animate the arm
-- geometry and its clothing together, preserving the same pose after PivotTo.
-- The returned animator is intentionally unavailable for live character rigs.
function Appearance.CreatePreviewPose(rig, victoryId)
	if not rig or not rig:IsA("Model") or rig:GetAttribute("CatchPreview") ~= true then return nil end
	if victoryId ~= "victory_wave" and victoryId ~= "victory_spin" and victoryId ~= "victory_flex" then return nil end
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local parts = {}
	local sides = {LeftUpperArm = -1, LeftLowerArm = -1, LeftHand = -1, RightUpperArm = 1, RightLowerArm = 1, RightHand = 1}
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") then
			if not part.Anchored then return nil end
			local weld = part:FindFirstChildOfClass("WeldConstraint")
			local targetName = weld and weld.Part0 and weld.Part0.Name or part.Name
			local side = sides[targetName]
			if side then table.insert(parts, {part = part, side = side, rest = root.CFrame:ToObjectSpace(part.CFrame)}) end
		end
	end
	Appearance.SetMood(rig, "Win")
	return function(elapsed)
		if not rig.Parent or not root.Parent then return end
		elapsed = type(elapsed) == "number" and elapsed == elapsed and math.abs(elapsed) < math.huge and elapsed or 0
		local wave = math.sin(elapsed * 5.5)
		for _, item in ipairs(parts) do
			if item.part.Parent then
				local angle
				if victoryId == "victory_spin" then angle = item.side * 72
				elseif victoryId == "victory_flex" then angle = item.side * (95 + math.sin(elapsed * 4) * 8)
				else angle = item.side == 1 and 138 + wave * 11 or -8 end
				local pivot = CFrame.new(item.side * 1.5, 1.65, 0)
				local rotation = pivot * CFrame.Angles(0, 0, math.rad(angle)) * pivot:Inverse()
				item.part.CFrame = root.CFrame * rotation * item.rest
			end
		end
	end
end

return Appearance
