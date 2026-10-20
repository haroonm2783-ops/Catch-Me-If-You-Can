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
		SoundService = instance.new("SoundService"), Lighting = instance.new("Lighting"), Debris = {AddItem = function() end}}
	local environment = {game = {GetService = function(_, name) return assert(services[name], name) end}, workspace = workspace,
		Instance = instance, task = {spawn = function(fn) fn() end, defer = function(fn) fn() end, delay = function() end},
		os = {clock = function() return monotonic end},
		require = function(module) expect(module == appearanceModule, "UI must use shared Appearance"); return appearance end,
		TweenInfo = {new = function() return {} end}, Random = {new = function() return {NextInteger = function(_, a, b) return math.floor((a + b) / 2) end, NextNumber = function(_, a, b) return (a + b) / 2 end} end},
	}
	for _, name in ipairs({"Enum", "Color3", "ColorSequence", "NumberSequence", "UDim", "UDim2", "Vector2", "Vector3", "CFrame"}) do environment[name] = roblox[name] end
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

-- Onboarding, daily login and round-type presentation.
do
	local f = fixture(Vector2.new(390, 760), Enum.UserInputType.Touch)
	f.ctx.Profile.loginStatus = {streak = 2, canClaim = true, day = 3, coins = 40, xp = 30}
	local ui = f.load("UIController"); f.ctx.Controllers.UIController = ui; ui:Start()
	expect(ui.tutorial.Visible and ui.tutorialStep.Text == "HOW TO PLAY  /  1 OF 5", "First-time players must see the tutorial")
	expect(ui.dock:FindFirstChild("Quests"):FindFirstChild("Badge").Visible, "Claimable daily reward must flag the Quests button")
	for _ = 1, 4 do ui.tutorialNext.Activated:Fire() end
	expect(ui.tutorialNext.Text == "LET'S RUN" and ui.tutorialTitle.Text:find("EARN"), "Final tutorial page should start the game")
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
	expect(#f.actions == count and action.Text == "NOT CONFIGURED", "Unconfigured game pass must not send a purchase")
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
	expect(preview.skin=="skin_midnight" and preview.mask=="mask_phantom","Midnight Collection previews its included outfit and mask")
	expect(preview.extra.trails=="trail_cyan","Midnight Collection preview includes its trail")
	ui.category="vip";ui.selectedItem="vip_founder";ui:_renderMenu()
	preview=f.previewCalls[#f.previewCalls]
	expect(preview.skin=="skin_streetwear" and preview.mask=="mask_jester","VIP previews the advertised collection")
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
			for index, name in ipairs({"Shop", "Inventory"}) do
				local b = ui.dock:FindFirstChild(name)
				expect(b and b.Visible and b.ClassName == "TextButton", name .. " button must exist and be visible at " .. where)
				-- Extents of the n-th dock button must stay on screen.
				local step = (b.Size.X.Offset + 6)
				local x = ui.dock.Position.X.Offset + (ui.dockHorizontal and (index - 1) * step or 0)
				local y = ui.dock.Position.Y.Offset + (ui.dockHorizontal and 0 or (index - 1) * (b.Size.Y.Offset + 6))
				expect(x >= 0 and y >= 0 and x + b.Size.X.Offset <= size.X and y + b.Size.Y.Offset <= size.Y, name .. " button must fit on screen at " .. where)
				expect(b.Size.X.Offset >= 40 and b.Size.Y.Offset >= 40, name .. " must keep a touch-sized hit area at " .. where)
			end
			if ui.dockHorizontal ~= true then
				ui:OpenMenu("Shop")
				expect(ui.panel.Position.X.Offset >= ui.dock.Position.X.Offset + ui.dock.Size.X.Offset, "The menu must not cover the dock at " .. where)
				ui:CloseMenu()
			end
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
	expect(ui.menu == "Results" and not ui.panelContent:FindFirstChild("RewardBreakdown", true), "Results open before the reward arrives")
	ui:OnNotice({kind = "reward", xp = 120, coins = 80, rating = 24, pickups = 12, closeCalls = 3, tags = 0, finds = 0, survived = 150})
	local total = ui.panelContent:FindFirstChild("RewardTotal", true)
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


-- Moods pose the avatar through the same single joint writer as sliding, for local and remote avatars.
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
	local base = joint(localRig, "RightShoulder").C0
	local otherBase = joint(other.Character, "RightShoulder").C0
	movement:_feedback(0.1)
	expect(joint(localRig, "Neck").C0 ~= roblox.CFrame.new(0, 0.2, 0), "Idle avatars breathe and sway their head")
	expect(joint(localRig, "RightShoulder").C0 == base, "Idle does not move the shoulders")
	localRig:SetAttribute("CatchMood", "Win"); other.Character:SetAttribute("CatchMood", "Win")
	for _ = 1, 20 do movement:_feedback(0.1) end
	expect(joint(localRig, "RightShoulder").C0 ~= base and joint(other.Character, "RightShoulder").C0 ~= otherBase, "A winning mood raises both avatars' arms")
	expect(joint(localRig, "LeftElbow").C0 ~= roblox.CFrame.new(0, 0.2, 0), "Win bends the elbows")
	localRig:SetAttribute("CatchMood", "Idle"); other.Character:SetAttribute("CatchMood", "Idle")
	for _ = 1, 40 do movement:_feedback(0.1) end
	expect((joint(localRig, "RightShoulder").C0.Position - base.Position).Magnitude < 0.001
		and (joint(localRig, "RightShoulder").C0.LookVector - base.LookVector).Magnitude < 0.01, "Returning to idle lowers the arms")
	expect(next(movement.remotePoses) == nil, "Finished remote moods release their joints")
	f.ctx.Profile.settings.reducedMotion = true
	other.Character:SetAttribute("CatchMood", "Scared"); movement:_feedback(0.1)
	expect(next(movement.remotePoses) == nil and joint(other.Character, "RightShoulder").C0 == otherBase, "Reduced motion disables mood poses")
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
		f.workspace.ChildAdded = signal()
		return {near = near, far = far, wall = wall, light = light, nearLight = nearLight, rays = rays, bloom = bloom}
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
	-- Hysteresis: a part just inside the radius stays hidden once hidden.
	w.far.Position = Vector3.new(105, 0, 0); perf:_lod(false)
	expect(w.far.LocalTransparencyModifier == 1, "LOD uses hysteresis so decoration does not flicker at the boundary")
	w.far.Position = Vector3.new(90, 0, 0); perf:_lod(false)
	expect(w.far.LocalTransparencyModifier == 0, "Decoration returns when comfortably inside the radius")
	perf:SetPreference(3)
	expect(not w.bloom.Enabled and not f.services.Lighting.GlobalShadows, "LOW disables bloom and global shadows")
	perf:SetPreference(nil)
	expect(f.ctx.Perf.tier == 1 and w.bloom.Enabled and w.rays.Enabled and f.services.Lighting.GlobalShadows and w.light.Enabled, "AUTO restores every effect and light")
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
