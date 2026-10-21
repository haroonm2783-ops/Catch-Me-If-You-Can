-- Client-side cosmetics that are drawn locally for every player:
--   Emotes     the server announces an emote with two attributes on the character (CatchEmote, CatchEmoteAt); each
--              client plays the matching pose function on that character's joints, so nothing streams per frame.
--   Footprints trails with a footprint design (Golden Footsteps) stamp pooled parts on the floor behind runners.
--   LOD        avatar auras and trail particles are thinned by distance and device tier. Purely local and cosmetic.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local shared = ReplicatedStorage:WaitForChild("CatchShared")
local Emotes = require(shared:WaitForChild("Emotes"))
local Poses = require(shared:WaitForChild("Poses"))
local Trails = require(shared:WaitForChild("Trails"))

local CosmeticsController = {}
CosmeticsController.__index = CosmeticsController

local FOOTPRINT_RANGE = 70   -- other players' footprints only draw this close to the camera
local EMITTER_RANGE = {160, 90, 55}

function CosmeticsController.new(ctx)
	return setmetatable({ctx = ctx, player = Players.LocalPlayer, connections = {}, watched = {}, sessions = {}, prints = {}, lodClock = 0, printClock = 0}, CosmeticsController)
end

-- ---------------------------------------------------------------------------------------
-- Emotes
-- ---------------------------------------------------------------------------------------
function CosmeticsController:_stopSession(character)
	local session = self.sessions[character]
	if not session then return end
	self.sessions[character] = nil
	session.live:Restore()
end

function CosmeticsController:_startSession(character)
	self:_stopSession(character)
	local id = character:GetAttribute("CatchEmote")
	if type(id) ~= "string" or not Emotes.Has(id) then return end
	local started = character:GetAttribute("CatchEmoteAt")
	local now = Workspace:GetServerTimeNow()
	local elapsed = type(started) == "number" and math.clamp(now - started, 0, Emotes.Duration(id)) or 0
	self.sessions[character] = {id = id, live = Poses.Live(character), clock = elapsed, fired = false}
end

function CosmeticsController:_burst(character, def, fx)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not fx then return end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "CatchEmoteBurst"
	emitter.Color = ColorSequence.new(Color3.fromRGB(fx.a[1], fx.a[2], fx.a[3]), Color3.fromRGB(fx.b[1], fx.b[2], fx.b[3]))
	emitter.Texture = Trails.Textures.sparkles
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Speed = NumberRange.new(7, 13)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0)})
	emitter.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1)})
	emitter.LightEmission = 0.6
	emitter.Rate = 0
	emitter.Parent = root
	emitter:Emit(fx.count)
	game:GetService("Debris"):AddItem(emitter, 2)
end

function CosmeticsController:_stepEmotes(dt)
	for character, session in pairs(self.sessions) do
		local humanoid = character.Parent and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or character:GetAttribute("CatchEmote") ~= session.id then
			self:_stopSession(character)
		else
			session.clock += dt
			local pose = Emotes.Sample(session.id, session.clock, false)
			if not pose then
				self:_stopSession(character)
			else
				session.live:Apply(pose)
				local fx = Emotes.Defs[session.id].fx
				if fx and not session.fired and session.clock >= fx.at then
					session.fired = true
					self:_burst(character, Emotes.Defs[session.id], fx)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Footprints
-- ---------------------------------------------------------------------------------------
function CosmeticsController:_fxFolder()
	if self.fxFolder and self.fxFolder.Parent then return self.fxFolder end
	local folder = Instance.new("Folder")
	folder.Name = "CatchClientEffects"
	folder.Parent = Workspace
	self.fxFolder = folder
	return folder
end

function CosmeticsController:_stepFootprints(dt)
	local camera = Workspace.CurrentCamera
	local seen = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local trailId = character and character:GetAttribute("CatchTrail")
		local def = trailId and Trails.Defs[trailId]
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if def and def.footprints and root then
			local near = player == self.player or not camera or (camera.CFrame.Position - root.Position).Magnitude <= FOOTPRINT_RANGE
			if near and (self.ctx.Perf or {tier = 1}).tier < 3 then
				seen[character] = true
				local record = self.prints[character]
				if not record or record.id ~= trailId then
					if record then record.object:Destroy() end
					record = {id = trailId, object = Trails.Footprints.new(self:_fxFolder(), def.footprints)}
					self.prints[character] = record
				end
				local appearance = character:FindFirstChild("CatchAppearance")
				local mount = appearance and appearance:FindFirstChild("TrailMount")
				local ribbon = mount and mount:FindFirstChildOfClass("Trail")
				local active = ribbon ~= nil and ribbon.Enabled
				local velocity = root.AssemblyLinearVelocity
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				local drop = (humanoid and humanoid.HipHeight or 2) + root.Size.Y / 2
				local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				record.object:Step(dt, Vector3.new(root.Position.X, root.Position.Y - drop + 0.04, root.Position.Z), speed > 0.1 and velocity or root.CFrame.LookVector, active and speed or 0)
			end
		end
	end
	for character, record in pairs(self.prints) do
		if not seen[character] then
			-- Keep fading prints for a moment after a runner stops; drop the record once nothing is visible.
			record.object:Step(dt, Vector3.zero, Vector3.new(0, 0, -1), 0)
			if not character.Parent or record.object:Visible() == 0 then
				record.object:Destroy()
				self.prints[character] = nil
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------
-- Particle level of detail
-- ---------------------------------------------------------------------------------------
function CosmeticsController:_lod()
	local tier = (self.ctx.Perf or {tier = 1}).tier
	local camera = Workspace.CurrentCamera
	local origin = camera and camera.CFrame.Position
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local folder = character and character:FindFirstChild("CatchAppearance")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if folder and root then
			local mine = player == self.player
			local range = EMITTER_RANGE[tier] or EMITTER_RANGE[3]
			local far = origin ~= nil and (origin - root.Position).Magnitude > range
			for _, descendant in ipairs(folder:GetDescendants()) do
				if descendant:IsA("ParticleEmitter") then
					local base = descendant:GetAttribute("CatchBaseRate")
					if base == nil then
						base = descendant.Rate
						descendant:SetAttribute("CatchBaseRate", base)
					end
					local factor = 1
					if far then factor = 0
					elseif tier >= 3 then factor = mine and 0.4 or 0
					elseif tier == 2 then factor = mine and 0.7 or 0.5 end
					local rate = base * factor
					if descendant.Rate ~= rate then descendant.Rate = rate end
				end
			end
		end
	end
end

-- ---------------------------------------------------------------------------------------
function CosmeticsController:_watch(player)
	if self.watched[player] then return end
	local connections = {}
	self.watched[player] = connections
	local function bind(character)
		if not character then return end
		table.insert(connections, character:GetAttributeChangedSignal("CatchEmote"):Connect(function() self:_startSession(character) end))
		if character:GetAttribute("CatchEmote") then self:_startSession(character) end
	end
	table.insert(connections, player.CharacterAdded:Connect(bind))
	table.insert(connections, player.CharacterRemoving:Connect(function(character) self:_stopSession(character) end))
	bind(player.Character)
end

function CosmeticsController:Start()
	if self.started then return end
	self.started = true
	for _, player in ipairs(Players:GetPlayers()) do self:_watch(player) end
	if Players.PlayerAdded then table.insert(self.connections, Players.PlayerAdded:Connect(function(player) self:_watch(player) end)) end
	if Players.PlayerRemoving then
		table.insert(self.connections, Players.PlayerRemoving:Connect(function(player)
			for _, connection in ipairs(self.watched[player] or {}) do connection:Disconnect() end
			self.watched[player] = nil
			if player.Character then self:_stopSession(player.Character) end
		end))
	end
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self:_stepEmotes(dt)
		self.printClock += dt
		if self.printClock >= 1 / 30 then
			self:_stepFootprints(self.printClock)
			self.printClock = 0
		end
		self.lodClock += dt
		if self.lodClock >= 0.6 then
			self.lodClock = 0
			self:_lod()
		end
	end))
end

function CosmeticsController:Destroy()
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	for _, connections in pairs(self.watched) do
		for _, connection in ipairs(connections) do connection:Disconnect() end
	end
	for character in pairs(self.sessions) do self:_stopSession(character) end
	for _, record in pairs(self.prints) do record.object:Destroy() end
	table.clear(self.connections)
	table.clear(self.watched)
	table.clear(self.prints)
	if self.fxFolder then self.fxFolder:Destroy() self.fxFolder = nil end
end

return CosmeticsController
