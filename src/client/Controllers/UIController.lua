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
	background = Color3.fromRGB(38, 28, 96), panel = Color3.fromRGB(56, 42, 130),
	card = Color3.fromRGB(78, 62, 162), line = Color3.fromRGB(118, 98, 214),
	text = Color3.fromRGB(255, 255, 255), muted = Color3.fromRGB(205, 196, 246),
	cyan = Color3.fromRGB(52, 220, 255), coral = Color3.fromRGB(255, 92, 110),
	amber = Color3.fromRGB(255, 208, 64), green = Color3.fromRGB(86, 232, 142),
	pink = Color3.fromRGB(255, 96, 184), ink = Color3.fromRGB(28, 20, 76),
}
local RARITY = {
	Common = Color3.fromRGB(190, 200, 224), Rare = Color3.fromRGB(70, 168, 255),
	Epic = Color3.fromRGB(190, 106, 255), Legendary = Color3.fromRGB(255, 190, 40),
}
local F = {regular = Enum.Font.Gotham, medium = Enum.Font.GothamMedium, bold = Enum.Font.GothamBold,
	black = Enum.Font.GothamBlack, title = Enum.Font.FredokaOne}
local CATEGORY_ICON = {skins = "👕", masks = "🎭", trails = "✨", victories = "🎉", emotes = "💃", nameplates = "🏷", bundles = "🎁", tones = "🙂", hairColors = "💇"}
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
	self:_buildDock() -- built after the panel so Shop and Locker always stay on top and clickable
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
	self:OnProfile(self.ctx.Profile)
	self:OnState(self.ctx.State)
end

-- Roblox's default chat window and player list sit in corners the HUD uses. On keyboard devices the chat moves
-- to the lower left (clear of the dock and the ability bar) and the player list is hidden, because the CREW menu
-- replaces it. On phones both collapse to topbar icons above the HUD, so they are left alone.
-- TextChat exposes alignment and scale (not Position/Size); the legacy chat gets the SetCore equivalents.
-- Best-effort: a failure here never affects gameplay.
function UIController:_makeRoomForCoreUi()
	local touchOnly = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	if touchOnly then return end
	pcall(function()
		game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
	end)
	local placed = pcall(function()
		local window = game:GetService("TextChatService"):FindFirstChildOfClass("ChatWindowConfiguration")
		assert(window, "no ChatWindowConfiguration")
		window.HorizontalAlignment = Enum.HorizontalAlignment.Left
		window.VerticalAlignment = Enum.VerticalAlignment.Bottom
		window.WidthScale = 0.22
		window.HeightScale = 0.2
	end)
	if not placed then
		pcall(function()
			local starterGui = game:GetService("StarterGui")
			starterGui:SetCore("ChatWindowPosition", UDim2.new(0, 108, 1, -230))
			starterGui:SetCore("ChatWindowSize", UDim2.fromOffset(340, 170))
		end)
	end
end

---------------------------------------------------------------------------------------------------
-- Persistent HUD
---------------------------------------------------------------------------------------------------

function UIController:_buildHeader()
	self.header = frame(self.root, {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 66), BackgroundTransparency = 1})
	self.brand = frame(self.header, {Name = "Brand", Size = UDim2.fromOffset(176, 52), BackgroundColor3 = C.pink}, 14)
	stroke(self.brand, C.ink, 0, 3)
	gradient(self.brand, Color3.fromRGB(255, 130, 200), Color3.fromRGB(235, 60, 150), 90)
	self.brandLabel = label(self.brand, "CATCH ME\nIF YOU CAN!", {Font = F.title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.6})
	self.clock = frame(self.header, {Name = "RoundCard", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(230, 66), BackgroundColor3 = C.background}, 16)
	self.clockStroke = stroke(self.clock, C.ink, 0, 3)
	gradient(self.clock, Color3.fromRGB(74, 56, 170), C.background, 90)
	self.roundTrack = frame(self.clock, {Name = "RoundProgress", Position = UDim2.new(0, 12, 1, -9), Size = UDim2.new(1, -24, 0, 5), BackgroundColor3 = C.ink}, 3)
	self.roundFill = frame(self.roundTrack, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.cyan}, 3)
	self.phaseLabel = label(self.clock, "WELCOME TO THE MALL", {Position = UDim2.fromOffset(5, 5), Size = UDim2.new(1, -10, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 10, TextColor3 = C.cyan})
	self.timerLabel = label(self.clock, "LOBBY", {Position = UDim2.fromOffset(5, 18), Size = UDim2.new(1, -10, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 28, Font = F.title})
	self.aliveLabel = label(self.clock, "Waiting for players", {Position = UDim2.fromOffset(5, 47), Size = UDim2.new(1, -10, 0, 11), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 9, TextColor3 = C.muted})
	self.wallet = frame(self.header, {Name = "Wallet", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(188, 60), BackgroundColor3 = C.background}, 16)
	stroke(self.wallet, C.ink, 0, 3)
	gradient(self.wallet, Color3.fromRGB(74, 56, 170), C.background, 90)
	self.coinsLabel = label(self.wallet, "🪙 0", {Position = UDim2.fromOffset(12, 5), Size = UDim2.new(1, -24, 0, 26), Font = F.title, TextColor3 = C.amber, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Right})
	self.levelLabel = label(self.wallet, "LEVEL 1", {Position = UDim2.fromOffset(12, 33), Size = UDim2.new(1, -24, 0, 12), Font = F.bold, TextColor3 = C.muted, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right})
	local xpTrack = frame(self.wallet, {Position = UDim2.new(0, 12, 1, -11), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = C.ink}, 3)
	self.xpFill = frame(xpTrack, {Name = "XpFill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.green}, 3)
end

local DOCK = {
	{"Shop", "SHOP", "🛒", C.pink},
	{"Inventory", "LOCKER", "👕", C.cyan},
	{"Quests", "QUESTS", "📋", C.amber},
	{"Progress", "CAREER", "🏆", C.green},
	{"Leaderboard", "CREW", "👥", C.card},
	{"Settings", "SETTINGS", "⚙", C.card},
}

-- Shop and Locker are the first two entries and never hide: not in the lobby, the mall,
-- an active round, spectating, or between rounds.
function UIController:_buildDock()
	self.dock = frame(self.root, {Name = "Dock", Position = UDim2.fromOffset(10, 84), Size = UDim2.fromOffset(78, 400), BackgroundTransparency = 1, ZIndex = 12})
	self.dockLayout = list(self.dock, false, 6)
	self.dockButtons = {}
	for index, spec in ipairs(DOCK) do
		self.dockButtons[spec[1]] = self:_dockButton(spec[1], spec[2], spec[3], spec[4], index, function() self:OpenMenu(spec[1]) end)
	end
	self.emoteButton = self:_dockButton("Emote", "EMOTE", "💃", C.card, #DOCK + 1, function()
		local id = (self.ctx.Profile.equipped or {}).emotes
		if id and id ~= "" then self:_send("Emote", {id = id}) end
	end)
end

function UIController:_dockButton(name, text, icon, color, order, callback)
	local object = button(self.dock, "", callback, {Name = name, Size = UDim2.fromOffset(74, 58), LayoutOrder = order, BackgroundColor3 = color, ZIndex = 12})
	self:_dockContent(object, text, icon)
	return object
end

function UIController:_dockContent(object, text, icon)
	label(object, icon, {Name = "Icon", Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, 28), TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13})
	label(object, text, {Name = "Caption", Position = UDim2.new(0, 0, 1, -21), Size = UDim2.new(1, 0, 0, 16), TextSize = 10, Font = F.black, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 13})
	local badge = frame(object, {Name = "Badge", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = C.coral, Visible = false, ZIndex = 14}, 10)
	stroke(badge, C.text, 0, 2)
	label(badge, "!", {TextXAlignment = Enum.TextXAlignment.Center, TextSize = 13, Font = F.black, ZIndex = 15})
end

-- Objective card: what to do right now, coin progress, runners left, hide meter.
function UIController:_buildObjective()
	self.objective = frame(self.root, {Name = "Objective", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.fromOffset(300, 58), BackgroundColor3 = C.background, Visible = false}, 14)
	stroke(self.objective, C.ink, 0, 3)
	gradient(self.objective, Color3.fromRGB(74, 56, 170), C.background, 90)
	self.roleChip = label(self.objective, "RUNNER", {Position = UDim2.fromOffset(12, 5), Size = UDim2.new(0.5, -12, 0, 16), TextSize = 11, TextColor3 = C.cyan, Font = F.black})
	self.objectiveRight = label(self.objective, "", {Position = UDim2.new(0.5, 0, 0, 5), Size = UDim2.new(0.5, -12, 0, 16), TextSize = 11, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right})
	self.objectiveText = label(self.objective, "", {Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -24, 0, 30), TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
	self.hideMeter = frame(self.root, {Name = "HideMeter", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 150), Size = UDim2.fromOffset(300, 84), BackgroundColor3 = C.background, Visible = false}, 14)
	stroke(self.hideMeter, C.amber, 0, 3)
	label(self.hideMeter, "🤫 HIDING... SHHH!", {Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 16), TextSize = 12, TextColor3 = C.amber, Font = F.black})
	local track = frame(self.hideMeter, {Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 8), BackgroundColor3 = C.ink}, 4)
	self.hideFill = frame(track, {Name = "HideFill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.amber}, 4)
	self.leaveButton = button(self.hideMeter, "LEAVE SPOT", function() self:_send("Unhide") end, {Name = "LeaveHiding", Position = UDim2.new(0, 12, 1, -38), Size = UDim2.new(1, -24, 0, 32), TextSize = 12, BackgroundColor3 = C.coral})
end

function UIController:_buildHero()
	self.hero = frame(self.root, {Name = "Welcome", Position = UDim2.new(0, 108, 0.5, -90), Size = UDim2.fromOffset(430, 250), BackgroundColor3 = C.background}, 22)
	stroke(self.hero, C.ink, 0, 4)
	gradient(self.hero, Color3.fromRGB(90, 66, 196), C.background, 110)
	label(self.hero, "THE BIGGEST MALL IN TOWN", {Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 18), TextColor3 = C.cyan, TextSize = 11, Font = F.black})
	self.heroTitle = label(self.hero, "RUN. HIDE.\nESCAPE THE MALL!", {Position = UDim2.fromOffset(20, 38), Size = UDim2.new(1, -40, 0, 90), Font = F.title, TextSize = 34, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextStrokeTransparency = 0.7})
	self.heroDescription = label(self.hero, "Two floors, 24 stores and secret hiding spots. Grab coins, dodge the hunters, and look good doing it.", {Position = UDim2.fromOffset(20, 132), Size = UDim2.new(1, -40, 0, 44), TextColor3 = C.muted, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Font = F.medium})
	button(self.hero, "LET'S GO!", function()
		self.visited = true self.hero.Visible = false
		self:Toast("Explore the mall. You join the next round automatically.", "welcome")
	end, {Name = "EnterMall", Position = UDim2.fromOffset(20, 192), Size = UDim2.fromOffset(190, 46), BackgroundColor3 = C.green, TextColor3 = C.ink, TextSize = 16})
	button(self.hero, "OPEN LOCKER", function() self:OpenMenu("Inventory") end, {Name = "HeroLocker", Position = UDim2.fromOffset(222, 192), Size = UDim2.fromOffset(188, 46), BackgroundColor3 = C.cyan, TextColor3 = C.ink, TextSize = 14})
	self.saveLabel = label(self.root, "CONNECTING TO YOUR PROFILE", {AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -118, 1, -22), Size = UDim2.fromOffset(300, 14), TextColor3 = C.muted, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd})
	self.versionLabel = label(self.root, "BUILD " .. tostring(self.ctx.Config.Version), {Name = "BuildVersion", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 1, -22), Size = UDim2.fromOffset(95, 14), TextColor3 = C.muted, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right})
end

function UIController:_buildAbilities()
	self.abilities = frame(self.root, {Name = "Abilities", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(500, 54), BackgroundTransparency = 1})
	local layout = list(self.abilities, true, 6)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	self.abilityLabels = {}
	local specs = {{"Sprint", "SHIFT", "L3", "👟"}, {"Slide", "C", "B", "🛹"}, {"Vault", "SPACE", "A", "🦘"}, {"Tag", "F", "R2", "🖐"}, {"Scan", "Q", "X", "📡"}}
	for index, spec in ipairs(specs) do
		local clickable = spec[1] == "Scan"
		local box = clickable and button(self.abilities, "", function() self:_send("Scan") end, {Name = "ScanButton", Size = UDim2.fromOffset(96, 52), BackgroundColor3 = C.background, LayoutOrder = index})
			or frame(self.abilities, {Size = UDim2.fromOffset(96, 52), BackgroundColor3 = C.background, LayoutOrder = index}, 12)
		if not clickable then stroke(box, C.ink, 0, 2) end
		label(box, spec[4], {Position = UDim2.fromOffset(8, 5), Size = UDim2.fromOffset(24, 24), TextSize = 18})
		local name = label(box, string.upper(spec[1]), {Position = UDim2.fromOffset(34, 6), Size = UDim2.new(1, -40, 0, 16), Font = F.black, TextSize = 11})
		local status = label(box, spec[2], {Position = UDim2.fromOffset(8, 29), Size = UDim2.new(1, -16, 0, 14), TextColor3 = C.cyan, TextSize = 10})
		local fill = frame(box, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -4), Size = UDim2.new(1, -16, 0, 3), BackgroundColor3 = C.cyan}, 2)
		self.abilityLabels[spec[1]] = {box = box, name = name, status = status, fill = fill, keyboard = spec[2], gamepad = spec[3]}
	end
end

function UIController:_buildSpectator()
	self.spectator = frame(self.root, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(320, 62), BackgroundColor3 = C.background, Visible = false}, 16)
	stroke(self.spectator, C.ink, 0, 3)
	button(self.spectator, "<", function() self.spectateIndex -= 1 self:_updateSpectator() end, {Position = UDim2.fromOffset(8, 11), Size = UDim2.fromOffset(40, 40)})
	button(self.spectator, ">", function() self.spectateIndex += 1 self:_updateSpectator() end, {Position = UDim2.new(1, -48, 0, 11), Size = UDim2.fromOffset(40, 40)})
	label(self.spectator, "SPECTATING", {Position = UDim2.fromOffset(52, 8), Size = UDim2.new(1, -104, 0, 16), TextColor3 = C.cyan, Font = F.black, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center})
	self.spectatorName = label(self.spectator, "Waiting for runners", {Position = UDim2.fromOffset(52, 28), Size = UDim2.new(1, -104, 0, 22), Font = F.bold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd})
end

function UIController:_buildPanel()
	self.panel = frame(self.root, {
		Name = "MenuPanel", Position = UDim2.fromOffset(108, 80), Size = UDim2.new(1, -120, 1, -140), BackgroundColor3 = C.background, Visible = false, ZIndex = 5,
	}, 22)
	node("UISizeConstraint", {MaxSize = Vector2.new(1180, 760), MinSize = Vector2.new(250, 160)}, self.panel)
	stroke(self.panel, C.ink, 0, 4)
	gradient(self.panel, Color3.fromRGB(70, 54, 160), C.background, 110)
	self.panelScale = node("UIScale", {Scale = 1}, self.panel)
	self.panelBanner = frame(self.panel, {Name = "Banner", Size = UDim2.new(1, 0, 0, 66), BackgroundColor3 = C.pink, ZIndex = 5}, 22)
	self.bannerGradient = gradient(self.panelBanner, Color3.fromRGB(255, 130, 200), Color3.fromRGB(150, 80, 255), 0)
	self.panelTitle = label(self.panel, "THE SHOP", {Position = UDim2.fromOffset(20, 8), Size = UDim2.new(1, -90, 0, 30), Font = F.title, TextSize = 26, TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeTransparency = 0.6, ZIndex = 6})
	self.panelSubtitle = label(self.panel, "", {Position = UDim2.fromOffset(20, 38), Size = UDim2.new(1, -90, 0, 20), TextColor3 = Color3.fromRGB(255, 240, 255), TextSize = 11, Font = F.medium, ZIndex = 6})
	button(self.panel, "X", function() self:CloseMenu() end, {Name = "Close", Position = UDim2.new(1, -54, 0, 12), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = C.coral, ZIndex = 7})
	self.panelContent = frame(self.panel, {Position = UDim2.fromOffset(16, 80), Size = UDim2.new(1, -32, 1, -96), BackgroundTransparency = 1, ZIndex = 6})
end

---------------------------------------------------------------------------------------------------
-- Onboarding
---------------------------------------------------------------------------------------------------

function UIController:_buildTutorial()
	self.tutorial = frame(self.root, {Name = "Tutorial", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -40, 0, 320), BackgroundColor3 = C.background, Visible = false, ZIndex = 30}, 22)
	node("UISizeConstraint", {MaxSize = Vector2.new(580, 340), MinSize = Vector2.new(260, 260)}, self.tutorial)
	stroke(self.tutorial, C.cyan, 0, 4)
	gradient(self.tutorial, Color3.fromRGB(90, 66, 196), C.background, 110)
	self.tutorialStep = label(self.tutorial, "", {Position = UDim2.fromOffset(22, 16), Size = UDim2.new(1, -44, 0, 16), TextSize = 11, Font = F.black, TextColor3 = C.cyan, ZIndex = 31})
	self.tutorialTitle = label(self.tutorial, "", {Position = UDim2.fromOffset(22, 38), Size = UDim2.new(1, -44, 0, 40), Font = F.title, TextSize = 26, TextWrapped = true, ZIndex = 31})
	self.tutorialBody = label(self.tutorial, "", {Position = UDim2.fromOffset(22, 88), Size = UDim2.new(1, -44, 1, -166), TextSize = 14, TextColor3 = C.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31, Font = F.medium})
	self.tutorialSkip = button(self.tutorial, "SKIP", function() self:_finishTutorial() end, {Name = "TutorialSkip", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -18), Size = UDim2.fromOffset(90, 42), ZIndex = 31})
	self.tutorialNext = button(self.tutorial, "NEXT", function() self:_tutorialAdvance() end, {Name = "TutorialNext", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -22, 1, -18), Size = UDim2.fromOffset(160, 42), BackgroundColor3 = C.green, TextColor3 = C.ink, ZIndex = 31})
end

function UIController:_tutorialPages()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local pad = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not touch
	local controls = touch and "Use the RUN, SLIDE and TAG buttons. The jump button also vaults low obstacles. Hold the HIDE prompt near a hiding spot."
		or (pad and "Sprint: L3     Slide: B     Jump / vault: A     Tag: R2     Scan: X     Locker: Y")
		or "Sprint: hold Shift     Slide: C while running     Jump / vault: Space     Tag: F     Hide / search: hold E     Scan (hunters): Q"
	return {
		{title = "WELCOME TO THE MALL!", body = "Every round, a few HUNTERS chase the RUNNERS through a two-floor mall. The round starts by itself when enough players are ready."},
		{title = "RUNNERS: STAY FREE", body = "Grab spinning coins, dive into fitting rooms, lockers and stalls to hide for a few seconds, cut through stores, take escalators and jump the balcony gaps. Survive until the timer ends."},
		{title = "HUNTERS: FIND THEM ALL", body = "Runners get a head start. Search hiding spots with E, use SCAN (Q) to spot movement nearby, and tag anyone you catch. Hidden runners cannot be tagged, but searching flushes them out!"},
		{title = "MOVE LIKE A PRO", body = controls .. "\n\nHiding only lasts a few seconds and needs a cooldown. Nobody can sit in a closet forever."},
		{title = "EARN, STYLE, SHOW OFF", body = "Collect coins and win rounds for XP and coins. Unlock skins, masks, trails and titles in the SHOP and wear them from your LOCKER. Everything is cosmetic: nobody can buy an advantage."},
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
	if self.hero then self.hero.Visible = false end
	if (self.ctx.Profile.settings or {}).tutorialDone ~= true then
		self:_send("Settings", {tutorialDone = true})
	end
end

function UIController:_buildToast()
	self.toast = frame(self.root, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.new(0.8, 0, 0, 52), Visible = false, BackgroundColor3 = C.card, ZIndex = 20}, 14)
	node("UISizeConstraint", {MaxSize = Vector2.new(600, 90)}, self.toast)
	self.toastStroke = stroke(self.toast, C.cyan, 0, 3)
	self.toastText = label(self.toast, "", {Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 1, -12), TextSize = 14, Font = F.bold, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 21})
end

function UIController:_buildAnnouncement()
	self.announcement = frame(self.root, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.new(0.85, 0, 0, 144), BackgroundColor3 = C.background, BackgroundTransparency = 0.04, Visible = false, ZIndex = 18}, 22)
	node("UISizeConstraint", {MaxSize = Vector2.new(640, 144)}, self.announcement)
	self.announcementStroke = stroke(self.announcement, C.cyan, 0, 4)
	self.announcementTitle = label(self.announcement, "YOU ARE A RUNNER", {Position = UDim2.fromOffset(12, 20), Size = UDim2.new(1, -24, 0, 50), TextSize = 32, Font = F.title, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true, ZIndex = 19})
	node("UITextSizeConstraint", {MaxTextSize = 34, MinTextSize = 16}, self.announcementTitle)
	self.announcementCopy = label(self.announcement, "", {Position = UDim2.fromOffset(20, 80), Size = UDim2.new(1, -40, 0, 46), TextSize = 14, TextWrapped = true, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center, Font = F.medium, ZIndex = 19})
end

function UIController:_buildLoading()
	self.loading = frame(self.root, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.background, ZIndex = 50})
	gradient(self.loading, Color3.fromRGB(110, 70, 220), Color3.fromRGB(255, 96, 184), 45)
	label(self.loading, "CATCH ME IF YOU CAN", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.new(0.9, 0, 0, 70), Font = F.title, TextSize = 40, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5, ZIndex = 51})
	label(self.loading, "THE MALL", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(0.9, 0, 0, 24), Font = F.black, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.amber, ZIndex = 51})
	self.loadingStatus = label(self.loading, "Opening the mall / loading your profile", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.new(0.85, 0, 0, 44), TextColor3 = Color3.fromRGB(255, 240, 255), TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 51})
	label(self.loading, "TIP: " .. TIPS[math.floor(os.clock() * 7) % #TIPS + 1], {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.new(0.9, 0, 0, 40), TextColor3 = C.text, TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Font = F.medium, ZIndex = 51})
	task.delay(12, function()
		if self.loading and self.loading.Visible then self.loadingStatus.Text = "Your profile is taking longer to load. Reconnecting automatically..." end
	end)
end

---------------------------------------------------------------------------------------------------
-- Layout
---------------------------------------------------------------------------------------------------

function UIController:_responsive()
	local size = self.root.AbsoluteSize
	local small = size.X < 700
	local short = size.Y < 520
	local tiny = size.X < 360
	self.compact = small
	self.short = short
	local compactDock = small or short
	local horizontal = short
	local cell = compactDock and (tiny and 40 or 44) or 74
	self.dockHorizontal = horizontal
	-- Header
	self.brand.Visible = size.X >= 560
	self.brand.Size = UDim2.fromOffset(small and 120 or 176, 52)
	self.brandLabel.TextSize = small and 13 or 20
	self.clock.Position = size.X < 560 and UDim2.fromOffset(size.X < 400 and 60 or 80, 0) or UDim2.fromScale(0.5, 0)
	self.clock.AnchorPoint = size.X < 560 and Vector2.zero or Vector2.new(0.5, 0)
	self.clock.Size = UDim2.fromOffset(size.X < 360 and 124 or (small and 150 or 230), 66)
	self.phaseLabel.TextSize = small and 8 or 10
	self.timerLabel.TextSize = small and 22 or 28
	self.wallet.Size = UDim2.fromOffset(size.X < 360 and 108 or (small and 116 or 188), 60)
	self.coinsLabel.TextSize = small and 15 or 21
	self.levelLabel.TextSize = small and 8 or 10
	-- Dock: Shop and Locker lead, and stay on screen at every size.
	for _, child in ipairs(self.dock:GetChildren()) do
		if child:IsA("GuiButton") then
			child.Size = UDim2.fromOffset(cell, compactDock and cell or 58)
			local caption = child:FindFirstChild("Caption")
			local icon = child:FindFirstChild("Icon")
			if caption then caption.Visible = not compactDock end
			if icon then
				icon.Size = UDim2.new(1, 0, 0, compactDock and cell or 28)
				icon.Position = UDim2.fromOffset(0, compactDock and 0 or 5)
				icon.TextSize = compactDock and 22 or 24
			end
		end
	end
	self.dockLayout.FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical
	self.dockLayout.Padding = UDim.new(0, compactDock and 4 or 6)
	self.dock.Position = horizontal and UDim2.fromOffset(8, 74) or UDim2.fromOffset(compactDock and 6 or 10, 82)
	self.dock.Size = horizontal and UDim2.new(1, -16, 0, cell) or UDim2.fromOffset(cell, math.max(60, size.Y - 100))
	local leftMargin = horizontal and 8 or (cell + 20)
	local top = horizontal and (74 + cell + 6) or 80
	self.leftMargin = leftMargin
	-- Objective
	local objectiveWidth = math.min(300, size.X - leftMargin - 130)
	self.objective.Size = UDim2.fromOffset(math.max(180, objectiveWidth), 62)
	-- Short screens tuck the objective under the dock row instead of beside it, so it never leaves the screen.
	if horizontal then
		self.objective.Size = UDim2.fromOffset(math.max(180, math.min(300, size.X - 16)), 52)
		self.objective.Position = UDim2.fromOffset(8, top)
	elseif small then
		self.objective.Position = UDim2.fromOffset(leftMargin, 78)
	else
		self.objective.Position = UDim2.new(0.5, 0, 0, 82)
	end
	self.objective.AnchorPoint = (small or horizontal) and Vector2.zero or Vector2.new(0.5, 0)
	self.hideMeter.Size = UDim2.fromOffset(math.max(180, math.min(300, size.X - leftMargin - 16)), 84)
	self.hideMeter.AnchorPoint = Vector2.new(0.5, 0)
	self.hideMeter.Position = UDim2.new(0.5, 0, 0, horizontal and 140 or (small and 146 or 150))
	-- Welcome card
	self.hero.Size = UDim2.fromOffset(math.max(220, math.min(size.X - leftMargin - 16, 430)), short and 200 or 250)
	self.hero.Position = short and UDim2.fromOffset(leftMargin, top + 6) or UDim2.new(0, leftMargin, 0.5, -90)
	self.heroTitle.TextSize = small and 26 or 34
	-- Menu panel: leaves the dock visible. During a round it becomes a side drawer so the world stays in view.
	local bottom = (compactDock and 8 or 16)
	local drawer = self:_inRound() and size.X >= 700
	local width = math.min(math.max(250, size.X - leftMargin - 12), drawer and 540 or 1180)
	self.panel.Size = UDim2.new(0, width, 1, -(top + bottom))
	self.panel.Position = UDim2.new(0, drawer and (size.X - width - 12) or leftMargin, 0, top)
	self.panelTitle.TextSize = small and 20 or 26
	self.panelSubtitle.TextSize = small and 9 or 11
	self.panelSubtitle.TextTruncate = Enum.TextTruncate.AtEnd
	self.hero.Visible = not self.visited and not self.menu and (self.ctx.State.phase == "Waiting" or self.ctx.State.phase == "Intermission") and not short
	self.abilities.Visible = not self.menu and UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch and not short
	self.spectator.Size = UDim2.fromOffset(math.min(320, size.X - 36), 62)
	self.spectator.Position = UDim2.new(0.5, 0, 1, UserInputService.TouchEnabled and -32 or -96)
	self.saveLabel.Visible = not short and not small
	self.versionLabel.Visible = not short
	self:_updateSpectator()
end

---------------------------------------------------------------------------------------------------
-- Menus
---------------------------------------------------------------------------------------------------

function UIController:OpenMenu(name)
	if not self.ctx.Profile.loaded then return end
	if self.menu == name then self:CloseMenu() return end
	self.menu = name
	self.player:SetAttribute("CatchMenuOpen", true)
	self.panel.Visible = true
	self.panelScale.Scale = self:_motion() and 0.97 or 1
	self:_tween(self.panelScale, 0.22, {Scale = 1})
	self.hero.Visible = false
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
	local colors = {Shop = C.pink, Inventory = C.cyan, Quests = C.amber, Progress = C.green, Settings = C.card, Leaderboard = C.card, Results = C.amber}
	local banner = colors[self.menu] or C.pink
	self.bannerGradient.Color = ColorSequence.new(shade(banner, 1.12), shade(banner, 0.82))
	if self.menu == "Shop" or self.menu == "Inventory" then self:_renderShop()
	elseif self.menu == "Quests" then self:_renderQuests()
	elseif self.menu == "Progress" then self:_renderProgress()
	elseif self.menu == "Settings" then self:_renderSettings()
	elseif self.menu == "Leaderboard" then self:_renderLeaderboard()
	elseif self.menu == "Results" then self:_renderResults() end
	if self:_inRound() and self.menu ~= "Results" then
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
	local key = item.id .. "|" .. (item.category == "masks" and tostring(equipped.skins) or tostring(equipped.masks))
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
		local ok, built = pcall(self.Appearance.BuildPreview, skin, mask, extra)
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
		if chosen then stroke(card, C.text, 0, 3) end
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
	local success, rig = pcall(self.Appearance.BuildPreview, skin, mask, extra)
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
	self.panelSubtitle.Text = "CATCH ME IF YOU CAN / " .. tostring(self.ctx.Config.Version or "v0.4.0") .. " / Preferences save with your profile."
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

-- Results show exactly what the server granted (arrives as a "reward" notice).
function UIController:_renderResults()
	local state = self.ctx.State
	local winners = state.winners or {}
	local won = table.find(winners, self.player.UserId) ~= nil
	self.panelTitle.Text = state.practice and "ROUTE LEARNED. CHASE NEXT." or (won and "YOU DID IT!" or "ROUND OVER")
	self.panelSubtitle.Text = state.practice and "Solo practice / no coins, XP, rating, or wins awarded" or "The next round starts automatically."
	local container = scroll(self.panelContent)
	list(container, false, 12)
	local headline = card(container, {Name = "WinnerHeadline", Size = UDim2.new(1, -8, 0, 120), LayoutOrder = 0})
	gradient(headline, Color3.fromRGB(110, 76, 210), Color3.fromRGB(52, 38, 120), 20)
	label(headline, state.practice and "PRACTICE" or (won and "VICTORY LAP" or "BETTER LUCK NEXT TIME"), {Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 18), TextSize = 11, Font = F.black, TextColor3 = C.amber, TextXAlignment = Enum.TextXAlignment.Center})
	label(headline, state.resultText or "ROUND COMPLETE", {Position = UDim2.fromOffset(18, 40), Size = UDim2.new(1, -36, 0, 64), TextSize = 30, Font = F.title, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true})
	local reward = self.lastReward
	if reward and not state.practice then
		local rewardCard = card(container, {Name = "RewardBreakdown", Size = UDim2.new(1, -8, 0, 214), LayoutOrder = 1})
		label(rewardCard, "YOUR REWARDS", {Position = UDim2.fromOffset(18, 12), Size = UDim2.new(1, -36, 0, 16), TextSize = 11, Font = F.black, TextColor3 = C.cyan})
		local rows = {
			{"🪙 Mall coins collected", reward.pickups}, {"😮 Close calls", reward.closeCalls},
			{"🎯 Runners tagged", reward.tags}, {"🔍 Hidden runners found", reward.finds}, {"⏱ Seconds survived", reward.survived},
		}
		local y = 34
		for _, row in ipairs(rows) do
			if (row[2] or 0) > 0 then
				label(rewardCard, row[1], {Position = UDim2.fromOffset(18, y), Size = UDim2.new(1, -110, 0, 20), TextSize = 12, TextColor3 = C.muted, Font = F.medium})
				label(rewardCard, number(row[2]), {Position = UDim2.new(1, -90, 0, y), Size = UDim2.fromOffset(72, 20), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right})
				y += 22
			end
		end
		label(rewardCard, "+" .. number(reward.xp) .. " XP    +" .. number(reward.coins) .. " COINS", {Name = "RewardTotal", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, -16), Size = UDim2.new(1, -36, 0, 36), Font = F.title, TextSize = 26, TextColor3 = C.amber})
		if reward.rating and reward.rating ~= 0 then
			label(rewardCard, (reward.rating > 0 and "+" or "") .. number(reward.rating) .. " RATING", {AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -22), Size = UDim2.fromOffset(110, 20), TextSize = 11, Font = F.black, TextColor3 = reward.rating > 0 and C.green or C.coral, TextXAlignment = Enum.TextXAlignment.Right})
		end
	end
	for index, userId in ipairs(winners) do
		local name = "Player " .. tostring(userId)
		for _, entry in ipairs(state.players or {}) do if entry.userId == userId then name = entry.displayName or entry.name break end end
		local row = card(container, {Size = UDim2.new(1, -8, 0, 76), LayoutOrder = 10 + index, BackgroundColor3 = userId == self.player.UserId and C.card or C.panel})
		label(row, string.format("%02d", index), {Position = UDim2.fromOffset(17, 14), Size = UDim2.fromOffset(48, 48), TextColor3 = C.amber, Font = F.title, TextSize = 30})
		label(row, "CHAMPION", {Position = UDim2.fromOffset(78, 12), Size = UDim2.new(1, -96, 0, 16), TextColor3 = C.amber, Font = F.black, TextSize = 10})
		label(row, name .. (userId == self.player.UserId and " / YOU" or ""), {Position = UDim2.fromOffset(78, 34), Size = UDim2.new(1, -96, 0, 27), TextSize = 19, TextTruncate = Enum.TextTruncate.AtEnd})
	end
	local footer = card(container, {Size = UDim2.new(1, -8, 0, 116), LayoutOrder = 100})
	label(footer, "LEVEL " .. number(self.ctx.Profile.level) .. "  /  " .. number(self.ctx.Profile.xp) .. " XP  /  " .. number(self.ctx.Profile.coins) .. " COINS", {Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 30), TextSize = 12, TextColor3 = C.cyan, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center})
	button(footer, "VIEW PODIUM", function() self:CloseMenu() end, {Name = "ViewPodium", Position = UDim2.fromOffset(12, 58), Size = UDim2.new(0.5, -18, 0, 44), BackgroundColor3 = C.green, TextColor3 = C.ink, TextSize = 11})
	button(footer, "MY CAREER", function() self:OpenMenu("Progress") end, {Name = "ViewCareer", Position = UDim2.new(0.5, 6, 0, 58), Size = UDim2.new(0.5, -18, 0, 44), TextSize = 11})
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
		self.objectiveText.Text = "🪙 Coins " .. count .. "/" .. cap .. "  ·  Hold E to hide"
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
	self.phaseLabel.Text = state.practice and "STUDIO / SOLO PRACTICE" or (labels[phase] or "CATCH ME IF YOU CAN")
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
		self:_announce(role, state.practice, state.modifier, self.lastRole)
	end
	if phase == "Results" and self.lastResult ~= state.roundId then
		self.lastResult = state.roundId
		self:OpenMenu("Results")
	elseif self.menu == "Results" and phase ~= "Results" then self:CloseMenu() end
	if not active then self.hideEndsAt = nil end
	self.lastRound = state.roundId
	self.lastRole = role
	self:_responsive()
	-- The drawer layout and "round keeps going" notes follow the round, so redraw an open menu once.
	if self.menu and self.menu ~= "Results" and self.menuWasInRound ~= active then self:_renderMenu() end
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
	local questsButton = self.dock and self.dock:FindFirstChild("Quests")
	local badge = questsButton and questsButton:FindFirstChild("Badge")
	if badge then badge.Visible = login ~= nil and login.canClaim == true end
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
	if notice.kind == "purchase" or notice.kind == "unlock" then
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
		if self.menu == "Results" then self:_renderMenu() end
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
