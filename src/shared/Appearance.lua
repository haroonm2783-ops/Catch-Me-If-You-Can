-- Avatar-first cosmetics, shared by live characters and viewport previews.
--
-- Players keep their OWN Roblox avatar: body, face, clothes, hair and Roblox's standard animations are
-- never replaced. Skins are optional overlays made of chunky welded, massless, non-colliding pieces
-- (hats, back items, capes, wings, tails, belts) built from plain parts, so they need no uploaded assets.
-- Epic and Legendary skins add an ambient aura; a few full-body looks (like the gold statue) also tint the
-- player's limbs, which is reversible and restores the original colors on the next Apply.
-- Cosmetic only: nothing here touches collision, speed, hitboxes or tag raycasts.
local Appearance = {Version = 4}

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
-- Skins. Each definition may declare: hidesHair (hat-like looks hide the player's hair/hat
-- accessories), tint (full-body look), aura (ambient particles) and a `build` of overlay parts.
-- Shapes are deliberately bold and simple so they read at a distance on a phone.
-- ---------------------------------------------------------------------------------------
local skins = {}
local M = Enum.Material

local function wristbands(k, color, material)
	for _, s in ipairs(SIDES) do
		k.p(s[1] .. "LowerArm", "Wristband_" .. s[1], Vector3.new(1.1, 0.24, 1.1), offset(0, -0.34, 0), color, material)
	end
end

-- Default: nothing is changed. The player's own avatar is the starting look.
skins.skin_courier = {build = function() end}

skins.skin_rooftop = {
	hidesHair = true,
	build = function(k)
		local yellow, white, red, purple = C(255, 208, 40), C(255, 255, 255), C(236, 60, 70), C(140, 80, 230)
		k.p("Head", "Beanie", Vector3.new(1.4, 0.95, 1.4), offset(0, 0.56, 0.02), yellow, nil, "Ball")
		k.p("Head", "BeanieFold", Vector3.new(1.42, 0.26, 1.42), offset(0, 0.4, 0.02), white, nil, "Can")
		k.p("Head", "BeanieStripe", Vector3.new(1.36, 0.12, 1.36), offset(0, 0.78, 0.02), red, nil, "Can")
		k.p("Head", "Pompom", Vector3.new(0.42, 0.42, 0.42), offset(0, 1.12, 0.02), red, nil, "Ball")
		-- A deck on the back gives a clear silhouette from behind.
		k.p("UpperTorso", "SkateDeck", Vector3.new(1.0, 2.7, 0.14), offset(0, -0.1, 0.66, 0, 0, 12), purple)
		k.p("UpperTorso", "DeckGrip", Vector3.new(0.9, 2.5, 0.05), offset(0, -0.1, 0.74, 0, 0, 12), C(40, 40, 48))
		for _, y in ipairs({-1.0, 0.8}) do
			for _, x in ipairs({-0.32, 0.32}) do
				k.p("UpperTorso", "SkateWheel", Vector3.new(0.26, 0.26, 0.26), offset(x - y * 0.06, y, 0.84), white, nil, "Ball")
			end
		end
		wristbands(k, red)
	end,
}

skins.skin_pizza = {
	hidesHair = true,
	build = function(k)
		local red, white, cheese, pepperoni = C(230, 50, 50), C(255, 255, 255), C(255, 196, 60), C(200, 40, 40)
		k.p("Head", "CapCrown", Vector3.new(1.38, 0.8, 1.38), offset(0, 0.56, 0.02), red, nil, "Ball")
		k.p("Head", "CapBrim", Vector3.new(1.1, 0.09, 0.7), offset(0, 0.46, -0.82, 10), white)
		k.p("Head", "CapBadge", Vector3.new(0.44, 0.44, 0.06), offset(0, 0.7, -0.66, -20), cheese, nil, "Disc")
		k.p("Head", "CapPepperoni", Vector3.new(0.14, 0.14, 0.06), offset(0.06, 0.72, -0.7, -20), pepperoni, nil, "Disc")
		-- A big flat delivery box carried on the back, with a pizza circle on the lid.
		k.p("UpperTorso", "PizzaBox", Vector3.new(2.0, 2.0, 0.4), offset(0, 0.0, 0.72), white)
		k.p("UpperTorso", "BoxStripe", Vector3.new(2.04, 0.3, 0.42), offset(0, 0.62, 0.72), red)
		k.p("UpperTorso", "PizzaDisc", Vector3.new(1.3, 1.3, 0.06), offset(0, -0.2, 0.95), cheese, nil, "Disc")
		for i, p in ipairs({{-0.3, 0.0}, {0.3, -0.1}, {0, -0.55}, {-0.25, -0.4}}) do
			k.p("UpperTorso", "PizzaPepperoni" .. i, Vector3.new(0.26, 0.26, 0.06), offset(p[1], p[2] - 0.2, 0.99), pepperoni, nil, "Disc")
		end
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "BoxStrap_" .. s[1], Vector3.new(0.2, 1.7, 0.06), offset(s[2] * 0.62, 0, -0.52), red)
		end
		wristbands(k, red)
	end,
}

skins.skin_bunny = {
	build = function(k)
		local pink, white, deep = C(255, 150, 200), C(255, 255, 255), C(255, 100, 170)
		k.p("Head", "BunnyBand", Vector3.new(1.3, 0.12, 1.3), offset(0, 0.52, 0.02), pink, nil, "Can")
		for _, s in ipairs(SIDES) do
			k.p("Head", "BunnyEar_" .. s[1], Vector3.new(0.46, 1.7, 0.3), offset(s[2] * 0.3, 1.3, 0.05, 0, 0, s[2] * -9), white, nil, "Ball")
			k.p("Head", "BunnyEarInner_" .. s[1], Vector3.new(0.26, 1.35, 0.16), offset(s[2] * 0.3 + s[2] * 0.02, 1.28, -0.07, 0, 0, s[2] * -9), pink, nil, "Ball")
		end
		k.p("LowerTorso", "BunnyTail", Vector3.new(0.78, 0.78, 0.78), offset(0, 0.0, 0.62), white, nil, "Ball")
		-- Big ribbon collar.
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "BowWing_" .. s[1], Vector3.new(0.56, 0.4, 0.14), offset(s[2] * 0.34, 0.7, -0.5, 0, 0, s[2] * 14), deep)
		end
		k.p("UpperTorso", "BowKnot", Vector3.new(0.26, 0.26, 0.2), offset(0, 0.7, -0.52), deep, nil, "Ball")
		for _, s in ipairs(SIDES) do
			k.p(s[1] .. "LowerLeg", "FluffyCuff_" .. s[1], Vector3.new(1.18, 0.34, 1.18), offset(0, -0.4, 0), white, M.Fabric, "Can")
		end
	end,
}

skins.skin_panda = {
	hidesHair = true,
	build = function(k)
		local white, black, green, dark = C(250, 250, 250), C(34, 34, 40), C(110, 200, 90), C(70, 150, 60)
		-- Hood sits behind the face plane, so the player's own face stays visible.
		k.p("Head", "PandaHood", Vector3.new(1.62, 1.46, 1.54), offset(0, 0.14, 0.2), white, nil, "Ball")
		for _, s in ipairs(SIDES) do
			k.p("Head", "PandaEar_" .. s[1], Vector3.new(0.62, 0.62, 0.34), offset(s[2] * 0.56, 0.86, 0.12), black, nil, "Ball")
			k.p("Head", "PandaCheek_" .. s[1], Vector3.new(0.26, 0.9, 0.7), offset(s[2] * 0.7, -0.04, -0.02), white)
		end
		k.p("Head", "PandaBrow", Vector3.new(1.3, 0.32, 0.8), offset(0, 0.62, -0.3, -12), white)
		-- Bamboo stalks tied to the back.
		for i, x in ipairs({-0.55, 0, 0.55}) do
			local tall = 2.5 + (i % 2) * 0.5
			k.p("UpperTorso", "Bamboo" .. i, Vector3.new(0.3, tall, 0.3), offset(x, 0.35 + (tall - 2.5) / 2, 0.74, 0, 0, (i - 2) * 8), green, nil, "Can")
			for _, y in ipairs({-0.5, 0.4, 1.3}) do
				k.p("UpperTorso", "BambooRing" .. i, Vector3.new(0.36, 0.1, 0.36), offset(x + (i - 2) * y * 0.14, y + 0.2, 0.74, 0, 0, (i - 2) * 8), dark, nil, "Can")
			end
		end
		k.p("UpperTorso", "BambooTie", Vector3.new(1.8, 0.14, 0.5), offset(0, 0.1, 0.62), C(230, 190, 120))
		k.p("LowerTorso", "PandaBelt", Vector3.new(2.08, 0.2, 1.08), offset(0, 0.06, 0), black)
	end,
}

skins.skin_streetwear = {
	hidesHair = true,
	build = function(k)
		local gold, red, blue, cream = C(255, 200, 40), C(235, 50, 60), C(40, 90, 220), C(255, 244, 214)
		k.p("Head", "BucketCrown", Vector3.new(1.34, 0.7, 1.34), offset(0, 0.88, 0.02), cream, nil, "Can")
		k.p("Head", "BucketTop", Vector3.new(1.2, 0.1, 1.2), offset(0, 1.24, 0.02), cream, nil, "Can")
		k.p("Head", "BucketBrim", Vector3.new(2.0, 0.1, 2.0), offset(0, 0.56, 0.02), red, nil, "Can")
		k.p("Head", "BucketBand", Vector3.new(1.4, 0.18, 1.4), offset(0, 0.68, 0.02), gold, M.Metal, "Can")
		-- Chunky gold chain with a big pendant, and a crossbody bag.
		local chain = {{-0.55, 0.62}, {-0.4, 0.4}, {-0.2, 0.26}, {0.2, 0.26}, {0.4, 0.4}, {0.55, 0.62}}
		for i, c in ipairs(chain) do
			k.p("UpperTorso", "ChainLink" .. i, Vector3.new(0.17, 0.17, 0.17), offset(c[1], c[2], -0.56), gold, M.Metal, "Ball")
		end
		k.p("UpperTorso", "ChainPendant", Vector3.new(0.5, 0.5, 0.1), offset(0, -0.02, -0.58), gold, M.Metal, "Disc")
		k.p("UpperTorso", "ChainGem", Vector3.new(0.22, 0.22, 0.08), offset(0, -0.02, -0.64), red, nil, "Disc")
		k.p("UpperTorso", "BagStrap", Vector3.new(0.2, 2.2, 0.08), offset(0, 0, -0.53, 0, 0, -38), blue)
		k.p("LowerTorso", "BagBody", Vector3.new(0.9, 0.8, 0.44), offset(-0.85, -0.2, -0.3), blue)
		k.p("LowerTorso", "BagFlap", Vector3.new(0.92, 0.26, 0.46), offset(-0.85, 0.06, -0.3), red)
		wristbands(k, gold, M.Metal)
	end,
}

skins.skin_cyber = {
	build = function(k)
		local steel, orange, teal, dark = C(200, 210, 224), C(255, 140, 40), C(60, 200, 220), C(60, 70, 90)
		-- Pilot goggles on the forehead.
		k.p("Head", "GoggleStrap", Vector3.new(1.34, 0.2, 1.34), offset(0, 0.5, 0.02), dark, nil, "Can")
		for _, s in ipairs(SIDES) do
			k.p("Head", "GoggleRim_" .. s[1], Vector3.new(0.52, 0.52, 0.12), offset(s[2] * 0.3, 0.62, -0.62), orange, M.Metal, "Disc")
			k.p("Head", "GoggleLens_" .. s[1], Vector3.new(0.38, 0.38, 0.1), offset(s[2] * 0.3, 0.62, -0.68), teal, M.Glass, "Disc", {transparency = 0.25})
		end
		-- Jet pack with two nozzles, shoulder pads and orange gauntlets.
		k.p("UpperTorso", "JetBody", Vector3.new(1.5, 1.3, 0.55), offset(0, 0.1, 0.78), steel, M.Metal)
		k.p("UpperTorso", "JetStripe", Vector3.new(1.54, 0.2, 0.58), offset(0, 0.4, 0.78), orange)
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "JetTank_" .. s[1], Vector3.new(0.58, 1.5, 0.58), offset(s[2] * 0.5, -0.1, 0.98), orange, M.Metal, "Can")
			k.p("UpperTorso", "JetNozzle_" .. s[1], Vector3.new(0.44, 0.3, 0.44), offset(s[2] * 0.5, -0.95, 0.98), dark, M.Metal, "Can")
			k.p("UpperTorso", "ShoulderPad_" .. s[1], Vector3.new(0.95, 0.34, 1.2), offset(s[2] * 1.0, 0.84, 0, 0, 0, s[2] * 12), orange, M.Metal)
			k.p(s[1] .. "LowerArm", "Gauntlet_" .. s[1], Vector3.new(1.12, 0.56, 1.12), offset(0, -0.22, 0), steel, M.Metal)
		end
		k.p("UpperTorso", "ChestPlate", Vector3.new(0.7, 0.7, 0.1), offset(0, 0.25, -0.54), teal, M.Metal, "Disc")
	end,
	aura = {kind = "jet", color = {C(255, 200, 80), C(255, 100, 30)}, mount = "UpperTorso", at = offset(0, -1.1, 0.98)},
}

skins.skin_ninja = {
	build = function(k)
		local red, steel, wrap, black = C(230, 40, 50), C(190, 204, 220), C(220, 214, 196), C(34, 34, 42)
		k.p("Head", "Headband", Vector3.new(1.32, 0.24, 1.32), offset(0, 0.48, 0.02), red, nil, "Can")
		k.p("Head", "HeadbandPlate", Vector3.new(0.62, 0.34, 0.08), offset(0, 0.48, -0.66), steel, M.Metal)
		k.p("Head", "HeadbandMark", Vector3.new(0.2, 0.2, 0.06), offset(0, 0.48, -0.72, 0, 0, 45), red)
		for _, s in ipairs(SIDES) do
			k.p("Head", "HeadbandTail_" .. s[1], Vector3.new(0.22, 1.1, 0.08), offset(s[2] * 0.22, -0.3, 0.7, 14, 0, s[2] * -8), red)
		end
		k.p("LowerTorso", "Sash", Vector3.new(2.12, 0.4, 1.12), offset(0, 0.04, 0), red)
		k.p("LowerTorso", "SashKnot", Vector3.new(0.46, 0.46, 0.18), offset(-0.5, 0.02, -0.6), red, nil, "Ball")
		k.p("LowerTorso", "SashTailA", Vector3.new(0.26, 1.0, 0.08), offset(-0.55, -0.5, -0.62, 8, 0, 8), red)
		k.p("LowerTorso", "SashTailB", Vector3.new(0.26, 0.9, 0.08), offset(-0.38, -0.46, -0.62, 8, 0, -10), red)
		k.p("UpperTorso", "KatanaSheath", Vector3.new(0.22, 2.7, 0.2), offset(0, 0, 0.64, 0, 0, 38), black)
		k.p("UpperTorso", "KatanaHandle", Vector3.new(0.26, 0.62, 0.26), offset(-0.88, 0.95, 0.64, 0, 0, 38), red)
		k.p("UpperTorso", "KatanaGuard", Vector3.new(0.56, 0.1, 0.34), offset(-0.68, 0.66, 0.64, 0, 0, 38), C(255, 200, 60), M.Metal)
		k.p("UpperTorso", "ChestStrap", Vector3.new(0.16, 2.0, 0.08), offset(0, 0, -0.53, 0, 0, 38), black)
		for _, s in ipairs(SIDES) do
			k.p(s[1] .. "LowerArm", "ForearmWrap_" .. s[1], Vector3.new(1.12, 0.74, 1.12), offset(0, -0.1, 0), wrap)
			k.p(s[1] .. "LowerLeg", "ShinWrap_" .. s[1], Vector3.new(1.1, 0.74, 1.1), offset(0, -0.1, 0), wrap)
		end
		k.p("LowerTorso", "ShurikenA", Vector3.new(0.56, 0.1, 0.1), offset(0.85, 0, -0.58), steel, M.Metal)
		k.p("LowerTorso", "ShurikenB", Vector3.new(0.1, 0.56, 0.1), offset(0.85, 0, -0.59), steel, M.Metal)
	end,
}

skins.skin_neonphantom = {
	hidesHair = true,
	build = function(k)
		local hood, dark, ghost, glow = C(120, 70, 210), C(80, 44, 150), C(245, 240, 255), C(200, 140, 255)
		k.p("Head", "HoodShell", Vector3.new(1.64, 1.48, 1.56), offset(0, 0.14, 0.2), hood, nil, "Ball")
		for _, s in ipairs(SIDES) do
			k.p("Head", "HoodCheek_" .. s[1], Vector3.new(0.28, 1.0, 0.8), offset(s[2] * 0.7, -0.04, -0.0), hood)
			k.p("Head", "HoodPoint_" .. s[1], Vector3.new(0.5, 0.6, 0.4), offset(s[2] * 0.4, 0.92, 0.12, 0, 0, s[2] * -20), dark, nil, "Wedge")
		end
		k.p("Head", "HoodBrow", Vector3.new(1.34, 0.36, 0.86), offset(0, 0.62, -0.3, -12), hood)
		-- A flowing bedsheet-ghost cape with a scalloped hem.
		k.p("UpperTorso", "GhostCape", Vector3.new(1.9, 2.5, 0.12), offset(0, -0.55, 0.62, 8, 0, 0), ghost, nil, nil, {transparency = 0.18})
		for i, x in ipairs({-0.72, -0.24, 0.24, 0.72}) do
			k.p("UpperTorso", "GhostHem" .. i, Vector3.new(0.5, 0.5, 0.12), offset(x, -1.86, 0.86, 8), ghost, nil, "Ball", {transparency = 0.18})
		end
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "CapeClasp_" .. s[1], Vector3.new(0.3, 0.3, 0.14), offset(s[2] * 0.7, 0.72, 0.5), glow, nil, "Ball")
		end
	end,
	aura = {kind = "wisps", color = {C(200, 140, 255), C(120, 70, 210)}, mount = "UpperTorso", at = offset(0, -0.6, 0.7)},
}

skins.skin_midnight = {
	hidesHair = true,
	build = function(k)
		local deep, band, gold, white, cape = C(80, 40, 160), C(255, 205, 60), C(255, 205, 60), C(255, 255, 255), C(104, 60, 200)
		k.p("Head", "HatBrim", Vector3.new(1.9, 0.1, 1.9), offset(0, 0.56, 0.02), deep, nil, "Can")
		k.p("Head", "HatCrown", Vector3.new(1.3, 1.0, 1.3), offset(0, 1.06, 0.02), deep, nil, "Can")
		k.p("Head", "HatBand", Vector3.new(1.34, 0.24, 1.34), offset(0, 0.72, 0.02), band, nil, "Can")
		k.p("Head", "HatStar", Vector3.new(0.34, 0.34, 0.06), offset(0.3, 0.74, -0.68, 0, 0, 45), white, nil, "Disc")
		-- Long swishy cape, high collar, bow tie and white gloves.
		k.p("UpperTorso", "Cape", Vector3.new(2.1, 3.0, 0.12), offset(0, -0.9, 0.62, 7, 0, 0), cape)
		k.p("UpperTorso", "CapeLining", Vector3.new(1.9, 2.8, 0.06), offset(0, -0.9, 0.55, 7, 0, 0), C(255, 120, 200))
		k.p("UpperTorso", "CapeTrim", Vector3.new(2.14, 0.16, 0.16), offset(0, -2.38, 0.84, 7, 0, 0), gold, M.Metal)
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "CapeCollar_" .. s[1], Vector3.new(0.5, 0.9, 0.16), offset(s[2] * 0.62, 0.9, 0.56, 0, 0, s[2] * -10), cape)
			k.p(s[1] .. "LowerArm", "Glove_" .. s[1], Vector3.new(1.12, 0.5, 1.12), offset(0, -0.26, 0), white)
		end
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "BowTie_" .. s[1], Vector3.new(0.42, 0.34, 0.12), offset(s[2] * 0.24, 0.66, -0.52, 0, 0, s[2] * 12), C(235, 50, 80))
		end
		k.p("UpperTorso", "BowKnot", Vector3.new(0.2, 0.2, 0.16), offset(0, 0.66, -0.54), C(235, 50, 80), nil, "Ball")
	end,
	aura = {kind = "stars", color = {C(255, 230, 120), C(255, 160, 230)}, mount = "UpperTorso", at = offset(0, 0.3, 0.2)},
}

skins.skin_candy = {
	hidesHair = true,
	build = function(k)
		local pink, mint, cone, cherry, white = C(255, 140, 200), C(120, 235, 200), C(236, 180, 100), C(230, 40, 60), C(255, 255, 255)
		-- Ice-cream hat: a waffle band, two scoops and a cherry.
		k.p("Head", "WaffleBand", Vector3.new(1.4, 0.34, 1.4), offset(0, 0.56, 0.02), cone, nil, "Can")
		k.p("Head", "ScoopPink", Vector3.new(1.55, 1.1, 1.55), offset(0, 1.06, 0.02), pink, nil, "Ball")
		k.p("Head", "ScoopMint", Vector3.new(1.1, 0.8, 1.1), offset(0, 1.66, 0.02), mint, nil, "Ball")
		k.p("Head", "Cherry", Vector3.new(0.34, 0.34, 0.34), offset(0, 2.1, 0.02), cherry, nil, "Ball")
		for i, p in ipairs({{-0.5, 1.2, -0.5}, {0.4, 0.9, -0.62}, {0.55, 1.3, 0.2}, {-0.55, 1.0, 0.3}}) do
			k.p("Head", "Sprinkle" .. i, Vector3.new(0.18, 0.08, 0.08), offset(p[1], p[2], p[3], 0, i * 40, 0), white)
		end
		-- Giant lollipop on the back.
		k.p("UpperTorso", "LollipopStick", Vector3.new(0.14, 2.8, 0.14), offset(0.5, -0.1, 0.7, 0, 0, -14), white, nil, "Can")
		k.p("UpperTorso", "LollipopSwirl", Vector3.new(1.5, 1.5, 0.16), offset(0.95, 1.35, 0.7), pink, nil, "Disc")
		k.p("UpperTorso", "LollipopRing", Vector3.new(1.0, 1.0, 0.18), offset(0.95, 1.35, 0.74), white, nil, "Disc")
		k.p("UpperTorso", "LollipopCore", Vector3.new(0.5, 0.5, 0.2), offset(0.95, 1.35, 0.78), mint, nil, "Disc")
		-- Candy-stripe collar and wristbands.
		for i = 0, 4 do
			k.p("UpperTorso", "CandyCollar" .. i, Vector3.new(0.4, 0.28, 1.1), offset(-0.8 + i * 0.4, 0.8, 0), i % 2 == 0 and pink or white)
		end
		wristbands(k, pink)
	end,
	aura = {kind = "sprinkles", color = {C(255, 140, 200), C(120, 235, 200)}, mount = "UpperTorso", at = offset(0, 0.9, 0)},
}

skins.skin_golden = {
	hidesHair = true,
	tint = {color = C(255, 200, 50), material = M.Metal, stashClothes = true},
	build = function(k)
		local gold, ruby, purple, white = C(255, 210, 70), C(230, 40, 70), C(110, 50, 200), C(255, 255, 255)
		-- Crown with five bold points and gems.
		k.p("Head", "CrownBand", Vector3.new(1.36, 0.3, 1.36), offset(0, 0.62, 0.02), gold, M.Metal, "Can")
		for i, x in ipairs({-0.52, -0.26, 0, 0.26, 0.52}) do
			local tall = i == 3 and 0.74 or 0.52
			k.p("Head", "CrownSpike" .. i, Vector3.new(0.3, tall, 0.2), offset(x, 0.76 + tall / 2, -0.5 + math.abs(x) * 0.5), gold, M.Metal, "Wedge")
			k.p("Head", "CrownJewel" .. i, Vector3.new(0.14, 0.14, 0.06), offset(x, 0.62, -0.7 + math.abs(x) * 0.2), i % 2 == 0 and white or ruby, nil, "Disc")
		end
		-- Royal cape, champion belt, medal and shoulder guards.
		k.p("UpperTorso", "Cape", Vector3.new(2.1, 3.0, 0.12), offset(0, -0.9, 0.62, 7, 0, 0), purple)
		k.p("UpperTorso", "CapeTrim", Vector3.new(2.14, 0.2, 0.18), offset(0, -2.38, 0.84, 7, 0, 0), gold, M.Metal)
		for _, s in ipairs(SIDES) do
			k.p("UpperTorso", "Epaulette_" .. s[1], Vector3.new(1.0, 0.24, 1.2), offset(s[2] * 1.0, 0.84, 0, 0, 0, s[2] * 12), gold, M.Metal)
			k.p("UpperTorso", "CapeFur_" .. s[1], Vector3.new(0.7, 0.4, 0.5), offset(s[2] * 0.56, 0.78, 0.5), white, nil, "Ball")
		end
		k.p("LowerTorso", "ChampionBelt", Vector3.new(2.16, 0.38, 1.16), offset(0, 0.04, 0), gold, M.Metal)
		k.p("LowerTorso", "BeltPlaque", Vector3.new(0.96, 0.6, 0.1), offset(0, 0.04, -0.6), purple)
		k.p("LowerTorso", "BeltJewel", Vector3.new(0.4, 0.4, 0.08), offset(0, 0.04, -0.67), ruby, nil, "Disc")
		k.p("UpperTorso", "MedalDisc", Vector3.new(0.56, 0.56, 0.08), offset(0, 0.1, -0.56), gold, M.Metal, "Disc")
		k.p("UpperTorso", "MedalCore", Vector3.new(0.28, 0.28, 0.06), offset(0, 0.1, -0.62), ruby, nil, "Disc")
		wristbands(k, gold, M.Metal)
	end,
	aura = {kind = "gold", color = {C(255, 240, 150), C(255, 190, 40)}, mount = "UpperTorso", at = offset(0, 0, 0)},
}

skins.skin_dragon = {
	build = function(k)
		local red, bone, orange, dark = C(215, 50, 40), C(250, 236, 206), C(255, 140, 40), C(120, 24, 30)
		-- Swept-back horns and a spiny crest.
		for _, s in ipairs(SIDES) do
			k.p("Head", "HornBase_" .. s[1], Vector3.new(0.34, 0.5, 0.34), offset(s[2] * 0.4, 0.7, 0.1, -14, 0, s[2] * -12), bone, nil, "Can")
			k.p("Head", "HornTip_" .. s[1], Vector3.new(0.26, 0.7, 0.26), offset(s[2] * 0.52, 1.18, 0.34, -40, 0, s[2] * -20), orange, nil, "Can")
		end
		for i = 1, 3 do
			k.p("UpperTorso", "BackSpike" .. i, Vector3.new(0.34, 0.5, 0.34), offset(0, 0.9 - i * 0.5, 0.62, 25, 0, 0), bone, nil, "Wedge")
		end
		-- Wings: a bone spar and four fanned feather panels per side, so the V reads from behind.
		for _, s in ipairs(SIDES) do
			local x = s[2]
			local function fan(name, angle, length, width, color, material)
				local a = math.rad(angle)
				local base = Vector3.new(x * 0.55, 0.45, 0.72)
				local center = base + Vector3.new(x * math.sin(a), math.cos(a), 0) * (length / 2)
				return k.p("UpperTorso", name .. "_" .. s[1], Vector3.new(width, length, 0.1), offset(center.X, center.Y, center.Z, 0, 0, -x * angle), color, material)
			end
			fan("WingSpar", 38, 3.1, 0.22, bone)
			fan("WingFeatherA", 14, 2.3, 0.7, red)
			fan("WingFeatherB", 36, 2.9, 0.7, dark)
			fan("WingFeatherC", 58, 2.6, 0.7, red)
			fan("WingFeatherD", 80, 2.0, 0.7, dark)
			k.p("UpperTorso", "WingClaw_" .. s[1], Vector3.new(0.22, 0.5, 0.22), offset(x * 2.5, 2.75, 0.76, 0, 0, -x * 38), orange, nil, "Wedge")
		end
		-- Tapering tail with a flame tip.
		k.p("LowerTorso", "TailA", Vector3.new(0.6, 0.6, 1.0), offset(0, -0.1, 0.9, -12, 0, 0), red)
		k.p("LowerTorso", "TailB", Vector3.new(0.46, 0.46, 1.0), offset(0, -0.34, 1.78, -22, 0, 0), red)
		k.p("LowerTorso", "TailC", Vector3.new(0.3, 0.3, 0.9), offset(0, -0.72, 2.5, -30, 0, 0), dark)
		k.p("LowerTorso", "TailFlame", Vector3.new(0.5, 0.6, 0.5), offset(0, -1.0, 3.0, -30, 0, 0), orange, nil, "Wedge")
		for _, s in ipairs(SIDES) do
			k.p(s[1] .. "LowerArm", "ClawBand_" .. s[1], Vector3.new(1.12, 0.3, 1.12), offset(0, -0.3, 0), bone, nil, "Can")
		end
	end,
	aura = {kind = "embers", color = {C(255, 210, 90), C(255, 80, 30)}, mount = "UpperTorso", at = offset(0, 0.2, 0.5)},
}

Appearance.SkinOrder = {"skin_courier", "skin_rooftop", "skin_pizza", "skin_bunny", "skin_panda", "skin_streetwear", "skin_cyber", "skin_ninja",
	"skin_neonphantom", "skin_midnight", "skin_candy", "skin_golden", "skin_dragon"}
function Appearance.HasSkin(id) return skins[id] ~= nil end

-- Presentational mood is a replicated attribute only. Roblox's own animations and face are untouched.
Appearance.Moods = {Idle = "idle", Run = "run", Hunt = "hunt", Scared = "scared", Hide = "hide", Win = "win", Lose = "lose"}
function Appearance.SetMood(rig, mood)
	if not rig then return false end
	rig:SetAttribute("CatchMood", Appearance.Moods[mood] and mood or "Idle")
	return true
end

-- ---------------------------------------------------------------------------------------
-- Masks sit in front of the player's real face. Bold, simple shapes; a little metal, no glow.
-- ---------------------------------------------------------------------------------------
local masks = {
	mask_street = true, mask_visor = true, mask_phantom = true, mask_kitsune = true,
	mask_skull = true, mask_ninja = true, mask_jester = true, mask_pixel = true,
}
function Appearance.HasMask(id) return masks[id] ~= nil end
Appearance.MaskOrder = {"mask_street", "mask_visor", "mask_ninja", "mask_jester", "mask_phantom", "mask_kitsune", "mask_skull", "mask_pixel"}

local function buildMask(k, maskId)
	local white, ink, gold = C(250, 246, 240), C(30, 30, 44), C(255, 205, 60)
	local m = function(name, size, cf, color, material, shape, opts) return k.p("Head", name, size, cf, color, material, shape, opts) end
	if maskId == "mask_street" then
		local teal, light = C(30, 190, 200), C(255, 255, 255)
		m("BandanaCloth", Vector3.new(1.34, 0.56, 0.24), offset(0, -0.26, -0.6), teal)
		m("BandanaPoint", Vector3.new(0.6, 0.34, 0.24), offset(0, -0.62, -0.58, 0, 0, 180), teal, nil, "Wedge")
		m("BandanaTopEdge", Vector3.new(1.34, 0.08, 0.26), offset(0, -0.02, -0.61), light)
		for _, x in ipairs({-0.4, 0, 0.4}) do m("BandanaDot", Vector3.new(0.12, 0.12, 0.05), offset(x, -0.3, -0.73), light, nil, "Disc") end
		m("BandanaKnot", Vector3.new(0.4, 0.34, 0.34), offset(0.3, -0.2, 0.66), teal, nil, "Ball")
		m("BandanaStrap", Vector3.new(1.28, 0.2, 1.28), offset(0, -0.2, 0.0), teal, nil, "Can")
	elseif maskId == "mask_visor" then
		-- Cool shades: opaque lenses, bright frame.
		local frame = C(255, 90, 160)
		m("ShadesBridge", Vector3.new(1.32, 0.12, 0.16), offset(0, 0.14, -0.64), frame)
		for _, s in ipairs(SIDES) do
			m("ShadesLens_" .. s[1], Vector3.new(0.54, 0.4, 0.14), offset(s[2] * 0.3, 0.1, -0.66), ink, M.Glass, nil, {transparency = 0.1})
			m("ShadesRim_" .. s[1], Vector3.new(0.6, 0.46, 0.1), offset(s[2] * 0.3, 0.1, -0.63), frame)
			m("ShadesShine_" .. s[1], Vector3.new(0.14, 0.06, 0.06), offset(s[2] * 0.4, 0.2, -0.74, 0, 0, 20), white)
			m("ShadesArm_" .. s[1], Vector3.new(0.1, 0.12, 1.0), offset(s[2] * 0.62, 0.14, -0.1), frame)
		end
	elseif maskId == "mask_ninja" then
		local cloth, wrap = C(40, 44, 70), C(230, 40, 50)
		m("WrapLower", Vector3.new(1.34, 0.62, 0.24), offset(0, -0.22, -0.6), cloth)
		m("WrapNose", Vector3.new(0.5, 0.24, 0.26), offset(0, 0.06, -0.62), cloth, nil, "Wedge")
		m("WrapStrap", Vector3.new(1.3, 0.24, 1.3), offset(0, -0.1, 0.0), cloth, nil, "Can")
		m("WrapStripe", Vector3.new(1.36, 0.08, 0.26), offset(0, -0.46, -0.6), wrap)
		m("WrapTail", Vector3.new(0.24, 0.9, 0.08), offset(0.4, -0.4, 0.68, 12, 0, -8), wrap)
	elseif maskId == "mask_jester" then
		local purple = C(150, 80, 230)
		m("JesterFace", Vector3.new(1.06, 0.84, 0.2), offset(0, -0.02, -0.62), white)
		m("JesterHalf", Vector3.new(0.53, 0.84, 0.21), offset(0.265, -0.02, -0.63), purple)
		for _, s in ipairs(SIDES) do
			m("JesterEye_" .. s[1], Vector3.new(0.32, 0.24, 0.06), offset(s[2] * 0.26, 0.14, -0.74, 0, 0, s[2] * 18), ink)
			m("JesterBrowPoint_" .. s[1], Vector3.new(0.4, 0.36, 0.22), offset(s[2] * 0.46, 0.52, -0.58, 0, 0, s[2] * -28), s[1] == "Left" and white or purple, nil, "Wedge")
			m("JesterBell_" .. s[1], Vector3.new(0.26, 0.26, 0.26), offset(s[2] * 0.74, 0.8, -0.58), gold, M.Metal, "Ball")
		end
		m("JesterGrin", Vector3.new(0.74, 0.22, 0.06), offset(0, -0.26, -0.74), ink)
		for x = -0.24, 0.24, 0.12 do m("JesterTooth", Vector3.new(0.07, 0.15, 0.06), offset(x, -0.24, -0.78), white) end
		m("JesterNose", Vector3.new(0.22, 0.22, 0.22), offset(0, -0.06, -0.78), C(236, 70, 80), nil, "Ball")
	elseif maskId == "mask_phantom" then
		m("PhantomCeramic", Vector3.new(1.06, 0.9, 0.2), offset(0, -0.02, -0.62), white)
		for _, s in ipairs(SIDES) do
			m("PhantomCheek_" .. s[1], Vector3.new(0.36, 0.42, 0.16), offset(s[2] * 0.36, -0.3, -0.68, 0, 0, s[2] * 20), white, nil, "Wedge")
			m("PhantomEye_" .. s[1], Vector3.new(0.34, 0.14, 0.06), offset(s[2] * 0.26, 0.12, -0.74, 0, 0, s[2] * 10), ink)
			m("PhantomGoldBrow_" .. s[1], Vector3.new(0.38, 0.06, 0.06), offset(s[2] * 0.26, 0.26, -0.75, 0, 0, s[2] * 10), gold, M.Metal)
			m("PhantomFiligree_" .. s[1], Vector3.new(0.08, 0.36, 0.06), offset(s[2] * 0.47, -0.03, -0.75, 0, 0, s[2] * 18), gold, M.Metal)
		end
		m("PhantomNose", Vector3.new(0.16, 0.28, 0.2), offset(0, -0.06, -0.78, 0, 0, 180), white, nil, "Wedge")
		m("PhantomMouth", Vector3.new(0.26, 0.06, 0.04), offset(0, -0.3, -0.75), ink)
	elseif maskId == "mask_kitsune" then
		local vermilion = C(226, 70, 70)
		m("FoxFace", Vector3.new(1.06, 0.82, 0.22), offset(0, -0.02, -0.63), white)
		for _, s in ipairs(SIDES) do
			m("FoxEar_" .. s[1], Vector3.new(0.4, 0.84, 0.2), offset(s[2] * 0.44, 0.66, -0.5, 0, 0, s[2] * -18), white, nil, "Wedge")
			m("FoxEarInner_" .. s[1], Vector3.new(0.2, 0.5, 0.06), offset(s[2] * 0.45, 0.64, -0.62, 0, 0, s[2] * -18), vermilion, nil, "Wedge")
			m("FoxEye_" .. s[1], Vector3.new(0.34, 0.1, 0.06), offset(s[2] * 0.26, 0.1, -0.75, 0, 0, s[2] * 20), vermilion)
			m("FoxCheekMark_" .. s[1], Vector3.new(0.3, 0.08, 0.06), offset(s[2] * 0.34, -0.14, -0.75, 0, 0, s[2] * -25), vermilion)
		end
		m("FoxMuzzle", Vector3.new(0.42, 0.28, 0.26), offset(0, -0.26, -0.78), white)
		m("FoxNose", Vector3.new(0.16, 0.1, 0.06), offset(0, -0.19, -0.92), ink)
		m("FoxForeheadSeal", Vector3.new(0.2, 0.26, 0.05), offset(0, 0.28, -0.75, 0, 0, 45), vermilion)
	elseif maskId == "mask_skull" then
		m("SkullForehead", Vector3.new(1.08, 0.54, 0.24), offset(0, 0.2, -0.62), gold, M.Metal)
		for _, s in ipairs(SIDES) do
			m("SkullCheek_" .. s[1], Vector3.new(0.34, 0.4, 0.18), offset(s[2] * 0.4, -0.14, -0.66, 0, 0, s[2] * 18), gold, M.Metal)
			m("SkullSocket_" .. s[1], Vector3.new(0.36, 0.3, 0.08), offset(s[2] * 0.27, 0.1, -0.78, 0, 0, s[2] * 9), ink)
			m("SkullEye_" .. s[1], Vector3.new(0.12, 0.12, 0.05), offset(s[2] * 0.27, 0.1, -0.83), C(255, 90, 90), nil, "Disc")
		end
		m("SkullJaw", Vector3.new(0.7, 0.3, 0.22), offset(0, -0.34, -0.64), gold, M.Metal)
		m("SkullNasal", Vector3.new(0.15, 0.19, 0.06), offset(0, -0.1, -0.8, 0, 0, 180), ink, nil, "Wedge")
		for x = -0.24, 0.24, 0.12 do m("ToothGap", Vector3.new(0.04, 0.17, 0.04), offset(x, -0.34, -0.77), ink) end
	elseif maskId == "mask_pixel" then
		local screen, glow = C(34, 40, 66), C(80, 235, 160)
		m("PixelScreen", Vector3.new(1.1, 0.9, 0.22), offset(0, -0.02, -0.62), screen, M.Metal)
		m("PixelFrame", Vector3.new(1.18, 0.98, 0.14), offset(0, -0.02, -0.58), C(100, 110, 150), M.Metal)
		for _, s in ipairs(SIDES) do
			m("PixelEye_" .. s[1], Vector3.new(0.26, 0.26, 0.06), offset(s[2] * 0.25, 0.14, -0.74), glow)
			m("PixelCheek_" .. s[1], Vector3.new(0.12, 0.12, 0.06), offset(s[2] * 0.36, -0.2, -0.74), C(255, 120, 190))
		end
		for i, x in ipairs({-0.3, -0.15, 0, 0.15, 0.3}) do
			m("PixelMouth" .. i, Vector3.new(0.12, 0.12, 0.06), offset(x, i % 2 == 0 and -0.34 or -0.28, -0.74), glow)
		end
		m("PixelAntenna", Vector3.new(0.06, 0.44, 0.06), offset(0, 0.78, -0.2), C(100, 110, 150), M.Metal)
		m("PixelAntennaTip", Vector3.new(0.18, 0.18, 0.18), offset(0, 1.02, -0.2), glow, nil, "Ball")
	end
end

-- ---------------------------------------------------------------------------------------
-- Effects: sprint trails and rarity auras. Both are tiny and switched off by distance LOD elsewhere.
-- ---------------------------------------------------------------------------------------
local function addTrail(folder, rig, id)
	if id ~= "trail_cyan" and id ~= "trail_sunset" and id ~= "trail_rainbow" and id ~= "trail_flame" and id ~= "trail_candy" then return end
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
	elseif id == "trail_flame" then trail.Color = ColorSequence.new(C(255, 220, 90), C(255, 70, 20))
	elseif id == "trail_candy" then trail.Color = ColorSequence.new(C(255, 140, 200), C(120, 235, 200))
	else
		trail.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, C(255, 90, 120)), ColorSequenceKeypoint.new(0.35, C(255, 220, 90)),
			ColorSequenceKeypoint.new(0.7, C(90, 240, 160)), ColorSequenceKeypoint.new(1, C(100, 150, 255))})
	end
	trail.Lifetime = 0.33
	trail.MinLength = 0.08
	trail.FaceCamera = true
	trail.LightEmission = 0.4
	trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)})
	trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.72), NumberSequenceKeypoint.new(1, 0)})
	trail.Parent = folder
end

-- Ambient auras: one small emitter per Epic/Legendary skin. `kind` shapes the motion.
local function addAura(folder, rig, definition)
	local aura = definition.aura
	if not aura then return end
	local target = bodyPart(rig, aura.mount or "UpperTorso")
	local mount = attach(folder, target, "AuraMount", Vector3.new(0.2, 0.2, 0.2), aura.at or offset(0, 0, 0), Color3.new())
	if not mount then return end
	mount.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Name = "Aura_" .. aura.kind
	e.Color = ColorSequence.new(aura.color[1], aura.color[2])
	e.LockedToPart = aura.kind == "jet"
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	if aura.kind == "gold" or aura.kind == "stars" or aura.kind == "sprinkles" then
		e.Rate, e.Lifetime, e.Speed, e.SpreadAngle = 7, NumberRange.new(1.0, 1.8), NumberRange.new(0.5, 1.5), Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, 0.8, 0)
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
		e.LightEmission = 0.5
	elseif aura.kind == "embers" then
		e.Rate, e.Lifetime, e.Speed, e.SpreadAngle = 9, NumberRange.new(0.9, 1.6), NumberRange.new(1.5, 3), Vector2.new(30, 30)
		e.Acceleration = Vector3.new(0, 4, 0)
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0)})
		e.LightEmission = 0.6
	elseif aura.kind == "jet" then
		e.Rate, e.Lifetime, e.Speed, e.SpreadAngle = 14, NumberRange.new(0.25, 0.45), NumberRange.new(5, 8), Vector2.new(8, 8)
		e.Acceleration = Vector3.new(0, -6, 0)
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
		e.LightEmission = 0.7
	else -- wisps
		e.Rate, e.Lifetime, e.Speed, e.SpreadAngle = 6, NumberRange.new(1.2, 2.0), NumberRange.new(0.8, 1.6), Vector2.new(60, 60)
		e.Acceleration = Vector3.new(0, 1.2, 0)
		e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.1)})
		e.LightEmission = 0.3
	end
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
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

local function hideHair(rig)
	for _, child in ipairs(rig:GetChildren()) do
		if child:IsA("Accessory") then
			local kind = child.AccessoryType
			if kind == Enum.AccessoryType.Hair or kind == Enum.AccessoryType.Hat then
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
	if tint.stashClothes then
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
	if definition.hidesHair then hideHair(rig) end
	if definition.tint then tintAvatar(rig, definition.tint) end
	local folder = Instance.new("Folder")
	folder.Name = "CatchAppearance"
	folder.Parent = rig
	local kit = {isR6 = rig:FindFirstChild("UpperTorso") == nil}
	kit.p = function(targetName, name, size, cf, color, material, shape, opts)
		return attach(folder, bodyPart(rig, targetName), name, size, cf, color, material, shape, opts)
	end
	definition.build(kit)
	buildMask(kit, maskId)
	addAura(folder, rig, definition)
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

-- Build a standing model of a real avatar from a HumanoidDescription (yields; wrap in pcall + task.spawn).
function Appearance.BuildAvatar(description, rigType)
	if description == nil then return nil end
	local ok, model = pcall(function()
		return game:GetService("Players"):CreateHumanoidModelFromDescription(description, rigType or Enum.HumanoidRigType.R15)
	end)
	if not ok or not model then return nil end
	model.Name = "CatchAvatarBase"
	anchorPreview(model)
	-- Same frame as the mannequin: root at the origin, facing -Z, so previews can share cameras.
	pcall(function() model:PivotTo(CFrame.new()) end)
	return model
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
