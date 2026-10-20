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
	-- Skins are optional looks worn ON TOP of the player's own Roblox avatar (their face, hair, clothes and
	-- animations never change). Rarity tiers: Common = free, Rare = a few rounds of coins, Epic = a goal worth
	-- chasing (adds an aura), Legendary = the showpieces (adds a body treatment or aura). All cosmetic only.
	{id="skin_courier",category="skins",name="Original You",description="Just your own avatar, untouched. Everything else in here layers on top of you.",currency="Free",price=0,rarity="Common",accent={120,200,255}},
	{id="skin_rooftop",category="skins",name="Skate Kid",description="Yellow beanie with a pompom and a skateboard on your back. Reach level 5.",currency="Milestone",price=0,milestone={stat="level",value=5},rarity="Rare",accent={255,208,40}},
	{id="skin_pizza",category="skins",name="Pizza Courier",description="Red delivery cap and a giant pizza box on your back. Always on time, never caught.",currency="Coins",price=600,rarity="Rare",accent={235,60,50}},
	{id="skin_bunny",category="skins",name="Bunny Hop",description="Tall floppy ears, a fluffy tail and a big pink bow. Built for jumping.",currency="Coins",price=900,rarity="Rare",accent={255,150,200}},
	{id="skin_panda",category="skins",name="Bamboo Panda",description="A cozy panda hood and bamboo stalks tied to your back.",currency="Coins",price=1200,rarity="Rare",accent={110,200,90}},
	{id="skin_streetwear",category="skins",name="Streetwear Star",description="Cream bucket hat, chunky gold chain and a crossbody bag. Epic style.",currency="Coins",price=1800,rarity="Epic",accent={255,200,40}},
	{id="skin_candy",category="skins",name="Candy Pop",description="Ice-cream scoop hat, a giant lollipop and a sprinkle trail of sparkles.",currency="Coins",price=2600,rarity="Epic",accent={255,140,200}},
	{id="skin_cyber",category="skins",name="Jet Runner",description="Pilot goggles and a jet pack with real flames. Win 25 rounds to unlock it.",currency="Milestone",price=0,milestone={stat="wins",value=25},rarity="Epic",accent={255,140,40}},
	{id="skin_ninja",category="skins",name="Shadow Ninja",description="Red headband, katana on your back, a bold sash and shuriken at your hip.",currency="Robux",price=349,gamePassId=0,rarity="Epic",accent={230,40,50}},
	{id="skin_neonphantom",category="skins",name="Phantom Prankster",description="A purple hood and a flowing ghost cape that leaves spooky wisps behind you.",currency="Robux",price=399,gamePassId=0,rarity="Epic",accent={170,110,255}},
	{id="skin_midnight",category="skins",name="Midnight Magician",description="Starry top hat, a long flowing cape and a trail of magic stars.",currency="Robux",price=449,gamePassId=0,rarity="Epic",accent={150,90,230}},
	{id="skin_golden",category="skins",name="Golden Champion",description="You turn to solid gold. Crown, royal cape, champion belt and a shower of gold sparkles.",currency="Robux",price=599,gamePassId=0,rarity="Legendary",accent={255,200,50}},
	{id="skin_dragon",category="skins",name="Dragon Racer",description="Horns, big wings, a spiky tail and drifting embers. Win 60 rounds to earn it.",currency="Milestone",price=0,milestone={stat="wins",value=60},rarity="Legendary",accent={255,100,40}},
	-- Masks: every mask works with every skin and sits in front of your real face.
	{id="mask_street",category="masks",name="Street Bandana",description="A teal polka-dot bandana pulled up over your nose. Yours from the start.",currency="Free",price=0,rarity="Common",accent={40,196,190}},
	{id="mask_visor",category="masks",name="Cool Shades",description="Dark wraparound shades with a hot-pink frame.",currency="Coins",price=300,rarity="Rare",accent={255,90,160}},
	{id="mask_ninja",category="masks",name="Shinobi Wrap",description="A dark face wrap with a crimson stripe and a trailing tail.",currency="Coins",price=450,rarity="Rare",accent={226,48,58}},
	{id="mask_jester",category="masks",name="Jester Grin",description="Split-color jester face with bells, pointed brows and a huge toothy grin.",currency="Coins",price=900,rarity="Epic",accent={150,90,230}},
	{id="mask_pixel",category="masks",name="Pixel Visage",description="A game-screen face with a smiling pixel mouth and an antenna. Make 75 tags to unlock.",currency="Milestone",price=0,milestone={stat="tags",value=75},rarity="Epic",accent={80,235,160}},
	{id="mask_phantom",category="masks",name="Phantom Mask",description="An ivory phantom face with faceted cheeks, gold brows and temple filigree.",currency="Robux",price=149,gamePassId=0,rarity="Epic",accent={202,188,255}},
	{id="mask_kitsune",category="masks",name="Kitsune Mask",description="Sculpted fox ears, an ivory muzzle and vermilion markings.",currency="Robux",price=199,gamePassId=0,rarity="Epic",accent={255,119,104}},
	{id="mask_skull",category="masks",name="Gold Skull Mask",description="A gilded skull face with glowing red eyes and an engraved brow.",currency="Robux",price=349,gamePassId=0,rarity="Legendary",accent={255,204,91}},
	{id="trail_cyan",category="trails",name="Afterglow",description="A cyan ribbon that wakes up while you sprint.",currency="Coins",price=250,rarity="Rare",accent={87,238,237}},
	{id="trail_sunset",category="trails",name="Sunset Circuit",description="Warm coral light for runners who have earned 20 wins.",currency="Milestone",price=0,milestone={stat="wins",value=20},rarity="Epic",accent={255,140,117}},
	{id="trail_rainbow",category="trails",name="Prism Streak",description="A shifting rainbow ribbon behind every sprint.",currency="Coins",price=1500,rarity="Epic",accent={255,200,90}},
	{id="trail_flame",category="trails",name="Hot Foot",description="A blazing orange streak for fast feet.",currency="Coins",price=900,rarity="Rare",accent={255,150,50}},
	{id="trail_candy",category="trails",name="Candy Swirl",description="Bubblegum pink and mint ribbons. Sweet and speedy.",currency="Coins",price=1600,rarity="Epic",accent={255,140,200}},
	{id="tag_spark",category="tagEffects",name="Signal Burst",description="A crisp cyan pulse on every successful catch.",currency="Free",price=0,rarity="Common",accent={81,231,240}},
	{id="tag_bloom",category="tagEffects",name="Cherry Bloom",description="A coral burst of petals. Unlock after 50 tags.",currency="Milestone",price=0,milestone={stat="tags",value=50},rarity="Epic",accent={255,128,174}},
	{id="tag_star",category="tagEffects",name="Star Pop",description="A burst of golden stars on every catch.",currency="Coins",price=700,rarity="Rare",accent={255,208,64}},
	{id="tag_confetti",category="tagEffects",name="Party Pop",description="Rainbow confetti for every catch. Win 40 rounds to unlock.",currency="Milestone",price=0,milestone={stat="wins",value=40},rarity="Epic",accent={255,120,200}},
	{id="victory_wave",category="victories",name="Mall Salute",description="Wave to the whole mall from the winners' podium.",currency="Free",price=0,rarity="Common",accent={121,228,231}},
	{id="victory_spin",category="victories",name="Victory Lap",description="An animated podium turn with both arms up.",currency="Coins",price=350,rarity="Rare",accent={255,190,95}},
	{id="victory_flex",category="victories",name="Champion Flex",description="Strike a power pose and hold it for the crowd.",currency="Coins",price=600,rarity="Rare",accent={255,160,80}},
	{id="emote_wave",category="emotes",name="Hey, Shopper",description="A friendly wave in the lobby or after a round.",currency="Free",price=0,rarity="Common",accent={112,215,242}},
	{id="emote_dance",category="emotes",name="Food Court Shuffle",description="A quick shoulder-and-step dance for your crew.",currency="Coins",price=220,rarity="Rare",accent={221,151,255}},
	{id="name_rookie",category="nameplates",name="MALL NEWCOMER",description="Every mall legend starts somewhere.",currency="Free",price=0,rarity="Common",accent={172,193,208}},
	{id="name_survivor",category="nameplates",name="UNTOUCHABLE",description="Earn 10 wins and let your name do the talking.",currency="Milestone",price=0,milestone={stat="wins",value=10},rarity="Rare",accent={87,238,237}},
	{id="name_legend",category="nameplates",name="MALL LEGEND",description="Reach level 30. A badge of long-term mastery.",currency="Milestone",price=0,milestone={stat="level",value=30},rarity="Legendary",accent={255,204,91}},
	{id="name_regular",category="nameplates",name="MALL REGULAR",description="Finish 50 rounds. You know every shortcut by heart.",currency="Milestone",price=0,milestone={stat="rounds",value=50},rarity="Rare",accent={120,226,198}},
	{id="name_relentless",category="nameplates",name="RELENTLESS",description="Catch 100 runners. Nobody stays hidden for long.",currency="Milestone",price=0,milestone={stat="tags",value=100},rarity="Rare",accent={255,128,120}},
	{id="name_hotstreak",category="nameplates",name="HOT STREAK",description="Win 5 rounds in a row.",currency="Milestone",price=0,milestone={stat="bestStreak",value=5},rarity="Epic",accent={255,160,90}},
	{id="name_apex",category="nameplates",name="APEX HUNTER",description="Win 15 rounds as a hunter.",currency="Milestone",price=0,milestone={stat="hunterWins",value=15},rarity="Epic",accent={255,88,109}},
	{id="name_ghost",category="nameplates",name="GHOST RUNNER",description="Survive 3,000 seconds across your career.",currency="Milestone",price=0,milestone={stat="survived",value=3000},rarity="Epic",accent={190,170,255}},
	{id="bundle_night",category="bundles",name="Midnight Collection",description="Midnight Magician, Phantom Mask and Afterglow trail. Appearance only.",currency="Robux",price=649,gamePassId=0,grants={"skin_midnight","mask_phantom","trail_cyan"},rarity="Legendary",accent={190,110,255}},
	{id="bundle_ninja",category="bundles",name="Shadow Ninja Crew",description="Shadow Ninja, Shinobi Wrap and Sunset Circuit trail. Appearance only.",currency="Robux",price=549,gamePassId=0,grants={"skin_ninja","mask_ninja","trail_sunset"},rarity="Epic",accent={226,48,58}},
	{id="vip_founder",category="vip",name="Superstar Club",description="Streetwear Star, Jester Grin and Food Court Shuffle. No XP, speed or currency boosts.",currency="Robux",price=799,gamePassId=0,grants={"skin_streetwear","mask_jester","emote_dance"},rarity="Legendary",accent={255,204,91}},
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
-- Developer-product coin packs. Coins only ever buy cosmetics, so these are convenience, never power.
-- productId stays 0 until a real developer product is created; a 0 pack can be seen but never prompts.
Catalog.Products = {
	{id="coins_pocket",name="Pocket Change",coins=500,robux=49,productId=0,accent={255,208,64}},
	{id="coins_bag",name="Shopping Bag",coins=1200,robux=99,productId=0,accent={86,232,142}},
	{id="coins_haul",name="Mall Haul",coins=3200,robux=249,productId=0,accent={52,220,255}},
	{id="coins_mogul",name="Mall Mogul",coins=9000,robux=599,productId=0,accent={255,96,184}},
}
Catalog.ProductsById = {}
for _, product in ipairs(Catalog.Products) do Catalog.ProductsById[product.id] = product end
function Catalog.Product(id) return Catalog.ProductsById[id] end
function Catalog.ProductByRobloxId(productId)
	if type(productId) ~= "number" or productId <= 0 then return nil end
	for _, product in ipairs(Catalog.Products) do
		if product.productId == productId then return product end
	end
	return nil
end
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
