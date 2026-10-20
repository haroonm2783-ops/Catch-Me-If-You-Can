-- CATCH ME IF YOU CAN interface. Bright mall palette, persistent Shop / Locker dock,
-- and menus that never pause or protect the player. Every persistent action goes through the server.
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
	background = Color3.fromRGB(34, 40, 76), panel = Color3.fromRGB(46, 54, 100),
	card = Color3.fromRGB(64, 76, 136), line = Color3.fromRGB(112, 128, 205),
	text = Color3.fromRGB(255, 255, 255), muted = Color3.fromRGB(200, 210, 238),
	cyan = Color3.fromRGB(44, 214, 204), coral = Color3.fromRGB(255, 96, 84),
	amber = Color3.fromRGB(255, 198, 40), green = Color3.fromRGB(84, 220, 128),
	pink = Color3.fromRGB(255, 100, 170), blue = Color3.fromRGB(60, 160, 255), ink = Color3.fromRGB(22, 26, 52),
}
local RARITY = {
	Common = Color3.fromRGB(190, 200, 224), Rare = Color3.fromRGB(70, 168, 255),
	Epic = Color3.fromRGB(190, 106, 255), Legendary = Color3.fromRGB(255, 190, 40),
}
local F = {regular = Enum.Font.Gotham, medium = Enum.Font.GothamMedium, bold = Enum.Font.GothamBold,
	black = Enum.Font.GothamBlack, title = Enum.Font.FredokaOne}
local CATEGORY_ICON = {skins = "👕", masks = "🎭", trails = "✨", tagEffects = "💥", victories = "🎉", emotes = "💃", nameplates = "🏷", bundles = "🎁", vip = "👑"}
local TIPS = {
	"Hold E near a fitting room, locker or stall to hide. Hunters can search them!",
	"Grab the spinning coins. Up to 25 per round.",
	"Hunters: press Q to scan for movement. Ground-floor shortcuts are your friend.",
	"Jump the balcony gaps to escape a chase. The fall is safe.",
	"Everything in the shop is cosmetic. Nobody can buy an advantage.",
}

local function shade(color, factor)
	return Color3.new(math.clamp(color.R * factor, 0, 1), math.clamp(color.G * factor, 0, 1), math.clamp(color.B * factor, 0, 1))
end

local function node(class, props, parent)
	local object = Instance.new(class)
	for key, value in pairs(props or {}) do object[key] = value end
	object.Parent = parent
	return object
end

local function corner(object, radius)
	node("UICorner", {CornerRadius = UDim.new(0, radius or 14)}, object)
end

local function stroke(object, color, transparency, thickness)
	return node("UIStroke", {Color = color or C.ink, Transparency = transparency or 0, Thickness = thickness or 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, object)
end

-- A UIGradient multiplies the object's BackgroundColor3, so the base stays white and the gradient owns the color.
local function gradient(object, first, last, rotation)
	object.BackgroundColor3 = Color3.new(1, 1, 1)
	return node("UIGradient", {Color = ColorSequence.new(first, last), Rotation = rotation or 90}, object)
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
		Text = text or "", Font = F.bold, TextSize = 14, TextColor3 = C.text,
		BackgroundTransparency = 1, BorderSizePixel = 0, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center, Size = UDim2.fromScale(1, 1),
	}
	for key, value in pairs(props or {}) do values[key] = value end
	return node("TextLabel", values, parent)
end

-- Chunky candy button: lighter top, dark outline, brighter on hover.
local function button(parent, text, callback, props)
	local values = {
		Text = text, Font = F.black, TextSize = 13, TextColor3 = C.text,
		BackgroundColor3 = C.card, BorderSizePixel = 0, AutoButtonColor = true,
		Selectable = true, Size = UDim2.fromOffset(150, 40),
	}
	for key, value in pairs(props or {}) do values[key] = value end
	local object = node("TextButton", values, parent)
	corner(object, 12)
	local outline = stroke(object, shade(values.BackgroundColor3, 0.45), 0, 2)
	-- A UIGradient on the button itself would also tint its text, so the sheen is a child overlay.
	local sheen = frame(object, {Name = "Sheen", BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Active = false}, 12)
	node("UIGradient", {Transparency = NumberSequence.new(0.78, 1), Rotation = 90}, sheen)
	if object.MouseEnter then
		object.MouseEnter:Connect(function() outline.Color = C.text end)
		object.MouseLeave:Connect(function() outline.Color = shade(values.BackgroundColor3, 0.45) end)
	end
	object.Activated:Connect(callback)
	return object
end

local function scroll(parent, props, horizontal)
	local values = {
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
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

local function rarityColor(item)
	return RARITY[item and item.rarity or "Common"] or RARITY.Common
end

local function clear(parent)
	for _, child in ipairs(parent:GetChildren()) do child:Destroy() end
end

local function myRecord(state)
	for _, record in ipairs(state.players or {}) do
		if record.userId == Players.LocalPlayer.UserId then return record end
	end
	return nil
end

local function myRole(state)
	local record = myRecord(state)
	if record then return record.role, record.alive end
	if state.phase == "Active" or state.phase == "HeadStart" then return "Spectator", false end
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
		thumbs = {}, pickupCount = 0, hideEndsAt = nil, hideDuration = 7, lastReward = nil,
	}, UIController)
end

-- The shop and locker preview the player's own avatar wearing the chosen cosmetics. The base model is built
-- from their applied HumanoidDescription (async); until it exists, a neutral mannequin stands in.
function UIController:_loadAvatarBase()
	if self.avatarLoading or self.destroyed then return end
	self.avatarLoading = true
	task.spawn(function()
		local character = self.player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local base
		if humanoid then
			local ok, description = pcall(function() return humanoid:GetAppliedDescription() end)
			if ok and description then base = self.Appearance.BuildAvatar(description, humanoid.RigType) end
		end
		self.avatarLoading = false
		if base and not self.destroyed then
			if self.avatarBase then self.avatarBase:Destroy() end
			self.avatarBase, self.thumbs, self.thumbCount = base, {}, 0
			if self.menu == "Shop" or self.menu == "Inventory" then self:_renderMenu() end
		elseif base then
			base:Destroy()
		end
	end)
end

function UIController:_send(action, payload)
	self.ctx.Remotes.Action:FireServer(action, payload or {})
end

function UIController:_motion()
	return not (self.ctx.Profile.settings or {}).reducedMotion
end

function UIController:_tween(object, duration, props)
	if not self:_motion() then
		for key, value in pairs(props) do object[key] = value end
		return
	end
	TweenService:Create(object, TweenInfo.new(duration, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end

function UIController:_inRound()
	local phase = self.ctx.State.phase
	return phase == "Active" or phase == "HeadStart"
end

function UIController:Start()
	if self.started then return end
	self.started = true
	self.Appearance = require(ReplicatedStorage:WaitForChild("CatchShared"):WaitForChild("Appearance"))
	self.gui = node("ScreenGui", {
		Name = "CatchMallUI", ResetOnSpawn = false, IgnoreGuiInset = false,
		DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, self.player:WaitForChild("PlayerGui"))
	self.root = frame(self.gui, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
	self:_buildHeader()
	self:_buildObjective()
	self:_buildHero()
	self:_buildAbilities()
	self:_buildSpectator()
	self:_buildPanel()
	self:_buildResults()
	self:_buildDock() -- built after the panel so Shop and Locker always stay on top and clickable
	self:_buildToast()
	self:_buildAnnouncement()
	self:_buildTutorial()
	self:_buildLoading()
	self.connections[#self.connections + 1] = UserInputService.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape then
			if self.menu then self:CloseMenu() elseif self.moreMenu.Visible then self:CloseMore() end
		end
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
			local angle = self.previewAngle + (self:_motion() and math.sin(self.previewTime * 0.38) * 0.12 or 0)
			self.previewCamera.CFrame = CFrame.lookAt(Vector3.new(math.sin(angle) * 11, 1.4, -math.cos(angle) * 11), Vector3.new(0, 0.15, 0))
		end
	end)
	self:_makeRoomForCoreUi()
	self:_responsive()
	self:_loadAvatarBase()
	self:OnProfile(self.ctx.Profile)
	self:OnState(self.ctx.State)
end

-- Roblox's default player list sits in the top right corner the wallet uses, so on keyboard devices it is hidden
-- (the CREW menu replaces it). Chat stays in its familiar top-left corner and is only narrowed. On phones both
-- collapse to topbar icons, so they are left alone. Best-effort: a failure here never affects gameplay.
function UIController:_makeRoomForCoreUi()
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if touchOnly then return end
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	-- Chat stays where players expect it (top left). It is only narrowed so it can never reach the round timer;
	-- the HUD keeps the whole left edge below it free and puts its own buttons on the right.
	pcall(function()
		local window = game:GetService("TextChatService"):FindFirstChildOfClass("ChatWindowConfiguration")
		assert(window, "no ChatWindowConfiguration")
		window.WidthScale = 0.3
		window.HeightScale = 0.22
	end)
end

---------------------------------------------------------------------------------------------------
-- Persistent HUD
---------------------------------------------------------------------------------------------------

function UIController:_buildHeader()
	self.header = frame(self.root, {Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 52), BackgroundTransparency = 1})
	-- Round chip: phase, timer and runners left in one compact card.
	self.clock = frame(self.header, {Name = "RoundCard", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(190, 50), BackgroundColor3 = C.background}, 14)
	self.clockStroke = stroke(self.clock, C.ink, 0, 3)
	gradient(self.clock, Color3.fromRGB(52, 62, 120), C.background, 90)
	self.roundTrack = frame(self.clock, {Name = "RoundProgress", Position = UDim2.new(0, 12, 1, -6), Size = UDim2.new(1, -24, 0, 4), BackgroundColor3 = C.ink}, 2)
	self.roundFill = frame(self.roundTrack, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.cyan}, 2)
	self.phaseLabel = label(self.clock, "WELCOME TO THE MALL", {Position = UDim2.fromOffset(6, 3), Size = UDim2.new(1, -12, 0, 11), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 9, TextColor3 = C.cyan, TextTruncate = Enum.TextTruncate.AtEnd})
	self.timerLabel = label(self.clock, "LOBBY", {Position = UDim2.fromOffset(6, 13), Size = UDim2.new(1, -12, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 22, Font = F.title})
	self.aliveLabel = label(self.clock, "Waiting for players", {Position = UDim2.fromOffset(6, 34), Size = UDim2.new(1, -12, 0, 9), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 8, TextColor3 = C.muted, TextTruncate = Enum.TextTruncate.AtEnd})
	-- Wallet pill: coins, level and an XP bar.
	self.wallet = frame(self.header, {Name = "Wallet", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(150, 44), BackgroundColor3 = C.background}, 14)
	stroke(self.wallet, C.ink, 0, 3)
	gradient(self.wallet, Color3.fromRGB(52, 62, 120), C.background, 90)
	self.coinsLabel = label(self.wallet, "🪙 0", {Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -20, 0, 22), Font = F.title, TextColor3 = C.amber, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Right})
	self.levelLabel = label(self.wallet, "LEVEL 1", {Position = UDim2.fromOffset(10, 25), Size = UDim2.new(1, -20, 0, 10), Font = F.bold, TextColor3 = C.muted, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Right})
	local xpTrack = frame(self.wallet, {Position = UDim2.new(0, 10, 1, -8), Size = UDim2.new(1, -20, 0, 4), BackgroundColor3 = C.ink}, 2)
	self.xpFill = frame(xpTrack, {Name = "XpFill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.green}, 2)
end

-- Shop and Locker are always on screen: not in the lobby, an active round, spectating, or results.
-- Everything else lives behind one "More" button so the HUD stays clean.
local DOCK = {
	{"Shop", "SHOP", "🛒", C.pink},
	{"Inventory", "LOCKER", "👕", C.blue},
}
local MORE = {
	{"Quests", "QUESTS", "📋", C.amber},
	{"Progress", "CAREER", "🏆", C.green},
	{"Leaderboard", "CREW", "👥", C.cyan},
	{"Settings", "SETTINGS", "⚙", C.line},
}

function UIController:_buildDock()
	self.dock = frame(self.root, {Name = "Dock", Position = UDim2.fromOffset(8, 62), Size = UDim2.fromOffset(64, 200), BackgroundTransparency = 1, ZIndex = 12})
	self.dockLayout = list(self.dock, false, 6)
	self.dockButtons = {}
	for index, spec in ipairs(DOCK) do
		self.dockButtons[spec[1]] = self:_dockButton(self.dock, spec[1], spec[2], spec[3], spec[4], index, function() self:OpenMenu(spec[1]) end)
	end
	self.dockButtons.More = self:_dockButton(self.dock, "More", "MORE", "☰", C.amber, #DOCK + 1, function() self:ToggleMore() end)
	-- The More popover: icon + caption rows, closed on any selection.
	self.moreMenu = frame(self.root, {Name = "MoreMenu", Position = UDim2.fromOffset(80, 120), Size = UDim2.fromOffset(150, 8 + (#MORE + 1) * 40), BackgroundColor3 = C.background, Visible = false, ZIndex = 14}, 14)
	stroke(self.moreMenu, C.ink, 0, 3)
	local layout = list(self.moreMenu, false, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	node("UIPadding", {PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4)}, self.moreMenu)
	for index, spec in ipairs(MORE) do
		self.dockButtons[spec[1]] = self:_moreRow(spec[1], spec[2], spec[3], spec[4], index, function() self:CloseMore() self:OpenMenu(spec[1]) end)
	end
	self.emoteButton = self:_moreRow("Emote", "EMOTE", "💃", C.card, #MORE + 1, function()
		self:CloseMore()
		local id = (self.ctx.Profile.equipped or {}).emotes
		if id and id ~= "" then self:_send("Emote", {id = id}) end
	end)
	self.dockButtons.Emote = self.emoteButton
end

function UIController:_dockButton(parent, name, text, icon, color, order, callback)
	local object = button(parent, "", callback, {Name = name, Size = UDim2.fromOffset(62, 62), LayoutOrder = order, BackgroundColor3 = color, ZIndex = 12})
	label(object, icon, {Name = "Icon", Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 30), TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13})
	label(object, text, {Name = "Caption", Position = UDim2.new(0, 0, 1, -20), Size = UDim2.new(1, 0, 0, 14), TextSize = 10, Font = F.black, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13, TextColor3 = color == C.amber and C.ink or C.text})
	local badge = frame(object, {Name = "Badge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.coral, Visible = false, ZIndex = 14}, 10)
	stroke(badge, C.text, 0, 2)
	label(badge, "!", {TextXAlignment = Enum.TextXAlignment.Center, TextSize = 13, Font = F.black, ZIndex = 15})
	return object
end

function UIController:_moreRow(name, text, icon, color, order, callback)
	local object = button(self.moreMenu, "", callback, {Name = name, Size = UDim2.new(1, -12, 0, 36), LayoutOrder = order, BackgroundColor3 = color, ZIndex = 14})
	label(object, icon, {Name = "Icon", Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(28, 36), TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 15})
	label(object, text, {Name = "Caption", Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -44, 1, 0), TextSize = 12, Font = F.black, ZIndex = 15, TextColor3 = color == C.amber and C.ink or C.text})
	local badge = frame(object, {Name = "Badge", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.coral, Visible = false, ZIndex = 16}, 9)
	stroke(badge, C.text, 0, 2)
	label(badge, "!", {TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, Font = F.black, ZIndex = 17})
	return object
end

function UIController:ToggleMore()
	if self.moreMenu.Visible then self:CloseMore() return end
	self.moreMenu.Visible = true
	self:_responsive()
	if UserInputService.GamepadEnabled then
		local first = self.moreMenu:FindFirstChild("Quests")
		if first then GuiService.SelectedObject = first end
	end
end

function UIController:CloseMore()
	if self.moreMenu and self.moreMenu.Visible then
		self.moreMenu.Visible = false
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.moreMenu) then GuiService.SelectedObject = self.dockButtons.More end
	end
end

-- Objective chip: what to do right now. Kept to two short lines.
function UIController:_buildObjective()
	self.objective = frame(self.root, {Name = "Objective", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(280, 44), BackgroundColor3 = C.background, Visible = false}, 12)
	stroke(self.objective, C.ink, 0, 3)
	self.roleChip = label(self.objective, "RUNNER", {Position = UDim2.fromOffset(12, 4), Size = UDim2.new(0.5, -12, 0, 14), TextSize = 10, TextColor3 = C.cyan, Font = F.black})
	self.objectiveRight = label(self.objective, "", {Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.new(0.5, -12, 0, 14), TextSize = 10, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right})
	self.objectiveText = label(self.objective, "", {Position = UDim2.fromOffset(12, 20), Size = UDim2.new(1, -24, 0, 20), TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd})
	self.hideMeter = frame(self.root, {Name = "HideMeter", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.fromOffset(240, 62), BackgroundColor3 = C.background, Visible = false}, 12)
	stroke(self.hideMeter, C.amber, 0, 3)
	label(self.hideMeter, "🤫 HIDING...", {Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 14), TextSize = 11, TextColor3 = C.amber, Font = F.black})
	local track = frame(self.hideMeter, {Position = UDim2.fromOffset(12, 21), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = C.ink}, 3)
	self.hideFill = frame(track, {Name = "HideFill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.amber}, 3)
	self.leaveButton = button(self.hideMeter, "LEAVE SPOT", function() self:_send("Unhide") end, {Name = "LeaveHiding", Position = UDim2.new(0, 12, 1, -30), Size = UDim2.new(1, -24, 0, 24), TextSize = 11, BackgroundColor3 = C.coral})
end

-- Build/save status lives quietly at the bottom right, clear of the chat in the bottom left.
function UIController:_buildHero()
	self.saveLabel = label(self.root, "CONNECTING TO YOUR PROFILE", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -112, 1, -6), Size = UDim2.fromOffset(280, 12), TextColor3 = C.muted, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd})
	self.versionLabel = label(self.root, "BUILD " .. tostring(self.ctx.Config.Version), {Name = "BuildVersion", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -6), Size = UDim2.fromOffset(95, 12), TextColor3 = C.muted, TextSize = 8, TextXAlignment = Enum.TextXAlignment.Right})
end

function UIController:_buildAbilities()
	self.abilities = frame(self.root, {Name = "Abilities", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(410, 46), BackgroundTransparency = 1})
	local layout = list(self.abilities, true, 5)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	self.abilityLabels = {}
	local specs = {{"Sprint", "SHIFT", "L3", "👟"}, {"Slide", "C", "B", "🛹"}, {"Vault", "SPACE", "A", "🦘"}, {"Tag", "F", "R2", "🖐"}, {"Scan", "Q", "X", "📡"}}
	for index, spec in ipairs(specs) do
		local clickable = spec[1] == "Scan"
		local box = clickable and button(self.abilities, "", function() self:_send("Scan") end, {Name = "ScanButton", Size = UDim2.fromOffset(76, 44), BackgroundColor3 = C.background, LayoutOrder = index})
			or frame(self.abilities, {Size = UDim2.fromOffset(76, 44), BackgroundColor3 = C.background, LayoutOrder = index}, 12)
		if not clickable then stroke(box, C.ink, 0, 2) end
		label(box, spec[4], {Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(22, 20), TextSize = 16})
		local name = label(box, string.upper(spec[1]), {Position = UDim2.fromOffset(28, 5), Size = UDim2.new(1, -32, 0, 14), Font = F.black, TextSize = 10})
		local status = label(box, spec[2], {Position = UDim2.fromOffset(6, 24), Size = UDim2.new(1, -12, 0, 12), TextColor3 = C.cyan, TextSize = 9})
		local fill = frame(box, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 6, 1, -3), Size = UDim2.new(1, -12, 0, 3), BackgroundColor3 = C.cyan}, 2)
		self.abilityLabels[spec[1]] = {box = box, name = name, status = status, fill = fill, keyboard = spec[2], gamepad = spec[3]}
	end
end

function UIController:_buildSpectator()
	self.spectator = frame(self.root, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -66), Size = UDim2.fromOffset(280, 52), BackgroundColor3 = C.background, Visible = false}, 14)
	stroke(self.spectator, C.ink, 0, 3)
	button(self.spectator, "<", function() self.spectateIndex -= 1 self:_updateSpectator() end, {Position = UDim2.fromOffset(6, 8), Size = UDim2.fromOffset(36, 36)})
	button(self.spectator, ">", function() self.spectateIndex += 1 self:_updateSpectator() end, {Position = UDim2.new(1, -42, 0, 8), Size = UDim2.fromOffset(36, 36)})
	label(self.spectator, "SPECTATING", {Position = UDim2.fromOffset(46, 6), Size = UDim2.new(1, -92, 0, 14), TextColor3 = C.cyan, Font = F.black, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center})
	self.spectatorName = label(self.spectator, "Waiting for runners", {Position = UDim2.fromOffset(46, 22), Size = UDim2.new(1, -92, 0, 22), Font = F.bold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd})
end

-- The shared menu panel. Shop and Locker get a roomy panel; every other menu is a small card.
function UIController:_buildPanel()
	self.panel = frame(self.root, {
		Name = "MenuPanel", Position = UDim2.fromOffset(84, 62), Size = UDim2.fromOffset(900, 560), BackgroundColor3 = C.background, Visible = false, ZIndex = 5,
	}, 18)
	node("UISizeConstraint", {MaxSize = Vector2.new(980, 640), MinSize = Vector2.new(250, 160)}, self.panel)
	stroke(self.panel, C.ink, 0, 4)
	gradient(self.panel, Color3.fromRGB(50, 60, 116), C.background, 110)
	self.panelScale = node("UIScale", {Scale = 1}, self.panel)
	self.panelBanner = frame(self.panel, {Name = "Banner", Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.pink, ZIndex = 5}, 18)
	self.bannerGradient = gradient(self.panelBanner, Color3.fromRGB(255, 130, 170), Color3.fromRGB(255, 96, 84), 0)
	self.panelTitle = label(self.panel, "THE SHOP", {Position = UDim2.fromOffset(16, 5), Size = UDim2.new(1, -76, 0, 26), Font = F.title, TextSize = 22, TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeTransparency = 0.6, ZIndex = 6})
	self.panelSubtitle = label(self.panel, "", {Position = UDim2.fromOffset(16, 30), Size = UDim2.new(1, -76, 0, 16), TextColor3 = Color3.fromRGB(255, 244, 240), TextSize = 10, Font = F.medium, ZIndex = 6})
	button(self.panel, "X", function() self:CloseMenu() end, {Name = "Close", Position = UDim2.new(1, -46, 0, 6), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = C.coral, ZIndex = 7})
	self.panelContent = frame(self.panel, {Position = UDim2.fromOffset(14, 62), Size = UDim2.new(1, -28, 1, -76), BackgroundTransparency = 1, ZIndex = 6})
end

---------------------------------------------------------------------------------------------------
-- Onboarding: a small tip card at the bottom of the screen. It never blocks the world or the controls.
---------------------------------------------------------------------------------------------------

function UIController:_buildTutorial()
	self.tutorial = frame(self.root, {Name = "Tutorial", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -70), Size = UDim2.new(1, -24, 0, 170), BackgroundColor3 = C.background, Visible = false, ZIndex = 30}, 16)
	node("UISizeConstraint", {MaxSize = Vector2.new(430, 180), MinSize = Vector2.new(240, 150)}, self.tutorial)
	stroke(self.tutorial, C.cyan, 0, 3)
	self.tutorialStep = label(self.tutorial, "", {Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 14), TextSize = 9, Font = F.black, TextColor3 = C.cyan, ZIndex = 31})
	self.tutorialTitle = label(self.tutorial, "", {Position = UDim2.fromOffset(16, 24), Size = UDim2.new(1, -32, 0, 28), Font = F.title, TextSize = 20, TextWrapped = true, ZIndex = 31})
	self.tutorialBody = label(self.tutorial, "", {Position = UDim2.fromOffset(16, 54), Size = UDim2.new(1, -32, 1, -100), TextSize = 12, TextColor3 = C.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31, Font = F.medium})
	self.tutorialSkip = button(self.tutorial, "SKIP", function() self:_finishTutorial() end, {Name = "TutorialSkip", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -10), Size = UDim2.fromOffset(70, 32), TextSize = 11, ZIndex = 31})
	self.tutorialNext = button(self.tutorial, "NEXT", function() self:_tutorialAdvance() end, {Name = "TutorialNext", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -10), Size = UDim2.fromOffset(120, 32), BackgroundColor3 = C.green, TextColor3 = C.ink, TextSize = 12, ZIndex = 31})
end

function UIController:_tutorialPages()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local pad = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not touch
	local controls = touch and "RUN, SLIDE and TAG buttons sit by your thumb. Jump also vaults low things. Tap a hiding spot's HIDE prompt."
		or (pad and "Sprint L3 · Slide B · Jump/Vault A · Tag R2 · Scan X · Locker Y")
		or "Shift = sprint · C = slide · Space = jump/vault · F = tag · E = hide/search · Q = scan"
	return {
		{title = "WELCOME TO THE MALL!", body = "Hunters chase runners through a two-floor mall. Rounds start by themselves."},
		{title = "RUNNERS: STAY FREE", body = "Grab coins, hide in fitting rooms, lockers and vents, cut through stores and jump the balcony gaps. Survive until the timer ends."},
		{title = "HUNTERS: FIND THEM", body = "Runners get a head start. Search hiding spots (E), scan (Q) and tag everyone you catch."},
		{title = "MOVE LIKE A PRO", body = controls .. "\nSHOP and LOCKER are always on the left: skins are just for style."},
	}
end

function UIController:ShowTutorial()
	if not self.tutorial then return end
	self.tutorialPages = self:_tutorialPages()
	self.tutorialPage = 1
	self:CloseMenu()
	self:CloseMore()
	self.tutorial.Visible = true
	self:_renderTutorial()
end

function UIController:_renderTutorial()
	local page = self.tutorialPages[self.tutorialPage]
	self.tutorialStep.Text = "HOW TO PLAY  /  " .. self.tutorialPage .. " OF " .. #self.tutorialPages
	self.tutorialTitle.Text = page.title
	self.tutorialBody.Text = page.body
	self.tutorialNext.Text = self.tutorialPage == #self.tutorialPages and "LET'S RUN" or "NEXT"
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
	if (self.ctx.Profile.settings or {}).tutorialDone ~= true then
		self:_send("Settings", {tutorialDone = true})
	end
end

function UIController:_buildToast()
	self.toast = frame(self.root, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 180), Size = UDim2.new(0.9, 0, 0, 40), Visible = false, BackgroundColor3 = C.card, ZIndex = 20}, 12)
	node("UISizeConstraint", {MaxSize = Vector2.new(440, 80)}, self.toast)
	self.toastStroke = stroke(self.toast, C.cyan, 0, 3)
	self.toastText = label(self.toast, "", {Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 1, -8), TextSize = 12, Font = F.bold, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 21})
end

-- Role banner at the start of a round: short, near the top, gone in a few seconds.
function UIController:_buildAnnouncement()
	self.announcement = frame(self.root, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 112), Size = UDim2.new(0.9, 0, 0, 74), BackgroundColor3 = C.background, BackgroundTransparency = 0.04, Visible = false, ZIndex = 18}, 16)
	node("UISizeConstraint", {MaxSize = Vector2.new(430, 74)}, self.announcement)
	self.announcementStroke = stroke(self.announcement, C.cyan, 0, 3)
	self.announcementTitle = label(self.announcement, "YOU ARE A RUNNER", {Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 34), TextSize = 26, Font = F.title, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true, ZIndex = 19})
	node("UITextSizeConstraint", {MaxTextSize = 28, MinTextSize = 14}, self.announcementTitle)
	self.announcementCopy = label(self.announcement, "", {Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 28), TextSize = 11, TextWrapped = true, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center, Font = F.medium, ZIndex = 19})
end

function UIController:_buildLoading()
	self.loading = frame(self.root, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.background, ZIndex = 50})
	gradient(self.loading, Color3.fromRGB(255, 150, 70), Color3.fromRGB(255, 80, 110), 45)
	label(self.loading, "CATCH ME IF YOU CAN", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0.9, 0, 0, 70), Font = F.title, TextSize = 40, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.4, ZIndex = 51})
	label(self.loading, "THE MALL", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0.9, 0, 0, 24), Font = F.black, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.amber, ZIndex = 51})
	self.loadingStatus = label(self.loading, "Opening the mall / loading your profile", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.new(0.85, 0, 0, 44), TextColor3 = Color3.fromRGB(255, 244, 240), TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 51})
	label(self.loading, "TIP: " .. TIPS[math.floor(os.clock() * 7) % #TIPS + 1], {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.new(0.9, 0, 0, 40), TextColor3 = C.text, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Font = F.medium, ZIndex = 51})
	task.delay(12, function()
		if self.loading and self.loading.Visible then self.loadingStatus.Text = "Your profile is taking longer to load. Reconnecting automatically..." end
	end)
end

---------------------------------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------------------------------

local BIG_MENUS = {Shop = true, Inventory = true}

function UIController:_responsive()
	local size = self.root.AbsoluteSize
	local small = size.X < 700
	local short = size.Y < 520
	local tiny = size.X < 360
	self.compact = small
	self.short = short
	local cell = (small or short) and (tiny and 44 or 48) or 62
	local horizontal = short
	self.dockHorizontal = horizontal
	-- Header: a compact timer chip and wallet pill.
	self.clock.Position = size.X < 520 and UDim2.fromOffset(tiny and 8 or 12, 0) or UDim2.fromScale(0.5, 0)
	self.clock.AnchorPoint = size.X < 520 and Vector2.zero or Vector2.new(0.5, 0)
	self.clock.Size = UDim2.fromOffset(tiny and 128 or (small and 150 or 190), 50)
	self.phaseLabel.TextSize = small and 8 or 9
	self.timerLabel.TextSize = small and 18 or 22
	self.wallet.Size = UDim2.fromOffset(tiny and 104 or (small and 116 or 150), 44)
	self.coinsLabel.TextSize = small and 14 or 17
	-- Dock: Shop, Locker and More, on screen at every size.
	for _, child in ipairs(self.dock:GetChildren()) do
		if child:IsA("GuiButton") then
			child.Size = UDim2.fromOffset(cell, cell)
			local caption, icon = child:FindFirstChild("Caption"), child:FindFirstChild("Icon")
			if caption then caption.Visible = cell >= 60 end
			if icon then
				icon.Size = UDim2.new(1, 0, 0, cell >= 60 and 30 or cell)
				icon.Position = UDim2.fromOffset(0, cell >= 60 and 4 or 0)
				icon.TextSize = cell >= 60 and 26 or 22
			end
		end
	end
	self.dockLayout.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	self.dockLayout.Padding = UDim.new(0, (small or short) and 4 or 6)
	local dockCount = #DOCK + 1
	local gap = (small or short) and 4 or 6
	local dockLength = dockCount * cell + (dockCount - 1) * gap
	-- The dock lives on the right, so Roblox's own chat (top left) is never moved or covered.
	self.dock.AnchorPoint = Vector2.new(1, 0)
	self.dock.Position = horizontal and UDim2.new(1, -8, 0, 58) or UDim2.new(1, small and -6 or -8, 0, 62)
	self.dock.Size = horizontal and UDim2.fromOffset(dockLength, cell) or UDim2.fromOffset(cell, dockLength)
	local rightMargin = horizontal and 8 or (cell + (small and 12 or 16))
	local top = horizontal and (58 + cell + 6) or 62
	self.rightMargin = rightMargin
	self.leftMargin = 12
	-- More popover: beside the More button (below the dock on short screens).
	self.moreMenu.AnchorPoint = Vector2.new(1, 0)
	if horizontal then
		self.moreMenu.Position = UDim2.new(1, -8, 0, 58 + cell + 4)
	else
		local y = 62 + (dockCount - 1) * (cell + gap)
		y = math.min(y, math.max(8, size.Y - self.moreMenu.Size.Y.Offset - 8))
		self.moreMenu.Position = UDim2.new(1, -rightMargin, 0, y)
	end
	-- Objective chip: centered under the timer, or at the left edge on narrow screens.
	local objectiveWidth = math.min(290, size.X - 12 - rightMargin - 8)
	self.objective.Size = UDim2.fromOffset(math.max(180, objectiveWidth), 44)
	if small then
		self.objective.AnchorPoint = Vector2.zero
		self.objective.Position = UDim2.fromOffset(12, 58)
	else
		self.objective.AnchorPoint = Vector2.new(0.5, 0)
		self.objective.Position = UDim2.new(0.5, 0, 0, 62)
	end
	self.hideMeter.Size = UDim2.fromOffset(math.max(180, math.min(240, size.X - 12 - rightMargin - 8)), 62)
	self.hideMeter.AnchorPoint = small and Vector2.zero or Vector2.new(0.5, 0)
	self.hideMeter.Position = small and UDim2.fromOffset(12, 108) or UDim2.new(0.5, 0, 0, 112)
	-- Menu panel: Shop and Locker are roomy, everything else is a small card. In a round the big menus become a
	-- narrow drawer so the world stays in view. The panel sits left of the dock and never covers it.
	local bottom = (small or short) and 8 or 12
	local drawer = self:_inRound() and size.X >= 700
	local big = BIG_MENUS[self.menu or ""] == true
	local available = size.X - rightMargin - 12
	local width
	if big then width = math.min(math.max(250, available), drawer and 440 or 940)
	else width = math.min(math.max(250, available), 390) end
	local height = size.Y - (top + bottom)
	if not big then height = math.min(height, 520) elseif not drawer then height = math.min(height, 600) end
	self.panel.Size = UDim2.fromOffset(width, height)
	self.panel.Position = UDim2.fromOffset(size.X - rightMargin - width, top)
	self.panelTitle.TextSize = small and 18 or 22
	self.panelSubtitle.TextSize = small and 9 or 10
	self.panelSubtitle.TextTruncate = Enum.TextTruncate.AtEnd
	self.abilities.Visible = UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch and not short and size.X >= 820 and not (self.results and self.results.Visible)
	self.spectator.Size = UDim2.fromOffset(math.min(280, size.X - 36), 52)
	self.spectator.Position = UDim2.new(0.5, 0, 1, UserInputService.TouchEnabled and -24 or -66)
	self.saveLabel.Visible = not short and not small
	self.versionLabel.Visible = not short
	if self.results then self:_layoutResults() end
	self:_updateSpectator()
end

---------------------------------------------------------------------------------------------------
-- Menus
---------------------------------------------------------------------------------------------------

function UIController:OpenMenu(name)
	if not self.ctx.Profile.loaded then return end
	if self.menu == name then self:CloseMenu() return end
	self:CloseMore()
	self.menu = name
	self.player:SetAttribute("CatchMenuOpen", true)
	self.panel.Visible = true
	self.panelScale.Scale = self:_motion() and 0.97 or 1
	self:_tween(self.panelScale, 0.22, {Scale = 1})
	self:_responsive()
	self:_renderMenu()
	if UserInputService.GamepadEnabled then
		local close = self.panel:FindFirstChild("Close")
		if close then GuiService.SelectedObject = close end
	end
end

function UIController:CloseMenu()
	self.menu = nil
	self.player:SetAttribute("CatchMenuOpen", false)
	self.panel.Visible = false
	self.previewModel = nil
	self.previewCamera = nil
	clear(self.panelContent)
	GuiService.SelectedObject = nil
	self:_responsive()
end

function UIController:_renderMenu()
	local focused = GuiService.SelectedObject
	local focusName = focused and focused:IsDescendantOf(self.panelContent) and focused.Name
	local grid = self.panelContent:FindFirstChild("CollectionGrid", true)
	if grid and grid.ClassName == "ScrollingFrame" and grid.CanvasPosition then self.gridScroll = grid.CanvasPosition.Y end
	self.previewModel, self.previewCamera = nil, nil
	clear(self.panelContent)
	local colors = {Shop = C.pink, Inventory = C.blue, Quests = C.amber, Progress = C.green, Settings = C.line, Leaderboard = C.cyan}
	local banner = colors[self.menu] or C.pink
	self.bannerGradient.Color = ColorSequence.new(shade(banner, 1.12), shade(banner, 0.82))
	if self.menu == "Shop" or self.menu == "Inventory" then self:_renderShop()
	elseif self.menu == "Quests" then self:_renderQuests()
	elseif self.menu == "Progress" then self:_renderProgress()
	elseif self.menu == "Settings" then self:_renderSettings()
	elseif self.menu == "Leaderboard" then self:_renderLeaderboard() end
	if self:_inRound() and (self.menu == "Shop" or self.menu == "Inventory") then
		self.panelSubtitle.Text = "The round keeps going while you browse. " .. self.panelSubtitle.Text
	end
	-- Rerendering an equipped item or category must not strand controller focus.
	if focusName then
		local replacement = self.panelContent:FindFirstChild(focusName, true)
		GuiService.SelectedObject = replacement and replacement:IsA("GuiButton") and replacement or self.panel:FindFirstChild("Close")
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
		local names = {rounds = "ROUNDS", wins = "WINS", tags = "TAGS", level = "LEVEL", bestStreak = "WIN STREAK", hunterWins = "HUNTER WINS", survived = "SECONDS SURVIVED", pickups = "COINS COLLECTED", finds = "FINDS"}
		return (names[milestone.stat] or string.upper(tostring(milestone.stat or "milestone"))) .. " " .. number(milestone.value)
	end
	return "FREE"
end

-- Short card caption: never says "NOT CONFIGURED" on a card, the action button is honest about that.
function UIController:_cardStatus(item, owned, equipped)
	if equipped[item.category] == item.id then return "EQUIPPED", C.green end
	if owned[item.id] then return "OWNED", C.cyan end
	if item.currency == "Robux" then return "R$ " .. number(item.price), C.amber end
	return self:_itemPrice(item), C.amber
end

-- Skin and mask thumbnails come from a cached preview rig so browsing does not rebuild avatars.
function UIController:_thumbnail(parent, item, equipped)
	local key = item.id .. "|" .. (item.category == "masks" and tostring(equipped.skins) or tostring(equipped.masks)) .. "|" .. (self.avatarBase and "avatar" or "mannequin")
	local view = node("ViewportFrame", {
		Name = "Thumb", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 3,
		Ambient = Color3.fromRGB(200, 205, 235), LightColor = Color3.fromRGB(255, 244, 225), LightDirection = Vector3.new(-1, -0.6, -1),
	}, parent)
	local world = node("WorldModel", {}, view)
	local rig = self.thumbs[key]
	local clone
	if rig then
		local ok, copy = pcall(function() return rig:Clone() end)
		if ok then clone = copy end
	else
		local extra = table.clone(equipped)
		local skin, mask
		if item.category == "masks" then
			skin = equipped.skins ~= "" and equipped.skins or "skin_courier"
			mask = item.id
		else
			skin = item.id
			mask = ""
		end
		local ok, built = pcall(self.Appearance.BuildPreview, skin, mask, extra, {userId = self.player.UserId}, self.avatarBase)
		if ok and built then
			self.thumbCount = (self.thumbCount or 0) + 1
			if self.thumbCount > 48 then self.thumbs, self.thumbCount = {}, 1 end
			self.thumbs[key] = built
			local copied, copy = pcall(function() return built:Clone() end)
			clone = copied and copy or built
		end
	end
	if not clone then view:Destroy() return end
	clone.Parent = world
	local camera = node("Camera", {FieldOfView = item.category == "masks" and 28 or 40,
		CFrame = item.category == "masks" and CFrame.lookAt(Vector3.new(0.5, 2.5, -6.4), Vector3.new(0, 2.35, 0))
			or CFrame.lookAt(Vector3.new(1.2, 0.2, -12.5), Vector3.new(0, -0.1, 0))}, view)
	view.CurrentCamera = camera
end

function UIController:_renderShop()
	local inventory = self.menu == "Inventory"
	self.panelTitle.Text = inventory and "MY LOCKER" or "THE MALL SHOP"
	self.panelSubtitle.Text = inventory and "Mix and match. Every mask works with every outfit." or "Cosmetics only. Nobody can buy an advantage."
	local compact = self.panel.AbsoluteSize.X < 760 or self.panelContent.AbsoluteSize.Y < 390
	local portrait = self.panel.AbsoluteSize.X < 540
	local profile = self.ctx.Profile
	local owned = profile.owned or {}
	local equipped = profile.equipped or {}
	if inventory and self.category == "coins" then self.category = "skins" end
	local visible = {}
	for _, item in ipairs(self.ctx.Catalog.ForCategory(self.category)) do
		if not inventory or owned[item.id] then visible[#visible + 1] = item end
	end
	local columns = compact and (portrait and 2 or 3) or 3
	local surface = compact and scroll(self.panelContent, {Name = "CompactCollection"}) or self.panelContent
	local detailHeight = portrait and 502 or 286
	local cellHeight = portrait and 164 or 178
	local gridHeight = math.max(cellHeight, math.ceil(#visible / columns) * (cellHeight + 10))
	local detail = frame(surface, {
		Name = "FittingStage",
		Position = UDim2.new(),
		Size = compact and UDim2.new(1, -5, 0, detailHeight) or UDim2.new(0.4, -8, 1, 0),
		BackgroundColor3 = C.panel,
	}, 18)
	stroke(detail, C.ink, 0, 3)
	gradient(detail, Color3.fromRGB(96, 76, 200), Color3.fromRGB(46, 34, 112), 115)
	local collection = frame(surface, {
		Position = compact and UDim2.fromOffset(0, detailHeight + 18) or UDim2.new(0.4, 10, 0, 0),
		Size = compact and UDim2.new(1, -5, 0, gridHeight + 78) or UDim2.new(0.6, -10, 1, 0), BackgroundTransparency = 1,
	})
	local categories = scroll(collection, {Name = "Categories", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 44), ScrollBarThickness = 0}, true)
	list(categories, true, 6)
	for index, category in ipairs(self.ctx.Catalog.Categories) do
		local chosen = self.category == category.id
		button(categories, (CATEGORY_ICON[category.id] or "") .. " " .. string.upper(category.label), function()
			self.category = category.id self.gridScroll = 0 self:_renderMenu()
		end, {Name = "Category_" .. category.id, Size = UDim2.fromOffset(math.max(86, #category.label * 8 + 44), 38), LayoutOrder = index, TextSize = 11,
			BackgroundColor3 = chosen and C.amber or C.card, TextColor3 = chosen and C.ink or C.text})
	end
	if not inventory then
		local chosen = self.category == "coins"
		button(categories, "💰 COINS", function() self.category = "coins" self.gridScroll = 0 self:_renderMenu() end,
			{Name = "Category_coins", Size = UDim2.fromOffset(96, 38), LayoutOrder = 99, TextSize = 11,
				BackgroundColor3 = chosen and C.amber or C.green, TextColor3 = C.ink})
	end
	if self.category == "coins" and not inventory then
		self:_renderCoinPacks(collection, detail)
		return
	end
	local gridProps = {Name = "CollectionGrid", Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), BackgroundTransparency = 1}
	local grid = compact and frame(collection, gridProps) or scroll(collection, gridProps)
	node("UIGridLayout", {CellPadding = UDim2.fromOffset(10, 10), CellSize = UDim2.new(1 / columns, -8, 0, cellHeight), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	local selected = self.ctx.Catalog.Get(self.selectedItem)
	local selectionValid = false
	for _, item in ipairs(visible) do if item.id == self.selectedItem then selectionValid = true break end end
	if not selectionValid then selected = visible[1] self.selectedItem = selected and selected.id or nil end
	for index, item in ipairs(visible) do
		local chosen = self.selectedItem == item.id
		local rarity = rarityColor(item)
		local card = button(grid, "", function() self.selectedItem = item.id self:_renderMenu() end, {Name = "Item_" .. item.id, LayoutOrder = index,
			BackgroundColor3 = chosen and shade(rarity, 0.62) or C.card})
		local art = frame(card, {Name = "Art", Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, cellHeight - 74), BackgroundColor3 = shade(rarity, 0.4), ZIndex = 2}, 10)
		gradient(art, shade(rarity, 0.75), shade(rarity, 0.35), 90)
		local tier = (self.ctx.Perf or {}).tier or 1
		local wantsThumb = (item.category == "skins" or item.category == "masks") and (tier == 1 or (tier == 2 and index <= 6))
		if wantsThumb then
			self:_thumbnail(art, item, equipped)
		elseif item.category == "skins" or item.category == "masks" then
			label(art, CATEGORY_ICON[item.category], {TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3})
		elseif item.category == "tones" or item.category == "hairColors" then
			local swatch = frame(art, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(54, 54), BackgroundColor3 = accent(item), ZIndex = 3}, 27)
			stroke(swatch, C.text, 0, 3)
		else
			label(art, CATEGORY_ICON[item.category] or "🎁", {TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3})
		end
		label(card, string.upper(item.rarity or "Common"), {Name = "Rarity", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(80, 14), TextSize = 9, Font = F.black, TextColor3 = C.text, TextStrokeTransparency = 0.4, ZIndex = 4})
		label(card, item.name, {Name = "Name", Position = UDim2.new(0, 8, 1, -64), Size = UDim2.new(1, -16, 0, 34), Font = F.black, TextSize = portrait and 11 or 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 4})
		local text, color = self:_cardStatus(item, owned, equipped)
		label(card, text, {Name = "Status", Position = UDim2.new(0, 8, 1, -28), Size = UDim2.new(1, -16, 0, 20), Font = F.black, TextSize = 10, TextColor3 = color, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4})
		-- Rarity at a glance: Epic and Legendary cards carry a colored outline; the chosen card is outlined in white.
		if chosen then stroke(card, C.text, 0, 3)
		elseif item.rarity == "Epic" or item.rarity == "Legendary" then stroke(card, rarity, 0, item.rarity == "Legendary" and 3 or 2) end
	end
	if not compact and grid.ClassName == "ScrollingFrame" and self.gridScroll then grid.CanvasPosition = Vector2.new(0, self.gridScroll) end
	if #visible == 0 then
		label(collection, "Your locker is empty here.\nVisit the shop to find something you love!", {Position = UDim2.fromOffset(12, 96), Size = UDim2.new(1, -24, 0, 80), TextWrapped = true, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center})
		button(collection, "EXPLORE THE SHOP", function() self:OpenMenu("Shop") end, {Name = "ExploreShop", Position = UDim2.fromOffset(12, 186), Size = UDim2.new(1, -24, 0, 44), BackgroundColor3 = C.pink, TextSize = 13})
	end
	self:_renderItemDetail(detail, selected, compact and not portrait)
end

-- Coin packs are developer products: the server grants coins from the receipt, never from this UI.
function UIController:_renderCoinPacks(collection, detail)
	label(detail, "COINS BUY STYLE, NOT POWER", {Position = UDim2.fromOffset(18, 18), Size = UDim2.new(1, -36, 0, 40), Font = F.title, TextSize = 22, TextWrapped = true, TextColor3 = C.amber})
	label(detail, "Coins only unlock cosmetics: outfits, masks, trails and titles. No pack changes speed, tagging, hiding or anything else in a round. You also earn coins free by playing, collecting mall coins and claiming daily missions.", {Position = UDim2.fromOffset(18, 66), Size = UDim2.new(1, -36, 1, -90), TextSize = 12, TextColor3 = C.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = F.medium})
	local grid = scroll(collection, {Name = "CoinPacks", Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52)})
	list(grid, false, 10)
	for index, pack in ipairs(self.ctx.Catalog.Products) do
		local configured = (pack.productId or 0) > 0
		local row = frame(grid, {Name = "Pack_" .. pack.id, Size = UDim2.new(1, -8, 0, 78), LayoutOrder = index, BackgroundColor3 = C.card}, 16)
		stroke(row, C.ink, 0, 3)
		label(row, "🪙", {Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(52, 52), TextSize = 38, TextXAlignment = Enum.TextXAlignment.Center})
		label(row, pack.name, {Position = UDim2.fromOffset(72, 12), Size = UDim2.new(1, -230, 0, 22), Font = F.black, TextSize = 15, TextTruncate = Enum.TextTruncate.AtEnd})
		label(row, number(pack.coins) .. " COINS", {Position = UDim2.fromOffset(72, 38), Size = UDim2.new(1, -230, 0, 24), Font = F.title, TextSize = 20, TextColor3 = C.amber})
		button(row, configured and ("R$ " .. number(pack.robux)) or "COMING SOON", function()
			if configured then self:_send("BuyCoins", {id = pack.id}) else self:Toast("Coin packs are not configured for sale yet.") end
		end, {Name = "BuyPack_" .. pack.id, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(130, 44), TextSize = 13,
			BackgroundColor3 = configured and C.green or C.card, TextColor3 = configured and C.ink or C.muted})
	end
end

function UIController:_renderItemDetail(parent, item, horizontal)
	if not item then label(parent, "PICK SOMETHING FUN", {TextColor3 = C.muted, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center}) return end
	local profile = self.ctx.Profile
	local owned = (profile.owned or {})[item.id] == true
	local equipped = profile.equipped or {}
	local rarity = rarityColor(item)
	label(parent, "TRY IT ON / " .. string.upper(item.category), {Position = UDim2.fromOffset(16, 13), Size = UDim2.new(1, -32, 0, 17), Font = F.black, TextSize = 10, TextColor3 = C.cyan})
	local stage = frame(parent, {Name = "PreviewStage", Position = UDim2.fromOffset(8, 35), Size = horizontal and UDim2.new(0.46, -8, 1, -43) or UDim2.new(1, -16, 1, -249), BackgroundTransparency = 1})
	local plate = frame(stage, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -42), Size = UDim2.new(0.72, 0, 0, 25), BackgroundColor3 = rarity, BackgroundTransparency = 0.7}, 100)
	stroke(plate, rarity, 0.4, 2)
	local view = node("ViewportFrame", {
		Name = "CharacterPreview", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -36),
		Ambient = Color3.fromRGB(205, 210, 240), LightColor = Color3.fromRGB(255, 244, 225), LightDirection = Vector3.new(-1, -0.6, -1),
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
	local success, rig = pcall(self.Appearance.BuildPreview, skin, mask, extra, {userId = self.player.UserId}, self.avatarBase)
	if success and rig then
		rig.Parent = world
		self.previewModel = rig
		self.previewAngle, self.previewTime = 0.18, 0
		local camera = node("Camera", {FieldOfView = 38, CFrame = CFrame.lookAt(Vector3.new(2, 1.4, -11), Vector3.new(0, 0.15, 0))}, view)
		view.CurrentCamera = camera self.previewCamera = camera
	else
		label(stage, "PREVIEW UNAVAILABLE", {Size = view.Size, TextColor3 = C.muted, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center})
	end
	local controls = frame(stage, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromOffset(184, 34), BackgroundTransparency = 1})
	button(controls, "<", function() self.previewAngle -= math.pi / 4 end, {Name = "PreviewLeft", Size = UDim2.fromOffset(40, 32), TextSize = 16})
	button(controls, "FRONT", function() self.previewAngle, self.previewTime = 0, 0 end, {Name = "PreviewFront", Position = UDim2.fromOffset(46, 0), Size = UDim2.fromOffset(92, 32), TextSize = 10})
	button(controls, ">", function() self.previewAngle += math.pi / 4 end, {Name = "PreviewRight", Position = UDim2.fromOffset(144, 0), Size = UDim2.fromOffset(40, 32), TextSize = 16})
	local info = frame(parent, {Name = "ItemInformation", Position = horizontal and UDim2.new(0.46, 8, 0, 42) or UDim2.new(0, 18, 1, -196), Size = horizontal and UDim2.new(0.54, -26, 1, -60) or UDim2.new(1, -36, 0, 178), BackgroundTransparency = 1})
	label(info, string.upper(item.rarity or "COMMON"), {Size = UDim2.new(1, 0, 0, 15), TextSize = 10, Font = F.black, TextColor3 = rarity})
	label(info, item.name, {Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 0, 38), TextSize = 22, Font = F.title, TextWrapped = true})
	label(info, item.description or "", {Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 62), TextSize = 11, TextColor3 = C.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = F.medium})
	if self:_inRound() and self.ctx.Catalog.IsEquippable(item.category) then
		label(info, "Saves now, shows up after this round.", {Name = "RoundHint", Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 0, 14), TextSize = 10, TextColor3 = C.amber})
	end
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
	button(info, actionText, function()
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
	end, {Name = "ItemAction", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 44), TextSize = 13, BackgroundColor3 = canAct and C.green or C.card, TextColor3 = canAct and C.ink or C.muted})
end

local function progressBar(parent, position, size, ratio, color)
	local track = frame(parent, {Position = position, Size = size, BackgroundColor3 = C.ink}, 5)
	frame(track, {Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1), BackgroundColor3 = color}, 5)
	return track
end

local function card(parent, props)
	local object = frame(parent, props, 16)
	stroke(object, C.ink, 0, 3)
	return object
end

function UIController:_renderQuests()
	self.panelTitle.Text = "DAILY MISSIONS"
	self.panelSubtitle.Text = "Three quick goals. Refreshes at 00:00 UTC."
	local container = scroll(self.panelContent)
	list(container, false, 12)
	local quests = self.ctx.Profile.quests or {}
	local narrow = self.panelContent.AbsoluteSize.X < 520
	local login = self.ctx.Profile.loginStatus
	if login then
		local done = login.canClaim and (login.day - 1) or login.day
		local box = card(container, {Name = "DailyLogin", Size = UDim2.new(1, -8, 0, narrow and 176 or 132), LayoutOrder = 0})
		label(box, "DAILY LOGIN  /  DAY " .. number(login.day) .. " OF 7", {Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 15), TextSize = 10, TextColor3 = login.canClaim and C.amber or C.muted, Font = F.black})
		label(box, login.canClaim and ("Today: +" .. number(login.coins) .. " COINS  /  +" .. number(login.xp) .. " XP")
			or ("Claimed. Come back tomorrow to extend your " .. number(login.streak) .. "-day streak."), {Position = UDim2.fromOffset(18, 36), Size = UDim2.new(1, narrow and -36 or -168, 0, 40), TextSize = 16, TextWrapped = true})
		for day = 1, 7 do
			frame(box, {Name = "LoginDay" .. day, Position = UDim2.fromOffset(18 + (day - 1) * 34, 88), Size = UDim2.fromOffset(28, 12), BackgroundColor3 = day <= done and C.amber or C.ink}, 4)
		end
		button(box, login.canClaim and "CLAIM" or "CLAIMED", function()
			if login.canClaim then self:_send("ClaimLogin") end
		end, {Name = "ClaimLogin", Position = UDim2.new(1, -142, 0, narrow and 128 or 36), Size = UDim2.fromOffset(124, 38), TextSize = 12, BackgroundColor3 = login.canClaim and C.amber or C.card, TextColor3 = login.canClaim and C.ink or C.muted})
	end
	for index, quest in ipairs(quests) do
		local box = card(container, {Name = "Dispatch_" .. quest.id, Size = UDim2.new(1, -8, 0, narrow and 182 or 140), LayoutOrder = index})
		local ratio = math.clamp((quest.progress or 0) / math.max(quest.goal or 1, 1), 0, 1)
		label(box, string.format("MISSION %02d", index), {Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 15), TextSize = 10, TextColor3 = quest.claimed and C.muted or C.cyan, Font = F.black})
		label(box, quest.text, {Position = UDim2.fromOffset(18, 39), Size = UDim2.new(1, narrow and -36 or -168, 0, 40), TextSize = 16, TextWrapped = true})
		label(box, "+" .. number(quest.xp) .. " XP  /  +" .. number(quest.coins) .. " COINS", {Position = UDim2.fromOffset(18, 85), Size = UDim2.new(1, -36, 0, 17), TextSize = 12, TextColor3 = C.amber})
		progressBar(box, UDim2.fromOffset(18, 114), UDim2.new(1, -36, 0, 10), ratio, quest.claimed and C.muted or C.green)
		if narrow then
			label(box, number(math.min(quest.progress or 0, quest.goal or 0)) .. " / " .. number(quest.goal), {Position = UDim2.fromOffset(18, 132), Size = UDim2.new(1, -155, 0, 31), TextSize = 12, TextColor3 = C.muted})
		end
		button(box, quest.claimed and "CLAIMED" or (ratio >= 1 and "CLAIM REWARD" or (number(math.min(quest.progress or 0, quest.goal or 0)) .. " / " .. number(quest.goal))), function()
			if ratio >= 1 and not quest.claimed then self:_send("ClaimQuest", {id = quest.id}) end
		end, {Name = "Quest_" .. quest.id, Position = UDim2.new(1, -142, 0, narrow and 132 or 41), Size = UDim2.fromOffset(124, 38), TextSize = 11, BackgroundColor3 = ratio >= 1 and not quest.claimed and C.green or C.card, TextColor3 = ratio >= 1 and not quest.claimed and C.ink or C.muted})
	end
	if #quests == 0 then label(container, "Your missions are loading.", {Size = UDim2.new(1, 0, 0, 50), TextColor3 = C.muted}) end
end

function UIController:_renderProgress()
	local profile = self.ctx.Profile
	self.panelTitle.Text = "MY MALL CAREER"
	self.panelSubtitle.Text = "Every chase counts. Studio solo practice gives no rewards."
	local container = scroll(self.panelContent)
	list(container, false, 12)
	local rank = card(container, {Size = UDim2.new(1, -8, 0, 145), LayoutOrder = 1})
	label(rank, string.upper(profile.rank or "ROOKIE") .. "  /  " .. number(profile.rating) .. " RATING", {Position = UDim2.fromOffset(18, 15), Size = UDim2.new(1, -36, 0, 20), TextColor3 = C.amber, TextSize = 13, Font = F.black})
	label(rank, "LEVEL " .. number(profile.level), {Position = UDim2.fromOffset(18, 40), Size = UDim2.new(1, -36, 0, 38), Font = F.title, TextSize = 30})
	local level = profile.level or 1
	local lower = self.ctx.Rules.XPForLevel(level)
	local upper = self.ctx.Rules.XPForLevel(level + 1)
	local ratio = math.clamp(((profile.xp or 0) - lower) / math.max(upper - lower, 1), 0, 1)
	label(rank, number(profile.xp) .. " XP  /  " .. number(upper) .. " XP NEXT LEVEL", {Position = UDim2.fromOffset(18, 86), Size = UDim2.new(1, -36, 0, 17), TextColor3 = C.muted, TextSize = 11})
	progressBar(rank, UDim2.fromOffset(18, 112), UDim2.new(1, -36, 0, 12), ratio, C.green)
	local stats = profile.stats or {}
	local specs = {{"ROUNDS PLAYED", stats.rounds}, {"TOTAL WINS", stats.wins}, {"SUCCESSFUL TAGS", stats.tags}, {"RUNNERS FOUND", stats.finds}, {"MALL COINS COLLECTED", stats.pickups}, {"CLOSE CALLS", stats.closeCalls},
		{"HUNTER WINS", stats.hunterWins}, {"RUNNER WINS", stats.runnerWins}, {"BEST WIN STREAK", profile.bestStreak}, {"SECONDS SURVIVED", stats.survived}}
	for index, spec in ipairs(specs) do
		local row = card(container, {Size = UDim2.new(1, -8, 0, 48), LayoutOrder = index + 1})
		label(row, spec[1], {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -100, 1, 0), Font = F.bold, TextColor3 = C.muted, TextSize = 11})
		label(row, number(spec[2]), {Position = UDim2.new(1, -90, 0, 0), Size = UDim2.fromOffset(72, 48), Font = F.title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right})
	end
	for index, achievement in ipairs(self.ctx.Achievements.List) do
		local unlocked = (profile.achievements or {})[achievement.id] == true
		local current = (profile.stats or {})[achievement.stat] or profile[achievement.stat] or 0
		local row = card(container, {Size = UDim2.new(1, -8, 0, 66), LayoutOrder = 20 + index})
		label(row, (unlocked and "UNLOCKED  /  " or "LOCKED  /  ") .. achievement.name, {Position = UDim2.fromOffset(16, 9), Size = UDim2.new(1, -120, 0, 21), TextSize = 11, Font = F.black, TextColor3 = unlocked and C.amber or C.muted, TextTruncate = Enum.TextTruncate.AtEnd})
		label(row, "+" .. number(achievement.coins) .. " COINS", {Position = UDim2.new(1, -104, 0, 9), Size = UDim2.fromOffset(90, 21), TextSize = 10, TextColor3 = unlocked and C.muted or C.amber, TextXAlignment = Enum.TextXAlignment.Right})
		label(row, achievement.text .. (unlocked and "" or ("   " .. number(math.min(current, achievement.goal)) .. " / " .. number(achievement.goal))), {Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -32, 0, 17), TextSize = 11, TextColor3 = C.muted, TextTruncate = Enum.TextTruncate.AtEnd, Font = F.medium})
	end
end

function UIController:_renderSettings()
	self.panelTitle.Text = "SETTINGS"
	self.panelSubtitle.Text = "CATCH ME IF YOU CAN / " .. tostring(self.ctx.Config.Version or "v0.5.0") .. " / Preferences save with your profile."
	local container = scroll(self.panelContent)
	list(container, false, 10)
	local settings = self.ctx.Profile.settings or {}
	local specs = {
		{"music", "MUSIC", "Background soundtrack when audio is configured."},
		{"sfx", "SOUND EFFECTS", "Chase, coin, movement and celebration sounds."},
		{"reducedMotion", "REDUCED MOTION", "Calmer transitions, a still preview, less camera motion."},
		{"cameraShake", "CAMERA FEEDBACK", "Small camera reactions to actions and nearby tags."},
	}
	for index, spec in ipairs(specs) do
		local row = card(container, {Size = UDim2.new(1, -8, 0, 83), LayoutOrder = index})
		label(row, spec[2], {Position = UDim2.fromOffset(16, 13), Size = UDim2.new(1, -120, 0, 22), TextSize = 13, Font = F.black})
		label(row, spec[3], {Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -120, 0, 32), TextSize = 10, TextColor3 = C.muted, TextWrapped = true, Font = F.medium})
		local enabled = settings[spec[1]] == true
		button(row, enabled and "ON" or "OFF", function() self:_send("Settings", {[spec[1]] = not enabled}) end, {Name = "Setting_" .. spec[1], Position = UDim2.new(1, -92, 0, 23), Size = UDim2.fromOffset(74, 38), BackgroundColor3 = enabled and C.green or C.card, TextColor3 = enabled and C.ink or C.muted})
	end
	do
		-- Graphics: AUTO picks by device and steps down if the frame rate stays low. Local only; never changes gameplay.
		local perf = self.ctx.Perf or {tier = 1, name = "HIGH", auto = true}
		local row = card(container, {Name = "GraphicsRow", Size = UDim2.new(1, -8, 0, 83), LayoutOrder = 5})
		label(row, "GRAPHICS", {Position = UDim2.fromOffset(16, 13), Size = UDim2.new(1, -170, 0, 22), TextSize = 13, Font = F.black})
		label(row, "Lower settings hide far-away decoration and effects on slower devices.", {Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -170, 0, 32), TextSize = 10, TextColor3 = C.muted, TextWrapped = true, Font = F.medium})
		button(row, (perf.auto and "AUTO · " or "") .. (perf.name or "HIGH"), function()
			local controller = self.ctx.Controllers and self.ctx.Controllers.PerformanceController
			if not controller then return end
			-- AUTO -> HIGH -> MEDIUM -> LOW -> AUTO
			if perf.auto then controller:SetPreference(1)
			elseif perf.tier < 3 then controller:SetPreference(perf.tier + 1)
			else controller:SetPreference(nil) end
			self:_renderMenu()
		end, {Name = "Setting_graphics", Position = UDim2.new(1, -150, 0, 23), Size = UDim2.fromOffset(132, 38), TextSize = 12})
	end
	local instructions = card(container, {Size = UDim2.new(1, -8, 0, 176), LayoutOrder = 10})
	button(container, "HOW TO PLAY", function() self:ShowTutorial() end, {Name = "HowToPlay", Size = UDim2.new(1, -8, 0, 44), LayoutOrder = 11, TextSize = 12, BackgroundColor3 = C.pink})
	label(instructions, "CONTROLS", {Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 22), Font = F.black, TextColor3 = C.cyan, TextSize = 12})
	label(instructions, "Sprint  Shift / L3     Slide  C / B\nJump + vault  Space / A     Tag  F / R2\nHide or search a spot  hold E\nHunter scan  Q / X     Leave a hiding spot  jump or LEAVE\nTouch: use the on-screen controls.\nGamepad: Y opens your locker. A selects; B closes.", {Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 126), TextColor3 = C.muted, TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = F.medium})
end

function UIController:_renderLeaderboard()
	self.panelTitle.Text = "THE CREW"
	self.panelSubtitle.Text = "This server / rating, wins and tags"
	local container = scroll(self.panelContent)
	list(container, false, 7)
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
		local row = card(container, {Size = UDim2.new(1, -8, 0, 72), LayoutOrder = index, BackgroundColor3 = player == self.player and C.card or C.panel})
		label(row, string.format("%02d", index), {Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(33, 25), TextColor3 = index == 1 and C.amber or C.muted, Font = F.title, TextSize = 22})
		label(row, player.DisplayName .. (player == self.player and "  (YOU)" or ""), {Position = UDim2.fromOffset(54, 10), Size = UDim2.new(1, -68, 0, 23), TextSize = 14, TextTruncate = Enum.TextTruncate.AtEnd})
		label(row, string.upper(role) .. "  /  LV " .. number(stat(player, "Level")) .. "  /  " .. number(stat(player, "Rating")) .. " RATING  /  " .. number(stat(player, "Wins")) .. " WINS  /  " .. number(stat(player, "Tags")) .. " TAGS", {Position = UDim2.fromOffset(54, 39), Size = UDim2.new(1, -68, 0, 24), TextColor3 = C.muted, TextSize = self.compact and 8 or 10, TextWrapped = true, Font = F.medium})
	end
end

-- Results: a compact card at the side of the screen (not a full panel), so the podium and the world stay visible.
-- Practice rounds say plainly that nothing is saved; real rounds show exactly what the server granted
-- (it arrives as a "reward" notice).
function UIController:_buildResults()
	self.results = frame(self.root, {Name = "ResultsCard", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(330, 240), BackgroundColor3 = C.background, Visible = false, ZIndex = 16}, 16)
	stroke(self.results, C.amber, 0, 3)
	gradient(self.results, Color3.fromRGB(56, 66, 124), C.background, 110)
	self.resultsTitle = label(self.results, "", {Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -62, 0, 28), Font = F.title, TextSize = 22, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 17})
	self.resultsSubtitle = label(self.results, "", {Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -28, 0, 28), TextSize = 10, TextColor3 = C.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = F.medium, ZIndex = 17})
	button(self.results, "X", function() self:_hideResults() end, {Name = "ResultsClose", Position = UDim2.new(1, -42, 0, 8), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = C.coral, TextSize = 13, ZIndex = 18})
	self.resultsBody = frame(self.results, {Name = "ResultsBody", Position = UDim2.fromOffset(12, 68), Size = UDim2.new(1, -24, 1, -118), BackgroundTransparency = 1, ZIndex = 17})
	list(self.resultsBody, false, 5)
	button(self.results, "OK", function() self:_hideResults() end, {Name = "ViewPodium", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -10), Size = UDim2.new(0.4, -16, 0, 34), BackgroundColor3 = C.green, TextColor3 = C.ink, TextSize = 12, ZIndex = 18})
	button(self.results, "MY CAREER", function() self:_hideResults() self:OpenMenu("Progress") end, {Name = "ViewCareer", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -12, 1, -10), Size = UDim2.new(0.6, -16, 0, 34), TextSize = 12, ZIndex = 18})
end

function UIController:_layoutResults()
	local size = self.root.AbsoluteSize
	local winners = math.min(#(self.ctx.State.winners or {}), 3)
	local rewarded = self.lastReward ~= nil and not self.ctx.State.practice
	local height = 132 + winners * 24 + (rewarded and 70 or 26)
	height = math.min(height, size.Y - 90)
	if size.X < 700 then
		self.results.AnchorPoint = Vector2.new(0.5, 1)
		self.results.Position = UDim2.new(0.5, 0, 1, -62)
		self.results.Size = UDim2.fromOffset(math.min(340, size.X - 24), math.min(height, size.Y - 130))
	else
		self.results.AnchorPoint = Vector2.new(0, 0.5)
		self.results.Position = UDim2.new(0, 12, 0.5, 0)
		self.results.Size = UDim2.fromOffset(330, height)
	end
end

function UIController:_showResults()
	self:CloseMore()
	self.results.Visible = true
	self:_renderResults()
	self:_responsive()
end

function UIController:_hideResults()
	if self.results and self.results.Visible then
		self.results.Visible = false
		self:_responsive()
	end
end

function UIController:_renderResults()
	local state = self.ctx.State
	local winners = state.winners or {}
	local won = table.find(winners, self.player.UserId) ~= nil
	clear(self.resultsBody)
	self.resultsTitle.Text = state.practice and "PRACTICE DONE" or (won and "YOU DID IT!" or "ROUND OVER")
	self.resultsTitle.TextColor3 = state.practice and C.cyan or (won and C.amber or C.text)
	self.resultsSubtitle.Text = state.practice and "Practice rounds are not saved: no XP, coins, rating or wins."
		or (state.resultText or "The next round starts automatically.")
	local function row(text, props)
		local values = {Size = UDim2.new(1, 0, 0, 20), TextSize = 12, TextColor3 = C.muted, Font = F.medium, ZIndex = 18}
		for key, value in pairs(props or {}) do values[key] = value end
		return label(self.resultsBody, text, values)
	end
	if state.practice then
		local picked = self.pickupCount or 0
		row(picked > 0 and ("🪙 " .. picked .. " practice coins grabbed (not saved)") or "Explore every route, then jump into a real round.")
		row("Your coins and level are unchanged.", {TextSize = 10})
	else
		local reward = self.lastReward
		if reward then
			local card = frame(self.resultsBody, {Name = "RewardBreakdown", Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = C.panel}, 12)
			label(card, "+" .. number(reward.xp) .. " XP    +" .. number(reward.coins) .. " COINS", {Name = "RewardTotal", Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 30), Font = F.title, TextSize = 22, TextColor3 = C.amber, ZIndex = 18})
			local parts = {}
			for _, spec in ipairs({{"🪙", reward.pickups}, {"😮", reward.closeCalls}, {"🎯", reward.tags}, {"🔍", reward.finds}, {"⏱", reward.survived}}) do
				if (spec[2] or 0) > 0 then table.insert(parts, spec[1] .. " " .. number(spec[2])) end
			end
			if reward.rating and reward.rating ~= 0 then table.insert(parts, (reward.rating > 0 and "+" or "") .. number(reward.rating) .. " RATING") end
			label(card, table.concat(parts, "   "), {Position = UDim2.fromOffset(10, 36), Size = UDim2.new(1, -20, 0, 22), TextSize = 11, TextColor3 = C.muted, ZIndex = 18, TextTruncate = Enum.TextTruncate.AtEnd})
		else
			row("Counting your rewards...")
		end
	end
	local medals = {"🥇", "🥈", "🥉"}
	for index, userId in ipairs(winners) do
		if index > 3 then break end
		local name = "Player " .. tostring(userId)
		for _, entry in ipairs(state.players or {}) do if entry.userId == userId then name = entry.displayName or entry.name break end end
		row(medals[index] .. "  " .. name .. (userId == self.player.UserId and "  (YOU)" or ""), {TextColor3 = userId == self.player.UserId and C.amber or C.text, Font = F.bold, TextTruncate = Enum.TextTruncate.AtEnd})
	end
	self:_layoutResults()
end

---------------------------------------------------------------------------------------------------
-- Feedback
---------------------------------------------------------------------------------------------------

function UIController:Toast(text, kind)
	if not self.toast or not text or text == "" then return end
	self.toastSerial += 1
	local serial = self.toastSerial
	self.toastText.Text = tostring(text)
	self.toastStroke.Color = (kind == "purchase" or kind == "level" or kind == "unlock" or kind == "pickup") and C.amber
		or (kind == "found" and C.coral) or C.cyan
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
	self.announcementCopy.Text = practice and "Learn the mall. Practice gives no progression rewards." or (hunter and "The runners get a head start. Search hiding spots, use SCAN (Q), and tag them all." or (role == "Spectator" and "Join the next round automatically. Cycle through the runners below." or "Grab coins, hide in fitting rooms and lockers, and use the escalators to escape."))
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
	task.delay(2, function() if not self.destroyed and self.player.Character == character then self:_loadAvatarBase() end end)
	task.spawn(function()
		character:WaitForChild("Humanoid", 10)
		if self.destroyed or self.player.Character ~= character then return end
		if self.wasSpectating then self:_updateSpectator()
		else self:_restoreCamera() end
	end)
end

function UIController:_updateSpectator()
	local state = self.ctx.State
	local role = myRole(state)
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

function UIController:_updateObjective(state, role)
	local active = self:_inRound()
	self.objective.Visible = active and role ~= "Spectator"
	if not self.objective.Visible then
		self.hideMeter.Visible = false
		return
	end
	local record = myRecord(state)
	local cap = state.pickupCap or (self.ctx.Config.Hide or {}).PickupCap or 25
	self.roleChip.Text = state.practice and "PRACTICE" or string.upper(role)
	self.roleChip.TextColor3 = role == "Hunter" and C.coral or C.cyan
	self.objectiveRight.Text = tostring(state.aliveRunners or 0) .. " RUNNERS LEFT"
	if role == "Hunter" then
		local finds = record and record.finds or 0
		self.objectiveText.Text = "Search (E) · Scan (Q) · Tag" .. (finds > 0 and ("  ·  Found: " .. finds) or "")
	else
		local count = math.max(record and record.pickups or 0, self.pickupCount or 0)
		self.objectiveText.Text = (state.practice and "🪙 Practice coins " or "🪙 Coins ") .. count .. "/" .. cap .. "  ·  Hold E to hide"
	end
	local hiding = self.hideEndsAt ~= nil and role == "Runner"
	self.hideMeter.Visible = hiding
	if hiding then
		local remaining = math.max(0, self.hideEndsAt - workspace:GetServerTimeNow())
		self.hideFill.Size = UDim2.fromScale(math.clamp(remaining / math.max(self.hideDuration, 0.1), 0, 1), 1)
		self.hideFill.BackgroundColor3 = remaining < 2 and C.coral or C.amber
	end
end

function UIController:_tick()
	local state = self.ctx.State
	local now = workspace:GetServerTimeNow()
	local remaining = math.max(0, (state.endsAt or now) - now)
	self.timerLabel.Text = state.phase == "Waiting" and "LOBBY" or clockText(remaining)
	local final = state.phase == "Active" and (state.finalChase or remaining <= 30)
	self.timerLabel.TextColor3 = final and C.coral or C.text
	self.clockStroke.Color = final and C.coral or C.ink
	local durations = {Intermission = self.ctx.Config.Round.Intermission, HeadStart = self.ctx.Config.Round.HeadStart, Active = self.ctx.Config.Round.Duration, Results = self.ctx.Config.Round.ResultsDuration}
	self.roundFill.Size = UDim2.fromScale(state.phase == "Waiting" and 1 or math.clamp(remaining / math.max(durations[state.phase] or 1, 1), 0, 1), 1)
	self.roundFill.BackgroundColor3 = final and C.coral or C.cyan
	if final then self.phaseLabel.Text = state.lastRunner and "LAST RUNNER / FINAL CHASE" or "FINAL CHASE" self.phaseLabel.TextColor3 = C.coral end
	local role = myRole(state)
	local frozen = self.player.Character and self.player.Character:GetAttribute("RoundFrozen") == true
	local gamepad = string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil
	for action, widgets in pairs(self.abilityLabels) do
		local deadline = self.player:GetAttribute("Catch" .. action .. "ReadyAt") or 0
		local cooldown = math.max(0, deadline - now)
		local huntersOnly = action == "Tag" or action == "Scan"
		widgets.box.Visible = not huntersOnly or role == "Hunter"
		local enabled = role ~= "Spectator" and not frozen
		if huntersOnly and state.phase ~= "Active" then enabled = false end
		widgets.status.Text = not enabled and (frozen and "HEAD START" or huntersOnly and "WAIT..." or "SPECTATING") or (cooldown > 0 and string.format("%.1fs", cooldown) or (gamepad and widgets.gamepad or widgets.keyboard))
		widgets.status.TextColor3 = not enabled and C.muted or (cooldown > 0 and C.amber or C.cyan)
		widgets.fill.BackgroundColor3 = not enabled and C.line or (cooldown > 0 and C.amber or C.cyan)
	end
	if self.hideEndsAt and now > self.hideEndsAt + 1 then self.hideEndsAt = nil end
	self:_updateObjective(state, role)
	if self.wasSpectating then self:_updateSpectator() end
	if self.pendingCameraRestore and not self.wasSpectating then self:_restoreCamera() end
end

function UIController:OnState(state)
	if not self.gui then return end
	local phase = state.phase or "Waiting"
	local role = myRole(state)
	local active = phase == "Active" or phase == "HeadStart"
	local labels = {Waiting = "WELCOME TO THE MALL", Intermission = "NEXT CHASE STARTS IN", HeadStart = "RUNNERS GET A HEAD START", Active = "THE CHASE IS ON", Results = "NEXT UP / PODIUM"}
	local modifier = state.modifier
	local special = modifier and modifier.id ~= "classic" and not state.practice
	if special and phase == "Intermission" then labels.Intermission = "NEXT: " .. modifier.name .. " IN"
	elseif special and phase == "Active" then labels.Active = modifier.name end
	self.phaseLabel.Text = state.practice and "PRACTICE / NOTHING IS SAVED" or (labels[phase] or "CATCH ME IF YOU CAN")
	self.phaseLabel.TextColor3 = C.cyan
	self.aliveLabel.Text = active and (tostring(state.aliveRunners or 0) .. " RUNNERS LEFT") or (phase == "Waiting" and "Waiting for the crew" or (state.mapName or "THE MALL"))
	self.emoteButton.Visible = not active
	if active and (self.lastRound ~= state.roundId or self.lastRole ~= role) then
		-- Menus stay open: they never pause the round and never protect the player.
		if self.lastRound ~= state.roundId then
			self.pickupCount, self.hideEndsAt, self.lastReward = 0, nil, nil
		end
		if self.tutorial and self.tutorial.Visible and role ~= "Spectator" then self:_finishTutorial() end
		self.visited = true
		self:_hideResults()
		self:_announce(role, state.practice, state.modifier, self.lastRole)
	end
	if phase == "Results" and self.lastResult ~= state.roundId then
		self.lastResult = state.roundId
		self:_showResults()
	elseif phase ~= "Results" and self.results.Visible then self:_hideResults() end
	if not active then self.hideEndsAt = nil end
	self.lastRound = state.roundId
	self.lastRole = role
	self:_responsive()
	-- The drawer layout and "round keeps going" notes follow the round, so redraw an open menu once.
	if self.menu and self.menuWasInRound ~= active then self:_renderMenu() end
	self.menuWasInRound = active
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
	self.coinsLabel.Text = "🪙 " .. number(profile.coins)
	self.levelLabel.Text = "LEVEL " .. number(profile.level or 1) .. " / " .. string.upper(profile.rank or "ROOKIE")
	local level = profile.level or 1
	local lower = self.ctx.Rules.XPForLevel(level)
	local upper = self.ctx.Rules.XPForLevel(level + 1)
	self.xpFill.Size = UDim2.fromScale(math.clamp(((profile.xp or 0) - lower) / math.max(upper - lower, 1), 0, 1), 1)
	self.loading.Visible = profile.loaded ~= true
	if profile.persistence == "saved" then self.saveLabel.Text = profile.saveMessage or "PROFILE CONNECTED / AUTOSAVE ENABLED"
	elseif profile.persistence == "session" then self.saveLabel.Text = profile.saveMessage or "SESSION PROFILE / PROGRESS IS NOT PERSISTED"
	elseif profile.persistence == "unavailable" then self.saveLabel.Text = profile.saveMessage or "SAVING UNAVAILABLE / THIS SESSION MAY NOT PERSIST" end
	self.saveLabel.TextColor3 = profile.persistence == "saved" and C.muted or C.amber
	self.pendingId = nil
	local login = profile.loginStatus
	local flagged = login ~= nil and login.canClaim == true
	for _, name in ipairs({"Quests", "More"}) do
		local holder = self.dockButtons and self.dockButtons[name]
		local badge = holder and holder:FindFirstChild("Badge")
		if badge then badge.Visible = flagged end
	end
	if profile.loaded and profile.settings and profile.settings.tutorialDone == false and not self.tutorialShown then
		self.tutorialShown = true
		self:ShowTutorial()
	elseif login and login.canClaim and not self.loginHinted and profile.loaded and not (self.tutorial and self.tutorial.Visible) then
		self.loginHinted = true
		self:Toast("Daily reward ready. Open QUESTS to claim it.", "unlock")
	end
	if self.menu then self:_renderMenu() end
end

function UIController:OnNotice(notice)
	if not self.gui or type(notice) ~= "table" then return end
	if notice.text then self:Toast(notice.text, notice.kind) end
	if notice.kind == "menu" then
		-- Hub kiosks: the server only asks; menus open on this client.
		if notice.menu == "Shop" or notice.menu == "Inventory" then self:OpenMenu(notice.menu) end
	elseif notice.kind == "purchase" or notice.kind == "unlock" then
		self.pendingId = nil
		if self.menu == "Shop" or self.menu == "Inventory" then self:_renderMenu() end
	elseif notice.kind == "pickup" then
		self.pickupCount = math.max(self.pickupCount or 0, tonumber(notice.count) or 0)
	elseif notice.kind == "hide" then
		if notice.state == "in" then
			self.hideEndsAt = tonumber(notice.endsAt)
			self.hideDuration = tonumber(notice.duration) or 7
		else
			self.hideEndsAt = nil
			self.hideMeter.Visible = false
		end
	elseif notice.kind == "reward" then
		self.lastReward = notice
		if self.results.Visible then self:_renderResults() end
	end
end

function UIController:Destroy()
	self.destroyed = true
	ContextActionService:UnbindAction("CatchCloseMenu")
	ContextActionService:UnbindAction("CatchOpenMenu")
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	self.player:SetAttribute("CatchMenuOpen", false)
	self:_restoreCamera()
	if self.avatarBase then self.avatarBase:Destroy() self.avatarBase = nil end
	if self.gui then self.gui:Destroy() end
end

return UIController
