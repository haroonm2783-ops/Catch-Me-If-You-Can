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
			Died = signal(), Ended = signal(), IsPlaying = false, TimePosition = 0,
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
	local runService = {Heartbeat = signal(), BindToRenderStep = function() end, UnbindFromRenderStep = function() end}
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
		require = function(module) expect(module == appearanceModule, "UI must use shared Appearance"); return appearance end,
		TweenInfo = {new = function() return {} end}, Random = {new = function() return {NextInteger = function(_, a, b) return math.floor((a + b) / 2) end, NextNumber = function(_, a, b) return (a + b) / 2 end} end},
	}
	for _, name in ipairs({"Enum", "Color3", "UDim", "UDim2", "Vector2", "Vector3", "CFrame"}) do environment[name] = roblox[name] end
	local profile = Rules.NewProfile(1700000000); profile.loaded = true; profile.persistence = "session"; profile.quests = {}
	local actions = {}
	local ctx = {Config = Config, Catalog = Catalog, Rules = Rules, Profile = profile, State = {phase = "Waiting", roundId = 0, players = {}}, Controllers = {},
		Remotes = {Action = {FireServer = function(_, action, payload) table.insert(actions, {action = action, payload = payload}) end}}}
	local function load(name)
		return luau.load(fs.readFile("src/client/Controllers/" .. name .. ".lua"), {environment = environment, debugName = name})().new(ctx)
	end
	return {load = load, player = player, humanoid = humanoid, character = character, instance = instance, players = players, workspace = workspace,
		ctx = ctx, cas = cas, input = input, guiService = guiService, actions = actions, previewCalls = previewCalls, services = services}
end

-- Every menu can construct on desktop, portrait phone, and landscape phone.
for _, size in ipairs({Vector2.new(1440, 860), Vector2.new(390, 760), Vector2.new(844, 350), Vector2.new(320, 500)}) do
	local f = fixture(size, Enum.UserInputType.Touch)
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

print("Client controller integration: " .. checks .. " checks passed")
