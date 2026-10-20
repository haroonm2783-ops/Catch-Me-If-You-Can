-- Original NEON HEIGHTS interface. Every persistent action goes through the server.
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
	background = Color3.fromRGB(10, 16, 29), panel = Color3.fromRGB(18, 28, 45),
	card = Color3.fromRGB(26, 39, 58), line = Color3.fromRGB(49, 66, 87),
	text = Color3.fromRGB(237, 246, 255), muted = Color3.fromRGB(150, 172, 194),
	cyan = Color3.fromRGB(68, 230, 231), coral = Color3.fromRGB(255, 112, 118),
	amber = Color3.fromRGB(255, 204, 107), green = Color3.fromRGB(133, 235, 175),
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

local function button(parent, text, callback, props)
	local values = {
		Text = text, Font = F.bold, TextSize = 13, TextColor3 = C.text,
		BackgroundColor3 = C.card, BorderSizePixel = 0, AutoButtonColor = true,
		Selectable = true, Size = UDim2.fromOffset(150, 40),
	}
	for key, value in pairs(props or {}) do values[key] = value end
	local object = node("TextButton", values, parent)
	corner(object, 10)
	stroke(object, values.BackgroundColor3 == C.cyan and C.cyan or C.line, 0.3)
	object.Activated:Connect(callback)
	return object
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

local function myRole(state)
	for _, record in ipairs(state.players or {}) do
		if record.userId == Players.LocalPlayer.UserId then return record.role, record.alive end
	end
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

function UIController:Start()
	if self.started then return end
	self.started = true
	self.Appearance = require(ReplicatedStorage:WaitForChild("CatchShared"):WaitForChild("Appearance"))
	self.gui = node("ScreenGui", {
		Name = "CatchCityUI", ResetOnSpawn = false, IgnoreGuiInset = false,
		DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, self.player:WaitForChild("PlayerGui"))
	self.root = frame(self.gui, {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
	self:_buildHeader()
	self:_buildDock()
	self:_buildHero()
	self:_buildAbilities()
	self:_buildSpectator()
	self.panel = frame(self.root, {
		Name = "MenuPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53),
		Size = UDim2.new(1, -40, 1, -160), BackgroundColor3 = C.background, Visible = false, ZIndex = 5,
	}, 18)
	node("UISizeConstraint", {MaxSize = Vector2.new(1180, 760), MinSize = Vector2.new(270, 160)}, self.panel)
	stroke(self.panel)
	gradient(self.panel, Color3.fromRGB(22, 35, 53), C.background, 110)
	self.panelScale = node("UIScale", {Scale = 1}, self.panel)
	frame(self.panel, {Position = UDim2.fromOffset(20, 0), Size = UDim2.fromOffset(80, 3), BackgroundColor3 = C.cyan}, 2)
	self.panelTitle = label(self.panel, "THE COLLECTION", {Position = UDim2.fromOffset(20, 12), Size = UDim2.new(1, -90, 0, 27), Font = F.black, TextSize = 22, TextTruncate = Enum.TextTruncate.AtEnd})
	self.panelSubtitle = label(self.panel, "", {Position = UDim2.fromOffset(20, 43), Size = UDim2.new(1, -90, 0, 20), TextColor3 = C.muted, TextSize = 11})
	button(self.panel, "X", function() self:CloseMenu() end, {Name = "Close", Position = UDim2.new(1, -56, 0, 16), Size = UDim2.fromOffset(38, 38)})
	self.panelContent = frame(self.panel, {Position = UDim2.fromOffset(16, 78), Size = UDim2.new(1, -32, 1, -94), BackgroundTransparency = 1})
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
	self:_responsive()
	self:OnProfile(self.ctx.Profile)
	self:OnState(self.ctx.State)
end

function UIController:_buildHeader()
	self.header = frame(self.root, {Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -36, 0, 68), BackgroundTransparency = 1})
	self.brand = label(self.header, "CATCH ME\nIF YOU CAN", {Font = F.black, TextSize = 21, TextColor3 = C.text, Size = UDim2.fromOffset(220, 52), TextYAlignment = Enum.TextYAlignment.Top})
	self.brandAccent = frame(self.header, {Position = UDim2.fromOffset(0, 56), Size = UDim2.fromOffset(36, 3), BackgroundColor3 = C.cyan}, 2)
	self.clock = frame(self.header, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(220, 67), BackgroundColor3 = C.background, BackgroundTransparency = 0.08}, 14)
	self.clockStroke = stroke(self.clock)
	gradient(self.clock, Color3.fromRGB(26, 43, 60), C.background)
	self.roundTrack = frame(self.clock, {Name = "RoundProgress", Position = UDim2.new(0, 9, 1, -3), Size = UDim2.new(1, -18, 0, 2), BackgroundColor3 = C.line}, 2)
	self.roundFill = frame(self.roundTrack, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.cyan}, 2)
	self.phaseLabel = label(self.clock, "WELCOME TO NEON HEIGHTS", {Position = UDim2.fromOffset(5, 6), Size = UDim2.new(1, -10, 0, 15), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 9, Font = F.bold, TextColor3 = C.cyan})
	self.timerLabel = label(self.clock, "LOBBY", {Position = UDim2.fromOffset(5, 21), Size = UDim2.new(1, -10, 0, 29), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 27, Font = F.black})
	self.aliveLabel = label(self.clock, "Waiting for players", {Position = UDim2.fromOffset(5, 50), Size = UDim2.new(1, -10, 0, 12), TextXAlignment = Enum.TextXAlignment.Center, TextSize = 9, TextColor3 = C.muted})
	self.wallet = frame(self.header, {AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(180, 60), BackgroundColor3 = C.background, BackgroundTransparency = 0.08}, 12)
	stroke(self.wallet)
	self.coinsLabel = label(self.wallet, "0 COINS", {Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -24, 0, 22), Font = F.bold, TextColor3 = C.amber, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Right})
	self.levelLabel = label(self.wallet, "LEVEL 1 / ROOKIE", {Position = UDim2.fromOffset(10, 35), Size = UDim2.new(1, -20, 0, 13), Font = F.medium, TextColor3 = C.muted, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right})
	self.roleChip = label(self.root, "EXPLORE THE CITY", {Position = UDim2.fromOffset(20, 132), Size = UDim2.fromOffset(260, 22), Font = F.bold, TextSize = 11, TextColor3 = C.cyan})
end

function UIController:_buildDock()
	self.dock = scroll(self.root, {Position = UDim2.fromOffset(18, 88), Size = UDim2.new(1, -36, 0, 36), ScrollBarThickness = 0}, true)
	list(self.dock, true, 7)
	local options = {{"Shop", "SHOP"}, {"Inventory", "LOCKER"}, {"Quests", "QUESTS"}, {"Progress", "CAREER"}, {"Leaderboard", "ROSTER"}, {"Settings", "SETTINGS"}}
	for index, option in ipairs(options) do
		button(self.dock, option[2], function() self:OpenMenu(option[1]) end, {Name = option[1], Size = UDim2.fromOffset(option[1] == "Leaderboard" and 85 or 78, 34), LayoutOrder = index, TextSize = 10})
	end
	self.emoteButton = button(self.dock, "EMOTE", function()
		local id = (self.ctx.Profile.equipped or {}).emotes
		if id and id ~= "" then self:_send("Emote", {id = id}) end
	end, {Size = UDim2.fromOffset(78, 34), LayoutOrder = 7, TextSize = 10})
end

function UIController:_buildHero()
	self.hero = frame(self.root, {Position = UDim2.new(0, 22, 0.5, -78), Size = UDim2.fromOffset(440, 230), BackgroundTransparency = 1})
	label(self.hero, "A CITY MADE FOR THE CHASE", {Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 18), TextColor3 = C.cyan, TextSize = 11, Font = F.bold})
	self.heroTitle = label(self.hero, "RUN THE CITY.\nOWN THE MOMENT.", {Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 97), Font = F.black, TextSize = 35, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
	self.heroDescription = label(self.hero, "Rooftops. Shortcuts. One more escape.\nRounds start automatically when the crew is ready.", {Position = UDim2.fromOffset(0, 132), Size = UDim2.new(1, -10, 0, 42), TextColor3 = C.muted, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
	button(self.hero, "ENTER THE CITY  >", function()
		self.visited = true self.hero.Visible = false
		self:Toast("Explore the lobby. You join the next round automatically.", "welcome")
	end, {Position = UDim2.fromOffset(0, 188), Size = UDim2.fromOffset(225, 42), BackgroundColor3 = C.cyan, TextColor3 = C.background})
	self.saveLabel = label(self.root, "CONNECTING TO YOUR PROFILE", {Position = UDim2.new(0, 20, 1, -25), Size = UDim2.new(1, -125, 0, 15), TextColor3 = C.muted, TextSize = 9, TextTruncate = Enum.TextTruncate.AtEnd})
	self.versionLabel = label(self.root, "BUILD " .. tostring(self.ctx.Config.Version), {Name = "BuildVersion", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 1, -25), Size = UDim2.fromOffset(85, 15), TextColor3 = C.muted, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right})
end

function UIController:_buildAbilities()
	self.abilities = frame(self.root, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -32), Size = UDim2.fromOffset(402, 54), BackgroundTransparency = 1})
	list(self.abilities, true, 6)
	self.abilityLabels = {}
	local specs = {{"Sprint", "SHIFT", "L3"}, {"Slide", "C", "B"}, {"Vault", "SPACE", "A"}, {"Tag", "F", "R2"}}
	for index, spec in ipairs(specs) do
		local box = frame(self.abilities, {Size = UDim2.fromOffset(96, 52), BackgroundColor3 = C.background, BackgroundTransparency = 0.12, LayoutOrder = index}, 9)
		stroke(box, C.line, 0.2)
		local name = label(box, string.upper(spec[1]), {Position = UDim2.fromOffset(8, 7), Size = UDim2.new(1, -16, 0, 16), Font = F.bold, TextSize = 10})
		local status = label(box, spec[2], {Position = UDim2.fromOffset(8, 28), Size = UDim2.new(1, -16, 0, 14), TextColor3 = C.cyan, TextSize = 9})
		local fill = frame(box, {AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -4), Size = UDim2.new(1, -16, 0, 2), BackgroundColor3 = C.cyan}, 2)
		self.abilityLabels[spec[1]] = {box = box, name = name, status = status, fill = fill, keyboard = spec[2], gamepad = spec[3]}
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

-- First-time onboarding. Also reachable from Settings > HOW TO PLAY.
function UIController:_buildTutorial()
	self.tutorial = frame(self.root, {Name = "Tutorial", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -40, 0, 300), BackgroundColor3 = C.background, Visible = false, ZIndex = 30}, 18)
	node("UISizeConstraint", {MaxSize = Vector2.new(560, 330), MinSize = Vector2.new(260, 250)}, self.tutorial)
	stroke(self.tutorial, C.cyan, 0.2)
	gradient(self.tutorial, Color3.fromRGB(24, 40, 58), C.background, 110)
	self.tutorialStep = label(self.tutorial, "", {Position = UDim2.fromOffset(22, 16), Size = UDim2.new(1, -44, 0, 16), TextSize = 10, Font = F.bold, TextColor3 = C.cyan, ZIndex = 31})
	self.tutorialTitle = label(self.tutorial, "", {Position = UDim2.fromOffset(22, 38), Size = UDim2.new(1, -44, 0, 36), Font = F.black, TextSize = 22, TextWrapped = true, ZIndex = 31})
	self.tutorialBody = label(self.tutorial, "", {Position = UDim2.fromOffset(22, 84), Size = UDim2.new(1, -44, 1, -158), TextSize = 14, TextColor3 = C.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 31})
	self.tutorialSkip = button(self.tutorial, "SKIP", function() self:_finishTutorial() end, {Name = "TutorialSkip", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 22, 1, -18), Size = UDim2.fromOffset(90, 40), ZIndex = 31})
	self.tutorialNext = button(self.tutorial, "NEXT", function() self:_tutorialAdvance() end, {Name = "TutorialNext", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -22, 1, -18), Size = UDim2.fromOffset(150, 40), BackgroundColor3 = C.cyan, TextColor3 = C.background, ZIndex = 31})
end

function UIController:_tutorialPages()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local pad = UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled and not touch
	local controls = touch and "Use the RUN, SLIDE and TAG buttons. The jump button also vaults low obstacles when you run at them."
		or (pad and "Sprint: L3     Slide: B     Jump / vault: A     Tag: R2     Locker: Y")
		or "Sprint: hold Shift     Slide: C while running     Jump / vault: Space     Tag: F"
	return {
		{title = "WELCOME TO NEON HEIGHTS", body = "Every round, a few HUNTERS chase the RUNNERS across the rooftops. The round starts by itself when enough players are ready."},
		{title = "RUNNERS: STAY FREE", body = "Take ramps, bridges and ladders. Break line of sight and use the moving gates. Outlast the clock to win."},
		{title = "HUNTERS: TAG THEM ALL", body = "Runners get a head start. Get close and tag them. In some rounds caught runners join the hunt, so watch the banner for the round type."},
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
	self.toast = frame(self.root, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 134), Size = UDim2.new(0.8, 0, 0, 54), Visible = false, BackgroundColor3 = C.card, ZIndex = 20}, 12)
	node("UISizeConstraint", {MaxSize = Vector2.new(600, 90)}, self.toast)
	self.toastStroke = stroke(self.toast, C.cyan)
	self.toastText = label(self.toast, "", {Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 1, -16), TextSize = 13, Font = F.medium, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center})
end

function UIController:_buildAnnouncement()
	self.announcement = frame(self.root, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.new(0.85, 0, 0, 144), BackgroundColor3 = C.background, BackgroundTransparency = 0.05, Visible = false, ZIndex = 18}, 16)
	node("UISizeConstraint", {MaxSize = Vector2.new(640, 144)}, self.announcement)
	self.announcementStroke = stroke(self.announcement, C.cyan)
	self.announcementTitle = label(self.announcement, "YOU ARE A RUNNER", {Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -24, 0, 47), TextSize = 30, Font = F.black, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true})
	node("UITextSizeConstraint", {MaxTextSize = 32, MinTextSize = 16}, self.announcementTitle)
	self.announcementCopy = label(self.announcement, "", {Position = UDim2.fromOffset(20, 83), Size = UDim2.new(1, -40, 0, 37), TextSize = 13, TextWrapped = true, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center})
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
	self.compact = small
	self.brand.TextSize = small and 13 or 21
	self.brand.Size = UDim2.fromOffset(small and 115 or 220, 52)
	self.brand.Visible = size.X >= 390
	self.brandAccent.Visible = self.brand.Visible
	self.clock.Position = size.X < 390 and UDim2.fromOffset(64, 0) or UDim2.fromScale(0.5, 0)
	self.clock.Size = UDim2.fromOffset(small and 128 or 220, 67)
	self.phaseLabel.TextSize = small and 7 or 9
	self.wallet.Size = UDim2.fromOffset(small and 112 or 180, 60)
	self.coinsLabel.TextSize = small and 12 or 17
	self.levelLabel.TextSize = small and 7 or 10
	self.hero.Size = UDim2.fromOffset(math.min(size.X - 44, 440), short and 190 or 230)
	self.hero.Position = short and UDim2.fromOffset(22, 156) or UDim2.new(0, 22, 0.5, -78)
	self.heroTitle.TextSize = small and 26 or 35
	-- Short landscape displays need a usable content viewport below the dock.
	self.panel.Size = UDim2.new(1, -24, 1, short and -136 or -160)
	self.panel.Position = UDim2.new(0.5, 0, 0.5, short and 58 or 60)
	self.panelTitle.TextSize = small and 18 or 22
	self.panelSubtitle.TextSize = small and 10 or 11
	self.panelSubtitle.TextTruncate = Enum.TextTruncate.AtEnd
	self.roleChip.Visible = not short and not self.menu
	self.hero.Visible = not self.visited and not self.menu and (self.ctx.State.phase == "Waiting" or self.ctx.State.phase == "Intermission") and not short
	self.abilities.Visible = not self.menu and UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch and not short
	self.spectator.Size = UDim2.fromOffset(math.min(320, size.X - 36), 62)
	self.spectator.Position = UDim2.new(0.5, 0, 1, UserInputService.TouchEnabled and -32 or -96)
	self.saveLabel.Visible = not short
	self.versionLabel.Visible = not short
	self:_updateSpectator()
end

function UIController:OpenMenu(name)
	if not self.ctx.Profile.loaded then return end
	if self.menu == name then self:CloseMenu() return end
	self.menu = name
	self.player:SetAttribute("CatchMenuOpen", true)
	self.panel.Visible = true
	self.panelScale.Scale = self:_motion() and 0.97 or 1
	self:_tween(self.panelScale, 0.22, {Scale = 1})
	self.hero.Visible = false
	self:_renderMenu()
	self:_responsive()
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
	self.previewModel, self.previewCamera = nil, nil
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
		local names = {rounds = "ROUNDS", wins = "WINS", tags = "TAGS", level = "LEVEL", bestStreak = "WIN STREAK", hunterWins = "HUNTER WINS", survived = "SECONDS SURVIVED"}
		return (names[milestone.stat] or string.upper(tostring(milestone.stat or "milestone"))) .. " " .. number(milestone.value)
	end
	return "FREE"
end

function UIController:_renderShop()
	local inventory = self.menu == "Inventory"
	self.panelTitle.Text = inventory and "THE FIT STUDIO" or "NEON HEIGHTS / COLLECTION"
	self.panelSubtitle.Text = inventory and "Build your signature. Every mask works with every outfit." or "Original citywear. Try on the look. Keep the chase fair."
	local compact = self.panel.AbsoluteSize.X < 760 or self.panelContent.AbsoluteSize.Y < 390
	local portrait = self.panel.AbsoluteSize.X < 540
	local profile = self.ctx.Profile
	local owned = profile.owned or {}
	local equipped = profile.equipped or {}
	local visible = {}
	for _, item in ipairs(self.ctx.Catalog.ForCategory(self.category)) do
		if not inventory or owned[item.id] then visible[#visible + 1] = item end
	end
	local columns = compact and (portrait and 2 or 3) or 2
	local surface = compact and scroll(self.panelContent, {Name = "CompactCollection"}) or self.panelContent
	local detailHeight = portrait and 502 or 286
	local cellHeight = portrait and 142 or 158
	local gridHeight = math.max(cellHeight, math.ceil(#visible / columns) * (cellHeight + 10))
	local detail = frame(surface, {
		Name = "FittingStage",
		Position = UDim2.new(),
		Size = compact and UDim2.new(1, -5, 0, detailHeight) or UDim2.new(0.44, -8, 1, 0),
		BackgroundColor3 = C.panel,
	}, 16)
	stroke(detail, Color3.fromRGB(65, 91, 112), 0.3)
	gradient(detail, Color3.fromRGB(35, 57, 74), Color3.fromRGB(13, 22, 38), 115)
	local collection = frame(surface, {
		Position = compact and UDim2.fromOffset(0, detailHeight + 18) or UDim2.new(0.44, 10, 0, 0),
		Size = compact and UDim2.new(1, -5, 0, gridHeight + 78) or UDim2.new(0.56, -10, 1, 0), BackgroundTransparency = 1,
	})
	label(collection, inventory and "YOUR WARDROBE" or "FIND YOUR NEXT SIGNATURE", {Size = UDim2.new(1, 0, 0, 16), Font = F.bold, TextSize = 10, TextColor3 = C.muted})
	local categories = scroll(collection, {Position = UDim2.fromOffset(0, 25), Size = UDim2.new(1, 0, 0, 42)}, true)
	list(categories, true, 6)
	for index, category in ipairs(self.ctx.Catalog.Categories) do
		button(categories, string.upper(category.label), function()
			self.category = category.id self:_renderMenu()
		end, {Name = "Category_" .. category.id, Size = UDim2.fromOffset(math.max(80, #category.label * 7 + 24), 36), LayoutOrder = index, TextSize = 10,
			BackgroundColor3 = self.category == category.id and C.cyan or C.card,
			TextColor3 = self.category == category.id and C.background or C.muted})
	end
	local gridProps = {Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 1, -76), BackgroundTransparency = 1}
	local grid = compact and frame(collection, gridProps) or scroll(collection, gridProps)
	node("UIGridLayout", {CellPadding = UDim2.fromOffset(10, 10), CellSize = UDim2.new(1 / columns, -6, 0, cellHeight), SortOrder = Enum.SortOrder.LayoutOrder}, grid)
	local selected = self.ctx.Catalog.Get(self.selectedItem)
	local selectionValid = false
	for _, item in ipairs(visible) do if item.id == self.selectedItem then selectionValid = true break end end
	if not selectionValid then selected = visible[1] self.selectedItem = selected and selected.id or nil end
	for index, item in ipairs(visible) do
		local itemColor = accent(item)
		local chosen = self.selectedItem == item.id
		local card = button(grid, "", function() self.selectedItem = item.id self:_renderMenu() end, {Name = "Item_" .. item.id, LayoutOrder = index, BackgroundColor3 = chosen and Color3.fromRGB(31, 58, 72) or C.card})
		frame(card, {Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(30, 4), BackgroundColor3 = itemColor}, 2)
		label(card, string.upper(item.rarity or "Common"), {Position = UDim2.fromOffset(12, 25), Size = UDim2.new(1, -24, 0, 15), TextSize = 9, Font = F.bold, TextColor3 = itemColor})
		label(card, item.name, {Position = UDim2.fromOffset(12, 47), Size = UDim2.new(1, -24, 0, 47), Font = F.bold, TextSize = portrait and 14 or 18, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
		local status = equipped[item.category] == item.id and "EQUIPPED" or (owned[item.id] and "OWNED" or self:_itemPrice(item))
		label(card, status, {Position = UDim2.new(0, 12, 1, -30), Size = UDim2.new(1, -24, 0, 20), Font = F.bold, TextSize = 10, TextColor3 = owned[item.id] and C.cyan or C.amber, TextTruncate = Enum.TextTruncate.AtEnd})
	end
	if #visible == 0 then
		label(collection, "Your signature starts here.\nFind your next favorite in the collection.", {Position = UDim2.fromOffset(12, 86), Size = UDim2.new(1, -24, 0, 80), TextWrapped = true, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center})
		button(collection, "EXPLORE COLLECTION", function() self:OpenMenu("Shop") end, {Name = "ExploreShop", Position = UDim2.fromOffset(12, 176), Size = UDim2.new(1, -24, 0, 42), BackgroundColor3 = C.cyan, TextColor3 = C.background})
	end
	self:_renderItemDetail(detail, selected, compact and not portrait)
end

function UIController:_renderItemDetail(parent, item, horizontal)
	if not item then label(parent, "SELECT YOUR SIGNATURE", {TextColor3 = C.muted, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center}) return end
	local profile = self.ctx.Profile
	local owned = (profile.owned or {})[item.id] == true
	local equipped = profile.equipped or {}
	label(parent, "LIVE FIT / " .. string.upper(item.category), {Position = UDim2.fromOffset(16, 13), Size = UDim2.new(1, -32, 0, 17), Font = F.bold, TextSize = 9, TextColor3 = C.cyan})
	local stage = frame(parent, {Name = "PreviewStage", Position = UDim2.fromOffset(8, 35), Size = horizontal and UDim2.new(0.46, -8, 1, -43) or UDim2.new(1, -16, 1, -249), BackgroundTransparency = 1})
	local plate = frame(stage, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -42), Size = UDim2.new(0.72, 0, 0, 25), BackgroundColor3 = accent(item), BackgroundTransparency = 0.83}, 100)
	stroke(plate, accent(item), 0.5)
	local view = node("ViewportFrame", {
		Name = "CharacterPreview", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -36),
		Ambient = Color3.fromRGB(190, 207, 230), LightColor = Color3.fromRGB(255, 240, 219), LightDirection = Vector3.new(-1, -0.6, -1),
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
	button(controls, "FRONT VIEW", function() self.previewAngle, self.previewTime = 0, 0 end, {Name = "PreviewFront", Position = UDim2.fromOffset(46, 0), Size = UDim2.fromOffset(92, 32), TextSize = 9})
	button(controls, ">", function() self.previewAngle += math.pi / 4 end, {Name = "PreviewRight", Position = UDim2.fromOffset(144, 0), Size = UDim2.fromOffset(40, 32), TextSize = 16})
	local info = frame(parent, {Name = "ItemInformation", Position = horizontal and UDim2.new(0.46, 8, 0, 42) or UDim2.new(0, 18, 1, -196), Size = horizontal and UDim2.new(0.54, -26, 1, -60) or UDim2.new(1, -36, 0, 178), BackgroundTransparency = 1})
	label(info, string.upper(item.rarity or "COMMON"), {Size = UDim2.new(1, 0, 0, 15), TextSize = 9, Font = F.bold, TextColor3 = accent(item)})
	label(info, item.name, {Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 45), TextSize = 23, Font = F.black, TextWrapped = true})
	label(info, item.description or "", {Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 50), TextSize = 11, TextColor3 = C.muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
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
	end, {Name = "ItemAction", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 42), TextSize = 11, BackgroundColor3 = canAct and C.cyan or C.card, TextColor3 = canAct and C.background or C.muted})
end

function UIController:_renderQuests()
	self.panelTitle.Text = "DAILY DISPATCH"
	self.panelSubtitle.Text = "Three reasons for one more chase / refreshes at 00:00 UTC"
	local container = scroll(self.panelContent)
	list(container, false, 12)
	local quests = self.ctx.Profile.quests or {}
	local narrow = self.panelContent.AbsoluteSize.X < 520
	local login = self.ctx.Profile.loginStatus
	if login then
		local done = login.canClaim and (login.day - 1) or login.day
		local card = frame(container, {Name = "DailyLogin", Size = UDim2.new(1, -5, 0, narrow and 176 or 132), LayoutOrder = 0}, 14)
		stroke(card, login.canClaim and C.amber or C.line, 0.6)
		label(card, "DAILY LOGIN  /  DAY " .. number(login.day) .. " OF 7", {Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 15), TextSize = 9, TextColor3 = login.canClaim and C.amber or C.muted, Font = F.bold})
		label(card, login.canClaim and ("Today: +" .. number(login.coins) .. " COINS  /  +" .. number(login.xp) .. " XP")
			or ("Claimed. Return tomorrow to extend your " .. number(login.streak) .. "-day streak."), {Position = UDim2.fromOffset(18, 36), Size = UDim2.new(1, narrow and -36 or -168, 0, 40), TextSize = 16, Font = F.bold, TextWrapped = true})
		for day = 1, 7 do
			frame(card, {Name = "LoginDay" .. day, Position = UDim2.fromOffset(18 + (day - 1) * 34, 88), Size = UDim2.fromOffset(28, 10), BackgroundColor3 = day <= done and C.amber or C.line}, 3)
		end
		button(card, login.canClaim and "CLAIM" or "CLAIMED", function()
			if login.canClaim then self:_send("ClaimLogin") end
		end, {Name = "ClaimLogin", Position = UDim2.new(1, -142, 0, narrow and 128 or 36), Size = UDim2.fromOffset(124, 36), TextSize = 10, BackgroundColor3 = login.canClaim and C.amber or C.card, TextColor3 = login.canClaim and C.background or C.muted})
	end
	for index, quest in ipairs(quests) do
		local card = frame(container, {Name = "Dispatch_" .. quest.id, Size = UDim2.new(1, -5, 0, narrow and 182 or 140), LayoutOrder = index}, 14)
		stroke(card, quest.claimed and C.line or C.cyan, 0.75)
		local ratio = math.clamp((quest.progress or 0) / math.max(quest.goal or 1, 1), 0, 1)
		label(card, string.format("%02d / DAILY CHALLENGE", index), {Position = UDim2.fromOffset(18, 14), Size = UDim2.new(1, -36, 0, 15), TextSize = 9, TextColor3 = quest.claimed and C.muted or C.cyan, Font = F.bold})
		label(card, quest.text, {Position = UDim2.fromOffset(18, 39), Size = UDim2.new(1, narrow and -36 or -168, 0, 40), TextSize = 17, Font = F.bold, TextWrapped = true})
		label(card, "+" .. number(quest.xp) .. " XP  /  +" .. number(quest.coins) .. " COINS", {Position = UDim2.fromOffset(18, 85), Size = UDim2.new(1, -36, 0, 17), TextSize = 11, Font = F.bold, TextColor3 = C.amber})
		local track = frame(card, {Position = UDim2.fromOffset(18, 114), Size = UDim2.new(1, -36, 0, 5), BackgroundColor3 = C.line}, 3)
		frame(track, {Size = UDim2.fromScale(ratio, 1), BackgroundColor3 = quest.claimed and C.muted or C.cyan}, 3)
		if narrow then
			label(card, number(math.min(quest.progress or 0, quest.goal or 0)) .. " / " .. number(quest.goal), {Position = UDim2.fromOffset(18, 132), Size = UDim2.new(1, -155, 0, 31), Font = F.bold, TextSize = 12, TextColor3 = C.muted})
		end
		button(card, quest.claimed and "CLAIMED" or (ratio >= 1 and "CLAIM REWARD" or (number(math.min(quest.progress or 0, quest.goal or 0)) .. " / " .. number(quest.goal))), function()
			if ratio >= 1 and not quest.claimed then self:_send("ClaimQuest", {id = quest.id}) end
		end, {Name = "Quest_" .. quest.id, Position = UDim2.new(1, -142, 0, narrow and 132 or 41), Size = UDim2.fromOffset(124, 36), TextSize = 10, BackgroundColor3 = ratio >= 1 and not quest.claimed and C.cyan or C.card, TextColor3 = ratio >= 1 and not quest.claimed and C.background or C.muted})
	end
	if #quests == 0 then label(container, "Your daily dispatch is loading.", {Size = UDim2.new(1, 0, 0, 50), TextColor3 = C.muted}) end
end

function UIController:_renderProgress()
	local profile = self.ctx.Profile
	self.panelTitle.Text = "YOUR CITY STORY"
	self.panelSubtitle.Text = "Every chase counts. Studio solo practice gives no rewards."
	local container = scroll(self.panelContent)
	list(container, false, 12)
	local rank = frame(container, {Size = UDim2.new(1, -5, 0, 145), LayoutOrder = 1}, 12)
	label(rank, string.upper(profile.rank or "ROOKIE") .. "  /  " .. number(profile.rating) .. " RATING", {Position = UDim2.fromOffset(18, 15), Size = UDim2.new(1, -36, 0, 20), Font = F.bold, TextColor3 = C.amber, TextSize = 13})
	label(rank, "LEVEL " .. number(profile.level), {Position = UDim2.fromOffset(18, 42), Size = UDim2.new(1, -36, 0, 35), Font = F.black, TextSize = 28})
	local level = profile.level or 1
	local lower = self.ctx.Rules.XPForLevel(level)
	local upper = self.ctx.Rules.XPForLevel(level + 1)
	local ratio = math.clamp(((profile.xp or 0) - lower) / math.max(upper - lower, 1), 0, 1)
	label(rank, number(profile.xp) .. " XP  /  " .. number(upper) .. " XP NEXT LEVEL", {Position = UDim2.fromOffset(18, 88), Size = UDim2.new(1, -36, 0, 17), TextColor3 = C.muted, TextSize = 10})
	local track = frame(rank, {Position = UDim2.fromOffset(18, 117), Size = UDim2.new(1, -36, 0, 7), BackgroundColor3 = C.line}, 4)
	frame(track, {Size = UDim2.fromScale(ratio, 1), BackgroundColor3 = C.cyan}, 4)
	local stats = profile.stats or {}
	local specs = {{"ROUNDS PLAYED", stats.rounds}, {"TOTAL WINS", stats.wins}, {"SUCCESSFUL TAGS", stats.tags}, {"HUNTER WINS", stats.hunterWins}, {"RUNNER WINS", stats.runnerWins}, {"BEST WIN STREAK", profile.bestStreak}, {"SECONDS SURVIVED", stats.survived}}
	for index, spec in ipairs(specs) do
		local row = frame(container, {Size = UDim2.new(1, -5, 0, 48), LayoutOrder = index + 1}, 9)
		label(row, spec[1], {Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -100, 1, 0), Font = F.medium, TextColor3 = C.muted, TextSize = 11})
		label(row, number(spec[2]), {Position = UDim2.new(1, -90, 0, 0), Size = UDim2.fromOffset(72, 48), Font = F.bold, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right})
	end
	for index, achievement in ipairs(self.ctx.Achievements.List) do
		local unlocked = (profile.achievements or {})[achievement.id] == true
		local current = (profile.stats or {})[achievement.stat] or profile[achievement.stat] or 0
		local row = frame(container, {Size = UDim2.new(1, -5, 0, 66), LayoutOrder = 20 + index}, 9)
		label(row, (unlocked and "UNLOCKED  /  " or "LOCKED  /  ") .. achievement.name, {Position = UDim2.fromOffset(16, 9), Size = UDim2.new(1, -120, 0, 21), TextSize = 11, Font = F.bold, TextColor3 = unlocked and C.amber or C.muted, TextTruncate = Enum.TextTruncate.AtEnd})
		label(row, "+" .. number(achievement.coins) .. " COINS", {Position = UDim2.new(1, -104, 0, 9), Size = UDim2.fromOffset(90, 21), TextSize = 10, Font = F.bold, TextColor3 = unlocked and C.muted or C.amber, TextXAlignment = Enum.TextXAlignment.Right})
		label(row, achievement.text .. (unlocked and "" or ("   " .. number(math.min(current, achievement.goal)) .. " / " .. number(achievement.goal))), {Position = UDim2.fromOffset(16, 36), Size = UDim2.new(1, -32, 0, 17), TextSize = 11, TextColor3 = C.muted, TextTruncate = Enum.TextTruncate.AtEnd})
	end
end

function UIController:_renderSettings()
	self.panelTitle.Text = "MAKE IT YOURS"
	self.panelSubtitle.Text = "NEON HEIGHTS / " .. tostring(self.ctx.Config.Version or "v0.2.0") .. " / Preferences save with your profile."
	local container = scroll(self.panelContent)
	list(container, false, 10)
	local settings = self.ctx.Profile.settings or {}
	local specs = {
		{"music", "MUSIC", "Background soundtrack when audio is configured."},
		{"sfx", "SOUND EFFECTS", "Chase, movement, and celebration sounds."},
		{"reducedMotion", "REDUCED MOTION", "Calmer transitions, a still preview, less camera motion."},
		{"cameraShake", "CAMERA FEEDBACK", "Small camera reactions to actions and nearby tags."},
	}
	for index, spec in ipairs(specs) do
		local row = frame(container, {Size = UDim2.new(1, -5, 0, 83), LayoutOrder = index}, 10)
		label(row, spec[2], {Position = UDim2.fromOffset(16, 13), Size = UDim2.new(1, -120, 0, 22), TextSize = 13, Font = F.bold})
		label(row, spec[3], {Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -120, 0, 32), TextSize = 10, TextColor3 = C.muted, TextWrapped = true})
		local enabled = settings[spec[1]] == true
		button(row, enabled and "ON" or "OFF", function() self:_send("Settings", {[spec[1]] = not enabled}) end, {Name = "Setting_" .. spec[1], Position = UDim2.new(1, -92, 0, 23), Size = UDim2.fromOffset(74, 36), BackgroundColor3 = enabled and C.cyan or C.card, TextColor3 = enabled and C.background or C.muted})
	end
	local instructions = frame(container, {Size = UDim2.new(1, -5, 0, 152), LayoutOrder = 10}, 10)
	button(container, "HOW TO PLAY", function() self:ShowTutorial() end, {Name = "HowToPlay", Size = UDim2.new(1, -5, 0, 42), LayoutOrder = 11, TextSize = 11})
	label(instructions, "KNOW YOUR ROUTE", {Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 22), Font = F.bold, TextColor3 = C.cyan, TextSize = 12})
	label(instructions, "Sprint  Shift / L3     Slide  C / B\nJump + vault  Space / A     Tag  F / R2\nTouch: use the on-screen controls.\nGamepad: Y opens your locker. A selects; B closes.\nRunners escape until time runs out. Hunters tag every runner.", {Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 100), TextColor3 = C.muted, TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
end

function UIController:_renderLeaderboard()
	self.panelTitle.Text = "THE CITY CREW"
	self.panelSubtitle.Text = "Current server / lifetime rating, wins, and tags"
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
		local row = frame(container, {Size = UDim2.new(1, -5, 0, 72), LayoutOrder = index, BackgroundColor3 = player == self.player and Color3.fromRGB(27, 57, 69) or C.panel}, 10)
		label(row, string.format("%02d", index), {Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(33, 25), TextColor3 = index == 1 and C.amber or C.muted, Font = F.black, TextSize = 20})
		label(row, player.DisplayName .. (player == self.player and "  (YOU)" or ""), {Position = UDim2.fromOffset(54, 10), Size = UDim2.new(1, -68, 0, 23), TextSize = 14, Font = F.bold, TextTruncate = Enum.TextTruncate.AtEnd})
		label(row, string.upper(role) .. "  /  LV " .. number(stat(player, "Level")) .. "  /  " .. number(stat(player, "Rating")) .. " RATING  /  " .. number(stat(player, "Wins")) .. " WINS  /  " .. number(stat(player, "Tags")) .. " TAGS", {Position = UDim2.fromOffset(54, 39), Size = UDim2.new(1, -68, 0, 24), TextColor3 = C.muted, TextSize = self.compact and 8 or 10, TextWrapped = true})
	end
end

function UIController:_renderResults()
	local state = self.ctx.State
	local winners = state.winners or {}
	local won = table.find(winners, self.player.UserId) ~= nil
	self.panelTitle.Text = state.practice and "ROUTE LEARNED. CHASE NEXT." or (won and "YOUR CITY. YOUR MOMENT." or "THE CHASE IS OVER")
	self.panelSubtitle.Text = state.practice and "Solo practice / no coins, XP, rating, or wins awarded" or "Celebrate the escape. The next chase starts automatically."
	local container = scroll(self.panelContent)
	list(container, false, 12)
	local headline = frame(container, {Name = "WinnerHeadline", Size = UDim2.new(1, -5, 0, 132), LayoutOrder = 0}, 16)
	gradient(headline, Color3.fromRGB(65, 48, 35), Color3.fromRGB(24, 32, 48), 20)
	stroke(headline, C.amber, 0.4)
	label(headline, state.practice and "NEON HEIGHTS / PRACTICE" or "NEON HEIGHTS / VICTORY LAP", {Position = UDim2.fromOffset(18, 16), Size = UDim2.new(1, -36, 0, 18), TextSize = 10, Font = F.bold, TextColor3 = C.amber, TextXAlignment = Enum.TextXAlignment.Center})
	label(headline, state.resultText or "ROUND COMPLETE", {Position = UDim2.fromOffset(18, 47), Size = UDim2.new(1, -36, 0, 60), TextSize = 30, Font = F.black, TextColor3 = C.text, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true})
	for index, userId in ipairs(winners) do
		local name = "Player " .. tostring(userId)
		for _, entry in ipairs(state.players or {}) do if entry.userId == userId then name = entry.displayName or entry.name break end end
		local card = frame(container, {Size = UDim2.new(1, -5, 0, 86), LayoutOrder = index, BackgroundColor3 = userId == self.player.UserId and Color3.fromRGB(42, 53, 56) or C.panel}, 12)
		label(card, string.format("%02d", index), {Position = UDim2.fromOffset(17, 18), Size = UDim2.fromOffset(48, 50), TextColor3 = C.amber, Font = F.black, TextSize = 32})
		label(card, "CHASE CHAMPION", {Position = UDim2.fromOffset(78, 16), Size = UDim2.new(1, -96, 0, 16), TextColor3 = C.amber, Font = F.bold, TextSize = 9})
		label(card, name .. (userId == self.player.UserId and " / YOU" or ""), {Position = UDim2.fromOffset(78, 40), Size = UDim2.new(1, -96, 0, 27), Font = F.bold, TextSize = 20, TextTruncate = Enum.TextTruncate.AtEnd})
	end
	local footer = frame(container, {Size = UDim2.new(1, -5, 0, 116), LayoutOrder = 100}, 12)
	label(footer, "LEVEL " .. number(self.ctx.Profile.level) .. "  /  " .. number(self.ctx.Profile.xp) .. " XP  /  " .. number(self.ctx.Profile.coins) .. " COINS", {Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -32, 0, 30), Font = F.bold, TextSize = 11, TextColor3 = C.cyan, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center})
	button(footer, "VIEW PODIUM", function() self:CloseMenu() end, {Name = "ViewPodium", Position = UDim2.fromOffset(12, 58), Size = UDim2.new(0.5, -18, 0, 42), BackgroundColor3 = C.cyan, TextColor3 = C.background, TextSize = 10})
	button(footer, "YOUR CAREER", function() self:OpenMenu("Progress") end, {Name = "ViewCareer", Position = UDim2.new(0.5, 6, 0, 58), Size = UDim2.new(0.5, -18, 0, 42), TextSize = 10})
end

function UIController:Toast(text, kind)
	if not self.toast or not text or text == "" then return end
	self.toastSerial += 1
	local serial = self.toastSerial
	self.toastText.Text = tostring(text)
	self.toastStroke.Color = (kind == "purchase" or kind == "level" or kind == "unlock") and C.amber or C.cyan
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
	local role = myRole(state)
	for action, widgets in pairs(self.abilityLabels) do
		local deadline = self.player:GetAttribute("Catch" .. action .. "ReadyAt") or 0
		local cooldown = math.max(0, deadline - now)
		local frozen = self.player.Character and self.player.Character:GetAttribute("RoundFrozen") == true
		local enabled = role ~= "Spectator" and not frozen
		if action == "Tag" and (role ~= "Hunter" or state.phase ~= "Active") then enabled = false end
		local gamepad = string.find(UserInputService:GetLastInputType().Name, "Gamepad") ~= nil
		widgets.status.Text = not enabled and (frozen and "HEAD START" or action == "Tag" and "HUNTERS ONLY" or "SPECTATING") or (cooldown > 0 and string.format("%.1fs", cooldown) or (gamepad and widgets.gamepad or widgets.keyboard))
		widgets.status.TextColor3 = not enabled and C.muted or (cooldown > 0 and C.amber or C.cyan)
		widgets.fill.BackgroundColor3 = not enabled and C.line or (cooldown > 0 and C.amber or C.cyan)
	end
	if self.wasSpectating then self:_updateSpectator() end
	if self.pendingCameraRestore and not self.wasSpectating then self:_restoreCamera() end
end

function UIController:OnState(state)
	if not self.gui then return end
	local phase = state.phase or "Waiting"
	local role = myRole(state)
	local active = phase == "Active" or phase == "HeadStart"
	local labels = {Waiting = "WELCOME TO NEON HEIGHTS", Intermission = "NEXT CHASE STARTS IN", HeadStart = "RUNNERS GET A HEAD START", Active = "THE CHASE IS ON", Results = "NEXT UP / CITY PODIUM"}
	local modifier = state.modifier
	local special = modifier and modifier.id ~= "classic" and not state.practice
	if special and phase == "Intermission" then labels.Intermission = "NEXT: " .. modifier.name .. " IN"
	elseif special and phase == "Active" then labels.Active = modifier.name end
	self.phaseLabel.Text = state.practice and "STUDIO / SOLO PRACTICE" or (labels[phase] or "NEON HEIGHTS")
	self.phaseLabel.TextColor3 = C.cyan
	self.aliveLabel.Text = active and (tostring(state.aliveRunners or 0) .. " RUNNERS LEFT") or (phase == "Waiting" and "Waiting for the crew" or (state.mapName or "NEON HEIGHTS"))
	self.roleChip.Text = state.practice and "PRACTICE / NO PROGRESSION REWARDS" or (active and string.upper(role) .. " / " .. (role == "Hunter" and "TAG EVERY RUNNER" or role == "Runner" and "SURVIVE THE CHASE" or "NEXT ROUND IS YOURS") or "EXPLORE THE CITY")
	self.roleChip.TextColor3 = role == "Hunter" and C.coral or C.cyan
	self.emoteButton.Visible = not active
	if active and (self.lastRound ~= state.roundId or self.lastRole ~= role) then
		self:CloseMenu()
		if self.tutorial and self.tutorial.Visible and role ~= "Spectator" then self:_finishTutorial() end
		self.visited = true
		self:_announce(role, state.practice, state.modifier, self.lastRole)
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
	self.coinsLabel.Text = number(profile.coins) .. " COINS"
	self.levelLabel.Text = "LEVEL " .. number(profile.level or 1) .. " / " .. string.upper(profile.rank or "ROOKIE")
	self.loading.Visible = profile.loaded ~= true
	if profile.persistence == "saved" then self.saveLabel.Text = profile.saveMessage or "PROFILE CONNECTED / AUTOSAVE ENABLED"
	elseif profile.persistence == "session" then self.saveLabel.Text = profile.saveMessage or "SESSION PROFILE / PROGRESS IS NOT PERSISTED"
	elseif profile.persistence == "unavailable" then self.saveLabel.Text = profile.saveMessage or "SAVING UNAVAILABLE / THIS SESSION MAY NOT PERSIST" end
	self.saveLabel.TextColor3 = profile.persistence == "saved" and C.muted or C.amber
	self.pendingId = nil
	local login = profile.loginStatus
	local questsButton = self.dock and self.dock:FindFirstChild("Quests")
	if questsButton then questsButton.Text = (login and login.canClaim) and "QUESTS  !" or "QUESTS" end
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
