local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local shared = ReplicatedStorage:WaitForChild("CatchShared")
local Appearance = require(shared:WaitForChild("Appearance"))
local Emotes = require(shared:WaitForChild("Emotes"))
local Poses = require(shared:WaitForChild("Poses"))
local Trails = require(shared:WaitForChild("Trails"))

local CosmeticService = {}
CosmeticService.__index = CosmeticService

local function plateStyle(catalog, plateId)
	local item = catalog and (catalog.Get(plateId) or catalog.Get("name_rookie"))
	local rgb = item and item.accent or {160,189,210}
	return {label = item and item.name or "MALL NEWCOMER", color = Color3.fromRGB(rgb[1],rgb[2],rgb[3])}
end

local function text(parent, name, value, size, position, color, bold)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size, label.Position = size,position
	label.Text = value
	label.FontFace = Font.fromEnum(bold and Enum.Font.GothamBold or Enum.Font.GothamMedium)
	label.TextSize = bold and 15 or 10
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(12,17,28)
	label.TextStrokeTransparency = 0.35
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Parent = parent
	return label
end

local function nameplate(folder, rig, displayName, plateId, title, catalog, userId)
	local head = rig:FindFirstChild("Head")
	if not head then return end
	local style = plateStyle(catalog, plateId)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CatchNameplate"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(200,52)
	gui.StudsOffset = Vector3.new(0,1.65,0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 70
	gui.Parent = folder
	text(gui,"Identity",displayName,UDim2.fromScale(1,0.55),UDim2.fromScale(0,0),Color3.fromRGB(255,255,255),true)
	-- A per-player identity bar keeps every runner recognizable whatever they wear.
	local bar = Instance.new("Frame")
	bar.Name = "IdentityBar"
	bar.BackgroundColor3 = Appearance.IdentityColor(userId)
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0.5,0)
	bar.Position = UDim2.fromScale(0.5,0.56)
	bar.Size = UDim2.fromOffset(46,3)
	bar.Parent = gui
	if title or plateId ~= "" then
		text(gui,"Title",title or style.label,UDim2.fromScale(1,0.38),UDim2.fromScale(0,0.62),style.color,false)
	end
end

local function ownedEquipment(ctx, profile)
	local result = {}
	for category, fallback in pairs(ctx.Catalog.DefaultEquipment) do
		local id = profile.equipped and profile.equipped[category] or fallback
		local item = ctx.Catalog.Get(id)
		if id == "" then
			result[category] = ""
		elseif item and item.category == category and profile.owned and profile.owned[id] then
			result[category] = id
		else
			result[category] = fallback
		end
	end
	return result
end

function CosmeticService.new(ctx)
	return setmetatable({ctx=ctx, connections={}, playerConnections={}, characterConnections={}, emotes={}, lastEmote={}, podiums=nil, podiumSpin=nil, pendingLook={}, moodClock=0},CosmeticService)
end

function CosmeticService:_inRound(player)
	local round = self.ctx.Services.RoundService
	return round ~= nil and round.IsActive ~= nil and round:IsActive(player) == true
end

function CosmeticService:Apply(player, refreshLoadingAppearance, force)
	local data = self.ctx.Services.DataService
	local profile = data and data:Get(player)
	local rig = player.Character
	if not Appearance.IsRigReady(rig) then return false end
	-- A slow profile read should not expose an unfinished avatar. Render the free
	-- outfit once while loading; DataService reapplies verified owned items on load.
	if not profile and not refreshLoadingAppearance and rig:FindFirstChild("CatchAppearance")
		and rig:GetAttribute("CatchAppearanceVersion") == Appearance.Version then return false end
	-- Never change a participant's silhouette mid-chase: the choice is saved at once but the
	-- new look is applied when they are next out of the round (results, lobby, or respawn).
	if profile and not force and rig:FindFirstChild("CatchAppearance") and self:_inRound(player) then
		if not self.pendingLook[player] then
			self.pendingLook[player] = true
			self.ctx.Remotes.Notice:FireClient(player,{kind="toast",text="Saved! Your new look appears after this round."})
		end
		return true
	end
	self.pendingLook[player] = nil
	local equipped = profile and ownedEquipment(self.ctx,profile) or self.ctx.Catalog.DefaultEquipment
	local previousSkin = rig:GetAttribute("CatchAppearanceSkinId")
	local folder = Appearance.Apply(rig,equipped.skins,equipped.masks,equipped,{userId=player.UserId})
	if not folder then return false end
	if profile and previousSkin ~= nil and previousSkin ~= equipped.skins then self:_celebrate(rig,equipped.skins) end
	nameplate(folder,rig,player.DisplayName,equipped.nameplates,nil,self.ctx.Catalog,player.UserId)
	Appearance.ApplyRole(rig,player:GetAttribute("RoundRole") or rig:GetAttribute("RoundRole") or "Lobby")
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	return profile ~= nil
end

-- A short rarity-colored sparkle burst when a better look is equipped. Cosmetic only and capped to one emitter.
local BURST = {Rare={count=14,color=Color3.fromRGB(90,180,255)},Epic={count=24,color=Color3.fromRGB(200,120,255)},Legendary={count=40,color=Color3.fromRGB(255,205,70)}}
function CosmeticService:_celebrate(rig,skinId)
	local item = self.ctx.Catalog.Get(skinId)
	local style = item and BURST[item.rarity]
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not style or not root then return end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "CatchEquipBurst"
	emitter.Color = ColorSequence.new(style.color,Color3.fromRGB(255,255,255))
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Lifetime = NumberRange.new(0.7,1.2)
	emitter.Speed = NumberRange.new(8,15)
	emitter.SpreadAngle = Vector2.new(180,180)
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,0.9),NumberSequenceKeypoint.new(1,0)})
	emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)})
	emitter.LightEmission = 0.6
	emitter.Rate = 0
	emitter.Parent = root
	emitter:Emit(style.count)
	game:GetService("Debris"):AddItem(emitter,1.6)
end

function CosmeticService:UpdateRole(player)
	local rig = player.Character
	if rig and rig:FindFirstChild("CatchAppearance") then
		local role = player:GetAttribute("RoundRole") or rig:GetAttribute("RoundRole") or "Lobby"
		if rig:GetAttribute("CatchAppearanceRole") ~= role then Appearance.ApplyRole(rig,role) end
	end
end

function CosmeticService:Preview(rig, skinId, maskId, extra)
	return Appearance.Apply(rig,skinId,maskId,extra)
end

function CosmeticService:TagEffect(hunter, target)
	local profile = self.ctx.Services.DataService:Get(hunter)
	local rig = target and (target:IsA("Player") and target.Character or target)
	local root = rig and rig:FindFirstChild("HumanoidRootPart")
	if not profile or not root then return end
	local equipped = ownedEquipment(self.ctx,profile)
	self.ctx.Remotes.Notice:FireAllClients({kind="tag",position=root.Position,userId=hunter.UserId,
		victimUserId=target:IsA("Player") and target.UserId or nil,action=equipped.tagEffects or "tag_spark"})
end

-- Emotes are procedural poses (Emotes.lua). The server only validates and announces them with two replicated
-- attributes on the character; every client then plays the pose locally on that character's joints (EmoteController).
function CosmeticService:_stopEmote(player)
	local current = self.emotes[player]
	if not current then return end
	self.emotes[player] = nil
	if current.connection then current.connection:Disconnect() end
	local character = current.character
	if character.Parent then
		character:SetAttribute("CatchEmoting",false)
		character:SetAttribute("CatchEmote",nil)
	end
end

function CosmeticService:_canEmote(player)
	local round = self.ctx.Services.RoundService
	if not round then return false end
	local phase = round:Snapshot().phase
	if phase ~= "Waiting" and phase ~= "Intermission" and phase ~= "Results" then return false end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid ~= nil and humanoid.Health > 0 and root ~= nil
end

-- Any emote the player owns can be played (the equipped one is the quick-play default on the dock).
function CosmeticService:Emote(player, id)
	if type(id) ~= "string" or not Emotes.Has(id) or Emotes.Defs[id].victory then return false end
	local profile = self.ctx.Services.DataService:Get(player)
	local item = self.ctx.Catalog.Get(id)
	if not profile or not item or item.category ~= "emotes" or not profile.owned[id] then return false end
	if not self:_canEmote(player) then
		self.ctx.Remotes.Notice:FireClient(player,{kind="toast",text="Emotes are available in the lobby and on the results screen."})
		return false
	end
	local now = os.clock()
	if now-(self.lastEmote[player] or -10) < 1.5 then return false end
	self.lastEmote[player] = now
	self:_stopEmote(player)
	local character = player.Character
	local current = {character=character,connection=nil,id=id}
	self.emotes[player] = current
	character:SetAttribute("CatchEmote",id)
	character:SetAttribute("CatchEmoteAt",workspace:GetServerTimeNow())
	character:SetAttribute("CatchEmoting",true)
	local duration = Emotes.Duration(id)
	local checkClock = 0
	current.connection = RunService.Heartbeat:Connect(function(dt)
		checkClock += dt
		if checkClock < 0.1 then return end
		checkClock = 0
		local root = character:FindFirstChild("HumanoidRootPart")
		if self.emotes[player] ~= current or player.Character ~= character or not root or os.clock()-now > duration or not self:_canEmote(player)
			or Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude > 4 then
			self:_stopEmote(player)
		end
	end)
	return true
end

-- Winners stand on the podium as their REAL avatar (from their HumanoidDescription) wearing their equipped
-- cosmetics. If the description cannot be fetched, a neutral mannequin wearing the same cosmetics is used.
function CosmeticService:_buildShowcase(player,profile)
	local equipped = ownedEquipment(self.ctx,profile)
	local base
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local ok,description = pcall(function() return humanoid:GetAppliedDescription() end)
		if ok and description then base = Appearance.BuildAvatar(description,humanoid.RigType) end
	end
	local rig = Appearance.BuildPreview(equipped.skins,equipped.masks,equipped,{userId=player.UserId},base)
	if base then base:Destroy() end
	return rig,equipped
end

function CosmeticService:ShowWinners(players)
	if self.podiumSpin then self.podiumSpin:Disconnect(); self.podiumSpin=nil end
	if self.podiums then self.podiums:Destroy(); self.podiums=nil end
	if type(players) ~= "table" or #players == 0 then return end
	local positions = self.ctx.World and self.ctx.World.Podiums
	if not positions or #positions == 0 then return end
	local folder = Instance.new("Folder")
	folder.Name = "CatchWinnerShowcase"
	folder.Parent = workspace
	self.podiums = folder
	local showcases = {}
	local began = os.clock()
	for index=1,math.min(#players,#positions) do
		local player = players[index]
		local profile = self.ctx.Services.DataService:Get(player)
		if profile then
			task.spawn(function()
				local ok,rig,equipped = pcall(function() return self:_buildShowcase(player,profile) end)
				if not ok or not rig then return end
				if self.podiums ~= folder or not folder.Parent then rig:Destroy(); return end
				rig.Name = "Winner_"..tostring(player.UserId)
				rig.Parent = folder
				rig:PivotTo(positions[index])
				nameplate(rig.CatchAppearance,rig,player.DisplayName,equipped.nameplates,"CHASE CHAMPION",self.ctx.Catalog,player.UserId)
				local pose = Poses.Preview(rig)
				if pose and Emotes.Has(equipped.victories) then
					Appearance.SetMood(rig,"Win")
					pose:Set(Emotes.Sample(equipped.victories,1,true) or {},positions[index])
					table.insert(showcases,{rig=rig,origin=positions[index],pose=pose,victory=equipped.victories})
				end
			end)
		end
	end
	self.podiumSpin = RunService.Heartbeat:Connect(function()
		if not folder.Parent then
			if self.podiumSpin then self.podiumSpin:Disconnect(); self.podiumSpin=nil end
			return
		end
		local elapsed = os.clock()-began
		for _, item in ipairs(showcases) do
			if item.rig.Parent then item.pose:Set(Emotes.Sample(item.victory,1+elapsed,true) or {},item.origin) end
		end
	end)
end

function CosmeticService:_watchPlayer(player)
	if self.playerConnections[player] then return end
	local function clearCharacter()
		for _, connection in ipairs(self.characterConnections[player] or {}) do connection:Disconnect() end
		self.characterConnections[player] = nil
	end
	local function applyWhenReady(character)
		clearCharacter()
		local refreshQueued = false
		self.characterConnections[player] = {
			character:GetAttributeChangedSignal("RoundRole"):Connect(function() self:UpdateRole(player) end),
			character.ChildAdded:Connect(function(child)
				-- Roblox may insert BodyColors/accessories after CharacterAdded even
				-- when LoadCharacterAppearance is disabled. Our own folders are ignored.
				if (child:IsA("BodyColors") or child:IsA("Accessory") or child:IsA("BasePart") or child:IsA("Humanoid")) and not refreshQueued then
					refreshQueued = true
					task.defer(function()
						refreshQueued = false
						if player.Character==character then self:Apply(player,true) end
					end)
				end
			end),
		}
		task.spawn(function()
			local deadline = os.clock()+20
			while player.Parent and player.Character==character and os.clock()<deadline do
				if self:Apply(player) then return end
				task.wait(0.25)
			end
			if player.Character==character and not character:FindFirstChild("CatchAppearance") then
				warn("[Catch cosmetics] Outfit unavailable for "..tostring(player.UserId).."; character needs a complete R15 or R6 rig. Appearance version "..Appearance.Version)
			end
		end)
	end
	self.playerConnections[player] = {
		player.CharacterAdded:Connect(function(character) self:_stopEmote(player); applyWhenReady(character) end),
		player.CharacterAppearanceLoaded:Connect(function(character)
			if player.Character == character then self:Apply(player,true) end
		end),
		player.CharacterRemoving:Connect(function() self:_stopEmote(player); clearCharacter() end),
		player:GetAttributeChangedSignal("RoundRole"):Connect(function() self:UpdateRole(player) end),
	}
	if player.Character then applyWhenReady(player.Character) end
end

-- Moods drive replicated face geometry; the round service owns the facts behind them.
function CosmeticService:_updateMoods()
	local round = self.ctx.Services.RoundService
	if not round or not round.MoodFor then return end
	for _, player in ipairs(Players:GetPlayers()) do
		local rig = player.Character
		if rig and rig:FindFirstChild("CatchAppearance") then
			local mood = round:MoodFor(player)
			if rig:GetAttribute("CatchMood") ~= mood then rig:SetAttribute("CatchMood",mood) end
			Appearance.SetMood(rig,mood)
			local plate = rig.CatchAppearance:FindFirstChild("CatchNameplate")
			if plate then
				local visible = rig:GetAttribute("CatchHiding") ~= true
				if plate.Enabled ~= visible then plate.Enabled = visible end
			end
		end
	end
end

function CosmeticService:_flushPending()
	for player in pairs(self.pendingLook) do
		if not self:_inRound(player) then
			self:Apply(player,false,true)
		end
	end
end

function CosmeticService:_updateTrails()
	for _, player in ipairs(Players:GetPlayers()) do
		local rig = player.Character
		local root = rig and rig:FindFirstChild("HumanoidRootPart")
		local folder = rig and rig:FindFirstChild("CatchAppearance")
		local humanoid = rig and rig:FindFirstChildOfClass("Humanoid")
		if folder then
			local enabled = root ~= nil and humanoid ~= nil and humanoid.Health > 0 and not root.Anchored
				and rig:GetAttribute("RoundFrozen") ~= true and rig:GetAttribute("Sprinting") == true
				and Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude > 3
			Trails.SetActive(folder,enabled)
		end
	end
end

function CosmeticService:Start()
	if self.started then return end
	self.started = true
	local elapsed = 0
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.15 then
			self.moodClock += elapsed
			elapsed = 0
			self:_updateTrails()
			if self.moodClock >= 0.45 then
				self.moodClock = 0
				self:_flushPending()
				self:_updateMoods()
			end
		end
	end))
	table.insert(self.connections,Players.PlayerAdded:Connect(function(player) self:_watchPlayer(player) end))
	table.insert(self.connections,Players.PlayerRemoving:Connect(function(player)
		self:_stopEmote(player)
		for _, connection in ipairs(self.playerConnections[player] or {}) do connection:Disconnect() end
		for _, connection in ipairs(self.characterConnections[player] or {}) do connection:Disconnect() end
		self.playerConnections[player] = nil
		self.characterConnections[player] = nil
		self.lastEmote[player] = nil
		self.pendingLook[player] = nil
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_watchPlayer(player) end
end

return CosmeticService
