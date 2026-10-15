-- Run: .tooling/bin/lune run tests/data_service.spec.luau
-- These service integration tests execute production code against deterministic
-- in-memory Roblox boundaries. They do not contact DataStore or Marketplace APIs.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Catalog = require("../src/shared/Catalog")
local Rules = require("../src/shared/Rules")
local checks = 0

local function expect(value, message)
	checks += 1
	assert(value, message)
end

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = copy(child) end
	return result
end

local function signal()
	local handlers = {}
	return {
		Connect = function(_, handler) table.insert(handlers, handler); return { Disconnect = function() end } end,
		Fire = function(_, ...) for _, handler in ipairs(handlers) do handler(...) end end,
	}
end

local function instance(className)
	local object = { _children = {}, ClassName = className }
	function object:FindFirstChild(name) return self._children[name] end
	function object:IsA(name) return self.ClassName == name end
	function object:SetAttribute(key, value) self[key] = value end
	return setmetatable(object, {
		__newindex = function(self, key, value)
			rawset(self, key, value)
			if key == "Parent" and value and value._children then value._children[self.Name] = self end
		end,
	})
end

local nextGuid = 0
local function fixture(studio, existingStore)
	local queue, notices, snapshots = {}, {}, {}
	local players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end }
	local store = existingStore or { values = {}, calls = 0 }
	function store:UpdateAsync(key, transform)
		self.calls += 1
		if self.failBefore then error("simulated storage outage") end
		local value = transform(copy(self.values[key]))
		if self.beforeCommit then local hook = self.beforeCommit; self.beforeCommit = nil; hook() end
		if value ~= nil then self.values[key] = copy(value) end
		if self.failAfterCommit then self.failAfterCommit = false; error("simulated lost response after commit") end
		return copy(value)
	end
	local marketplace = { PromptGamePassPurchaseFinished = signal(), owns = {}, prompts = 0, queries = 0 }
	function marketplace:UserOwnsGamePassAsync(userId, passId)
		self.queries += 1
		if self.failVerification then error("simulated marketplace outage") end
		return self.owns[tostring(userId) .. ":" .. tostring(passId)] == true
	end
	function marketplace:PromptGamePassPurchase(_, _passId) self.prompts += 1 end
	local services = {
		Players = players, MarketplaceService = marketplace,
		RunService = { IsStudio = function() return studio == true end },
		DataStoreService = { GetDataStore = function() return store end },
		HttpService = { GenerateGUID = function() nextGuid += 1; return "guid" .. nextGuid end },
	}
	local environment = {
		game = { JobId = "test_server", GetService = function(_, name) return assert(services[name], name) end },
		task = { wait = function() end, defer = function(fn) table.insert(queue, fn) end, spawn = function(fn) table.insert(queue, fn) end },
		Instance = { new = instance },
	}
	local ctx = {
		Config = {
			Round = { MaxPlayers = 12, Duration = 180 },
			Persistence = { StoreName = "test", Retries = 3, UseStudioDataStores = false, AutosaveSeconds = 60, SessionLockSeconds = 180 },
			Progression = { RoundXP = 45, WinXP = 80, TagXP = 25, SurvivalXPPerSecond = 0.4, RoundCoins = 12, WinCoins = 25, TagCoins = 6 },
		},
		Catalog = Catalog, Rules = Rules, Services = {},
		Remotes = {
			Notice = { FireClient = function(_, _, notice) table.insert(notices, notice) end },
			Profile = { FireClient = function(_, _, snapshot) table.insert(snapshots, snapshot) end },
		},
	}
	local DataService = luau.load(fs.readFile("src/server/Services/DataService.lua"), { environment = environment, debugName = "DataService" })()
	local ShopService = luau.load(fs.readFile("src/server/Services/ShopService.lua"), { environment = environment, debugName = "ShopService" })()
	local data = DataService.new(ctx)
	ctx.Services.DataService = data
	local shop = ShopService.new(ctx)
	local applied = 0
	ctx.Services.CosmeticService = { Apply = function() applied += 1 end }
	local player = instance("Player")
	player.UserId = 42
	player.Name = "TestRunner"
	player.Parent = players
	return {
		data = data, shop = shop, player = player, store = store, ctx = ctx, queue = queue,
		notices = notices, snapshots = snapshots, marketplace = marketplace, players = players,
		applied = function() return applied end,
	}
end

-- Studio can develop without touching production storage.
do
	local f = fixture(true)
	f.data:_Load(f.player)
	expect(f.store.calls == 0, "Studio default must make no DataStore calls")
	expect(f.data:Ready(f.player), "Studio session should be playable")
	expect(f.data:Snapshot(f.player).persistence == "session", "Studio must clearly report session-only persistence")
	expect(not f.data:Save(f.player), "Studio ephemeral data must not claim it saved")
end

-- Coin debit and ownership are one operation; replay cannot charge twice.
do
	local f = fixture(true)
	f.data:_Load(f.player)
	local profile = f.data:Get(f.player)
	profile.coins = 1000
	expect(f.data:_PurchaseWithCoins(f.player, "mask_visor"), "Affordable cosmetic should purchase")
	expect(profile.coins == 820 and profile.owned.mask_visor, "Server price must be debited with grant")
	expect(not f.data:_PurchaseWithCoins(f.player, "mask_visor"), "Duplicate purchase must be rejected")
	expect(profile.coins == 820, "Duplicate purchase must not debit again")
	expect(not f.data:_PurchaseWithCoins(f.player, "skin_shadow"), "Premium item cannot use coin path")
	expect(not f.data:Equip(f.player, "skins", "skin_shadow"), "Unowned cosmetic must not equip")
	expect(not f.data:Equip(f.player, "skins", "mask_visor"), "Cosmetic cannot equip in wrong category")
	expect(f.data:Equip(f.player, "masks", "mask_visor"), "Owned matching cosmetic should equip")
	expect(f.applied() == 1, "Equipment change must call CosmeticService")
	expect(f.data:Equip(f.player, "masks", ""), "Unequip must work")
	profile.coins = 0
	expect(not f.data:_PurchaseWithCoins(f.player, "trail_cyan"), "Insufficient funds must be rejected")
	expect(profile.coins == 0 and not profile.owned.trail_cyan, "Failed debit must not alter balance or ownership")
	f.data:UpdateSettings(f.player, { music = false, sfx = "false", coins = 999999 })
	expect(profile.settings.music == false and profile.settings.sfx == true and profile.coins == 0, "Only known boolean settings may change")
end

-- Only one reward per server round; practice cannot farm any progression.
do
	local f = fixture(true)
	f.data:_Load(f.player)
	local profile = f.data:Get(f.player)
	local summary = { role = "Runner", win = true, tags = 99, survived = 180, roundId = 1, practice = true }
	expect(not f.data:AwardRound(f.player, summary), "Practice must reject progression")
	expect(profile.coins == 0 and profile.stats.rounds == 0 and profile.rating == 1000, "Practice must leave all progression untouched")
	summary.practice = false
	expect(f.data:AwardRound(f.player, summary), "Competitive round should reward")
	local coins, xp, rating = profile.coins, profile.xp, profile.rating
	expect(profile.stats.rounds == 1 and profile.stats.tags == 0 and profile.stats.runnerWins == 1, "Runner reward stats must be authoritative")
	expect(profile.achievements.first_round and profile.achievements.first_win, "Milestone achievements should unlock")
	expect(not f.data:AwardRound(f.player, summary), "Replayed round reward must fail")
	expect(profile.coins == coins and profile.xp == xp and profile.rating == rating, "Replayed round must not duplicate any rewards")
	expect(not f.data:AwardRound(f.player, { role = "Runner", win = true, roundId = 0/0 }), "NaN round ID must fail")
	expect(not f.data:ClaimQuest(f.player, "play_3"), "Incomplete quest must fail")
	expect(f.data:ClaimQuest(f.player, "survive_120"), "Completed survival quest should claim")
	coins, xp = profile.coins, profile.xp
	expect(not f.data:ClaimQuest(f.player, "survive_120"), "Quest replay must fail")
	expect(profile.coins == coins and profile.xp == xp, "Quest replay must not duplicate rewards")
	profile.daily.day = "2000-01-01"
	local snapshot = f.data:Snapshot(f.player)
	expect(snapshot.daily.day == Rules.DayKey() and snapshot.daily.progress.survived == 0 and not snapshot.daily.claimed.survive_120, "UTC day rollover must reset progress and claims")
	profile.xp = Rules.XPForLevel(5)
	f.data:_AfterProgress(f.data.records[f.player], 1)
	expect(profile.owned.skin_rooftop, "Level threshold should unlock milestone cosmetic")
	expect(f.player:FindFirstChild("leaderstats"):FindFirstChild("Level").Value == 5, "Leaderstats should follow progression")
	snapshot.coins = 999999
	expect(profile.coins ~= snapshot.coins, "Snapshots must not expose mutable profile references")
end

-- Failed loads never overwrite unknown or currently leased player data.
do
	local f = fixture(false)
	f.store.values.player_42 = { schemaVersion = 9000, valuableFutureData = "preserve" }
	f.data:_Load(f.player)
	expect(f.data:Snapshot(f.player).persistence == "unavailable", "Future schema must be unavailable")
	expect(not f.data:Save(f.player), "Future schema must not be writable")
	expect(f.store.values.player_42.valuableFutureData == "preserve", "Future schema contents must survive unchanged")
	local g = fixture(false)
	g.store.values.player_42 = { _format = "CatchMeIfYouCan.profile.v1", profile = Rules.NewProfile(), session = { id = "another_server", expiresAt = os.time() + 180 } }
	g.data:_Load(g.player)
	expect(not g.data.records[g.player].writable, "Live foreign lease must not be acquired")
	expect(g.store.values.player_42.session.id == "another_server", "Foreign lease must not be changed")
	local h = fixture(false)
	h.store.failBefore = true
	h.data:_Load(h.player)
	expect(h.store.calls == 3, "Transient load errors should use bounded retries")
	expect(h.data:Ready(h.player) and h.data:Snapshot(h.player).persistence == "unavailable", "Load outage should allow explicitly unsaved local play")
	expect(not h.data:Save(h.player) and h.store.values.player_42 == nil, "Failed load must never write defaults over unknown remote state")
end

-- A save snapshots balances before yielding. New edits remain dirty and survive a later save.
do
	local f = fixture(false)
	f.data:_Load(f.player)
	local profile = f.data:Get(f.player)
	profile.coins = 1000
	f.data:_Dirty(f.data.records[f.player])
	f.store.beforeCommit = function() expect(f.data:_PurchaseWithCoins(f.player, "mask_visor"), "Mutation during in-flight save should work") end
	expect(f.data:Save(f.player), "First snapshot should save")
	expect(f.store.values.player_42.profile.coins == 1000 and profile.coins == 820, "In-flight snapshot must not overwrite newer live profile")
	expect(f.data:Snapshot(f.player).saveMessage == "Changes pending autosave.", "Newer edits must not be labeled saved")
	expect(f.data:Save(f.player), "Follow-up should save newer changes")
	expect(f.store.values.player_42.profile.coins == 820 and f.store.values.player_42.profile.owned.mask_visor, "Follow-up must persist atomic debit and grant")
	f.store.failBefore = true
	profile.coins = 700
	f.data:_Dirty(f.data.records[f.player])
	expect(not f.data:Save(f.player), "Storage outage must report failure")
	expect(f.data:Snapshot(f.player).persistence == "unavailable", "Save failure must not report saved")
	expect(f.store.values.player_42.profile.coins == 820, "Failed save must not alter durable data")
	f.store.failBefore = false
	expect(f.data:Save(f.player), "Later save should recover from temporary outage")
	f.store.values.player_42.session.id = "replacement_server"
	profile.coins = 100
	expect(not f.data:Save(f.player), "Lost lease must stop writes")
	expect(f.store.values.player_42.profile.coins == 700 and f.store.values.player_42.session.id == "replacement_server", "Old server must not clobber a replacement lease")
end

-- A lost acknowledgment after the releasing commit is an idempotent success.
do
	local f = fixture(false)
	f.data:_Load(f.player)
	f.data:Get(f.player).coins = 321
	f.data:_Dirty(f.data.records[f.player])
	f.store.failAfterCommit = true
	expect(f.data:_SaveRecord(f.data.records[f.player], true), "Retry should recognize an already committed release")
	expect(f.store.values.player_42.session == nil and f.store.values.player_42.profile.coins == 321, "Release must persist final profile and remove lease")
	local reconnect = fixture(false, f.store)
	reconnect.data:_Load(reconnect.player)
	expect(reconnect.data:Get(reconnect.player).coins == 321, "New session should restore released profile")
	expect(not f.data:Save(f.player), "Released old record must remain unwritable")
	expect(f.data.records[f.player].lockId ~= reconnect.data.records[reconnect.player].lockId, "Each load must have a distinct lease token")
end

-- Marketplace IDs of zero never prompt; a prompt callback alone never grants ownership.
do
	local f = fixture(true)
	f.data:_Load(f.player)
	expect(not f.shop:Purchase(f.player, "skin_shadow") and f.marketplace.prompts == 0, "Unconfigured pass must not prompt")
	expect(f.notices[#f.notices].success == false, "Unconfigured purchase must not trigger celebration")
	local item = Catalog.Get("skin_shadow")
	local previousId = item.gamePassId
	item.gamePassId = 123456
	expect(f.shop:Purchase(f.player, "skin_shadow") and f.marketplace.prompts == 1, "Configured unowned pass should prompt")
	expect(not f.data:Get(f.player).owned.skin_shadow, "Opening prompt must not grant item")
	expect(not f.shop:Purchase(f.player, "skin_shadow") and f.marketplace.prompts == 1, "Concurrent duplicate prompt should be blocked")
	expect(not f.shop:_Verify(f.player, item.gamePassId, true), "Unverified prompt success must not grant pass")
	expect(not f.data:Get(f.player).owned.skin_shadow, "Failed ownership check must not grant cosmetic")
	f.marketplace.owns["42:123456"] = true
	expect(f.shop:_Verify(f.player, item.gamePassId, true), "Server-confirmed pass should grant cosmetic")
	expect(f.data:Get(f.player).owned.skin_shadow, "Verified pass cosmetic should be owned")
	item.gamePassId = previousId
	local bundle = Catalog.Get("bundle_night")
	previousId = bundle.gamePassId
	bundle.gamePassId = 789012
	f.marketplace.owns["42:789012"] = true
	f.shop:_Refresh(f.player)
	expect(f.data:Get(f.player).owned.bundle_night and f.data:Get(f.player).owned.mask_phantom and f.data:Get(f.player).owned.trail_cyan, "Join refresh should restore all verified bundle grants")
	bundle.gamePassId = previousId
end

print("Data and shop service tests passed: " .. checks .. " checks")
