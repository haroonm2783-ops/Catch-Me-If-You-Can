-- Pure domain rules. Works in Roblox and in the standalone Luau test runner.
local Catalog = if script then require(script.Parent.Catalog) else require("./Catalog")
local Rules = {}
local MAX_NUMBER = 1000000000
local function integer(value, fallback, maximum)
	if type(value) ~= "number" or value ~= value or math.abs(value) == math.huge then return fallback end
	return math.clamp(math.floor(value), 0, maximum or MAX_NUMBER)
end
function Rules.HunterCount(count)
	count = integer(count, 0, 12)
	if count < 2 then return 0 end
	return if count >= 7 then 2 else 1
end
function Rules.XPForLevel(level)
	level = math.clamp(integer(level, 1, 10000), 1, 10000)
	return 100 * (level - 1) + 25 * (level - 1) * (level - 1)
end
function Rules.LevelFromXP(xp)
	xp = integer(xp, 0)
	return math.floor((-100 + math.sqrt(10000 + 100 * xp)) / 50) + 1
end
function Rules.Rank(rating)
	rating = integer(rating, 1000)
	if rating >= 1800 then return "Skyline Elite" end
	if rating >= 1500 then return "Diamond" end
	if rating >= 1250 then return "Gold" end
	if rating >= 1000 then return "Silver" end
	return "Bronze"
end
function Rules.DayKey(timestamp)
	return os.date("!%Y-%m-%d", timestamp or os.time())
end
function Rules.DailyQuests(_dayKey)
	return {
		{id="play_3",text="Finish 3 competitive rounds",stat="rounds",goal=3,xp=100,coins=40},
		{id="tag_5",text="Catch 5 runners",stat="tags",goal=5,xp=125,coins=50},
		{id="survive_120",text="Survive for 120 seconds",stat="survived",goal=120,xp=100,coins=40},
	}
end
-- Seven-day login cycle. Coins and a little XP only; nothing here affects chase outcomes.
Rules.LoginCycle = {
	{coins=25,xp=25}, {coins=30,xp=25}, {coins=40,xp=30}, {coins=50,xp=30},
	{coins=60,xp=40}, {coins=75,xp=40}, {coins=150,xp=75},
}
-- Returns nil when today's reward was already claimed, else the streak this claim would reach.
function Rules.NextLoginStreak(login, now)
	local today = Rules.DayKey(now)
	if login.lastClaim == today then return nil end
	local yesterday = Rules.DayKey((now or os.time()) - 86400)
	if login.lastClaim == yesterday then return login.streak + 1 end
	return 1
end
function Rules.LoginReward(streak)
	streak = math.max(1, integer(streak, 1))
	return Rules.LoginCycle[((streak - 1) % #Rules.LoginCycle) + 1], ((streak - 1) % #Rules.LoginCycle) + 1
end
function Rules.NewProfile(now)
	return {
		schemaVersion=1, coins=0, xp=0, level=1, rating=1000, streak=0, bestStreak=0,
		stats={rounds=0,wins=0,hunterWins=0,runnerWins=0,tags=0,survived=0,pickups=0,finds=0,closeCalls=0},
		owned=Catalog.DefaultOwned(), equipped=table.clone(Catalog.DefaultEquipment),
		settings={music=true,sfx=true,reducedMotion=false,cameraShake=true,tutorialDone=false},
		daily={day=Rules.DayKey(now),progress={rounds=0,tags=0,survived=0},claimed={}},
		achievements={},
		login={streak=0,lastClaim=""},
	}
end
function Rules.NormalizeProfile(raw, now)
	local result = Rules.NewProfile(now)
	if type(raw) ~= "table" then return result end
	for _, key in ipairs({"coins","xp","rating","streak","bestStreak"}) do
		result[key] = integer(raw[key], result[key])
	end
	result.level = Rules.LevelFromXP(result.xp)
	result.bestStreak = math.max(result.bestStreak, result.streak)
	if type(raw.stats) == "table" then
		for key in pairs(result.stats) do result.stats[key] = integer(raw.stats[key], 0) end
	end
	if type(raw.owned) == "table" then
		for id, owned in pairs(raw.owned) do
			if type(id) == "string" and owned == true then
				if Catalog.Get(id) then result.owned[id] = true
				elseif Catalog.Renamed and Catalog.Renamed[id] and Catalog.Get(Catalog.Renamed[id]) then result.owned[Catalog.Renamed[id]] = true end
			end
		end
	end
	if type(raw.equipped) == "table" then
		for category in pairs(result.equipped) do
			local id = raw.equipped[category]
			if type(id) == "string" and Catalog.Renamed and Catalog.Renamed[id] then id = Catalog.Renamed[id] end
			local item = type(id) == "string" and Catalog.Get(id)
			if id == "" then result.equipped[category] = ""
			elseif item and item.category == category and result.owned[id] then result.equipped[category] = id end
		end
	end
	if type(raw.settings) == "table" then
		for key in pairs(result.settings) do
			if type(raw.settings[key]) == "boolean" then result.settings[key] = raw.settings[key] end
		end
	end
	if type(raw.daily) == "table" and raw.daily.day == result.daily.day then
		if type(raw.daily.progress) == "table" then
			for key in pairs(result.daily.progress) do result.daily.progress[key] = integer(raw.daily.progress[key], 0) end
		end
		if type(raw.daily.claimed) == "table" then
			for _, quest in ipairs(Rules.DailyQuests(result.daily.day)) do
				if raw.daily.claimed[quest.id] == true then result.daily.claimed[quest.id] = true end
			end
		end
	end
	if type(raw.login) == "table" then
		result.login.streak = integer(raw.login.streak, 0, 100000)
		local last = raw.login.lastClaim
		if type(last) == "string" and (last == "" or last:match("^%d%d%d%d%-%d%d%-%d%d$")) then result.login.lastClaim = last end
	end
	if type(raw.achievements) == "table" then
		for id, value in pairs(raw.achievements) do
			if type(id) == "string" and #id < 80 and (value == true or type(value) == "number") then
				result.achievements[id] = if value == true then true else integer(value, 0)
			end
		end
	end
	return result
end
function Rules.QuestProgress(profile, quest)
	local progress = profile.daily and profile.daily.progress or {}
	return math.clamp(integer(progress[quest.stat], 0), 0, quest.goal)
end
function Rules.RoundReward(summary, config)
	if summary.practice then return {xp=0,coins=0,rating=0} end
	local progression = config.Progression or config
	local tags = if summary.role == "Hunter" then integer(summary.tags, 0, 10) else 0
	local survived = integer(summary.survived, 0, 180)
	local win = summary.win == true
	-- Runner objectives: coin pickups and close calls. Hunter objective: finding hidden runners.
	local pickups = if summary.role == "Runner" then integer(summary.pickups, 0, 25) else 0
	local closeCalls = if summary.role == "Runner" then integer(summary.closeCalls, 0, 5) else 0
	local finds = if summary.role == "Hunter" then integer(summary.finds, 0, 10) else 0
	return {
		xp=math.floor(progression.RoundXP + tags * progression.TagXP + survived * progression.SurvivalXPPerSecond + (if win then progression.WinXP else 0)
			+ pickups * (progression.PickupXP or 0) + closeCalls * (progression.CloseCallXP or 0) + finds * (progression.FindXP or 0)),
		coins=progression.RoundCoins + tags * progression.TagCoins + (if win then progression.WinCoins else 0) + pickups * (progression.PickupCoins or 0),
		rating=if win then 24 else -14,
		pickups=pickups, closeCalls=closeCalls, finds=finds, tags=tags, survived=survived,
	}
end
return Rules
