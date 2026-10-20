-- Original NEON MALL interface. Every persistent action goes through the server.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local UIController = {}
UIController.__index = UIController

local C = {
	background = Color3.fromRGB(14, 13, 38), panel = Color3.fromRGB(24, 22, 56),
	card = Color3.fromRGB(36, 32, 76), line = Color3.fromRGB(74, 66, 130),
	text = Color3.fromRGB(246, 244, 255), muted = Color3.fromRGB(170, 164, 210),
	cyan = Color3.fromRGB(72, 228, 240), coral = Color3.fromRGB(255, 108, 120),
	amber = Color3.fromRGB(255, 200, 92), green = Color3.fromRGB(120, 236, 170),
	magenta = Color3.fromRGB(240, 80, 196), purple = Color3.fromRGB(140, 100, 240),
	blue = Color3.fromRGB(84, 150, 255), orange = Color3.fromRGB(255, 150, 64),
}
local F = {regular = Enum.Font.Gotham, medium = Enum.Font.GothamMedium, bold = Enum.Font.GothamBold, black = Enum.Font.GothamBlack}

local function node(class, props, parent)
	local object = Instance.new(class)
	for key, value in pairs(props or {}) do object[key] = value end
	object.Parent = parent
	return object
end

local function corner(object, radius)
	node("UICorner", {CornerRadius = UDim.new(0, radius or 12)}, object)
end

local function stroke(object, color, transparency)
	return node("UIStroke", {Color = color or C.line, Transparency = transparency or 0, Thickness = 1}, object)
end

local function frame(parent, props, radius)
	props = props or {}
	if props.BorderSizePixel == nil then props.BorderSizePixel = 0 end
	if props.BackgroundColor3 == nil then props.BackgroundColor3 = C.panel end
	local object = node("Frame", props, parent)
	if radius then corner(object, radius) end
	return object
end

local function label(parent, text, props)
	local values = {
		Text = text or "", Font = F.regular, TextSize = 14, TextColor3 = C.text,
		BackgroundTransparency = 1, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1),
	}
	for key, value in pairs(props or {}) do values[key] = value end
	return node("TextLabel", values, parent)
end

local function scroll(parent, props, horizontal)
	local values = {
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 3,
		ScrollBarImageColor3 = C.cyan, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = horizontal and Enum.AutomaticSize.X or Enum.AutomaticSize.Y,
		ScrollingDirection = horizontal and Enum.ScrollingDirection.X or Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	}
	for key, value in pairs(props or {}) do values[key] = value end
	return node("ScrollingFrame", values, parent)
end

local function list(parent, horizontal, gap)
	return node("UIListLayout", {
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 10), SortOrder = Enum.SortOrder.LayoutOrder,
	}, parent)
end

local function number(value)
	local amount = math.floor(tonumber(value) or 0)
	local result = tostring(amount)
	while true do
		local nextResult, count = result:gsub("^(%-?%d+)(%d%d%d)", "%1,%2")
		result = nextResult
		if count == 0 then break end
	end
	return result
end

local function accent(item)
	local rgb = item and item.accent
	return rgb and Color3.fromRGB(rgb[1] or rgb.r or 68, rgb[2] or rgb.g or 230, rgb[3] or rgb.b or 231) or C.cyan
end

local function gradient(object, first, last, rotation)
	return node("UIGradient", {Color = ColorSequence.new(first, last), Rotation = rotation or 90}, object)
end

local function clear(parent)
	for _, child in ipairs(parent:GetChildren()) do child:Destroy() end
end

-- ======================================================================================
-- UI kit: gradients, outlines, drop shadows, hover/press motion, rarity + menu themes.
-- Icons are emoji glyphs rendered by Roblox's built-in emoji font (no uploaded assets).
-- ======================================================================================
local function shade(color, factor)
	return Color3.new(math.clamp(color.R * factor, 0, 1), math.clamp(color.G * factor, 0, 1), math.clamp(color.B * factor, 0, 1))
end

local function hook(object, name, callback)
	local signal = object[name]
	if signal and type(signal) ~= "boolean" and type(signal) ~= "number" and signal.Connect then return signal:Connect(callback) end
end

local function springTo(object, duration, props, style)
	pcall(function()
		TweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
	end)
end

-- Hover grows, press squashes, release pops. Works with mouse, touch and gamepad selection.
local function attachMotion(object, scale)
	hook(object, "MouseEnter", function() springTo(scale, 0.12, {Scale = 1.06}) end)
	hook(object, "MouseLeave", function() springTo(scale, 0.12, {Scale = 1}) end)
	hook(object, "MouseButton1Down", function() springTo(scale, 0.07, {Scale = 0.93}) end)
	hook(object, "MouseButton1Up", function() springTo(scale, 0.14, {Scale = 1.06}, Enum.EasingStyle.Back) end)
	hook(object, "SelectionGained", function() springTo(scale, 0.12, {Scale = 1.06}) end)
	hook(object, "SelectionLost", function() springTo(scale, 0.12, {Scale = 1}) end)
end

local function gloss(parent, radius)
	local sheen = frame(parent, {Name = "Gloss", Size = UDim2.fromScale(1, 0.5), Position = UDim2.new(), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, ZIndex = (parent.ZIndex or 1)}, radius or 12)
	node("UIGradient", {Transparency = NumberSequence.new(0.55, 1), Rotation = 90}, sheen)
	return sheen
end

local function button(parent, text, callback, props)
	local values = {
		Text = text, Font = F.bold, TextSize = 13, TextColor3 = C.text,
		BackgroundColor3 = C.card, BorderSizePixel = 0, AutoButtonColor = false,
		Selectable = true, Size = UDim2.fromOffset(150, 40),
		TextStrokeTransparency = 0.8, TextStrokeColor3 = Color3.new(0, 0, 0),
	}
	for key, value in pairs(props or {}) do values[key] = value end
	local object = node("TextButton", values, parent)
	local base = values.BackgroundColor3
	corner(object, 12)
	gloss(object, 11)
	node("UIStroke", {Color = shade(base, 0.45), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, object)
	local scale = node("UIScale", {Scale = 1}, object)
	attachMotion(object, scale)
	object.Activated:Connect(callback)
	return object
end

local RARITY = {
	Common = {main = Color3.fromRGB(150, 168, 200), deep = Color3.fromRGB(52, 60, 96), label = "COMMON"},
	Rare = {main = Color3.fromRGB(84, 172, 255), deep = Color3.fromRGB(32, 62, 130), label = "RARE"},
	Epic = {main = Color3.fromRGB(188, 120, 255), deep = Color3.fromRGB(70, 38, 130), label = "EPIC"},
	Legendary = {main = Color3.fromRGB(255, 202, 74), deep = Color3.fromRGB(128, 78, 22), label = "LEGENDARY"},
}
local function rarityOf(item) return RARITY[item and item.rarity or "Common"] or RARITY.Common end

-- One accent per menu: icon, header gradient, outline.
local THEME = {
	Shop = {icon = "🛍️", top = Color3.fromRGB(255, 176, 64), bottom = Color3.fromRGB(240, 96, 48), title = "SHOP"},
	Inventory = {icon = "👕", top = Color3.fromRGB(196, 136, 255), bottom = Color3.fromRGB(116, 70, 232), title = "LOCKER"},
	Quests = {icon = "📜", top = Color3.fromRGB(255, 216, 94), bottom = Color3.fromRGB(240, 150, 36), title = "QUESTS"},
	Progress = {icon = "🏆", top = Color3.fromRGB(80, 228, 204), bottom = Color3.fromRGB(34, 150, 176), title = "CAREER"},
	Leaderboard = {icon = "👥", top = Color3.fromRGB(110, 176, 255), bottom = Color3.fromRGB(54, 100, 232), title = "CREW"},
	Settings = {icon = "⚙️", top = Color3.fromRGB(176, 186, 220), bottom = Color3.fromRGB(104, 112, 160), title = "SETTINGS"},
	Results = {icon = "🎉", top = Color3.fromRGB(255, 120, 204), bottom = Color3.fromRGB(150, 80, 240), title = "RESULTS"},
}

-- Chunky icon button: drop shadow, gradient, thick outline, big glyph, small caption.
local function iconButton(parent, spec)
	local size = spec.size or 56
	local holder = frame(parent, {Name = (spec.name or "Icon") .. "Slot", Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, LayoutOrder = spec.order or 0})
	frame(holder, {Name = "Shadow", Position = UDim2.fromOffset(0, 4), Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55}, 16)
	local object = node("TextButton", {Name = spec.name, Text = "", AutoButtonColor = false, BackgroundColor3 = spec.top, Size = UDim2.fromScale(1, 1), Selectable = true, BorderSizePixel = 0}, holder)
	corner(object, 16)
	node("UIGradient", {Color = ColorSequence.new(spec.top, spec.bottom), Rotation = 90}, object)
	node("UIStroke", {Color = shade(spec.bottom, 0.5), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, object)
	gloss(object, 14)
	local glyph = label(object, spec.icon, {Name = "Glyph", Size = UDim2.fromScale(1, 0.68), Position = UDim2.fromScale(0, 0.04), TextXAlignment = Enum.TextXAlignment.Center, TextSize = math.floor(size * 0.46), Font = F.bold})
	local caption = label(object, spec.text or "", {Name = "Caption", Size = UDim2.fromScale(1, 0.26), Position = UDim2.fromScale(0, 0.70), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 9, Font = F.black, TextStrokeTransparency = 0.5, TextStrokeColor3 = shade(spec.bottom, 0.4)})
	local scale = node("UIScale", {Scale = 1}, holder)
	attachMotion(object, scale)
	if spec.callback then object.Activated:Connect(spec.callback) end
	return holder, object, glyph, caption
end

-- Pill-shaped progress bar with a gradient fill and a highlight.
local function progressBar(parent, props, ratio, colorA, colorB)
	local values = {BackgroundColor3 = Color3.fromRGB(18, 16, 44), Size = UDim2.new(1, 0, 0, 12)}
	for key, value in pairs(props or {}) do values[key] = value end
	local track = frame(parent, values, 100)
	node("UIStroke", {Color = Color3.fromRGB(8, 8, 24), Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, track)
	ratio = math.clamp(ratio or 0, 0, 1)
	local fill = frame(track, {Name = "Fill", Size = UDim2.fromScale(ratio > 0 and math.max(ratio, 0.05) or 0, 1), BackgroundColor3 = colorA, Visible = ratio > 0}, 100)
	node("UIGradient", {Color = ColorSequence.new(colorA, colorB or colorA), Rotation = 0}, fill)
	gloss(fill, 100)
	return track, fill
end

local function pill(parent, text, color, props)
	local values = {Text = text, Font = F.black, TextSize = 9, TextColor3 = shade(color, 0.18), BackgroundColor3 = color, BackgroundTransparency = 0,
		Size = UDim2.fromOffset(math.floor(#text * 6.4 + 16), 18), TextXAlignment = Enum.TextXAlignment.Center}
	for key, value in pairs(props or {}) do values[key] = value end
	local object = label(parent, text, values)
	corner(object, 9)
	return object
end

local function card(parent, props, accentColor)
	local values = {BackgroundColor3 = C.card}
	for key, value in pairs(props or {}) do values[key] = value end
	local object = frame(parent, values, 16)
	gradient(object, Color3.fromRGB(54, 48, 112), Color3.fromRGB(30, 27, 68), 90)
	node("UIStroke", {Color = accentColor or C.line, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.15}, object)
	return object
end

local function sectionLabel(parent, text, order)
	return label(parent, text, {Size = UDim2.new(1, -5, 0, 22), Font = F.black, TextSize = 12, TextColor3 = C.muted, LayoutOrder = order})
end

local function isQueued(ctx)
	local required = ctx and ctx.Config and ctx.Config.Round and ctx.Config.Round.RequireQueue
	return not required or Players.LocalPlayer:GetAttribute("CatchQueued") == true
end

-- Players who have not pressed PLAY stay in the Plaza hub; they are never spectators.
local function myRole(state, ctx)
	for _, record in ipairs(state.players or {}) do
		if record.userId == Players.LocalPlayer.UserId then return record.role, record.alive end
	end
	if (state.phase == "Active" or state.phase == "HeadStart") and isQueued(ctx) then return "Spectator", false end
	return "Lobby", true
end

local function clockText(seconds)
	local value = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", math.floor(value / 60), value % 60)
end

function UIController.new(ctx)
	return setmetatable({
		ctx = ctx, player = Players.LocalPlayer, category = "skins", selectedItem = "skin_courier",
		menu = nil, visited = false, spectateIndex = 1, toastSerial = 0, connections = {},
		lastRound = -1, lastRole = "Lobby", lastResult = -1, previewAngle = 0,
	}, UIController)
end

function UIController:_send(action, payload)
	self.ctx.Remotes.Action:FireServer(action, payload or {})
end

function UIController:_motion()
	return not (self.ctx.Profile.settings or {}).reducedMotion
end

function UIController:_tween(object, duration, props, style)
	if not self:_motion() then
		for key, value in pairs(props) do object[key] = value end
		return
	end
	TweenService:Create(object, TweenInfo.new(duration, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end

-- Confetti-style burst of small squares from the center of a GUI object.
function UIController:_burst(origin, colors)
	if not self:_motion() or not origin or not self.root then return end
	local size = origin.AbsoluteSize
	local center = origin.AbsolutePosition and (origin.AbsolutePosition + size / 2 - self.root.AbsolutePosition) or Vector2.new(0, 0)
	colors = colors or {C.amber, C.cyan, C.magenta, C.green}
	for index = 1, 14 do
		local angle = index * math.pi * 2 / 14
		local piece = frame(self.root, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(math.floor(center.X), math.floor(center.Y)), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = colors[index % #colors + 1], ZIndex = 60, Rotation = index * 25}, 3)
		springTo(piece, 0.7, {Position = UDim2.fromOffset(math.floor(center.X + math.cos(angle) * 70), math.floor(center.Y + math.sin(angle) * 70 + 14)), BackgroundTransparency = 1, Rotation = index * 25 + 180})
		task.delay(0.8, function() if piece.Parent then piece:Destroy() end end)
	end
end

function UIController:Start()
	if self.started then return end
	self.started = true
	self.Appearance = require(ReplicatedStorage:WaitForChild("CatchShared"):WaitForChild("Appearance"))
	self.gui = node("ScreenGui", {
		Name = "CatchCityUI", ResetOnSpawn = false, IgnoreGuiInset = false,
		DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, self.player:WaitForChild("PlayerGui"))
	-- Respect notches and home indicators; the left edge stays clear for Roblox chat.
	pcall(function() self.gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets end)
	-- The Roblox player list would sit under the wallet; the Plaza board and CREW menu replace it.
	local function hideCoreGui()
		pcall(function()
			local StarterGui = game:GetService("StarterGui")
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
	end
	hideCoreGui()
	-- The CoreGui can register late on slow devices; a second pass makes the setting stick.
	task.delay(3, hideCoreGui)
	self.root = frame(self.gui, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
	self:_buildHeader()
	self:_buildDock()
	self:_buildHero()
	self:_buildAbilities()
	self:_buildSpectator()
	self.panel = frame(self.root, {
		Name = "MenuPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(1, -40, 1, -160), BackgroundColor3 = C.background, Visible = false, ZIndex = 5,
	}, 22)
	self.panelConstraint = node("UISizeConstraint", {MaxSize = Vector2.new(1000, 640), MinSize = Vector2.new(270, 160)}, self.panel)
	self.panelStroke = stroke(self.panel, C.purple, 0)
	self.panelStroke.Thickness = 3
	gradient(self.panel, Color3.fromRGB(44, 36, 96), C.background, 100)
	self.panelScale = node("UIScale", {Scale = 1}, self.panel)
	-- Floating header card: themed gradient, round icon plate, title and a round close button.
	self.panelHeader = frame(self.panel, {Name = "Header", Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 58), BackgroundColor3 = C.purple, ZIndex = 6}, 18)
	self.panelGradient = gradient(self.panelHeader, C.purple, C.magenta, 0)
	node("UIStroke", {Color = Color3.fromRGB(10, 8, 30), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.3}, self.panelHeader)
	gloss(self.panelHeader, 16)
	local plate = frame(self.panelHeader, {Position = UDim2.fromOffset(9, 8), Size = UDim2.fromOffset(42, 42), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.78, ZIndex = 7}, 21)
	self.panelIcon = label(plate, "🛍️", {TextXAlignment = Enum.TextXAlignment.Center, TextSize = 24, ZIndex = 8})
	self.panelTitle = label(self.panelHeader, "THE COLLECTION", {Position = UDim2.fromOffset(62, 6), Size = UDim2.new(1, -130, 0, 28), Font = F.black, TextSize = 22, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 7, TextStrokeTransparency = 0.6, TextStrokeColor3 = Color3.fromRGB(20, 10, 40)})
	self.panelSubtitle = label(self.panelHeader, "", {Position = UDim2.fromOffset(62, 34), Size = UDim2.new(1, -130, 0, 18), TextColor3 = Color3.fromRGB(240, 236, 255), TextSize = 11, ZIndex = 7, TextTruncate = Enum.TextTruncate.AtEnd})
	self.panelClose = button(self.panelHeader, "✕", function() self:CloseMenu() end, {Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = Color3.fromRGB(240, 70, 92), TextSize = 18, Font = F.black, ZIndex = 8})
	self.panelContent = frame(self.panel, {Position = UDim2.fromOffset(16, 80), Size = UDim2.new(1, -32, 1, -96), BackgroundTransparency = 1})
	self:_buildToast()
	self:_buildAnnouncement()
	self:_buildTutorial()
	self:_buildLoading()
	self.connections[#self.connections + 1] = UserInputService.InputBegan:Connect(function(input)
		if self.menu and input.KeyCode == Enum.KeyCode.Escape then self:CloseMenu() end
	end)
	-- B must be consumed before the movement binding, including the closing press.
	ContextActionService:BindActionAtPriority("CatchCloseMenu", function(_, state)
		if state == Enum.UserInputState.Begin then
			self.consumingBack = self.menu ~= nil or GuiService.SelectedObject ~= nil
			if self.menu then self:CloseMenu()
			elseif self.consumingBack then GuiService.SelectedObject = nil end
		end
		local consume = self.consumingBack
		if state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then self.consumingBack = false end
		return consume and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
	end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.ButtonB)
	ContextActionService:BindActionAtPriority("CatchOpenMenu", function(_, state)
		if state == Enum.UserInputState.Begin then
			if self.menu then self:CloseMenu() else self:OpenMenu("Inventory") end
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.ButtonY)
	local dragConnection = hook(UserInputService, "InputChanged", function(input)
		local kind = input.UserInputType
		if self.dragging and (kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch) and input.Delta then
			self.previewAngle = (self.previewAngle or 0) - input.Delta.X * 0.012
			self.lastInteract = os.clock()
		end
	end)
	if dragConnection then self.connections[#self.connections + 1] = dragConnection end
	local dragEnd = hook(UserInputService, "InputEnded", function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then self.dragging = false end
	end)
	if dragEnd then self.connections[#self.connections + 1] = dragEnd end
	self.connections[#self.connections + 1] = UserInputService.LastInputTypeChanged:Connect(function()
		self:_responsive()
	end)
	self.connections[#self.connections + 1] = self.root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		self:_responsive()
		self.resizeSerial = (self.resizeSerial or 0) + 1
		local serial = self.resizeSerial
		task.delay(0.15, function()
			if serial == self.resizeSerial and self.menu then self:_renderMenu() end
		end)
	end)
	local accumulated = 0
	self.connections[#self.connections + 1] = RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated >= 0.1 then accumulated = 0 self:_tick() end
		if self.previewCamera and self.previewModel then
			self.previewTime = (self.previewTime or 0) + dt
			-- Gentle idle spin after a few quiet seconds; dragging and buttons take over immediately.
			if self:_motion() and not self.dragging and os.clock() - (self.lastInteract or 0) > 3 then self.previewAngle += dt * 0.35 end
			local angle = self.previewAngle + (self:_motion() and math.sin(self.previewTime * 0.38) * 0.12 or 0)
			self.previewCamera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * 11, 1.4, -math.cos(angle) * 11), Vector3.new(0, 0.15, 0))
		end
	end)
	self:_responsive()
	self:OnProfile(self.ctx.Profile)
	self:OnState(self.ctx.State)
end

function UIController:_buildHeader()
	-- Top row: round clock centered, wallet at the right. The left edge belongs to Roblox chat.
	self.header = frame(self.root, {Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 72), BackgroundTransparency = 1})
	self.clock = frame(self.header, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(236, 70), BackgroundColor3 = C.background, BackgroundTransparency = 0.06}, 16)
	self.clockStroke = stroke(self.clock, C.line, 0.1)
	gradient(self.clock, C.panel, C.background)
	frame(self.clock, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(64, 3), BackgroundColor3 = C.magenta}, 2)
	self.roundTrack = frame(self.clock, {Name = "RoundProgress", Position = UDim2.new(0, 14, 1, -7), Size = UDim2.new(1, -28, 0, 3), BackgroundColor3 = C.line}, 2)
	self.roundFill = frame(self.roundTrack, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.cyan}, 2)
	self.phaseLabel = label(self.clock, "WELCOME TO THE PLAZA", {Position = UDim2.fromOffset(5, 8), Size = UDim2.new(1, -10, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 10, Font = F.bold, TextColor3 = C.cyan})
	self.timerLabel = label(self.clock, "LOBBY", {Position = UDim2.fromOffset(5, 21), Size = UDim2.new(1, -10, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 28, Font = F.black})
	self.aliveLabel = label(self.clock, "Waiting for players", {Position = UDim2.fromOffset(5, 50), Size = UDim2.new(1, -10, 0, 12), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 10, TextColor3 = C.muted})
	self.wallet = frame(self.header, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 0), Size = UDim2.fromOffset(176, 58), BackgroundColor3 = C.background, BackgroundTransparency = 0.06}, 14)
	stroke(self.wallet, C.line, 0.1)
	gradient(self.wallet, C.panel, C.background)
	local coin = frame(self.wallet, {Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.amber}, 10)
	stroke(coin, Color3.fromRGB(255, 236, 170), 0.2)
	self.coinsLabel = label(self.wallet, "0", {Position = UDim2.fromOffset(38, 7), Size = UDim2.new(1, -48, 0, 24), Font = F.black, TextColor3 = C.amber, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Right})
	self.levelLabel = label(self.wallet, "LEVEL 1 / ROOKIE", {Position = UDim2.fromOffset(10, 34), Size = UDim2.new(1, -20, 0, 14), Font = F.medium, TextColor3 = C.muted, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right})
	self.roleChip = label(self.root, "EXPLORE THE PLAZA", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86), Size = UDim2.fromOffset(320, 20), Font = F.bold, TextSize = 11, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Center})
end

local DOCK = {
	{"Shop", "SHOP", "🛍️", Color3.fromRGB(255, 176, 64), Color3.fromRGB(240, 96, 48)},
	{"Inventory", "LOCKER", "👕", Color3.fromRGB(196, 136, 255), Color3.fromRGB(116, 70, 232)},
	{"Quests", "QUESTS", "📜", Color3.fromRGB(255, 216, 94), Color3.fromRGB(240, 150, 36)},
	{"Progress", "CAREER", "🏆", Color3.fromRGB(80, 228, 204), Color3.fromRGB(34, 150, 176)},
	{"Leaderboard", "CREW", "👥", Color3.fromRGB(110, 176, 255), Color3.fromRGB(54, 100, 232)},
}

function UIController:_buildDock()
	-- Five primary icon buttons plus a "more" toggle for SETTINGS and EMOTE.
	self.dock = frame(self.root, {Name = "Dock", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 96), Size = UDim2.fromOffset(60, 60), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY})
	self.dockLayout = list(self.dock, false, 8)
	self.dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	self.dockSlots = {}
	for index, entry in ipairs(DOCK) do
		local holder, object, glyph, caption = iconButton(self.dock, {name = entry[1], text = entry[2], icon = entry[3], top = entry[4], bottom = entry[5], order = index,
			callback = function() self:OpenMenu(entry[1]) end})
		table.insert(self.dockSlots, {holder = holder, glyph = glyph, caption = caption})
		if entry[1] == "Quests" then
			self.questBadge = frame(holder, {Name = "Badge", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = Color3.fromRGB(255, 64, 84), Visible = false, ZIndex = 5}, 10)
			node("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, self.questBadge)
			label(self.questBadge, "!", {TextXAlignment = Enum.TextXAlignment.Center, Font = F.black, TextSize = 13, ZIndex = 6})
		end
	end
	local moreHolder, moreButton, moreGlyph, moreCaption = iconButton(self.dock, {name = "More", text = "MORE", icon = "•••", top = Color3.fromRGB(150, 160, 200), bottom = Color3.fromRGB(88, 96, 150), order = 10})
	table.insert(self.dockSlots, {holder = moreHolder, glyph = moreGlyph, caption = moreCaption})
	self.moreExpanded = false
	local function secondary(name, text, icon, top, bottom, order, callback)
		local holder, object, glyph, caption = iconButton(self.dock, {name = name, text = text, icon = icon, top = top, bottom = bottom, order = order, callback = callback})
		holder.Visible = false
		table.insert(self.dockSlots, {holder = holder, glyph = glyph, caption = caption})
		return holder
	end
	self.settingsSlot = secondary("Settings", "SETTINGS", "⚙️", Color3.fromRGB(176, 186, 220), Color3.fromRGB(104, 112, 160), 11, function() self:OpenMenu("Settings") end)
	self.emoteSlot = secondary("Emote", "EMOTE", "😀", Color3.fromRGB(255, 160, 214), Color3.fromRGB(226, 84, 160), 12, function()
		local id = (self.ctx.Profile.equipped or {}).emotes
		if id and id ~= "" then self:_send("Emote", {id = id}) end
	end)
	self.emoteButton = self.emoteSlot
	moreButton.Activated:Connect(function()
		self.moreExpanded = not self.moreExpanded
		moreGlyph.Text = self.moreExpanded and "✕" or "•••"
		self:_responsive()
	end)
end

-- Bottom-center call to action. In the Plaza this is the PLAY / queue control.
function UIController:_buildHero()
	self.hero = frame(self.root, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(280, 86), BackgroundTransparency = 1})
	self.heroTitle = label(self.hero, "RUN THE MALL. OWN THE MOMENT.", {Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 16), Font = F.bold, TextSize = 11, TextColor3 = C.cyan, TextXAlignment = Enum.TextXAlignment.Center})
	self.heroDescription = label(self.hero, "Walk into the PLAY gate, or press the button.", {Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 16), TextColor3 = C.muted, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center})
	self.playButton = button(self.hero, "PLAY", function()
		local queued = self.player:GetAttribute("CatchQueued") == true
		self:_send(queued and "Leave" or "Play")
		self.optimisticQueue = not queued
		self.optimisticUntil = os.clock() + 1.5
		self:_updatePlay()
	end, {Name = "PlayButton", Position = UDim2.fromOffset(0, 20), Size = UDim2.fromOffset(280, 44), BackgroundColor3 = C.magenta, TextSize = 22, Font = F.black})
	gradient(self.playButton, C.magenta, C.purple, 0)
	self.saveLabel = label(self.root, "CONNECTING TO YOUR PROFILE", {Position = UDim2.new(0, 20, 1, -25), Size = UDim2.new(1, -125, 0, 15), TextColor3 = C.muted, TextSize = 9, TextTruncate = Enum.TextTruncate.AtEnd})
	self.versionLabel = label(self.root, "BUILD " .. tostring(self.ctx.Config.Version), {Name = "BuildVersion", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 1, -25), Size = UDim2.fromOffset(85, 15), TextColor3 = C.muted, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right})
end

function UIController:_updatePlay()
	if not self.playButton then return end
	local queued = self.player:GetAttribute("CatchQueued") == true
	if self.optimisticUntil and os.clock() < self.optimisticUntil then queued = self.optimisticQueue end
	local state = self.ctx.State or {}
	local count = state.queued or 0
	self.playButton.Text = queued and "IN QUEUE  /  LEAVE" or "PLAY"
	self.playButton.TextSize = queued and 15 or 22
	self.playButton.BackgroundColor3 = queued and C.card or C.magenta
	local gradientObject = self.playButton:FindFirstChildOfClass("UIGradient")
	if gradientObject then gradientObject.Enabled = not queued end
	self.heroDescription.Text = queued and (tostring(count) .. " queued / the chase starts automatically") or "Walk into the PLAY gate, or press the button."
end

function UIController:_buildAbilities()
	self.abilities = frame(self.root, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(384, 66), BackgroundTransparency = 1})
	local layout = list(self.abilities, true, 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	self.abilityLabels = {}
	local specs = {{"Sprint", "SHIFT", "L3", "🏃", Color3.fromRGB(80, 228, 204)}, {"Slide", "C", "B", "🌀", Color3.fromRGB(110, 176, 255)},
		{"Vault", "SPACE", "A", "🤸", Color3.fromRGB(196, 136, 255)}, {"Tag", "F", "R2", "✋", Color3.fromRGB(255, 120, 130)}}
	for index, spec in ipairs(specs) do
		local box = frame(self.abilities, {Size = UDim2.fromOffset(86, 64), BackgroundColor3 = C.background, BackgroundTransparency = 0.12, LayoutOrder = index}, 16)
		gradient(box, C.card, C.background)
		node("UIStroke", {Color = spec[5], Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.35}, box)
		local icon = label(box, spec[4], {Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(28, 28), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center})
		local name = label(box, string.upper(spec[1]), {Position = UDim2.fromOffset(38, 8), Size = UDim2.new(1, -44, 0, 18), Font = F.black, TextSize = 10})
		local status = label(box, spec[2], {Position = UDim2.fromOffset(8, 38), Size = UDim2.new(1, -16, 0, 18), TextColor3 = spec[5], TextSize = 10, Font = F.black, TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.6, BackgroundColor3 = C.line})
		corner(status, 9)
		local fill = frame(box, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -3), Size = UDim2.new(1, -20, 0, 2), BackgroundColor3 = spec[5]}, 2)
		self.abilityLabels[spec[1]] = {box = box, name = name, status = status, fill = fill, keyboard = spec[2], gamepad = spec[3], accent = spec[5]}
	end
end

function UIController:_buildSpectator()
	self.spectator = frame(self.root, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(320, 62), BackgroundColor3 = C.background, Visible = false}, 12)
	stroke(self.spectator)
	button(self.spectator, "<", function() self.spectateIndex -= 1 self:_updateSpectator() end, {Position = UDim2.fromOffset(8, 11), Size = UDim2.fromOffset(40, 40)})
	button(self.spectator, ">", function() self.spectateIndex += 1 self:_updateSpectator() end, {Position = UDim2.new(1, -48, 0, 11), Size = UDim2.fromOffset(40, 40)})
	label(self.spectator, "SPECTATING", {Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -104, 0, 16), TextColor3 = C.cyan, Font = F.bold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center})
	self.spectatorName = label(self.spectator, "Waiting for runners", {Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -104, 0, 22), Font = F.bold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd})
end

-- First-time onboarding: a compact bottom card, never a full-screen takeover.
function UIController:_buildTutorial()
	self.tutorial = card(self.root, {Name = "Tutorial", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.new(1, -24, 0, 196), BackgroundColor3 = C.background, Visible = false, ZIndex = 30}, C.cyan)
	node("UISizeConstraint", {MaxSize = Vector2.new(460, 210), MinSize = Vector2.new(260, 170)}, self.tutorial)
	local plate = frame(self.tutorial, {Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(56, 56), BackgroundColor3 = C.purple, ZIndex = 31}, 28)
	node("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, plate)
	self.tutorialIcon = label(plate, "👋", {TextXAlignment = Enum.TextXAlignment.Center, TextSize = 28, ZIndex = 32})
	self.tutorialStep = label(self.tutorial, "", {Position = UDim2.fromOffset(80, 12), Size = UDim2.new(1, -94, 0, 14), TextSize = 9, Font = F.black, TextColor3 = C.cyan, ZIndex = 31})
	self.tutorialTitle = label(self.tutorial, "", {Position = UDim2.fromOffset(80, 28), Size = UDim2.new(1, -94, 0, 28), Font = F.black, TextSize = 17, TextWrapped = true, ZIndex = 31, TextTruncate = Enum.TextTruncate.AtEnd})
	self.tutorialBody = label(self.tutorial, "", {Position = UDim2.fromOffset(80, 58), Size = UDim2.new(1, -94, 1, -118), TextSize = 12, TextColor3 = C.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31})
	self.tutorialDots = frame(self.tutorial, {Position = UDim2.new(0, 14, 1, -92), Size = UDim2.fromOffset(60, 12), BackgroundTransparency = 1, ZIndex = 31})
	self.tutorialSkip = button(self.tutorial, "SKIP", function() self:_finishTutorial() end, {Name = "TutorialSkip", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 14, 1, -12), Size = UDim2.fromOffset(84, 38), BackgroundColor3 = C.panel, TextSize = 12, ZIndex = 31})
	self.tutorialNext = button(self.tutorial, "NEXT", function() self:_tutorialAdvance() end, {Name = "TutorialNext", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -12), Size = UDim2.fromOffset(150, 38), BackgroundColor3 = C.cyan, TextColor3 = Color3.fromRGB(10, 40, 50), TextSize = 13, Font = F.black, ZIndex = 31})
end

function UIController:_tutorialPages()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local pad = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not touch
	local controls = touch and "Use the RUN, SLIDE and TAG buttons. The jump button also vaults low obstacles when you run at them."
		or (pad and "Sprint: L3     Slide: B     Jump / vault: A     Tag: R2     Locker: Y")
		or "Sprint: hold Shift     Slide: C while running     Jump / vault: Space     Tag: F"
	return {
		{title = "WELCOME TO THE NEON MALL", body = "Every round, HUNTERS chase RUNNERS through a two-story mall. Press PLAY in the Plaza to join the queue; rounds start by themselves."},
		{title = "RUNNERS: STAY FREE", body = "Use escalators, stairs and store back doors. Break line of sight, vault counters and outlast the clock to win."},
		{title = "HUNTERS: TAG THEM ALL", body = "Runners get a head start. Cut them off across the atrium. If nobody is near for a while you get a tracking pulse. Some rounds turn caught runners into hunters."},
		{title = "MOVE LIKE A LEGEND", body = controls .. "\n\nSlide under pressure, vault over obstacles, and keep your momentum."},
		{title = "EARN, CUSTOMIZE, SHOW OFF", body = "Win rounds and finish daily dispatches for coins and XP. Unlock skins, masks, trails and titles. Everything in the shop is cosmetic: nobody can buy an advantage."},
	}
end

function UIController:ShowTutorial()
	if not self.tutorial then return end
	self.tutorialPages = self:_tutorialPages()
	self.tutorialPage = 1
	self:CloseMenu()
	self.tutorial.Visible = true
	self:_renderTutorial()
end

function UIController:_renderTutorial()
	local page = self.tutorialPages[self.tutorialPage]
	self.tutorialStep.Text = "HOW TO PLAY  /  " .. self.tutorialPage .. " OF " .. #self.tutorialPages
	self.tutorialTitle.Text = page.title
	self.tutorialBody.Text = page.body
	self.tutorialNext.Text = self.tutorialPage == #self.tutorialPages and "LET'S RUN" or "NEXT"
	local icons = {"👋", "🏃", "✋", "🤸", "🎁"}
	self.tutorialIcon.Text = icons[self.tutorialPage] or "💡"
	clear(self.tutorialDots)
	for index = 1, #self.tutorialPages do
		frame(self.tutorialDots, {Position = UDim2.fromOffset((index - 1) * 12, 2), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = index == self.tutorialPage and C.cyan or C.line}, 4)
	end
end

function UIController:_tutorialAdvance()
	if self.tutorialPage >= #self.tutorialPages then
		self:_finishTutorial()
	else
		self.tutorialPage += 1
		self:_renderTutorial()
	end
end

function UIController:_finishTutorial()
	if self.tutorial then self.tutorial.Visible = false end
	self.visited = true
	self:_responsive()
	if (self.ctx.Profile.settings or {}).tutorialDone ~= true then
		self:_send("Settings", {tutorialDone = true})
	end
end

function UIController:_buildToast()
	self.toast = frame(self.root, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.new(0.8, 0, 0, 48), Visible = false, BackgroundColor3 = C.card, ZIndex = 20}, 24)
	node("UISizeConstraint", {MaxSize = Vector2.new(560, 80)}, self.toast)
	gradient(self.toast, C.card, C.background, 0)
	self.toastStroke = node("UIStroke", {Color = C.cyan, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, self.toast)
	self.toastIcon = label(self.toast, "💬", {Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(30, 48), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 21})
	self.toastText = label(self.toast, "", {Position = UDim2.fromOffset(48, 6), Size = UDim2.new(1, -62, 1, -12), TextSize = 13, Font = F.bold, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21})
end

function UIController:_buildAnnouncement()
	self.announcement = frame(self.root, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.new(0.85, 0, 0, 120), BackgroundColor3 = C.background, BackgroundTransparency = 0.04, Visible = false, ZIndex = 18}, 24)
	node("UISizeConstraint", {MaxSize = Vector2.new(560, 120)}, self.announcement)
	gradient(self.announcement, C.card, C.background, 90)
	self.announcementStroke = node("UIStroke", {Color = C.cyan, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, self.announcement)
	self.announcementTitle = label(self.announcement, "YOU ARE A RUNNER", {Position = UDim2.fromOffset(12, 14), Size = UDim2.new(1, -24, 0, 46), TextSize = 30, Font = F.black, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true, ZIndex = 19, TextStrokeTransparency = 0.5, TextStrokeColor3 = Color3.fromRGB(10, 8, 30)})
	node("UITextSizeConstraint", {MaxTextSize = 32, MinTextSize = 16}, self.announcementTitle)
	self.announcementCopy = label(self.announcement, "", {Position = UDim2.fromOffset(20, 66), Size = UDim2.new(1, -40, 0, 42), TextSize = 13, TextWrapped = true, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 19})
end

function UIController:_buildLoading()
	self.loading = frame(self.root, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.background, ZIndex = 50})
	frame(self.loading, {Position = UDim2.new(0.5, -24, 0.5, -100), Size = UDim2.fromOffset(48, 4), BackgroundColor3 = C.cyan}, 2)
	label(self.loading, "CATCH ME IF YOU CAN", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.47), Size = UDim2.new(0.9, 0, 0, 60), Font = F.black, TextSize = 32, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center})
	self.loadingStatus = label(self.loading, "Opening the city / loading your profile", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.57), Size = UDim2.new(0.85, 0, 0, 44), TextColor3 = C.muted, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center})
	task.delay(12, function()
		if self.loading and self.loading.Visible then self.loadingStatus.Text = "Your profile is taking longer to load. Reconnecting automatically..." end
	end)
end

function UIController:_responsive()
	local size = self.root.AbsoluteSize
	local small = size.X < 700
	local short = size.Y < 560
	local touch = UserInputService:GetLastInputType() == Enum.UserInputType.Touch
	self.compact = small
	-- Top row: clock stays centered; wallet shrinks beside it on phones.
	local tiny = size.X < 420
	self.clock.Size = UDim2.fromOffset(tiny and 130 or (small and 168 or 236), small and 62 or 70)
	self.phaseLabel.TextSize = small and 8 or 10
	self.timerLabel.TextSize = small and 22 or 28
	self.timerLabel.Position = UDim2.fromOffset(5, small and 17 or 21)
	self.aliveLabel.Position = UDim2.fromOffset(5, small and 43 or 50)
	self.aliveLabel.TextSize = small and 8 or 10
	self.wallet.Size = UDim2.fromOffset(tiny and 112 or (small and 120 or 176), small and 50 or 58)
	self.coinsLabel.TextSize = tiny and 14 or (small and 15 or 19)
	self.coinsLabel.Position = UDim2.fromOffset(small and 34 or 38, small and 5 or 7)
	self.levelLabel.TextSize = small and 8 or 10
	self.levelLabel.Position = UDim2.fromOffset(10, small and 29 or 34)
	self.roleChip.Position = UDim2.new(0.5, 0, 0, small and 76 or 86)
	-- Menu icons: a vertical rail on the right, or a compact row under the wallet on short landscape phones.
	local horizontal = short and size.X >= 600
	local button = small and 46 or 58
	self.dockLayout.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	self.dockLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	self.dock.Position = UDim2.new(1, -10, 0, horizontal and 78 or (small and 70 or 94))
	for _, slot in ipairs(self.dockSlots) do
		slot.holder.Size = UDim2.fromOffset(button, button)
		slot.glyph.TextSize = math.floor(button * 0.46)
		slot.caption.TextSize = button < 50 and 8 or 9
	end
	self.settingsSlot.Visible = self.moreExpanded
	self.emoteSlot.Visible = self.moreExpanded and not self.roundActiveForMe
	-- Menus are modal; keep them clear of the top bar and the clock.
	self.panelConstraint.MaxSize = self.menu == "Results" and Vector2.new(540, 450) or Vector2.new(1000, 640)
	self.panel.Size = UDim2.new(1, -24, 1, short and -104 or -150)
	self.panel.Position = UDim2.new(0.5, 0, 0.5, short and 42 or 50)
	self.panelTitle.TextSize = small and 18 or 22
	self.panelSubtitle.TextSize = small and 10 or 11
	self.panelSubtitle.TextTruncate = Enum.TextTruncate.AtEnd
	self.roleChip.Visible = not self.menu and not (short and size.X >= 600)
	-- PLAY control: Plaza only. Hidden during menus, the tutorial, and active rounds.
	local state = self.ctx.State or {}
	local role = myRole(state, self.ctx)
	local inRound = (state.phase == "Active" or state.phase == "HeadStart") and role ~= "Lobby"
	local tutorial = self.tutorial and self.tutorial.Visible
	self.roundActiveForMe = inRound
	self.dock.Visible = not self.menu and not inRound and not tutorial
	self.hero.Size = UDim2.fromOffset(math.min(size.X - 24, 280), 86)
	self.playButton.Size = UDim2.fromOffset(math.min(size.X - 24, 280), 44)
	self.hero.Position = UDim2.new(0.5, 0, 1, touch and (short and -16 or -28) or -96)
	self.hero.Visible = not self.menu and not tutorial and not inRound and role ~= "Spectator"
	self.heroTitle.Visible = not short
	self.heroDescription.Visible = not short
	self.abilities.Visible = not self.menu and not touch and not short and (inRound or role == "Spectator" or state.phase == "Active")
	self.spectator.Size = UDim2.fromOffset(math.min(320, size.X - 36), 62)
	self.spectator.Position = UDim2.new(0.5, 0, 1, touch and -32 or -96)
	self.saveLabel.Visible = not short
	self.versionLabel.Visible = not short
	self:_updatePlay()
	self:_updateSpectator()
end

function UIController:OpenMenu(name)
	if not self.ctx.Profile.loaded then return end
	if self.menu == name then self:CloseMenu() return end
	self.menu = name
	self.player:SetAttribute("CatchMenuOpen", true)
	local theme = THEME[name] or THEME.Shop
	self.panelGradient.Color = ColorSequence.new(theme.top, theme.bottom)
	self.panelStroke.Color = theme.bottom
	self.panelIcon.Text = theme.icon
	self.panel.Visible = true
	if self.toast then self.toast.AnchorPoint = Vector2.new(0.5, 1) self.toast.Position = UDim2.new(0.5, 0, 1, -20) end
	self.panelScale.Scale = self:_motion() and 0.9 or 1
	self:_tween(self.panelScale, 0.32, {Scale = 1}, Enum.EasingStyle.Back)
	self.hero.Visible = false
	self:_renderMenu()
	self:_responsive()
	if UserInputService.GamepadEnabled then
		local close = self.panelClose
		if close then GuiService.SelectedObject = close end
	end
end

function UIController:CloseMenu()
	self.menu = nil
	self.player:SetAttribute("CatchMenuOpen", false)
	self.panel.Visible = false
	self.previewModel = nil
	self.previewCamera = nil
	for _, rig in pairs(self.thumbCache or {}) do rig.Parent = nil end
	clear(self.panelContent)
	GuiService.SelectedObject = nil
	self:_responsive()
end

function UIController:_renderMenu()
	local focused = GuiService.SelectedObject
	local focusName = focused and focused:IsDescendantOf(self.panelContent) and focused.Name
	self.previewModel, self.previewCamera = nil, nil
	for _, rig in pairs(self.thumbCache or {}) do rig.Parent = nil end
	clear(self.panelContent)
	if self.menu == "Shop" or self.menu == "Inventory" then self:_renderShop()
	elseif self.menu == "Quests" then self:_renderQuests()
	elseif self.menu == "Progress" then self:_renderProgress()
	elseif self.menu == "Settings" then self:_renderSettings()
	elseif self.menu == "Leaderboard" then self:_renderLeaderboard()
	elseif self.menu == "Results" then self:_renderResults() end
	-- Rerendering an equipped item or category must not strand controller focus.
	if focusName then
		local replacement = self.panelContent:FindFirstChild(focusName, true)
		GuiService.SelectedObject = replacement and replacement:IsA("GuiButton") and replacement or self.panelClose
	end
end

function UIController:_itemPrice(item)
	if item.currency == "Coins" then return number(item.price) .. " COINS" end
	if item.currency == "Robux" then
		if not item.gamePassId or item.gamePassId == 0 then return "NOT CONFIGURED" end
		return "VIEW ROBUX PRICE"
	end
	if item.currency == "Milestone" then
		local milestone = item.milestone or {}
		local names = {rounds = "ROUNDS", wins = "WINS", tags = "TAGS", level = "LEVEL", bestStreak = "WIN STREAK", hunterWins = "HUNTER WINS", survived = "SECONDS SURVIVED"}
		return (names[milestone.stat] or string.upper(tostring(milestone.stat or "milestone"))) .. " " .. number(milestone.value)
	end
	return "FREE"
end

local CATEGORY_ICON = {skins = "👕", masks = "🎭", trails = "✨", emotes = "💃", tagEffects = "💥", victories = "🏆", nameplates = "🏷️", bundles = "🎁", vip = "👑"}

-- Small 3D bust for skin/mask cards. Rigs are cached and re-parented, never rebuilt per click.
function UIController:_thumbnail(parent, item, equipped)
	local category = item.category
	if category ~= "skins" and category ~= "masks" then return false end
	self.thumbCache = self.thumbCache or {}
	local skin = category == "skins" and item.id or ((equipped.skins ~= "" and equipped.skins) or "skin_courier")
	local mask = category == "masks" and item.id or ""
	local key = skin .. "|" .. mask
	local rig = self.thumbCache[key]
	if not rig then
		local ok, built = pcall(self.Appearance.BuildPreview, skin, mask, {})
		if not ok or not built then return false end
		rig = built
		self.thumbCache[key] = rig
	end
	local view = node("ViewportFrame", {Name = "Thumb", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(205, 200, 235), LightColor = Color3.fromRGB(255, 240, 224), LightDirection = Vector3.new(-1, -0.6, -1), ZIndex = 3}, parent)
	local world = node("WorldModel", {}, view)
	rig.Parent = world
	local focus = category == "masks" and Vector3.new(0, 2.3, 0) or Vector3.new(0, 1.15, 0)
	local distance = category == "masks" and 4.6 or 8.2
	local camera = node("Camera", {FieldOfView = category == "masks" and 30 or 34, CFrame = CFrame.lookAt(focus + Vector3.new(0.9, 0.2, -distance), focus)}, view)
	view.CurrentCamera = camera
	return true
end

function UIController:_pricePill(parent, item, owned, equipped, props)
	local text, color
	if equipped then text, color = "★ EQUIPPED", C.cyan
	elseif owned then text, color = "✔ OWNED", C.green
	elseif item.currency == "Coins" then text, color = "🪙 " .. number(item.price), C.amber
	elseif item.currency == "Robux" then text, color = ((item.gamePassId or 0) > 0) and ("R$ " .. number(item.price)) or "SOON", Color3.fromRGB(120, 220, 120)
	elseif item.currency == "Milestone" then text, color = "🔒 " .. self:_itemPrice(item), C.muted
	else text, color = "FREE", C.green end
	return pill(parent, text, color, props)
end

function UIController:_featuredItem()
	local best
	for _, category in ipairs(self.ctx.Catalog.Categories) do
		for _, item in ipairs(self.ctx.Catalog.ForCategory(category.id)) do
			if not (self.ctx.Profile.owned or {})[item.id] and item.currency ~= "Milestone" and (item.rarity == "Legendary" or item.rarity == "Epic") then
				if not best or (item.rarity == "Legendary" and best.rarity ~= "Legendary") then best = item end
			end
		end
	end
	return best
end

function UIController:_renderShop()
	local inventory = self.menu == "Inventory"
	self.panelTitle.Text = inventory and "THE FIT STUDIO" or "COLLECTION"
	self.panelSubtitle.Text = inventory and "Build your signature. Every mask works with every outfit." or "Original citywear. Try on the look. Keep the chase fair."
	local panelSize = self.panel.AbsoluteSize
	local contentSize = self.panelContent.AbsoluteSize
	local narrow = panelSize.X < 600
	local profile = self.ctx.Profile
	local owned = profile.owned or {}
	local equipped = profile.equipped or {}
	local visible = {}
	for _, item in ipairs(self.ctx.Catalog.ForCategory(self.category)) do
		if not inventory or owned[item.id] then visible[#visible + 1] = item end
	end
	local selected = self.ctx.Catalog.Get(self.selectedItem)
	local selectionValid = false
	for _, item in ipairs(visible) do if item.id == self.selectedItem then selectionValid = true break end end
	if not selectionValid then selected = visible[1] self.selectedItem = selected and selected.id or nil end
	local rare = rarityOf(selected)
	-- Left: fitting stage. Right: tabs, featured banner and card grid. Narrow screens stack both in one scroll.
	local surface = narrow and scroll(self.panelContent, {Name = "CompactCollection"}) or self.panelContent
	local stageHeight = narrow and 300 or math.clamp(contentSize.Y - 250, 140, 340)
	local detail = narrow and frame(surface, {Name = "FittingStage", Position = UDim2.new(), Size = UDim2.new(1, -5, 0, stageHeight + 214), BackgroundColor3 = C.panel}, 18)
		or scroll(surface, {Name = "FittingStage", Position = UDim2.new(), Size = UDim2.new(0.42, -8, 1, 0), BackgroundColor3 = C.panel, BackgroundTransparency = 0, ScrollBarThickness = 0})
	if not narrow then corner(detail, 18) end
	stroke(detail, rare.main, 0.55)
	gradient(detail, shade(rare.deep, 1.1), C.background, 110)
	local collection = frame(surface, {
		Position = narrow and UDim2.fromOffset(0, stageHeight + 214 + 14) or UDim2.new(0.42, 6, 0, 0),
		Size = narrow and UDim2.new(1, -5, 0, 1200) or UDim2.new(0.58, -6, 1, 0), BackgroundTransparency = 1,
	})
	-- Category tabs.
	local tabs = scroll(collection, {Name = "Categories", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 46), ScrollBarThickness = 0}, true)
	list(tabs, true, 6)
	for index, category in ipairs(self.ctx.Catalog.Categories) do
		local active = self.category == category.id
		button(tabs, (CATEGORY_ICON[category.id] or "•") .. " " .. string.upper(category.label), function()
			self.category = category.id self:_renderMenu()
		end, {Name = "Category_" .. category.id, Size = UDim2.fromOffset(math.floor(math.max(86, #category.label * 7.5 + 46)), 40), LayoutOrder = index, TextSize = 11,
			BackgroundColor3 = active and (THEME[self.menu] or THEME.Shop).top or C.card,
			TextColor3 = active and Color3.fromRGB(30, 20, 50) or C.muted})
	end
	local top = 52
	-- Featured banner (shop only).
	local featured = not inventory and contentSize.Y >= 330 and self:_featuredItem()
	if featured then
		local fr = rarityOf(featured)
		local banner = frame(collection, {Name = "FeaturedBanner", Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, -4, 0, 62), BackgroundColor3 = fr.deep}, 16)
		gradient(banner, fr.main, fr.deep, 0)
		node("UIStroke", {Color = shade(fr.deep, 0.5), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, banner)
		gloss(banner, 14)
		label(banner, "⭐", {Position = UDim2.fromOffset(10, 0), Size = UDim2.fromOffset(36, 62), TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3})
		label(banner, "FEATURED  /  " .. fr.label, {Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -170, 0, 14), TextSize = 9, Font = F.black, TextColor3 = Color3.fromRGB(255, 255, 255), ZIndex = 3})
		label(banner, featured.name, {Position = UDim2.fromOffset(52, 24), Size = UDim2.new(1, -170, 0, 30), TextSize = 18, Font = F.black, ZIndex = 3, TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeTransparency = 0.6, TextStrokeColor3 = shade(fr.deep, 0.3)})
		button(banner, "VIEW", function()
			self.category, self.selectedItem = featured.category, featured.id
			self:_renderMenu()
		end, {Name = "ViewFeatured", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(84, 36), BackgroundColor3 = Color3.fromRGB(255, 255, 255), TextColor3 = shade(fr.deep, 0.5), TextSize = 12, ZIndex = 4})
		top += 70
	end
	-- Card grid.
	local gridProps = {Name = "Grid", Position = UDim2.fromOffset(0, top), Size = UDim2.new(1, 0, 1, -top), BackgroundTransparency = 1}
	local grid = narrow and frame(collection, gridProps) or scroll(collection, gridProps)
	local gridWidth = (narrow and panelSize.X - 56) or (panelSize.X - 32) * 0.58 - 14
	local columns = math.max(2, math.floor(gridWidth / 150))
	local cellHeight = 178
	node("UIGridLayout", {CellPadding = UDim2.fromOffset(10, 10), CellSize = UDim2.new(1 / columns, -10, 0, cellHeight), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	if narrow then
		collection.Size = UDim2.new(1, -5, 0, top + math.ceil(math.max(#visible, 1) / columns) * (cellHeight + 10) + 8)
		surface.CanvasSize = UDim2.fromOffset(0, stageHeight + 214 + 14 + collection.Size.Y.Offset)
		grid.Size = UDim2.new(1, 0, 1, -top)
	end
	for index, item in ipairs(visible) do
		local rr = rarityOf(item)
		local chosen = self.selectedItem == item.id
		local isOwned, isEquipped = owned[item.id] == true, equipped[item.category] == item.id
		local card = button(grid, "", function() self.selectedItem = item.id self:_renderMenu() end, {Name = "Item_" .. item.id, LayoutOrder = index, BackgroundColor3 = rr.deep})
		gradient(card, shade(rr.main, 0.55), shade(rr.deep, 0.8), 90)
		local cardStroke = card:FindFirstChildOfClass("UIStroke")
		if cardStroke then cardStroke.Color = chosen and Color3.new(1, 1, 1) or rr.main cardStroke.Thickness = chosen and 3.5 or 2 end
		local thumb = frame(card, {Name = "ThumbArea", Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 92), BackgroundColor3 = shade(rr.deep, 0.6), BackgroundTransparency = 0.2, ZIndex = 2}, 12)
		local glow = frame(thumb, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(0.6, 0, 0, 10), BackgroundColor3 = rr.main, BackgroundTransparency = 0.5, ZIndex = 2}, 5)
		if not self:_thumbnail(thumb, item, equipped) then
			label(thumb, CATEGORY_ICON[item.category] or "🎁", {TextXAlignment = Enum.TextXAlignment.Center, TextSize = 38, ZIndex = 3})
		end
		pill(card, rr.label, rr.main, {Name = "RarityBadge", Position = UDim2.fromOffset(12, 12), ZIndex = 5})
		label(card, item.name, {Position = UDim2.fromOffset(10, 104), Size = UDim2.new(1, -20, 0, 34), Font = F.black, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 3})
		self:_pricePill(card, item, isOwned, isEquipped, {Name = "StatusPill", Position = UDim2.new(0, 10, 1, -28), Size = UDim2.new(1, -20, 0, 20), ZIndex = 4, TextSize = 10})
	end
	if #visible == 0 then
		label(collection, "Your signature starts here.\nFind your next favorite in the collection.", {Position = UDim2.fromOffset(12, top + 40), Size = UDim2.new(1, -24, 0, 80), TextWrapped = true, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center})
		button(collection, "EXPLORE COLLECTION", function() self:OpenMenu("Shop") end, {Name = "ExploreShop", Position = UDim2.fromOffset(12, top + 130), Size = UDim2.new(1, -24, 0, 44), BackgroundColor3 = THEME.Shop.top, TextColor3 = Color3.fromRGB(40, 20, 20)})
	end
	self:_renderItemDetail(detail, selected, stageHeight, narrow)
end

function UIController:_renderItemDetail(parent, item, stageHeight, narrow)
	if not item then label(parent, "SELECT YOUR SIGNATURE", {TextColor3 = C.muted, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center}) return end
	local profile = self.ctx.Profile
	local owned = (profile.owned or {})[item.id] == true
	local equipped = profile.equipped or {}
	local rr = rarityOf(item)
	local width = narrow and 1 or 1
	label(parent, "LIVE FIT  /  " .. string.upper(item.category), {Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 16), Font = F.black, TextSize = 10, TextColor3 = rr.main})
	local stage = frame(parent, {Name = "PreviewStage", Active = true, Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 0, stageHeight), BackgroundColor3 = shade(rr.deep, 0.7)}, 16)
	gradient(stage, shade(rr.main, 0.5), shade(rr.deep, 0.5), 90)
	local plate = frame(stage, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -46), Size = UDim2.new(0.62, 0, 0, 24), BackgroundColor3 = rr.main, BackgroundTransparency = 0.55}, 100)
	node("UIStroke", {Color = rr.main, Thickness = 2, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, plate)
	local view = node("ViewportFrame", {
		Name = "CharacterPreview", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -34),
		Ambient = Color3.fromRGB(205, 200, 235), LightColor = Color3.fromRGB(255, 240, 224), LightDirection = Vector3.new(-1, -0.6, -1), ZIndex = 3,
	}, stage)
	local world = node("WorldModel", {}, view)
	local extra = table.clone(equipped)
	if self.ctx.Catalog.IsEquippable(item.category) then extra[item.category] = item.id end
	for _, grantedId in ipairs(item.grants or {}) do
		local granted = self.ctx.Catalog.Get(grantedId)
		if granted and self.ctx.Catalog.IsEquippable(granted.category) then extra[granted.category] = granted.id end
	end
	local skin = extra.skins ~= "" and extra.skins or "skin_courier"
	local mask = extra.masks or ""
	local success, rig = pcall(self.Appearance.BuildPreview, skin, mask, extra)
	if success and rig then
		rig.Parent = world
		self.previewModel = rig
		self.previewAngle, self.previewTime, self.lastInteract = 0.18, 0, os.clock()
		local camera = node("Camera", {FieldOfView = 38, CFrame = CFrame.lookAt(Vector3.new(2, 1.4, -11), Vector3.new(0, 0.15, 0))}, view)
		view.CurrentCamera = camera self.previewCamera = camera
	else
		label(stage, "PREVIEW UNAVAILABLE", {Size = view.Size, TextColor3 = C.muted, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center})
	end
	-- Drag anywhere on the stage to spin the character.
	hook(stage, "InputBegan", function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then self.dragging = true self.lastInteract = os.clock() end
	end)
	label(stage, "DRAG TO SPIN", {Position = UDim2.new(0, 10, 0, 8), Size = UDim2.fromOffset(110, 14), TextSize = 9, Font = F.bold, TextColor3 = Color3.fromRGB(255, 255, 255), TextTransparency = 0.4, ZIndex = 5})
	local controls = frame(stage, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.fromOffset(190, 34), BackgroundTransparency = 1, ZIndex = 6})
	local function nudge(delta) self.previewAngle += delta self.lastInteract = os.clock() end
	button(controls, "<", function() nudge(-math.pi / 4) end, {Name = "PreviewLeft", Size = UDim2.fromOffset(42, 32), TextSize = 16, ZIndex = 7})
	button(controls, "FRONT", function() self.previewAngle, self.previewTime = 0, 0 self.lastInteract = os.clock() end, {Name = "PreviewFront", Position = UDim2.fromOffset(48, 0), Size = UDim2.fromOffset(94, 32), TextSize = 10, ZIndex = 7})
	button(controls, ">", function() nudge(math.pi / 4) end, {Name = "PreviewRight", Position = UDim2.fromOffset(148, 0), Size = UDim2.fromOffset(42, 32), TextSize = 16, ZIndex = 7})
	local y = 30 + stageHeight + 12
	local info = frame(parent, {Name = "ItemInformation", Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, 190), BackgroundTransparency = 1})
	pill(info, rr.label, rr.main, {Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(math.floor(#rr.label * 7 + 16), 20), TextSize = 10})
	self:_pricePill(info, item, owned, equipped[item.category] == item.id, {Position = UDim2.new(1, -110, 0, 0), Size = UDim2.fromOffset(110, 20), TextSize = 10, AnchorPoint = Vector2.new(0, 0)})
	label(info, item.name, {Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 30), TextSize = 22, Font = F.black, TextTruncate = Enum.TextTruncate.AtEnd})
	label(info, item.description or "", {Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 62), TextSize = 11, TextColor3 = C.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
	local configured = item.currency ~= "Robux" or (item.gamePassId or 0) > 0
	local canUnequip = owned and equipped[item.category] == item.id
		and (item.category ~= "skins" or item.id ~= self.ctx.Catalog.DefaultEquipment.skins)
		and self.ctx.Catalog.IsEquippable(item.category) and self.menu == "Inventory"
	local actionText
	if self.pendingId == item.id then actionText = "WAITING FOR SERVER..."
	elseif canUnequip then actionText = item.category == "skins" and "USE DEFAULT LOOK" or "UNEQUIP"
	elseif owned and equipped[item.category] == item.id then actionText = "EQUIPPED"
	elseif owned and self.ctx.Catalog.IsEquippable(item.category) then actionText = "EQUIP"
	elseif owned then actionText = "OWNED"
	elseif not configured then actionText = "NOT CONFIGURED"
	elseif item.currency == "Milestone" then actionText = self:_itemPrice(item)
	else actionText = item.currency == "Free" and "CLAIM FREE" or self:_itemPrice(item) end
	local canAct = not self.pendingId and (canUnequip or (owned and self.ctx.Catalog.IsEquippable(item.category) and equipped[item.category] ~= item.id) or (not owned and configured and item.currency ~= "Milestone"))
	local theme = THEME[self.menu] or THEME.Shop
	local action = button(info, actionText, function()
		if not canAct then
			if not configured and not owned then self:Toast("This item is not configured for purchase yet.") end
			return
		end
		-- Set pending before firing so an immediate profile response wins the race.
		self.pendingId = item.id
		if owned then self:_send("Equip", {category = item.category, id = canUnequip and "" or item.id})
		else self:_send("Buy", {id = item.id}) end
		self:_renderMenu()
		task.delay(8, function()
			if self.pendingId == item.id then
				self.pendingId = nil
				if self.menu == "Shop" or self.menu == "Inventory" then self:_renderMenu() end
			end
		end)
	end, {Name = "ItemAction", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 46), TextSize = 14, Font = F.black,
		BackgroundColor3 = canAct and theme.top or C.card, TextColor3 = canAct and Color3.fromRGB(36, 20, 40) or C.muted})
	self.lastActionButton = action
	if narrow then parent.Size = UDim2.new(1, -5, 0, y + 190 + 8) end
	if parent.ClassName == "ScrollingFrame" then parent.CanvasSize = UDim2.fromOffset(0, y + 190 + 8) end
end

local QUEST_ICON = {rounds = "🏁", tags = "✋", survived = "⏱️", wins = "🏆"}

function UIController:_renderQuests()
	self.panelTitle.Text = "DAILY QUESTS"
	self.panelSubtitle.Text = "Fresh challenges every day / refreshes at 00:00 UTC"
	local container = scroll(self.panelContent)
	list(container, false, 12)
	local quests = self.ctx.Profile.quests or {}
	local narrow = self.panelContent.AbsoluteSize.X < 520
	local login = self.ctx.Profile.loginStatus
	if login then
		local done = login.canClaim and (login.day - 1) or login.day
		local box = card(container, {Name = "DailyLogin", Size = UDim2.new(1, -5, 0, narrow and 196 or 150), LayoutOrder = 0}, login.canClaim and C.amber or C.line)
		pill(box, "DAILY LOGIN", C.amber, {Position = UDim2.fromOffset(16, 14), Size = UDim2.fromOffset(104, 20), TextSize = 10})
		label(box, "DAY " .. number(login.day) .. " OF 7", {Position = UDim2.fromOffset(128, 14), Size = UDim2.fromOffset(100, 20), Font = F.black, TextSize = 11, TextColor3 = C.muted})
		label(box, login.canClaim and ("🪙 +" .. number(login.coins) .. "     ✨ +" .. number(login.xp) .. " XP")
			or ("Claimed! Come back tomorrow to extend your " .. number(login.streak) .. "-day streak."), {Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, narrow and -32 or -170, 0, 26), TextSize = login.canClaim and 17 or 13, Font = F.bold, TextWrapped = true})
		for day = 1, 7 do
			local reached, current = day <= done, day == done + 1 and login.canClaim
			local chip = frame(box, {Name = "LoginDay" .. day, Position = UDim2.fromOffset(16 + (day - 1) * 46, 76), Size = UDim2.fromOffset(40, 44), BackgroundColor3 = reached and C.green or (current and C.amber or Color3.fromRGB(26, 24, 58))}, 12)
			node("UIStroke", {Color = reached and shade(C.green, 0.5) or (current and Color3.new(1, 1, 1) or C.line), Thickness = current and 3 or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, chip)
			label(chip, reached and "✔" or (day == 7 and "👑" or tostring(day)), {TextXAlignment = Enum.TextXAlignment.Center, Font = F.black, TextSize = 16, TextColor3 = (reached or current) and Color3.fromRGB(30, 24, 50) or C.muted})
		end
		local claim = button(box, login.canClaim and "CLAIM" or "CLAIMED", function() end, {Name = "ClaimLogin",
			AnchorPoint = narrow and Vector2.new(0.5, 1) or Vector2.new(1, 0), Position = narrow and UDim2.new(0.5, 0, 1, -12) or UDim2.new(1, -16, 0, 36), Size = narrow and UDim2.new(1, -32, 0, 40) or UDim2.fromOffset(140, 56),
			TextSize = 14, Font = F.black, BackgroundColor3 = login.canClaim and C.amber or C.card, TextColor3 = login.canClaim and Color3.fromRGB(50, 30, 10) or C.muted})
		claim.Activated:Connect(function()
			if login.canClaim then self:_send("ClaimLogin") self:_burst(claim, {C.amber, C.green, C.cyan}) end
		end)
	end
	sectionLabel(container, "TODAY'S CHALLENGES", 1)
	for index, quest in ipairs(quests) do
		local ratio = math.clamp((quest.progress or 0) / math.max(quest.goal or 1, 1), 0, 1)
		local claimable = ratio >= 1 and not quest.claimed
		local box = card(container, {Name = "Dispatch_" .. quest.id, Size = UDim2.new(1, -5, 0, narrow and 150 or 108), LayoutOrder = index + 1}, claimable and C.green or (quest.claimed and C.line or C.cyan))
		local badge = frame(box, {Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = quest.claimed and C.line or (claimable and C.green or C.purple)}, 26)
		node("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, badge)
		label(badge, quest.claimed and "✔" or (QUEST_ICON[quest.id] or "🎯"), {TextXAlignment = Enum.TextXAlignment.Center, TextSize = 26})
		label(box, quest.text, {Position = UDim2.fromOffset(78, 10), Size = UDim2.new(1, narrow and -92 or -230, 0, 24), TextSize = 15, Font = F.black, TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = quest.claimed and C.muted or C.text})
		pill(box, "🪙 +" .. number(quest.coins), C.amber, {Position = UDim2.fromOffset(78, 40), Size = UDim2.fromOffset(78, 20), TextSize = 10})
		pill(box, "✨ +" .. number(quest.xp) .. " XP", C.cyan, {Position = UDim2.fromOffset(162, 40), Size = UDim2.fromOffset(90, 20), TextSize = 10})
		local track = progressBar(box, {Position = UDim2.fromOffset(78, 74), Size = UDim2.new(1, narrow and -92 or -246, 0, 16)}, ratio, quest.claimed and C.muted or (claimable and C.green or C.cyan), quest.claimed and C.line or (claimable and Color3.fromRGB(70, 200, 120) or C.blue or C.purple))
		label(track, number(math.min(quest.progress or 0, quest.goal or 0)) .. " / " .. number(quest.goal), {TextXAlignment = Enum.TextXAlignment.Center, Font = F.black, TextSize = 10, ZIndex = 5, TextStrokeTransparency = 0.5})
		local claim = button(box, quest.claimed and "CLAIMED ✔" or (claimable and "CLAIM REWARD" or "IN PROGRESS"), function() end, {Name = "Quest_" .. quest.id,
			AnchorPoint = narrow and Vector2.new(0.5, 1) or Vector2.new(1, 0.5), Position = narrow and UDim2.new(0.5, 0, 1, -10) or UDim2.new(1, -14, 0.5, 0), Size = narrow and UDim2.new(1, -28, 0, 36) or UDim2.fromOffset(140, 48),
			TextSize = 12, Font = F.black, BackgroundColor3 = claimable and C.green or C.card, TextColor3 = claimable and Color3.fromRGB(14, 50, 30) or C.muted})
		claim.Activated:Connect(function()
			if claimable then self:_send("ClaimQuest", {id = quest.id}) self:_burst(claim, {C.green, C.amber, C.cyan}) end
		end)
	end
	if #quests == 0 then label(container, "Your daily quests are loading.", {Size = UDim2.new(1, 0, 0, 50), TextColor3 = C.muted}) end
end

local STAT_ICON = {"🏁", "🏆", "✋", "🎯", "🏃", "🔥", "⏱️"}

function UIController:_renderProgress()
	local profile = self.ctx.Profile
	self.panelTitle.Text = "YOUR CAREER"
	self.panelSubtitle.Text = "Every chase counts. Studio solo practice gives no rewards."
	local container = scroll(self.panelContent)
	list(container, false, 12)
	local narrow = self.panelContent.AbsoluteSize.X < 520
	local level = profile.level or 1
	local lower, upper = self.ctx.Rules.XPForLevel(level), self.ctx.Rules.XPForLevel(level + 1)
	local ratio = math.clamp(((profile.xp or 0) - lower) / math.max(upper - lower, 1), 0, 1)
	local hero = card(container, {Name = "RankCard", Size = UDim2.new(1, -5, 0, 150), LayoutOrder = 1}, C.cyan)
	local ring = frame(hero, {Position = UDim2.fromOffset(18, 20), Size = UDim2.fromOffset(104, 104), BackgroundColor3 = C.cyan}, 52)
	gradient(ring, Color3.fromRGB(80, 228, 204), Color3.fromRGB(34, 150, 176), 90)
	node("UIStroke", {Color = Color3.new(1, 1, 1), Thickness = 3, Transparency = 0.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, ring)
	label(ring, "LEVEL", {Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, Font = F.black, TextSize = 10, TextColor3 = Color3.fromRGB(20, 60, 70)})
	label(ring, number(level), {Position = UDim2.fromOffset(0, 32), Size = UDim2.new(1, 0, 0, 50), TextXAlignment = Enum.TextXAlignment.Center, Font = F.black, TextSize = 40, TextStrokeTransparency = 0.6})
	label(hero, string.upper(profile.rank or "ROOKIE"), {Position = UDim2.fromOffset(138, 18), Size = UDim2.new(1, -150, 0, 34), Font = F.black, TextSize = narrow and 22 or 28, TextTruncate = Enum.TextTruncate.AtEnd})
	pill(hero, "⭐ " .. number(profile.rating) .. " RATING", C.amber, {Position = UDim2.fromOffset(138, 56), Size = UDim2.fromOffset(130, 20), TextSize = 10})
	local track = progressBar(hero, {Name = "XPBar", Position = UDim2.fromOffset(138, 92), Size = UDim2.new(1, -156, 0, 20)}, ratio, C.cyan, C.blue)
	label(track, number(profile.xp) .. " / " .. number(upper) .. " XP", {TextXAlignment = Enum.TextXAlignment.Center, Font = F.black, TextSize = 11, ZIndex = 5, TextStrokeTransparency = 0.5})
	label(hero, number(math.max(upper - (profile.xp or 0), 0)) .. " XP to level " .. number(level + 1), {Position = UDim2.fromOffset(138, 118), Size = UDim2.new(1, -156, 0, 16), TextSize = 10, TextColor3 = C.muted})
	sectionLabel(container, "LIFETIME STATS", 2)
	local stats = profile.stats or {}
	local specs = {{"ROUNDS", stats.rounds}, {"WINS", stats.wins}, {"TAGS", stats.tags}, {"HUNTER WINS", stats.hunterWins}, {"RUNNER WINS", stats.runnerWins}, {"BEST STREAK", profile.bestStreak}, {"SECONDS SURVIVED", stats.survived}}
	local grid = frame(container, {Name = "StatGrid", Size = UDim2.new(1, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3})
	local columns = narrow and 2 or 4
	node("UIGridLayout", {CellPadding = UDim2.fromOffset(10, 10), CellSize = UDim2.new(1 / columns, -10, 0, 78), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	for index, spec in ipairs(specs) do
		local tile = card(grid, {Name = "Stat_" .. index, LayoutOrder = index, Size = UDim2.new(1 / columns, -10, 0, 78)}, C.line)
		label(tile, STAT_ICON[index], {Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(30, 30), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center})
		label(tile, number(spec[2]), {Position = UDim2.fromOffset(44, 6), Size = UDim2.new(1, -52, 0, 32), Font = F.black, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Right})
		label(tile, spec[1], {Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -24, 0, 18), Font = F.bold, TextSize = 10, TextColor3 = C.muted})
	end
	sectionLabel(container, "BADGES  " .. tostring(self:_countBadges()) .. " / " .. #self.ctx.Achievements.List, 4)
	local badges = frame(container, {Name = "BadgeGrid", Size = UDim2.new(1, -5, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 5})
	node("UIGridLayout", {CellPadding = UDim2.fromOffset(10, 10), CellSize = UDim2.new(narrow and 1 or 0.5, -10, 0, 88), SortOrder = Enum.SortOrder.LayoutOrder}, badges)
	for index, achievement in ipairs(self.ctx.Achievements.List) do
		local unlocked = (profile.achievements or {})[achievement.id] == true
		local current = (profile.stats or {})[achievement.stat] or profile[achievement.stat] or 0
		local box = card(badges, {Name = "Badge_" .. achievement.id, LayoutOrder = index, Size = UDim2.new(narrow and 1 or 0.5, -10, 0, 88)}, unlocked and C.amber or C.line)
		local medal = frame(box, {Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = unlocked and C.amber or Color3.fromRGB(32, 30, 66)}, 26)
		node("UIStroke", {Color = unlocked and Color3.fromRGB(255, 236, 170) or C.line, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, medal)
		label(medal, unlocked and "🏅" or "🔒", {TextXAlignment = Enum.TextXAlignment.Center, TextSize = 24})
		label(box, achievement.name, {Position = UDim2.fromOffset(74, 8), Size = UDim2.new(1, -150, 0, 20), TextSize = 12, Font = F.black, TextColor3 = unlocked and C.amber or C.text, TextTruncate = Enum.TextTruncate.AtEnd})
		pill(box, "🪙 " .. number(achievement.coins), unlocked and C.muted or C.amber, {Position = UDim2.new(1, -66, 0, 9), Size = UDim2.fromOffset(56, 18), TextSize = 9})
		label(box, achievement.text, {Position = UDim2.fromOffset(74, 30), Size = UDim2.new(1, -86, 0, 16), TextSize = 10, TextColor3 = C.muted, TextTruncate = Enum.TextTruncate.AtEnd})
		local bar = progressBar(box, {Position = UDim2.fromOffset(74, 56), Size = UDim2.new(1, -90, 0, 14)}, unlocked and 1 or math.min(current, achievement.goal) / math.max(achievement.goal, 1), unlocked and C.amber or C.cyan, unlocked and C.orange or C.blue)
		label(bar, unlocked and "UNLOCKED" or (number(math.min(current, achievement.goal)) .. " / " .. number(achievement.goal)), {TextXAlignment = Enum.TextXAlignment.Center, Font = F.black, TextSize = 9, ZIndex = 5, TextStrokeTransparency = 0.5})
	end
end

function UIController:_countBadges()
	local count = 0
	for _, achievement in ipairs(self.ctx.Achievements.List) do
		if (self.ctx.Profile.achievements or {})[achievement.id] == true then count += 1 end
	end
	return count
end

function UIController:_renderSettings()
	self.panelTitle.Text = "SETTINGS"
	self.panelSubtitle.Text = "NEON MALL / " .. tostring(self.ctx.Config.Version or "v0.2.0") .. " / saved with your profile"
	local container = scroll(self.panelContent)
	list(container, false, 10)
	local settings = self.ctx.Profile.settings or {}
	local specs = {
		{"music", "MUSIC", "Background soundtrack when audio is configured.", "🎵"},
		{"sfx", "SOUND EFFECTS", "Chase, movement, and celebration sounds.", "🔊"},
		{"reducedMotion", "REDUCED MOTION", "Calmer transitions, a still preview, less camera motion.", "🌿"},
		{"cameraShake", "CAMERA FEEDBACK", "Small camera reactions to actions and nearby tags.", "🎥"},
	}
	for index, spec in ipairs(specs) do
		local row = card(container, {Size = UDim2.new(1, -5, 0, 76), LayoutOrder = index}, C.line)
		label(row, spec[4], {Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(44, 48), TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center})
		label(row, spec[2], {Position = UDim2.fromOffset(64, 12), Size = UDim2.new(1, -170, 0, 22), TextSize = 13, Font = F.black})
		label(row, spec[3], {Position = UDim2.fromOffset(64, 36), Size = UDim2.new(1, -170, 0, 32), TextSize = 10, TextColor3 = C.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
		local enabled = settings[spec[1]] == true
		button(row, enabled and "ON" or "OFF", function() self:_send("Settings", {[spec[1]] = not enabled}) end, {Name = "Setting_" .. spec[1], AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(84, 40), TextSize = 14, Font = F.black,
			BackgroundColor3 = enabled and C.green or C.card, TextColor3 = enabled and Color3.fromRGB(14, 50, 30) or C.muted})
	end
	local howto = button(container, "📖  HOW TO PLAY", function() self:ShowTutorial() end, {Name = "HowToPlay", Size = UDim2.new(1, -5, 0, 46), LayoutOrder = 11, TextSize = 13, BackgroundColor3 = THEME.Progress.top, TextColor3 = Color3.fromRGB(10, 50, 54)})
	local instructions = card(container, {Size = UDim2.new(1, -5, 0, 150), LayoutOrder = 12}, C.line)
	label(instructions, "KNOW YOUR ROUTE", {Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 22), Font = F.black, TextColor3 = C.cyan, TextSize = 12})
	label(instructions, "Sprint  Shift / L3     Slide  C / B\nJump + vault  Space / A     Tag  F / R2\nTouch: use the on-screen controls.\nGamepad: Y opens your locker. A selects; B closes.\nRunners escape until time runs out. Hunters tag every runner.", {Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 100), TextColor3 = C.muted, TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
end

local MEDALS = {"🥇", "🥈", "🥉"}

function UIController:_renderLeaderboard()
	self.panelTitle.Text = "THE MALL CREW"
	self.panelSubtitle.Text = "Current server / lifetime rating, wins, and tags"
	local container = scroll(self.panelContent)
	list(container, false, 8)
	local players = Players:GetPlayers()
	local function stat(player, name)
		local folder = player:FindFirstChild("leaderstats")
		local value = folder and folder:FindFirstChild(name)
		return value and value.Value or 0
	end
	table.sort(players, function(a, b) local av, bv = stat(a, "Rating"), stat(b, "Rating") if av == bv then return a.UserId < b.UserId end return av > bv end)
	for index, player in ipairs(players) do
		local role = "Lobby"
		for _, entry in ipairs(self.ctx.State.players or {}) do if entry.userId == player.UserId then role = entry.role break end end
		local me = player == self.player
		local row = card(container, {Size = UDim2.new(1, -5, 0, 68), LayoutOrder = index}, me and C.cyan or C.line)
		label(row, MEDALS[index] or tostring(index), {Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(46, 48), TextSize = MEDALS[index] and 28 or 20, Font = F.black, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.muted})
		label(row, player.DisplayName .. (me and "  (YOU)" or ""), {Position = UDim2.fromOffset(64, 8), Size = UDim2.new(1, -170, 0, 24), TextSize = 15, Font = F.black, TextTruncate = Enum.TextTruncate.AtEnd})
		label(row, "LV " .. number(stat(player, "Level")) .. "  /  " .. number(stat(player, "Rating")) .. " RATING  /  " .. number(stat(player, "Wins")) .. " WINS  /  " .. number(stat(player, "Tags")) .. " TAGS", {Position = UDim2.fromOffset(64, 36), Size = UDim2.new(1, -76, 0, 22), TextColor3 = C.muted, TextSize = self.compact and 9 or 11, TextTruncate = Enum.TextTruncate.AtEnd})
		local hunter = role == "Hunter"
		pill(row, string.upper(role), hunter and C.coral or (role == "Runner" and C.cyan or C.muted), {Position = UDim2.new(1, -86, 0, 12), Size = UDim2.fromOffset(74, 18), TextSize = 9})
	end
end

function UIController:_renderResults()
	local state = self.ctx.State
	local profile = self.ctx.Profile
	local winners = state.winners or {}
	local won = table.find(winners, self.player.UserId) ~= nil
	local practice = state.practice == true
	local mine
	for _, entry in ipairs(state.players or {}) do if entry.userId == self.player.UserId then mine = entry end end
	self.panelTitle.Text = practice and "PRACTICE COMPLETE" or (won and "VICTORY!" or "ROUND OVER")
	self.panelSubtitle.Text = practice and "Solo practice / no rewards" or (mine and string.upper(mine.role) or "SPECTATOR") .. " / " .. (state.resultText or "Round complete")
	local container = scroll(self.panelContent)
	list(container, false, 10)
	-- Banner: outcome, with an unmistakable practice vs competitive tag.
	local banner = card(container, {Name = "WinnerHeadline", Size = UDim2.new(1, -5, 0, 78), LayoutOrder = 0}, practice and C.amber or (won and C.amber or C.line))
	label(banner, practice and "🧭" or (won and "🏆" or "🏁"), {Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(56, 78), TextSize = 36, TextXAlignment = Enum.TextXAlignment.Center})
	label(banner, state.resultText or "ROUND COMPLETE", {Position = UDim2.fromOffset(74, 10), Size = UDim2.new(1, -90, 0, 34), TextSize = 20, Font = F.black, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = true})
	pill(banner, practice and "PRACTICE / NO REWARDS" or "COMPETITIVE", practice and C.amber or C.green, {Position = UDim2.fromOffset(74, 50), Size = UDim2.fromOffset(practice and 150 or 104, 20), TextSize = 9})
	-- Podium chips.
	if #winners > 0 then
		local row = frame(container, {Name = "Winners", Size = UDim2.new(1, -5, 0, 40), BackgroundTransparency = 1, LayoutOrder = 1})
		local layout = list(row, true, 8)
		for index, userId in ipairs(winners) do
			if index <= 3 then
				local name = "Player " .. tostring(userId)
				for _, entry in ipairs(state.players or {}) do if entry.userId == userId then name = entry.displayName or entry.name break end end
				local chip = card(row, {Name = "Winner_" .. index, Size = UDim2.new(1 / math.min(#winners, 3), -6, 1, 0), LayoutOrder = index}, userId == self.player.UserId and C.cyan or C.line)
				label(chip, (MEDALS[index] or "🏅") .. "  " .. name .. (userId == self.player.UserId and " (YOU)" or ""), {Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -16, 1, 0), TextSize = 12, Font = F.black, TextTruncate = Enum.TextTruncate.AtEnd})
			end
		end
	end
	-- Rewards earned this round (profile delta since the round began).
	local start = self.roundStartProfile
	local rewards = card(container, {Name = "Rewards", Size = UDim2.new(1, -5, 0, practice and 56 or 112), LayoutOrder = 2}, C.line)
	if practice then
		label(rewards, "Practice rounds award no XP, coins, rating or wins. Queue with friends for real rewards.", {Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), TextSize = 11, TextColor3 = C.muted, TextWrapped = true})
	else
		local dxp = start and ((profile.xp or 0) - (start.xp or 0)) or 0
		local dcoins = start and ((profile.coins or 0) - (start.coins or 0)) or 0
		local dlevel = start and ((profile.level or 1) - (start.level or 1)) or 0
		local tiles = {{"✨", "+" .. number(math.max(dxp, 0)), "XP"}, {"🪙", "+" .. number(math.max(dcoins, 0)), "COINS"}, {"📈", string.upper(profile.rank or "ROOKIE"), "RANK"}}
		for index, tile in ipairs(tiles) do
			local x = (index - 1) / 3
			label(rewards, tile[1], {Position = UDim2.new(x, 8, 0, 8), Size = UDim2.new(1 / 3, -16, 0, 28), TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center})
			label(rewards, tile[2], {Position = UDim2.new(x, 4, 0, 34), Size = UDim2.new(1 / 3, -8, 0, 24), TextSize = 17, Font = F.black, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = index == 3 and C.cyan or C.text, TextTruncate = Enum.TextTruncate.AtEnd})
			label(rewards, tile[3], {Position = UDim2.new(x, 4, 0, 58), Size = UDim2.new(1 / 3, -8, 0, 14), TextSize = 9, Font = F.bold, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center})
		end
		local level = profile.level or 1
		local lower, upper = self.ctx.Rules.XPForLevel(level), self.ctx.Rules.XPForLevel(level + 1)
		local bar = progressBar(rewards, {Position = UDim2.fromOffset(14, 82), Size = UDim2.new(1, -28, 0, 16)}, ((profile.xp or 0) - lower) / math.max(upper - lower, 1), C.cyan, C.blue)
		label(bar, (dlevel > 0 and "LEVEL UP!  " or "LEVEL ") .. number(level) .. "  /  " .. number(profile.xp) .. " XP", {TextXAlignment = Enum.TextXAlignment.Center, Font = F.black, TextSize = 10, ZIndex = 5, TextStrokeTransparency = 0.5})
	end
	-- Actions.
	local actions = frame(container, {Name = "Actions", Size = UDim2.new(1, -5, 0, 96), BackgroundTransparency = 1, LayoutOrder = 3})
	button(actions, "▶  PLAY AGAIN", function()
		if not isQueued(self.ctx) or self.player:GetAttribute("CatchQueued") ~= true then self:_send("Play") end
		self:CloseMenu()
	end, {Name = "PlayAgain", Size = UDim2.new(0.58, -4, 0, 46), BackgroundColor3 = C.magenta, TextSize = 15, Font = F.black})
	button(actions, "🏠  LOBBY", function()
		self:_send("Leave")
		self:CloseMenu()
	end, {Name = "ReturnLobby", Position = UDim2.new(0.58, 4, 0, 0), Size = UDim2.new(0.42, -4, 0, 46), BackgroundColor3 = C.card, TextSize = 13, Font = F.black})
	button(actions, "VIEW PODIUM", function() self:CloseMenu() end, {Name = "ViewPodium", Position = UDim2.fromOffset(0, 54), Size = UDim2.new(0.5, -4, 0, 34), TextSize = 11, BackgroundColor3 = C.panel})
	button(actions, "YOUR CAREER", function() self:OpenMenu("Progress") end, {Name = "ViewCareer", Position = UDim2.new(0.5, 4, 0, 54), Size = UDim2.new(0.5, -4, 0, 34), TextSize = 11, BackgroundColor3 = C.panel})
end

function UIController:Toast(text, kind)
	if not self.toast or not text or text == "" then return end
	self.toastSerial += 1
	local serial = self.toastSerial
	self.toastText.Text = tostring(text)
	local icons = {purchase = "🛍️", level = "⭐", unlock = "🔓", welcome = "👋", round = "🏁"}
	self.toastIcon.Text = icons[kind] or "💬"
	self.toastStroke.Color = (kind == "purchase" or kind == "level" or kind == "unlock") and C.amber or C.cyan

	-- Over a modal menu the toast moves to the bottom so it never covers the header.
	self.toast.AnchorPoint = self.menu and Vector2.new(0.5, 1) or Vector2.new(0.5, 0)
	self.toast.Position = self.menu and UDim2.new(0.5, 0, 1, -20) or UDim2.new(0.5, 0, 0, 112)
	self.toast.Visible = true
	self.toast.BackgroundTransparency = 0.04
	task.delay(4.3, function() if serial == self.toastSerial then self.toast.Visible = false end end)
end

function UIController:_announce(role, practice, modifier, previousRole)
	self.announceSerial = (self.announceSerial or 0) + 1
	local serial = self.announceSerial
	local hunter = role == "Hunter"
	self.announcementStroke.Color = hunter and C.coral or C.cyan
	self.announcementTitle.TextColor3 = hunter and C.coral or C.cyan
	self.announcementTitle.Text = practice and "SOLO PRACTICE" or (role == "Spectator" and "WATCH THE CHASE" or "YOU ARE A " .. string.upper(role))
	self.announcementCopy.Text = practice and "Learn the shortcuts. Practice gives no progression rewards." or (hunter and "The runners get a head start. Track them down. Tag them all." or (role == "Spectator" and "Join the next round automatically. Cycle through the runners below." or "Use the rooftops. Break line of sight. Survive until time runs out."))
	local special = modifier and modifier.id ~= "classic" and not practice
	if special then
		if previousRole == "Runner" and hunter then
			self.announcementTitle.Text = "INFECTED!"
			self.announcementCopy.Text = "You are a hunter now. Tag the remaining runners."
		else
			self.announcementCopy.Text = modifier.name .. ": " .. modifier.tagline
		end
	end
	self.announcement.Visible = true
	task.delay(3.5, function() if self.announceSerial == serial then self.announcement.Visible = false end end)
end

function UIController:_restoreCamera()
	local camera = workspace.CurrentCamera
	local character = self.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if camera and humanoid then camera.CameraType = Enum.CameraType.Custom camera.CameraSubject = humanoid end
	self.pendingCameraRestore = not (camera and humanoid and humanoid.Health > 0)
	self.spectateTarget = nil
end

function UIController:OnCharacter(character)
	if not character then return end
	task.spawn(function()
		character:WaitForChild("Humanoid", 10)
		if self.destroyed or self.player.Character ~= character then return end
		if self.wasSpectating then self:_updateSpectator()
		else self:_restoreCamera() end
	end)
end

function UIController:_updateSpectator()
	local state = self.ctx.State
	local role = myRole(state, self.ctx)
	local spectating = role == "Spectator" and (state.phase == "Active" or state.phase == "HeadStart")
	self.spectator.Visible = spectating and not self.menu
	if not spectating then
		if self.wasSpectating or self.spectateTarget then self:_restoreCamera() end
		self.wasSpectating = false
		return
	end
	self.wasSpectating = true
	self.pendingCameraRestore = false
	local targets = {}
	for _, entry in ipairs(state.players or {}) do
		if entry.alive and entry.role == "Runner" and entry.userId ~= self.player.UserId then
			local player = Players:GetPlayerByUserId(entry.userId)
			local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then targets[#targets + 1] = {player = player, humanoid = humanoid} end
		end
	end
	if #targets == 0 then self.spectatorName.Text = "Waiting for runners" self:_restoreCamera() return end
	self.spectateIndex = ((self.spectateIndex - 1) % #targets) + 1
	local selected = targets[self.spectateIndex]
	local camera = workspace.CurrentCamera
	if camera then camera.CameraType = Enum.CameraType.Custom camera.CameraSubject = selected.humanoid end
	self.spectateTarget = selected.player
	self.spectatorName.Text = selected.player.DisplayName .. "  " .. self.spectateIndex .. "/" .. #targets
end

function UIController:_tick()
	local state = self.ctx.State
	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, (state.endsAt or now) - now)
	self.timerLabel.Text = state.phase == "Waiting" and "LOBBY" or clockText(remaining)
	local final = state.phase == "Active" and (state.finalChase or remaining <= 30)
	self.timerLabel.TextColor3 = final and C.coral or C.text
	self.clockStroke.Color = final and C.coral or C.line
	local durations = {Intermission = self.ctx.Config.Round.Intermission, HeadStart = self.ctx.Config.Round.HeadStart, Active = self.ctx.Config.Round.Duration, Results = self.ctx.Config.Round.ResultsDuration}
	self.roundFill.Size = UDim2.fromScale(state.phase == "Waiting" and 1 or math.clamp(remaining / math.max(durations[state.phase] or 1, 1), 0, 1), 1)
	self.roundFill.BackgroundColor3 = final and C.coral or C.cyan
	if final then self.phaseLabel.Text = state.lastRunner and "LAST RUNNER / FINAL CHASE" or "FINAL CHASE" self.phaseLabel.TextColor3 = C.coral end
	local role = myRole(state, self.ctx)
	for action, widgets in pairs(self.abilityLabels) do
		local deadline = self.player:GetAttribute("Catch" .. action .. "ReadyAt") or 0
		local cooldown = math.max(0, deadline - now)
		local frozen = self.player.Character and self.player.Character:GetAttribute("RoundFrozen") == true
		local enabled = role ~= "Spectator" and not frozen
		if action == "Tag" and (role ~= "Hunter" or state.phase ~= "Active") then enabled = false end
		local gamepad = string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil
		widgets.status.Text = not enabled and (frozen and "HEAD START" or action == "Tag" and "HUNTERS ONLY" or "SPECTATING") or (cooldown > 0 and string.format("%.1fs", cooldown) or (gamepad and widgets.gamepad or widgets.keyboard))
		widgets.status.TextColor3 = not enabled and C.muted or (cooldown > 0 and C.amber or widgets.accent)
		widgets.fill.BackgroundColor3 = not enabled and C.line or (cooldown > 0 and C.amber or widgets.accent)
	end
	self:_updatePlay()
	if self.wasSpectating then self:_updateSpectator() end
	if self.pendingCameraRestore and not self.wasSpectating then self:_restoreCamera() end
end

function UIController:OnState(state)
	if not self.gui then return end
	local phase = state.phase or "Waiting"
	local role = myRole(state, self.ctx)
	local active = phase == "Active" or phase == "HeadStart"
	local labels = {Waiting = "WELCOME TO THE PLAZA", Intermission = "NEXT CHASE STARTS IN", HeadStart = "RUNNERS GET A HEAD START", Active = "THE CHASE IS ON", Results = "NEXT UP / CHAMPIONS"}
	local modifier = state.modifier
	local special = modifier and modifier.id ~= "classic" and not state.practice
	if special and phase == "Intermission" then labels.Intermission = "NEXT: " .. modifier.name .. " IN"
	elseif special and phase == "Active" then labels.Active = modifier.name end
	self.phaseLabel.Text = state.practice and "STUDIO / SOLO PRACTICE" or (labels[phase] or "NEON MALL")
	self.phaseLabel.TextColor3 = C.cyan
	self.aliveLabel.Text = active and (tostring(state.aliveRunners or 0) .. " RUNNERS LEFT") or (phase == "Waiting" and "Waiting for the crew" or (state.mapName or "NEON MALL"))
	self.roleChip.Text = state.practice and "PRACTICE / NO PROGRESSION REWARDS" or (active and string.upper(role) .. " / " .. (role == "Hunter" and "TAG EVERY RUNNER" or role == "Runner" and "SURVIVE THE CHASE" or "NEXT ROUND IS YOURS") or "EXPLORE THE PLAZA")
	self.roleChip.TextColor3 = role == "Hunter" and C.coral or C.cyan
	if active and (self.lastRound ~= state.roundId or self.lastRole ~= role) then
		self:CloseMenu()
		if self.tutorial and self.tutorial.Visible and role ~= "Spectator" then self:_finishTutorial() end
		self.visited = true
		self:_announce(role, state.practice, state.modifier, self.lastRole)
		if self.lastRound ~= state.roundId then
			local profile = self.ctx.Profile
			self.roundStartProfile = {xp = profile.xp, coins = profile.coins, level = profile.level, rating = profile.rating}
		end
	end
	if phase == "Results" and self.lastResult ~= state.roundId then
		self.lastResult = state.roundId
		self:OpenMenu("Results")
	elseif self.menu == "Results" and phase ~= "Results" then self:CloseMenu() end
	self.lastRound = state.roundId
	self.lastRole = role
	self:_responsive()
	self:_updateSpectator()
	if self.menu == "Leaderboard" then self:_renderLeaderboardRefresh() end
	self:_tick()
end

function UIController:_renderLeaderboardRefresh()
	clear(self.panelContent)
	self:_renderLeaderboard()
end

function UIController:OnProfile(profile)
	if not self.gui then return end
	self.coinsLabel.Text = number(profile.coins)
	self.levelLabel.Text = "LEVEL " .. number(profile.level or 1) .. " / " .. string.upper(profile.rank or "ROOKIE")
	self.loading.Visible = profile.loaded ~= true
	if profile.persistence == "saved" then self.saveLabel.Text = profile.saveMessage or "PROFILE CONNECTED / AUTOSAVE ENABLED"
	elseif profile.persistence == "session" then self.saveLabel.Text = profile.saveMessage or "SESSION PROFILE / PROGRESS IS NOT PERSISTED"
	elseif profile.persistence == "unavailable" then self.saveLabel.Text = profile.saveMessage or "SAVING UNAVAILABLE / THIS SESSION MAY NOT PERSIST" end
	self.saveLabel.TextColor3 = profile.persistence == "saved" and C.muted or C.amber
	self.pendingId = nil
	local login = profile.loginStatus
	if self.questBadge then
		local claimable = login and login.canClaim
		for _, quest in ipairs(profile.quests or {}) do
			if not quest.claimed and (quest.progress or 0) >= (quest.goal or 1) then claimable = true end
		end
		self.questBadge.Visible = claimable == true
	end
	if profile.loaded and profile.settings and profile.settings.tutorialDone == false and not self.tutorialShown then
		self.tutorialShown = true
		self:ShowTutorial()
	elseif login and login.canClaim and not self.loginHinted and profile.loaded and not (self.tutorial and self.tutorial.Visible) then
		self.loginHinted = true
		self:Toast("Daily reward ready. Open QUESTS to claim it.", "unlock")
	end
	-- Equip feedback: a burst from the action button when a slot changed.
	local equippedNow = profile.equipped or {}
	if self.lastEquipped and (self.menu == "Shop" or self.menu == "Inventory") then
		for slot, id in pairs(equippedNow) do
			if self.lastEquipped[slot] ~= id and id ~= "" then pcall(function() self:_burst(self.lastActionButton, {C.cyan, C.magenta, C.amber}) end) break end
		end
	end
	self.lastEquipped = table.clone(equippedNow)
	if self.menu then self:_renderMenu() end
end

function UIController:OnNotice(notice)
	if not self.gui or type(notice) ~= "table" then return end
	if notice.kind == "openMenu" and type(notice.menu) == "string" then
		if self.menu ~= notice.menu then self:OpenMenu(notice.menu) end
		return
	end
	if notice.text then self:Toast(notice.text, notice.kind == "pulse" and "unlock" or notice.kind) end
	if notice.kind == "purchase" or notice.kind == "unlock" then
		pcall(function() self:_burst(self.lastActionButton) end)
		self.pendingId = nil
		if self.menu == "Shop" or self.menu == "Inventory" then self:_renderMenu() end
	end
end

function UIController:Destroy()
	self.destroyed = true
	ContextActionService:UnbindAction("CatchCloseMenu")
	ContextActionService:UnbindAction("CatchOpenMenu")
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	self.player:SetAttribute("CatchMenuOpen", false)
	self:_restoreCamera()
	if self.gui then self.gui:Destroy() end
end

return UIController
