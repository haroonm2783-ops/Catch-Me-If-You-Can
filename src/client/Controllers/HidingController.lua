-- Client presentation for hiding, searching and mall coins. All rules live on the server:
-- this only relabels prompts by role, spins coins, and shows scan / reveal highlights.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local HidingController = {}
HidingController.__index = HidingController

local MAP_NAME = "CatchMall"
local SPIN_RANGE = 140
local CORAL = Color3.fromRGB(255, 92, 110)
local CYAN = Color3.fromRGB(52, 220, 255)

function HidingController.new(ctx)
	return setmetatable({
		ctx = ctx, player = Players.LocalPlayer, connections = {}, spots = {}, coins = {},
		highlights = {}, markers = {}, role = "Lobby", phase = "Waiting", spin = 0, labelClock = 0,
	}, HidingController)
end

function HidingController:_collect(model)
	if self.model == model then return end
	self.model = model
	table.clear(self.spots)
	table.clear(self.coins)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Model") and descendant:GetAttribute("CatchHideSpot") then
			local prompt = descendant:FindFirstChild("HidePrompt", true)
			if prompt and prompt:IsA("ProximityPrompt") then
				table.insert(self.spots, {model = descendant, prompt = prompt})
			end
		end
	end
	local folder = model:FindFirstChild("MallCoins")
	if folder then
		for _, coin in ipairs(folder:GetChildren()) do
			if coin:IsA("BasePart") then
				local inner = coin:FindFirstChild("CoinInner")
				table.insert(self.coins, {part = coin, inner = inner, base = coin.CFrame, hidden = false, phase = #self.coins * 0.7})
			end
		end
	end
	self:_refreshPrompts()
end

-- Prompts are relabelled by role; ProximityPrompt changes made on the client stay local.
function HidingController:_refreshPrompts()
	local live = self.phase == "Active"
	local role = self.role
	for _, spot in ipairs(self.spots) do
		local prompt = spot.prompt
		if prompt.Parent then
			local mine = spot.model:GetAttribute("OccupantUserId") == self.player.UserId
			local occupied = spot.model:GetAttribute("Occupied") == true
			if role == "Hunter" then
				prompt.ActionText = "Search"
				prompt.Enabled = live
			elseif role == "Runner" then
				prompt.ActionText = mine and "Leave" or (occupied and "Taken" or "Hide")
				prompt.Enabled = live and (mine or not occupied)
			else
				prompt.Enabled = false
			end
		end
	end
end

function HidingController:_highlight(character, color, duration)
	if not character or not character.Parent then return end
	local existing = self.highlights[character]
	if existing then existing:Destroy() end
	local highlight = Instance.new("Highlight")
	highlight.Name = "CatchReveal"
	highlight.FillColor = color
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.45
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = character
	self.highlights[character] = highlight
	Debris:AddItem(highlight, duration)
	task.delay(duration, function()
		if self.highlights[character] == highlight then self.highlights[character] = nil end
	end)
end

-- Occupied cells are shown as an anonymous "?" so the scan finds spots, not names.
function HidingController:_marker(position, duration)
	if typeof(position) ~= "Vector3" then return end
	local anchor = Instance.new("Part")
	anchor.Name = "CatchScanMarker"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.Position = position
	anchor.Parent = workspace
	local board = Instance.new("BillboardGui")
	board.Size = UDim2.fromOffset(46, 46)
	board.AlwaysOnTop = true
	board.MaxDistance = 90
	board.Adornee = anchor
	board.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = CYAN
	label.Text = "?"
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 30
	label.TextColor3 = Color3.fromRGB(28, 20, 76)
	label.Parent = board
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = label
	Debris:AddItem(anchor, duration)
	table.insert(self.markers, anchor)
end

function HidingController:OnState(state)
	self.phase = state.phase or "Waiting"
	self.role = "Lobby"
	for _, record in ipairs(state.players or {}) do
		if record.userId == self.player.UserId then self.role = record.role break end
	end
	if self.phase == "Waiting" or self.phase == "Intermission" then
		-- New round: every coin is back.
		for _, coin in ipairs(self.coins) do coin.hidden = false end
	end
	self:_refreshPrompts()
end

function HidingController:OnNotice(notice)
	if notice.kind == "scan" then
		local duration = tonumber(notice.duration) or 2.2
		for _, userId in ipairs(notice.targets or {}) do
			local target = Players:GetPlayerByUserId(userId)
			if target then self:_highlight(target.Character, CYAN, duration) end
		end
		for _, position in ipairs(notice.spots or {}) do self:_marker(position, duration) end
	elseif notice.kind == "reveal" then
		local target = Players:GetPlayerByUserId(notice.userId)
		if target then self:_highlight(target.Character, CORAL, tonumber(notice.duration) or 2.5) end
	end
end

function HidingController:_update(dt)
	self.spin += dt
	self.labelClock += dt
	if self.labelClock >= 0.4 then
		self.labelClock = 0
		self:_refreshPrompts()
	end
	local camera = workspace.CurrentCamera
	local origin = camera and camera.CFrame.Position
	local reduced = (self.ctx.Profile.settings or {}).reducedMotion == true
	for _, coin in ipairs(self.coins) do
		local part = coin.part
		if part.Parent then
			local gone = part:GetAttribute("Collected") == true
			if gone ~= coin.hidden then
				coin.hidden = gone
				part.Transparency = gone and 1 or 0
				if coin.inner then coin.inner.Transparency = gone and 1 or 0 end
			end
			if not gone and origin and (coin.base.Position - origin).Magnitude < SPIN_RANGE then
				local bob = reduced and 0 or math.sin(self.spin * 2.2 + coin.phase) * 0.35
				local turn = reduced and 0 or self.spin * 2.6 + coin.phase
				local cframe = coin.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, turn, 0)
				part.CFrame = cframe
				if coin.inner then coin.inner.CFrame = cframe end
			end
		end
	end
end

function HidingController:Start()
	if self.started then return end
	self.started = true
	local model = workspace:FindFirstChild(MAP_NAME)
	if model then self:_collect(model) end
	table.insert(self.connections, workspace.ChildAdded:Connect(function(child)
		if child.Name == MAP_NAME then
			-- The map streams in whole (StreamingEnabled is off); wait a beat for its descendants.
			task.delay(1, function() if child.Parent then self:_collect(child) end end)
		end
	end))
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self:_update(dt)
	end))
	self:OnState(self.ctx.State)
end

function HidingController:Destroy()
	self.destroyed = true
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
	for _, highlight in pairs(self.highlights) do highlight:Destroy() end
	for _, marker in ipairs(self.markers) do marker:Destroy() end
end

return HidingController
