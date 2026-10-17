-- Run: .tooling/bin/lune run tests/client_controllers.spec.luau
-- Executes production client controllers against deterministic GUI/input boundaries.
-- This checks interaction and layout contracts, not Roblox rendering or device ergonomics.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Catalog = require("../src/shared/Catalog")
local Rules = require("../src/shared/Rules")
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
		}}, {
			__index = function(self, key)
				if methods[key] then return methods[key] end
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
	local appearanceModule = instance.new("ModuleScript"); appearanceModule.Name = "Appearance"; appearanceModule.Parent = shared
	local replicated = instance.new("ReplicatedStorage"); shared.Parent = replicated
	local previewCalls = {}
	local appearance = {BuildPreview = function(skin, mask, extra)
		table.insert(previewCalls, {skin = skin, mask = mask, extra = extra})
		return instance.new("Model")
	end}
	local services = {Players = players, TweenService = {Create = function(_, object, _, values) return {Play = function() for key, value in pairs(values) do object[key] = value end end} end},
		RunService = runService, UserInputService = input, GuiService = guiService, ReplicatedStorage = replicated, ContextActionService = cas,
		ContentProvider = {PreloadAsync = function(_, assets, callback) for _, asset in ipairs(assets) do callback(asset.SoundId, Enum.AssetFetchStatus.Success) end end},
		SoundService = instance.new("SoundService"), Debris = {AddItem = function() end}}
	local environment = {game = {GetService = function(_, name) return assert(services[name], name) end}, workspace = workspace,
		Instance = instance, task = {spawn = function(fn) fn() end, defer = function(fn) fn() end, delay = function() end},
		os = {clock = function() return monotonic end},
		require = function(module) expect(module == appearanceModule, "UI must use shared Appearance"); return appearance end,
		TweenInfo = {new = function() return {} end}, Random = {new = function() return {NextInteger = function(_, a, b) return math.floor((a + b) / 2) end, NextNumber = function(_, a, b) return (a + b) / 2 end} end},
	}
	for _, name in ipairs({"Enum", "Color3", "ColorSequence", "UDim", "UDim2", "Vector2", "Vector3", "CFrame"}) do environment[name] = roblox[name] end
	local profile = Rules.NewProfile(1700000000); profile.loaded = true; profile.persistence = "session"; profile.quests = {}
	local actions = {}
	local ctx = {Config = Config, Catalog = Catalog, Rules = Rules, Profile = profile, State = {phase = "Waiting", roundId = 0, players = {}}, Controllers = {},
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
	for _, menu in ipairs({"Shop", "Inventory", "Quests", "Progress", "Settings", "Leaderboard", "Results"}) do
		ui:OpenMenu(menu)
		for _, node in ipairs(ui.panelContent:GetDescendants()) do
			if node.ClassName == "Frame" or node.ClassName == "ScrollingFrame" or node.ClassName == "ViewportFrame" then
				expect(node.AbsoluteSize.X >= 0 and node.AbsoluteSize.Y >= 0, menu .. " must not create negative-size content at " .. tostring(size))
			end
		end
	end
	ui:CloseMenu()
	expect(not f.player:GetAttribute("CatchMenuOpen"), "Closing the menu must release input")
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
	expect(#f.actions == count and action.Text == "NOT CONFIGURED", "Unconfigured game pass must not send a purchase")
end

-- Coin purchases must wait for ownership; a prompt or local preview never grants it.
do
	local f = fixture(Vector2.new(390, 760), Enum.UserInputType.Touch)
	f.ctx.Profile.coins = 1000
	local ui = f.load("UIController"); ui:Start()
	ui.category = "skins"; ui.selectedItem = "skin_gardener"; ui:OpenMenu("Shop")
	local coins = f.ctx.Profile.coins
	ui.panelContent:FindFirstChild("ItemAction", true).Activated:Fire()
	expect(#f.actions == 1 and f.actions[1].action == "Buy" and f.actions[1].payload.id == "skin_gardener", "Coin checkout must send only the catalog item to the server")
	expect(f.ctx.Profile.coins == coins and not f.ctx.Profile.owned.skin_gardener, "Client checkout cannot deduct coins or grant ownership")
	expect(ui.panelContent:FindFirstChild("ItemAction", true).Text == "WAITING FOR SERVER...", "Checkout must show an acknowledgement state")
	ui.panelContent:FindFirstChild("ItemAction", true).Activated:Fire()
	expect(#f.actions == 1, "A pending checkout must not submit a second request")
	-- Simulate the authoritative server profile after a successful coin transaction.
	f.ctx.Profile.owned.skin_gardener = true; f.ctx.Profile.coins -= Catalog.Get("skin_gardener").price
	ui:OnProfile(f.ctx.Profile)
	expect(ui.panelContent:FindFirstChild("ItemAction", true).Text == "EQUIP", "Confirmed ownership must offer the newly purchased outfit")
	ui.panelContent:FindFirstChild("ItemAction", true).Activated:Fire()
	expect(f.actions[2].action == "Equip" and f.actions[2].payload.id == "skin_gardener", "Purchased outfits must use the validated equip action")
	expect(f.ctx.Profile.equipped.skins == "skin_courier", "Equipping must await the server profile")
	f.ctx.Profile.equipped.skins = "skin_gardener"; ui:OnProfile(f.ctx.Profile); ui:OpenMenu("Inventory")
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
	f.ctx.Profile.settings.reducedMotion = true
	effects:_worldBurst(Vector3.zero, roblox.Color3.new(1, 1, 1), false)
	expect(#effects.worldEffects:GetChildren() == 0, "Reduced motion must suppress animated tag particles")
end

-- Collection previews must present the granted pieces, not the current outfit.
do
	local f=fixture(Vector2.new(1280,720))
	local ui=f.load("UIController");ui:Start()
	ui.category="bundles";ui.selectedItem="bundle_night";ui:OpenMenu("Shop")
	local preview=f.previewCalls[#f.previewCalls]
	expect(preview.skin=="skin_shadow" and preview.mask=="mask_phantom","Nightfall previews its included outfit and mask")
	expect(preview.extra.trails=="trail_cyan","Nightfall preview includes its trail")
	ui.category="vip";ui.selectedItem="vip_founder";ui:_renderMenu()
	preview=f.previewCalls[#f.previewCalls]
	expect(preview.skin=="skin_neon" and preview.mask=="mask_visor","VIP previews the advertised collection")
	expect(f.ctx.Profile.equipped.skins=="skin_courier","Trying on a collection never changes equipped ownership")
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
	f.services.RunService.Heartbeat:Fire(0.016)
	expect(ui.previewCamera.CFrame.Position.X < 0, "Left control must rotate the preview camera")
	ui:OnProfile(f.ctx.Profile)
	expect(f.guiService.SelectedObject.Name == "PreviewLeft" and f.guiService.SelectedObject ~= left, "Preview control focus must survive a saved profile refresh")
	f.ctx.Profile.settings.reducedMotion = true
	stage = ui.panelContent:FindFirstChild("PreviewStage", true)
	stage:FindFirstChild("PreviewFront", true).Activated:Fire(); f.services.RunService.Heartbeat:Fire(0.1)
	expect(math.abs(ui.previewCamera.CFrame.Position.X) < 0.0001, "Front view must reset the camera even with reduced motion")
	stage:FindFirstChild("PreviewRight", true).Activated:Fire(); f.services.RunService.Heartbeat:Fire(0.1)
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
	ui.panelContent:FindFirstChild("ViewCareer", true).Activated:Fire()
	expect(ui.menu == "Progress", "Results career button must open progression")
	ui:OpenMenu("Results"); ui.panelContent:FindFirstChild("ViewPodium", true).Activated:Fire()
	expect(ui.menu == nil and not f.player:GetAttribute("CatchMenuOpen"), "Podium button must restore the playable world")
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

print("Client controller integration: " .. checks .. " checks passed")
