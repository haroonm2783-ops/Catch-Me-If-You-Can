-- Server-owned profiles. Every persistent write holds a renewable UpdateAsync lease.
-- Gameplay mutations never yield; saves take immutable snapshots and preserve newer edits.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local DataService = {}
DataService.__index = DataService

local FORMAT = "CatchMeIfYouCan.profile.v1"
local MAX_COUNTER = 1000000000
local function clone(value)
	if type(value) ~= "table" then return value end
	local copy = {}
	for key, child in pairs(value) do copy[key] = clone(child) end
	return copy
end

local function number(value, minimum, maximum)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return minimum end
	return math.clamp(math.floor(value), minimum, maximum)
end

local function add(value, amount)
	return number(value + amount, 0, MAX_COUNTER)
end

-- A future schema, malformed record, or unknown envelope is never replaced with defaults.
local function decode(raw)
	if raw == nil then return nil, nil end
	if type(raw) ~= "table" then return nil, "unsupported" end
	if raw._format == FORMAT then
		if type(raw.profile) ~= "table" or raw.profile.schemaVersion ~= 1 or type(raw.profile.stats) ~= "table"
			or type(raw.profile.owned) ~= "table" or type(raw.profile.equipped) ~= "table" then return nil, "unsupported" end
		if raw.session ~= nil then
			if type(raw.session) ~= "table" or type(raw.session.id) ~= "string"
				or type(raw.session.expiresAt) ~= "number" or raw.session.expiresAt ~= raw.session.expiresAt
				or math.abs(raw.session.expiresAt) == math.huge then return nil, "unsupported" end
		end
		return raw, nil
	end
	-- Supports the documented initial flat schema without accepting unrelated tables.
	if raw._format == nil and raw.schemaVersion == 1 and type(raw.stats) == "table"
		and type(raw.owned) == "table" and type(raw.equipped) == "table" then
		return { _format = FORMAT, profile = raw }, nil
	end
	return nil, "unsupported"
end

function DataService.new(ctx)
	local self = setmetatable({}, DataService)
	self.ctx = ctx
	self.records = {}
	self.sessionId = (game.JobId ~= "" and game.JobId or "studio") .. ":" .. HttpService:GenerateGUID(false)
	self.config = ctx.Config.Persistence
	self.sessionOnly = RunService:IsStudio() and self.config.UseStudioDataStores ~= true
	self.closing = false
	self.activeLoads = 0
	if not self.sessionOnly then
		local ok, store = pcall(function() return DataStoreService:GetDataStore(self.config.StoreName) end)
		if ok then self.store = store end
	end
	return self
end

function DataService:_Notice(player, text, kind)
	if player.Parent == Players then self.ctx.Remotes.Notice:FireClient(player, { kind = kind or "toast", text = text }) end
end

function DataService:_Sanitize(raw)
	local profile = self.ctx.Rules.NormalizeProfile(raw, os.time())
	for id in pairs(profile.owned) do
		if not self.ctx.Catalog.Get(id) then profile.owned[id] = nil end
	end
	for id in pairs(self.ctx.Catalog.DefaultOwned()) do profile.owned[id] = true end
	for category, id in pairs(profile.equipped) do
		local item = self.ctx.Catalog.Get(id)
		if not self.ctx.Catalog.IsEquippable(category) then
			profile.equipped[category] = nil
		elseif id ~= "" and (not item or item.category ~= category or not profile.owned[id]) then
			profile.equipped[category] = self.ctx.Catalog.DefaultEquipment[category] or ""
		end
	end
	return profile
end

function DataService:_Dirty(record)
	record.revision += 1
	if record.writable then record.saveMessage = "Changes pending autosave." end
end

function DataService:_RollDay(record)
	local day = self.ctx.Rules.DayKey(os.time())
	if record.profile.daily.day ~= day then
		record.profile.daily = { day = day, progress = { rounds = 0, tags = 0, survived = 0 }, claimed = {} }
		self:_Dirty(record)
	end
end

function DataService:_Leaderboard(player, profile)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then folder = Instance.new("Folder"); folder.Name = "leaderstats"; folder.Parent = player end
	local values = { Level = profile.level, Wins = profile.stats.wins, Tags = profile.stats.tags, Rating = profile.rating }
	for name, value in pairs(values) do
		local stat = folder:FindFirstChild(name)
		if not stat then stat = Instance.new("IntValue"); stat.Name = name; stat.Parent = folder end
		if stat:IsA("IntValue") then stat.Value = value end
	end
end

function DataService:_Unlocks(record, notify)
	local profile = record.profile
	local changed = false
	for _, definition in ipairs(self.ctx.Achievements.List) do
		local progress = profile.stats[definition.stat] or profile[definition.stat] or 0
		if progress >= definition.goal and not profile.achievements[definition.id] then
			profile.achievements[definition.id] = true
			profile.coins = add(profile.coins, definition.coins or 0)
			changed = true
			if notify then
				self:_Notice(record.player, "Achievement: " .. definition.name .. " · +" .. (definition.coins or 0) .. " coins", "unlock")
			end
		end
	end
	for id, item in pairs(self.ctx.Catalog.Items) do
		local milestone = item.milestone
		if milestone and not profile.owned[id] then
			local progress = profile.stats[milestone.stat] or profile[milestone.stat] or 0
			if progress >= milestone.value then
				profile.owned[id] = true
				for _, grantedId in ipairs(item.grants or {}) do
					if self.ctx.Catalog.Get(grantedId) then profile.owned[grantedId] = true end
				end
				changed = true
				if notify then self:_Notice(record.player, "Unlocked " .. item.name, "unlock") end
			end
		end
	end
	if changed then self:_Dirty(record) end
end

function DataService:_Load(player)
	if self.records[player] or self.closing then return end
	local record = {
		player = player, loaded = false, accepting = true, departed = false, writable = false,
		revision = 0, savedRevision = 0, awarded = {}, receipts = {}, saving = false,
		persistence = self.sessionOnly and "session" or "unavailable",
		lockId = self.sessionId .. ":" .. HttpService:GenerateGUID(false), writeSequence = 0,
	}
	self.records[player] = record
	self.activeLoads += 1
	local loadedProfile, receiptList
	local failure = "unavailable"
	if self.store then
		for attempt = 1, number(self.config.Retries or 3, 1, 5) do
			if self.closing or record.departed then break end
			local denied
			local ok, result = pcall(function()
				return self.store:UpdateAsync("player_" .. player.UserId, function(raw)
					denied = nil
					local current, decodeError = decode(raw)
					if decodeError then denied = decodeError; return nil end
					local now = os.time()
					if current and current.session and current.session.id ~= record.lockId
						and current.session.expiresAt > now then denied = "locked"; return nil end
					local profile = self:_Sanitize(current and current.profile or self.ctx.Rules.NewProfile(now))
					local receipts = {}
					for _, receipt in ipairs(current and type(current.receipts) == "table" and current.receipts or {}) do
						if type(receipt) == "string" and #receipt <= 160 and #receipts < 40 then table.insert(receipts, receipt) end
					end
					return {
						_format = FORMAT, profile = profile, receipts = receipts, updatedAt = now,
						session = { id = record.lockId, expiresAt = now + number(self.config.SessionLockSeconds or 180, 90, 600) },
					}
				end)
			end)
			if ok and result and not denied then
				loadedProfile, receiptList = result.profile, result.receipts
				record.writable = true
				record.persistence = "saved"
				record.saveMessage = "Saved."
				break
			end
			failure = denied or "unavailable"
			if denied then break end
			if attempt < number(self.config.Retries or 3, 1, 5) then task.wait(2 ^ (attempt - 1)) end
		end
	end
	if not loadedProfile then
		loadedProfile = self.ctx.Rules.NewProfile(os.time())
		if self.sessionOnly then
			record.saveMessage = "Studio session only. Progress resets when this test ends."
		elseif failure == "locked" then
			record.saveMessage = "Your profile is active on another server. This session will not save; rejoin after leaving that server."
		elseif failure == "unsupported" then
			record.saveMessage = "Stored data needs a newer compatible server. Existing data is protected; this session will not save."
		else
			record.saveMessage = "Data storage is unavailable. This session will not save; rejoin to retry loading."
		end
	end
	record.profile = self:_Sanitize(loadedProfile)
	record.receipts = receiptList or {}
	for _, receipt in ipairs(record.receipts) do record.awarded[receipt] = true end
	record.loaded = true
	self:_RollDay(record)
	self:_Unlocks(record, false)
	if record.departed or self.closing or player.Parent ~= Players then
		record.accepting = false
		self:_SaveRecord(record, true)
		if self.records[player] == record then self.records[player] = nil end
		-- BindToClose must keep waiting while a load that finished during shutdown
		-- is still saving and releasing its newly acquired lease.
		self.activeLoads -= 1
		return
	end
	self.activeLoads -= 1
	self:_Leaderboard(player, record.profile)
	player:SetAttribute("DataReady", true)
	self:Send(player)
	if record.persistence ~= "saved" then self:_Notice(player, record.saveMessage) end
	local cosmeticService = self.ctx.Services.CosmeticService
	if cosmeticService and player.Character then task.defer(function() cosmeticService:Apply(player) end) end
end

function DataService:Get(player)
	local record = self.records[player]
	return record and record.loaded and record.profile or nil
end

function DataService:Ready(player)
	local record = self.records[player]
	return record ~= nil and record.loaded and record.accepting and not self.closing
end

function DataService:Snapshot(player)
	local record = self.records[player]
	if not record or not record.loaded then return { loaded = false, persistence = "unavailable", saveMessage = "Loading profile…" } end
	self:_RollDay(record)
	local snapshot = clone(record.profile)
	snapshot.loaded = true
	snapshot.persistence = record.persistence
	snapshot.saveMessage = record.saveMessage
	snapshot.rank = self.ctx.Rules.Rank(snapshot.rating)
	local login = snapshot.login
	local nextStreak = self.ctx.Rules.NextLoginStreak(login, os.time())
	local reward, day = self.ctx.Rules.LoginReward(nextStreak or login.streak)
	snapshot.loginStatus = {
		streak = login.streak, canClaim = nextStreak ~= nil, day = day, coins = reward.coins, xp = reward.xp,
		cycle = self.ctx.Rules.LoginCycle,
	}
	snapshot.quests = {}
	for _, quest in ipairs(self.ctx.Rules.DailyQuests(snapshot.daily.day)) do
		table.insert(snapshot.quests, {
			id = quest.id, text = quest.text, progress = self.ctx.Rules.QuestProgress(snapshot, quest), goal = quest.goal,
			claimed = snapshot.daily.claimed[quest.id] == true, xp = quest.xp, coins = quest.coins,
		})
	end
	return snapshot
end

function DataService:Send(player)
	if player.Parent == Players then self.ctx.Remotes.Profile:FireClient(player, self:Snapshot(player)) end
end

function DataService:_AfterProgress(record, previousLevel)
	local profile = record.profile
	profile.level = self.ctx.Rules.LevelFromXP(profile.xp)
	self:_Unlocks(record, true)
	self:_Leaderboard(record.player, profile)
	self:Send(record.player)
	if profile.level > previousLevel then self:_Notice(record.player, "Level " .. profile.level .. " reached!", "level") end
end

function DataService:AwardRound(player, summary)
	if not self:Ready(player) or type(summary) ~= "table" or summary.practice == true then return false, "No progression in practice." end
	if (summary.role ~= "Hunter" and summary.role ~= "Runner") or type(summary.win) ~= "boolean"
		or type(summary.roundId) ~= "number" or summary.roundId ~= number(summary.roundId, 1, MAX_COUNTER) then return false, "Invalid round." end
	local record = self.records[player]
	local receipt = self.sessionId .. ":" .. tostring(summary.roundId)
	if record.awarded[receipt] then return false, "Round already rewarded." end
	local safe = {
		role = summary.role, win = summary.win, practice = false, roundId = summary.roundId,
		tags = summary.role == "Hunter" and number(summary.tags, 0, self.ctx.Config.Round.MaxPlayers) or 0,
		survived = number(summary.survived, 0, self.ctx.Config.Round.Duration),
	}
	local reward = self.ctx.Rules.RoundReward(safe, self.ctx.Config)
	-- Record receipt before changing balances; this section contains no yielding calls.
	record.awarded[receipt] = true
	table.insert(record.receipts, receipt)
	if #record.receipts > 40 then table.remove(record.receipts, 1) end
	self:_RollDay(record)
	local profile, previousLevel = record.profile, record.profile.level
	profile.coins = add(profile.coins, number(reward.coins, 0, MAX_COUNTER))
	profile.xp = add(profile.xp, number(reward.xp, 0, MAX_COUNTER))
	profile.rating = number(profile.rating + number(reward.rating, -1000, 1000), 0, MAX_COUNTER)
	profile.stats.rounds = add(profile.stats.rounds, 1)
	profile.stats.tags = add(profile.stats.tags, safe.tags)
	profile.stats.survived = add(profile.stats.survived, safe.survived)
	profile.daily.progress.rounds = add(profile.daily.progress.rounds, 1)
	profile.daily.progress.tags = add(profile.daily.progress.tags, safe.tags)
	profile.daily.progress.survived = add(profile.daily.progress.survived, safe.survived)
	if safe.win then
		profile.stats.wins = add(profile.stats.wins, 1)
		local stat = safe.role == "Hunter" and "hunterWins" or "runnerWins"
		profile.stats[stat] = add(profile.stats[stat], 1)
		profile.streak = add(profile.streak, 1)
		profile.bestStreak = math.max(profile.bestStreak, profile.streak)
	else profile.streak = 0 end
	self:_Dirty(record)
	self:_AfterProgress(record, previousLevel)
	task.defer(function() self:Save(player) end)
	return true
end

function DataService:Grant(player, ids, source)
	if not self:Ready(player) then return false, "Profile is not ready." end
	if type(ids) ~= "table" then return false, "Invalid grant." end
	local record = self.records[player]
	local changed = false
	for _, id in ipairs(ids) do
		local item = type(id) == "string" and self.ctx.Catalog.Get(id)
		if item then
			if not record.profile.owned[id] then record.profile.owned[id] = true; changed = true end
			for _, grantedId in ipairs(item.grants or {}) do
				if self.ctx.Catalog.Get(grantedId) and not record.profile.owned[grantedId] then
					record.profile.owned[grantedId] = true; changed = true
				end
			end
		end
	end
	if changed then
		self:_Dirty(record)
		self:Send(player)
		if source then self:_Notice(player, source, "unlock") end
		task.defer(function() self:Save(player) end)
	end
	return true, changed and "Granted." or "Already owned."
end

function DataService:_PurchaseWithCoins(player, id)
	if not self:Ready(player) then return false, "Profile is not ready." end
	local item = self.ctx.Catalog.Get(id)
	if not item or item.currency ~= "Coins" or type(item.price) ~= "number"
		or item.price ~= number(item.price, 0, MAX_COUNTER) then return false, "Item cannot be purchased with coins." end
	local record = self.records[player]
	local profile = record.profile
	if profile.owned[id] then return false, "You already own this cosmetic." end
	if profile.coins < item.price then return false, "You need " .. (item.price - profile.coins) .. " more coins." end
	-- Debit and ownership are one non-yielding transaction. Never trust a client price.
	profile.coins -= item.price
	profile.owned[id] = true
	for _, grantedId in ipairs(item.grants or {}) do
		if self.ctx.Catalog.Get(grantedId) then profile.owned[grantedId] = true end
	end
	self:_Dirty(record)
	self:Send(player)
	task.defer(function() self:Save(player) end)
	local suffix = record.writable and " Saving progress…" or " Session only; progress will not save."
	return true, "Purchased " .. item.name .. "." .. suffix
end

function DataService:Equip(player, category, id)
	if not self:Ready(player) then return false, "Profile is not ready." end
	if type(category) ~= "string" or type(id) ~= "string" or not self.ctx.Catalog.IsEquippable(category) then return false, "Invalid equipment slot." end
	if category == "skins" and id == "" then id = self.ctx.Catalog.DefaultEquipment.skins end
	local record = self.records[player]
	if id ~= "" then
		local item = self.ctx.Catalog.Get(id)
		if not item or item.category ~= category or not record.profile.owned[id] then return false, "You do not own that cosmetic." end
	end
	if record.profile.equipped[category] == id then return true end
	record.profile.equipped[category] = id
	self:_Dirty(record)
	self:Send(player)
	local cosmetics = self.ctx.Services.CosmeticService
	if cosmetics then cosmetics:Apply(player) end
	return true
end

function DataService:UpdateSettings(player, settings)
	if not self:Ready(player) or type(settings) ~= "table" then return false, "Profile is not ready." end
	local record = self.records[player]
	local changed = false
	for _, key in ipairs({ "music", "sfx", "reducedMotion", "cameraShake", "tutorialDone" }) do
		if type(settings[key]) == "boolean" and record.profile.settings[key] ~= settings[key] then
			record.profile.settings[key] = settings[key]; changed = true
		end
	end
	if changed then self:_Dirty(record); self:Send(player) end
	return true
end

function DataService:ClaimQuest(player, id)
	if not self:Ready(player) or type(id) ~= "string" then return false, "Profile is not ready." end
	local record = self.records[player]
	self:_RollDay(record)
	local profile = record.profile
	for _, quest in ipairs(self.ctx.Rules.DailyQuests(profile.daily.day)) do
		if quest.id == id then
			if profile.daily.claimed[id] then return false, "Reward already claimed." end
			if self.ctx.Rules.QuestProgress(profile, quest) < quest.goal then return false, "Quest is still in progress." end
			local previousLevel = profile.level
			profile.daily.claimed[id] = true
			profile.coins = add(profile.coins, quest.coins)
			profile.xp = add(profile.xp, quest.xp)
			self:_Dirty(record)
			self:_AfterProgress(record, previousLevel)
			self:_Notice(player, "Quest claimed: +" .. quest.coins .. " coins · +" .. quest.xp .. " XP", "unlock")
			task.defer(function() self:Save(player) end)
			return true
		end
	end
	return false, "Unknown quest."
end

-- One reward per UTC day; the server decides streak, amount and eligibility.
function DataService:ClaimLogin(player)
	if not self:Ready(player) then return false, "Profile is not ready." end
	local record = self.records[player]
	local profile = record.profile
	local streak = self.ctx.Rules.NextLoginStreak(profile.login, os.time())
	if not streak then return false, "Today's reward is already claimed." end
	local reward = self.ctx.Rules.LoginReward(streak)
	local previousLevel = profile.level
	profile.login = { streak = streak, lastClaim = self.ctx.Rules.DayKey(os.time()) }
	profile.coins = add(profile.coins, reward.coins)
	profile.xp = add(profile.xp, reward.xp)
	self:_Dirty(record)
	self:_AfterProgress(record, previousLevel)
	self:_Notice(player, "Daily reward: +" .. reward.coins .. " coins · +" .. reward.xp .. " XP · day " .. streak, "unlock")
	task.defer(function() self:Save(player) end)
	return true
end

function DataService:_SaveRecord(record, release)
	if not record.loaded or not record.writable or not self.store then return false, record.saveMessage end
	-- Concurrent autosave, reward, leave, and shutdown requests share this single writer.
	while record.saving do task.wait(0.05) end
	if not record.writable or record.released then return false, record.saveMessage end
	record.saving = true
	record.writeSequence += 1
	local writeId = record.lockId .. ":" .. record.writeSequence
	local revision = record.revision
	local snapshot = self:_Sanitize(clone(record.profile))
	local receipts = clone(record.receipts)
	local succeeded = false
	local denied
	for attempt = 1, number(self.config.Retries or 3, 1, 5) do
		local alreadyCommitted = false
		local ok, result = pcall(function()
			return self.store:UpdateAsync("player_" .. record.player.UserId, function(raw)
				denied = nil
				local current, decodeError = decode(raw)
				if decodeError then denied = decodeError; return nil end
				-- A response can be lost after a commit. Releasing twice must not look like
				-- a lost lease or cause a second write, even if the first response timed out.
				if current and current.lastWriteId == writeId then alreadyCommitted = true; return nil end
				if not current or not current.session or current.session.id ~= record.lockId then denied = "lease"; return nil end
				local now = os.time()
				return {
					_format = FORMAT, profile = snapshot, receipts = receipts, updatedAt = now, lastWriteId = writeId,
					session = not release and { id = record.lockId, expiresAt = now + number(self.config.SessionLockSeconds or 180, 90, 600) } or nil,
				}
			end)
		end)
		if ok and (result or alreadyCommitted) and not denied then succeeded = true; break end
		if denied then break end
		if attempt < number(self.config.Retries or 3, 1, 5) then task.wait(2 ^ (attempt - 1)) end
	end
	if succeeded then
		record.savedRevision = math.max(record.savedRevision, revision)
		record.persistence = "saved"
		record.saveMessage = record.revision == revision and "Saved." or "Changes pending autosave."
		if release then record.released = true; record.writable = false end
	else
		record.persistence = "unavailable"
		if denied then
			record.writable = false
			record.saveMessage = "Profile access changed on the server. Further changes will not save; rejoin to reload safely."
		else record.saveMessage = "Saving failed. Your latest changes are not saved; the server will retry." end
	end
	record.saving = false
	if not record.departed and not self.closing then self:Send(record.player) end
	return succeeded, record.saveMessage
end

function DataService:Save(player)
	local record = self.records[player]
	if not record then return false, "Profile is not loaded." end
	return self:_SaveRecord(record, false)
end

function DataService:Start()
	if self.started then return end
	self.started = true
	Players.PlayerAdded:Connect(function(player) task.spawn(function() self:_Load(player) end) end)
	Players.PlayerRemoving:Connect(function(player)
		local record = self.records[player]
		if not record then return end
		record.departed = true
		record.accepting = false
		if record.loaded then
			self:_SaveRecord(record, true)
			if self.records[player] == record then self.records[player] = nil end
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(function() self:_Load(player) end) end
	task.spawn(function()
		local interval = math.min(number(self.config.AutosaveSeconds or 60, 15, 120), number(self.config.SessionLockSeconds or 180, 90, 600) / 3)
		while not self.closing do
			task.wait(interval)
			if self.closing then break end
			for _, record in pairs(self.records) do
				if record.loaded and not record.departed then task.spawn(function() self:_SaveRecord(record, false) end) end
			end
		end
	end)
	game:BindToClose(function()
		self.closing = true
		local waiting = 0
		for _, record in pairs(self.records) do
			record.accepting = false
			if record.loaded then
				waiting += 1
				task.spawn(function() self:_SaveRecord(record, true); waiting -= 1 end)
			end
		end
		local deadline = os.clock() + 25
		while (waiting > 0 or self.activeLoads > 0) and os.clock() < deadline do task.wait(0.1) end
	end)
end

return DataService
