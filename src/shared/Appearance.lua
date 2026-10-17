-- Original, asset-free costume geometry shared by live characters and viewport previews.
-- Apply only changes appearance: every attached part is massless and non-colliding.
local Appearance = {Version = 2}

local C = Color3.fromRGB
local palettes = {
	skin_courier = {base=C(25,34,49), coat=C(40,100,112), trim=C(230,229,209), detail=C(255,145,90), skin=C(193,145,112)},
	skin_rooftop = {base=C(28,39,60), coat=C(53,97,156), trim=C(165,215,242), detail=C(235,117,79), skin=C(185,127,96)},
	skin_gardener = {base=C(57,76,61), coat=C(130,167,108), trim=C(239,221,164), detail=C(232,156,107), skin=C(155,103,76)},
	skin_shadow = {base=C(23,24,35), coat=C(38,37,55), trim=C(99,86,147), detail=C(191,139,255), skin=C(139,120,153)},
	skin_golden = {base=C(38,38,46), coat=C(239,227,188), trim=C(201,153,57), detail=C(255,224,116), skin=C(180,131,93)},
	skin_neon = {base=C(27,34,56), coat=C(109,51,137), trim=C(62,226,225), detail=C(248,107,212), skin=C(159,112,86)},
	skin_crimson = {base=C(43,30,40), coat=C(145,44,62), trim=C(192,191,201), detail=C(255,113,85), skin=C(150,113,95)},
}
local masks = {mask_phantom=true,mask_kitsune=true,mask_skull=true,mask_visor=true,mask_street=true}
local nominal = {
	Head=Vector3.new(1.15,1,1), UpperTorso=Vector3.new(2,1.6,1), LowerTorso=Vector3.new(1.8,0.7,0.9),
	LeftUpperArm=Vector3.new(0.7,1.1,0.8), RightUpperArm=Vector3.new(0.7,1.1,0.8),
	LeftLowerArm=Vector3.new(0.65,1,0.7), RightLowerArm=Vector3.new(0.65,1,0.7),
	LeftHand=Vector3.new(0.65,0.4,0.7), RightHand=Vector3.new(0.65,0.4,0.7),
	LeftUpperLeg=Vector3.new(0.85,1.1,0.85), RightUpperLeg=Vector3.new(0.85,1.1,0.85),
	LeftLowerLeg=Vector3.new(0.8,1.1,0.8), RightLowerLeg=Vector3.new(0.8,1.1,0.8),
	LeftFoot=Vector3.new(0.85,0.4,1.1), RightFoot=Vector3.new(0.85,0.4,1.1),
	HumanoidRootPart=Vector3.new(2,2,1),
}
local function mul(a,b) return Vector3.new(a.X*b.X,a.Y*b.Y,a.Z*b.Z) end
local function offset(x,y,z,rx,ry,rz)
	return CFrame.new(x,y,z) * CFrame.Angles(math.rad(rx or 0),math.rad(ry or 0),math.rad(rz or 0))
end
-- Experience avatar settings can override a place's R15 preference. Fit the same
-- authored outfit to R6 limb sections without replacing joints or the character.
local r6Segments = {
	UpperTorso={"Torso",Vector3.new(2,1.35,1),Vector3.new(0,0.325,0)},
	LowerTorso={"Torso",Vector3.new(1.8,0.65,0.9),Vector3.new(0,-0.675,0)},
}
for _, side in ipairs({"Left","Right"}) do
	r6Segments[side.."UpperArm"]={side.." Arm",Vector3.new(1,0.9,1),Vector3.new(0,0.55,0)}
	r6Segments[side.."LowerArm"]={side.." Arm",Vector3.new(1,0.75,1),Vector3.new(0,-0.275,0)}
	r6Segments[side.."Hand"]={side.." Arm",Vector3.new(1,0.35,1),Vector3.new(0,-0.825,0)}
	r6Segments[side.."UpperLeg"]={side.." Leg",Vector3.new(0.95,0.9,0.95),Vector3.new(0,0.55,0)}
	r6Segments[side.."LowerLeg"]={side.." Leg",Vector3.new(0.9,0.75,0.9),Vector3.new(0,-0.275,0)}
	r6Segments[side.."Foot"]={side.." Leg",Vector3.new(1,0.35,1.1),Vector3.new(0,-0.825,-0.1)}
end
local function bodyPart(rig, name)
	local actual = rig:FindFirstChild(name)
	if actual and actual:IsA("BasePart") then return actual end
	local segment = r6Segments[name]
	local limb = segment and rig:FindFirstChild(segment[1])
	if not limb or not limb:IsA("BasePart") then return nil end
	local standard = segment[1] == "Torso" and Vector3.new(2,2,1) or Vector3.new(1,2,1)
	local scale = Vector3.new(limb.Size.X/standard.X,limb.Size.Y/standard.Y,limb.Size.Z/standard.Z)
	return {Name=name,Size=mul(segment[2],scale),CFrame=limb.CFrame*CFrame.new(mul(segment[3],scale)),Anchored=limb.Anchored,Part=limb}
end
function Appearance.IsRigReady(rig)
	if not rig or not rig:IsA("Model") then return false end
	for name in pairs(nominal) do if not bodyPart(rig,name) then return false end end
	return rig:FindFirstChildOfClass("Humanoid") ~= nil
end
local function attach(folder, target, name, size, cf, color, material, shape)
	if not target then return nil end
	local base = nominal[target.Name] or target.Size
	local scale = Vector3.new(target.Size.X/base.X,target.Size.Y/base.Y,target.Size.Z/base.Z)
	local part = Instance.new(shape == "Wedge" and "WedgePart" or "Part")
	part.Name = name
	part.Size = mul(size,scale)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape == "Ball" then part.Shape = Enum.PartType.Ball end
	if shape == "Cylinder" then part.Shape = Enum.PartType.Cylinder end
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.Massless = true
	-- Live roots are temporarily anchored by head starts and vaults. A welded
	-- cosmetic must never keep that avatar anchored after the move ends.
	part.Anchored = folder.Parent:GetAttribute("CatchPreview") == true and target.Anchored
	part.CFrame = target.CFrame * CFrame.new(mul(cf.Position,scale)) * (cf-cf.Position)
	part.Parent = folder
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = type(target)=="table" and target.Part or target, part
	weld.Parent = part
	return part
end

local function costume(folder, rig, skinId, maskId, p)
	local head, torso, hip = bodyPart(rig,"Head"),bodyPart(rig,"UpperTorso"),bodyPart(rig,"LowerTorso")
	local function piece(target,name,size,cf,color,material,shape)
		return attach(folder,target,name,size,cf,color or p.coat,material,shape)
	end
	-- Structured clothing encloses limbs without replacing any motor or collision body.
	for _, name in ipairs({"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot"}) do
		local body = bodyPart(rig,name)
		if body then
			local isCoat = name == "UpperTorso" or string.find(name,"Arm") ~= nil
			piece(body,"Tailored_"..name,nominal[name]+Vector3.new(0.055,0.025,0.055),CFrame.new(),isCoat and p.coat or p.base)
		end
	end
	for _, side in ipairs({"Left","Right"}) do
		piece(bodyPart(rig,side.."LowerArm"),"Cuff",Vector3.new(0.71,0.15,0.77),offset(0,-0.41,0),p.base)
		piece(bodyPart(rig,side.."Foot"),"SneakerToe",Vector3.new(0.91,0.21,0.48),offset(0,0.04,-0.36),p.coat)
		piece(bodyPart(rig,side.."Foot"),"SneakerSole",Vector3.new(0.93,0.12,1.19),offset(0,-0.19,-0.02),p.trim)
		piece(bodyPart(rig,side.."Foot"),"SneakerTongue",Vector3.new(0.36,0.10,0.46),offset(0,0.23,-0.15,12),p.detail)
		piece(bodyPart(rig,side.."LowerLeg"),"BootStripe",Vector3.new(0.10,0.65,0.05),offset(side=="Left" and -0.28 or 0.28,-0.2,-0.43),p.trim)
		piece(bodyPart(rig,side.."UpperLeg"),"CargoPocket",Vector3.new(0.22,0.47,0.62),offset(side=="Left" and -0.45 or 0.45,-0.21,0),p.base)
		piece(bodyPart(rig,side.."UpperLeg"),"CargoFlap",Vector3.new(0.24,0.10,0.66),offset(side=="Left" and -0.46 or 0.46,0.01,0),p.coat)
	end
	piece(hip,"Belt",Vector3.new(1.87,0.18,0.97),offset(0,0.24,0),p.base)
	piece(hip,"Buckle",Vector3.new(0.28,0.24,0.09),offset(0,0.24,-0.55),p.trim,Enum.Material.Metal)
	if skinId == "skin_shadow" then
		piece(head,"HoodCrown",Vector3.new(1.46,0.43,1.31),offset(0,0.55,0.08,-8),p.base,nil,"Ball")
		piece(head,"HoodBack",Vector3.new(1.45,1.20,0.22),offset(0,-0.02,0.57),p.base)
		for _, side in ipairs({-1,1}) do
			piece(head,"HoodFold",Vector3.new(0.25,1.18,1.24),offset(side*0.65,0,0.07,0,0,side*-10),p.coat)
			piece(head,"HoodLip",Vector3.new(0.09,0.84,0.10),offset(side*0.53,0.12,-0.57,0,0,side*-10),p.trim)
			piece(torso,"LayeredShoulder",Vector3.new(0.73,0.31,1.12),offset(side*0.93,0.69,0,0,0,side*15),p.base,Enum.Material.Metal)
			piece(torso,"SplitCape",Vector3.new(1.10,2.8,0.16),offset(side*0.47,-0.75,0.81,12,0,side*-5),p.base)
			piece(torso,"CapeTip",Vector3.new(0.99,0.55,0.15),offset(side*0.59,-2.36,1.14,12,0,180),p.coat,nil,"Wedge")
		end
		piece(torso,"CrossedHarness",Vector3.new(0.22,1.73,0.10),offset(0,0,-0.59,0,0,32),p.trim)
		piece(torso,"AmethystClasp",Vector3.new(0.24,0.24,0.15),offset(0,0.51,-0.69,0,0,45),p.detail,Enum.Material.Neon)
		piece(bodyPart(rig,"LeftLowerArm"),"ScoutBracer",Vector3.new(0.8,0.76,0.84),offset(0,0,0),p.base)
		for _, side in ipairs({-1,1}) do
			piece(torso,"NightRouteInsignia",Vector3.new(0.10,1.12,0.06),offset(side*0.28,-0.38,0.94,12,0,side*25),p.detail)
		end
		piece(torso,"ShadowNeckWrap",Vector3.new(1.24,0.25,1.14),offset(0,0.82,0.04),p.coat)
	elseif skinId == "skin_golden" then
		for _, side in ipairs({-1,1}) do
			piece(torso,"PhantomLapels",Vector3.new(0.36,1.40,0.13),offset(side*0.52,0.16,-0.60,0,0,side*-18),p.trim,Enum.Material.Metal)
			piece(torso,"CoatTail",Vector3.new(0.86,1.8,0.16),offset(side*0.57,-1.34,0.55,8,0,side*-8),p.coat)
			piece(torso,"TailGoldHem",Vector3.new(0.07,1.7,0.06),offset(side*0.90,-1.30,0.65,8,0,side*-8),p.trim,Enum.Material.Metal)
			piece(torso,"StandingCollar",Vector3.new(0.24,0.81,0.85),offset(side*0.62,0.89,0.22,-16,0,side*-14),p.trim,Enum.Material.Metal)
			for layer=1,3 do
				piece(torso,"DecoFan",Vector3.new(0.31,0.18,1.04-layer*0.12),offset(side*(0.98+layer*0.16),0.67+layer*0.12,0.06,0,0,side*22),p.trim,Enum.Material.Metal)
			end
		end
		piece(torso,"DarkWaistcoat",Vector3.new(0.65,1.43,0.08),offset(0,-0.03,-0.58),p.base)
		for y=-0.5,0.5,0.33 do piece(torso,"DecoButton",Vector3.new(0.10,0.10,0.08),offset(0,y,-0.66,0,0,45),p.detail,Enum.Material.Metal) end
		piece(head,"PhantomBrow",Vector3.new(1.03,0.13,0.14),offset(0,0.43,-0.53),p.trim,Enum.Material.Metal)
		piece(torso,"PhantomBrooch",Vector3.new(0.30,0.30,0.12),offset(-0.67,0.48,-0.75,0,0,45),p.detail,Enum.Material.Metal)
		for _, side in ipairs({-1,1}) do
			piece(torso,"CoatPocketWelt",Vector3.new(0.40,0.08,0.07),offset(side*0.60,-0.43,-0.61,0,0,side*8),p.trim,Enum.Material.Metal)
		end
	elseif skinId == "skin_neon" then
		piece(torso,"PufferYoke",Vector3.new(2.19,0.45,1.2),offset(0,0.56,0),p.coat)
		piece(torso,"ZipGlow",Vector3.new(0.07,1.47,0.06),offset(0,-0.02,-0.58),p.trim,Enum.Material.Neon)
		for _, side in ipairs({-1,1}) do
			piece(torso,"NeonCollar",Vector3.new(0.44,0.53,0.88),offset(side*0.5,0.89,0.07,0,0,side*-15),p.base)
			piece(torso,"Piping",Vector3.new(0.07,0.39,1.24),offset(side*1.09,0.56,0),p.trim,Enum.Material.Neon)
			piece(bodyPart(rig,side==-1 and "LeftUpperArm" or "RightUpperArm"),"JacketPuff",Vector3.new(0.91,0.90,0.96),offset(0,0.07,0),p.coat)
			piece(bodyPart(rig,side==-1 and "LeftLowerArm" or "RightLowerArm"),"WristDisplay",Vector3.new(0.45,0.33,0.08),offset(0,-0.14,-0.43),p.trim,Enum.Material.Neon)
		end
		piece(torso,"TechPack",Vector3.new(1.10,1.15,0.47),offset(0,0.05,0.78),p.base)
		piece(torso,"PackBattery",Vector3.new(0.44,0.83,0.07),offset(0,0.05,1.05),p.detail,Enum.Material.Neon)
		piece(head,"Receiver",Vector3.new(0.22,0.48,0.48),offset(-0.68,0.12,0),p.base)
		piece(head,"Antenna",Vector3.new(0.06,0.45,0.06),offset(-0.69,0.55,0.1,0,0,-12),p.trim,Enum.Material.Neon)
		for _, y in ipairs({-0.42,0.05}) do
			piece(torso,"QuiltedJacketPanel",Vector3.new(1.98,0.33,0.12),offset(0,y,-0.57),p.coat)
		end
		piece(torso,"OutlawBackChevron",Vector3.new(0.63,0.10,0.06),offset(0,0.34,1.10,0,0,-24),p.trim,Enum.Material.Neon)
		if maskId == "" or not maskId then
			piece(head,"IntegratedTechVisor",Vector3.new(1.24,0.25,0.13),offset(0,0.12,-0.57),p.base)
			piece(head,"IntegratedTechLens",Vector3.new(1.06,0.10,0.06),offset(0,0.13,-0.67),p.trim,Enum.Material.Neon)
		end
	elseif skinId == "skin_crimson" then
		piece(torso,"ArmoredChest",Vector3.new(1.74,1.07,0.24),offset(0,0.14,-0.66),p.coat,Enum.Material.Metal)
		piece(torso,"ChestRidge",Vector3.new(0.14,1.13,0.12),offset(0,0.13,-0.83),p.trim,Enum.Material.Metal)
		for _, side in ipairs({-1,1}) do
			piece(torso,"HunterPauldron",Vector3.new(0.94,0.51,1.19),offset(side*1.18,0.65,0,0,0,side*16),p.coat,Enum.Material.Metal,"Wedge")
			piece(torso,"PauldronRim",Vector3.new(0.13,0.53,1.23),offset(side*1.54,0.52,0,0,0,side*16),p.trim,Enum.Material.Metal)
			piece(torso,"ChestSlash",Vector3.new(0.67,0.10,0.07),offset(side*0.45,0.38,-0.82,0,0,side*-15),p.detail,Enum.Material.Neon)
			local sideName = side==-1 and "Left" or "Right"
			piece(bodyPart(rig,sideName.."LowerArm"),"HunterGauntlet",Vector3.new(0.86,0.80,0.91),offset(0,-0.02,0),p.coat,Enum.Material.Metal)
			piece(bodyPart(rig,sideName.."LowerLeg"),"KneeShield",Vector3.new(0.73,0.51,0.19),offset(0,0.42,-0.49),p.coat,Enum.Material.Metal)
			piece(head,"TempleArmor",Vector3.new(0.22,0.57,0.75),offset(side*0.63,0.15,0.05),p.coat,Enum.Material.Metal)
		end
		piece(head,"HunterBrow",Vector3.new(1.35,0.26,0.73),offset(0,0.45,-0.02),p.coat,Enum.Material.Metal)
		piece(head,"Crest",Vector3.new(0.22,0.31,0.93),offset(0,0.68,0.03),p.trim,Enum.Material.Metal)
		piece(torso,"CrimsonCore",Vector3.new(0.29,0.29,0.09),offset(0,0.42,-0.94,0,0,45),p.detail,Enum.Material.Neon)
		for _, side in ipairs({-1,1}) do
			piece(hip,"ArmoredJacketHem",Vector3.new(0.63,0.52,0.16),offset(side*0.55,-0.13,-0.53,0,0,side*8),p.coat,Enum.Material.Metal,"Wedge")
		end
	elseif skinId == "skin_rooftop" then
		piece(torso,"ScarfLoop",Vector3.new(1.40,0.29,1.13),offset(0,0.81,0),p.detail)
		piece(torso,"WindScarf",Vector3.new(0.48,1.87,0.15),offset(0.58,0.1,0.87,-20,0,-12),p.detail)
		piece(torso,"WindbreakerZip",Vector3.new(0.10,1.40,0.07),offset(0,0,-0.58),p.trim)
		piece(torso,"RouteChevron",Vector3.new(0.67,0.14,0.06),offset(-0.53,0.35,-0.59,0,0,20),p.trim)
		piece(head,"RaisedGogglesBand",Vector3.new(1.26,0.16,1.13),offset(0,0.36,0),p.base)
		for _, side in ipairs({-1,1}) do
			piece(head,"RaisedGoggleLens",Vector3.new(0.43,0.27,0.16),offset(side*0.30,0.42,-0.55),p.detail,Enum.Material.Glass)
			piece(bodyPart(rig,side==-1 and "LeftLowerArm" or "RightLowerArm"),"ClimberWrap",Vector3.new(0.73,0.53,0.79),offset(0,-0.12,0),p.base)
		end
	elseif skinId == "skin_gardener" then
		piece(torso,"UtilityApron",Vector3.new(1.48,1.93,0.11),offset(0,-0.27,-0.58),p.base)
		for _, side in ipairs({-1,1}) do
			piece(torso,"ApronStrap",Vector3.new(0.15,0.80,0.09),offset(side*0.54,0.48,-0.59),p.trim)
			piece(torso,"SeedPocket",Vector3.new(0.55,0.48,0.15),offset(side*0.38,-0.62,-0.69),p.coat)
		end
		piece(head,"StrawHatBrim",Vector3.new(0.14,2.04,2.04),offset(0,0.53,0,0,0,90),p.trim,nil,"Cylinder")
		piece(head,"StrawHatCrown",Vector3.new(0.49,1.25,1.25),offset(0,0.82,0,0,0,90),p.trim,nil,"Cylinder")
		piece(head,"HatRibbon",Vector3.new(0.13,1.29,1.29),offset(0,0.64,0,0,0,90),p.detail,nil,"Cylinder")
		piece(torso,"FlowerStem",Vector3.new(0.06,0.40,0.06),offset(-0.40,0.03,-0.69,0,0,14),p.coat)
		piece(torso,"PocketFlower",Vector3.new(0.23,0.23,0.10),offset(-0.45,0.22,-0.71),p.detail,nil,"Ball")
	else
		-- The free courier is a complete streetwear outfit, not a recolored body:
		-- cropped teal jacket, dropped hood, sling bag, cargo pants and cream soles.
		piece(torso,"HoodVolume",Vector3.new(1.45,0.72,0.66),offset(0,0.73,0.61,-20),p.base,nil,"Ball")
		piece(torso,"HoodLining",Vector3.new(1.02,0.34,0.38),offset(0,0.96,0.63,-20),p.detail,nil,"Ball")
		piece(torso,"Undershirt",Vector3.new(0.57,1.48,0.10),offset(0,-0.04,-0.59),p.trim)
		for _, side in ipairs({-1,1}) do
			piece(torso,"JacketCollar",Vector3.new(0.38,0.56,0.18),offset(side*0.43,0.66,-0.59,0,0,side*-25),p.coat,nil,"Wedge")
			piece(torso,"JacketPocket",Vector3.new(0.50,0.32,0.13),offset(side*0.63,-0.42,-0.61,0,0,side*10),p.base)
			piece(torso,"Drawcord",Vector3.new(0.045,0.43,0.05),offset(side*0.25,0.44,-0.72,0,0,side*5),p.trim)
		end
		piece(torso,"JacketHem",Vector3.new(2.09,0.15,1.08),offset(0,-0.73,0),p.base)
		piece(torso,"MessengerStrap",Vector3.new(0.19,1.96,0.11),offset(0,0,-0.76,0,0,34),p.base)
		piece(hip,"DispatchSatchel",Vector3.new(0.75,0.77,0.51),offset(0.92,-0.02,-0.02),p.detail)
		piece(hip,"SatchelFlap",Vector3.new(0.79,0.29,0.10),offset(0.92,0.19,-0.32),p.trim)
		piece(torso,"CourierPatch",Vector3.new(0.33,0.20,0.07),offset(-0.66,0.35,-0.61,0,0,-12),p.detail)
		piece(head,"CourierHair",Vector3.new(1.24,0.30,1.09),offset(0,0.46,0.05),p.base,nil,"Ball")
		piece(head,"SweptFringe",Vector3.new(0.79,0.29,0.25),offset(-0.20,0.36,-0.51,0,0,-14),p.base,nil,"Wedge")
		piece(head,"CourierReceiver",Vector3.new(0.16,0.30,0.35),offset(0.65,-0.04,0),p.detail)
	end
end

local function mask(folder, rig, maskId)
	local head = rig:FindFirstChild("Head")
	if not head or not maskId or maskId == "" then return end
	local function m(name,size,cf,color,material,shape) return attach(folder,head,name,size,cf,color,material,shape) end
	local white, ink, gold = C(240,235,228),C(28,29,42),C(222,176,73)
	if maskId == "mask_phantom" then
		m("PhantomCeramic",Vector3.new(0.96,0.76,0.17),offset(0,-0.01,-0.60),white)
		for _, side in ipairs({-1,1}) do
			m("PhantomCheek",Vector3.new(0.33,0.38,0.13),offset(side*0.35,-0.26,-0.66,0,0,side*20),white,nil,"Wedge")
			m("PhantomEye",Vector3.new(0.27,0.10,0.06),offset(side*0.26,0.12,-0.72,0,0,side*10),ink)
			m("PhantomGoldBrow",Vector3.new(0.31,0.045,0.06),offset(side*0.26,0.23,-0.73,0,0,side*10),gold,Enum.Material.Metal)
			m("PhantomTempleFiligree",Vector3.new(0.065,0.31,0.06),offset(side*0.46,-0.03,-0.73,0,0,side*18),gold,Enum.Material.Metal)
		end
		m("PhantomNose",Vector3.new(0.12,0.24,0.17),offset(0,-0.05,-0.76,0,0,180),white,nil,"Wedge")
		m("PhantomMouth",Vector3.new(0.21,0.045,0.04),offset(0,-0.28,-0.75),ink)
	elseif maskId == "mask_kitsune" then
		m("FoxFace",Vector3.new(0.96,0.68,0.19),offset(0,-0.01,-0.62),white)
		for _, side in ipairs({-1,1}) do
			m("FoxEar",Vector3.new(0.32,0.63,0.17),offset(side*0.42,0.48,-0.58,0,0,side*-18),white,nil,"Wedge")
			m("FoxEarInner",Vector3.new(0.15,0.35,0.05),offset(side*0.43,0.47,-0.69,0,0,side*-18),C(195,65,82),nil,"Wedge")
			m("FoxEye",Vector3.new(0.28,0.075,0.06),offset(side*0.25,0.09,-0.75,0,0,side*20),C(174,37,60))
			m("FoxCheekMark",Vector3.new(0.24,0.07,0.06),offset(side*0.33,-0.13,-0.75,0,0,side*-25),C(195,65,82))
			m("FoxCheekFacet",Vector3.new(0.24,0.30,0.12),offset(side*0.46,-0.14,-0.64,0,0,side*28),white,nil,"Wedge")
		end
		m("FoxMuzzle",Vector3.new(0.36,0.23,0.23),offset(0,-0.25,-0.76),white)
		m("FoxNose",Vector3.new(0.13,0.08,0.06),offset(0,-0.18,-0.91),ink)
		m("FoxForeheadSeal",Vector3.new(0.16,0.21,0.05),offset(0,0.23,-0.75,0,0,45),C(195,65,82))
	elseif maskId == "mask_skull" then
		m("SkullForehead",Vector3.new(1.01,0.47,0.22),offset(0,0.18,-0.61),gold,Enum.Material.Metal)
		for _, side in ipairs({-1,1}) do
			m("SkullCheek",Vector3.new(0.29,0.35,0.16),offset(side*0.38,-0.13,-0.65,0,0,side*18),gold,Enum.Material.Metal)
			m("SkullSocket",Vector3.new(0.30,0.23,0.07),offset(side*0.26,0.10,-0.77,0,0,side*9),ink)
			m("SkullSocketRidge",Vector3.new(0.35,0.08,0.08),offset(side*0.27,0.24,-0.79,0,0,side*12),C(255,221,126),Enum.Material.Metal)
		end
		m("SkullJaw",Vector3.new(0.62,0.24,0.19),offset(0,-0.33,-0.63),gold,Enum.Material.Metal)
		m("SkullNasal",Vector3.new(0.12,0.16,0.06),offset(0,-0.10,-0.79,0,0,180),ink,nil,"Wedge")
		m("SkullCrownEngraving",Vector3.new(0.07,0.23,0.05),offset(0,0.28,-0.75,0,0,30),ink)
		for x=-0.24,0.24,0.12 do m("ToothGap",Vector3.new(0.025,0.14,0.04),offset(x,-0.33,-0.75),ink) end
	elseif maskId == "mask_visor" then
		m("VisorFrame",Vector3.new(1.34,0.42,0.22),offset(0,0.08,-0.61),ink,Enum.Material.Metal)
		m("VisorLens",Vector3.new(1.16,0.25,0.06),offset(0,0.09,-0.76),C(67,230,232),Enum.Material.Neon)
		m("VisorDivider",Vector3.new(0.05,0.26,0.07),offset(0.31,0.09,-0.80),white)
		for _, side in ipairs({-1,1}) do m("VisorEarpiece",Vector3.new(0.17,0.33,0.87),offset(side*0.67,0.06,-0.17),ink) end
	elseif maskId == "mask_street" then
		m("StreetRespirator",Vector3.new(0.87,0.43,0.21),offset(0,-0.24,-0.62),ink)
		for _, side in ipairs({-1,1}) do
			m("RespiratorFilter",Vector3.new(0.26,0.26,0.14),offset(side*0.35,-0.23,-0.77),C(105,115,133),Enum.Material.Metal,"Ball")
			m("StreetStrap",Vector3.new(0.07,0.10,0.93),offset(side*0.57,-0.13,-0.04),ink)
		end
		for y=-0.32,-0.16,0.08 do m("RespiratorVent",Vector3.new(0.30,0.025,0.04),offset(0,y,-0.75),C(244,184,70)) end
	end
end

local function addTrail(folder, rig, id)
	if id ~= "trail_cyan" and id ~= "trail_sunset" then return end
	local root = rig:FindFirstChild("HumanoidRootPart")
	local mount = attach(folder,root,"TrailMount",Vector3.new(0.05,0.05,0.05),offset(0,-0.55,0.6),Color3.new())
	if not mount then return end
	mount.Transparency = 1
	local a,b = Instance.new("Attachment"),Instance.new("Attachment")
	a.Position,b.Position = Vector3.new(-0.5,0,0),Vector3.new(0.5,0,0)
	a.Parent,b.Parent = mount,mount
	local trail = Instance.new("Trail")
	trail.Name = id
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	trail.Enabled = rig:GetAttribute("CatchPreview") == true or (humanoid ~= nil and humanoid.Health > 0
		and not root.Anchored and rig:GetAttribute("RoundFrozen") ~= true
		and rig:GetAttribute("Sprinting") == true
		and Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude > 3)
	trail.Attachment0,trail.Attachment1 = a,b
	trail.Color = id=="trail_cyan" and ColorSequence.new(C(59,236,228),C(85,123,239)) or ColorSequence.new(C(255,196,91),C(246,86,135))
	trail.Lifetime = 0.33
	trail.MinLength = 0.08
	trail.FaceCamera = true
	trail.LightEmission = 0.65
	trail.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0.35),NumberSequenceKeypoint.new(1,1)})
	trail.WidthScale = NumberSequence.new({NumberSequenceKeypoint.new(0,0.72),NumberSequenceKeypoint.new(1,0)})
	trail.Parent = folder
end

function Appearance.Apply(rig, skinId, maskId, equipped)
	-- CharacterAdded can fire before all limb parts arrive. Do not replace a good
	-- outfit or claim success until every authored attachment has a valid target.
	if not Appearance.IsRigReady(rig) then return nil end
	local old = rig:FindFirstChild("CatchAppearance")
	if old then old:Destroy() end
	skinId = palettes[skinId] and skinId or "skin_courier"
	maskId = masks[maskId] and maskId or ""
	local p = palettes[skinId]
	local colors = rig:FindFirstChildOfClass("BodyColors")
	if colors then
		colors.HeadColor3,colors.TorsoColor3 = p.skin,p.coat
		colors.LeftArmColor3,colors.RightArmColor3 = p.skin,p.skin
		colors.LeftLegColor3,colors.RightLegColor3 = p.base,p.base
	end
	for _, body in ipairs(rig:GetChildren()) do
		if body:IsA("BasePart") and (nominal[body.Name] or body.Name=="Torso" or body.Name:match(" Arm$") or body.Name:match(" Leg$")) and body.Name ~= "HumanoidRootPart" then
			if body:GetAttribute("CatchOriginalColor") == nil then body:SetAttribute("CatchOriginalColor",body.Color) end
			body.Color = p.base
			if body.Name=="UpperTorso" or body.Name=="Torso" or body.Name:find("Arm") then body.Color=p.coat end
			if body.Name=="Head" or body.Name:find("Hand") or body.Name:match(" Arm$") then body.Color=p.skin end
		elseif body:IsA("Accessory") then
			for _, part in ipairs(body:GetDescendants()) do
				if part:IsA("BasePart") then
					if part:GetAttribute("CatchOriginalTransparency") == nil then part:SetAttribute("CatchOriginalTransparency",part.Transparency) end
					part.Transparency = 1
				end
			end
		end
	end
	local folder = Instance.new("Folder")
	folder.Name = "CatchAppearance"
	folder.Parent = rig
	costume(folder,rig,skinId,maskId,p)
	mask(folder,rig,maskId)
	if equipped then addTrail(folder,rig,equipped.trails) end
	folder:SetAttribute("AppearanceVersion",Appearance.Version)
	folder:SetAttribute("SkinId",skinId)
	folder:SetAttribute("MaskId",maskId)
	rig:SetAttribute("CatchAppearanceVersion",Appearance.Version)
	rig:SetAttribute("CatchAppearanceSkinId",skinId)
	rig:SetAttribute("CatchAppearanceRig",rig:FindFirstChild("UpperTorso") and "R15" or "R6")
	-- Keep the asset-free face through repeated outfit and mask changes in previews.
	if rig:GetAttribute("CatchPreview") and maskId == "" then
		local head = rig:FindFirstChild("Head")
		for _, side in ipairs({-1,1}) do attach(folder,head,"PreviewEye",Vector3.new(0.065,0.10,0.035),offset(side*0.20,0.07,-0.54),C(38,35,42)) end
		attach(folder,head,"PreviewSmile",Vector3.new(0.22,0.035,0.035),offset(0,-0.20,-0.54),C(89,55,48))
	end
	return folder
end

-- Temporary team identity is separate from persistent ownership/equipment. It
-- never replaces a chosen mask or skin and is removed on spectator/lobby roles.
function Appearance.ApplyRole(rig, role)
	if not Appearance.IsRigReady(rig) then return nil end
	local old = rig:FindFirstChild("CatchRoleAppearance")
	if old then old:Destroy() end
	rig:SetAttribute("CatchAppearanceRole",role or "Lobby")
	if role ~= "Hunter" then return nil end
	local folder = Instance.new("Folder")
	folder.Name,folder.Parent = "CatchRoleAppearance",rig
	local coral, dark = C(255,91,77),C(71,29,39)
	for _, side in ipairs({"Left","Right"}) do
		local arm = bodyPart(rig,side.."LowerArm")
		attach(folder,arm,"HunterSignalCuff",Vector3.new(0.91,0.18,0.96),offset(0,0.06,0),dark)
		attach(folder,arm,"HunterSignalLight",Vector3.new(0.48,0.085,0.06),offset(0,0.06,-0.51),coral,Enum.Material.Neon)
	end
	local highlight = Instance.new("Highlight")
	highlight.Name,highlight.Adornee = "HunterSilhouette",rig
	highlight.FillTransparency = 1
	highlight.OutlineColor,highlight.OutlineTransparency = coral,0.25
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = folder
	return folder
end

function Appearance.BuildPreview(skinId, maskId, extra)
	local rig = Instance.new("Model")
	rig.Name = "CatchPreview"
	rig:SetAttribute("CatchPreview",true)
	local positions = {
		HumanoidRootPart=Vector3.new(0,0,0),UpperTorso=Vector3.new(0,0.65,0),LowerTorso=Vector3.new(0,-0.50,0),Head=Vector3.new(0,2.02,0),
		LeftUpperArm=Vector3.new(-1.39,0.84,0),RightUpperArm=Vector3.new(1.39,0.84,0),
		LeftLowerArm=Vector3.new(-1.43,-0.21,0),RightLowerArm=Vector3.new(1.43,-0.21,0),
		LeftHand=Vector3.new(-1.43,-0.90,0),RightHand=Vector3.new(1.43,-0.90,0),
		LeftUpperLeg=Vector3.new(-0.46,-1.39,0),RightUpperLeg=Vector3.new(0.46,-1.39,0),
		LeftLowerLeg=Vector3.new(-0.46,-2.49,0),RightLowerLeg=Vector3.new(0.46,-2.49,0),
		LeftFoot=Vector3.new(-0.46,-3.23,-0.12),RightFoot=Vector3.new(0.46,-3.23,-0.12),
	}
	-- Root matches Roblox's standing height of about 3 studs; feet finish at -3.
	for name, position in pairs(positions) do
		if name ~= "HumanoidRootPart" then position += Vector3.new(0,0.43,0) end
		local part = Instance.new("Part")
		part.Name,part.Size = name,nominal[name]
		part.CFrame = CFrame.new(position)
		part.Anchored = true
		part.CanCollide,part.CanTouch,part.CanQuery = false,false,false
		part.Massless = true
		part.Color = C(190,146,112)
		part.TopSurface,part.BottomSurface = Enum.SurfaceType.Smooth,Enum.SurfaceType.Smooth
		if name == "HumanoidRootPart" then part.Transparency = 1 end
		if name == "Head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Head
			mesh.Scale = Vector3.new(1.12,1.05,1.08)
			mesh.Parent = part
		end
		part.Parent = rig
	end
	rig.PrimaryPart = rig:FindFirstChild("HumanoidRootPart")
	-- Preview joints make the model recognizable to avatar tools without live physics.
	local joints = {
		{"Root","HumanoidRootPart","LowerTorso"},{"Waist","LowerTorso","UpperTorso"},{"Neck","UpperTorso","Head"},
		{"LeftShoulder","UpperTorso","LeftUpperArm"},{"RightShoulder","UpperTorso","RightUpperArm"},
		{"LeftElbow","LeftUpperArm","LeftLowerArm"},{"RightElbow","RightUpperArm","RightLowerArm"},
		{"LeftWrist","LeftLowerArm","LeftHand"},{"RightWrist","RightLowerArm","RightHand"},
		{"LeftHip","LowerTorso","LeftUpperLeg"},{"RightHip","LowerTorso","RightUpperLeg"},
		{"LeftKnee","LeftUpperLeg","LeftLowerLeg"},{"RightKnee","RightUpperLeg","RightLowerLeg"},
		{"LeftAnkle","LeftLowerLeg","LeftFoot"},{"RightAnkle","RightLowerLeg","RightFoot"},
	}
	for _, spec in ipairs(joints) do
		local joint = Instance.new("Motor6D")
		joint.Name,joint.Part0,joint.Part1 = spec[1],rig:FindFirstChild(spec[2]),rig:FindFirstChild(spec[3])
		joint.C0 = joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame)
		joint.Parent = joint.Part0
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.Health = 100
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.AutoRotate = false
	humanoid.Parent = rig
	Appearance.Apply(rig,skinId,maskId,extra)
	return rig
end

-- Anchored showroom models cannot rely on live Motor6D physics. Animate the arm
-- geometry and its clothing together, preserving the same pose after PivotTo.
-- The returned animator is intentionally unavailable for live character rigs.
function Appearance.CreatePreviewPose(rig, victoryId)
	if not rig or not rig:IsA("Model") or rig:GetAttribute("CatchPreview") ~= true then return nil end
	if victoryId ~= "victory_wave" and victoryId ~= "victory_spin" then return nil end
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local parts = {}
	local sides = {LeftUpperArm=-1,LeftLowerArm=-1,LeftHand=-1,RightUpperArm=1,RightLowerArm=1,RightHand=1}
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") then
			if not part.Anchored then return nil end
			local weld = part:FindFirstChildOfClass("WeldConstraint")
			local targetName = weld and weld.Part0 and weld.Part0.Name or part.Name
			local side = sides[targetName]
			if side then table.insert(parts,{part=part,side=side,rest=root.CFrame:ToObjectSpace(part.CFrame)}) end
		end
	end
	return function(elapsed)
		if not rig.Parent or not root.Parent then return end
		elapsed = type(elapsed)=="number" and elapsed==elapsed and math.abs(elapsed)<math.huge and elapsed or 0
		local wave = math.sin(elapsed*5.5)
		for _, item in ipairs(parts) do
			if item.part.Parent then
				local angle = victoryId=="victory_spin" and item.side*72
					or (item.side==1 and 138+wave*11 or -8)
				local pivot = CFrame.new(item.side*1.05,1.78,0)
				local rotation = pivot*CFrame.Angles(0,0,math.rad(angle))*pivot:Inverse()
				item.part.CFrame = root.CFrame*rotation*item.rest
			end
		end
	end
end

return Appearance
