-- The spawn hub's live parts: two leaderboards (this server, from leaderstats), the status board over the mall
-- entrance, and the Shop / Locker kiosks. Everything here is presentation: it reads public state and never
-- changes rounds, rewards or inventory. Kiosks only ask the player's own client to open a menu.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local HubService = {}
HubService.__index = HubService

local PHASE_TEXT = {
	Waiting = "WAITING FOR PLAYERS",
	Intermission = "NEXT CHASE IN",
	HeadStart = "RUNNERS GET A HEAD START",
	Active = "CHASE IN PROGRESS",
	Results = "WINNERS ON THE PODIUM",
}
local MENUS = {Shop = true, Inventory = true}

function HubService.new(ctx)
	return setmetatable({ctx = ctx, boards = {}, statusGui = nil, connections = {}, lastOpen = {}, boardClock = 0, statusClock = 0}, HubService)
end

function HubService:_collect()
	local model = self.ctx.World and self.ctx.World.Model
	if not model then return end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item.Name == "HubLeaderboard" then
			local gui = item:FindFirstChild("Board")
			if gui then table.insert(self.boards, {gui = gui, stat = item:GetAttribute("Stat") or "Wins"}) end
		elseif item:IsA("BasePart") and item.Name == "StatusBoard" then
			self.statusGui = item:FindFirstChild("Board")
		elseif item:IsA("ProximityPrompt") and item.Name == "MenuPrompt" then
			local menu = item.Parent and item.Parent:GetAttribute("Menu")
			if MENUS[menu] then
				table.insert(self.connections, item.Triggered:Connect(function(player) self:_openMenu(player, menu) end))
			end
		end
	end
end

-- Ask the triggering player's own client to open Shop or Locker. Throttled so a held key cannot spam.
function HubService:_openMenu(player, menu)
	local now = os.clock()
	if now - (self.lastOpen[player] or -1) < 0.6 or not MENUS[menu] then return end
	self.lastOpen[player] = now
	if player.Parent then self.ctx.Remotes.Notice:FireClient(player, {kind = "menu", menu = menu}) end
end

function HubService:_rows(stat)
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local folder = player:FindFirstChild("leaderstats")
		local value = folder and folder:FindFirstChild(stat)
		if value then table.insert(list, {name = player.DisplayName, value = value.Value, userId = player.UserId}) end
	end
	table.sort(list, function(a, b)
		if a.value == b.value then return a.userId < b.userId end
		return a.value > b.value
	end)
	return list
end

function HubService:UpdateBoards()
	for _, board in ipairs(self.boards) do
		local rows = self:_rows(board.stat)
		for index = 1, 5 do
			local label = board.gui:FindFirstChild("Row" .. index)
			if label then
				local entry = rows[index]
				local text = entry and string.format("%d.  %s  %d", index, string.sub(entry.name, 1, 14), entry.value) or (index .. ".  ---")
				if label.Text ~= text then label.Text = text end
			end
		end
	end
end

local function clock(seconds)
	local value = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", math.floor(value / 60), value % 60)
end

function HubService:UpdateStatus()
	local gui = self.statusGui
	local round = self.ctx.Services.RoundService
	if not gui or not round then return end
	local state = round:Snapshot()
	local phase = state.practice and state.phase ~= "Results" and "SOLO PRACTICE" or (PHASE_TEXT[state.phase] or "WELCOME TO THE MALL")
	local timer = state.phase == "Waiting" and "--:--" or clock((state.endsAt or 0) - Workspace:GetServerTimeNow())
	local count = #Players:GetPlayers()
	local labels = {Phase = phase, Timer = timer, Players = count .. (count == 1 and " PLAYER" or " PLAYERS")}
	for name, text in pairs(labels) do
		local label = gui:FindFirstChild(name)
		if label and label.Text ~= text then label.Text = text end
	end
end

function HubService:Start()
	if self.started then return end
	self.started = true
	self:_collect()
	self:UpdateBoards()
	self:UpdateStatus()
	table.insert(self.connections, RunService.Heartbeat:Connect(function(dt)
		self.boardClock += dt
		self.statusClock += dt
		if self.statusClock >= 0.5 then
			self.statusClock = 0
			local ok, err = pcall(function() self:UpdateStatus() end)
			if not ok then warn("[Catch hub] status failed: " .. tostring(err)) end
		end
		if self.boardClock >= 3 then
			self.boardClock = 0
			local ok, err = pcall(function() self:UpdateBoards() end)
			if not ok then warn("[Catch hub] boards failed: " .. tostring(err)) end
		end
	end))
	table.insert(self.connections, Players.PlayerRemoving:Connect(function(player) self.lastOpen[player] = nil end))
end

return HubService
