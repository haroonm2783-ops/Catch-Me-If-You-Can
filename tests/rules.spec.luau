local Rules = require("../src/shared/Rules")
local Catalog = require("../src/shared/Catalog")
local Config = require("../src/shared/Config")
local assertions = 0
local function equal(actual, expected, label)
	assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	assertions += 1
end
for count = 0, 12 do
	equal(Rules.HunterCount(count), if count < 2 then 0 elseif count < 7 then 1 else 2, "Hunter balance " .. count)
end
equal(Rules.HunterCount(-4),0,"Negative population")
equal(Rules.HunterCount(100),2,"Capacity clamp")
for level = 1, 100 do
	local threshold=Rules.XPForLevel(level)
	equal(Rules.LevelFromXP(threshold),level,"Level threshold "..level)
	if level > 1 then equal(Rules.LevelFromXP(threshold-1),level-1,"XP before threshold "..level) end
end
equal(Rules.LevelFromXP(0/0),1,"NaN XP")
equal(Rules.Rank(999),"Bronze","Bronze boundary")
equal(Rules.Rank(1000),"Silver","Silver boundary")
equal(Rules.Rank(1250),"Gold","Gold boundary")
equal(Rules.Rank(1500),"Diamond","Diamond boundary")
equal(Rules.Rank(1800),"Skyline Elite","Elite boundary")
local now = 1792022400
local first = Rules.NewProfile(now)
local second = Rules.NewProfile(now)
first.owned.skin_ninja=true
first.settings.sfx=false
equal(second.owned.skin_ninja,nil,"Independent ownership tables")
equal(second.settings.sfx,true,"Independent settings")
equal(second.equipped.skins,"skin_courier","Starter outfit")
local clean=Rules.NormalizeProfile({
	coins=-500,xp=500,level=999,rating=0/0,streak=3,bestStreak=1,
	owned={skin_ninja=true,unknown=true,mask_skull="true"},
	equipped={skins="skin_ninja",masks="mask_skull",trails="skin_ninja"},
	settings={music="false",sfx=false,reducedMotion=true,admin=true},
	stats={wins=math.huge,tags=-1,rounds=4.9},
	daily={day=Rules.DayKey(now),progress={rounds=999,tags=2},claimed={play_3=true,fake=true}},
},now)
equal(clean.coins,0,"Negative coins rejected")
equal(clean.level,Rules.LevelFromXP(500),"Level derived from XP")
equal(clean.rating,1000,"NaN rating rejected")
equal(clean.bestStreak,3,"Best streak invariant")
equal(clean.owned.unknown,nil,"Unknown item rejected")
equal(clean.owned.mask_skull,nil,"Nonboolean ownership rejected")
equal(clean.equipped.skins,"skin_ninja","Owned item restored")
equal(clean.equipped.masks,"","Unowned item not equipped")
equal(clean.equipped.trails,"","Cross-category equipment rejected")
equal(clean.settings.music,true,"Nonboolean setting ignored")
equal(clean.settings.sfx,false,"Boolean setting preserved")
equal(clean.settings.admin,nil,"Unknown setting rejected")
equal(clean.stats.wins,0,"Infinity rejected")
equal(clean.stats.tags,0,"Negative stat rejected")
equal(clean.stats.rounds,4,"Stats integral")
equal(clean.daily.claimed.fake,nil,"Unknown daily claim rejected")
local quests=Rules.DailyQuests(Rules.DayKey(now))
equal(Rules.QuestProgress(clean,quests[1]),3,"Quest progress capped")
local nextDay=Rules.NormalizeProfile(clean,now+86400)
equal(nextDay.daily.progress.rounds,0,"Daily progress resets")
equal(nextDay.daily.claimed.play_3,nil,"Daily claims reset")
equal(nextDay.coins,clean.coins,"Daily reset preserves currency")
local practice=Rules.RoundReward({practice=true,role="Hunter",win=true,tags=10},Config)
equal(practice.xp,0,"Practice no XP")
equal(practice.coins,0,"Practice no coins")
equal(practice.rating,0,"Practice no rank farming")
local hunter=Rules.RoundReward({role="Hunter",win=true,tags=2},Config)
equal(hunter.xp,175,"Hunter win XP")
equal(hunter.coins,49,"Hunter win coins")
equal(hunter.rating,24,"Win rating")
local infected=Rules.RoundReward({role="Hunter",win=false,tags=1,survived=60},Config)
equal(infected.xp,94,"Infected hunter keeps survival and tag XP")
equal(infected.coins,18,"Infected hunter coins")
local runner=Rules.RoundReward({role="Runner",win=false,tags=10,survived=90},Config)
equal(runner.xp,81,"Runner survival XP and no tag XP")
equal(runner.coins,12,"Runner participation coins")
equal(runner.rating,-14,"Loss rating")
local capped=Rules.RoundReward({role="Runner",win=true,survived=100000},Config)
equal(capped.xp,197,"Survival reward bounded")
local ids={}
for id,item in pairs(Catalog.Items) do
	equal(item.id,id,"Catalog key")
	assert(not ids[id],"Duplicate item"); ids[id]=true
	assert(#item.name>0 and #item.description>0,"Every item has readable presentation")
	assert(item.price>=0,"Nonnegative price")
	if item.currency=="Robux" then equal(type(item.gamePassId)=="number" and item.gamePassId>=0 and item.gamePassId%1==0,true,"Pass ID is configurable nonnegative integer") end
	if item.grants then for _, grant in ipairs(item.grants) do assert(Catalog.Get(grant),"Bundle grants existing item") end end
	if item.milestone then assert(item.milestone.value>0,"Positive milestone") end
end
for category,id in pairs(Catalog.DefaultEquipment) do
	if id~="" then
		equal(Catalog.Get(id).category,category,"Starter category")
		equal(Catalog.DefaultOwned()[id],true,"Starter item owned")
	end
end
equal(Catalog.IsEquippable("bundles"),false,"Bundles cannot equip")
equal(Catalog.IsEquippable("skins"),true,"Skins can equip")
equal(#Catalog.ForCategory("skins"),14,"Fourteen skins (including the untouched default)")
equal(#Catalog.ForCategory("masks"),12,"Twelve masks")
equal(#Catalog.ForCategory("trails"),10,"Ten trails")
equal(#Catalog.ForCategory("emotes"),7,"Seven emotes")
equal(#Catalog.ForCategory("tones")+#Catalog.ForCategory("hairColors"),0,"Players keep their own skin tone and hair")
-- Every premium item is cosmetic: only an appearance category, never a gameplay stat.
local rarities,free,earned,coins,robux={},0,0,0,0
for _,item in pairs(Catalog.Items) do
	rarities[item.rarity]=(rarities[item.rarity] or 0)+1
	if item.currency=="Free" then free+=1 elseif item.currency=="Milestone" then earned+=1 elseif item.currency=="Coins" then coins+=1 elseif item.currency=="Robux" then robux+=1 end
	equal(item.stat==nil and item.speed==nil and item.advantage==nil,true,"Catalog entries carry no gameplay modifiers: "..item.id)
end
equal(rarities.Common>=3 and rarities.Rare>=3 and rarities.Epic>=3 and rarities.Legendary>=2,true,"All four rarity tiers are populated")
equal(earned>=8 and coins>=8 and free>=6,true,"Meaningful free and earnable cosmetics exist beside Robux items")
local total=0
for _ in pairs(Catalog.Items) do total+=1 end
equal(robux>=8 and robux<total*0.35,true,"Robux items are a premium minority")
for _,id in ipairs({"skin_courier","skin_rooftop","skin_streetwear","skin_cyber"}) do equal(Catalog.Get(id).currency~="Robux",true,"Skin can be earned without Robux: "..id) end
print("PASS: "..assertions.." economy, profile, rank, quest and catalog assertions")
