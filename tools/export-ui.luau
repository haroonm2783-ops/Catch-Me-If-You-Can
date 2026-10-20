-- Optional layout inspection (not a Roblox render): builds the production UIController against the same
-- deterministic GUI mock the tests use and writes the resulting tree as JSON for tools/render-ui.py.
-- Usage: .tooling/bin/lune run tools/export-ui.luau WIDTH HEIGHT STATE [touch] [output.json]
-- STATE: lobby | runner | hunter | results | shop | locker | more | tutorial
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Catalog = require("../src/shared/Catalog")
local Rules = require("../src/shared/Rules")
local Achievements = require("../src/shared/Achievements")
local Config = require("../src/shared/Config")
local Enum, Vector2, Vector3 = roblox.Enum, roblox.Vector2, roblox.Vector3
local function expect(condition, message) assert(condition, message) end
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


local width, height = tonumber(process.args[1]) or 1280, tonumber(process.args[2]) or 720
local state = process.args[3] or "lobby"
local touch = process.args[4] == "touch"
local output = process.args[5] or (touch and process.args[4] ~= "touch" and process.args[4]) or ".tooling/ui.json"
if process.args[4] and process.args[4] ~= "touch" then output = process.args[4] end
local f = fixture(Vector2.new(width, height), touch and Enum.UserInputType.Touch or nil)
f.ctx.Profile.settings.tutorialDone = state ~= "tutorial"
f.ctx.Profile.coins = 1240
f.ctx.Profile.xp = 480
f.ctx.Profile.level = 7
f.ctx.Profile.quests = {{id = "rounds", text = "Complete 3 competitive rounds", xp = 75, coins = 30, goal = 3, progress = 2, claimed = false}}
f.ctx.Profile.loginStatus = {streak = 2, canClaim = true, day = 3, coins = 40, xp = 30}
local ui = f.load("UIController"); f.ctx.Controllers.UIController = ui; ui:Start()
local me = f.player.UserId
if state == "runner" or state == "hunter" then
	f.ctx.State = {phase = "Active", roundId = 3, endsAt = 160, pickupCap = 25, aliveRunners = 5, players = {{userId = me, role = state == "runner" and "Runner" or "Hunter", alive = true, pickups = 6, finds = 1}}}
	ui:OnState(f.ctx.State)
	ui:_tick()
elseif state == "results" then
	f.ctx.State = {phase = "Results", roundId = 3, endsAt = 105, winners = {me, 7}, resultText = "Time is up: runners escaped!", players = {{userId = me, role = "Runner", displayName = "You"}, {userId = 7, role = "Runner", displayName = "FriendlyFox"}}}
	ui:OnState(f.ctx.State)
	ui:OnNotice({kind = "reward", xp = 120, coins = 80, rating = 24, pickups = 12, closeCalls = 3, tags = 0, finds = 0, survived = 150})
elseif state == "shop" then ui:OpenMenu("Shop")
elseif state == "locker" then ui:OpenMenu("Inventory")
elseif state == "more" then ui:ToggleMore()
elseif state == "lobby" then ui:OnState({phase = "Intermission", roundId = 2, endsAt = 114, players = {}})
end
local function color(c) return c and {c.R, c.G, c.B} or nil end
local function dump(object)
	local p = object._props
	local entry = {class = object.ClassName, name = object.Name, visible = p.Visible ~= false, z = p.ZIndex or 1, children = {}}
	if object.ClassName ~= "ScreenGui" then
		local pos, size, anchor = p.Position, p.Size, p.AnchorPoint
		if pos then entry.pos = {pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset} end
		if size then entry.size = {size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset} end
		if anchor then entry.anchor = {anchor.X, anchor.Y} end
	end
	entry.order = p.LayoutOrder or 0
	entry.bg = color(p.BackgroundColor3)
	entry.alpha = p.BackgroundTransparency or 0
	if p.Text ~= nil then
		entry.text, entry.textSize, entry.textColor = p.Text, p.TextSize, color(p.TextColor3)
		entry.textAlign = p.TextXAlignment and p.TextXAlignment.Name or "Left"
		entry.textTransparency = p.TextTransparency or 0
	end
	for _, child in ipairs(object._children) do
		if child.ClassName == "UICorner" then entry.corner = child._props.CornerRadius and child._props.CornerRadius.Offset or 8
		elseif child.ClassName == "UIListLayout" then
			entry.list = {horizontal = child._props.FillDirection == Enum.FillDirection.Horizontal, padding = child._props.Padding and child._props.Padding.Offset or 0,
				halign = child._props.HorizontalAlignment and child._props.HorizontalAlignment.Name or "Left"}
		elseif child.ClassName == "UIGridLayout" then
			local cs, cp = child._props.CellSize, child._props.CellPadding
			entry.grid = {cell = {cs.X.Scale, cs.X.Offset, cs.Y.Scale, cs.Y.Offset}, padding = {cp.X.Offset, cp.Y.Offset}}
		elseif child.ClassName == "UISizeConstraint" then
			entry.constraint = {min = child._props.MinSize and {child._props.MinSize.X, child._props.MinSize.Y}, max = child._props.MaxSize and {child._props.MaxSize.X, child._props.MaxSize.Y}}
		elseif child.ClassName == "UIGradient" and child._props.Color then
			local kp = child._props.Color.Keypoints
			if kp and kp[1] then entry.gradient = color(kp[1].Value) end
		elseif child.ClassName == "UIStroke" then
			entry.stroke = {color = color(child._props.Color), thickness = child._props.Thickness or 1}
		elseif child.ClassName == "UIScale" or child.ClassName == "UITextSizeConstraint" or child.ClassName == "UIPadding" then
		else table.insert(entry.children, dump(child)) end
	end
	return entry
end
local root = f.player:FindFirstChild("PlayerGui"):FindFirstChild("CatchMallUI")
fs.writeFile(output, serde.encode("json", {width = width, height = height, state = state, touch = touch, tree = dump(root)}, false))
print("Exported UI " .. state .. " " .. width .. "x" .. height .. " to " .. output)
