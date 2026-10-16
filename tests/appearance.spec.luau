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
				expect(weld and weld.Part0 and weld.Part0.Parent == rig and weld.Part1 == item, "Attachment is welded to an R15 body part")
			end
		end
	end
	expect(partCount(rig) <= 100, "Preview and costume stay within the 100-part avatar budget")
	expect(#rig:GetDescendants() <= 240, "Avatar descendants remain bounded")
	-- This exercises Roblox serializer reflection in addition to Luau's constructor API.
	local serialized = roblox.serializeModel({rig})
	expect(#serialized > 0, "Avatar serializes as a valid Roblox model")
	local restored = roblox.deserializeModel(serialized)
	expect(partCount(restored[1]) == partCount(rig), "Serialized avatar retains all geometry")
	restored[1]:Destroy()
end

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
		rig:Destroy()
	end
end
expect(combinations == 42,"All seven skins with all five masks and no mask were instantiated")

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
	Appearance.Apply(rig,"skin_shadow","mask_kitsune",{trails="trail_sunset"})
	audit(rig,false)
	expect(not rig.CatchAppearance.TrailMount.Anchored,"Equipping a trail during a server hold cannot anchor the avatar")
	rig.HumanoidRootPart.Anchored = false
	expect(accessory.Parent == rig and handle.Transparency == 1,"Player accessories are hidden without deletion")
	Appearance.Apply(rig,"skin_golden","mask_skull",{trails=""})
	expect(handle:GetAttribute("CatchOriginalTransparency") == 0.25,"Repeated appearance changes preserve original accessory metadata")
	expect(rig.Head.Color == roblox.Color3.fromRGB(180,131,93),"Switching outfits updates exposed skin color")
	expect(rig:FindFirstChildOfClass("Humanoid") ~= nil,"Character humanoid survives")
	Appearance.Apply(rig,"unknown_skin","unknown_mask")
	expect(rig.CatchAppearance:FindFirstChild("DispatchSatchel") ~= nil,"Unknown skins use safe courier fallback")
	expect(rig.Head.Parent == rig,"Unknown masks preserve the live avatar head")
	expect(Appearance.CreatePreviewPose(rig,"victory_wave") == nil,"Podium poses reject live unanchored body parts")
	expect(Appearance.Apply(nil,"skin_shadow","") == nil,"Missing rig is rejected")
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
do
	local now, phase, notices = 0,"Waiting",{}
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
	env.require = function(request) expect(request==module,"Only production appearance dependency is replaced") return Appearance end
	local CosmeticService = luau.load(fs.readFile("src/server/Services/CosmeticService.lua"),{environment=env,debugName="CosmeticService"})()
	local player = roblox.Instance.new("Player")
	player.Name,player.DisplayName,player.UserId = "TestHunter","Test Hunter",42
	local rig = Appearance.BuildPreview("skin_courier","")
	rig:SetAttribute("CatchPreview",false)
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
	profile.equipped.skins = "skin_shadow"
	expect(service:Apply(player),"Profile applies to live R15 character")
	expect(rig.CatchAppearance:FindFirstChild("DispatchSatchel") ~= nil,"Unowned skin cannot render on live avatar")
	profile.owned.skin_shadow = true
	expect(service:Apply(player) and rig.CatchAppearance:FindFirstChild("HoodCrown"),"Verified skin renders original geometry")
	expect(rig.CatchAppearance:FindFirstChild("CatchNameplate") ~= nil,"Live avatar gets chosen nameplate")
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
		local costume = winner.CatchAppearance:FindFirstChild("Tailored_RightLowerArm")
		expect((costume.CFrame.Position-winner.RightLowerArm.CFrame.Position).Magnitude<0.001,"Anchored costume follows animated arm")
		audit(winner,true)
		local old = service.podiums
		service:ShowWinners({})
		expect(old.Parent==nil and service.podiums==nil and heartbeat.Count()==0,"Next round removes podium models and animation listeners")
	end
	world:Destroy()
	player:Destroy()
	victim:Destroy()
end
print("Appearance tests passed: "..checks.." checks, "..combinations.." combinations, maximum "..maximum.." avatar parts")
