local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Appearance = require(ReplicatedStorage:WaitForChild("CatchShared"):WaitForChild("Appearance"))

local CosmeticService = {}
CosmeticService.__index = CosmeticService

local plateStyles = {
	name_rookie = {label="CITY NEWCOMER",color=Color3.fromRGB(160,189,210)},
	name_survivor = {label="UNTOUCHABLE",color=Color3.fromRGB(73,227,204)},
	name_legend = {label="SKYLINE LEGEND",color=Color3.fromRGB(244,194,88)},
}

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

local function nameplate(folder, rig, displayName, plateId, title)
	local head = rig:FindFirstChild("Head")
	if not head then return end
	local style = plateStyles[plateId] or plateStyles.name_rookie
	local gui = Instance.new("BillboardGui")
	gui.Name = "CatchNameplate"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(190,45)
	gui.StudsOffset = Vector3.new(0,1.45,0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 70
	gui.Parent = folder
	text(gui,"Identity",displayName,UDim2.fromScale(1,0.58),UDim2.fromScale(0,0),Color3.fromRGB(245,246,255),true)
	if title or plateId ~= "" then
		text(gui,"Title",title or style.label,UDim2.fromScale(1,0.42),UDim2.fromScale(0,0.58),style.color,false)
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
	return setmetatable({ctx=ctx, connections={}, playerConnections={}, characterConnections={}, emotes={}, lastEmote={}, podiums=nil, podiumSpin=nil},CosmeticService)
end

function CosmeticService:Apply(player, refreshLoadingAppearance)
	local data = self.ctx.Services.DataService
	local profile = data and data:Get(player)
	local rig = player.Character
	if not Appearance.IsRigReady(rig) then return false end
	-- A slow profile read should not expose an unfinished avatar. Render the free
	-- outfit once while loading; DataService reapplies verified owned items on load.
	if not profile and not refreshLoadingAppearance and rig:FindFirstChild("CatchAppearance")
		and rig:GetAttribute("CatchAppearanceVersion") == Appearance.Version then return false end
	local equipped = profile and ownedEquipment(self.ctx,profile) or self.ctx.Catalog.DefaultEquipment
	local folder = Appearance.Apply(rig,equipped.skins,equipped.masks,equipped)
	if not folder then return false end
	nameplate(folder,rig,player.DisplayName,equipped.nameplates)
	Appearance.ApplyRole(rig,player:GetAttribute("RoundRole") or rig:GetAttribute("RoundRole") or "Lobby")
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None end
	return profile ~= nil
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

function CosmeticService:_stopEmote(player)
	local current = self.emotes[player]
	if not current then return end
	self.emotes[player] = nil
	if current.connection then current.connection:Disconnect() end
	for motor,original in pairs(current.motors) do
		if motor.Parent then motor.C0 = original end
	end
	if current.character.Parent then current.character:SetAttribute("CatchEmoting",false) end
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

function CosmeticService:Emote(player, id)
	if type(id) ~= "string" or (id ~= "emote_wave" and id ~= "emote_dance") then return false end
	local profile = self.ctx.Services.DataService:Get(player)
	if not profile or not profile.owned[id] or profile.equipped.emotes ~= id then return false end
	if not self:_canEmote(player) then
		self.ctx.Remotes.Notice:FireClient(player,{kind="toast",text="Emotes are available in the lobby and on the results screen."})
		return false
	end
	local now = os.clock()
	if now-(self.lastEmote[player] or -10) < 2 then return false end
	self.lastEmote[player] = now
	self:_stopEmote(player)
	local character = player.Character
	local motors = {}
	local named = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		local jointName = descendant.Name:gsub("%s", "")
		if descendant:IsA("Motor6D") and (jointName == "RightShoulder" or jointName == "LeftShoulder" or jointName == "Waist") then
			motors[descendant] = descendant.C0
			named[jointName] = descendant
		end
	end
	local current = {character=character,motors=motors,connection=nil}
	self.emotes[player] = current
	character:SetAttribute("CatchEmoting",true)
	local duration = id == "emote_wave" and 3.4 or 5.0
	current.connection = RunService.Heartbeat:Connect(function()
		local elapsed = os.clock()-now
		local root = character:FindFirstChild("HumanoidRootPart")
		if self.emotes[player] ~= current or player.Character ~= character or not root or elapsed > duration or not self:_canEmote(player)
			or Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude > 4 then
			self:_stopEmote(player)
			return
		end
		local weight = math.min(1,elapsed/0.20,(duration-elapsed)/0.25)
		local wave = math.sin(elapsed*10)
		if named.RightShoulder then
			local pose = id=="emote_wave" and CFrame.Angles(math.rad(-20),0,math.rad(135+wave*18))
				or CFrame.Angles(math.rad(-25+math.sin(elapsed*6)*20),0,math.rad(65+wave*18))
			named.RightShoulder.C0 = motors[named.RightShoulder] * CFrame.new():Lerp(pose,weight)
		end
		if id=="emote_dance" then
			if named.LeftShoulder then named.LeftShoulder.C0 = motors[named.LeftShoulder] * CFrame.Angles(math.rad(-25-math.sin(elapsed*6)*20)*weight,0,math.rad(-65+wave*18)*weight) end
			if named.Waist then named.Waist.C0 = motors[named.Waist] * CFrame.Angles(0,math.sin(elapsed*6)*0.20*weight,math.sin(elapsed*6)*0.10*weight) end
		end
	end)
	return true
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
	for index=1,math.min(#players,#positions) do
		local player = players[index]
		local profile = self.ctx.Services.DataService:Get(player)
		if profile then
			local equipped = ownedEquipment(self.ctx,profile)
			local rig = Appearance.BuildPreview(equipped.skins,equipped.masks,equipped)
			rig.Name = "Winner_"..tostring(player.UserId)
			rig.Parent = folder
			rig:PivotTo(positions[index])
			nameplate(rig.CatchAppearance,rig,player.DisplayName,equipped.nameplates,"CHASE CHAMPION")
			local animate = Appearance.CreatePreviewPose(rig,equipped.victories)
			if animate then
				animate(0)
				table.insert(showcases,{rig=rig,origin=positions[index],spin=equipped.victories=="victory_spin",animate=animate})
			end
		end
	end
	if #showcases > 0 then
		local began = os.clock()
		self.podiumSpin = RunService.Heartbeat:Connect(function()
			if not folder.Parent then
				if self.podiumSpin then self.podiumSpin:Disconnect(); self.podiumSpin=nil end
				return
			end
			local elapsed = os.clock()-began
			for _, item in ipairs(showcases) do
				if item.rig.Parent then
					if item.spin then item.rig:PivotTo(item.origin*CFrame.Angles(0,elapsed*0.7,0)) end
					item.animate(elapsed)
				end
			end
		end)
	end
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
			for _, effect in ipairs(folder:GetChildren()) do
				if effect:IsA("Trail") and effect.Enabled ~= enabled then effect.Enabled = enabled end
			end
		end
	end
end

function CosmeticService:Start()
	if self.started then return end
	self.started = true
	local elapsed = 0
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 0.15 then elapsed = 0; self:_updateTrails() end
	end))
	table.insert(self.connections,Players.PlayerAdded:Connect(function(player) self:_watchPlayer(player) end))
	table.insert(self.connections,Players.PlayerRemoving:Connect(function(player)
		self:_stopEmote(player)
		for _, connection in ipairs(self.playerConnections[player] or {}) do connection:Disconnect() end
		for _, connection in ipairs(self.characterConnections[player] or {}) do connection:Disconnect() end
		self.playerConnections[player] = nil
		self.characterConnections[player] = nil
		self.lastEmote[player] = nil
	end))
	for _, player in ipairs(Players:GetPlayers()) do self:_watchPlayer(player) end
end

return CosmeticService
