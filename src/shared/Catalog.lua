-- Original cosmetics, all cosmetic-only.
--
-- OWNER: paste your real Roblox IDs into PASS_IDS and PRODUCT_IDS below (docs/MONETIZATION.md lists exactly what to
-- create in the Creator Dashboard). A value of 0 means "not configured": that Robux checkout stays OFF. Premium
-- Robux items are still obtainable with coins (`coinPrice`), so nothing is locked while a pass is unconfigured.
-- The Robux `price` shown here is a design price: set the matching price in the Creator Dashboard. Roblox's
-- purchase prompt remains the authority for charged prices.
local PASS_IDS = {
	-- Game Passes (one per premium item and collection). Permanent ownership.
	skin_ninja = 0, skin_neonphantom = 0, skin_trickster = 0, skin_galaxy = 0, skin_golden = 0,
	mask_phantom = 0, mask_kitsune = 0, mask_skull = 0, mask_astral = 0,
	trail_shadow = 0, trail_gold = 0, trail_stardust = 0, emote_royal = 0,
	bundle_shadow = 0, bundle_phantom = 0, bundle_trickster = 0, bundle_galaxy = 0, vip_founder = 0,
}
local PRODUCT_IDS = {
	-- Developer Products (coin packs; consumable, granted from the receipt).
	coins_pocket = 0, coins_bag = 0, coins_haul = 0, coins_mogul = 0,
}
local Catalog = {}
Catalog.Categories = {
	{id="skins",label="Skins"}, {id="masks",label="Masks"},
	{id="trails",label="Trails"}, {id="emotes",label="Emotes"},
	{id="tagEffects",label="Tag effects"}, {id="victories",label="Victories"},
	{id="nameplates",label="Nameplates"}, {id="bundles",label="Bundles"},
	{id="vip",label="VIP"},
}
local entries = {
	-- Skins are optional costumes worn ON TOP of the player's own Roblox avatar (their face, head, proportions and
	-- animations never change; their own clothes are tucked away while a costume is worn). Rarity tiers: Common and
	-- Rare = coins or a small goal, Epic = a bigger goal or a premium pick (adds an aura), Legendary = the showpieces.
	-- Every skin is built from original parts in Appearance.lua. All cosmetic only: no speed, tag, hide, XP or coin effect.
	{id="skin_courier",category="skins",name="Original You",description="Just your own avatar, untouched. Everything else in here layers on top of you.",currency="Free",price=0,rarity="Common",accent={120,200,255}},
	{id="skin_pizza",category="skins",name="Pizza Courier",description="Red delivery cap and polo, white sneakers and a giant pizza box on your back. Always on time, never caught.",currency="Coins",price=500,rarity="Common",accent={235,60,50}},
	{id="skin_rooftop",category="skins",name="Skate Kid",description="Yellow hoodie, denim, knee pads, a pompom beanie and a skateboard on your back. Reach level 5.",currency="Milestone",price=0,milestone={stat="level",value=5},rarity="Rare",accent={255,208,40}},
	{id="skin_bunny",category="skins",name="Bunny Hop",description="A fluffy white bunny suit with floppy ears, pink paws and slippers, a cotton tail and a big bow.",currency="Coins",price=900,rarity="Rare",accent={255,150,200}},
	{id="skin_panda",category="skins",name="Bamboo Panda",description="A cozy panda onesie with a hood and ears, and bamboo stalks tied to your back.",currency="Coins",price=1200,rarity="Rare",accent={110,200,90}},
	{id="skin_streetwear",category="skins",name="Street Legend",description="Varsity jacket, cargo pants, chunky sneakers, a bucket hat, gold chain and crossbody bag, plus a gold dust shimmer.",currency="Coins",price=1800,rarity="Epic",accent={255,200,40}},
	{id="skin_cyber",category="skins",name="Jet Runner",description="An orange flight suit with steel boots and gauntlets, aviator goggles and a jet pack with real flames. Win 25 rounds to unlock it.",currency="Milestone",price=0,milestone={stat="wins",value=25},rarity="Epic",accent={255,140,40}},
	{id="skin_candy",category="skins",name="Candy Pop",description="A peppermint outfit with polka-dot pants, cotton-candy shoulders, an ice-cream hat and a giant lollipop, with a sprinkle shimmer.",currency="Coins",price=2600,rarity="Epic",accent={255,140,200}},
	{id="skin_ninja",category="skins",name="Shadow Runner",description="A charcoal hooded parkour kit with violet trim, wrapped shins, kunai pouch and a long streaming scarf, with drifting shadow smoke.",currency="Robux",price=349,gamePassId=0,coinPrice=2800,rarity="Epic",accent={150,90,235}},
	{id="skin_neonphantom",category="skins",name="Mall Phantom",description="Black tailcoat with a crimson-lined opera cape, white gloves, spats and a top hat, followed by haunting wisps.",currency="Robux",price=399,gamePassId=0,coinPrice=3200,rarity="Epic",accent={196,36,60}},
	{id="skin_trickster",category="skins",name="Royal Trickster",description="A purple-and-gold harlequin suit, ruffled collar, curled belled shoes and a three-horned jester crown, with a confetti shimmer.",currency="Robux",price=449,gamePassId=0,coinPrice=3400,rarity="Epic",accent={132,66,224}},
	{id="skin_galaxy",category="skins",name="Galaxy Escape Artist",description="A midnight star-patterned suit, a three-layer cosmic cape, a top hat with a ringed planet, gold trim and a drifting stardust aura.",currency="Robux",price=699,gamePassId=0,coinPrice=7500,rarity="Legendary",accent={140,110,255}},
	{id="skin_golden",category="skins",name="Golden Champion",description="You turn to solid gold: crown, chest plate, gauntlets, boots, royal cape and champion belt, in a shower of gold sparkles.",currency="Robux",price=599,gamePassId=0,coinPrice=6500,rarity="Legendary",accent={255,200,50}},
	{id="skin_dragon",category="skins",name="Dragon Racer",description="Scale armor with belly plates and claws, horns, huge wings, a spiked tail and drifting embers. Win 60 rounds to earn it.",currency="Milestone",price=0,milestone={stat="wins",value=60},rarity="Legendary",accent={255,100,40}},
	-- Masks: every mask works with every skin and sits in front of your real face.
	{id="mask_street",category="masks",name="Street Bandana",description="A teal polka-dot bandana pulled up over your nose. Yours from the start.",currency="Free",price=0,rarity="Common",accent={40,196,190}},
	{id="mask_visor",category="masks",name="Cool Shades",description="Dark wraparound shades with a hot-pink frame.",currency="Coins",price=300,rarity="Rare",accent={255,90,160}},
	{id="mask_smile",category="masks",name="Big Smile",description="A cartoon smiley with rosy cheeks and an enormous grin.",currency="Coins",price=400,rarity="Rare",accent={255,214,40}},
	{id="mask_ninja",category="masks",name="Shadow Wrap",description="A dark face wrap with a crimson stripe and a trailing tail.",currency="Coins",price=450,rarity="Rare",accent={226,48,58}},
	{id="mask_cat",category="masks",name="Kitty Cat",description="A cartoon cat face with a pink nose, big eyes, whiskers and pointed ears.",currency="Coins",price=600,rarity="Rare",accent={255,156,52}},
	{id="mask_jester",category="masks",name="Jester Grin",description="Split-color jester face with bells, diamond cheeks and a huge toothy grin.",currency="Coins",price=900,rarity="Epic",accent={150,90,230}},
	{id="mask_pumpkin",category="masks",name="Jack-o'-Lantern",description="A carved pumpkin face with a jagged grin and a green stem. Spooky and silly.",currency="Coins",price=1100,rarity="Epic",accent={255,132,30}},
	{id="mask_pixel",category="masks",name="Retro Bot",description="A game-screen robot face with a pixel smile and an antenna. Make 75 tags to unlock.",currency="Milestone",price=0,milestone={stat="tags",value=75},rarity="Epic",accent={80,235,160}},
	{id="mask_phantom",category="masks",name="Phantom Half-Mask",description="An ivory opera half-mask with gold brow, trim and a music note.",currency="Robux",price=149,gamePassId=0,coinPrice=1200,rarity="Epic",accent={202,188,255}},
	{id="mask_kitsune",category="masks",name="Kitsune Mask",description="Sculpted fox ears, an ivory muzzle and vermilion markings.",currency="Robux",price=199,gamePassId=0,coinPrice=1500,rarity="Epic",accent={255,119,104}},
	{id="mask_skull",category="masks",name="Gold Skull Mask",description="A gilded skull face with glowing red eyes and an engraved brow.",currency="Robux",price=349,gamePassId=0,coinPrice=3000,rarity="Legendary",accent={255,204,91}},
	{id="mask_astral",category="masks",name="Astral Visor",description="A star-filled wraparound visor with a golden frame and a tiny ringed planet.",currency="Robux",price=399,gamePassId=0,coinPrice=3500,rarity="Legendary",accent={120,80,220}},
	-- Trails: every trail is drawn by real Trail and ParticleEmitter objects (Trails.lua), switched on while you sprint.
	{id="trail_cyan",category="trails",name="Aqua Dash",description="A cool cyan ribbon that wakes up while you sprint.",currency="Coins",price=250,rarity="Rare",accent={87,238,237}},
	{id="trail_streaks",category="trails",name="Speed Streaks",description="Three colorful racing stripes, red, gold and sky blue, streaming behind you.",currency="Coins",price=600,rarity="Rare",accent={255,196,70}},
	{id="trail_flame",category="trails",name="Hot Foot",description="A blazing orange streak with drifting embers.",currency="Coins",price=900,rarity="Rare",accent={255,150,50}},
	{id="trail_rainbow",category="trails",name="Prism Streak",description="A shifting rainbow ribbon behind every sprint.",currency="Coins",price=1500,rarity="Epic",accent={255,200,90}},
	{id="trail_candy",category="trails",name="Candy Swirl",description="Twin bubblegum-pink and mint ribbons with a sprinkle of sparkles.",currency="Coins",price=1600,rarity="Epic",accent={255,140,200}},
	{id="trail_sparks",category="trails",name="Electric Sparks",description="A crackling blue-white ribbon that throws bright sparks as you run.",currency="Coins",price=2200,rarity="Epic",accent={150,200,255}},
	{id="trail_sunset",category="trails",name="Sunset Glide",description="Warm gold-to-coral light with glints, for runners who have earned 20 wins.",currency="Milestone",price=0,milestone={stat="wins",value=20},rarity="Epic",accent={255,140,117}},
	{id="trail_shadow",category="trails",name="Shadow Smoke",description="A dark violet ribbon with puffs of drifting shadow smoke.",currency="Robux",price=249,gamePassId=0,coinPrice=2000,rarity="Epic",accent={96,66,150}},
	{id="trail_gold",category="trails",name="Golden Footsteps",description="Glittering gold footprints stamped on the floor behind every stride, and golden glitter in the air.",currency="Robux",price=299,gamePassId=0,coinPrice=4500,rarity="Legendary",accent={255,200,60}},
	{id="trail_stardust",category="trails",name="Cosmic Stardust",description="A blue-to-pink ribbon, twinkling stars and a soft nebula glow.",currency="Robux",price=349,gamePassId=0,coinPrice=5000,rarity="Legendary",accent={150,130,255}},
	{id="tag_spark",category="tagEffects",name="Signal Burst",description="A crisp cyan pulse on every successful catch.",currency="Free",price=0,rarity="Common",accent={81,231,240}},
	{id="tag_bloom",category="tagEffects",name="Cherry Bloom",description="A coral burst of petals. Unlock after 50 tags.",currency="Milestone",price=0,milestone={stat="tags",value=50},rarity="Epic",accent={255,128,174}},
	{id="tag_star",category="tagEffects",name="Star Pop",description="A burst of golden stars on every catch.",currency="Coins",price=700,rarity="Rare",accent={255,208,64}},
	{id="tag_confetti",category="tagEffects",name="Party Pop",description="Rainbow confetti for every catch. Win 40 rounds to unlock.",currency="Milestone",price=0,milestone={stat="wins",value=40},rarity="Epic",accent={255,120,200}},
	{id="victory_wave",category="victories",name="Mall Salute",description="Wave to the whole mall from the winners' podium.",currency="Free",price=0,rarity="Common",accent={121,228,231}},
	{id="victory_spin",category="victories",name="Victory Lap",description="An animated podium turn with both arms up.",currency="Coins",price=350,rarity="Rare",accent={255,190,95}},
	{id="victory_flex",category="victories",name="Champion Flex",description="Strike a power pose and hold it for the crowd.",currency="Coins",price=600,rarity="Rare",accent={255,160,80}},
	{id="emote_wave",category="emotes",name="Hey, Shopper",description="A friendly wave. Plays on you in the lobby and on the results screen.",currency="Free",price=0,rarity="Common",accent={112,215,242}},
	{id="emote_dance",category="emotes",name="Food Court Shuffle",description="A bouncy hop-and-pump dance for your crew.",currency="Coins",price=220,rarity="Rare",accent={221,151,255}},
	{id="emote_tiptoe",category="emotes",name="Sneaky Tiptoe",description="Crouch, shush the crowd and tiptoe away with a suspicious glance.",currency="Coins",price=400,rarity="Rare",accent={160,190,255}},
	{id="emote_chicken",category="emotes",name="Mall Chicken",description="Flap, strut and peck like the proudest chicken in the food court.",currency="Coins",price=650,rarity="Rare",accent={255,200,90}},
	{id="emote_drama",category="emotes",name="Dramatic Faint",description="Hand to the forehead, a theatrical swoon onto the floor, then a brave recovery.",currency="Coins",price=1100,rarity="Epic",accent={235,120,170}},
	{id="emote_flip",category="emotes",name="Showoff Flip",description="A big backflip that lands with arms up and a burst of gold.",currency="Coins",price=1500,rarity="Epic",accent={255,215,90}},
	{id="emote_royal",category="emotes",name="Royal Twirl",description="A graceful spin, a deep bow and a flourish, with a shower of sparkles.",currency="Robux",price=299,gamePassId=0,coinPrice=2500,rarity="Legendary",accent={255,210,90}},
	{id="name_rookie",category="nameplates",name="MALL NEWCOMER",description="Every mall legend starts somewhere.",currency="Free",price=0,rarity="Common",accent={172,193,208}},
	{id="name_survivor",category="nameplates",name="UNTOUCHABLE",description="Earn 10 wins and let your name do the talking.",currency="Milestone",price=0,milestone={stat="wins",value=10},rarity="Rare",accent={87,238,237}},
	{id="name_legend",category="nameplates",name="MALL LEGEND",description="Reach level 30. A badge of long-term mastery.",currency="Milestone",price=0,milestone={stat="level",value=30},rarity="Legendary",accent={255,204,91}},
	{id="name_regular",category="nameplates",name="MALL REGULAR",description="Finish 50 rounds. You know every shortcut by heart.",currency="Milestone",price=0,milestone={stat="rounds",value=50},rarity="Rare",accent={120,226,198}},
	{id="name_relentless",category="nameplates",name="RELENTLESS",description="Catch 100 runners. Nobody stays hidden for long.",currency="Milestone",price=0,milestone={stat="tags",value=100},rarity="Rare",accent={255,128,120}},
	{id="name_hotstreak",category="nameplates",name="HOT STREAK",description="Win 5 rounds in a row.",currency="Milestone",price=0,milestone={stat="bestStreak",value=5},rarity="Epic",accent={255,160,90}},
	{id="name_apex",category="nameplates",name="APEX HUNTER",description="Win 15 rounds as a hunter.",currency="Milestone",price=0,milestone={stat="hunterWins",value=15},rarity="Epic",accent={255,88,109}},
	{id="name_ghost",category="nameplates",name="GHOST RUNNER",description="Survive 3,000 seconds across your career.",currency="Milestone",price=0,milestone={stat="survived",value=3000},rarity="Epic",accent={190,170,255}},
	-- Collections: a complete matching look (outfit, mask, trail and emote). Appearance only; a collection costs less
	-- than buying its Robux pieces separately and never changes speed, tagging or hiding.
	{id="bundle_shadow",category="bundles",name="Shadow Runner Collection",description="Shadow Runner outfit, Shadow Wrap mask, Shadow Smoke trail and the Sneaky Tiptoe emote. Appearance only.",currency="Robux",price=499,gamePassId=0,coinPrice=4500,grants={"skin_ninja","mask_ninja","trail_shadow","emote_tiptoe"},rarity="Epic",accent={150,90,235}},
	{id="bundle_phantom",category="bundles",name="Mall Phantom Collection",description="Mall Phantom outfit, Phantom Half-Mask, Electric Sparks trail and the Dramatic Faint emote. Appearance only.",currency="Robux",price=499,gamePassId=0,coinPrice=6200,grants={"skin_neonphantom","mask_phantom","trail_sparks","emote_drama"},rarity="Epic",accent={196,36,60}},
	{id="bundle_trickster",category="bundles",name="Royal Trickster Collection",description="Royal Trickster outfit, Jester Grin mask, Prism Streak trail and the Showoff Flip emote. Appearance only.",currency="Robux",price=549,gamePassId=0,coinPrice=5900,grants={"skin_trickster","mask_jester","trail_rainbow","emote_flip"},rarity="Epic",accent={132,66,224}},
	{id="bundle_galaxy",category="bundles",name="Galaxy Escape Artist Collection",description="Galaxy Escape Artist outfit, Astral Visor, Cosmic Stardust trail and the Royal Twirl emote. Appearance only.",currency="Robux",price=1099,gamePassId=0,coinPrice=14500,grants={"skin_galaxy","mask_astral","trail_stardust","emote_royal"},rarity="Legendary",accent={140,110,255}},
	{id="vip_founder",category="vip",name="Superstar Club",description="Street Legend outfit, Cool Shades, Speed Streaks trail and the Food Court Shuffle emote. No XP, speed or currency boosts.",currency="Robux",price=349,gamePassId=0,coinPrice=2300,grants={"skin_streetwear","mask_visor","trail_streaks","emote_dance"},rarity="Epic",accent={255,204,91}},
}
Catalog.Items = {}
for order, item in ipairs(entries) do
	item.order = order
	if PASS_IDS[item.id] and PASS_IDS[item.id] > 0 then item.gamePassId = PASS_IDS[item.id] end
	Catalog.Items[item.id] = item
end
Catalog.PassIds, Catalog.ProductIds = PASS_IDS, PRODUCT_IDS
-- What a player can pay for an item with coins right now (nil = not purchasable with coins).
function Catalog.CoinPrice(item)
	if not item then return nil end
	if item.currency == "Coins" then return item.price end
	return item.coinPrice
end
-- True when a Robux checkout is configured (a real Game Pass ID) for this item.
function Catalog.RobuxConfigured(item)
	return item ~= nil and item.currency == "Robux" and type(item.gamePassId) == "number" and item.gamePassId > 0
end
-- Items that were renamed or replaced keep their owners: old save id -> current id.
Catalog.Renamed = {skin_midnight = "skin_trickster"}
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
for _, product in ipairs(Catalog.Products) do
	if PRODUCT_IDS[product.id] and PRODUCT_IDS[product.id] > 0 then product.productId = PRODUCT_IDS[product.id] end
	Catalog.ProductsById[product.id] = product
end
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
-- Every cosmetic on sale must be previewable and wearable. `defs` supplies the lookups (kept out of this file so
-- Catalog has no dependencies): HasSkin, HasMask, HasTrail, HasEmote. Collections are ready only when every piece is.
function Catalog.IsReady(item, defs)
	if not item then return false end
	local category = item.category
	if category == "skins" then return defs.HasSkin(item.id) == true
	elseif category == "masks" then return defs.HasMask(item.id) == true
	elseif category == "trails" then return defs.HasTrail(item.id) == true
	elseif category == "emotes" or category == "victories" then return defs.HasEmote(item.id) == true
	elseif category == "bundles" or category == "vip" then
		if not item.grants or #item.grants == 0 then return false end
		for _, id in ipairs(item.grants) do
			local piece = Catalog.Items[id]
			if not piece or piece.category == "bundles" or piece.category == "vip" or not Catalog.IsReady(piece, defs) then return false end
		end
		return true
	end
	return true
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
