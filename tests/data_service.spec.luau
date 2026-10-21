-- Run: .tooling/bin/lune run tests/data_service.spec.luau
-- These service integration tests execute production code against deterministic
-- in-memory Roblox boundaries. They do not contact DataStore or Marketplace APIs.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local Catalog = require("../src/shared/Catalog")
local Rules = require("../src/shared/Rules")
local Achievements = require("../src/shared/Achievements")
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
	local scheduler = {}
	local players = { PlayerAdded = signal(), PlayerRemoving = signal(), GetPlayers = function() return {} end }
	local roster = {}
	function players:GetPlayerByUserId(id) return roster[id] end
	local store = existingStore or { values = {}, calls = 0 }
	function store:UpdateAsync(key, transform)
		self.calls += 1
		if self.failBefore then error("simulated storage outage") end
		local value = transform(copy(self.values[key]))
		-- Roblox may rerun the transform when another writer wins before commit.
		if self.retryTransform and value ~= nil then
			local hook = self.retryTransform
			self.retryTransform = nil
			hook(self.values, key)
			value = transform(copy(self.values[key]))
		end
		if self.beforeCommit then local hook = self.beforeCommit; self.beforeCommit = nil; hook() end
		if value ~= nil then self.values[key] = copy(value) end
		if self.failAfterCommit then self.failAfterCommit = false; error("simulated lost response after commit") end
		return copy(value)
	end
	local marketplace = { PromptGamePassPurchaseFinished = signal(), owns = {}, prompts = 0, queries = 0 }
	function marketplace:UserOwnsGamePassAsync(userId, passId)
		self.queries += 1
		if self.failVerification then error("simulated marketplace outage") end
		if self.afterQuery then local hook = self.afterQuery; self.afterQuery = nil; hook() end
		return self.owns[tostring(userId) .. ":" .. tostring(passId)] == true
	end
	function marketplace:PromptProductPurchase(_, productId)
		self.productPrompts = (self.productPrompts or 0) + 1
		self.lastProduct = productId
		if self.failPrompt then error("simulated prompt failure") end
	end
	function marketplace:PromptGamePassPurchase(_, _passId)
		self.prompts += 1
		if self.failPrompt then error("simulated prompt failure") end
	end
	local services = {
		Players = players, MarketplaceService = marketplace,
		RunService = { IsStudio = function() return studio == true end },
		DataStoreService = { GetDataStore = function() return store end },
		HttpService = { GenerateGUID = function() nextGuid += 1; return "guid" .. nextGuid end },
	}
	local environment = {
		game = {
			JobId = "test_server", GetService = function(_, name) return assert(services[name], name) end,
			BindToClose = function(_, callback) scheduler.close = callback end,
		},
		task = {
			wait = function(seconds) if scheduler.wait then return scheduler.wait(seconds) end end,
			defer = function(fn) table.insert(queue, fn) end,
			spawn = function(fn) table.insert(queue, fn) end,
		},
		Instance = { new = instance },
		Enum = { ProductPurchaseDecision = { PurchaseGranted = "Granted", NotProcessedYet = "NotYet" } },
	}
	local ctx = {
		Config = {
			Round = { MaxPlayers = 12, Duration = 180 },
			Persistence = { StoreName = "test", Retries = 3, UseStudioDataStores = false, AutosaveSeconds = 60, SessionLockSeconds = 180 },
			Progression = { RoundXP = 45, WinXP = 80, TagXP = 25, SurvivalXPPerSecond = 0.4, RoundCoins = 12, WinCoins = 25, TagCoins = 6 },
		},
		Catalog = Catalog, Rules = Rules, Achievements = Achievements, Services = {},
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
	roster[42] = player
	return {
		data = data, shop = shop, player = player, store = store, ctx = ctx, queue = queue,
		notices = notices, snapshots = snapshots, marketplace = marketplace, players = players, scheduler = scheduler,
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
	expect(profile.coins == 700 and profile.owned.mask_visor, "Server price must be debited with grant")
	expect(not f.data:_PurchaseWithCoins(f.player, "mask_visor"), "Duplicate purchase must be rejected")
	expect(profile.coins == 700, "Duplicate purchase must not debit again")
	expect(not f.data:_PurchaseWithCoins(f.player, "skin_ninja"), "Premium item cannot use coin path")
	expect(not f.data:Equip(f.player, "skins", "skin_ninja"), "Unowned cosmetic must not equip")
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
	expect(f.store.values.player_42.profile.coins == 1000 and profile.coins == 700, "In-flight snapshot must not overwrite newer live profile")
	expect(f.data:Snapshot(f.player).saveMessage == "Changes pending autosave.", "Newer edits must not be labeled saved")
	expect(f.data:Save(f.player), "Follow-up should save newer changes")
	expect(f.store.values.player_42.profile.coins == 700 and f.store.values.player_42.profile.owned.mask_visor, "Follow-up must persist atomic debit and grant")
	f.store.failBefore = true
	profile.coins = 700
	f.data:_Dirty(f.data.records[f.player])
	expect(not f.data:Save(f.player), "Storage outage must report failure")
	expect(f.data:Snapshot(f.player).persistence == "unavailable", "Save failure must not report saved")
	expect(f.store.values.player_42.profile.coins == 700, "Failed save must not alter durable data")
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
	expect(not f.shop:Purchase(f.player, "skin_ninja") and f.marketplace.prompts == 0, "Unconfigured pass must not prompt")
	expect(f.notices[#f.notices].success == false, "Unconfigured purchase must not trigger celebration")
	local item = Catalog.Get("skin_ninja")
	local previousId = item.gamePassId
	item.gamePassId = 123456
	expect(f.shop:Purchase(f.player, "skin_ninja") and f.marketplace.prompts == 1, "Configured unowned pass should prompt")
	expect(not f.data:Get(f.player).owned.skin_ninja, "Opening prompt must not grant item")
	expect(not f.shop:Purchase(f.player, "skin_ninja") and f.marketplace.prompts == 1, "Concurrent duplicate prompt should be blocked")
	expect(not f.shop:_Verify(f.player, item.gamePassId, true), "Unverified prompt success must not grant pass")
	expect(not f.data:Get(f.player).owned.skin_ninja, "Failed ownership check must not grant cosmetic")
	f.marketplace.owns["42:123456"] = true
	expect(f.shop:_Verify(f.player, item.gamePassId, true), "Server-confirmed pass should grant cosmetic")
	expect(f.data:Get(f.player).owned.skin_ninja, "Verified pass cosmetic should be owned")
	item.gamePassId = previousId
	local bundle = Catalog.Get("bundle_galaxy")
	previousId = bundle.gamePassId
	bundle.gamePassId = 789012
	f.marketplace.owns["42:789012"] = true
	f.shop:_Refresh(f.player)
	local owned = f.data:Get(f.player).owned
	expect(owned.bundle_galaxy and owned.skin_galaxy and owned.mask_astral and owned.trail_stardust and owned.emote_royal, "Join refresh should restore all verified collection grants (outfit, mask, trail and emote)")
	bundle.gamePassId = previousId
end

-- Legacy profiles migrate under a lease; malformed and concurrently replaced records stay protected.
do
	local f = fixture(false)
	local legacy = Rules.NewProfile()
	legacy.coins = 73
	legacy.owned.mask_visor = true
	legacy.equipped.masks = "mask_visor"
	f.store.values.player_42 = legacy
	f.store.failAfterCommit = true
	f.data:_Load(f.player)
	expect(f.store.calls == 2 and f.data.records[f.player].writable, "Lost load acknowledgment should retry its own lease safely")
	expect(f.data:Get(f.player).coins == 73 and f.data:Get(f.player).equipped.masks == "mask_visor", "Migration must preserve balances and equipment")
	expect(f.store.values.player_42._format == "CatchMeIfYouCan.profile.v1", "Flat legacy profile must migrate into the documented envelope")
	local g = fixture(false)
	g.store.values.player_42 = { _format = "CatchMeIfYouCan.profile.v1", profile = Rules.NewProfile(), session = { id = "expired", expiresAt = os.time() - 1 } }
	g.data:_Load(g.player)
	expect(g.data.records[g.player].writable and g.store.values.player_42.session.id ~= "expired", "Expired lease should permit recovery")
	local h = fixture(false)
	h.store.retryTransform = function(values, key)
		values[key] = { _format = "CatchMeIfYouCan.profile.v1", profile = Rules.NewProfile(), session = { id = "winning_server", expiresAt = os.time() + 180 } }
		values[key].profile.coins = 456
	end
	h.data:_Load(h.player)
	expect(not h.data.records[h.player].writable, "Load must recheck ownership when UpdateAsync retries a transform")
	expect(h.store.values.player_42.profile.coins == 456 and h.store.values.player_42.session.id == "winning_server", "Contended load must preserve winner's profile and lease")
	for _, badSession in ipairs({ { id = "bad", expiresAt = 0/0 }, { id = "bad", expiresAt = math.huge }, { id = 99, expiresAt = os.time() } }) do
		local bad = fixture(false)
		bad.store.values.player_42 = { _format = "CatchMeIfYouCan.profile.v1", profile = Rules.NewProfile(), session = badSession }
		bad.data:_Load(bad.player)
		expect(not bad.data.records[bad.player].writable and not bad.data:Save(bad.player), "Malformed stored leases must never be replaced with defaults")
	end
end

-- A competing lease that wins during UpdateAsync retries invalidates the old writer.
do
	local f = fixture(false)
	f.data:_Load(f.player)
	f.data:Get(f.player).coins = 111
	f.data:_Dirty(f.data.records[f.player])
	f.store.retryTransform = function(values, key)
		values[key].session = { id = "new_owner", expiresAt = os.time() + 180 }
		values[key].profile.coins = 999
	end
	expect(not f.data:Save(f.player), "UpdateAsync conflict must recheck the writer's lease")
	expect(f.store.values.player_42.profile.coins == 999 and f.store.values.player_42.session.id == "new_owner", "A stale snapshot must never replace the winning session's profile")
	expect(not f.data.records[f.player].writable and f.data:Snapshot(f.player).persistence == "unavailable", "Losing a lease must revoke writing and report unsaved state")
	local calls = f.store.calls
	expect(not f.data:Save(f.player) and f.store.calls == calls, "Revoked writer must not retry writes against another session")
end

-- Concurrent saves serialize, and departure writes the newest revision before releasing.
do
	local f = fixture(false)
	f.data:_Load(f.player)
	local record = f.data.records[f.player]
	record.profile.coins = 1000
	f.data:_Dirty(record)
	f.scheduler.wait = function() coroutine.yield("waiting for writer") end
	f.store.beforeCommit = function() coroutine.yield("saving initial snapshot") end
	local firstResult, releaseResult
	local first = coroutine.create(function() firstResult = f.data:Save(f.player) end)
	expect(coroutine.resume(first), "Initial save coroutine should start")
	expect(record.saving and coroutine.status(first) == "suspended", "Initial save must hold writer guard while storage yields")
	expect(f.data:_PurchaseWithCoins(f.player, "mask_visor"), "Non-yielding purchase can progress while autosave is pending")
	record.departed = true
	record.accepting = false
	local release = coroutine.create(function() releaseResult = f.data:_SaveRecord(record, true) end)
	expect(coroutine.resume(release), "Departure save should start")
	expect(coroutine.status(release) == "suspended" and f.store.calls == 2, "Concurrent release must wait without issuing a second write")
	expect(coroutine.resume(first) and firstResult, "Initial save should complete")
	expect(coroutine.resume(release) and releaseResult, "Departure save should complete after existing writer")
	expect(f.store.values.player_42.profile.coins == 700 and f.store.values.player_42.profile.owned.mask_visor, "Departure must persist the newest atomic purchase")
	expect(f.store.values.player_42.session == nil and record.released, "Departure must release profile ownership")
	expect(not f.data:_PurchaseWithCoins(f.player, "trail_cyan"), "Departing profiles must stop accepting mutations")
end

-- Shutdown waits through a delayed load's final save and lease release.
do
	local f = fixture(false)
	f.data:Start()
	f.scheduler.wait = function() coroutine.yield("shutdown waiting") end
	f.store.beforeCommit = function()
		coroutine.yield("load response delayed")
		f.store.beforeCommit = function() coroutine.yield("release response delayed") end
	end
	local loading = coroutine.create(function() f.data:_Load(f.player) end)
	expect(coroutine.resume(loading) and f.data.activeLoads == 1, "Delayed load must count as active")
	local closing = coroutine.create(f.scheduler.close)
	expect(coroutine.resume(closing) and coroutine.status(closing) == "suspended", "Shutdown must wait for pending load")
	expect(coroutine.resume(loading) and coroutine.status(loading) == "suspended", "Load should enter delayed lease release after shutdown starts")
	expect(f.data.activeLoads == 1, "In-flight final release must remain counted as active load work")
	expect(coroutine.resume(closing) and coroutine.status(closing) == "suspended", "Shutdown must not finish before delayed release commits")
	expect(coroutine.resume(loading) and f.data.activeLoads == 0, "Completing release should settle load accounting")
	expect(coroutine.resume(closing) and coroutine.status(closing) == "dead", "Shutdown should finish after load cleanup")
	expect(f.data.records[f.player] == nil and f.store.values.player_42.session == nil, "Shutdown during load must remove local record and durable lease")
end

-- Marketplace failures, cancellation, callbacks, and player departure never manufacture entitlements.
do
	local item = Catalog.Get("skin_golden")
	local previousId = item.gamePassId
	item.gamePassId = 654321
	local f = fixture(true)
	f.data:_Load(f.player)
	f.shop:Start()
	f.marketplace.failVerification = true
	expect(not f.shop:Purchase(f.player, item.id) and f.marketplace.prompts == 0, "Ownership outage must block a new charge prompt")
	expect(not f.data:Get(f.player).owned[item.id] and not f.shop.busy[f.player], "Ownership outage must neither grant nor leave the shop busy")
	f.marketplace.failVerification = false
	f.marketplace.failPrompt = true
	expect(not f.shop:Purchase(f.player, item.id), "Prompt API failure must be reported")
	expect(f.shop.pending[f.player] == nil and not f.shop.busy[f.player], "Prompt failure must clear purchase locks")
	f.marketplace.failPrompt = false
	f.shop.lastPrompt[f.player] = nil
	expect(f.shop:Purchase(f.player, item.id), "Valid purchase should open a prompt")
	f.marketplace.PromptGamePassPurchaseFinished:Fire(f.player, item.gamePassId, false)
	expect(f.shop.pending[f.player] == nil and not f.data:Get(f.player).owned[item.id], "Cancelled prompt must clear pending state without granting")
	f.shop.lastPrompt[f.player] = nil
	expect(f.shop:Purchase(f.player, item.id), "Purchase after cancellation should remain possible")
	f.marketplace.owns["42:654321"] = true
	f.marketplace.PromptGamePassPurchaseFinished:Fire(f.player, item.gamePassId, true)
	expect(not f.data:Get(f.player).owned[item.id], "Prompt-finished event must schedule verification before any grant")
	local verifyCallback = table.remove(f.queue, 1)
	expect(type(verifyCallback) == "function", "Completed prompt must schedule server verification")
	verifyCallback()
	expect(f.data:Get(f.player).owned[item.id] and f.shop.pending[f.player] == nil, "Verified prompt callback must restore the entitlement and clear pending state")
	local queries = f.marketplace.queries
	expect(f.shop:_Verify(f.player, item.gamePassId, false) and f.marketplace.queries == queries, "Verified entitlement can be reused without another marketplace query")
	f.players.PlayerRemoving:Fire(f.player)
	expect(f.shop.verified[f.player] == nil and f.shop.pending[f.player] == nil and f.shop.lastPrompt[f.player] == nil, "Leaving must release per-player shop state")
	local g = fixture(true)
	g.data:_Load(g.player)
	g.marketplace.owns["42:654321"] = true
	g.marketplace.afterQuery = function() g.player.Parent = nil end
	expect(not g.shop:_Verify(g.player, item.gamePassId, false), "A departing player cannot receive an asynchronous ownership result")
	expect(not g.data:Get(g.player).owned[item.id], "Ownership response after departure must not mutate a profile")
	item.gamePassId = previousId
end

-- A skin and mask remain independent across wardrobe changes and a new server.
-- This exercises production serialization through the fake store; it is not a
-- claim that a live Roblox DataStore or a paid purchase has been exercised.
-- Saves from before the avatar-first change carry tone and hair-color items; they must load cleanly and be dropped.
do
	local f = fixture(false)
	local legacy = f.ctx.Rules.NewProfile(1700000000)
	legacy.owned.tone_sand, legacy.owned.hair_pink, legacy.owned.skin_ninja = true, true, true
	legacy.equipped.tones, legacy.equipped.hairColors, legacy.equipped.skins = "tone_sand", "hair_pink", "skin_ninja"
	local clean = f.data:_Sanitize(legacy)
	expect(clean.equipped.tones == nil and clean.equipped.hairColors == nil, "Retired personalization categories are dropped from equipment")
	expect(clean.owned.tone_sand == nil and clean.owned.hair_pink == nil, "Retired personalization items are dropped from inventory")
	expect(clean.equipped.skins == "skin_ninja" and clean.owned.skin_ninja == true, "Owned skins from an old save are kept")
	expect(clean.owned.skin_courier == true and clean.owned.mask_street == true, "Free defaults remain owned")
end

-- Unlock reveals: the server tells the client about the best newly gained item so it can celebrate.
do
	local f = fixture(false)
	f.data:_Load(f.player)
	f.data:Grant(f.player, {"skin_golden", "mask_street"}, "Purchase verified.")
	local notice = f.notices[#f.notices]
	expect(notice.kind == "unlock" and notice.reveal and notice.reveal.id == "skin_golden" and notice.reveal.rarity == "Legendary", "A new Legendary is revealed to the client")
	expect(notice.reveal.name == "Golden Champion" and notice.reveal.category == "skins", "The reveal names the item and its category")
	local count = #f.notices
	f.data:Grant(f.player, {"skin_golden"}, "Again.")
	expect(#f.notices == count, "Items that are already owned send no second celebration")
	f.data:Grant(f.player, {"skin_bunny"}, "Added Bunny Hop.")
	expect(f.notices[#f.notices].reveal and f.notices[#f.notices].reveal.rarity == "Rare", "Rare items are revealed too")
	f.data:Grant(f.player, {"bundle_galaxy"}, "Bundle.")
	local bundle = f.notices[#f.notices].reveal
	expect(bundle and bundle.rarity == "Legendary", "A collection is revealed as the best thing it newly grants")
end

do
	local f = fixture(false)
	f.data:_Load(f.player)
	expect(f.data:Grant(f.player, {"skin_ninja", "mask_phantom", "skin_neonphantom"}), "Server entitlement grants populate the test wardrobe")
	expect(f.data:Equip(f.player, "skins", "skin_ninja"), "Owned premium skin equips")
	expect(f.data:Equip(f.player, "masks", "mask_phantom"), "Independent owned mask equips")
	expect(f.data:Equip(f.player, "skins", "skin_neonphantom"), "Switching an owned skin works")
	expect(f.data:Get(f.player).equipped.masks == "mask_phantom", "Skin changes cannot remove the selected mask")
	expect(f.data:_SaveRecord(f.data.records[f.player], true), "Outfit selection saves and releases the lease")
	local nextServer = fixture(false, f.store)
	nextServer.data:_Load(nextServer.player)
	local restored = nextServer.data:Get(nextServer.player)
	expect(restored.equipped.skins == "skin_neonphantom" and restored.equipped.masks == "mask_phantom", "New server restores both selected slots")
	expect(restored.owned.skin_ninja and restored.owned.skin_neonphantom and restored.owned.mask_phantom, "Wardrobe ownership survives the same round trip")
	expect(nextServer.data:Equip(nextServer.player, "skins", ""), "Use default look resolves to the free courier")
	expect(restored.equipped.skins == "skin_courier" and restored.equipped.masks == "mask_phantom", "Default-look action preserves the independent mask")
	expect(nextServer.data:Equip(nextServer.player, "masks", ""), "Mask can be unequipped independently")
	expect(nextServer.data:_SaveRecord(nextServer.data.records[nextServer.player], true), "Unequipped mask saves")
	local finalServer = fixture(false, f.store)
	finalServer.data:_Load(finalServer.player)
	expect(finalServer.data:Get(finalServer.player).equipped.masks == "", "An intentionally empty mask slot stays empty on rejoin")
end

-- Every kind of cosmetic equipment persists across a reconnect: outfit, mask, trail and emote, plus independent unequip.
do
	local f = fixture(false)
	f.data:_Load(f.player)
	local profile = f.data:Get(f.player)
	profile.coins = 30000
	for _, id in ipairs({"skin_bunny", "mask_cat", "trail_streaks", "emote_tiptoe", "trail_flame"}) do
		expect(f.data:_PurchaseWithCoins(f.player, id), "Coin purchase works: " .. id)
	end
	expect(f.data:Equip(f.player, "skins", "skin_bunny") and f.data:Equip(f.player, "masks", "mask_cat") and f.data:Equip(f.player, "trails", "trail_streaks") and f.data:Equip(f.player, "emotes", "emote_tiptoe"), "Owned outfit, mask, trail and emote all equip")
	expect(not f.data:Equip(f.player, "trails", "emote_tiptoe") and not f.data:Equip(f.player, "emotes", "trail_streaks"), "An item cannot be equipped into the wrong slot")
	expect(not f.data:Equip(f.player, "trails", "trail_gold") and not f.data:Equip(f.player, "emotes", "emote_royal"), "Unowned premium trails and emotes cannot be equipped")
	expect(f.data:_SaveRecord(f.data.records[f.player], true), "Equipment saves")
	local nextServer = fixture(false, f.store)
	nextServer.data:_Load(nextServer.player)
	local restored = nextServer.data:Get(nextServer.player)
	expect(restored.equipped.skins == "skin_bunny" and restored.equipped.masks == "mask_cat" and restored.equipped.trails == "trail_streaks" and restored.equipped.emotes == "emote_tiptoe", "A new server restores outfit, mask, trail and emote")
	expect(nextServer.data:Equip(nextServer.player, "trails", "trail_flame") and restored.equipped.trails == "trail_flame" and restored.equipped.emotes == "emote_tiptoe", "Switching trails leaves the emote alone")
	expect(nextServer.data:Equip(nextServer.player, "trails", "") and restored.equipped.trails == "", "A trail can be taken off")
	expect(nextServer.data:_SaveRecord(nextServer.data.records[nextServer.player], true), "Unequipped trail saves")
	local finalServer = fixture(false, f.store)
	finalServer.data:_Load(finalServer.player)
	expect(finalServer.data:Get(finalServer.player).equipped.trails == "" and finalServer.data:Get(finalServer.player).equipped.emotes == "emote_tiptoe", "An intentionally empty trail slot stays empty on rejoin")
end

-- Replaced items keep their owners; unknown ids from old saves are dropped.
do
	local f = fixture(false)
	local legacy = f.ctx.Rules.NewProfile(1700000000)
	legacy.owned.skin_midnight, legacy.owned.skin_removed_long_ago, legacy.equipped.skins = true, true, "skin_midnight"
	local clean = f.data:_Sanitize(legacy)
	expect(clean.owned.skin_trickster == true and clean.equipped.skins == "skin_trickster", "Midnight Magician owners keep a purple-and-gold look as Royal Trickster")
	expect(clean.owned.skin_midnight == nil and clean.owned.skin_removed_long_ago == nil, "Retired ids do not linger in the inventory")
end

-- Every premium item can be unlocked with coins today; Robux checkout stays off until a real pass exists.
do
	local f = fixture(true)
	f.data:_Load(f.player)
	local profile = f.data:Get(f.player)
	local premium = 0
	for id, item in pairs(Catalog.Items) do
		if item.currency == "Robux" then
			premium += 1
			expect(item.gamePassId == 0 and type(item.coinPrice) == "number" and item.coinPrice > 0 and item.coinPrice % 1 == 0, "Premium item ships unconfigured with a coin price: " .. id)
			profile.owned[id] = nil -- a collection bought earlier in this loop may already have granted it
			profile.coins = item.coinPrice - 1
			expect(not f.shop:Purchase(f.player, id) and not profile.owned[id] and profile.coins == item.coinPrice - 1, "One coin short buys nothing and charges nothing: " .. id)
			profile.coins = item.coinPrice + 7
			expect(f.shop:Purchase(f.player, id) and profile.owned[id] and profile.coins == 7, "Coins unlock the premium item and are charged exactly once: " .. id)
			for _, grantedId in ipairs(item.grants or {}) do expect(profile.owned[grantedId], "A collection grants every piece: " .. id .. "/" .. grantedId) end
			expect(f.shop:Purchase(f.player, id) and profile.coins == 7, "Buying again never charges twice: " .. id)
			if Catalog.IsEquippable(item.category) then expect(f.data:Equip(f.player, item.category, id), "A bought premium item equips: " .. id) end
		end
	end
	expect(premium >= 15 and f.marketplace.prompts == 0, "Coin unlocks never open a Robux prompt")
end

-- Robux checkout is explicit and only exists with a configured pass; coins keep working beside it.
do
	local f = fixture(true)
	f.data:_Load(f.player)
	local profile = f.data:Get(f.player)
	profile.coins = 50000
	local item = Catalog.Get("skin_galaxy")
	expect(not f.shop:Purchase(f.player, "skin_galaxy", "Robux") and f.marketplace.prompts == 0 and not profile.owned.skin_galaxy and profile.coins == 50000, "Asking for Robux with no pass configured is refused without prompt or charge")
	item.gamePassId = 987654
	expect(f.shop:Purchase(f.player, "skin_galaxy") and f.marketplace.prompts == 1 and not profile.owned.skin_galaxy, "With a pass configured the default is the Robux prompt, which grants nothing by itself")
	f.shop.lastPrompt[f.player] = nil
	f.shop.pending[f.player] = nil
	expect(f.shop:Purchase(f.player, "skin_galaxy", "Coins") and profile.owned.skin_galaxy and profile.coins == 50000 - item.coinPrice and f.marketplace.prompts == 1, "Coins still work beside a configured pass and do not prompt")
	item.gamePassId = 0
	local free = Catalog.Get("skin_pizza")
	profile.coins = 10
	expect(not f.shop:Purchase(f.player, "skin_pizza", "Robux") and not profile.owned.skin_pizza, "A coin item cannot be forced through the Robux path")
end

-- The server never sells a cosmetic that has no implementation behind it.
do
	local f = fixture(true)
	f.data:_Load(f.player)
	local profile = f.data:Get(f.player)
	profile.coins = 5000
	f.ctx.CosmeticDefs = {HasSkin = function(id) return id ~= "skin_bunny" end, HasMask = function() return true end, HasTrail = function() return true end, HasEmote = function() return true end}
	expect(not f.shop:Purchase(f.player, "skin_bunny") and not profile.owned.skin_bunny and profile.coins == 5000, "An unimplemented skin cannot be bought, and no coins are taken")
	expect(f.notices[#f.notices].text:find("not available yet"), "The player is told it is not available yet")
	expect(f.shop:Purchase(f.player, "skin_panda") and profile.owned.skin_panda and profile.coins == 5000 - Catalog.Get("skin_panda").price, "Implemented items buy normally")
	f.ctx.CosmeticDefs = nil
end

do
	local f = fixture(true)
	f.data:_Load(f.player)
	local paid = 0
	for id, item in pairs(Catalog.Items) do
		if item.currency == "Robux" then
			paid += 1
			local configuredId = item.gamePassId
			item.gamePassId = 0
			expect(not f.shop:Purchase(f.player, id), "No delivered paid item opens an unconfigured sale: " .. id)
			item.gamePassId = configuredId
		end
	end
	expect(paid > 0 and f.marketplace.prompts == 0, "Every pass entry stays disabled when its ID is zero")
end

-- Achievements pay once; login rewards are server-owned, once per UTC day, streak-aware.
do
	local f = fixture(true)
	f.data:_Load(f.player)
	local profile = f.data:Get(f.player)
	local record = f.data.records[f.player]
	local before = profile.coins
	profile.stats.tags = 55
	f.data:_Unlocks(record, true)
	expect(profile.achievements.tag_10 and profile.achievements.tag_50 and not profile.achievements.tag_200, "Tag achievements unlock by threshold")
	expect(profile.coins - before == 40 + 80, "Achievement coin rewards are granted")
	local coins = profile.coins
	f.data:_Unlocks(record, true)
	expect(profile.coins == coins, "Achievements never pay twice")
	expect(profile.owned.tag_bloom, "Tag milestone cosmetic still unlocks")

	local status = f.data:Snapshot(f.player).loginStatus
	expect(status.canClaim and status.day == 1 and status.coins == 25, "New profile can claim day one")
	coins = profile.coins
	expect(f.data:ClaimLogin(f.player) and profile.coins == coins + 25 and profile.login.streak == 1, "First claim pays day one")
	expect(not f.data:ClaimLogin(f.player) and profile.coins == coins + 25, "Second claim on the same UTC day is rejected")
	expect(not f.data:Snapshot(f.player).loginStatus.canClaim, "Claimed state is visible to the client")
	profile.login.lastClaim = Rules.DayKey(os.time() - 86400)
	profile.login.streak = 6
	coins = profile.coins
	expect(f.data:ClaimLogin(f.player) and profile.login.streak == 7 and profile.coins == coins + 150, "Consecutive days continue the streak to the day-seven bonus")
	profile.login.lastClaim = Rules.DayKey(os.time() - 3 * 86400)
	expect(f.data:ClaimLogin(f.player) and profile.login.streak == 1, "A missed day restarts the cycle")
	profile.login.lastClaim = Rules.DayKey(os.time() - 86400)
	profile.login.streak = 7
	local _, day = Rules.LoginReward(8)
	expect(f.data:ClaimLogin(f.player) and profile.login.streak == 8 and day == 1, "The cycle wraps after day seven")
	expect(not f.data:UpdateSettings(f.player, nil), "Invalid settings payload rejected")
	f.data:UpdateSettings(f.player, { tutorialDone = true, coins = true })
	expect(profile.settings.tutorialDone == true and profile.settings.coins == nil, "Settings only accept known flags")
	local normalized = Rules.NormalizeProfile({ login = { streak = -5, lastClaim = "'; drop" }, settings = { tutorialDone = "yes" } })
	expect(normalized.login.streak == 0 and normalized.login.lastClaim == "" and normalized.settings.tutorialDone == false, "Login state and tutorial flag are sanitized")
end


-- Developer-product coin packs: configured IDs only, one grant per PurchaseId, durable before success.
do
	local original = Catalog.Products[1]
	-- Unconfigured packs (productId 0) never prompt.
	local f = fixture(false)
	f.data:_Load(f.player)
	expect(not f.shop:PurchaseProduct(f.player, original.id) and (f.marketplace.productPrompts or 0) == 0, "Unconfigured coin pack must not prompt")
	expect(not f.shop:PurchaseProduct(f.player, "coins_nope") and not f.shop:PurchaseProduct(f.player, 12), "Unknown pack IDs are rejected")
	-- Temporarily configure a pack for the receipt flow.
	original.productId = 777
	local ok, err = pcall(function()
		expect(f.shop:PurchaseProduct(f.player, original.id) and f.marketplace.lastProduct == 777, "Configured pack prompts its developer product")
		expect(not f.shop:PurchaseProduct(f.player, original.id), "Rapid re-prompts are throttled")
		f.shop:Start()
		expect(type(f.marketplace.ProcessReceipt) == "function", "ShopService must own ProcessReceipt")
		local profile = f.data:Get(f.player)
		local before = profile.coins
		local receipt = { PlayerId = 42, ProductId = 777, PurchaseId = "abc-1" }
		expect(f.marketplace.ProcessReceipt(receipt) == "Granted", "A verified receipt is granted")
		expect(profile.coins == before + original.coins, "Coins are credited exactly once")
		expect(f.store.values.player_42 ~= nil and f.store.values.player_42.profile.coins == before + original.coins, "Success is only reported after the balance is saved")
		expect(f.marketplace.ProcessReceipt(receipt) == "Granted" and profile.coins == before + original.coins, "Replayed receipts do not pay twice")
		expect(f.marketplace.ProcessReceipt({ PlayerId = 42, ProductId = 999, PurchaseId = "abc-2" }) == "NotYet", "Unknown products are not marked processed")
		expect(f.marketplace.ProcessReceipt({ PlayerId = 7, ProductId = 777, PurchaseId = "abc-3" }) == "NotYet", "Players who left get the receipt again later")
		expect(f.marketplace.ProcessReceipt("junk") == "NotYet" and f.marketplace.ProcessReceipt({ PlayerId = 42, ProductId = 777 }) == "NotYet", "Malformed receipts are never granted")
		expect(profile.coins == before + original.coins, "Rejected receipts never change the balance")
		-- A failed save must not report success, and a retry must not double-credit.
		f.store.failBefore = true
		local retry = { PlayerId = 42, ProductId = 777, PurchaseId = "abc-4" }
		expect(f.marketplace.ProcessReceipt(retry) == "NotYet", "A receipt whose save failed is retried by Roblox")
		expect(profile.coins == before + original.coins * 2, "The balance is already credited in memory")
		f.store.failBefore = false
		expect(f.marketplace.ProcessReceipt(retry) == "Granted", "The retry completes once storage recovers")
		expect(profile.coins == before + original.coins * 2, "The retry must not credit a second time")
		expect(f.store.values.player_42.profile.coins == before + original.coins * 2, "The retried grant is durable")
		-- A profile that cannot save (live lease on another server) must never take Robux or grant unsaved coins.
		local locked = fixture(false)
		locked.store.values.player_42 = { _format = "CatchMeIfYouCan.profile.v1", profile = Rules.NewProfile(), session = { id = "another_server", expiresAt = os.time() + 180 } }
		locked.data:_Load(locked.player)
		locked.shop:Start()
		local lockedProfile = locked.data:Get(locked.player)
		local lockedBefore, lockedPrompts = lockedProfile.coins, locked.marketplace.productPrompts or 0
		expect(not locked.data:CanSave(locked.player), "A foreign lease means the profile cannot save")
		expect(not locked.shop:PurchaseProduct(locked.player, original.id) and (locked.marketplace.productPrompts or 0) == lockedPrompts, "No coin-pack prompt on a profile that cannot save")
		expect(locked.marketplace.ProcessReceipt({ PlayerId = 42, ProductId = 777, PurchaseId = "locked-1" }) == "NotYet" and lockedProfile.coins == lockedBefore, "A receipt on a non-saving profile is left for Roblox to re-send")
		expect(f.data:CanSave(f.player), "A normal profile can save")
		local snapshot = f.data:Snapshot(f.player)
		expect(snapshot.coins == profile.coins, "The client sees the new balance")
		-- Studio sessions are explicitly non-persistent, so a receipt there is grantable.
		local studio = fixture(true)
		studio.data:_Load(studio.player)
		studio.shop:Start()
		expect(studio.marketplace.ProcessReceipt({ PlayerId = 42, ProductId = 777, PurchaseId = "s-1" }) == "Granted", "Studio receipts grant into the session profile")
	end)
	original.productId = 0
	expect(ok, tostring(err))
end

print("Data and shop service tests passed: " .. checks .. " checks")
