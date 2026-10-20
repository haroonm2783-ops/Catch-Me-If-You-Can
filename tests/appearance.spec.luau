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
local Appearance = luau.load(fs.readFile("src/shared/Appearance.lua"), {environment=environment,debugName="Appearance"})()
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
	expect(partCount(rig) <= 150, "Preview and costume stay within the 150-part avatar budget")
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
for _, id in ipairs(Appearance.ToneOrder) do expect(Catalog.Get(id) and Catalog.Get(id).category == "tones", "Tone is selectable: "..id) end
for _, id in ipairs(Appearance.HairOrder) do expect(Catalog.Get(id) and Catalog.Get(id).category == "hairColors", "Hair color is selectable: "..id) end
local skins, masks = Catalog.ForCategory("skins"), {""}
for _, item in ipairs(Catalog.ForCategory("masks")) do table.insert(masks,item.id) end
local signatures, combinations, maximum = {}, 0, 0
for _, skin in ipairs(skins) do
	for _, mask in ipairs(masks) do
		local rig = Appearance.BuildPreview(skin.id,mask,{trails="trail_cyan"})
		audit(rig,true)
		maximum = math.max(maximum,partCount(rig))
		combinations += 1
		if mask == "" then
			local names = {}
			for _, part in ipairs(rig.CatchAppearance:GetChildren()) do if part:IsA("BasePart") then table.insert(names,part.Name) end end
			table.sort(names)
			local signature = table.concat(names,"|")
			expect(not signatures[signature],"Each skin has a distinct geometry silhouette")
			signatures[signature] = true
		end
		local motorCount = 0
		for _, item in ipairs(rig:GetDescendants()) do if item:IsA("Motor6D") then motorCount += 1 end end
		local initial = partCount(rig)
		Appearance.Apply(rig,skin.id,mask,{trails="trail_sunset"})
		local afterFirst = partCount(rig)
		expect(afterFirst == initial,"Reapplying preserves preview face and total geometry")
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
		expect(not rig.CatchAppearance.trail_sunset.Enabled,"Anchored head start never shows a live sprint trail")
		local outfit = rig.CatchAppearance
		local roleFolder = rig.CatchRoleAppearance
		for _, item in ipairs(roleFolder:GetChildren()) do
			if item:IsA("BasePart") then
				expect(not item.Anchored and item.Massless and not item.CanQuery and not item.CanCollide,"Hunter identity cannot freeze or block live movement")
			end
		end
		Appearance.ApplyRole(rig,"Hunter")
		expect(roleFolder.Parent==nil and rig.CatchAppearance==outfit,"Reapplying team identity never duplicates cuffs or replaces paid outfits")
		Appearance.ApplyRole(rig,"Runner")
		expect(not rig:FindFirstChild("CatchRoleAppearance") and rig.CatchAppearance==outfit,"Runner transition removes Hunter identity while preserving cosmetics")
		rig:Destroy()
	end
end
expect(combinations == #skins*#masks and #skins >= 8 and #masks >= 9,"Every launch skin with every mask and no mask was instantiated")

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
		expect(rig.CatchAppearance.ShoeSole_Left:FindFirstChildOfClass("WeldConstraint").Part0==rig["Left Leg"],"R6 shoes weld to the actual left leg")
		expect(rig.CatchAppearance.ShoeSole_Left.CFrame.Position.Y < -2.7,"R6 sneakers sit at foot level rather than leg center")
		expect(rig.CatchRoleAppearance.HunterSignalCuff:FindFirstChildOfClass("WeldConstraint").Part0.Name:match(" Arm$"),"Hunter cuffs adapt to R6 limbs")
		r6Combinations += 1
		rig:Destroy()
	end
end
expect(r6Combinations==#skins*#masks,"Every skin and mask also serializes on live R6 rigs")

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

-- Representative scaled live avatar: its body, joints, and accessories must survive.
do
	local rig = Appearance.BuildPreview("skin_courier","")
	rig:SetAttribute("CatchPreview",false)
	for _, part in ipairs(rig:GetChildren()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Size = roblox.Vector3.new(part.Size.X*0.8,part.Size.Y*1.2,part.Size.Z*0.9)
		end
	end
	local accessory = roblox.Instance.new("Accessory")
	accessory.Name,accessory.Parent = "PlayerAccessory",rig
	local handle = roblox.Instance.new("Part")
	handle.Name,handle.Parent = "Handle",accessory
	handle.Transparency = 0.25
	rig.HumanoidRootPart.Anchored = true -- HeadStart/vault server hold.
	Appearance.Apply(rig,"skin_ninja","mask_kitsune",{trails="trail_sunset"})
	audit(rig,false)
	expect(not rig.CatchAppearance.TrailMount.Anchored,"Equipping a trail during a server hold cannot anchor the avatar")
	rig.HumanoidRootPart.Anchored = false
	expect(accessory.Parent == rig and handle.Transparency == 1,"Player accessories are hidden without deletion")
	Appearance.Apply(rig,"skin_golden","mask_skull",{trails=""})
	expect(handle:GetAttribute("CatchOriginalTransparency") == 0.25,"Repeated appearance changes preserve original accessory metadata")
	expect(rig.Head.Color == Appearance.Tones.tone_porcelain,"Switching outfits keeps the stable identity skin tone")
	expect(rig:FindFirstChildOfClass("Humanoid") ~= nil,"Character humanoid survives")
	Appearance.Apply(rig,"unknown_skin","unknown_mask")
	expect(rig.CatchAppearance:FindFirstChild("CapCrown") ~= nil,"Unknown skins use safe courier fallback")
	expect(rig.Head.Parent == rig,"Unknown masks preserve the live avatar head")
	expect(Appearance.CreatePreviewPose(rig,"victory_wave") == nil,"Podium poses reject live unanchored body parts")
	expect(Appearance.Apply(nil,"skin_shadow","") == nil,"Missing rig is rejected")
	rig:Destroy()
end

-- Faces, moods and personalization.
do
	local rig = Appearance.BuildPreview("skin_courier","",{hairColors="hair_pink",tones="tone_cocoa"},{userId=7})
	local folder = rig.CatchAppearance
	local expressions, visibleBefore = {}, 0
	for _, part in ipairs(folder:GetChildren()) do
		local expr = part:IsA("BasePart") and part:GetAttribute("CatchExpr")
		if expr then expressions[expr] = (expressions[expr] or 0) + 1 end
	end
	for _, name in ipairs({"smile","determined","grin","scared","joy","sad"}) do expect(expressions[name] and expressions[name] >= 1,"Expression geometry exists: "..name) end
	expect(folder.EyeWhite_Left ~= nil and folder.EyeIris_Right ~= nil,"Characters have real eyes")
	expect(rig.Head.Color == Appearance.Tones.tone_cocoa,"Chosen skin tone applies to the head")
	expect(folder.BackHair.Color == Appearance.HairColors.hair_pink,"Chosen hair color overrides outfit hair")
	for _, mood in ipairs({"Idle","Run","Hunt","Scared","Hide","Win","Lose"}) do
		expect(Appearance.SetMood(rig,mood),"Mood is accepted: "..mood)
		local wanted = Appearance.Moods[mood]
		local shown = 0
		for _, part in ipairs(folder:GetChildren()) do
			local expr = part:IsA("BasePart") and part:GetAttribute("CatchExpr")
			if expr then
				expect((part.Transparency == 0) == (expr == wanted),"Only the "..wanted.." expression is visible in mood "..mood)
				if part.Transparency == 0 then shown += 1 end
			end
		end
		expect(shown >= 1,"Each mood shows face geometry")
	end
	-- Reapplying keeps the current mood instead of resetting the face.
	Appearance.SetMood(rig,"Scared")
	Appearance.Apply(rig,"skin_courier","",{},{userId=7})
	expect(rig.CatchAppearance:GetAttribute("CatchMood") == "Scared","Outfit changes preserve the current mood")
	-- Masks hide only the face they cover.
	local function faceParts(maskId)
		local r = Appearance.BuildPreview("skin_courier",maskId,{},{userId=7})
		local f = r.CatchAppearance
		local result = {eyes = f:FindFirstChild("EyeWhite_Left") ~= nil, mouth = f:FindFirstChild("Mouth_smile") ~= nil}
		r:Destroy()
		return result
	end
	expect(faceParts("").eyes and faceParts("").mouth,"No mask shows the whole face")
	expect(faceParts("mask_street").eyes and not faceParts("mask_street").mouth,"Lower-face masks keep eyes and hide the mouth")
	expect(not faceParts("mask_visor").eyes and faceParts("mask_visor").mouth,"Visors hide eyes but keep the mouth")
	expect(not faceParts("mask_phantom").eyes and not faceParts("mask_phantom").mouth,"Full masks replace the face")
	-- The stock decal face is hidden but never destroyed.
	local live = Appearance.BuildPreview("skin_courier","")
	live:SetAttribute("CatchPreview",false)
	for _, part in ipairs(live:GetChildren()) do if part:IsA("BasePart") then part.Anchored = false end end
	local decal = roblox.Instance.new("Decal")
	decal.Name,decal.Transparency,decal.Parent = "face",0,live.Head
	Appearance.Apply(live,"skin_cyber","")
	expect(decal.Parent == live.Head and decal.Transparency == 1 and decal:GetAttribute("CatchOriginalTransparency") == 0,"Stock face decal is hidden, not deleted")
	live:Destroy()
	rig:Destroy()
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
for _, name in ipairs({"CharacterAdded","CharacterRemoving","CharacterAppearanceLoaded"}) do
	roblox.implementProperty("Player",name,function(instance) return event(instance,name) end)
end
do
	local now, phase, notices = 0,"Waiting",{}
	local deferred,spawns,warnings = {},{},{}
	local heartbeat = signal()
	local world = roblox.Instance.new("Folder")
	local module = {}
	local shared = {WaitForChild=function(_,name) expect(name=="Appearance","Service loads shared appearance module") return module end}
	local services = {
		Players = {}, RunService = {Heartbeat=heartbeat},
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
	env.require = function(request) expect(request==module,"Only production appearance dependency is replaced") return Appearance end
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
	expect(rig.CatchAppearance:FindFirstChild("CapCrown") ~= nil,"Unowned skin cannot render on live avatar")
	profile.owned.skin_ninja = true
	expect(service:Apply(player) and rig.CatchAppearance:FindFirstChild("Topknot"),"Verified skin renders original geometry")
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
		expect(rig.CatchAppearance ~= beforeLook and rig.CatchAppearance:FindFirstChild("CoreGlow") and not service.pendingLook[player],"Pending look applies as soon as the round is over")
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
	expect(rig.CatchAppearance.trail_cyan.Enabled,"Sprint trail appears during real movement")
	rig:SetAttribute("RoundFrozen",true)
	service:_updateTrails()
	expect(not rig.CatchAppearance.trail_cyan.Enabled,"Frozen character never emits movement trails")
	rig:SetAttribute("RoundFrozen",false)
	rig:FindFirstChildOfClass("Humanoid").Health=0
	service:_updateTrails()
	expect(not rig.CatchAppearance.trail_cyan.Enabled,"Corpse motion never emits sprint trails")
	rig:FindFirstChildOfClass("Humanoid").Health=100
	rig.HumanoidRootPart.AssemblyLinearVelocity=roblox.Vector3.new(0,50,0)
	service:_updateTrails()
	expect(not rig.CatchAppearance.trail_cyan.Enabled,"Falling or jumping in place never emits sprint trails")
	rig:SetAttribute("Sprinting",false)
	service:_updateTrails()
	expect(not rig.CatchAppearance.trail_cyan.Enabled,"Sprint trail stops when sprint ends")
	rig.HumanoidRootPart.AssemblyLinearVelocity = roblox.Vector3.zero
	expect(Appearance.CreatePreviewPose(rig,"victory_wave") == nil,"Podium poses reject ordinary live characters")
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
	expect(not service:Apply(player) and rig.CatchAppearance:FindFirstChild("CapCrown"),"Slow profile loads show the free outfit without granting premium ownership")
	local loadingOutfit = rig.CatchAppearance
	service:Apply(player)
	expect(rig.CatchAppearance==loadingOutfit,"Loading retry preserves the existing free outfit")
	local lateAccessory = roblox.Instance.new("Accessory")
	local handle = roblox.Instance.new("Part")
	handle.Name,handle.Parent,lateAccessory.Parent = "Handle",lateAccessory,rig
	local colors = roblox.Instance.new("BodyColors")
	colors.Parent = rig
	service:Apply(player,true)
	expect(handle.Transparency==1 and colors.HeadColor3==rig.Head.Color,"Late accessories and BodyColors refresh even while profile loading")
	profile = savedProfile
	expect(service:Apply(player) and rig.CatchAppearance:FindFirstChild("Topknot"),"Verified saved outfit replaces temporary free outfit")
	local shoulder = rig.UpperTorso:FindFirstChild("RightShoulder")
	local rest = shoulder.C0
	expect(service:Emote(player,"emote_wave"),"Owned equipped emote starts in lobby")
	expect(not service:Emote(player,"emote_wave"),"Emote spam respects cooldown")
	now = 0.3
	heartbeat:Fire()
	expect(shoulder.C0 ~= rest and rig:GetAttribute("CatchEmoting"),"Wave changes the R15 shoulder and marks emote state")
	phase = "Active"
	heartbeat:Fire()
	expect(shoulder.C0 == rest and not rig:GetAttribute("CatchEmoting"),"Round start restores original joints and stops emote")
	expect(heartbeat.Count()==0,"Stopped emote releases Heartbeat listener")
	expect(not service:Emote(player,"emote_wave"),"Competitive play cannot emote")
	phase,now = "Waiting",5
	expect(not service:Emote(player,"emote_dance"),"Unowned emote cannot play")
	profile.owned.emote_dance,profile.equipped.emotes = true,"emote_dance"
	expect(service:Emote(player,"emote_dance"),"Owned equipped dance starts")
	now = 5.4
	heartbeat:Fire()
	rig.HumanoidRootPart.AssemblyLinearVelocity = roblox.Vector3.new(5,0,0)
	heartbeat:Fire()
	expect(shoulder.C0==rest and heartbeat.Count()==0,"Moving stops emote and restores joints")
	for _, victory in ipairs({"victory_wave","victory_spin"}) do
		profile.owned[victory],profile.equipped.victories = true,victory
		service:ShowWinners({player,player})
		expect(#service.podiums:GetChildren()==1,"Winner count is bounded by available podiums")
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
	phase,now = "Waiting",15
	profile.equipped.emotes = "emote_wave"
	local r6Shoulder = r6.Torso:FindFirstChild("Right Shoulder")
	local original = r6Shoulder.C0
	expect(service:Apply(player) and service:Emote(player,"emote_wave"),"R6 fallback supports owned outfit and wave emote")
	now += 0.4
	heartbeat:Fire()
	expect(r6Shoulder.C0~=original,"R6 shoulder naming is supported by visible emote feedback")
	service:_stopEmote(player)
	expect(r6Shoulder.C0==original and heartbeat.Count()==0,"R6 emote restores joint and disconnects on cleanup")
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
	expect(r6:FindFirstChild("CatchAppearance") and r6.CatchAppearance:FindFirstChild("CapCrown"),"Humanoid arriving after deadline restores free outfit while data remains pending")
	profile = savedProfile
	service:Apply(player)
	expect(r6.CatchAppearance:FindFirstChild("Topknot")~=nil,"Late profile restores owned equipment after spawn recovery")
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
	expect(replacement.CatchAppearance:FindFirstChild("Topknot") and replacement:FindFirstChild("CatchRoleAppearance"),"Respawn reapplies owned skin and current role to the new avatar")
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
