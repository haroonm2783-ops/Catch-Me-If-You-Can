-- Input is intent only. Speed, collision, cooldowns and tagging are server-owned.
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local MovementController = {}
MovementController.__index = MovementController

local ACTIONS = { "CatchSprint", "CatchSlide", "CatchVault", "CatchTag" }
local READY_ATTRIBUTES = {
	Slide = "CatchSlideReadyAt",
	Vault = "CatchVaultReadyAt",
	Tag = "CatchTagReadyAt",
}

-- Authored joint offsets provide a real slide silhouette without depending on
-- an uploaded animation. C0 leaves Roblox's Animator free to animate Transform.
-- R6 names keep older published places usable while R15 is the intended rig.
local SLIDE_POSE = {
	Root = CFrame.new(0, -0.7, 0) * CFrame.Angles(-0.12, 0, 0),
	RootJoint = CFrame.new(0, -0.45, 0) * CFrame.Angles(-0.22, 0, 0),
	Waist = CFrame.Angles(-0.28, 0.08, 0),
	LeftHip = CFrame.Angles(0.9, -0.12, -0.08),
	RightHip = CFrame.Angles(0.55, 0.12, 0.08),
	LeftKnee = CFrame.Angles(-1.35, 0, 0),
	RightKnee = CFrame.Angles(-0.8, 0, 0),
	LeftAnkle = CFrame.Angles(0.35, 0, 0),
	RightAnkle = CFrame.Angles(0.22, 0, 0),
	LeftShoulder = CFrame.Angles(-0.3, 0, -0.2),
	RightShoulder = CFrame.Angles(-0.15, 0, 0.25),
	["Left Hip"] = CFrame.Angles(0.8, 0, -0.12),
	["Right Hip"] = CFrame.Angles(0.35, 0, 0.12),
	["Left Shoulder"] = CFrame.Angles(-0.3, 0, -0.2),
	["Right Shoulder"] = CFrame.Angles(-0.15, 0, 0.25),
}

-- Extra authored poses blend on top of the slide pose: a tucked vault, a tag lunge, and a landing squash.
local VAULT_POSE = {
	Waist = CFrame.Angles(-0.38, 0, 0),
	LeftHip = CFrame.Angles(1.15, 0, 0), RightHip = CFrame.Angles(1.45, 0, 0),
	LeftKnee = CFrame.Angles(-1.5, 0, 0), RightKnee = CFrame.Angles(-1.2, 0, 0),
	LeftShoulder = CFrame.Angles(-2.5, 0, -0.18), RightShoulder = CFrame.Angles(-2.5, 0, 0.18),
	["Left Hip"] = CFrame.Angles(1.0, 0, 0), ["Right Hip"] = CFrame.Angles(1.3, 0, 0),
	["Left Shoulder"] = CFrame.Angles(-2.4, 0, -0.18), ["Right Shoulder"] = CFrame.Angles(-2.4, 0, 0.18),
}
local TAG_POSE = {
	Waist = CFrame.Angles(-0.45, -0.25, 0),
	RightShoulder = CFrame.Angles(-2.2, 0, 0.12), LeftShoulder = CFrame.Angles(0.7, 0, -0.12),
	LeftHip = CFrame.Angles(-0.45, 0, 0), RightHip = CFrame.Angles(0.8, 0, 0),
	RightKnee = CFrame.Angles(-0.5, 0, 0),
	["Right Shoulder"] = CFrame.Angles(-2.0, 0, 0.12), ["Left Shoulder"] = CFrame.Angles(0.6, 0, -0.12),
	["Left Hip"] = CFrame.Angles(-0.4, 0, 0), ["Right Hip"] = CFrame.Angles(0.7, 0, 0),
}
local LAND_POSE = {
	RootJoint = CFrame.new(0, -0.35, 0), Root = CFrame.new(0, -0.35, 0),
	Waist = CFrame.Angles(-0.2, 0, 0),
	LeftHip = CFrame.Angles(0.55, 0, 0), RightHip = CFrame.Angles(0.55, 0, 0),
	LeftKnee = CFrame.Angles(-0.9, 0, 0), RightKnee = CFrame.Angles(-0.9, 0, 0),
	LeftShoulder = CFrame.Angles(-0.35, 0, 0), RightShoulder = CFrame.Angles(-0.35, 0, 0),
}
local POSES = { slide = SLIDE_POSE, vault = VAULT_POSE, tag = TAG_POSE, land = LAND_POSE }
local POSE_ORDER = { "slide", "vault", "tag", "land" }
local TRACKED = {}
for _, set in pairs(POSES) do for name in pairs(set) do TRACKED[name] = true end end

local function poseOffset(name, blends)
	local offset = CFrame.new()
	for _, key in ipairs(POSE_ORDER) do
		local amount = blends[key]
		local target = amount and amount > 0.001 and POSES[key][name]
		if target then offset *= CFrame.new():Lerp(target, amount) end
	end
	return offset
end

local function collectPose(character)
	local pose = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") and TRACKED[descendant.Name] then
			table.insert(pose, { joint = descendant, base = descendant.C0 })
		end
	end
	return pose
end

local function resetPose(pose)
	for _, record in ipairs(pose) do
		if record.joint.Parent and record.last and record.joint.C0 == record.last then
			record.joint.C0 = record.base
		end
		record.last = nil
	end
end

local function applyPose(pose, blends, lean)
	if type(blends) == "number" then blends = { slide = blends } end
	for _, record in ipairs(pose) do
		local joint = record.joint
		if joint.Parent then
			if joint.C0 ~= record.last then record.base = joint.C0 end
			local offset = poseOffset(joint.Name, blends)
			if joint.Name == "Waist" or joint.Name == "RootJoint" then
				offset *= CFrame.Angles(lean.X, lean.Y, lean.Z)
			end
			-- Apply offsets in the parent's axes, including R6's rotated joint bases.
			record.last = CFrame.new(record.base.Position) * offset * record.base.Rotation
			joint.C0 = record.last
		end
	end
end

local function disconnectAll(connections)
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
	table.clear(connections)
end

function MovementController.new(ctx)
	return setmetatable({
		ctx = ctx,
		player = Players.LocalPlayer,
		connections = {},
		characterConnections = {},
		pose = {},
		remotePoses = {},
		slideBlend = 0,
		blends = { slide = 0, vault = 0, tag = 0, land = 0 },
		sprintRequested = false,
		lastVaultIntent = 0,
		lastSlideIntent = 0,
		lastTagIntent = 0,
		bobTime = 0,
		cameraOffset = Vector3.zero,
		lean = Vector3.zero,
		role = "Lobby",
		bindName = "CatchMovementFeedback",
	}, MovementController)
end

function MovementController:_settings()
	return self.ctx.Profile.settings or {}
end

function MovementController:_canAct()
	return self.humanoid ~= nil
		and self.humanoid.Health > 0
		and self.role ~= "Spectator"
		and self.character:GetAttribute("RoundFrozen") ~= true
		and not self.player:GetAttribute("CatchMenuOpen")
		and UserInputService:GetFocusedTextBox() == nil
end

function MovementController:_sprint(active)
	active = active == true and self:_canAct()
	if self.sprintRequested == active then
		return
	end
	self.sprintRequested = active
	self.ctx.Remotes.Action:FireServer("Sprint", { active = active })
	ContextActionService:SetTitle("CatchSprint", active and "RUN ON" or "RUN")
end

function MovementController:_intent(action)
	if not self:_canAct() then
		return
	end
	if action == "Tag" and (self.role ~= "Hunter" or self.phase ~= "Active") then return end
	-- This is only an input flood guard. The server decides whether the move is valid.
	local field = "last" .. action .. "Intent"
	local now = os.clock()
	if now - (self[field] or 0) < 0.15 then
		return
	end
	self[field] = now
	if action == "Tag" then self.localTagAt = now end
	self.ctx.Remotes.Action:FireServer(action, {})
end

function MovementController:GetCooldown(action)
	local attribute = READY_ATTRIBUTES[action]
	local readyAt = attribute and self.player:GetAttribute(attribute)
	return type(readyAt) == "number" and math.max(0, readyAt - workspace:GetServerTimeNow()) or 0
end

function MovementController:_resetPose()
	resetPose(self.pose)
	self.lean = Vector3.zero
	self.slideBlend = 0
	self.blends = { slide = 0, vault = 0, tag = 0, land = 0 }
end

-- Sliding is replicated by the server as an attribute. Each client renders the
-- same eased pose for nearby opponents as well as its own avatar; no RemoteEvent
-- is allowed to supply joint transforms or request another player's animation.
function MovementController:_remoteFeedback(dt)
	local seen = {}
	local smoothing = 1 - math.exp(-18 * dt)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= self.player then
			seen[player] = true
			local character, record = player.Character, self.remotePoses[player]
			if record and record.character ~= character then
				resetPose(record.pose)
				self.remotePoses[player], record = nil, nil
			end
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local alive = humanoid and humanoid.Health > 0 and not character:GetAttribute("CatchEmoting") and not self:_settings().reducedMotion
			local tagAt = character and character:GetAttribute("CatchTagAt")
			local targets = {
				slide = alive and character:GetAttribute("Sliding") == true and 1 or 0,
				vault = alive and character:GetAttribute("Vaulting") == true and 1 or 0,
				tag = alive and type(tagAt) == "number" and workspace:GetServerTimeNow() - tagAt < 0.4 and 1 or 0,
			}
			local wanted = targets.slide + targets.vault + targets.tag > 0
			if wanted and not record then
				record = { character = character, pose = collectPose(character), blends = { slide = 0, vault = 0, tag = 0 } }
				self.remotePoses[player] = record
			end
			if record then
				local total = 0
				for key, target in pairs(targets) do
					record.blends[key] += (target - record.blends[key]) * smoothing
					total += record.blends[key]
				end
				if not wanted and total < 0.001 then
					resetPose(record.pose)
					self.remotePoses[player] = nil
				else
					applyPose(record.pose, record.blends, Vector3.zero)
				end
			end
		end
	end
	for player, record in pairs(self.remotePoses) do
		if not seen[player] then resetPose(record.pose); self.remotePoses[player] = nil end
	end
end

function MovementController:_releaseCamera()
	if self.ownsCamera and self.camera and self.camera.Parent then
		self.camera.FieldOfView = self.baseFov
	end
	if self.humanoid and self.humanoid.Parent and self.lastCameraOffset
		and self.humanoid.CameraOffset == self.lastCameraOffset then
		self.humanoid.CameraOffset = self.baseCameraOffset or Vector3.zero
	end
	self.ownsCamera = false
	self.lastCameraOffset = nil
	self.cameraOffset = Vector3.zero
end

function MovementController:OnCharacter(character)
	if self.character == character then
		return
	end
	self:_sprint(false)
	self:_releaseCamera()
	self:_resetPose()
	disconnectAll(self.characterConnections)
	table.clear(self.pose)
	self.character = character
	self.humanoid = nil
	self.root = nil
	-- Server ResetPlayer clears parkour cooldowns when a new avatar spawns.
	-- Do not leave the previous avatar's acknowledged cooldown in the HUD.
	self.player:SetAttribute(READY_ATTRIBUTES.Slide, nil)
	self.player:SetAttribute(READY_ATTRIBUTES.Vault, nil)
	self.lastSlideIntent, self.lastVaultIntent = 0, 0
	if not character then
		return
	end
	-- Waiting for avatar parts must not stall Query/state dispatch.
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if self.character ~= character or not humanoid or not root or self.destroyed then
			return
		end
		self.humanoid = humanoid
		self.root = root
		self.baseCameraOffset = humanoid.CameraOffset
		self.bobTime = 0
		self.pose = collectPose(character)
		table.insert(self.characterConnections, humanoid.Died:Connect(function()
			self:_sprint(false)
			self:_releaseCamera()
			self:_resetPose()
		end))
	end)
end

function MovementController:_feedback(dt)
	dt = math.min(dt, 0.1)
	self:_remoteFeedback(dt)
	local humanoid, root, character = self.humanoid, self.root, self.character
	local camera = workspace.CurrentCamera
	local settings = self:_settings()
	local permitted = humanoid and root and character and humanoid.Health > 0
		and self.role ~= "Spectator" and not settings.reducedMotion
	if not permitted then
		self:_releaseCamera()
		self:_resetPose()
		return
	end
	local moving = humanoid.MoveDirection.Magnitude > 0.1
	local sprinting = character:GetAttribute("Sprinting") == true and moving
	local sliding = character:GetAttribute("Sliding") == true
	local vaulting = character:GetAttribute("Vaulting") == true
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local smoothing = 1 - math.exp(-10 * dt)
	local ownsSubject = camera and camera.CameraSubject == humanoid
		and camera.CameraType ~= Enum.CameraType.Scriptable
	if ownsSubject then
		if self.camera ~= camera or not self.ownsCamera then
			self:_releaseCamera()
			self.camera = camera
			self.baseFov = camera.FieldOfView
			self.ownsCamera = true
		end
		local targetFov = self.baseFov + (sliding and 9 or (sprinting and 7 or 0))
		camera.FieldOfView += (targetFov - camera.FieldOfView) * smoothing
		local offset = Vector3.zero
		if settings.cameraShake ~= false then
			if moving and grounded and not sliding and not vaulting then
				self.bobTime += dt * (sprinting and 13 or 9)
				offset = Vector3.new(math.sin(self.bobTime * 0.5) * 0.025,
					math.abs(math.sin(self.bobTime)) * 0.045, 0)
			elseif sliding then
				offset = Vector3.new(0, -0.5, 0)
			end
		end
		self.cameraOffset = self.cameraOffset:Lerp(offset, smoothing)
		self.lastCameraOffset = self.baseCameraOffset + self.cameraOffset
		humanoid.CameraOffset = self.lastCameraOffset
	else
		-- UIController owns the spectator camera and its subject.
		self:_releaseCamera()
	end
	if character:GetAttribute("CatchEmoting") then
		self:_resetPose()
		return
	end
	local direction = root.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
	local targetLean = Vector3.new(sliding and 0 or direction.Z * 0.065,
		0, -direction.X * (sprinting and 0.075 or 0.045))
	self.lean = self.lean:Lerp(targetLean, smoothing)
	local fast = 1 - math.exp(-18 * dt)
	self.slideBlend += ((sliding and 1 or 0) - self.slideBlend) * fast
	self.blends.slide = self.slideBlend
	self.blends.vault += ((vaulting and not sliding and 1 or 0) - self.blends.vault) * fast
	-- A tag lunge plays immediately on the local press and, for hits, from the replicated timestamp.
	local tagAt = character:GetAttribute("CatchTagAt")
	local lunging = (type(tagAt) == "number" and workspace:GetServerTimeNow() - tagAt < 0.4)
		or (self.localTagAt and os.clock() - self.localTagAt < 0.35)
	self.blends.tag += ((lunging and 1 or 0) - self.blends.tag) * fast
	-- Landing squash after a real fall (not after a hop).
	if not grounded then self.airTime = (self.airTime or 0) + dt
	else
		if (self.airTime or 0) > 0.45 then self.blends.land = 1 end
		self.airTime = 0
	end
	self.blends.land += (0 - self.blends.land) * (1 - math.exp(-9 * dt))
	local active = self.slideBlend > 0.001 or self.blends.vault > 0.001 or self.blends.tag > 0.001 or self.blends.land > 0.001
	if moving or sliding or active or self.lean.Magnitude > 0.001 then
		applyPose(self.pose, self.blends, self.lean)
	else
		self:_resetPose()
	end
end

function MovementController:OnState(state)
	local previousRole = self.role
	self.role = (state.phase == "Active" or state.phase == "HeadStart") and "Spectator" or "Lobby"
	for _, entry in ipairs(state.players or {}) do
		if entry.userId == self.player.UserId then
			self.role = entry.role
			break
		end
	end
	if self.role == "Spectator" or previousRole ~= self.role or self.phase ~= state.phase then
		self:_sprint(false)
	end
	self.phase = state.phase
	self:_touchControls()
end

function MovementController:_touchControls()
	local visible = self.role ~= "Spectator" and not self.player:GetAttribute("CatchMenuOpen")
	for _, action in ipairs(ACTIONS) do
		local control = ContextActionService:GetButton(action)
		if control then
			control.Visible = visible and (action ~= "CatchTag" or (self.role == "Hunter" and self.phase == "Active"))
		end
	end
end

function MovementController:OnProfile(_profile)
	if self:_settings().reducedMotion then
		self:_releaseCamera()
		self:_resetPose()
	end
end

function MovementController:OnNotice(notice)
	if notice.kind ~= "ability" or notice.success == false then
		return
	end
	local attribute = READY_ATTRIBUTES[notice.action]
	local cooldown = tonumber(notice.cooldown)
	if attribute and cooldown and cooldown == cooldown and cooldown >= 0 and cooldown < 60 then
		self.player:SetAttribute(attribute, workspace:GetServerTimeNow() + cooldown)
	end
end

function MovementController:Start()
	if self.started then
		return
	end
	self.started = true
	ContextActionService:BindAction("CatchSprint", function(_, state, input)
		if state == Enum.UserInputState.Cancel then
			self:_sprint(false)
		elseif input.KeyCode == Enum.KeyCode.ButtonL3 or input.UserInputType == Enum.UserInputType.Touch then
			if state == Enum.UserInputState.Begin then
				self:_sprint(not self.sprintRequested)
			end
		elseif state == Enum.UserInputState.Begin then
			self:_sprint(true)
		elseif state == Enum.UserInputState.End then
			self:_sprint(false)
		end
		return self:_canAct() and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
	ContextActionService:BindAction("CatchSlide", function(_, state)
		if state == Enum.UserInputState.Begin then
			self:_intent("Slide")
		end
		return self:_canAct() and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.C, Enum.KeyCode.ButtonB)
	ContextActionService:BindAction("CatchVault", function(_, state)
		if state == Enum.UserInputState.Begin then
			self:_intent("Vault")
		end
		-- Roblox's normal jumping remains available when no vault obstacle is present.
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
	ContextActionService:BindAction("CatchTag", function(_, state)
		if state == Enum.UserInputState.Begin then
			self:_intent("Tag")
		end
		return self:_canAct() and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle("CatchSprint", "RUN")
	ContextActionService:SetTitle("CatchSlide", "SLIDE")
	ContextActionService:SetTitle("CatchTag", "TAG")
	ContextActionService:SetPosition("CatchSprint", UDim2.new(1, -190, 1, -150))
	ContextActionService:SetPosition("CatchSlide", UDim2.new(1, -110, 1, -150))
	ContextActionService:SetPosition("CatchTag", UDim2.new(1, -190, 1, -225))
	for _, action in ipairs(ACTIONS) do
		local button = ContextActionService:GetButton(action)
		if button then
			button.Size = UDim2.fromOffset(64, 64)
			button.ImageColor3 = Color3.fromRGB(31, 47, 65)
		end
	end
	table.insert(self.connections, UserInputService.JumpRequest:Connect(function()
		if UserInputService.TouchEnabled then
			self:_intent("Vault")
		end
	end))
	table.insert(self.connections, UserInputService.WindowFocusReleased:Connect(function()
		self:_sprint(false)
	end))
	table.insert(self.connections, UserInputService.TextBoxFocused:Connect(function()
		self:_sprint(false)
	end))
	table.insert(self.connections, self.player:GetAttributeChangedSignal("CatchMenuOpen"):Connect(function()
		if self.player:GetAttribute("CatchMenuOpen") then
			self:_sprint(false)
		end
		self:_touchControls()
	end))
	table.insert(self.connections, GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		if GuiService.SelectedObject then self:_sprint(false) end
	end))
	table.insert(self.connections, self.player.CharacterAdded:Connect(function(character)
		self:OnCharacter(character)
	end))
	table.insert(self.connections, self.player.CharacterRemoving:Connect(function(character)
		if character == self.character then
			self:OnCharacter(nil)
		end
	end))
	RunService:BindToRenderStep(self.bindName, Enum.RenderPriority.Camera.Value - 1, function(dt)
		self:_feedback(dt)
	end)
	self:OnCharacter(self.player.Character)
	self:OnState(self.ctx.State)
end

function MovementController:Destroy()
	self.destroyed = true
	self:_sprint(false)
	RunService:UnbindFromRenderStep(self.bindName)
	for _, action in ipairs(ACTIONS) do
		ContextActionService:UnbindAction(action)
	end
	self:OnCharacter(nil)
	for _, record in pairs(self.remotePoses) do resetPose(record.pose) end
	table.clear(self.remotePoses)
	disconnectAll(self.connections)
end

return MovementController
