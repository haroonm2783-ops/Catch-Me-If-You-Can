-- Run: .tooling/bin/lune run tests/hub.spec.luau
-- The spawn hub's live boards and kiosks, built from the real map source and driven with a deterministic
-- Players/RoundService boundary. This checks wiring and text, not how the boards look in Roblox.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local Loader = require("../tools/lib/loader")
local checks = 0
local function expect(value, message)
	checks += 1
	assert(value, message)
end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn) local item = {fn = fn, on = true}; table.insert(listeners, item); return {Disconnect = function() item.on = false end} end,
		Fire = function(_, ...) for _, item in ipairs(listeners) do if item.on then item.fn(...) end end end,
	}
end

-- Build the real hub from the mall source.
local place = roblox.Instance.new("DataModel")
local world = roblox.Instance.new("Workspace")
world.Parent = place
local env = Loader.environment({game = place, workspace = world})
local Builder = Loader.load("src/server/World/MallBuilder.lua", env)
local map = Builder.Build({Static = true})
local model = map.Model
local hub = model:FindFirstChild("Hub")
expect(hub ~= nil, "The map contains a Hub folder")

local boards, prompts, status = {}, {}, nil
for _, item in ipairs(model:GetDescendants()) do
	if item.Name == "HubLeaderboard" then table.insert(boards, item)
	elseif item:IsA("ProximityPrompt") and item.Name == "MenuPrompt" then table.insert(prompts, item)
	elseif item.Name == "StatusBoard" then status = item end
end
expect(#boards == 2, "Two leaderboards: runners and hunters")
expect(#prompts == 2 and prompts[1].Parent:GetAttribute("Menu") ~= prompts[2].Parent:GetAttribute("Menu"), "Shop and Locker kiosks carry distinct prompts")
expect(status ~= nil and status:FindFirstChild("Board"):FindFirstChild("Timer") ~= nil, "The entrance has a status board with a timer")
for _, board in ipairs(boards) do
	expect(board:GetAttribute("Stat") == "Wins" or board:GetAttribute("Stat") == "Tags", "Leaderboards read a real leaderstat")
	for row = 1, 5 do expect(board.Board:FindFirstChild("Row" .. row) ~= nil, "Leaderboard has five rows") end
end

-- The hub is compact and reachable: spawn, podiums and boards are inside the plaza footprint.
expect(map.LobbySpawn.Position.X > -50 and map.LobbySpawn.Position.X < 50 and map.LobbySpawn.Position.Z < -154 and map.LobbySpawn.Position.Z > -232, "Spawn is inside the hub plaza")
expect(#map.Podiums == 3, "Three podium places")
for _, podium in ipairs(map.Podiums) do
	expect(podium.Position.Z > -190 and podium.Position.Z < -160 and math.abs(podium.Position.X) < 20, "Podium places sit on the stage")
end

-- Drive the real service.
local Service = luau.load(fs.readFile("src/server/Services/HubService.lua"), {debugName = "HubService", environment = (function()
	local e = {}
	for key, value in pairs(env) do e[key] = value end
	return e
end)()})
local heartbeat, removing = signal(), signal()
local players = {}
local function makePlayer(name, userId, stats)
	local player = roblox.Instance.new("Player")
	player.Name, player.DisplayName, player.UserId = name, name, userId
	local folder = roblox.Instance.new("Folder"); folder.Name = "leaderstats"; folder.Parent = player
	for stat, value in pairs(stats) do
		local v = roblox.Instance.new("IntValue"); v.Name, v.Value, v.Parent = stat, value, folder
	end
	player.Parent = world
	table.insert(players, player)
	return player
end
local ann = makePlayer("Ann", 1, {Wins = 5, Tags = 40, Level = 3, Rating = 1000})
local bob = makePlayer("Bob", 2, {Wins = 9, Tags = 12, Level = 4, Rating = 1100})
local cy = makePlayer("Cy", 3, {Wins = 9, Tags = 60, Level = 2, Rating = 900})
local services = {
	Players = {GetPlayers = function() return players end, PlayerRemoving = removing},
	RunService = {Heartbeat = heartbeat},
	Workspace = {GetServerTimeNow = function() return 100 end},
}
local serviceEnv = {}
for key, value in pairs(env) do serviceEnv[key] = value end
serviceEnv.game = {GetService = function(_, name) return assert(services[name], name) end}
local now = 1000
serviceEnv.os = {clock = function() return now end}
local HubService = luau.load(fs.readFile("src/server/Services/HubService.lua"), {debugName = "HubService", environment = serviceEnv})()
local snapshot = {phase = "Waiting", endsAt = 0}
local sent = {}
local ctx = {World = map, Services = {RoundService = {Snapshot = function() return snapshot end}},
	Remotes = {Notice = {FireClient = function(_, player, notice) table.insert(sent, {player = player, notice = notice}) end}}}
local service = HubService.new(ctx)
-- Prompts are not dispatched by Lune: replace the signal so Triggered can be fired.
local trigger = signal()
roblox.implementProperty("ProximityPrompt", "Triggered", function() return trigger end)
service:Start()
local winsBoard
for _, board in ipairs(boards) do if board:GetAttribute("Stat") == "Wins" then winsBoard = board end end
expect(winsBoard.Board.Row1.Text:find("Bob") and winsBoard.Board.Row2.Text:find("Cy") and winsBoard.Board.Row3.Text:find("Ann"), "Wins board sorts by wins, ties by user id")
expect(winsBoard.Board.Row1.Text:find("9") and winsBoard.Board.Row4.Text == "4.  ---", "Rows show values and placeholders")
local tagsBoard
for _, board in ipairs(boards) do if board:GetAttribute("Stat") == "Tags" then tagsBoard = board end end
expect(tagsBoard.Board.Row1.Text:find("Cy") and tagsBoard.Board.Row1.Text:find("60"), "Tags board leads with the top tagger")
local gui = status.Board
expect(gui.Phase.Text == "WAITING FOR PLAYERS" and gui.Timer.Text == "--:--" and gui.Players.Text == "3 PLAYERS", "Status board shows waiting state and player count")
snapshot = {phase = "Intermission", endsAt = 114}
service:UpdateStatus()
expect(gui.Phase.Text == "NEXT CHASE IN" and gui.Timer.Text == "00:14", "Status board counts down the intermission")
snapshot = {phase = "Active", endsAt = 280, practice = true}
service:UpdateStatus()
expect(gui.Phase.Text == "SOLO PRACTICE", "Practice is labelled on the board")
snapshot = {phase = "Results", endsAt = 110, practice = false}
service:UpdateStatus()
expect(gui.Phase.Text == "WINNERS ON THE PODIUM", "Results phase is announced")
players[3] = nil
service:UpdateStatus()
expect(gui.Players.Text == "2 PLAYERS", "Player count follows the server")
bob:FindFirstChild("leaderstats").Wins.Value = 1
service:UpdateBoards()
expect(winsBoard.Board.Row1.Text:find("Ann"), "Boards refresh when stats change")
-- Kiosks: only a known menu is requested, only for the player who pressed it, and spam is throttled.
service:_openMenu(ann, "Shop")
expect(#sent == 1 and sent[1].player == ann and sent[1].notice.kind == "menu" and sent[1].notice.menu == "Shop", "Shop kiosk opens the Shop on the pressing client")
service:_openMenu(ann, "Shop")
expect(#sent == 1, "A held key cannot spam menu requests")
now += 1
service:_openMenu(ann, "Shop")
expect(#sent == 2, "The kiosk works again after the short throttle")
sent = {}
service:_openMenu(bob, "Inventory")
expect(#sent == 1 and sent[1].notice.menu == "Inventory", "Locker kiosk opens the Locker")
service:_openMenu(bob, "AdminPanel")
expect(#sent == 1, "Unknown menus are never forwarded")
print("Hub tests passed: " .. checks .. " checks")
