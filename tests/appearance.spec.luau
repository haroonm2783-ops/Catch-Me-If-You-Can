-- Run: .tooling/bin/lune run tests/appearance.spec.luau
-- Real Roblox property serialization and geometry; no engine rendering or physics.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Catalog = require("../src/shared/Catalog")
local checks = 0
local function expect(value, message)
	checks += 1
	assert(value, message)
end
local environment = {}
for key, value in pairs(roblox) do environment[key] = value end
-- Shared modules require their siblings the way they do inside Roblox.
local modules = {}
local function loadModule(name)
	local scoped = table.clone(environment)
	scoped.script = {Parent = {WaitForChild = function(_, sibling) return sibling end}}
	scoped.require = function(sibling) return assert(modules[sibling], "unknown sibling " .. tostring(sibling)) end
	modules[name] = luau.load(fs.readFile("src/shared/" .. name .. ".lua"), {environment=scoped,debugName=name})()
	return modules[name]
end
local Trails, Poses, Emotes = loadModule("Trails"), loadModule("Poses"), loadModule("Emotes")
local Appearance = loadModule("Appearance")
local function finite(value) return value == value and math.abs(value) < math.huge end
local function partCount(model)
	local count = 0
	for _, item in ipairs(model:GetDescendants()) do if item:IsA("BasePart") then count += 1 end end
	return count
end
local function audit(rig, anchored)
	local folder = rig:FindFirstChild("CatchAppearance")
	expect(folder ~= nil, "Generated outfit exists")
	for _, item in ipairs(rig:GetDescendants()) do
		if item:IsA("BasePart") then
			for _, n in ipairs({item.Size.X,item.Size.Y,item.Size.Z}) do expect(finite(n) and n > 0 and n < 8, "Finite, bounded part size: "..item.Name) end
			for _, n in ipairs({item.CFrame:GetComponents()}) do expect(finite(n), "Finite transform: "..item.Name) end
			if item:IsDescendantOf(folder) then
				expect(item.Massless and not item.CanCollide and not item.CanTouch and not item.CanQuery, "Cosmetic parts cannot affect movement or tag raycasts: "..item.Name)
				expect(item.Anchored == anchored, "Only showroom cosmetics can be anchored")
				local weld = item:FindFirstChildOfClass("WeldConstraint")
				expect(weld and weld.Part0 and weld.Part0.Parent == rig and weld.Part1 == item, "Attachment is welded to an actual rig body part")
			end
		end
	end
	expect(partCount(rig) <= 110, "Preview and costume stay within the 110-part avatar budget")
	expect(#rig:GetDescendants() <= 420, "Avatar descendants remain bounded")
	-- This exercises Roblox serializer reflection in addition to Luau's constructor API.
	local serialized = roblox.serializeModel({rig})
	expect(#serialized > 0, "Avatar serializes as a valid Roblox model")
	local restored = roblox.deserializeModel(serialized)
	expect(partCount(restored[1]) == partCount(rig), "Serialized avatar retains all geometry")
	restored[1]:Destroy()
end

-- The catalog and the appearance module must agree on every skin and mask.
for _, item in ipairs(Catalog.ForCategory("skins")) do expect(Appearance.HasSkin(item.id), "Catalog skin has geometry: "..item.id) end
for _, item in ipairs(Catalog.ForCategory("masks")) do expect(Appearance.HasMask(item.id), "Catalog mask has geometry: "..item.id) end
for _, id in ipairs(Appearance.SkinOrder) do expect(Catalog.Get(id) and Catalog.Get(id).category == "skins", "Appearance skin is sold: "..id) end
for _, id in ipairs(Appearance.MaskOrder) do expect(Catalog.Get(id) and Catalog.Get(id).category == "masks", "Appearance mask is sold: "..id) end
expect(Catalog.ForCategory("tones")[1] == nil and Catalog.ForCategory("hairColors")[1] == nil, "Players keep their own skin tone and hair: no tone or hair categories")
local skins, masks = Catalog.ForCategory("skins"), {""}
for _, item in ipairs(Catalog.ForCategory("masks")) do table.insert(masks,item.id) end
-- Rarity ladder: every tier exists and the default is a free, untouched avatar.
local tiers = {Common=0,Rare=0,Epic=0,Legendary=0}
for _, skin in ipairs(skins) do tiers[skin.rarity] += 1 end
expect(tiers.Common >= 1 and tiers.Rare >= 3 and tiers.Epic >= 4 and tiers.Legendary >= 2, "Skins span all four rarity tiers")
expect(Catalog.DefaultEquipment.skins == "skin_courier" and Catalog.Get("skin_courier").currency == "Free", "Default skin is the free, untouched avatar")
local signatures, combinations, maximum = {}, 0, 0
for _, skin in ipairs(skins) do
	for _, mask in ipairs(masks) do
		local rig = Appearance.BuildPreview(skin.id,mask,{trails="trail_cyan"})
		audit(rig,true)
		maximum = math.max(maximum,partCount(rig))
		combinations += 1
		if mask == "" then
			local names = {}
			for _, part in ipairs(rig.CatchAppearance:GetChildren()) do if part:IsA("BasePart") and part.Name ~= "TrailMount" and part.Name ~= "AuraMount" then table.insert(names,part.Name) end end
			table.sort(names)
			local signature = table.concat(names,"|")
			if skin.id == "skin_courier" then
				expect(#names == 0, "Original You adds no geometry: the player's own avatar")
			else
				expect(#names >= 20 and #names <= 62, "Every skin is a full costume of 20-62 parts: "..skin.id.." has "..#names)
				expect(not signatures[signature],"Each skin has a distinct geometry silhouette")
				signatures[signature] = true
			end
		end
		local motorCount = 0
		for _, item in ipairs(rig:GetDescendants()) do if item:IsA("Motor6D") then motorCount += 1 end end
		local initial = partCount(rig)
		Appearance.Apply(rig,skin.id,mask,{trails="trail_sunset"})
		local afterFirst = partCount(rig)
		expect(afterFirst == initial,"Reapplying preserves total geometry")
		local firstFolder = rig.CatchAppearance
		Appearance.Apply(rig,skin.id,mask,{trails="trail_sunset"})
		expect(firstFolder.Parent == nil,"Reapplying disposes the old outfit")
		expect(partCount(rig) == afterFirst,"Reapplying never duplicates outfit geometry")
		local newMotorCount, folders, trails = 0, 0, 0
		for _, item in ipairs(rig:GetDescendants()) do
			if item:IsA("Motor6D") then newMotorCount += 1 end
			if item.Name == "CatchAppearance" then folders += 1 end
			if item:IsA("Trail") then
				trails += 1
				expect(item.Attachment0.Parent == item.Attachment1.Parent,"Trail endpoints have a single massless mount")
			end
		end
		expect(motorCount == 15 and newMotorCount == motorCount,"R15 joints survive outfit changes")
		expect(folders == 1 and trails == 1,"One outfit folder and one selected trail")
		-- Every selected skin/mask also retains its geometry on a live R15 avatar,
		-- including when the server is holding the root for a head start or vault.
		rig:SetAttribute("CatchPreview",false)
		for _, part in ipairs(rig:GetChildren()) do if part:IsA("BasePart") then part.Anchored=false end end
		rig.HumanoidRootPart.Anchored = true
		Appearance.Apply(rig,skin.id,mask,{trails="trail_sunset"})
		Appearance.ApplyRole(rig,"Hunter")
		audit(rig,false)
		maximum = math.max(maximum,partCount(rig))
		expect(not rig.CatchAppearance.TrailMount.trail_sunset.Enabled,"Anchored head start never shows a live sprint trail")
		local outfit = rig.CatchAppearance
		local roleFolder = rig.CatchRoleAppearance
		for _, item in ipairs(roleFolder:GetChildren()) do
			if item:IsA("BasePart") then
				expect(not item.Anchored and item.Massless and not item.CanQuery and not item.CanCollide,"Hunter identity cannot freeze or block live movement")
				expect(item.Material ~= roblox.Enum.Material.Neon,"Hunter identity is bold, not neon")
			end
		end
		Appearance.ApplyRole(rig,"Hunter")
		expect(roleFolder.Parent==nil and rig.CatchAppearance==outfit,"Reapplying team identity never duplicates cuffs or replaces paid outfits")
		Appearance.ApplyRole(rig,"Runner")
		expect(not rig:FindFirstChild("CatchRoleAppearance") and rig.CatchAppearance==outfit,"Runner transition removes Hunter identity while preserving cosmetics")
		rig:Destroy()
	end
end
expect(combinations == #skins*#masks and #skins >= 13 and #masks >= 9,"Every skin with every mask and no mask was instantiated")

-- Art direction: restrained glow. No skin or mask is built from glowing neon material.
for _, skin in ipairs(skins) do
	for _, mask in ipairs(masks) do
		local rig = Appearance.BuildPreview(skin.id,mask,{})
		for _, part in ipairs(rig.CatchAppearance:GetChildren()) do
			if part:IsA("BasePart") then expect(part.Material ~= roblox.Enum.Material.Neon,"No neon in cosmetics: "..skin.id.."/"..mask.."/"..part.Name) end
		end
		rig:Destroy()
	end
end
-- Epic and Legendary showpieces with auras: aura emitters exist and stay light.
for _, id in ipairs({"skin_streetwear","skin_cyber","skin_ninja","skin_neonphantom","skin_trickster","skin_candy","skin_galaxy","skin_golden","skin_dragon"}) do
	local rig = Appearance.BuildPreview(id,"",{})
	local emitter
	for _, item in ipairs(rig:GetDescendants()) do if item:IsA("ParticleEmitter") then emitter = item end end
	expect(emitter ~= nil and emitter.Rate <= 16 and emitter.Name:match("^Aura_"),"Showpiece skin has a light ambient aura: "..id)
	rig:Destroy()
end

local function buildR6()
	local rig = roblox.Instance.new("Model")
	local specs = {
		{"HumanoidRootPart",roblox.Vector3.new(2,2,1),roblox.Vector3.zero},
		{"Torso",roblox.Vector3.new(2,2,1),roblox.Vector3.zero},
		{"Head",roblox.Vector3.new(2,1,1),roblox.Vector3.new(0,1.5,0)},
		{"Left Arm",roblox.Vector3.new(1,2,1),roblox.Vector3.new(-1.5,0,0)},
		{"Right Arm",roblox.Vector3.new(1,2,1),roblox.Vector3.new(1.5,0,0)},
		{"Left Leg",roblox.Vector3.new(1,2,1),roblox.Vector3.new(-0.5,-2,0)},
		{"Right Leg",roblox.Vector3.new(1,2,1),roblox.Vector3.new(0.5,-2,0)},
	}
	for _, spec in ipairs(specs) do
		local part = roblox.Instance.new("Part")
		part.Name,part.Size,part.CFrame,part.Parent = spec[1],spec[2],roblox.CFrame.new(spec[3]),rig
	end
	rig.PrimaryPart = rig.HumanoidRootPart
	rig.HumanoidRootPart.AssemblyLinearVelocity = roblox.Vector3.zero
	local humanoid = roblox.Instance.new("Humanoid")
	humanoid.Health,humanoid.Parent = 100,rig
	for _, side in ipairs({"Left","Right"}) do
		local joint = roblox.Instance.new("Motor6D")
		joint.Name,joint.Part0,joint.Part1,joint.Parent = side.." Shoulder",rig.Torso,rig[side.." Arm"],rig.Torso
	end
	return rig
end
local r6Combinations = 0
for _, skin in ipairs(skins) do
	for _, maskId in ipairs(masks) do
		local rig = buildR6()
		expect(Appearance.IsRigReady(rig),"Complete R6 can wear the authored outfits without replacing its joints")
		Appearance.Apply(rig,skin.id,maskId,{trails="trail_cyan"})
		Appearance.ApplyRole(rig,"Hunter")
		audit(rig,false)
		maximum = math.max(maximum,partCount(rig))
		expect(rig:GetAttribute("CatchAppearanceRig")=="R6","R6 fallback is diagnosable in Studio attributes")
		expect(rig.CatchRoleAppearance.HunterCuff:FindFirstChildOfClass("WeldConstraint").Part0.Name:match(" Arm$"),"Hunter cuffs adapt to R6 limbs")
		r6Combinations += 1
		rig:Destroy()
	end
end
expect(r6Combinations==#skins*#masks,"Every skin and mask also serializes on live R6 rigs")
do
	local rig = buildR6()
	Appearance.Apply(rig,"skin_ninja","")
	expect(rig.CatchAppearance.Shin_Left:FindFirstChildOfClass("WeldConstraint").Part0==rig["Left Leg"],"R6 leg shells weld to the actual left leg")
	rig:Destroy()
end

do
	local rig = Appearance.BuildPreview("skin_courier","")
	local outfit, hand = rig.CatchAppearance,rig.LeftHand
	hand.Parent = nil
	expect(not Appearance.IsRigReady(rig) and Appearance.Apply(rig,"skin_golden","")==nil,"Partial R15 spawn is not reported as a completed outfit")
	expect(outfit.Parent==rig,"A partial rig never destroys the last good outfit")
	hand.Parent = rig
	expect(Appearance.IsRigReady(rig) and Appearance.Apply(rig,"skin_golden","")~=nil,"Late body part permits complete outfit recovery")
	expect(rig:GetAttribute("CatchAppearanceVersion")==Appearance.Version and rig:GetAttribute("CatchAppearanceSkinId")=="skin_golden","Visible appearance exposes current version and skin for troubleshooting")
	rig:Destroy()
end

-- The player's OWN avatar survives: face, clothes, hair and color are only changed reversibly.
do
	local rig = Appearance.BuildPreview("skin_courier","")
	rig:SetAttribute("CatchPreview",false)
	for _, part in ipairs(rig:GetChildren()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Size = roblox.Vector3.new(part.Size.X*0.8,part.Size.Y*1.2,part.Size.Z*0.9)
		end
	end
	local hair = roblox.Instance.new("Accessory")
	hair.Name,hair.AccessoryType,hair.Parent = "PlayerHair",roblox.Enum.AccessoryType.Hair,rig
	local hairHandle = roblox.Instance.new("Part")
	hairHandle.Name,hairHandle.Parent = "Handle",hair
	hairHandle.Transparency = 0.25
	local backpack = roblox.Instance.new("Accessory")
	backpack.Name,backpack.AccessoryType,backpack.Parent = "PlayerBack",roblox.Enum.AccessoryType.Back,rig
	local backHandle = roblox.Instance.new("Part")
	backHandle.Name,backHandle.Parent = "Handle",backpack
	local shirt = roblox.Instance.new("Shirt")
	shirt.Parent = rig
	local decal = rig.Head:FindFirstChild("face")
	expect(decal ~= nil and decal.Transparency == 0,"Mannequin has the stock face")
	local headColor, headMaterial = rig.Head.Color, rig.Head.Material
	rig.HumanoidRootPart.Anchored = true -- HeadStart/vault server hold.
	-- A plain overlay changes nothing about the player's own look.
	Appearance.Apply(rig,"skin_courier","mask_kitsune",{trails="trail_sunset"})
	audit(rig,false)
	expect(not rig.CatchAppearance.TrailMount.Anchored,"Equipping a trail during a server hold cannot anchor the avatar")
	expect(hairHandle.Transparency == 0.25 and backHandle.Transparency == 0 and rig.Head.Color == headColor and decal.Transparency == 0 and shirt.Parent == rig,"The untouched look keeps the player's hair, back item, color, face and shirt")
	-- A costume hides hair, hats, back items and classic clothing (so nothing clips); everything is restored on the next apply.
	Appearance.Apply(rig,"skin_pizza","",{})
	expect(hairHandle.Transparency == 1 and hairHandle:GetAttribute("CatchOriginalTransparency") == 0.25,"Costumes hide hair without deleting it")
	expect(backHandle.Transparency == 1 and shirt.Parent ~= rig and hair.Parent == rig and backpack.Parent == rig,"Costumes tuck away back items and clothing instead of destroying them")
	expect(decal.Transparency == 0 and rig.Head.Color == headColor,"The player's own face and skin tone stay visible under a costume")
	Appearance.Apply(rig,"skin_courier","",{})
	expect(hairHandle.Transparency == 0.25 and hairHandle:GetAttribute("CatchOriginalTransparency") == nil and backHandle.Transparency == 0 and shirt.Parent == rig,"Switching back restores the player's hair, back item and shirt exactly")
	-- The gold statue tints limbs and stashes clothes, then restores both.
	Appearance.Apply(rig,"skin_golden","mask_skull",{})
	expect(rig.Head.Color ~= headColor and rig.Head.Material == roblox.Enum.Material.Metal,"Golden Champion tints the body")
	expect(shirt.Parent ~= rig and rig:FindFirstChild("CatchStash") ~= nil,"Golden Champion stashes clothing instead of destroying it")
	expect(decal.Transparency == 0,"The player's own face is still visible on the gold statue")
	Appearance.Apply(rig,"skin_courier","",{})
	expect(rig.Head.Color == headColor and rig.Head.Material == headMaterial and shirt.Parent == rig and rig:FindFirstChild("CatchStash") == nil,"Un-equipping restores color, material and clothing")
	expect(rig:FindFirstChildOfClass("Humanoid") ~= nil,"Character humanoid survives")
	Appearance.Apply(rig,"unknown_skin","unknown_mask")
	expect(rig.CatchAppearance:GetAttribute("SkinId") == "skin_courier" and #rig.CatchAppearance:GetChildren() == 0,"Unknown skins fall back to the untouched avatar")
	expect(rig.Head.Parent == rig,"Unknown masks preserve the live avatar head")
	expect(Appearance.Apply(nil,"skin_shadow","") == nil,"Missing rig is rejected")
	rig:Destroy()
end

-- Previews: the player's real avatar (when available) is cloned, never modified, and wears the same cosmetics.
do
	expect(Appearance.BuildAvatar(nil) == nil,"No description means no real-avatar preview")
	local base = Appearance.BuildMannequin({userId=9})
	local look = Appearance.BuildPreview("skin_dragon","mask_street",{trails=""},{userId=9},base)
	expect(look ~= base and base:FindFirstChild("CatchAppearance") == nil,"Preview clones the base avatar and leaves it untouched")
	expect(look.CatchAppearance:GetAttribute("SkinId") == "skin_dragon" and look:GetAttribute("CatchPreview") == true,"Preview applies the chosen skin to the avatar clone")
	local live = Appearance.BuildPreview("skin_dragon","mask_street",{trails=""},{userId=9})
	local function names(model)
		local list = {}
		for _, part in ipairs(model.CatchAppearance:GetChildren()) do table.insert(list,part.Name) end
		table.sort(list)
		return table.concat(list,"|")
	end
	expect(names(look) == names(live),"Preview geometry matches what a live character receives")
	expect(Appearance.SetMood(look,"Scared") and look:GetAttribute("CatchMood") == "Scared","Mood is a plain attribute and no face is replaced")
	look:Destroy() live:Destroy() base:Destroy()
end

-- Model PivotTo is an engine operation, so the harness supplies its geometric
-- transform only. All Instances, CFrames, property types, and cosmetics are real.
roblox.implementMethod("Model","PivotTo",function(rig, destination)
	local origin = assert(rig.PrimaryPart).CFrame
	local delta = destination*origin:Inverse()
	for _, part in ipairs(rig:GetDescendants()) do
		if part:IsA("BasePart") then part.CFrame = delta*part.CFrame end
	end
end)
-- Detached accessories: a model that was never simulated has accessory handles wherever they were created (hair
-- floating beside the head). Solving the joints puts every handle where its weld says; the audit hides what cannot be placed.
do
	local CF, V3 = roblox.CFrame, roblox.Vector3
	local function accessory(rig, name, kind, partName, c0, c1, size, created)
		local acc = roblox.Instance.new("Accessory")
		acc.Name, acc.AccessoryType = name, kind
		local handle = roblox.Instance.new("Part")
		handle.Name, handle.Size, handle.CFrame, handle.Parent = "Handle", size, created, acc
		local weld = roblox.Instance.new("Weld")
		weld.Name, weld.Part0, weld.Part1, weld.C0, weld.C1, weld.Parent = "AccessoryWeld", rig[partName], handle, c0, c1, handle
		acc.Parent = rig
		return acc, handle
	end
	local function liveAvatar()
		local rig = Appearance.BuildMannequin({userId = 5})
		rig.Name = "LiveAvatar"
		local hairAcc, hair = accessory(rig, "Hair", roblox.Enum.AccessoryType.Hair, "Head", CF.new(0, 0.6, 0), CF.new(0, -0.3, 0), V3.new(1.3, 0.8, 1.3), CF.new(5, 0, 3))
		local _, hat = accessory(rig, "Cap", roblox.Enum.AccessoryType.Hat, "Head", CF.new(0, 0.5, 0), CF.new(0, 0, 0), V3.new(1.2, 0.5, 1.2), CF.new(-4, 8, 0))
		local _, backpack = accessory(rig, "Pack", roblox.Enum.AccessoryType.Back, "UpperTorso", CF.new(0, 0, 0.5), CF.new(0, 0, -0.5), V3.new(1.2, 1.6, 0.6), CF.new(0, -6, 0))
		return rig, hair, hat, backpack
	end
	local rig, hair, hat, backpack = liveAvatar()
	rig:SetAttribute("CatchPreview", nil)
	local expectedHair = rig.Head.CFrame * CF.new(0, 0.6, 0) * CF.new(0, -0.3, 0):Inverse()
	expect((hair.CFrame.Position - expectedHair.Position).Magnitude > 4, "Before solving, the hair really is detached (the bug)")
	local solved = Appearance.SolveRig(rig)
	expect(solved >= 18, "Every joint and accessory weld is solved")
	expect((hair.CFrame.Position - expectedHair.Position).Magnitude < 1e-3, "After solving, the hair sits on the head")
	local expectedHat = rig.Head.CFrame * CF.new(0, 0.5, 0)
	expect((hat.CFrame.Position - expectedHat.Position).Magnitude < 1e-3, "A hat sits on the head")
	expect((backpack.CFrame.Position - (rig.UpperTorso.CFrame * CF.new(0, 0, 0.5) * CF.new(0, 0, -0.5):Inverse()).Position).Magnitude < 1e-3, "A back item sits on the back")
	expect(#Appearance.AuditRig(rig) == 0, "A correctly welded avatar passes the audit")
	-- A handle whose weld is missing cannot be placed: hidden, reported, never shown floating.
	local orphanAcc = roblox.Instance.new("Accessory")
	orphanAcc.Name, orphanAcc.AccessoryType, orphanAcc.Parent = "Orphan", roblox.Enum.AccessoryType.Hair, rig
	local orphan = roblox.Instance.new("Part")
	orphan.Name, orphan.CFrame, orphan.Parent = "Handle", CF.new(40, 0, 0), orphanAcc
	local problems = Appearance.AuditRig(rig)
	expect(#problems == 1 and problems[1]:find("Orphan") and orphan.Transparency == 1 and orphan:GetAttribute("CatchOriginalTransparency") == 0, "An unplaceable accessory is hidden and reported")
	-- A drifted weld is caught too.
	orphanAcc:Destroy()
	hair.CFrame = hair.CFrame * CF.new(3, 0, 0)
	problems = Appearance.AuditRig(rig)
	expect(#problems == 1 and problems[1]:find("Hair") and hair.Transparency == 1, "A drifted accessory is hidden instead of floating")
	rig:Destroy()

	-- From the live character: costume leftovers removed, hair restored, everything solved, anchored and at the origin.
	local live, liveHair = liveAvatar()
	live.Parent = roblox.Instance.new("Folder")
	Appearance.Apply(live, "skin_dragon", "mask_street", {})
	for _, part in ipairs(live:GetChildren()) do if part:IsA("BasePart") then part.Anchored = false end end
	live.HumanoidRootPart.CFrame = CF.new(30, 5, -12)
	local handleBefore = liveHair.Transparency
	local base = Appearance.BuildAvatarFromCharacter(live)
	expect(base ~= nil and base ~= live and base.Name == "CatchAvatarBase", "A clone of the live character becomes the showroom base")
	expect(base:FindFirstChild("CatchAppearance") == nil and base:FindFirstChild("CatchRoleAppearance") == nil, "The live costume is stripped from the base")
	expect(live:FindFirstChild("CatchAppearance") ~= nil and liveHair.Transparency == 1, "The live character is untouched")
	local baseHair = base.Hair.Handle
	expect(baseHair.Transparency == 0, "The player's own hair, hidden under a worn costume, is restored on the base")
	expect((baseHair.CFrame.Position - (base.Head.CFrame * CF.new(0, 0.6, 0) * CF.new(0, -0.3, 0):Inverse()).Position).Magnitude < 1e-3, "The cloned hair sits on the cloned head")
	expect(base.HumanoidRootPart.CFrame.Position.Magnitude < 1e-3 and base:GetAttribute("CatchPreviewReport") == "ok", "The base is at the origin and audited clean")
	for _, part in ipairs(base:GetDescendants()) do
		if part:IsA("BasePart") then expect(part.Anchored, "Every base part is anchored: " .. part.Name) end
	end
	-- Wearing a costume on the base: the hair is hidden for outfit skins, shown for Original You, and follows poses.
	local original = Appearance.BuildPreview("skin_courier", "", {}, {userId = 5}, base)
	expect(original.Hair.Handle.Transparency == 0, "Original You shows the player's own hair in the preview")
	local pv = Poses.Preview(original)
	local relative = original.Head.CFrame:ToObjectSpace(original.Hair.Handle.CFrame)
	pv:Set(Emotes.Sample("emote_flip", 0.7, true), CF.new(2, 3, 1))
	expect((original.Head.CFrame:ToObjectSpace(original.Hair.Handle.CFrame).Position - relative.Position).Magnitude < 1e-3, "The hair stays on the head through a backflip")
	pv:Set(Emotes.Sample("emote_drama", 2.5, true), CF.new())
	expect((original.Head.CFrame:ToObjectSpace(original.Hair.Handle.CFrame).Position - relative.Position).Magnitude < 1e-3, "The hair stays on the head while fainting")
	local costume = Appearance.BuildPreview("skin_dragon", "mask_smile", {}, {userId = 5}, base)
	expect(costume.Hair.Handle.Transparency == 1 and costume.Pack.Handle.Transparency == 1, "Costumes hide the player's hair and back item so nothing clips")
	original:Destroy() costume:Destroy() live:Destroy() base:Destroy()
	expect(Appearance.BuildAvatarFromCharacter(nil) == nil and Appearance.BuildAvatarFromCharacter(roblox.Instance.new("Model")) == nil, "Incomplete characters yield no base")
end

local function signal()
	local listeners = {}
	return {
		Connect=function(_,fn)
			local item = {fn=fn,active=true}
			table.insert(listeners,item)
			return {Disconnect=function() item.active=false end}
		end,
		Fire=function(_,...) for _, item in ipairs(listeners) do if item.active then item.fn(...) end end end,
		Count=function() local count=0 for _, item in ipairs(listeners) do if item.active then count+=1 end end return count end,
	}
end
-- Lune stores real Roblox Instances but does not dispatch engine lifecycle
-- signals. Drive those boundaries explicitly while testing the real service.
local signals = {}
local function event(instance,name)
	signals[instance] = signals[instance] or {}
	signals[instance][name] = signals[instance][name] or signal()
	return signals[instance][name]
end
roblox.implementMethod("Instance","GetAttributeChangedSignal",function(instance,name) return event(instance,"Attribute_"..name) end)
roblox.implementProperty("Instance","ChildAdded",function(instance) return event(instance,"ChildAdded") end)
roblox.implementMethod("ParticleEmitter","Emit",function() end)
roblox.implementMethod("Instance","GetServerTimeNow",function() return 1000 end)
for _, name in ipairs({"CharacterAdded","CharacterRemoving","CharacterAppearanceLoaded"}) do
	roblox.implementProperty("Player",name,function(instance) return event(instance,name) end)
end
do
	local now, phase, notices = 0,"Waiting",{}
	local deferred,spawns,warnings = {},{},{}
	local heartbeat = signal()
	local world = roblox.Instance.new("Folder")
	local shared = {WaitForChild=function(_,name) expect(modules[name] ~= nil,"Service loads shared module "..tostring(name)) return name end}
	local services = {
		Players = {}, RunService = {Heartbeat=heartbeat}, Debris = {AddItem=function() end},
		ReplicatedStorage = {WaitForChild=function(_,name) expect(name=="CatchShared","Service loads correct shared folder") return shared end},
	}
	local env = table.clone(environment)
	env.game = {GetService=function(_,name) return assert(services[name],name) end}
	env.workspace = world
	env.os = {clock=function() return now end}
	env.task = {
		defer=function(fn) table.insert(deferred,fn) end,
		spawn=function(fn) table.insert(spawns,fn) end,
		wait=function(seconds) now += seconds end,
	}
	env.warn = function(message) table.insert(warnings,message) end
	env.require = function(request) return assert(modules[request],"Service requires only production shared modules") end
	local CosmeticService = luau.load(fs.readFile("src/server/Services/CosmeticService.lua"),{environment=env,debugName="CosmeticService"})()
	local player = roblox.Instance.new("Player")
	player.Name,player.DisplayName,player.UserId = "TestHunter","Test Hunter",42
	local rig = Appearance.BuildPreview("skin_courier","")
	rig:SetAttribute("CatchPreview",false)
	for _, part in ipairs(rig:GetChildren()) do if part:IsA("BasePart") then part.Anchored=false end end
	rig.Parent = world
	rig.HumanoidRootPart.AssemblyLinearVelocity = roblox.Vector3.zero
	-- Lune has no derived BasePart.Position/physics synchronization.
	rig.HumanoidRootPart.Position = rig.HumanoidRootPart.CFrame.Position
	rig:FindFirstChildOfClass("Humanoid").Health = 100
	player.Character = rig
	local profile = {owned=Catalog.DefaultOwned(),equipped=table.clone(Catalog.DefaultEquipment)}
	local ctx = {
		Catalog=Catalog,
		Services={DataService={Get=function(_,person) return person==player and profile or nil end},RoundService={Snapshot=function() return {phase=phase} end}},
		Remotes={Notice={FireAllClients=function(_,notice) table.insert(notices,notice) end,FireClient=function(_,_,notice) table.insert(notices,notice) end}},
		World={Podiums={roblox.CFrame.new(0,12,0)}},
	}
	local service = CosmeticService.new(ctx)
	profile.equipped.skins = "skin_ninja"
	expect(service:Apply(player),"Profile applies to live R15 character")
	expect(rig.CatchAppearance:FindFirstChild("HoodShell") == nil and rig.CatchAppearance:GetAttribute("SkinId") == "skin_courier","Unowned skin cannot render on live avatar")
	profile.owned.skin_ninja = true
	expect(service:Apply(player) and rig.CatchAppearance:FindFirstChild("HoodShell"),"Verified skin renders original geometry")
	expect(rig.CatchAppearance:FindFirstChild("CatchNameplate") ~= nil,"Live avatar gets chosen nameplate")
		expect(rig.CatchAppearance.CatchNameplate:FindFirstChild("IdentityBar") ~= nil,"Nameplate carries a per-player identity bar")
		-- A skin chosen mid-round is saved immediately but only applied once the player is out of the round.
		local inRound = true
		ctx.Services.RoundService.IsActive = function() return inRound end
		profile.owned.skin_cyber, profile.equipped.skins = true, "skin_cyber"
		local beforeLook = rig.CatchAppearance
		expect(service:Apply(player) and rig.CatchAppearance == beforeLook and service.pendingLook[player],"Mid-round equip is deferred, not applied")
		expect(notices[#notices].kind == "toast" and notices[#notices].text:find("after this round"),"Player is told when the new look will appear")
		service:_flushPending()
		expect(rig.CatchAppearance == beforeLook,"Pending look waits while the round is active")
		inRound = false
		service:_flushPending()
		expect(rig.CatchAppearance ~= beforeLook and rig.CatchAppearance:FindFirstChild("JetBody") and not service.pendingLook[player],"Pending look applies as soon as the round is over")
		profile.equipped.skins = "skin_ninja"
		service:Apply(player)
	profile.equipped.nameplates = ""
	service:Apply(player)
	expect(rig.CatchAppearance.CatchNameplate:FindFirstChild("Title") == nil,"Unequipping a nameplate hides its title")
	expect(rig.CatchAppearance.CatchNameplate:FindFirstChild("Identity") ~= nil,"Player identity remains visible without a cosmetic title")
	profile.owned.trail_cyan, profile.equipped.trails = true, "trail_cyan"
	service:Apply(player)
	services.Players.GetPlayers = function() return {player} end
	rig:SetAttribute("Sprinting",true)
	rig.HumanoidRootPart.AssemblyLinearVelocity = roblox.Vector3.new(26,0,0)
	service:_updateTrails()
	expect(rig.CatchAppearance.TrailMount.trail_cyan.Enabled,"Sprint trail appears during real movement")
	rig:SetAttribute("RoundFrozen",true)
	service:_updateTrails()
	expect(not rig.CatchAppearance.TrailMount.trail_cyan.Enabled,"Frozen character never emits movement trails")
	rig:SetAttribute("RoundFrozen",false)
	rig:FindFirstChildOfClass("Humanoid").Health=0
	service:_updateTrails()
	expect(not rig.CatchAppearance.TrailMount.trail_cyan.Enabled,"Corpse motion never emits sprint trails")
	rig:FindFirstChildOfClass("Humanoid").Health=100
	rig.HumanoidRootPart.AssemblyLinearVelocity=roblox.Vector3.new(0,50,0)
	service:_updateTrails()
	expect(not rig.CatchAppearance.TrailMount.trail_cyan.Enabled,"Falling or jumping in place never emits sprint trails")
	rig:SetAttribute("Sprinting",false)
	service:_updateTrails()
	expect(not rig.CatchAppearance.TrailMount.trail_cyan.Enabled,"Sprint trail stops when sprint ends")
	rig.HumanoidRootPart.AssemblyLinearVelocity = roblox.Vector3.zero
	local victim = roblox.Instance.new("Player")
	victim.UserId,victim.Character = 77,rig
	service:TagEffect(player,victim)
	expect(notices[#notices].userId==42 and notices[#notices].victimUserId==77,"Tag feedback identifies hunter and actual victim")
	expect(notices[#notices].action=="tag_spark","Tag uses owned default effect")
	profile.owned.tag_bloom,profile.equipped.tagEffects = true,"tag_bloom"
	service:TagEffect(player,rig)
	expect(notices[#notices].action=="tag_bloom" and notices[#notices].victimUserId==nil,"Practice bot supports selected cosmetic effect")
	player:SetAttribute("RoundRole","Hunter")
	service:UpdateRole(player)
	local appearanceFolder = rig.CatchAppearance
	expect(rig:FindFirstChild("CatchRoleAppearance")~=nil and rig:GetAttribute("CatchAppearanceRole")=="Hunter","Service updates actual Hunter role identity")
	player:SetAttribute("RoundRole","Spectator")
	service:UpdateRole(player)
	expect(not rig:FindFirstChild("CatchRoleAppearance") and rig.CatchAppearance==appearanceFolder,"Elimination removes Hunter cues without losing equipped outfit")
	local savedProfile = profile
	profile = nil
	rig.CatchAppearance:Destroy()
	expect(not service:Apply(player) and rig.CatchAppearance:FindFirstChild("HoodShell") == nil and rig.CatchAppearance:GetAttribute("SkinId") == "skin_courier","Slow profile loads show the free look without granting premium ownership")
	local loadingOutfit = rig.CatchAppearance
	service:Apply(player)
	expect(rig.CatchAppearance==loadingOutfit,"Loading retry preserves the existing free outfit")
	local lateAccessory = roblox.Instance.new("Accessory")
	local handle = roblox.Instance.new("Part")
	handle.Name,handle.Parent,lateAccessory.Parent = "Handle",lateAccessory,rig
	local colors = roblox.Instance.new("BodyColors")
	colors.Parent = rig
	service:Apply(player,true)
	expect(handle.Transparency==0,"Late accessories refresh and the avatar keeps its own accessories while the profile loads")
	profile = savedProfile
	expect(service:Apply(player) and rig.CatchAppearance:FindFirstChild("HoodShell"),"Verified saved outfit replaces temporary free outfit")
	expect(service:Emote(player,"emote_wave"),"Owned emote starts in the lobby")
	expect(rig:GetAttribute("CatchEmote")=="emote_wave" and rig:GetAttribute("CatchEmoting")==true and type(rig:GetAttribute("CatchEmoteAt"))=="number","The server announces an emote with replicated attributes")
	expect(not service:Emote(player,"emote_wave"),"Emote spam respects cooldown")
	now = 0.3
	heartbeat:Fire(0.2)
	expect(rig:GetAttribute("CatchEmote")=="emote_wave","A running emote keeps going while the player stands still in the lobby")
	phase = "Active"
	heartbeat:Fire(0.2)
	expect(rig:GetAttribute("CatchEmote")==nil and not rig:GetAttribute("CatchEmoting"),"Round start stops the emote and clears the announcement")
	expect(heartbeat.Count()==0,"Stopped emote releases its Heartbeat listener")
	expect(not service:Emote(player,"emote_wave"),"Competitive play cannot emote")
	phase,now = "Waiting",5
	expect(not service:Emote(player,"emote_dance"),"Unowned emote cannot play")
	profile.owned.emote_dance = true
	expect(service:Emote(player,"emote_dance") and rig:GetAttribute("CatchEmote")=="emote_dance","Any owned emote can be played, not only the equipped one")
	now = 5.4
	rig.HumanoidRootPart.AssemblyLinearVelocity = roblox.Vector3.new(5,0,0)
	heartbeat:Fire(0.2)
	expect(rig:GetAttribute("CatchEmote")==nil and heartbeat.Count()==0,"Moving stops the emote")
	rig.HumanoidRootPart.AssemblyLinearVelocity = roblox.Vector3.zero
	now = 8
	expect(not service:Emote(player,"victory_wave") and not service:Emote(player,"skin_ninja") and not service:Emote(player,"emote_missing") and not service:Emote(player,42),"Victories, other items and unknown or malformed ids are not emotes")
	now = 12
	profile.owned.emote_flip = true
	expect(service:Emote(player,"emote_flip"),"A one-shot emote starts")
	now = 12 + Emotes.Duration("emote_flip") + 0.2
	heartbeat:Fire(0.2)
	expect(rig:GetAttribute("CatchEmote")==nil,"A one-shot emote ends after its duration")
	for _, victory in ipairs({"victory_wave","victory_spin"}) do
		profile.owned[victory],profile.equipped.victories = true,victory
		service:ShowWinners({player,player})
		expect(#spawns==1,"Winner count is bounded by available podiums")
		table.remove(spawns,1)()
		expect(#service.podiums:GetChildren()==1,"Winner appears on the podium once built")
		local winner = service.podiums:GetChildren()[1]
		expect(winner.HumanoidRootPart.CFrame.Position == ctx.World.Podiums[1].Position,"Winner stands on the configured podium")
		expect(winner.RightHand.CFrame.Position.Y>winner.UpperTorso.CFrame.Position.Y,"Victory pose visibly raises arm")
		local hand = winner.RightHand.CFrame
		now += 0.5
		heartbeat:Fire()
		expect(winner.RightHand.CFrame~=hand,"Both victory salute and spin animate")
		local costume
			for _, piece in ipairs(winner.CatchAppearance:GetChildren()) do
				local weld = piece:IsA("BasePart") and piece:FindFirstChildOfClass("WeldConstraint")
				if weld and weld.Part0 == winner.RightLowerArm then costume = piece break end
			end
			expect(costume ~= nil,"Winner outfit has a piece on the animated forearm")
		expect((costume.CFrame.Position-winner.RightLowerArm.CFrame.Position).Magnitude<1.2,"Anchored costume follows animated arm")
		audit(winner,true)
		local old = service.podiums
		service:ShowWinners({})
		expect(old.Parent==nil and service.podiums==nil and heartbeat.Count()==0,"Next round removes podium models and animation listeners")
	end
	local r6 = buildR6()
	r6.Parent,player.Character = world,r6
	phase,now = "Waiting",20
	expect(service:Apply(player) and service:Emote(player,"emote_wave"),"R6 fallback supports an owned outfit and announces emotes")
	service:_stopEmote(player)
	expect(heartbeat.Count()==0 and r6:GetAttribute("CatchEmote")==nil,"R6 emote cleanup releases its listener")
	-- A spawn that completes after the retry window must recover from the last
	-- arriving Humanoid, including a slow profile read and a later respawn.
	player.Parent = world
	local lateHumanoid = r6:FindFirstChildOfClass("Humanoid")
	lateHumanoid.Parent = nil
	r6.CatchAppearance:Destroy()
	profile = nil
	service:_watchPlayer(player)
	expect(#spawns==1,"One bounded initial appearance retry loop starts per character")
	table.remove(spawns,1)()
	expect(#warnings==1 and not r6:FindFirstChild("CatchAppearance"),"Incomplete rig expires without constructing a partial outfit")
	lateHumanoid.Parent = r6
	r6.ChildAdded:Fire(lateHumanoid)
	local lateColors = roblox.Instance.new("BodyColors")
	lateColors.Parent = r6
	r6.ChildAdded:Fire(lateColors)
	expect(#deferred==1,"One deferred refresh coalesces late spawn instances")
	table.remove(deferred,1)()
	expect(r6:FindFirstChild("CatchAppearance") and r6.CatchAppearance:FindFirstChild("HoodShell") == nil,"Humanoid arriving after deadline restores the free look while data remains pending")
	profile = savedProfile
	service:Apply(player)
	expect(r6.CatchAppearance:FindFirstChild("HoodShell")~=nil,"Late profile restores owned equipment after spawn recovery")
	player:SetAttribute("RoundRole","Hunter")
	player:GetAttributeChangedSignal("RoundRole"):Fire()
	expect(r6:FindFirstChild("CatchRoleAppearance")~=nil,"Actual subscribed role signal applies Hunter identity")
	local accessoryAfterDeadline = roblox.Instance.new("Accessory")
	accessoryAfterDeadline.Parent = r6
	r6.ChildAdded:Fire(accessoryAfterDeadline)
	local priorOutfit = r6.CatchAppearance
	player.CharacterRemoving:Fire(r6)
	expect(r6.ChildAdded:Count()==0 and r6:GetAttributeChangedSignal("RoundRole"):Count()==0,"Respawn disconnects old rig lifecycle listeners")
	local replacement = Appearance.BuildPreview("skin_courier","")
	replacement:SetAttribute("CatchPreview",false)
	for _, part in ipairs(replacement:GetChildren()) do if part:IsA("BasePart") then part.Anchored=false end end
	replacement.Parent,player.Character = world,replacement
	player.CharacterAdded:Fire(replacement)
	table.remove(deferred,1)()
	expect(r6.CatchAppearance==priorOutfit,"A queued refresh cannot modify a previous character after respawn")
	table.remove(spawns,1)()
	expect(replacement.CatchAppearance:FindFirstChild("HoodShell") and replacement:FindFirstChild("CatchRoleAppearance"),"Respawn reapplies owned skin and current role to the new avatar")
	services.Players.PlayerAdded,services.Players.PlayerRemoving = signal(),signal()
	service:Start()
	expect(player.CharacterAdded:Count()==1 and replacement.ChildAdded:Count()==1,"Starting twice cannot duplicate player and character watchers")
	service:Start()
	services.Players.PlayerRemoving:Fire(player)
	expect(player.CharacterAdded:Count()==0 and replacement.ChildAdded:Count()==0,"Disconnect releases all player and character lifecycle listeners")
	world:Destroy()
	player:Destroy()
	victim:Destroy()
end
print("Appearance tests passed: "..checks.." checks, "..combinations.." preview/live R15 combinations, "..r6Combinations.." live R6 combinations, maximum "..maximum.." avatar parts including Hunter identity")
