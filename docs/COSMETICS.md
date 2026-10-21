# Cosmetics and the Shop (version 0.6.0)

Everything here is **cosmetic only**: no cosmetic changes speed, hitboxes, tagging, hiding, XP or coins, and tests
check the catalog and the code paths for it. Every cosmetic is built from original geometry or engine primitives in
this repository. **No Roblox catalog assets, uploaded animations, textures or audio are used**, so there are no asset
permissions to configure and nothing can be "missing from the library" at runtime. If you later upload animations or
meshes, add them as new, separately tested items instead of changing these.

> **Verified vs unverified.** `./tools/check.sh` proves geometry, poses, definitions, budgets and data contracts on
> real Roblox `Instance`/`CFrame` objects with mocked engine boundaries. It does **not** render. Everything about how
> these cosmetics *look and feel* (materials, particles, animation timing, clipping on real avatars, the real
> ViewportFrame) is **unverified until a human checks it in Studio**: use
> [the cosmetics acceptance script](TESTING.md#060-cosmetics-acceptance-script-start-here). The images in
> `docs/previews/` are flat-color software renders of a stand-in mannequin.

## How it fits together

| Piece | File | What it does |
| --- | --- | --- |
| Skins and masks | `src/shared/Appearance.lua` | Builds costumes from welded, massless, non-colliding parts on the player's **own** R15/R6 avatar. Hides the player's hair, hats and layered clothing while a costume is worn and restores them exactly. |
| Trails | `src/shared/Trails.lua` | One definition table per trail drives **both** the live `Trail`/`ParticleEmitter` objects and a parts-based emulation used in the Shop (viewports do not draw trails or particles). Also the footprint stamper for Golden Footsteps. |
| Poses | `src/shared/Poses.lua` | Pose = small CFrame offsets keyed by joint name, in the parent part's frame. `Poses.Live` drives real `Motor6D.C0`; `Poses.Preview` drives anchored showroom models by forward kinematics (body, accessories and costume move together). |
| Emotes | `src/shared/Emotes.lua` | 7 emotes + 3 podium victory poses as pose functions of time. |
| Showroom | `src/shared/PreviewStage.lua` | One stage per preview: auto-framing from the model's real bounds, orbit camera, front/back/rotate, replay, trail test run on a loop, catch-effect bursts, reduced-motion still frames. |
| Client effects | `src/client/Controllers/CosmeticsController.lua` | Plays announced emotes on every character, stamps footprints, thins avatar particles by distance and device tier. |
| Shop UI | `src/client/Controllers/UIController.lua` | Cards, thumbnails, detail panel, controls, drag, full-screen inspect, item states. |
| Server | `CosmeticService`, `ShopService` | Validates and announces emotes; refuses to sell a cosmetic with no implementation (`Catalog.IsReady`). |

### Emotes without uploaded animations
The server validates an emote request (owned, a real emote, lobby or results only, cooldown, standing still) and sets
two attributes on the character: `CatchEmote` and `CatchEmoteAt`. Each client then plays that pose function on that
character's joints and restores them when the attribute clears, the emote ends, the character dies or leaves.
Nothing streams per frame, nothing needs animation ownership, and the same function runs in the Shop preview and on
the winners' podium, so what you preview is what you perform. Limits to know: layered-clothing accessories do not
bend with the pose (costumes hide them), and poses are authored for the standard R15 proportions (R6 uses the same
joints and works, with a coarser look).

### Trails: why there are two renderers
Roblox `ViewportFrame`s do not draw `Trail` or `ParticleEmitter`, so a trail preview made of the real objects would
show nothing. `Trails.Emulator` draws the same ribbons (colors, fade, taper, lifetime, width) and the same emitters
(rate, lifetime, speed, spread, size, color, fade, acceleration) with small parts, behind a character running laps on
a looping track. A test compares every keypoint of the live `Trail` against the definition the emulator reads.
The emulation cannot reproduce the engine's particle textures or exact blending; compare the two side by side in
Studio (acceptance script step 6).

## The collection

### Skins (14, full costumes fitted to the player's avatar)
| Tier | Skin | How to get it |
| --- | --- | --- |
| Common | **Original You** (your own avatar, untouched) | free |
| Common | **Pizza Courier** (cap, polo, work pants, sneakers, giant pizza box) | 500 coins |
| Rare | **Skate Kid** (pompom beanie, hoodie, denim, knee pads, skateboard) | reach level 5 |
| Rare | **Bunny Hop** (fluffy bunny suit, floppy ears, paws, slippers, tail, bow) | 900 coins |
| Rare | **Bamboo Panda** (panda onesie, hood and ears, bamboo backpack) | 1,200 coins |
| Epic | **Street Legend** (varsity jacket, cargo pants, sneakers, bucket hat, chain, bag, gold dust) | 1,800 coins |
| Epic | **Jet Runner** (flight suit, steel boots and gauntlets, goggles, jet pack with flames) | win 25 rounds |
| Epic | **Candy Pop** (peppermint outfit, cotton-candy shoulders, ice-cream hat, lollipop) | 2,600 coins |
| Epic | **Shadow Runner** (hooded parkour kit, violet trim, wrapped shins, scarf, shadow smoke) | Robux (pass not configured) |
| Epic | **Mall Phantom** (tailcoat, lined opera cape, top hat, white gloves, wisps) | Robux (pass not configured) |
| Epic | **Royal Trickster** (purple-and-gold motley, ruffle, three-horned crown, belled shoes, confetti) | Robux (pass not configured) |
| Legendary | **Galaxy Escape Artist** (star suit, 3-layer cosmic cape, planet top hat, moon clasp, stardust) | Robux (pass not configured) |
| Legendary | **Golden Champion** (solid gold body, crown, armor, royal cape) | Robux (pass not configured) |
| Legendary | **Dragon Racer** (scale armor, horns, wings, spiked tail, embers) | win 60 rounds |

Premium looks are measurably more elaborate (a test compares average piece counts per tier). Epic and Legendary
costumes have an ambient aura (one emitter, at most 16 particles per second).

### Masks (12; every mask works with every skin)
Street Bandana (free), Cool Shades, Big Smile, Shadow Wrap, Kitty Cat (coins), Jester Grin, Jack-o'-Lantern (coins),
Retro Bot (75 tags), Phantom Half-Mask, Kitsune Mask (Robux), Gold Skull Mask, Astral Visor (Legendary, Robux).
Pieces that sit on top of the head (ears, stems, rings, antennas) are named `Top...` and are left off when the
costume already has headwear, so masks and hats never collide; a test checks every skin/mask pair for overlap.
A mask also hides the player's face accessories (glasses) instead of clipping through them.

### Trails (10)
Aqua Dash, Speed Streaks (three colored stripes), Hot Foot (embers) - Rare; Prism Streak, Candy Swirl, Electric
Sparks, Sunset Glide (20 wins) - Epic; Shadow Smoke - Epic (Robux); Golden Footsteps (stamped footprints) and Cosmic
Stardust - Legendary (Robux). Budget per trail: at most 3 ribbons, 2 emitters and 20 particles per second; trails are
only on while sprinting; avatar particles are halved on MEDIUM and mostly off on LOW graphics tiers and beyond 160 /
90 / 55 studs (HIGH / MEDIUM / LOW).

### Emotes (7) and victories (3)
Hey, Shopper (free wave), Food Court Shuffle, Sneaky Tiptoe, Mall Chicken (Rare, coins), Dramatic Faint, Showoff Flip
(Epic, coins), Royal Twirl (Legendary, Robux). Victories (podium poses): Mall Salute, Victory Lap, Champion Flex.
Emotes play in the lobby and on the results screen only; a player can play any emote they own from the Locker or the
dock's EMOTE button (the equipped one).

### Collections (outfit + mask + trail + emote)
| Collection | Pieces | Design price |
| --- | --- | ---: |
| Shadow Runner Collection | Shadow Runner, Shadow Wrap, Shadow Smoke, Sneaky Tiptoe | R$ 499 |
| Mall Phantom Collection | Mall Phantom, Phantom Half-Mask, Electric Sparks, Dramatic Faint | R$ 499 |
| Royal Trickster Collection | Royal Trickster, Jester Grin, Prism Streak, Showoff Flip | R$ 549 |
| Galaxy Escape Artist Collection | Galaxy Escape Artist, Astral Visor, Cosmic Stardust, Royal Twirl | R$ 1,099 |
| Superstar Club | Street Legend, Cool Shades, Speed Streaks, Food Court Shuffle | R$ 349 |

A test enforces that a collection never costs more than its pieces would and that no copy uses fake scarcity.
**All Robux items are unconfigured (`gamePassId = 0`)**: the Shop shows them as COMING SOON with the planned price and
sends no purchase. Enter real pass IDs (see [MONETIZATION.md](MONETIZATION.md)) and set matching prices in the Creator
Dashboard; the Robux prices in `Catalog.lua` are design references only.

## The Shop

- **Cards**: rarity label and outline (Epic/Legendary), a thumbnail drawn from the real definition (viewport render of
  your avatar for skins, masks, collections, emotes and victories; the trail's real ribbon colors and particles;
  catch-effect burst; nameplate), status line (OWNED, EQUIPPED, locked progress such as `12/60 WINS`, price, or COMING
  SOON), a check badge for equipped and a lock for locked.
- **Detail panel**: large auto-framed preview, rarity, name, description, what a collection includes (with what you
  already own), a plain price line (`you have 1,250`, `NEED 550 MORE COINS`, `Planned price R$ 699 · not on sale
  yet`, `12/60`), and one honest action button.
- **Controls**: `<` `FRONT` `BACK` `>`, drag to rotate (mouse or touch), `REPLAY` (emotes, trails, catch effects),
  `FULL` for a full-screen inspection that never covers the Shop/Locker dock, `PLAY ON MY AVATAR` for owned emotes.
- **Collections** have LOOK / TRAIL / EMOTE chips to inspect the whole matching set.
- **Not for sale until implemented**: if an item has no skin, mask, trail or emote implementation behind it, the card
  says SOON, the preview says NOT READY FOR SALE, the button says NOT AVAILABLE YET, and the server refuses the
  purchase. A test requires that no catalog item is in that state today.
- **Reduced motion** shows a still key pose and a finished, frozen trail instead of looping.
- **Performance**: only one preview (plus the optional inspect) runs at a time, only while a menu is open; thumbnails
  are cached and limited by graphics tier (all on HIGH, six on MEDIUM, none on LOW).

## Adding a cosmetic
1. **Skin**: add `skins.skin_x` in `Appearance.lua` (use `suit(k, {...})` for the body shells, then props; set
   `hides = "outfit"` and `headwear = true`), add it to `Appearance.SkinOrder`, add a catalog entry.
2. **Mask**: add a branch in `buildMask`, name any on-top pieces `Top...`, add to `masks` and `MaskOrder`.
3. **Trail**: add `defs.trail_x` in `Trails.lua` (ribbons and at most two emitters), add to `Trails.Order`, add a catalog entry.
4. **Emote**: add `defs.emote_x` in `Emotes.lua` (a function of time returning joint offsets; make loops periodic in
   `duration`), add to `Emotes.Order`, add a catalog entry.
5. Run `./tools/check.sh`. `tests/cosmetics.spec.luau` fails if a piece floats, clips a mask, leaves the floor, is not
   finite, breaks a budget, or has no catalog entry.
6. `lune run tools/export-characters.luau && python3 tools/render-characters.py` to look at it, then check it in Studio.

## Persistence
Equipped skin, mask, trail and emote are separate slots saved in the profile. Tests cover buy -> equip -> save -> new
server -> restore, independent unequip (an empty trail slot stays empty), equipping into the wrong slot (rejected) and
unowned items (rejected). Replaced items keep their owners (`Catalog.Renamed`: Midnight Magician owners receive Royal
Trickster). Real DataStore persistence is **unverified** until run in a published place.
