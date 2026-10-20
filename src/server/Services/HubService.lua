-- Plaza hub interactions: PLAY portal, locker/shop/quest/reward kiosks and the live board.
-- Prompts are baked into the map with a HubAction attribute; this service only wires them.
local Players = game:GetService("Players")

local HubService = {}
HubService.__index = HubService

local MENUS = { Shop = "Shop", Locker = "Inventory", Quests = "Quests", Rewards = "Quests", Career = "Progress", Roster = "Leaderboard" }

function HubService.new(ctx)
	return setmetatable({ ctx = ctx, connected = {} }, HubService)
end

function HubService:_trigger(player, action)
	local rounds = self.ctx.Services.RoundService
	if action == "Play" then
		rounds:Queue(player, true)
	elseif MENUS[action] then
		self.ctx.Remotes.Notice:FireClient(player, { kind = "openMenu", menu = MENUS[action] })
	end
end

function HubService:_wire(prompt)
	if self.connected[prompt] then return end
	local action = prompt:GetAttribute("HubAction")
	if not action then return end
	self.connected[prompt] = prompt.Triggered:Connect(function(player)
		self:_trigger(player, action)
	end)
end

function HubService:_refreshBoard()
	local board = self.board
	if not board or not board.Parent then return end
	local players = Players:GetPlayers()
	local function stat(player, name)
		local folder = player:FindFirstChild("leaderstats")
		local value = folder and folder:FindFirstChild(name)
		return value and value.Value or 0
	end
	table.sort(players, function(a, b)
		local av, bv = stat(a, "Rating"), stat(b, "Rating")
		if av == bv then return a.UserId < b.UserId end
		return av > bv
	end)
	for row = 1, 5 do
		local player = players[row]
		local name = board:FindFirstChild("Row" .. row, true)
		if name then
			name.Text = player and string.format("%d  %s", row, player.DisplayName) or string.format("%d  ---", row)
		end
		local score = board:FindFirstChild("Score" .. row, true)
		if score then
			score.Text = player and string.format("%d WINS", stat(player, "Wins")) or ""
		end
	end
end

function HubService:Start()
	if self.started then return end
	self.started = true
	local map = workspace:FindFirstChild("CatchMall")
	if not map then return end
	for _, object in ipairs(map:GetDescendants()) do
		if object:IsA("ProximityPrompt") then self:_wire(object)
		elseif object:IsA("BasePart") and object:GetAttribute("HubTouch") then
			local action = object:GetAttribute("HubTouch")
			object.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				if player then self:_trigger(player, action) end
			end)
		end
	end
	self.board = map:FindFirstChild("LeaderboardBoard", true)
	task.spawn(function()
		while self.started do
			pcall(function() self:_refreshBoard() end)
			task.wait(5)
		end
	end)
end

return HubService
