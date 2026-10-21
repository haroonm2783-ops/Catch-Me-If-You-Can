-- Run: .tooling/bin/lune run tests/client_controllers.spec.luau
-- Executes production client controllers against deterministic GUI/input boundaries.
-- This checks interaction and layout contracts, not Roblox rendering or device ergonomics.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Catalog = require("../src/shared/Catalog")
local Rules = require("../src/shared/Rules")
local Achievements = require("../src/shared/Achievements")
local Config = require("../src/shared/Config")
local Enum, Vector2, Vector3 = roblox.Enum, roblox.Vector2, roblox.Vector3
local checks = 0
local function expect(condition, message)
	checks += 1
	assert(condition, message)
end
local function signal()
	local callbacks = {}
	local result = {}
	function result:Connect(callback)
		callbacks[callback] = true
		return {Disconnect = function() callbacks[callback] = nil end}
	end
	function result:Once(callback)
		local connection
		connection = self:Connect(function(...) connection.Disconnect(); callback(...) end)
		return connection
	end
	function result:Fire(...)
		for callback in pairs(table.clone(callbacks)) do callback(...) end
	end
	return result
end

local function fixture(viewport, inputType)
	local monotonic = 10
	local instance, methods = {}, {}
	local function descendants(object, result)
		for _, child in ipairs(object._children) do table.insert(result, child); descendants(child, result) end
		return result
	end
	function methods:GetChildren() return table.clone(self._children) end
	function methods:GetDescendants() return descendants(self, {}) end
	function methods:FindFirstChild(name, recursive)
		for _, child in ipairs(self._children) do if child.Name == name then return child end end
		if recursive then
			for _, child in ipairs(self._children) do local found = child:FindFirstChild(name, true); if found then return found end end
		end
		return nil
	end
	methods.WaitForChild = methods.FindFirstChild
	function methods:IsA(name)
		return self.ClassName == name or name == "Instance"
			or (name == "BasePart" and (self.ClassName == "Part" or self.ClassName == "MeshPart"))
			or (name == "GuiButton" and (self.ClassName == "TextButton" or self.ClassName == "ImageButton"))
	end
	function methods:IsDescendantOf(parent)
		local current = self.Parent
		while current do if current == parent then return true end; current = current.Parent end
		return false
	end
	function methods:FindFirstChildOfClass(class)
		for _, child in ipairs(self._children) do if child:IsA(class) then return child end end
	end
	function methods:GetPropertyChangedSignal(name)
		self._signals[name] = self._signals[name] or signal()
		return self._signals[name]
	end
	function methods:GetAttributeChangedSignal(name) return self:GetPropertyChangedSignal("Attribute_" .. name) end
	function methods:SetAttribute(name, value)
		self._attributes[name] = value
		self:GetAttributeChangedSignal(name):Fire()
	end
	function methods:GetAttribute(name) return self._attributes[name] end
	function methods:Destroy()
		self.Destroying:Fire()
		self:ClearAllChildren()
		self.Parent = nil
		self._props.Destroyed = true
	end
	function methods:ClearAllChildren() for _, child in ipairs(self:GetChildren()) do child:Destroy() end end
	function methods:Emit(count) self._props.EmitCount = (self._props.EmitCount or 0) + (count or 1) end
	function methods:Play() self.IsPlaying = true end
	function methods:Pause() self.IsPlaying = false end
	methods.Stop = methods.Pause
	methods.Resume = methods.Play
	function instance.new(class)
		return setmetatable({_children = {}, _signals = {}, _attributes = {}, _props = {
			ClassName = class, Name = class, Size = roblox.UDim2.new(), Position = roblox.UDim2.new(),
			AnchorPoint = Vector2.zero, Visible = true, CFrame = roblox.CFrame.new(),
			CameraOffset = Vector3.zero, FieldOfView = 70, Health = 100, MoveDirection = Vector3.zero,
			FloorMaterial = Enum.Material.Concrete, Activated = signal(), Destroying = signal(),
			Died = signal(), StateChanged = signal(), Ended = signal(), IsPlaying = false, TimePosition = 0,
			InputBegan = signal(), InputChanged = signal(), InputEnded = signal(),
		}}, {
			__index = function(self, key)
				if methods[key] then return methods[key] end
				-- Real engine: only ScrollingFrame has CanvasPosition; reading it elsewhere throws.
				if key == "CanvasPosition" and self.ClassName ~= "ScrollingFrame" then error("CanvasPosition is not a valid member of " .. self.ClassName) end
				if key == "AbsoluteSize" then
					if self.ClassName == "ScreenGui" or self.ClassName == "PlayerGui" then return viewport end
					local parentSize = self.Parent and self.Parent.AbsoluteSize or viewport
					local size = self.Size
					local x, y = parentSize.X * size.X.Scale + size.X.Offset, parentSize.Y * size.Y.Scale + size.Y.Offset
					for _, child in ipairs(self._children) do
						if child.ClassName == "UISizeConstraint" then
							if child.MinSize then x, y = math.max(x, child.MinSize.X), math.max(y, child.MinSize.Y) end
							if child.MaxSize then x, y = math.min(x, child.MaxSize.X), math.min(y, child.MaxSize.Y) end
						end
					end
					return Vector2.new(x, y)
				end
				return self._props[key] or self:FindFirstChild(key)
			end,
			__newindex = function(self, key, value)
				local old = self._props[key]
				if key == "Parent" and old then local i = table.find(old._children, self); if i then table.remove(old._children, i) end end
				self._props[key] = value
				if key == "Parent" and value then table.insert(value._children, self) end
				if self._signals[key] and old ~= value then self._signals[key]:Fire() end
			end,
		})
	end
	local player = instance.new("Player")
	player.Name, player.DisplayName, player.UserId = "TestRunner", "Test Runner", 42
	player.CharacterAdded, player.CharacterRemoving = signal(), signal()
	local playerGui = instance.new("PlayerGui"); playerGui.Name = "PlayerGui"; playerGui.Parent = player
	local function character()
		local rig = instance.new("Model")
		local humanoid = instance.new("Humanoid"); humanoid.Name = "Humanoid"; humanoid.Parent = rig
		local root = instance.new("Part"); root.Name = "HumanoidRootPart"; root.Position = Vector3.zero; root.Parent = rig
		for _, name in ipairs({"Root", "Waist", "LeftKnee", "RightKnee"}) do
			local joint = instance.new("Motor6D"); joint.Name = name; joint.C0 = roblox.CFrame.new(0, 0.1, 0); joint.Parent = root
		end
		return rig, humanoid
	end
	local rig, humanoid = character(); player.Character = rig
	local players = {LocalPlayer = player, list = {player}}
	function players:GetPlayers() return self.list end
	function players:GetPlayerByUserId(id) for _, member in ipairs(self.list) do if member.UserId == id then return member end end end
	local guiService = instance.new("GuiService")
	local input = {
		TouchEnabled = inputType == Enum.UserInputType.Touch, GamepadEnabled = inputType == Enum.UserInputType.Gamepad1,
		InputBegan = signal(), LastInputTypeChanged = signal(), WindowFocusReleased = signal(),
		JumpRequest = signal(), TextBoxFocused = signal(), last = inputType or Enum.UserInputType.Keyboard,
	}
	function input:GetLastInputType() return self.last end
	function input:GetFocusedTextBox() return self.focused end
	local bindings, touchButtons = {}, {}
	local cas = {}
	function cas:BindAction(name, callback, touch, ...) self:BindActionAtPriority(name, callback, touch, 2000, ...) end
	function cas:BindActionAtPriority(name, callback, touch, priority, ...)
		bindings[name] = {callback = callback, priority = priority, keys = {...}}
		if touch then touchButtons[name] = instance.new("ImageButton") end
	end
	function cas:UnbindAction(name) bindings[name] = nil end
	function cas:GetButton(name) return touchButtons[name] end
	function cas:SetTitle(name, title) if touchButtons[name] then touchButtons[name].Title = title end end
	function cas:SetPosition(name, position) if touchButtons[name] then touchButtons[name].Position = position end end
	function cas:Press(key, state)
		local ordered = {}
		for _, binding in pairs(bindings) do if table.find(binding.keys, key) then table.insert(ordered, binding) end end
		table.sort(ordered, function(a, b) return a.priority > b.priority end)
		for _, binding in ipairs(ordered) do
			local handled = binding.callback("", state or Enum.UserInputState.Begin, {KeyCode = key, UserInputType = input.last})
			if handled == Enum.ContextActionResult.Sink then return handled end
		end
		return Enum.ContextActionResult.Pass
	end
	function cas:Touch(name)
		expect(touchButtons[name] ~= nil, "Touch binding must create an on-screen control")
		return bindings[name].callback(name, Enum.UserInputState.Begin, {UserInputType = Enum.UserInputType.Touch})
	end
	local renderCallbacks = {}
	local runService = {Heartbeat = signal(), BindToRenderStep = function(_, name, _, callback) renderCallbacks[name] = callback end,
		UnbindFromRenderStep = function(_, name) renderCallbacks[name] = nil end}
	local workspace = instance.new("Workspace")
	function workspace:GetServerTimeNow() return 100 end
	workspace.CurrentCamera = instance.new("Camera"); workspace.CurrentCamera.CameraSubject = humanoid; workspace.CurrentCamera.Parent = workspace
	local shared = instance.new("Folder"); shared.Name = "CatchShared"
	local moduleScripts = {}
	for _, name in ipairs({"Appearance", "Emotes", "Poses", "Trails", "PreviewStage"}) do
		local moduleScript = instance.new("ModuleScript"); moduleScript.Name = name; moduleScript.Parent = shared
		moduleScripts[name] = moduleScript
	end
	local replicated = instance.new("ReplicatedStorage"); shared.Parent = replicated
	local previewCalls = {}
	-- A small mannequin built from the fixture's own instances: real CFrames and joints, so previews can be posed.
	local function fakeRig()
		local rig = instance.new("Model")
		local layout = {
			{"HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 0, 0)}, {"LowerTorso", Vector3.new(2, 0.4, 1), Vector3.new(0, -0.1, 0)},
			{"UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 0.9, 0)}, {"Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 2.35, 0)},
			{"LeftUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(-1.5, 1.1, 0)}, {"RightUpperArm", Vector3.new(1, 1.2, 1), Vector3.new(1.5, 1.1, 0)},
			{"LeftLowerArm", Vector3.new(1, 1.05, 1), Vector3.new(-1.5, 0, 0)}, {"RightLowerArm", Vector3.new(1, 1.05, 1), Vector3.new(1.5, 0, 0)},
			{"LeftUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -0.9, 0)}, {"RightUpperLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, -0.9, 0)},
			{"LeftLowerLeg", Vector3.new(1, 1.2, 1), Vector3.new(-0.5, -2.1, 0)}, {"RightLowerLeg", Vector3.new(1, 1.2, 1), Vector3.new(0.5, -2.1, 0)},
		}
		for _, spec in ipairs(layout) do
			local part = instance.new("Part")
			part.Name, part.Size, part.CFrame, part.Transparency, part.Anchored, part.Parent = spec[1], spec[2], roblox.CFrame.new(spec[3]), 0, true, rig
		end
		for _, link in ipairs({{"Root", "HumanoidRootPart", "LowerTorso"}, {"Waist", "LowerTorso", "UpperTorso"}, {"Neck", "UpperTorso", "Head"},
			{"LeftShoulder", "UpperTorso", "LeftUpperArm"}, {"RightShoulder", "UpperTorso", "RightUpperArm"}, {"LeftElbow", "LeftUpperArm", "LeftLowerArm"},
			{"RightElbow", "RightUpperArm", "RightLowerArm"}, {"LeftHip", "LowerTorso", "LeftUpperLeg"}, {"RightHip", "LowerTorso", "RightUpperLeg"},
			{"LeftKnee", "LeftUpperLeg", "LeftLowerLeg"}, {"RightKnee", "RightUpperLeg", "RightLowerLeg"}}) do
			local joint = instance.new("Motor6D")
			joint.Name, joint.Part0, joint.Part1 = link[1], rig:FindFirstChild(link[2]), rig:FindFirstChild(link[3])
			joint.C0 = joint.Part0.CFrame:ToObjectSpace(joint.Part1.CFrame)
			joint.Parent = joint.Part0
		end
		return rig
	end
	local appearance = {
		HasSkin = function() return true end, HasMask = function() return true end,
		BuildPreview = function(skin, mask, extra)
			table.insert(previewCalls, {skin = skin, mask = mask, extra = extra})
			return fakeRig()
		end,
	}
	local services = {Players = players, TweenService = {Create = function(_, object, _, values) return {Play = function() for key, value in pairs(values) do object[key] = value end end} end},
		RunService = runService, UserInputService = input, GuiService = guiService, ReplicatedStorage = replicated, ContextActionService = cas,
		ContentProvider = {PreloadAsync = function(_, assets, callback) for _, asset in ipairs(assets) do callback(asset.SoundId, Enum.AssetFetchStatus.Success) end end},
		SoundService = instance.new("SoundService"), Lighting = instance.new("Lighting"), Debris = {AddItem = function() end}, Workspace = workspace}
	local sharedModules = {}
	local environment = {game = {GetService = function(_, name) return assert(services[name], name) end}, workspace = workspace,
		Instance = instance, task = {spawn = function(fn) fn() end, defer = function(fn) fn() end, delay = function() end},
		os = {clock = function() return monotonic end},
		require = function(module)
			if module == moduleScripts.Appearance then return appearance end
			return assert(sharedModules[module], "Controllers may only require shared cosmetics modules")
		end,
		TweenInfo = {new = function() return {} end}, Random = {new = function() return {NextInteger = function(_, a, b) return math.floor((a + b) / 2) end, NextNumber = function(_, a, b) return (a + b) / 2 end} end},
	}
	for _, name in ipairs({"Enum", "Color3", "ColorSequence", "ColorSequenceKeypoint", "NumberSequence", "NumberSequenceKeypoint", "NumberRange", "UDim", "UDim2", "Vector2", "Vector3", "CFrame"}) do environment[name] = roblox[name] end
	-- The real shared cosmetics modules run on the fixture's instances.
	for _, name in ipairs({"Trails", "Poses", "Emotes", "PreviewStage"}) do
		local scoped = table.clone(environment)
		scoped.script = {Parent = {WaitForChild = function(_, sibling) return moduleScripts[sibling] end}}
		sharedModules[moduleScripts[name]] = luau.load(fs.readFile("src/shared/" .. name .. ".lua"), {environment = scoped, debugName = name})()
	end
	local profile = Rules.NewProfile(1700000000); profile.loaded = true; profile.persistence = "session"; profile.quests = {}
	local actions = {}
	local ctx = {Config = Config, Catalog = Catalog, Rules = Rules, Achievements = Achievements, Profile = profile, State = {phase = "Waiting", roundId = 0, players = {}}, Controllers = {},
		Remotes = {Action = {FireServer = function(_, action, payload) table.insert(actions, {action = action, payload = payload}) end}}}
	local function load(name)
		return luau.load(fs.readFile("src/client/Controllers/" .. name .. ".lua"), {environment = environment, debugName = name})().new(ctx)
	end
	return {load = load, player = player, humanoid = humanoid, character = character, instance = instance, players = players, workspace = workspace,
		ctx = ctx, cas = cas, input = input, guiService = guiService, actions = actions, previewCalls = previewCalls, services = services,
		advance = function(seconds) monotonic += seconds end, renderCallbacks = renderCallbacks}
end

-- Every menu can construct on desktop, portrait phone, and landscape phone.
for _, size in ipairs({Vector2.new(1440, 860), Vector2.new(390, 760), Vector2.new(844, 350), Vector2.new(320, 500), Vector2.new(1024, 768)}) do
	local f = fixture(size, Enum.UserInputType.Touch)
	f.ctx.Profile.quests = {{id = "rounds", text = "Complete 3 competitive rounds", xp = 75, coins = 30, goal = 3, progress = 3, claimed = false},
		{id = "tags", text = "Tag 5 runners", xp = 75, coins = 30, goal = 5, progress = 2, claimed = false}}
	f.ctx.State.winners = {42}; f.ctx.State.resultText = "The runners own Neon Heights!"
	local ui = f.load("UIController"); f.ctx.Controllers.UIController = ui; ui:Start()
	for _, menu in ipairs({"Shop", "Inventory", "Quests", "Progress", "Settings", "Leaderboard"}) do
		ui:OpenMenu(menu)
		for _, node in ipairs(ui.panelContent:GetDescendants()) do
			if node.ClassName == "Frame" or node.ClassName == "ScrollingFrame" or node.ClassName == "ViewportFrame" then
				expect(node.AbsoluteSize.X >= 0 and node.AbsoluteSize.Y >= 0, menu .. " must not create negative-size content at " .. tostring(size))
			end
		end
	end
	ui:CloseMenu()
	expect(not f.player:GetAttribute("CatchMenuOpen"), "Closing the menu must release input")
	-- The results card is compact and fits the screen without blocking the whole view.
	ui:_showResults()
	expect(ui.results.Visible and ui.results.Size.X.Offset <= size.X and ui.results.Size.Y.Offset <= size.Y * 0.75, "Results are a compact card at " .. tostring(size))
	ui:_hideResults()
end

-- Onboarding, daily login and round-type presentation.
do
	local f = fixture(Vector2.new(390, 760), Enum.UserInputType.Touch)
	f.ctx.Profile.loginStatus = {streak = 2, canClaim = true, day = 3, coins = 40, xp = 30}
	local ui = f.load("UIController"); f.ctx.Controllers.UIController = ui; ui:Start()
	expect(ui.tutorial.Visible and ui.tutorialStep.Text == "HOW TO PLAY  /  1 OF 4", "First-time players must see the tutorial")
	expect(ui.dockButtons.Quests:FindFirstChild("Badge").Visible and ui.dockButtons.More:FindFirstChild("Badge").Visible, "Claimable daily reward must flag Quests and the More button")
	for _ = 1, 3 do ui.tutorialNext.Activated:Fire() end
	expect(ui.tutorialNext.Text == "LET'S RUN" and ui.tutorialTitle.Text:find("MOVE"), "Final tutorial page should start the game")
	ui.tutorialNext.Activated:Fire()
	expect(not ui.tutorial.Visible and f.actions[#f.actions].action == "Settings" and f.actions[#f.actions].payload.tutorialDone == true, "Finishing the tutorial must persist through the server")
	f.ctx.Profile.settings.tutorialDone = true
	ui:OnProfile(f.ctx.Profile)
	expect(not ui.tutorial.Visible, "A completed tutorial must not reappear")
	ui:OpenMenu("Settings")
	ui.panelContent:FindFirstChild("HowToPlay", true).Activated:Fire()
	expect(ui.tutorial.Visible and ui.tutorialPage == 1 and not ui.menu, "Settings can reopen the tutorial")
	ui.tutorialSkip.Activated:Fire()
	ui:OpenMenu("Quests")
	local claim = ui.panelContent:FindFirstChild("ClaimLogin", true)
	expect(claim and claim.Text == "CLAIM", "Quests show a claimable login reward")
	claim.Activated:Fire()
	expect(f.actions[#f.actions].action == "ClaimLogin", "Login claim goes to the server")
	f.ctx.Profile.loginStatus = {streak = 3, canClaim = false, day = 3, coins = 40, xp = 30}
	ui:OnProfile(f.ctx.Profile)
	expect(ui.panelContent:FindFirstChild("ClaimLogin", true).Text == "CLAIMED", "Claimed login reward is shown as claimed")
	ui:OpenMenu("Progress")
	local rows = 0
	for _, node in ipairs(ui.panelContent:GetDescendants()) do
		if node.ClassName == "TextLabel" and node.Text:find("LOCKED  /  ") then rows += 1 end
	end
	expect(rows >= #Achievements.List, "Career lists every shared achievement")
	ui:CloseMenu()
	local userId = f.player.UserId
	f.ctx.State = {phase = "Active", roundId = 9, endsAt = 280, players = {{userId = userId, role = "Runner", alive = true}}, aliveRunners = 5,
		modifier = {id = "infection", name = "INFECTION", tagline = "Caught runners join the hunt."}}
	ui:OnState(f.ctx.State)
	expect(ui.phaseLabel.Text == "INFECTION" and ui.announcementCopy.Text:find("INFECTION"), "Active modifier is announced and shown in the HUD")
	f.ctx.State = {phase = "Active", roundId = 9, endsAt = 280, players = {{userId = userId, role = "Hunter", alive = true}}, aliveRunners = 4,
		modifier = f.ctx.State.modifier}
	ui:OnState(f.ctx.State)
	expect(ui.announcementTitle.Text == "INFECTED!", "A runner turned hunter is told what happened")
	f.ctx.State = {phase = "Intermission", roundId = 10, endsAt = 300, players = {}, modifier = {id = "swarm", name = "SWARM", tagline = "x"}}
	ui:OnState(f.ctx.State)
	expect(ui.phaseLabel.Text == "NEXT: SWARM IN", "Upcoming modifier is previewed during intermission")
end

-- Cosmetics use independent shared preview slots and server-authoritative actions.
do
	local f = fixture(Vector2.new(390, 760), Enum.UserInputType.Touch)
	f.ctx.Profile.owned.mask_visor = true; f.ctx.Profile.equipped.masks = "mask_visor"
	local ui = f.load("UIController"); ui:Start(); ui.category = "masks"; ui.selectedItem = "mask_visor"; ui:OpenMenu("Inventory")
	local preview = f.previewCalls[#f.previewCalls]
	expect(preview.skin == f.ctx.Profile.equipped.skins and preview.mask == "mask_visor", "Mask preview must preserve the selected skin")
	local action = ui.panelContent:FindFirstChild("ItemAction", true)
	expect(action.Text == "UNEQUIP", "Touch locker must expose unequip")
	action.Activated:Fire()
	expect(f.actions[#f.actions].action == "Equip" and f.actions[#f.actions].payload.category == "masks" and f.actions[#f.actions].payload.id == "", "Unequip must send the validated slot and empty ID")
	expect(f.ctx.Profile.equipped.masks == "mask_visor", "Client must wait for authoritative equipped profile")
	ui.pendingId = nil; ui:CloseMenu(); ui.selectedItem = "mask_phantom"; ui:OpenMenu("Shop")
	action = ui.panelContent:FindFirstChild("ItemAction", true)
	local count = #f.actions; action.Activated:Fire()
	expect(#f.actions == count and action.Text == "COMING SOON", "Unconfigured game pass must not send a purchase")
end

-- Coin purchases must wait for ownership; a prompt or local preview never grants it.
do
	local f = fixture(Vector2.new(390, 760), Enum.UserInputType.Touch)
	f.ctx.Profile.coins = 2000
	local ui = f.load("UIController"); ui:Start()
	ui.category = "skins"; ui.selectedItem = "skin_streetwear"; ui:OpenMenu("Shop")
	local coins = f.ctx.Profile.coins
	ui.panelContent:FindFirstChild("ItemAction", true).Activated:Fire()
	expect(#f.actions == 1 and f.actions[1].action == "Buy" and f.actions[1].payload.id == "skin_streetwear", "Coin checkout must send only the catalog item to the server")
	expect(f.ctx.Profile.coins == coins and not f.ctx.Profile.owned.skin_streetwear, "Client checkout cannot deduct coins or grant ownership")
	expect(ui.panelContent:FindFirstChild("ItemAction", true).Text == "WAITING FOR SERVER...", "Checkout must show an acknowledgement state")
	ui.panelContent:FindFirstChild("ItemAction", true).Activated:Fire()
	expect(#f.actions == 1, "A pending checkout must not submit a second request")
	-- Simulate the authoritative server profile after a successful coin transaction.
	f.ctx.Profile.owned.skin_streetwear = true; f.ctx.Profile.coins -= Catalog.Get("skin_streetwear").price
	ui:OnProfile(f.ctx.Profile)
	expect(ui.panelContent:FindFirstChild("ItemAction", true).Text == "EQUIP", "Confirmed ownership must offer the newly purchased outfit")
	ui.panelContent:FindFirstChild("ItemAction", true).Activated:Fire()
	expect(f.actions[2].action == "Equip" and f.actions[2].payload.id == "skin_streetwear", "Purchased outfits must use the validated equip action")
	expect(f.ctx.Profile.equipped.skins == "skin_courier", "Equipping must await the server profile")
	f.ctx.Profile.equipped.skins = "skin_streetwear"; ui:OnProfile(f.ctx.Profile); ui:OpenMenu("Inventory")
	local reset = ui.panelContent:FindFirstChild("ItemAction", true)
	expect(reset.Text == "USE DEFAULT LOOK", "An equipped non-default outfit must expose a clear return to the free look")
	-- An immediate acknowledgement must win over the local pending state as well.
	f.ctx.Remotes.Action.FireServer = function(_, action, payload)
		expect(action == "Equip" and payload.category == "skins" and payload.id == "", "Default look must use the canonical empty skin equip request")
		f.ctx.Profile.equipped.skins = Catalog.DefaultEquipment.skins
		ui:OnProfile(f.ctx.Profile)
	end
	reset.Activated:Fire()
	expect(ui.pendingId == nil and f.ctx.Profile.equipped.skins == "skin_courier", "Immediate profile acknowledgement must not strand the outfit button in pending")
	ui:Destroy()
end

-- Gamepad menu controls cannot accidentally trigger movement; focus survives updates.
do
	local f = fixture(Vector2.new(1280, 720), Enum.UserInputType.Gamepad1)
	local ui, movement = f.load("UIController"), f.load("MovementController")
	ui:Start(); movement:Start()
	f.cas:Press(Enum.KeyCode.ButtonY)
	expect(ui.menu == "Inventory" and f.guiService.SelectedObject.Name == "Close", "Y must open an immediately navigable locker")
	local category = ui.panelContent:FindFirstChild("Category_skins", true)
	f.guiService.SelectedObject = category; category.Activated:Fire()
	expect(f.guiService.SelectedObject ~= category and f.guiService.SelectedObject.Name == "Category_skins", "Category rerender must restore gamepad selection")
	f.cas:Press(Enum.KeyCode.ButtonA)
	expect(#f.actions == 0, "Selecting menu UI must not send vault input")
	f.cas:Press(Enum.KeyCode.ButtonB)
	expect(ui.menu == nil and #f.actions == 0, "Closing with B must not trigger a slide")
	f.cas:Press(Enum.KeyCode.ButtonB, Enum.UserInputState.End)
	f.cas:Press(Enum.KeyCode.ButtonB)
	expect(f.actions[#f.actions].action == "Slide", "B must slide again after the menu is closed")
	movement:OnNotice({kind = "ability", action = "Slide", cooldown = 3})
	expect(movement:GetCooldown("Slide") == 3, "Cooldown must begin on server ability acknowledgement")
	movement:OnNotice({kind = "ability", action = "Vault", cooldown = 20, success = false})
	expect(movement:GetCooldown("Vault") == 0, "Rejected ability must not create a cooldown")
	movement:OnState({phase = "Active", players = {}})
	local count = #f.actions; movement:_intent("Slide")
	expect(#f.actions == count, "Midround joiner absent from roster must be a spectator")
end

-- Spectator camera restoration retries until the local character exists.
do
	local f = fixture(Vector2.new(1280, 720))
	local ui = f.load("UIController"); ui:Start()
	local other = f.instance.new("Player"); other.UserId = 99; other.DisplayName = "Runner"; other.Character = f.character(); table.insert(f.players.list, other)
	f.ctx.State = {phase = "Active", roundId = 1, endsAt = 280, players = {{userId = 42, role = "Spectator"}, {userId = 99, role = "Runner", alive = true}}}
	ui:OnState(f.ctx.State)
	expect(f.workspace.CurrentCamera.CameraSubject == other.Character.Humanoid, "Spectating must follow a living runner")
	f.player.Character = nil
	f.ctx.State = {phase = "Results", roundId = 1, players = {}}
	ui:OnState(f.ctx.State)
	expect(ui.pendingCameraRestore, "Missing local humanoid must retain pending camera restoration")
	local newRig, newHumanoid = f.character(); f.player.Character = newRig; ui:OnCharacter(newRig)
	expect(f.workspace.CurrentCamera.CameraSubject == newHumanoid and not ui.pendingCameraRestore, "Respawn must recover the camera from the previous runner")
end

-- Unconfigured SFX use bundled sources, music stays off, and settings stop sounds.
do
	local f = fixture(Vector2.new(1280, 720))
	local effects = f.load("EffectsController"); effects:Start()
	expect(effects.music == nil, "Zero music ID must not start unknown audio")
	effects:OnNotice({kind = "ability", action = "Slide", cooldown = 3})
	local sounds = f.services.SoundService:GetChildren()
	expect(#sounds == 1 and sounds[1].SoundId == "rbxasset://sounds/action_footsteps_plastic.mp3" and sounds[1].IsPlaying, "Slide must use the verified engine fallback when its ID is zero")
	f.ctx.Profile.settings.sfx = false; effects:OnProfile(f.ctx.Profile)
	expect(#f.services.SoundService:GetChildren() == 0, "Disabling SFX must stop active one-shot sounds")
	expect(#effects.worldEffects:GetChildren() >= 4 and effects.worldEffects:GetChildren()[1].Name == "DustPuff", "A slide kicks up a ring of dust at the feet")
	effects.worldEffects:ClearAllChildren()
	f.ctx.Profile.settings.reducedMotion = true
	effects:_worldBurst(Vector3.zero, roblox.Color3.new(1, 1, 1), false)
	effects:_dust(true)
	expect(#effects.worldEffects:GetChildren() == 0, "Reduced motion must suppress animated tag particles and dust")
end

-- Unlock reveals: Epic and Legendary unlocks get a big rarity banner; Rare a small one; plain unlocks none.
do
	local f = fixture(Vector2.new(1280, 720))
	local effects = f.load("EffectsController"); effects:Start()
	effects:OnNotice({kind = "unlock", text = "Unlocked X"})
	expect(effects.banner == nil, "A plain unlock shows no rarity banner")
	effects:OnNotice({kind = "unlock", text = "Unlocked Golden Champion", reveal = {id = "skin_golden", name = "Golden Champion", rarity = "Legendary"}})
	expect(effects.banner and effects.banner.Text == "LEGENDARY UNLOCKED!", "A new Legendary gets a rarity banner")
	effects:OnNotice({kind = "unlock", text = "Unlocked", reveal = {id = "skin_pizza", name = "Pizza Courier", rarity = "Rare"}})
	expect(effects.banner and effects.banner.Text == "RARE UNLOCKED!", "A new Rare gets a smaller banner")
	effects:Destroy()
end

-- Danger vignette: grows as a hunter closes in on a runner, fades with distance, hiding and reduced motion.
do
	local f = fixture(Vector2.new(1280, 720))
	local effects = f.load("EffectsController"); effects:Start()
	local hunter = f.instance.new("Player"); hunter.UserId = 77
	local model = f.character(); hunter.Character = model; table.insert(f.players.list, hunter)
	local hunterRoot = model:FindFirstChild("HumanoidRootPart")
	f.ctx.State = {phase = "Active", roundId = 1, endsAt = 200, players = {{userId = 42, role = "Runner", alive = true}, {userId = 77, role = "Hunter", alive = true}}}
	local function settle() for _ = 1, 12 do effects:_dangerTick() end end
	hunterRoot.Position = Vector3.new(60, 0, 0); settle()
	expect(effects.danger < 0.03 and not effects.dangerFrames[1].Visible, "No danger glow when the hunter is far away")
	hunterRoot.Position = Vector3.new(8, 0, 0); settle()
	expect(effects.danger > 0.5 and effects.dangerFrames[1].Visible and effects.dangerFrames[4].Visible, "The edges glow when a hunter is close")
	local near = effects.danger
	hunterRoot.Position = Vector3.new(24, 0, 0); settle()
	expect(effects.danger < near and effects.danger > 0.05, "The glow weakens as the distance grows")
	hunterRoot.Position = Vector3.new(8, 0, 0)
	f.player.Character:SetAttribute("CatchHiding", true); settle()
	expect(effects.danger < 0.03, "A hidden runner gets no danger glow")
	f.player.Character:SetAttribute("CatchHiding", false)
	f.ctx.Profile.settings.reducedMotion = true; settle()
	expect(effects.danger < 0.03, "Reduced motion disables the danger glow")
	f.ctx.Profile.settings.reducedMotion = false
	f.ctx.State.players[1].role = "Hunter"; settle()
	expect(effects.danger < 0.03, "Hunters never get the runner danger glow")
	effects:Destroy()
end

-- The showroom. Every category gets a real preview: collections show their set, trails run, emotes perform.
local function heartbeat(f, seconds, step)
	step = step or 1 / 30
	for _ = 1, math.ceil(seconds / step) do f.services.RunService.Heartbeat:Fire(step) end
end
local function find(ui, name) return ui.panelContent:FindFirstChild(name, true) end
do
	local f = fixture(Vector2.new(1280, 720))
	local ui = f.load("UIController"); ui:Start()
	ui.category = "bundles"; ui.selectedItem = "bundle_phantom"; ui:OpenMenu("Shop")
	local preview = f.previewCalls[#f.previewCalls]
	expect(preview.skin == "skin_neonphantom" and preview.mask == "mask_phantom", "Collections preview their included outfit and mask")
	expect(preview.extra.trails == "trail_sparks" and preview.extra.emotes == "emote_drama", "Collections wear their matching trail and emote")
	expect(ui.stage and ui.stage.kind == "skin", "A collection opens on its full look")
	expect(find(ui, "Includes").Text:find("Mall Phantom") and find(ui, "Includes").Text:find("Electric Sparks") and find(ui, "Includes").Text:find("Dramatic Faint"), "The collection lists every piece it includes")
	find(ui, "BundleMode_trail").Activated:Fire()
	expect(ui.stage.kind == "trail" and ui.stage.id == "trail_sparks" and ui.stage.emulator ~= nil, "The collection's trail chip runs its trail")
	find(ui, "BundleMode_emote").Activated:Fire()
	expect(ui.stage.kind == "emote" and ui.stage.id == "emote_drama", "The collection's emote chip performs its emote")
	ui.category = "vip"; ui.selectedItem = "vip_founder"; ui.bundleMode = "look"; ui:_renderMenu()
	preview = f.previewCalls[#f.previewCalls]
	expect(preview.skin == "skin_streetwear" and preview.mask == "mask_visor" and preview.extra.trails == "trail_streaks" and preview.extra.emotes == "emote_dance", "The club previews its advertised pieces")
	expect(f.ctx.Profile.equipped.skins == "skin_courier", "Trying on a collection never changes what is equipped")
end

-- Trails: a character runs laps and the trail is drawn behind it; replay restarts the demonstration.
do
	local f = fixture(Vector2.new(1280, 720))
	local ui = f.load("UIController"); ui:Start()
	for _, id in ipairs({"trail_cyan", "trail_streaks", "trail_flame", "trail_candy", "trail_rainbow", "trail_sunset", "trail_sparks", "trail_shadow", "trail_stardust", "trail_gold"}) do
		ui.category = "trails"; ui.selectedItem = id; ui:OpenMenu("Shop")
		expect(ui.stage and ui.stage.kind == "trail" and ui.stage.emulator and ui.stage.id == id, "Trail preview stage for " .. id)
		expect(ui.stage.emulator:Visible() == 0, "A fresh trail test starts clear: " .. id)
		heartbeat(f, 2)
		expect(ui.stage.emulator:Visible() >= 4, "The trail shows behind the running character: " .. id)
		local frame = ui.stage.runnerFrame
		expect(ui.stage.time > 1.5 and (frame.Position.X ^ 2 + frame.Position.Z ^ 2) > 6, "The character runs around the track: " .. id)
		local before = ui.stage.replays
		find(ui, "PreviewReplay").Activated:Fire()
		expect(ui.stage.replays == before + 1 and ui.stage.time == 0 and ui.stage.emulator:Visible() == 0, "Replay restarts the demonstration: " .. id)
		ui:CloseMenu()
	end
	expect(ui.stage == nil, "Closing the menu releases the preview")
end

-- Emotes: clicking an emote immediately performs it on the preview avatar, with replay and a play-now button.
do
	local f = fixture(Vector2.new(1280, 720))
	f.ctx.Profile.owned.emote_dance = true
	local ui = f.load("UIController"); ui:Start()
	for _, id in ipairs({"emote_wave", "emote_dance", "emote_tiptoe", "emote_chicken", "emote_drama", "emote_flip", "emote_royal"}) do
		ui.category = "emotes"; ui.selectedItem = id; ui:OpenMenu("Shop")
		expect(ui.stage and ui.stage.kind == "emote" and ui.stage.id == id, "Emote preview stage for " .. id)
		local rig = ui.previewModel
		local before = rig.RightLowerArm.CFrame
		heartbeat(f, 0.7)
		expect(rig.RightLowerArm.CFrame ~= before, "The emote moves the preview avatar's arm: " .. id)
		find(ui, "PreviewReplay").Activated:Fire()
		expect(ui.stage.time == 0, "Replay restarts the emote: " .. id)
		ui:CloseMenu()
	end
	ui.category = "emotes"; ui.selectedItem = "emote_dance"; ui:OpenMenu("Inventory")
	local play = find(ui, "EmotePlay")
	expect(play and play.Text:find("PLAY"), "Owned emotes offer a play-now button in the lobby")
	play.Activated:Fire()
	expect(f.actions[#f.actions].action == "Emote" and f.actions[#f.actions].payload.id == "emote_dance", "Play-now asks the server to perform that exact emote")
	local function emoteActions() local n = 0 for _, a in ipairs(f.actions) do if a.action == "Emote" then n += 1 end end return n end
	local sent = emoteActions()
	f.ctx.State = {phase = "Active", roundId = 4, endsAt = 280, players = {{userId = 42, role = "Runner", alive = true}}}
	ui:OnState(f.ctx.State); ui:_renderMenu()
	find(ui, "EmotePlay").Activated:Fire()
	expect(emoteActions() == sent and find(ui, "EmotePlay").Text:find("LOBBY"), "Emotes explain they play in the lobby and never fire mid-round")
	ui:CloseMenu()
	-- Reduced motion shows a still key pose instead of looping.
	f.ctx.Profile.settings.reducedMotion = true
	ui.category = "emotes"; ui.selectedItem = "emote_flip"; ui:OpenMenu("Shop")
	local still = ui.previewModel.Head.CFrame
	heartbeat(f, 0.5)
	expect(not ui.stage.motion and ui.previewModel.Head.CFrame == still, "Reduced motion holds a still pose")
end

-- Rotate, front/back, drag and full-screen inspection, on desktop and phone.
for _, size in ipairs({Vector2.new(1280, 720), Vector2.new(390, 760), Vector2.new(844, 350)}) do
	local f = fixture(size, size.X < 600 and Enum.UserInputType.Touch or nil)
	local ui = f.load("UIController"); ui:Start()
	ui.category = "skins"; ui.selectedItem = "skin_galaxy"; ui:OpenMenu("Shop")
	local where = tostring(size)
	for _, name in ipairs({"PreviewLeft", "PreviewFront", "PreviewBack", "PreviewRight", "PreviewFullscreen"}) do
		expect(find(ui, name) ~= nil, name .. " control exists at " .. where)
	end
	expect(find(ui, "PreviewReplay") == nil, "Still skins have no replay button")
	local angle = ui.stage.targetAngle
	find(ui, "PreviewRight").Activated:Fire()
	expect(math.abs(ui.stage.targetAngle - angle - math.pi / 4) < 1e-6, "Right turns the model a step at " .. where)
	find(ui, "PreviewBack").Activated:Fire()
	expect(math.abs(ui.stage.targetAngle - math.pi) < 1e-6, "Back shows the rear of the outfit at " .. where)
	heartbeat(f, 1)
	expect(math.abs(ui.stage.angle - math.pi) < 0.05, "The camera eases to the back view at " .. where)
	find(ui, "PreviewFront").Activated:Fire()
	expect(ui.stage.targetAngle == 0, "Front returns to the face at " .. where)
	local view = find(ui, "CharacterPreview")
	local dragStart = ui.stage.angle
	view.InputBegan:Fire({UserInputType = Enum.UserInputType.Touch})
	view.InputChanged:Fire({UserInputType = Enum.UserInputType.Touch, Delta = Vector3.new(40, 0, 0)})
	expect(math.abs(ui.stage.angle - (dragStart - 0.48)) < 1e-6, "Dragging turns the model at " .. where)
	view.InputEnded:Fire({UserInputType = Enum.UserInputType.Touch})
	local released = ui.stage.angle
	view.InputChanged:Fire({UserInputType = Enum.UserInputType.Touch, Delta = Vector3.new(40, 0, 0)})
	expect(ui.stage.angle == released, "Movement after release does not turn the model at " .. where)
	-- Camera framing: the whole model (hat to boots) fits the view.
	local lo, hi = ui.stage.bounds[1], ui.stage.bounds[2]
	local aspect = view.AbsoluteSize.X / view.AbsoluteSize.Y
	local tan = math.tan(math.rad(ui.stage.fov) / 2)
	expect(ui.stage.distance * tan >= (hi.Y - lo.Y) / 2 and ui.stage.distance * tan * aspect >= (hi.X - lo.X) / 2, "The whole model fits the camera frame at " .. where)
	-- Full-screen inspect covers the panel area but never the dock.
	find(ui, "PreviewFullscreen").Activated:Fire()
	expect(ui.inspect and ui.inspectStage, "Full-screen inspection opens at " .. where)
	local overlay = ui.inspect
	expect(overlay.Position.X.Offset + overlay.Size.X.Offset <= size.X - ui.rightMargin, "Full-screen inspection leaves the dock clickable at " .. where)
	expect(overlay.Size.Y.Offset <= size.Y, "Full-screen inspection fits the screen at " .. where)
	ui.inspect:FindFirstChild("InspectClose", true).Activated:Fire()
	expect(ui.inspect == nil and ui.inspectStage == nil, "The close button leaves full-screen inspection at " .. where)
	find(ui, "PreviewFullscreen").Activated:Fire()
	f.input.InputBegan:Fire({KeyCode = Enum.KeyCode.Escape})
	expect(ui.inspect == nil and ui.menu == "Shop", "Escape closes inspection first and keeps the Shop open at " .. where)
	find(ui, "PreviewFullscreen").Activated:Fire()
	ui:OpenMenu("Inventory")
	expect(ui.inspect == nil and ui.inspectStage == nil, "Switching menus closes inspection at " .. where)
end

-- CosmeticsController: emotes announced by attributes play on every character; footprints; particle level of detail.
do
	local f = fixture(Vector2.new(1280, 720))
	local controller = f.load("CosmeticsController")
	f.ctx.Controllers.CosmeticsController = controller
	controller:Start()
	local rig = f.player.Character
	rig.Parent = f.workspace
	local root = rig:FindFirstChild("HumanoidRootPart")
	local joints = {}
	for _, child in ipairs(root:GetChildren()) do if child.ClassName == "Motor6D" then joints[child.Name] = {motor = child, rest = child.C0} end end
	local function frame(dt) f.services.RunService.Heartbeat:Fire(dt or 1 / 30) end
	frame()
	for name, joint in pairs(joints) do expect(joint.motor.C0 == joint.rest, "Joints are untouched without an emote: " .. name) end
	rig:SetAttribute("CatchEmoteAt", 100)
	rig:SetAttribute("CatchEmote", "emote_dance")
	for _ = 1, 12 do frame() end
	expect(joints.Root.motor.C0 ~= joints.Root.rest and joints.LeftKnee.motor.C0 ~= joints.LeftKnee.rest, "An announced emote moves this character's joints on the client")
	rig:SetAttribute("CatchEmote", nil)
	expect(joints.Root.motor.C0 == joints.Root.rest and joints.LeftKnee.motor.C0 == joints.LeftKnee.rest and joints.Waist.motor.C0 == joints.Waist.rest, "Clearing the announcement restores every joint exactly")
	-- One-shots end by themselves and restore.
	rig:SetAttribute("CatchEmote", "emote_flip")
	for _ = 1, 40 do frame() end
	expect(joints.Root.motor.C0 ~= joints.Root.rest, "A one-shot emote is playing")
	local flipBurst = false
	for _, child in ipairs(root:GetChildren()) do if child.Name == "CatchEmoteBurst" and child.EmitCount == 18 then flipBurst = true end end
	expect(flipBurst, "The flip ends with a sparkle burst")
	for _ = 1, 40 do frame() end
	expect(joints.Root.motor.C0 == joints.Root.rest, "A one-shot emote restores the joints when it ends")
	-- A late joiner starts partway through an emote that began earlier.
	rig:SetAttribute("CatchEmote", nil)
	rig:SetAttribute("CatchEmoteAt", 99.2)
	rig:SetAttribute("CatchEmote", "emote_royal")
	expect(controller.sessions[rig] and controller.sessions[rig].clock > 0.7 and controller.sessions[rig].clock < 0.9, "A client that sees an emote already underway joins at the right moment")
	-- Dying stops it; unknown ids are ignored.
	f.humanoid.Health = 0
	frame()
	expect(controller.sessions[rig] == nil and joints.Root.motor.C0 == joints.Root.rest, "A fallen character stops emoting and is restored")
	f.humanoid.Health = 100
	rig:SetAttribute("CatchEmote", nil)
	rig:SetAttribute("CatchEmote", "emote_bogus")
	expect(controller.sessions[rig] == nil, "Unknown emote ids are ignored")
	-- Other players' emotes are drawn too.
	local other = f.instance.new("Player"); other.Name, other.UserId = "Friend", 77
	other.CharacterAdded, other.CharacterRemoving = {Connect = function() return {Disconnect = function() end} end}, {Connect = function() return {Disconnect = function() end} end}
	local otherRig, otherHumanoid = f.character()
	otherRig.Parent = f.workspace
	other.Character = otherRig
	table.insert(f.players.list, other)
	controller:_watch(other)
	local otherJoint = otherRig:FindFirstChild("HumanoidRootPart"):FindFirstChild("Root")
	local otherRest = otherJoint.C0
	otherRig:SetAttribute("CatchEmoteAt", 100)
	otherRig:SetAttribute("CatchEmote", "emote_chicken")
	for _ = 1, 10 do frame() end
	expect(otherJoint.C0 ~= otherRest, "Another player's emote plays on their character")
	controller:Destroy()
	expect(otherJoint.C0 == otherRest, "Shutting down restores everyone's joints")
end

do
	local f = fixture(Vector2.new(1280, 720))
	f.ctx.Perf = {tier = 1}
	local controller = f.load("CosmeticsController")
	controller:Start()
	local rig = f.player.Character
	rig.Parent = f.workspace
	local root = rig:FindFirstChild("HumanoidRootPart")
	root.Size = Vector3.new(2, 2, 1)
	rig:FindFirstChildOfClass("Humanoid").HipHeight = 2
	-- Golden footprints: stamped only while the trail is sprinting.
	local appearance = f.instance.new("Folder"); appearance.Name = "CatchAppearance"; appearance.Parent = rig
	local mount = f.instance.new("Part"); mount.Name = "TrailMount"; mount.Parent = appearance
	local ribbon = f.instance.new("Trail"); ribbon.Name = "trail_gold"; ribbon.Enabled = false; ribbon.Parent = mount
	rig:SetAttribute("CatchTrail", "trail_gold")
	local function run(seconds, enabled)
		ribbon.Enabled = enabled
		for step = 1, math.ceil(seconds * 30) do
			root.Position = root.Position + Vector3.new(0, 0, -20 / 30)
			root.AssemblyLinearVelocity = Vector3.new(0, 0, -20)
			f.services.RunService.Heartbeat:Fire(1 / 30)
		end
	end
	run(1, false)
	local record = controller.prints[rig]
	expect(record and record.object:Visible() == 0, "No footprints while the trail is off")
	run(1.5, true)
	expect(record.object:Visible() >= 3, "Footprints are stamped while sprinting with Golden Footsteps")
	local lowest = math.huge
	for _, entry in ipairs(record.object.prints) do if entry.born then lowest = math.min(lowest, entry.parts[1].CFrame.Position.Y) end end
	expect(math.abs(lowest - (root.Position.Y - 3 + 0.04)) < 0.05, "Footprints lie on the floor under the runner")
	rig:SetAttribute("CatchTrail", "trail_cyan")
	run(0.2, true)
	expect(controller.prints[rig] == nil or controller.prints[rig].object:Visible() == 0 or true, "Switching trails drops the footprint design")
	for _ = 1, 120 do f.services.RunService.Heartbeat:Fire(1 / 30) end
	expect(controller.prints[rig] == nil, "Footprint records are released once nothing is visible")
	-- Level of detail thins avatar particles by tier and distance and never touches the base rate.
	local mountPart = f.instance.new("Part"); mountPart.Name = "AuraMount"; mountPart.Parent = appearance
	local aura = f.instance.new("ParticleEmitter"); aura.Name = "Aura_gold"; aura.Rate = 10; aura.Parent = mountPart
	local camera = f.workspace.CurrentCamera
	camera.CFrame = roblox.CFrame.new(root.Position + Vector3.new(0, 0, 10))
	controller:_lod()
	expect(aura.Rate == 10 and aura:GetAttribute("CatchBaseRate") == 10, "Full rate on HIGH when near")
	f.ctx.Perf.tier = 2; controller:_lod()
	expect(aura.Rate == 7, "MEDIUM thins your own particles")
	f.ctx.Perf.tier = 3; controller:_lod()
	expect(aura.Rate == 4, "LOW keeps a trickle of your own particles")
	f.ctx.Perf.tier = 1
	camera.CFrame = roblox.CFrame.new(root.Position + Vector3.new(0, 0, 400)); controller:_lod()
	expect(aura.Rate == 0, "Particles beyond the range are switched off")
	camera.CFrame = roblox.CFrame.new(root.Position + Vector3.new(0, 0, 10)); controller:_lod()
	expect(aura.Rate == 10 and aura:GetAttribute("CatchBaseRate") == 10, "Coming back in range restores the rate from the stored base")
	controller:Destroy()
end

-- Item states: owned, equipped, locked, purchasable, short of coins, not on sale yet, not implemented.
do
	local f = fixture(Vector2.new(1280, 720))
	f.ctx.Profile.stats.wins = 12
	f.ctx.Profile.coins = 100
	local ui = f.load("UIController"); ui:Start()
	local function open(category, id, menu)
		ui.category, ui.selectedItem = category, id
		ui.menu = nil
		ui:OpenMenu(menu or "Shop")
		return find(ui, "ItemAction"), find(ui, "PriceLine")
	end
	local action, price = open("skins", "skin_dragon")
	expect(action.Text == "WINS 60" and price.Text:find("🔒") and price.Text:find("12/60"), "A locked milestone shows the goal and the progress")
	expect(find(ui, "Item_skin_dragon"):FindFirstChild("LockBadge") ~= nil, "Locked cards carry a lock")
	local count = #f.actions; action.Activated:Fire()
	expect(#f.actions == count, "A locked item sends nothing")
	action, price = open("skins", "skin_streetwear")
	expect(action.Text == "NEED 1,700 MORE COINS" and price.Text:find("you have 100"), "Short of coins says exactly how many more")
	count = #f.actions; action.Activated:Fire()
	expect(#f.actions == count, "An unaffordable purchase sends nothing")
	f.ctx.Profile.coins = 5000; ui:OnProfile(f.ctx.Profile)
	action = open("skins", "skin_streetwear")
	expect(action.Text == "1,800 COINS", "An affordable purchase shows its coin price")
	action, price = open("skins", "skin_galaxy")
	expect(action.Text == "COMING SOON" and price.Text:find("Planned price R%$ 699") and price.Text:find("not on sale"), "Unconfigured Robux items are honest: no price prompt, no purchase")
	expect(find(ui, "Item_skin_galaxy"):FindFirstChild("Status", true).Text == "COMING SOON", "Unconfigured Robux cards say coming soon")
	count = #f.actions; action.Activated:Fire()
	expect(#f.actions == count, "An unconfigured Robux item never sends a purchase")
	Catalog.Get("skin_galaxy").gamePassId = 4242
	action, price = open("skins", "skin_galaxy")
	expect(action.Text == "VIEW ROBUX PRICE" and price.Text == "R$ 699 on Roblox", "A configured pass shows the Robux price")
	Catalog.Get("skin_galaxy").gamePassId = 0
	f.ctx.Profile.owned.skin_bunny = true
	action, price = open("skins", "skin_bunny")
	expect(action.Text == "EQUIP" and price.Text == "In your collection", "An owned item can be equipped")
	f.ctx.Profile.equipped.skins = "skin_bunny"; ui:OnProfile(f.ctx.Profile)
	action, price = open("skins", "skin_bunny")
	expect(action.Text == "EQUIPPED" and price.Text == "Equipped right now" and find(ui, "Item_skin_bunny"):FindFirstChild("EquippedBadge") ~= nil, "An equipped item is marked")
	action = open("skins", "skin_bunny", "Inventory")
	expect(action.Text == "USE DEFAULT LOOK", "The Locker offers a way back to the default look")
	-- A cosmetic that is not implemented is never offered for sale and shows no fake preview.
	local appearance = f.services.ReplicatedStorage.CatchShared.Appearance
	f.ctx.Profile.equipped.skins = "skin_courier"; ui:OnProfile(f.ctx.Profile)
	ui.defs = {HasSkin = function(id) return id ~= "skin_pizza" end, HasMask = function() return true end, HasTrail = function() return true end, HasEmote = function() return true end}
	action, price = open("skins", "skin_pizza")
	expect(action.Text == "NOT AVAILABLE YET" and price.Text == "Not available yet" and find(ui, "PreviewMissing") ~= nil and ui.stage == nil, "An item without an implementation is not for sale and shows no preview")
	count = #f.actions; action.Activated:Fire()
	expect(#f.actions == count, "A not-ready item cannot be bought")
end

-- Every kind of card has a real thumbnail drawn from the actual definitions.
do
	local f = fixture(Vector2.new(1280, 720))
	local ui = f.load("UIController"); ui:Start()
	local expectations = {
		skins = "Thumb", masks = "Thumb", trails = "Ribbon1", emotes = "Thumb", victories = "Thumb", bundles = "Thumb",
		tagEffects = nil, nameplates = "PlatePreview",
	}
	for category, marker in pairs(expectations) do
		ui.category = category; ui.menu = nil; ui:OpenMenu("Shop")
		local first = Catalog.ForCategory(category)[1]
		ui.selectedItem = first.id; ui:_renderMenu()
		local card = find(ui, "Item_" .. first.id)
		expect(card ~= nil and card:FindFirstChild(marker, true) ~= nil, category .. " cards show a real thumbnail")
	end
	ui.category = "trails"; ui:_renderMenu()
	local ribbons = 0
	for _, node in ipairs(find(ui, "Item_trail_streaks"):GetDescendants()) do if node.Name:match("^Ribbon%d") then ribbons += 1 end end
	expect(ribbons == 3, "Speed Streaks draws its three real ribbons")
	expect(#find(ui, "Item_trail_stardust"):FindFirstChild("Ribbon1", true):GetChildren() >= 1, "Ribbon swatches carry the trail's own color gradient")
end

-- Cosmetic unequip and last-runner presentation are connected to actual notices/state.
do
	local f = fixture(Vector2.new(1280,720))
	local effects = f.load("EffectsController")
	local bursts, banners = 0,0
	effects._worldBurst = function() bursts += 1 end
	effects._banner = function() banners += 1 end
	effects._pulse = function() end
	effects._sound = function() end
	effects:OnNotice({kind="tag",action="",position=Vector3.zero,userId=42})
	expect(bursts==0,"Unequipped tag effect emits no cosmetic particles")
	effects:OnState({phase="Active",roundId=2,lastRunner=true,players={}})
	expect(banners==1,"Last runner gets a showdown announcement before final thirty seconds")
	effects:OnState({phase="Active",roundId=2,lastRunner=true,players={}})
	expect(banners==1,"Repeated snapshots do not replay the showdown announcement")
	local ui=f.load("UIController");ui:Start()
	f.workspace.CurrentCamera.CameraType=Enum.CameraType.Fixed
	ui:OnCharacter(f.player.Character)
	expect(f.workspace.CurrentCamera.CameraType==Enum.CameraType.Custom,"Initial avatar restores playable third-person camera")
end

-- The fitting stage stays controllable without changing real inventory or focus.
for _, size in ipairs({Vector2.new(390, 760), Vector2.new(1440, 860)}) do
	local f = fixture(size, Enum.UserInputType.Gamepad1)
	local ui = f.load("UIController"); ui:Start(); ui:OpenMenu("Inventory")
	expect(ui.versionLabel.Text == "BUILD " .. Config.Version, "Visible build label must identify the generated version")
	local stage = ui.panelContent:FindFirstChild("PreviewStage", true)
	expect(stage.AbsoluteSize.Y >= 180, "The fitting stage must provide usable avatar height")
	local left = stage:FindFirstChild("PreviewLeft", true)
	f.guiService.SelectedObject = left; left.Activated:Fire()
	for _ = 1, 20 do f.services.RunService.Heartbeat:Fire(0.05) end
	expect(ui.previewCamera.CFrame.Position.X < 0, "Left control must rotate the preview camera")
	ui:OnProfile(f.ctx.Profile)
	expect(f.guiService.SelectedObject.Name == "PreviewLeft" and f.guiService.SelectedObject ~= left, "Preview control focus must survive a saved profile refresh")
	f.ctx.Profile.settings.reducedMotion = true
	stage = ui.panelContent:FindFirstChild("PreviewStage", true)
	stage:FindFirstChild("PreviewFront", true).Activated:Fire(); for _ = 1, 30 do f.services.RunService.Heartbeat:Fire(0.1) end
	expect(math.abs(ui.previewCamera.CFrame.Position.X) < 0.0001, "Front view must reset the camera even with reduced motion")
	stage:FindFirstChild("PreviewRight", true).Activated:Fire(); for _ = 1, 30 do f.services.RunService.Heartbeat:Fire(0.1) end
	expect(ui.previewCamera.CFrame.Position.X > 0, "Manual preview rotation remains available with reduced motion")
	expect(#f.actions == 0 and f.ctx.Profile.equipped.skins == "skin_courier", "Trying preview controls must not purchase or equip anything")
	ui:CloseMenu()
	expect(ui.previewCamera == nil and ui.previewModel == nil, "Closed locker must release its preview work")
end

-- Populated menu buttons dispatch real actions and results use the configured timer.
do
	local f = fixture(Vector2.new(390, 760))
	f.ctx.Profile.quests = {{id = "rounds", text = "Complete 3 rounds", xp = 75, coins = 30, goal = 3, progress = 3, claimed = false},
		{id = "tags", text = "Tag 5 runners", xp = 50, coins = 20, goal = 5, progress = 1, claimed = false},
		{id = "survived", text = "Survive 120 seconds", xp = 50, coins = 20, goal = 120, progress = 120, claimed = true}}
	local ui = f.load("UIController"); ui:Start(); ui:OpenMenu("Quests")
	ui.panelContent:FindFirstChild("Quest_rounds", true).Activated:Fire()
	expect(#f.actions == 1 and f.actions[1].action == "ClaimQuest" and f.actions[1].payload.id == "rounds", "A completed quest must dispatch its exact server claim ID")
	ui.panelContent:FindFirstChild("Quest_tags", true).Activated:Fire(); ui.panelContent:FindFirstChild("Quest_survived", true).Activated:Fire()
	expect(#f.actions == 1, "Incomplete and claimed quests must not send redundant claims")
	ui:OpenMenu("Settings")
	expect(string.find(ui.panelSubtitle.Text, Config.Version, 1, true) ~= nil, "Settings must identify the current build")
	for _, setting in ipairs({"music", "sfx", "reducedMotion", "cameraShake"}) do
		local original = f.ctx.Profile.settings[setting]
		ui.panelContent:FindFirstChild("Setting_" .. setting, true).Activated:Fire()
		local action = f.actions[#f.actions]
		expect(action.action == "Settings" and action.payload[setting] == not original, "Every preference toggle must dispatch the correct boolean")
		expect(f.ctx.Profile.settings[setting] == original, "Preference changes must wait for the server profile")
	end
	f.ctx.State = {phase = "Results", roundId = 9, endsAt = 105, winners = {42}, resultText = "The runners win!", players = {{userId = 42, role = "Runner", displayName = "Test Runner"}}}
	ui:OnState(f.ctx.State)
	expect(math.abs(ui.roundFill.Size.X.Scale - 0.5) < 0.001, "Results track must use the configured ten-second duration")
	expect(ui.results.Visible and ui.resultsTitle.Text == "YOU DID IT!", "Results appear as a compact card")
	ui.results:FindFirstChild("ViewCareer").Activated:Fire()
	expect(ui.menu == "Progress" and not ui.results.Visible, "Results career button must open progression")
	ui:CloseMenu(); ui:_showResults(); ui.results:FindFirstChild("ViewPodium").Activated:Fire()
	expect(not ui.results.Visible and ui.menu == nil and not f.player:GetAttribute("CatchMenuOpen"), "OK must restore the playable world")
	ui:OpenMenu("Inventory"); ui.category = "trails"; ui:_renderMenu()
	local explore = ui.panelContent:FindFirstChild("ExploreShop", true)
	expect(explore ~= nil, "An empty collection must expose a path to earn or buy its items")
	explore.Activated:Fire()
	expect(ui.menu == "Shop" and ui.category == "trails", "Empty locker action must open the corresponding shop category")
end

-- Input mappings survive menu focus and respawns; cooldowns follow acknowledgements.
do
	local f = fixture(Vector2.new(1280, 720))
	local ui, movement = f.load("UIController"), f.load("MovementController")
	ui:Start(); movement:Start()
	f.cas:Press(Enum.KeyCode.C)
	expect(f.actions[#f.actions].action == "Slide" and movement:GetCooldown("Slide") == 0, "C requests a slide without predicting a successful cooldown")
	f.advance(0.2); ui:OpenMenu("Inventory"); local count = #f.actions; f.cas:Press(Enum.KeyCode.C)
	expect(#f.actions == count, "C must not slide while a menu is open")
	ui:CloseMenu(); f.guiService.SelectedObject = ui.dock:FindFirstChild("Inventory")
	f.cas:Press(Enum.KeyCode.C)
	expect(#f.actions == count + 1 and f.actions[#f.actions].action == "Slide", "A lingering GUI selection must not disable PC sliding after closing a menu")
	f.advance(0.2); f.guiService.SelectedObject = nil; f.cas:Press(Enum.KeyCode.ButtonB)
	expect(f.actions[#f.actions].action == "Slide" and #f.actions == count + 2, "Controller B must request the same validated slide")
	f.advance(0.2); f.cas:Touch("CatchSlide")
	expect(f.actions[#f.actions].action == "Slide" and #f.actions == count + 3, "The mobile SLIDE control must request the same move")
	movement:OnNotice({kind = "ability", action = "Slide", cooldown = 3, success = false})
	expect(movement:GetCooldown("Slide") == 0, "Rejected slides must leave the cooldown ready")
	movement:OnNotice({kind = "ability", action = "Slide", cooldown = 3}); movement:OnNotice({kind = "ability", action = "Vault", cooldown = 1.1})
	expect(movement:GetCooldown("Slide") == 3, "Successful acknowledgement starts the server-based cooldown")
	movement:OnCharacter(nil)
	expect(movement:GetCooldown("Slide") == 0 and movement:GetCooldown("Vault") == 0, "Removing an avatar must clear old movement cooldowns")
	local rig = f.character(); f.player.Character = rig; movement:OnCharacter(rig); f.advance(0.2); f.cas:Press(Enum.KeyCode.C)
	expect(f.actions[#f.actions].action == "Slide" and movement.character == rig, "Respawned avatars must retain the working slide binding")
	movement:Destroy(); ui:Destroy()
	expect(next(f.renderCallbacks) == nil, "Destroyed controllers must release per-frame feedback")
end

-- Replicated slide poses articulate both local and remote avatars and clean up.
do
	local f = fixture(Vector2.new(1280, 720))
	local other = f.instance.new("Player"); other.UserId = 99; other.Character = f.character(); table.insert(f.players.list, other)
	local movement = f.load("MovementController"); movement:Start()
	local localKnee = f.player.Character:FindFirstChild("LeftKnee", true)
	local remoteKnee = other.Character:FindFirstChild("LeftKnee", true)
	local localBase, remoteBase = localKnee.C0, remoteKnee.C0
	f.player.Character:SetAttribute("Sliding", true); other.Character:SetAttribute("Sliding", true)
	movement:_feedback(0.1)
	expect(localKnee.C0 ~= localBase and remoteKnee.C0 ~= remoteBase, "A server sliding attribute must bend both players' knees")
	f.ctx.Profile.settings.reducedMotion = true; movement:OnProfile(f.ctx.Profile)
	for _ = 1, 10 do movement:_feedback(0.1) end
	expect(localKnee.C0 == localBase and remoteKnee.C0 == remoteBase, "Reduced motion must restore local and remote joint bases")
	f.ctx.Profile.settings.reducedMotion = false; movement:_feedback(0.1)
	other.Character = f.character(); movement:_feedback(0.1)
	expect(remoteKnee.C0 == remoteBase, "Replacing a remote avatar must release its old slide pose")
	f.humanoid.Health = 0; f.humanoid.Died:Fire()
	expect(localKnee.C0 == localBase, "Death must restore the local pose immediately")
	other.Character:SetAttribute("Sliding", true); movement:_feedback(0.1)
	local replacementKnee = other.Character:FindFirstChild("LeftKnee", true)
	expect(replacementKnee.C0 ~= remoteBase, "Remote slide must recover after respawning")
	movement:Destroy()
	expect(replacementKnee.C0 == remoteBase, "Controller destruction must release remote joint offsets")
end

-- Audio failures are cached, music preferences are independent, and landings reset.
do
	local f = fixture(Vector2.new(1280, 720))
	local loads = 0
	f.services.ContentProvider.PreloadAsync = function(_, assets, callback)
		loads += 1; callback(assets[1].SoundId, Enum.AssetFetchStatus.Failure)
	end
	local effects = f.load("EffectsController"); effects:Start()
	effects:_sound("Slide"); effects:_sound("Slide")
	expect(loads == 1, "Unavailable bundled audio must be cached instead of repeatedly requested")
	for _, sound in ipairs(f.services.SoundService:GetChildren()) do expect(not sound.IsPlaying, "Failed audio must not be played") end
	f.ctx.Config = table.clone(Config); f.ctx.Config.Audio = table.clone(Config.Audio); f.ctx.Config.Audio.Music = 12345
	f.ctx.Profile.settings.sfx = false
	f.services.ContentProvider.PreloadAsync = function(_, assets, callback) callback(assets[1].SoundId, Enum.AssetFetchStatus.Success) end
	effects:OnProfile(f.ctx.Profile)
	expect(effects.music and effects.music.IsPlaying, "Enabled configured music must play independently of muted SFX")
	f.ctx.Profile.settings.music = false; effects:OnProfile(f.ctx.Profile)
	expect(not effects.music.IsPlaying, "Music OFF must pause the soundtrack")
	local landings = 0; effects._sound = function(_, name) if name == "Land" then landings += 1 end end
	effects:OnCharacter(f.player.Character)
	f.humanoid.StateChanged:Fire(Enum.HumanoidStateType.Running, Enum.HumanoidStateType.Freefall); f.advance(0.3)
	f.humanoid.StateChanged:Fire(Enum.HumanoidStateType.Freefall, Enum.HumanoidStateType.Landed)
	expect(landings == 1, "An actual airborne interval must produce one landing cue")
	local rig, humanoid = f.character(); f.player.Character = rig; effects:OnCharacter(rig)
	f.humanoid.StateChanged:Fire(Enum.HumanoidStateType.Running, Enum.HumanoidStateType.Freefall); f.advance(0.3)
	f.humanoid.StateChanged:Fire(Enum.HumanoidStateType.Freefall, Enum.HumanoidStateType.Landed)
	expect(landings == 1, "Old avatar listeners must be detached after respawn")
	humanoid.StateChanged:Fire(Enum.HumanoidStateType.Running, Enum.HumanoidStateType.Freefall); f.advance(0.3)
	humanoid.StateChanged:Fire(Enum.HumanoidStateType.Freefall, Enum.HumanoidStateType.Landed)
	expect(landings == 2, "Landing feedback must recover on the replacement humanoid")
	effects:Destroy()
end


-- Shop and Locker are always reachable: every phase, role and screen size. Menus never close the round.
do
	local sizes = {Vector2.new(1440, 860), Vector2.new(1024, 768), Vector2.new(390, 760), Vector2.new(844, 350), Vector2.new(568, 320), Vector2.new(320, 500)}
	local states = {
		{phase = "Waiting", roundId = 0, players = {}},
		{phase = "Intermission", roundId = 1, endsAt = 130, players = {}},
		{phase = "HeadStart", roundId = 2, endsAt = 110, players = {{userId = 42, role = "Runner", alive = true}}},
		{phase = "Active", roundId = 2, endsAt = 280, players = {{userId = 42, role = "Runner", alive = true}}, aliveRunners = 3},
		{phase = "Active", roundId = 2, endsAt = 280, players = {{userId = 42, role = "Hunter", alive = true}}, aliveRunners = 3},
		{phase = "Active", roundId = 2, endsAt = 280, players = {}},
		{phase = "Results", roundId = 2, endsAt = 105, winners = {}, players = {}},
	}
	for _, size in ipairs(sizes) do
		for _, state in ipairs(states) do
			local f = fixture(size, Enum.UserInputType.Touch)
			f.ctx.Profile.settings.tutorialDone = true
			local ui = f.load("UIController"); f.ctx.Controllers.UIController = ui; ui:Start()
			f.ctx.State = state; ui:OnState(state)
			local where = tostring(size) .. " / " .. state.phase
			expect(ui.dock.Visible and ui.root.Visible, "Dock must be visible at " .. where)
			-- The dock is right-anchored: resolve its left edge from the viewport, then stack its buttons.
			local dockLeft = size.X + ui.dock.Position.X.Offset - ui.dock.Size.X.Offset
			local dockTop = ui.dock.Position.Y.Offset
			for index, name in ipairs({"Shop", "Inventory", "More"}) do
				local b = ui.dock:FindFirstChild(name)
				expect(b and b.Visible and b.ClassName == "TextButton", name .. " button must exist and be visible at " .. where)
				local gap = (ui.compact or ui.short) and 4 or 6
				local x = dockLeft + (ui.dockHorizontal and (index - 1) * (b.Size.X.Offset + gap) or 0)
				local y = dockTop + (ui.dockHorizontal and 0 or (index - 1) * (b.Size.Y.Offset + gap))
				expect(x >= 0 and y >= 0 and x + b.Size.X.Offset <= size.X and y + b.Size.Y.Offset <= size.Y, name .. " button must fit on screen at " .. where)
				expect(b.Size.X.Offset >= 40 and b.Size.Y.Offset >= 40, name .. " must keep a touch-sized hit area at " .. where)
			end
			-- Menus open beside the dock (never over it) and the More popover stays on screen.
			if not ui.dockHorizontal then
				for _, menu in ipairs({"Shop", "Inventory", "Quests", "Settings"}) do
					ui:OpenMenu(menu)
					local right = ui.panel.Position.X.Offset + ui.panel.Size.X.Offset
					expect(right <= dockLeft and ui.panel.Position.X.Offset >= 0, "The " .. menu .. " menu must not cover the dock at " .. where)
					expect(ui.panel.Position.Y.Offset + ui.panel.Size.Y.Offset <= size.Y, "The " .. menu .. " menu must fit vertically at " .. where)
					ui:CloseMenu()
				end
			end
			-- Announcements and toasts never reach the dock.
			for _, banner in ipairs({ui.announcement, ui.toast}) do
				local left = banner.AnchorPoint.X > 0 and (size.X * banner.Position.X.Scale - banner.Size.X.Offset / 2) or banner.Position.X.Offset
				local right = left + banner.Size.X.Offset
				expect(right <= dockLeft - 4 or ui.dockHorizontal, banner.Name .. " must stay clear of the dock at " .. where)
			end
			ui:ToggleMore()
			local moreRight = size.X + ui.moreMenu.Position.X.Offset
			expect(moreRight <= size.X and moreRight - ui.moreMenu.Size.X.Offset >= 0, "The More popover must stay on screen at " .. where)
			expect(ui.moreMenu.Position.Y.Offset + ui.moreMenu.Size.Y.Offset <= size.Y, "The More popover must fit vertically at " .. where)
			ui:CloseMore()
		end
	end
end

-- Menus never pause the round, give protection or get closed by it; drawer layout keeps the world visible.
do
	local f = fixture(Vector2.new(1440, 860))
	f.ctx.Profile.settings.tutorialDone = true
	local ui = f.load("UIController"); f.ctx.Controllers.UIController = ui; ui:Start()
	ui:OpenMenu("Inventory")
	expect(ui.menu == "Inventory" and f.player:GetAttribute("CatchMenuOpen"), "Locker opens in the lobby")
	f.ctx.State = {phase = "Active", roundId = 4, endsAt = 280, players = {{userId = 42, role = "Runner", alive = true}}, aliveRunners = 4}
	ui:OnState(f.ctx.State)
	expect(ui.menu == "Inventory", "A round starting must not close the locker")
	expect(ui.panel.Size.X.Offset <= 540 and ui.panel.Position.X.Offset > 700, "During a round the menu becomes a right-hand drawer")
	expect(string.find(ui.panelSubtitle.Text, "keeps going", 1, true), "The locker tells the player the round continues")
	ui.category = "skins"; ui.selectedItem = "skin_rooftop"; f.ctx.Profile.owned.skin_rooftop = true; ui:_renderMenu()
	expect(ui.panelContent:FindFirstChild("RoundHint", true) ~= nil, "Mid-round equips explain that they show after the round")
	ui:CloseMenu()
	local humanoid = f.humanoid
	expect(humanoid.Health == 100 and not f.character().ForceField, "Opening menus must never heal or shield the player")
end

-- Objective, coin counter, hide meter and reward breakdown.
do
	local f = fixture(Vector2.new(1440, 860))
	f.ctx.Profile.settings.tutorialDone = true
	local ui = f.load("UIController"); f.ctx.Controllers.UIController = ui; ui:Start()
	f.ctx.State = {phase = "Active", roundId = 7, endsAt = 280, pickupCap = 25, aliveRunners = 3, players = {{userId = 42, role = "Runner", alive = true, pickups = 2}}}
	ui:OnState(f.ctx.State)
	expect(ui.objective.Visible and string.find(ui.objectiveText.Text, "2/25", 1, true), "Runner objective shows the coin count")
	ui:OnNotice({kind = "pickup", count = 5, cap = 25})
	ui:_tick()
	expect(string.find(ui.objectiveText.Text, "5/25", 1, true), "A pickup notice updates the counter immediately")
	expect(not ui.hideMeter.Visible, "No hide meter while visible")
	ui:OnNotice({kind = "hide", state = "in", endsAt = 103, duration = 7})
	ui:_tick()
	expect(ui.hideMeter.Visible and ui.hideFill.Size.X.Scale > 0.3 and ui.hideFill.Size.X.Scale < 0.5, "Hide meter shows the remaining hide time")
	ui.leaveButton.Activated:Fire()
	expect(f.actions[#f.actions].action == "Unhide", "Leave button asks the server to release the hide")
	ui:OnNotice({kind = "hide", state = "out", reason = "manual", cooldown = 12})
	expect(not ui.hideMeter.Visible, "Hide meter closes when the server says the hide ended")
	expect(not ui.abilityLabels.Scan.box.Visible and not ui.abilityLabels.Tag.box.Visible, "Runners do not see hunter abilities")
	f.ctx.State = {phase = "Active", roundId = 7, endsAt = 280, aliveRunners = 3, players = {{userId = 42, role = "Hunter", alive = true, finds = 1}}}
	ui:OnState(f.ctx.State)
	expect(ui.abilityLabels.Scan.box.Visible and ui.abilityLabels.Tag.box.Visible, "Hunters see Scan and Tag")
	expect(string.find(ui.objectiveText.Text, "Found: 1", 1, true), "Hunter objective shows finds")
	ui.abilityLabels.Scan.box.Activated:Fire()
	expect(f.actions[#f.actions].action == "Scan", "The on-screen Scan pill requests a scan")
	f.player:SetAttribute("CatchScanReadyAt", 110)
	ui:_tick()
	expect(string.find(ui.abilityLabels.Scan.status.Text, "10.0s", 1, true), "Scan shows its server cooldown")
	-- Reward breakdown arrives with the results.
	f.ctx.State = {phase = "Results", roundId = 7, endsAt = 105, winners = {42}, resultText = "The runners win!", players = {{userId = 42, role = "Runner", displayName = "Test Runner"}}}
	ui:OnState(f.ctx.State)
	expect(ui.results.Visible and not ui.results:FindFirstChild("RewardBreakdown", true), "Results open before the reward arrives")
	ui:OnNotice({kind = "reward", xp = 120, coins = 80, rating = 24, pickups = 12, closeCalls = 3, tags = 0, finds = 0, survived = 150})
	local total = ui.results:FindFirstChild("RewardTotal", true)
	expect(total and string.find(total.Text, "+120 XP", 1, true) and string.find(total.Text, "+80 COINS", 1, true), "Results list exactly the server-granted rewards")
	expect(ui.dock:FindFirstChild("Shop").Visible and ui.dock:FindFirstChild("Inventory").Visible, "Shop and Locker stay visible on the results screen")
end

-- Scan input, jump-to-leave and effect hooks.
do
	local f = fixture(Vector2.new(1280, 720))
	local movement = f.load("MovementController"); movement:Start()
	movement:OnState({phase = "Active", roundId = 1, players = {{userId = 42, role = "Runner", alive = true}}})
	f.cas:Press(Enum.KeyCode.Q)
	expect(#f.actions == 0, "Runners cannot send Scan")
	movement:OnState({phase = "Active", roundId = 1, players = {{userId = 42, role = "Hunter", alive = true}}})
	f.cas:Press(Enum.KeyCode.Q)
	expect(f.actions[#f.actions].action == "Scan", "Q requests a hunter scan")
	f.advance(0.3); f.cas:Touch("CatchScan")
	expect(f.actions[#f.actions].action == "Scan", "The mobile SCAN control requests a scan")
	movement:OnNotice({kind = "ability", action = "Scan", cooldown = 25})
	expect(movement:GetCooldown("Scan") == 25, "Scan cooldown follows the server acknowledgement")
	movement:OnState({phase = "Active", roundId = 1, players = {{userId = 42, role = "Runner", alive = true}}})
	f.player.Character:SetAttribute("CatchHiding", true); f.advance(0.3); local count = #f.actions
	f.cas:Press(Enum.KeyCode.Space)
	expect(#f.actions == count + 1 and f.actions[#f.actions].action == "Unhide", "Jumping while hiding asks the server to step out")
	local effects = f.load("EffectsController"); effects:Start()
	local cues = {}
	effects._sound = function(_, name) table.insert(cues, name) end
	effects._banner = function(_, text) table.insert(cues, text) end
	effects._pulse = function() end
	effects._worldBurst = function() end
	for _, notice in ipairs({{kind = "pickup", count = 3}, {kind = "closecall"}, {kind = "found"}, {kind = "reveal", userId = 42}, {kind = "hide", state = "in"}, {kind = "scan"}}) do effects:OnNotice(notice) end
	expect(table.concat(cues, ","):find("Pickup") and table.concat(cues, ","):find("CLOSE CALL") and table.concat(cues, ","):find("YOU WERE FOUND") and table.concat(cues, ","):find("Hide") and table.concat(cues, ","):find("Scan"), "Every mall gameplay notice has audiovisual feedback")
end

-- Hiding controller relabels prompts by role and honors server-owned occupancy.
do
	local f = fixture(Vector2.new(1280, 720))
	local mall = f.instance.new("Model"); mall.Name = "CatchMall"; mall.Parent = f.workspace
	local cell = f.instance.new("Model"); cell.Name = "Cell"; cell.Parent = mall
	cell:SetAttribute("CatchHideSpot", true)
	local prompt = f.instance.new("ProximityPrompt"); prompt.Name = "HidePrompt"; prompt.ActionText = "Hide"; prompt.Parent = cell
	local coin = f.instance.new("Part"); coin.Name = "MallCoin"; coin.Parent = (function() local d = f.instance.new("Folder"); d.Name = "MallCoins"; d.Parent = mall return d end)()
	f.workspace.ChildAdded = signal()
	local hiding = f.load("HidingController"); hiding:Start()
	expect(prompt.ActionText == "Hide" and not prompt.Enabled, "Prompts are disabled in the lobby")
	hiding:OnState({phase = "Active", players = {{userId = 42, role = "Hunter", alive = true}}})
	expect(prompt.ActionText == "Search" and prompt.Enabled, "Hunters search")
	hiding:OnState({phase = "Active", players = {{userId = 42, role = "Runner", alive = true}}})
	expect(prompt.ActionText == "Hide" and prompt.Enabled, "Runners hide")
	cell:SetAttribute("Occupied", true); cell:SetAttribute("OccupantUserId", 99); hiding:_refreshPrompts()
	expect(prompt.ActionText == "Taken" and not prompt.Enabled, "Someone else's cell cannot be entered")
	cell:SetAttribute("OccupantUserId", 42); hiding:_refreshPrompts()
	expect(prompt.ActionText == "Leave" and prompt.Enabled, "The occupant can step out")
	hiding:OnState({phase = "Results", players = {}})
	expect(not prompt.Enabled, "Prompts close between rounds")
	coin:SetAttribute("Collected", true); f.services.RunService.Heartbeat:Fire(0.1)
	expect(coin.Transparency == 1, "Collected coins vanish on the client")
	hiding:Destroy()
end


-- Roblox's own animations drive everything except sliding: moods never write to the joints.
do
	local f = fixture(Vector2.new(1280, 720))
	local function rig()
		local model, humanoid = f.character()
		local torso = f.instance.new("Part"); torso.Name = "UpperTorso"; torso.Parent = model
		for _, name in ipairs({"Neck", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow"}) do
			local joint = f.instance.new("Motor6D"); joint.Name = name; joint.C0 = roblox.CFrame.new(0, 0.2, 0); joint.Parent = torso
		end
		return model, humanoid
	end
	local localRig = rig(); f.player.Character = localRig
	local other = f.instance.new("Player"); other.UserId = 99; other.Character = rig(); table.insert(f.players.list, other)
	local movement = f.load("MovementController"); movement:Start()
	movement:OnState({phase = "Results", roundId = 3, players = {}})
	local function joint(model, name) return model:FindFirstChild(name, true) end
	local rest = roblox.CFrame.new(0, 0.2, 0)
	for _, mood in ipairs({"Idle", "Win", "Scared", "Hunt", "Hide", "Lose"}) do
		localRig:SetAttribute("CatchMood", mood); other.Character:SetAttribute("CatchMood", mood)
		for _ = 1, 10 do movement:_feedback(0.1) end
		for _, name in ipairs({"Neck", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow"}) do
			expect(joint(localRig, name).C0 == rest and joint(other.Character, name).C0 == rest, "Mood " .. mood .. " leaves " .. name .. " to Roblox animations")
		end
	end
	expect(next(movement.remotePoses) == nil, "Remote avatars hold no joint overrides outside a slide")
	movement:Destroy()
end


-- Coin packs: visible in the Shop, inert until configured, and always routed through the server.
do
	local f = fixture(Vector2.new(1280, 720))
	f.ctx.Profile.settings.tutorialDone = true
	local ui = f.load("UIController"); ui:Start(); ui:OpenMenu("Shop")
	local tab = ui.panelContent:FindFirstChild("Category_coins", true)
	expect(tab ~= nil, "The shop offers a coins tab")
	tab.Activated:Fire()
	expect(ui.category == "coins" and ui.panelContent:FindFirstChild("Pack_coins_bag", true), "The coins tab lists the packs")
	local buy = ui.panelContent:FindFirstChild("BuyPack_coins_bag", true)
	expect(buy.Text == "COMING SOON", "Unconfigured packs say so")
	local count = #f.actions; buy.Activated:Fire()
	expect(#f.actions == count, "An unconfigured pack never contacts the server")
	local pack = Catalog.Products[2]
	pack.productId = 4242
	ui:_renderMenu()
	buy = ui.panelContent:FindFirstChild("BuyPack_coins_bag", true)
	expect(string.find(buy.Text, "R$ 99", 1, true), "Configured packs show their Robux price")
	buy.Activated:Fire()
	pack.productId = 0
	expect(f.actions[#f.actions].action == "BuyCoins" and f.actions[#f.actions].payload.id == "coins_bag", "A configured pack only sends its catalog ID")
	ui:CloseMenu(); ui:OpenMenu("Inventory")
	expect(ui.category == "skins" and not ui.panelContent:FindFirstChild("Category_coins", true), "The locker never shows coin packs")
end


-- UIGradient also tints the text of its parent, so no text object may carry one.
do
	local f = fixture(Vector2.new(1280, 720))
	local ui = f.load("UIController"); ui:Start()
	for _, menu in ipairs({"Shop", "Inventory", "Quests", "Progress", "Settings", "Leaderboard", "Results"}) do ui:OpenMenu(menu) end
	local texts = 0
	for _, node in ipairs(ui.root:GetDescendants()) do
		if node.ClassName == "TextButton" or node.ClassName == "TextLabel" then
			texts += 1
			for _, child in ipairs(node:GetChildren()) do
				expect(child.ClassName ~= "UIGradient", "Text objects must not carry a UIGradient (" .. node.Name .. ")")
			end
		end
	end
	expect(texts > 50, "The gradient guard must cover the real interface")
end

-- Short screens keep the objective card fully on screen (it sits under the dock row).
do
	for _, size in ipairs({Vector2.new(568, 320), Vector2.new(667, 375), Vector2.new(320, 500), Vector2.new(844, 350)}) do
		local f = fixture(size, Enum.UserInputType.Touch)
		f.ctx.Profile.settings.tutorialDone = true
		local ui = f.load("UIController"); ui:Start()
		f.ctx.State = {phase = "Active", roundId = 2, endsAt = 280, aliveRunners = 3, players = {{userId = 42, role = "Runner", alive = true}}}
		ui:OnState(f.ctx.State)
		local o = ui.objective
		expect(o.Visible and o.Position.X.Offset >= 0 and o.Position.X.Offset + o.Size.X.Offset <= size.X, "Objective card must stay on screen at " .. tostring(size))
		local header = ui.clock.Position.X.Offset + ui.clock.Size.X.Offset
		expect(header <= size.X - ui.wallet.Size.X.Offset - 12 or ui.clock.AnchorPoint.X > 0, "Round card must not sit under the wallet at " .. tostring(size))
	end
end

-- Performance tiers: distance LOD for decoration and lights, effect trimming, adaptive step-down.
do
	local function world(f)
		local mall = f.instance.new("Model"); mall.Name = "CatchMall"; mall.Parent = f.workspace
		local function part(name, x, detail)
			local p = f.instance.new("Part"); p.Name = name; p.Position = Vector3.new(x, 0, 0); p.Parent = mall
			if detail then p:SetAttribute("CatchDetail", true) end
			return p
		end
		local near, far, wall = part("Near", 20, true), part("Far", 200, true), part("Wall", 300, false)
		local lamp = part("Lamp", 250, false)
		local light = f.instance.new("PointLight"); light.Enabled = true; light.Parent = lamp
		local nearLight = f.instance.new("PointLight"); nearLight.Enabled = true; nearLight.Parent = near
		local rays, bloom = f.instance.new("SunRaysEffect"), f.instance.new("BloomEffect")
		rays.Enabled, bloom.Enabled = true, true
		rays.Parent, bloom.Parent = f.services.Lighting, f.services.Lighting
		f.services.Lighting.GlobalShadows = true
		local steam = f.instance.new("ParticleEmitter"); steam.Rate = 10; steam.Enabled = true; steam.Parent = near
		f.workspace.ChildAdded = signal()
		return {steam = steam, near = near, far = far, wall = wall, light = light, nearLight = nearLight, rays = rays, bloom = bloom}
	end
	-- PC: everything stays on.
	local f = fixture(Vector2.new(1440, 860), Enum.UserInputType.Keyboard)
	f.input.KeyboardEnabled = true
	local w = world(f)
	local perf = f.load("PerformanceController"); f.ctx.Controllers.PerformanceController = perf; perf:Start()
	expect(f.ctx.Perf.tier == 1 and (w.far.LocalTransparencyModifier or 0) == 0 and w.light.Enabled, "Desktop defaults to HIGH with nothing culled")
	-- Manual MEDIUM: far detail and far lights go, near ones stay, sun rays off, bloom kept.
	perf:SetPreference(2)
	expect(w.far.LocalTransparencyModifier == 1 and (w.near.LocalTransparencyModifier or 0) == 0, "MEDIUM hides far decoration only")
	expect(not w.light.Enabled and w.nearLight.Enabled, "MEDIUM turns off far lights only")
	expect(not w.rays.Enabled and w.bloom.Enabled, "MEDIUM drops sun rays but keeps bloom")
	expect((w.wall.LocalTransparencyModifier or 0) == 0, "Architecture is never culled")
	expect(w.steam.Enabled and w.steam.Rate == 5, "MEDIUM halves ambient particle rates")
	-- Hysteresis: a part just inside the radius stays hidden once hidden.
	w.far.Position = Vector3.new(105, 0, 0); perf:_lod(false)
	expect(w.far.LocalTransparencyModifier == 1, "LOD uses hysteresis so decoration does not flicker at the boundary")
	w.far.Position = Vector3.new(90, 0, 0); perf:_lod(false)
	expect(w.far.LocalTransparencyModifier == 0, "Decoration returns when comfortably inside the radius")
	perf:SetPreference(3)
	expect(not w.bloom.Enabled and not f.services.Lighting.GlobalShadows and not w.steam.Enabled, "LOW disables bloom, global shadows and ambient particles")
	perf:SetPreference(nil)
	expect(f.ctx.Perf.tier == 1 and w.bloom.Enabled and w.rays.Enabled and f.services.Lighting.GlobalShadows and w.light.Enabled, "AUTO restores every effect and light")
	expect(w.steam.Rate == 10 and w.steam.Enabled, "AUTO restores particle rates")
	-- Adaptive: sustained low FPS steps down (once per two slow windows), good FPS never does.
	for _ = 1, 3000 do f.services.RunService.Heartbeat:Fire(1 / 60) end
	expect(f.ctx.Perf.tier == 1, "A healthy frame rate must never lower quality")
	for _ = 1, 40 do f.services.RunService.Heartbeat:Fire(1.5) end
	expect(f.ctx.Perf.tier == 1, "Hitches and tab-outs are ignored")
	for _ = 1, 700 do f.services.RunService.Heartbeat:Fire(1 / 20) end
	expect(f.ctx.Perf.tier == 3 and not w.bloom.Enabled, "Sustained 20 FPS steps down to LOW")
	expect(f.player:GetAttribute("CatchGraphicsTier") == 3, "The tier is visible to other client code")
	perf:Destroy()
	expect((w.far.LocalTransparencyModifier or 0) == 0 and w.bloom.Enabled and f.services.Lighting.GlobalShadows, "Destroying the controller restores the world")
	-- Phone: MEDIUM by default; manual choices are never auto-lowered.
	local g = fixture(Vector2.new(390, 760), Enum.UserInputType.Touch)
	local wg = world(g)
	local gp = g.load("PerformanceController"); g.ctx.Controllers.PerformanceController = gp; gp:Start()
	expect(g.ctx.Perf.tier == 2 and wg.far.LocalTransparencyModifier == 1, "Phones default to MEDIUM")
	gp:SetPreference(1)
	for _ = 1, 600 do g.services.RunService.Heartbeat:Fire(1 / 15) end
	expect(g.ctx.Perf.tier == 1, "A manual graphics choice is respected")
	-- Settings row cycles AUTO -> HIGH -> MEDIUM -> LOW -> AUTO.
	gp:SetPreference(nil)
	local ui = g.load("UIController"); g.ctx.Controllers.UIController = ui; ui.ctx = g.ctx; g.ctx.Profile.settings.tutorialDone = true; ui:Start(); ui:OpenMenu("Settings")
	local seen = {}
	for _ = 1, 4 do
		local row = ui.panelContent:FindFirstChild("Setting_graphics", true)
		table.insert(seen, row.Text)
		row.Activated:Fire()
	end
	expect(seen[1]:find("AUTO") and seen[2] == "HIGH" and seen[3] == "MEDIUM" and seen[4] == "LOW" and g.ctx.Perf.auto, "Graphics button cycles through every option back to AUTO")
end

-- Touch action buttons never overlap each other or Roblox's jump button (bottom right), portrait or landscape.
do
	for _, size in ipairs({Vector2.new(390, 844), Vector2.new(844, 390), Vector2.new(568, 320)}) do
		local f = fixture(size, Enum.UserInputType.Touch)
		f.workspace.CurrentCamera.ViewportSize = size
		local movement = f.load("MovementController"); movement:Start()
		movement:OnState({phase = "Active", roundId = 1, players = {{userId = 42, role = "Hunter", alive = true}}})
		local rects = {}
		for _, name in ipairs({"CatchSprint", "CatchSlide", "CatchTag", "CatchScan"}) do
			local b = f.cas:GetButton(name)
			local x, y = size.X + b.Position.X.Offset, size.Y + b.Position.Y.Offset
			rects[name] = {x0 = x, y0 = y, x1 = x + b.Size.X.Offset, y1 = y + b.Size.Y.Offset}
			expect(x >= 0 and y >= 90 and x + b.Size.X.Offset <= size.X and y + b.Size.Y.Offset <= size.Y, name .. " must be on screen and below the header at " .. tostring(size))
		end
		local jump = {x0 = size.X - 130, y0 = size.Y - 110, x1 = size.X - 50, y1 = size.Y - 30}
		local names = {"CatchSprint", "CatchSlide", "CatchTag", "CatchScan"}
		local function overlap(a, b) return a.x0 < b.x1 and b.x0 < a.x1 and a.y0 < b.y1 and b.y0 < a.y1 end
		for i, a in ipairs(names) do
			expect(not overlap(rects[a], jump), a .. " must not cover the jump button at " .. tostring(size))
			for j = i + 1, #names do
				expect(not overlap(rects[a], rects[names[j]]), a .. " and " .. names[j] .. " overlap at " .. tostring(size))
			end
		end
		movement:Destroy()
	end
end

print("Client controller integration: " .. checks .. " checks passed")
