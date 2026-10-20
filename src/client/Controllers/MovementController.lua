-- Input is intent only. Speed, collision, cooldowns and tagging are server-owned.
local Players = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local MovementController = {}
MovementController.__index = MovementController

local ACTIONS = { "CatchSprint", "CatchSlide", "CatchVault", "CatchTag", "CatchScan" }
local READY_ATTRIBUTES = {
	Slide = "CatchSlideReadyAt",
	Vault = "CatchVaultReadyAt",
	Tag = "CatchTagReadyAt",
	Scan = "CatchScanReadyAt",
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

-- Mood overlays share the slide pose's single writer so the two never fight over a joint.
-- Rotations are R15 joint offsets in the parent's axes: shoulders raise on Z, elbows and necks pitch on X.
-- Only the replicated CatchMood attribute (set by the server from round state) selects a mood.
local function angles(x, y, z) return CFrame.Angles(x or 0, y or 0, z or 0) end
local MOOD_POSES = {
	Hunt = { Waist = angles(-0.14), Neck = angles(-0.12), LeftElbow = angles(0.75), RightElbow = angles(0.75), LeftShoulder = angles(0, 0, -0.12), RightShoulder = angles(0, 0, 0.12) },
	Scared = { Neck = angles(-0.08), LeftShoulder = angles(0, 0, -0.4), RightShoulder = angles(0, 0, 0.4), LeftElbow = angles(1.05), RightElbow = angles(1.05) },
	Win = { Neck = angles(0.18), LeftShoulder = angles(0, 0, -2.55), RightShoulder = angles(0, 0, 2.55), LeftElbow = angles(0.1), RightElbow = angles(0.1) },
	Lose = { Waist = angles(-0.2), Neck = angles(-0.5), LeftShoulder = angles(0.1, 0, -0.08), RightShoulder = angles(0.1, 0, 0.08) },
}
MOOD_POSES.Hide = MOOD_POSES.Scared
-- Joints a mood or the idle breathing may touch.
local MOOD_JOINTS = { Waist = true, Neck = true, LeftElbow = true, RightElbow = true, LeftShoulder = true, RightShoulder = true }

-- Time-varying detail layered over the static mood pose.
local function moodMotion(name, mood, clock, blend)
	if name == "Waist" then
		return angles(math.sin(clock * 1.7) * 0.015)
	elseif name == "Neck" then
		if mood == "Scared" or mood == "Hide" then
			return angles(0, math.sin(clock * 3.4) * 0.35 * blend, 0) -- glancing around
		end
		return angles(math.sin(clock * 1.2 + 1) * 0.02, math.sin(clock * 0.6) * 0.08, 0)
	elseif mood == "Win" and (name == "LeftShoulder" or name == "RightShoulder") then
		local sway = math.sin(clock * 9) * 0.1 * blend
		return angles(0, 0, name == "LeftShoulder" and -sway or sway) -- cheering wave
	end
	return nil
end

local function moodOffset(name, mood, blend, clock)
	local base = CFrame.new()
	local target = MOOD_POSES[mood] and MOOD_POSES[mood][name]
	local offset = target and base:Lerp(target, blend) or base
	local motion = MOOD_JOINTS[name] and moodMotion(name, mood, clock, blend)
	if motion then offset = offset * motion end
	return offset
end

-- The engine can hand back a C0 that differs from what was written in the last float bits.
local function sameCFrame(a, b)
	if a == nil or b == nil then return a == b end
	return (a.Position - b.Position).Magnitude < 1e-4
		and (a.LookVector - b.LookVector).Magnitude < 1e-4
		and (a.UpVector - b.UpVector).Magnitude < 1e-4
end

local function collectPose(character)
	local pose = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("Motor6D") and (SLIDE_POSE[descendant.Name] or MOOD_JOINTS[descendant.Name]) then
			table.insert(pose, { joint = descendant, base = descendant.C0 })
		end
	end
	return pose
end

local function resetPose(pose)
	for _, record in ipairs(pose) do
		if record.joint.Parent and record.last and sameCFrame(record.joint.C0, record.last) then
			record.joint.C0 = record.base
		end
		record.last = nil
	end
end

local function applyPose(pose, blend, lean, mood, moodBlend, clock)
	for _, record in ipairs(pose) do
		local joint = record.joint
		if joint.Parent then
			if not sameCFrame(joint.C0, record.last) then record.base = joint.C0 end
			local offset = CFrame.new():Lerp(SLIDE_POSE[joint.Name] or CFrame.new(), blend)
			if MOOD_JOINTS[joint.Name] then
				-- Fade the mood out as the slide pose takes over a shared joint, so nothing pops.
				local share = SLIDE_POSE[joint.Name] and (1 - math.clamp(blend, 0, 1)) or 1
				offset = offset * moodOffset(joint.Name, mood or "Idle", (moodBlend or 0) * share, clock or 0)
			end
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
		moodBlend = 0,
		mood = "Idle",
		clock = 0,
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
	if (action == "Tag" or action == "Scan") and (self.role ~= "Hunter" or self.phase ~= "Active") then return end
	-- A jump while hiding is the "step out" gesture; the server owns the actual release.
	if action == "Vault" and self.character and self.character:GetAttribute("CatchHiding") == true then
		action = "Unhide"
	end
	-- This is only an input flood guard. The server decides whether the move is valid.
	local field = "last" .. action .. "Intent"
	local now = os.clock()
	if now - (self[field] or 0) < 0.15 then
		return
	end
	self[field] = now
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
	self.moodBlend = 0
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
			local sliding = alive and character:GetAttribute("Sliding") == true
			local mood = alive and character:GetAttribute("CatchMood") or "Idle"
			local moody = MOOD_POSES[mood] ~= nil
			if (sliding or moody) and not record then
				record = { character = character, pose = collectPose(character), blend = 0, moodBlend = 0, mood = mood }
				self.remotePoses[player] = record
			end
			if record then
				if moody then record.mood = mood end
				record.blend += ((sliding and 1 or 0) - record.blend) * smoothing
				record.moodBlend += ((moody and 1 or 0) - record.moodBlend) * smoothing
				if not sliding and not moody and record.blend < 0.001 and record.moodBlend < 0.001 then
					resetPose(record.pose)
					self.remotePoses[player] = nil
				else
					applyPose(record.pose, record.blend, Vector3.zero, record.mood, record.moodBlend, self.clock)
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
	self.clock += dt
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
	self.slideBlend += ((sliding and 1 or 0) - self.slideBlend) * (1 - math.exp(-18 * dt))
	local mood = character:GetAttribute("CatchMood") or "Idle"
	local moody = MOOD_POSES[mood] ~= nil
	if moody then self.mood = mood end
	self.moodBlend += ((moody and 1 or 0) - self.moodBlend) * smoothing
	-- Breathing and head sway run whenever the avatar is standing in the mall.
	applyPose(self.pose, self.slideBlend, self.lean, self.mood, self.moodBlend, self.clock)
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

-- Touch buttons can appear a frame after BindAction, so styling is reapplied on every state update.
function MovementController:_styleTouchControls()
	for _, action in ipairs(ACTIONS) do
		local control = ContextActionService:GetButton(action)
		if control and not control:GetAttribute("CatchStyled") then
			control.Size = UDim2.fromOffset(64, 64)
			control.ImageColor3 = Color3.fromRGB(86, 66, 190)
			control:SetAttribute("CatchStyled", true)
		end
	end
end

function MovementController:_touchControls()
	self:_styleTouchControls()
	local visible = self.role ~= "Spectator" and not self.player:GetAttribute("CatchMenuOpen")
	for _, action in ipairs(ACTIONS) do
		local control = ContextActionService:GetButton(action)
		if control then
			local hunterOnly = action == "CatchTag" or action == "CatchScan"
			control.Visible = visible and (not hunterOnly or (self.role == "Hunter" and self.phase == "Active"))
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
	ContextActionService:BindAction("CatchScan", function(_, state)
		if state == Enum.UserInputState.Begin then
			self:_intent("Scan")
		end
		return self:_canAct() and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle("CatchSprint", "RUN")
	ContextActionService:SetTitle("CatchSlide", "SLIDE")
	ContextActionService:SetTitle("CatchTag", "TAG")
	ContextActionService:SetTitle("CatchScan", "SCAN")
	ContextActionService:SetPosition("CatchSprint", UDim2.new(1, -190, 1, -150))
	ContextActionService:SetPosition("CatchSlide", UDim2.new(1, -110, 1, -150))
	ContextActionService:SetPosition("CatchTag", UDim2.new(1, -190, 1, -225))
	ContextActionService:SetPosition("CatchScan", UDim2.new(1, -110, 1, -225))
	self:_styleTouchControls()
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
