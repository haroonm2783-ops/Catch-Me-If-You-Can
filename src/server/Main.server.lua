-- The server is the only authority for rounds, movement intent, inventory and rewards.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
Players.CharacterAutoLoads = false
local shared = ReplicatedStorage:WaitForChild("CatchShared")
local Config = require(shared.Config)
local Catalog = require(shared.Catalog)
local Rules = require(shared.Rules)
local MapBuilder = require(script.Parent.World.MapBuilder)

local remotesFolder = Instance.new("Folder")
remotesFolder.Name = "CatchRemotes"
local remotes = {}
for _, name in ipairs({"State", "Action", "Profile", "Notice", "Query"}) do
	local remote = Instance.new(if name == "Query" then "RemoteFunction" else "RemoteEvent")
	remote.Name = name
	remote.Parent = remotesFolder
	remotes[name] = remote
end
local ctx = {Config=Config, Catalog=Catalog, Rules=Rules, Remotes=remotes, Services={}}
ctx.World = MapBuilder.Build()
for _, name in ipairs({"DataService", "CosmeticService", "ShopService", "MovementService", "RoundService"}) do
	ctx.Services[name] = require(script.Parent.Services[name]).new(ctx)
end

local limits = {
	Sprint={capacity=6,refill=4}, Slide={capacity=3,refill=1}, Vault={capacity=5,refill=3},
	Tag={capacity=5,refill=4}, Equip={capacity=4,refill=2}, Buy={capacity=2,refill=0.5},
	ClaimQuest={capacity=3,refill=1}, Settings={capacity=4,refill=2}, Emote={capacity=2,refill=0.5},
}
local buckets = {}
local queryTimes = {}
local function allow(player, action)
	local rule = limits[action]
	if not rule then return false end
	local byPlayer = buckets[player]
	if not byPlayer then byPlayer = {}; buckets[player] = byPlayer end
	local now = os.clock()
	local bucket = byPlayer[action] or {tokens=rule.capacity,time=now}
	byPlayer[action] = bucket
	bucket.tokens = math.min(rule.capacity, bucket.tokens + (now-bucket.time)*rule.refill)
	bucket.time = now
	if bucket.tokens < 1 then return false end
	bucket.tokens -= 1
	return true
end
local function validPayload(payload)
	if type(payload) ~= "table" then return false end
	local count = 0
	for key, value in pairs(payload) do
		count += 1
		if count > 8 or type(key) ~= "string" or #key > 30 then return false end
		if type(value) == "string" then
			if #value > 80 then return false end
		elseif type(value) ~= "boolean" then return false end
	end
	return true
end
local function dispatch(player, action, payload)
	if type(action) ~= "string" or #action > 20 or not allow(player, action) then return end
	payload = payload or {}
	if not validPayload(payload) or not ctx.Services.DataService:Ready(player) then return end
	if action == "Sprint" or action == "Slide" or action == "Vault" then
		ctx.Services.MovementService:Handle(player, action, payload)
	elseif action == "Tag" then
		ctx.Services.RoundService:TryTag(player)
	elseif action == "Equip" then
		if type(payload.category)=="string" and type(payload.id)=="string" then ctx.Services.DataService:Equip(player,payload.category,payload.id) end
	elseif action == "Buy" then
		if type(payload.id)=="string" then ctx.Services.ShopService:Purchase(player,payload.id) end
	elseif action == "ClaimQuest" then
		if type(payload.id)=="string" then ctx.Services.DataService:ClaimQuest(player,payload.id) end
	elseif action == "Settings" then
		ctx.Services.DataService:UpdateSettings(player, payload)
	elseif action == "Emote" then
		if type(payload.id)=="string" then ctx.Services.CosmeticService:Emote(player,payload.id) end
	end
end
remotes.Action.OnServerEvent:Connect(function(player, action, payload)
	local ok, err = pcall(dispatch, player, action, payload)
	if not ok then warn("[Catch] Action failed:", action, err) end
end)
remotes.Query.OnServerInvoke = function(player)
	local now = os.clock()
	if queryTimes[player] and now-queryTimes[player] < 0.75 then return nil end
	queryTimes[player] = now
	return {state=ctx.Services.RoundService:Snapshot(),profile=ctx.Services.DataService:Snapshot(player)}
end
Players.PlayerRemoving:Connect(function(player) buckets[player]=nil; queryTimes[player]=nil end)
for _, name in ipairs({"DataService", "CosmeticService", "ShopService", "MovementService", "RoundService"}) do
	local service = ctx.Services[name]
	if service.Start then service:Start() end
end
-- Publish only after handlers and service state are initialized.
remotesFolder.Parent = ReplicatedStorage
print("[Catch] Neon Heights initialized. " .. Config.Version)
