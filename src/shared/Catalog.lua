-- Original cosmetics, all cosmetic-only. Enter real experience pass IDs here.
-- The Robux price shown here is a design price: set the matching price in Creator
-- Dashboard. Roblox's purchase prompt remains the authority for charged prices.
local Catalog = {}
Catalog.Categories = {
	{id="skins",label="Skins"}, {id="masks",label="Masks"},
	{id="trails",label="Trails"}, {id="emotes",label="Emotes"},
	{id="tagEffects",label="Tag effects"}, {id="victories",label="Victories"},
	{id="nameplates",label="Nameplates"}, {id="bundles",label="Bundles"},
	{id="vip",label="VIP"},
}
local entries = {
	{id="skin_courier",category="skins",name="Midnight Courier",description="A cropped teal jacket, dropped hood, coral sling bag, cargo pockets and cream-soled sneakers.",currency="Free",price=0,rarity="Common",accent={71,179,183}},
	{id="skin_rooftop",category="skins",name="Rooftop Ace",description="A blue windbreaker, coral scarf, raised goggles and climber wraps. Reach level 5.",currency="Milestone",price=0,milestone={stat="level",value=5},rarity="Rare",accent={73,234,219}},
	{id="skin_gardener",category="skins",name="Skygarden Keeper",description="A ribboned straw hat, utility apron, seed pockets and a rooftop flower.",currency="Coins",price=650,rarity="Rare",accent={152,219,151}},
	{id="skin_shadow",category="skins",name="Shadow Runner",description="A midnight hood, layered shoulders, split cape and violet route harness.",currency="Robux",price=299,gamePassId=0,rarity="Epic",accent={164,129,255}},
	{id="skin_golden",category="skins",name="Golden Phantom",description="An ivory tailcoat, gilded lapels, Art Deco shoulder fans and a diamond brooch.",currency="Robux",price=599,gamePassId=0,rarity="Legendary",accent={255,204,91}},
	{id="skin_neon",category="skins",name="Neon Outlaw",description="A quilted violet jacket, cyan piping, wrist displays and a luminous tech pack.",currency="Robux",price=399,gamePassId=0,rarity="Epic",accent={62,233,255}},
	{id="skin_crimson",category="skins",name="Crimson Hunter",description="Angular crimson pauldrons, armored jacket hems, gauntlets and a glowing chest core.",currency="Robux",price=499,gamePassId=0,rarity="Epic",accent={255,88,109}},
	{id="mask_street",category="masks",name="Street Signal",description="A charcoal respirator with silver side filters and amber vents. Yours from the start.",currency="Free",price=0,rarity="Common",accent={88,228,206}},
	{id="mask_visor",category="masks",name="Prism Visor",description="A luminous wraparound lens with independent temple plates.",currency="Coins",price=180,rarity="Rare",accent={94,218,255}},
	{id="mask_phantom",category="masks",name="Phantom Mask",description="An ivory phantom face with faceted cheeks, gold brows and temple filigree.",currency="Robux",price=149,gamePassId=0,rarity="Epic",accent={202,188,255}},
	{id="mask_kitsune",category="masks",name="Kitsune Mask",description="Sculpted fox ears, an ivory muzzle and vermilion markings.",currency="Robux",price=199,gamePassId=0,rarity="Epic",accent={255,119,104}},
	{id="mask_skull",category="masks",name="Gold Skull Mask",description="A gilded skull face with raised socket rims, engraved brow and dark tooth gaps.",currency="Robux",price=349,gamePassId=0,rarity="Legendary",accent={255,204,91}},
	{id="trail_cyan",category="trails",name="Afterglow",description="A restrained cyan ribbon that wakes up while you sprint.",currency="Coins",price=250,rarity="Rare",accent={87,238,237}},
	{id="trail_sunset",category="trails",name="Sunset Circuit",description="Warm coral light for runners who have earned 20 wins.",currency="Milestone",price=0,milestone={stat="wins",value=20},rarity="Epic",accent={255,140,117}},
	{id="tag_spark",category="tagEffects",name="Signal Burst",description="A crisp cyan pulse on every successful catch.",currency="Free",price=0,rarity="Common",accent={81,231,240}},
	{id="tag_bloom",category="tagEffects",name="Cherry Bloom",description="A coral burst of city petals. Unlock after 50 tags.",currency="Milestone",price=0,milestone={stat="tags",value=50},rarity="Epic",accent={255,128,174}},
	{id="victory_wave",category="victories",name="City Salute",description="Wave to the whole skyline from the winners' podium.",currency="Free",price=0,rarity="Common",accent={121,228,231}},
	{id="victory_spin",category="victories",name="Victory Lap",description="An animated podium turn with neon confetti.",currency="Coins",price=350,rarity="Rare",accent={255,190,95}},
	{id="emote_wave",category="emotes",name="Hey, Neighbor",description="A friendly wave in the lobby or after a round.",currency="Free",price=0,rarity="Common",accent={112,215,242}},
	{id="emote_dance",category="emotes",name="Rooftop Shuffle",description="A quick shoulder-and-step dance for your crew.",currency="Coins",price=220,rarity="Rare",accent={221,151,255}},
	{id="name_rookie",category="nameplates",name="CITY NEWCOMER",description="Every rooftop legend starts somewhere.",currency="Free",price=0,rarity="Common",accent={172,193,208}},
	{id="name_survivor",category="nameplates",name="UNTOUCHABLE",description="Earn 10 wins and let your name do the talking.",currency="Milestone",price=0,milestone={stat="wins",value=10},rarity="Rare",accent={87,238,237}},
	{id="name_legend",category="nameplates",name="SKYLINE LEGEND",description="Reach level 30. A badge of long-term city mastery.",currency="Milestone",price=0,milestone={stat="level",value=30},rarity="Legendary",accent={255,204,91}},
	{id="bundle_night",category="bundles",name="Nightfall Collection",description="Shadow Runner, Phantom Mask and Afterglow trail. Appearance only.",currency="Robux",price=649,gamePassId=0,grants={"skin_shadow","mask_phantom","trail_cyan"},rarity="Legendary",accent={164,129,255}},
	{id="vip_founder",category="vip",name="Neon Social Club",description="Neon Outlaw, Prism Visor and Rooftop Shuffle. No XP, speed or currency boosts.",currency="Robux",price=699,gamePassId=0,grants={"skin_neon","mask_visor","emote_dance"},rarity="Legendary",accent={255,204,91}},
}
Catalog.Items = {}
for order, item in ipairs(entries) do
	item.order = order
	Catalog.Items[item.id] = item
end
Catalog.DefaultEquipment = {
	skins="skin_courier", masks="", trails="", tagEffects="tag_spark",
	victories="victory_wave", emotes="emote_wave", nameplates="name_rookie",
}
function Catalog.Get(id) return Catalog.Items[id] end
function Catalog.ForCategory(category)
	local result = {}
	for _, item in ipairs(entries) do
		if item.category == category then table.insert(result, item) end
	end
	return result
end
function Catalog.IsEquippable(category)
	return Catalog.DefaultEquipment[category] ~= nil
end
function Catalog.DefaultOwned()
	local owned = {}
	for _, item in ipairs(entries) do
		if item.currency == "Free" then owned[item.id] = true end
	end
	return owned
end
return Catalog
