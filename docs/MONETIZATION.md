# Cosmetics and Robux setup

**Status:** the Shop, Locker, coin purchases, equipment, server-side pass checks and the coin-pack receipt handler are
implemented and covered by mocked tests. **Real Roblox purchases have never been tested** (no Studio in the build
environment). No product IDs exist in the repository: every `gamePassId` and `productId` is `0`, and I will not invent them.

## What players can do today (before you configure anything)

- **Every cosmetic is obtainable and equippable now.** Premium (Robux-tier) items show a coin price (`coinPrice`) and
  are bought with earned coins. Nothing says "coming soon".
- **No Robux prompt can open** for an item whose pass ID is 0, and coin packs are hidden until a product ID is set.
- Once you enter a pass ID, that item's detail panel gets a second button: **BUY WITH ROBUX** (the coin button stays).
  Robux and coin buyers receive the identical item; nothing is gameplay-affecting.

## Step by step: turn Robux sales on

You can do this for one item, a few, or all 22 products. Items you skip keep working with coins.

1. **Publish the place privately first.** Studio > File > Publish to Roblox (as a *private* experience while testing).
   Passes and developer products belong to an experience, so this must happen before step 2.
2. **Create each Game Pass.** [create.roblox.com/dashboard/creations](https://create.roblox.com/dashboard/creations) >
   your experience > **Monetization > Passes > Create a Pass**. Upload artwork you own, name it exactly like the catalog
   name below, and describe it as appearance-only. Save, then open the pass > **Sales** > turn **Item for Sale** on and
   set the Robux price (the design prices below are suggestions; you set the real ones).
3. **Copy the Pass ID** from the pass page URL (`.../passes/<ID>/...`). It is *not* the experience ID, place ID or image ID.
4. **Create the coin packs.** Same dashboard > **Monetization > Developer Products > Create**. Name them like the
   table at the bottom, set prices, copy each **Product ID**.
5. **Paste the IDs** into the two tables at the very top of
   [`src/shared/Catalog.lua`](../src/shared/Catalog.lua): `PASS_IDS` (keyed by catalog ID, e.g. `skin_golden = 1234567`)
   and `PRODUCT_IDS` (keyed by pack ID, e.g. `coins_bag = 7654321`). **Also set that item's `price=` (and each pack's
   `robux=`) in the same file to the exact Robux price you chose in the Dashboard**: the Shop displays the catalog
   number, while Roblox's prompt shows the real one, and the two must match or players see two different prices.
6. Run `./tools/check.sh` (it rebuilds `dist/Catch-Me-If-You-Can-Final.rbxl`), open that file, publish over the private
   experience, then run the real-service checks at the bottom of this page before making the experience public.
7. A pass is only offered for sale when its ID is a valid positive whole number *and* the item's skin/mask/trail/emote is
   implemented (`Catalog.IsReady`). If a purchase prompt looks wrong, set that ID back to `0` and republish.

Until an ID is set the catalog `price` is only a design reference and is not shown to players. Once an ID is set the Shop
displays it, so keep it identical to the Dashboard price; the Roblox prompt is always the authoritative charge. Coin
prices are enforced by the server from the catalog and cannot be set by a client.

### The 18 Game Passes (paste each ID into `PASS_IDS`)

| Catalog ID | Cosmetic entitlement | Design price (Robux) |
| --- | --- | ---: |
| `skin_ninja` | Shadow Runner (Epic outfit) | 349 |
| `skin_neonphantom` | Mall Phantom (Epic outfit) | 399 |
| `skin_trickster` | Royal Trickster (Epic outfit) | 449 |
| `skin_galaxy` | Galaxy Escape Artist (Legendary outfit) | 699 |
| `skin_golden` | Golden Champion (Legendary outfit) | 599 |
| `mask_phantom` | Phantom Half-Mask (Epic) | 149 |
| `mask_kitsune` | Kitsune Mask (Epic) | 199 |
| `mask_skull` | Gold Skull Mask (Legendary) | 349 |
| `mask_astral` | Astral Visor (Legendary) | 399 |
| `trail_shadow` | Shadow Smoke trail (Epic) | 249 |
| `trail_gold` | Golden Footsteps trail (Legendary) | 299 |
| `trail_stardust` | Cosmic Stardust trail (Legendary) | 349 |
| `emote_royal` | Royal Twirl emote (Legendary) | 299 |
| `bundle_shadow` | Shadow Runner, Shadow Wrap, Shadow Smoke, Sneaky Tiptoe | 499 |
| `bundle_phantom` | Mall Phantom, Phantom Half-Mask, Electric Sparks, Dramatic Faint | 499 |
| `bundle_trickster` | Royal Trickster, Jester Grin, Prism Streak, Showoff Flip | 549 |
| `bundle_galaxy` | Galaxy Escape Artist, Astral Visor, Cosmic Stardust, Royal Twirl | 1,099 |
| `vip_founder` | Street Legend, Cool Shades, Speed Streaks, Food Court Shuffle (Superstar Club) | 349 |

Each Robux row is its own game pass (18 passes); collections are separate passes that grant their four pieces (owning
a piece already is fine: only the missing ownership flags are added, with no automatic refund, so say so in the pass
description). The sale gate (`Catalog.IsReady`) means an item is never offered if its skin, mask, trail or emote is not
implemented, and tests enforce that every collection costs less than its pieces and uses no fake-scarcity wording.
Until a pass ID is entered, the item is bought with coins only and no Robux prompt can open.

Free and earnable (no Robux needed): **Original You** (free), **Pizza Courier** (500 coins), **Skate Kid** (level 5),
**Bunny Hop** (900), **Bamboo Panda** (1,200), **Street Legend** (1,800), **Candy Pop** (2,600), **Jet Runner**
(25 wins) and the Legendary **Dragon Racer** (60 wins). Masks: Street Bandana (free), Cool Shades, Big Smile, Shadow
Wrap, Kitty Cat, Jester Grin, Jack-o'-Lantern (coins), Retro Bot (75 tags). Trails: Aqua Dash, Speed Streaks, Hot
Foot, Prism Streak, Candy Swirl, Electric Sparks (coins) and Sunset Glide (20 wins). Emotes: Hey, Shopper (free),
Food Court Shuffle, Sneaky Tiptoe, Mall Chicken, Dramatic Faint, Showoff Flip (coins). Tag effects: Star Pop (coins),
Party Pop (40 wins), Cherry Bloom (50 tags).
Skins are *costumes fitted to the player's own Roblox avatar*; there are no skin-tone or hair-color items.
Rarity tiers: Common (free or cheap), Rare (coins or a small milestone), Epic (a real goal or a premium purchase, adds an
ambient aura), Legendary (showpieces). **Nothing here changes speed, tagging, hiding, XP or coins.**

Skins and masks occupy independent equipment slots and can be combined. Bundles
and VIP grant their listed inventory items; their collection entry is not an
equipment slot. Buying a collection with an already-owned component grants only
the remaining ownership flags; there is no automatic price reduction or refund.
State that clearly in the pass description. VIP provides no speed, XP, coin,
tagging, or competitive advantage.

## Purchase and save behavior

- The client requests a catalog item ID. `ShopService` resolves the configured
  pass on the server, throttles requests, and calls
  `MarketplaceService:PromptGamePassPurchase`.
- `PromptGamePassPurchaseFinished` alone never grants an item. The server calls
  `UserOwnsGamePassAsync` before granting ownership, with bounded retries after a
  completed prompt. Ownership is also refreshed on join.
- A delayed verification notice means retry the item or rejoin; the player should
  not buy again. Already-owned passes can restore their cosmetic entitlement.
- `DataService` validates coin balance, milestone unlocks, ownership, equipment
  categories, and duplicate purchases. Successful persistence stores ownership
  and equipped items in the player's profile with session locking.
- Studio uses temporary session data by default. A storage failure or another
  active session produces an explicit non-saving status. Inspect the status in
  CAREER; an inventory update is not proof that a DataStore write succeeded.
- Permanent cosmetics are **game passes**. Repeatable **coin packs** are
  **developer products** handled by `ShopService:ProcessReceipt` (below). Never put a
  developer product ID in a `gamePassId` or a pass ID in a coin pack.

## Coin packs (developer products)

Coins only buy cosmetics, so packs are a convenience and never a gameplay advantage.
All four packs ship with `productId = 0`: the pack is hidden in the Shop and nothing can
prompt. To activate one (this is the same as step 4-5 above):

1. In Creator Dashboard, **Monetization → Developer Products → Create**. Set the Robux
   price and copy the **product ID** (not a pass or asset ID).
2. Put it in `Catalog.Products[n].productId` in [`src/shared/Catalog.lua`](../src/shared/Catalog.lua).
3. Rebuild with `./tools/check.sh`, publish, and test on a private server.

| Pack | Coins | Design price (Robux) |
| --- | ---: | ---: |
| `coins_pocket` Pocket Change | 500 | 49 |
| `coins_bag` Shopping Bag | 1,200 | 99 |
| `coins_haul` Mall Haul | 3,200 | 249 |
| `coins_mogul` Mall Mogul | 9,000 | 599 |

How it stays safe (covered by `tests/data_service.spec.luau` against mocks):

- The client sends only a pack ID (`BuyCoins`); the server maps it to the product ID and
  throttles prompts. The prompt is intent only.
- `ProcessReceipt` validates the receipt, resolves the product by ID, and credits coins
  exactly once per `PurchaseId` (stored with the profile's receipt list).
- Packs are paused (no prompt, receipt left unprocessed) on a profile that cannot save, such as one locked by another
  server, so a player never pays for coins that would vanish.
- It returns `PurchaseGranted` only after the balance is saved (or, in Studio, when the
  server is intentionally session-only). A failed save returns `NotProcessedYet`, and the
  retry will not credit twice. Players who left get the receipt on their next join.
- Real settlement is **not** proven by mocks: complete the real-service checks below.

## Required real-service tests

Use published private test servers, authorized test accounts, test-experience
passes, and a separate DataStore as described in [TESTING.md](TESTING.md).
Studio mocks cannot establish a real purchase or a successful Roblox save.

- An unconfigured item never prompts. A configured item opens the correct
  official pass prompt with the current price and exact cosmetic description.
- Cancel and retry; no item is granted and the next prompt remains usable.
- Purchase a single item, then a collection. Verify the server-granted ownership,
  independent skin/mask previews, equipping, and the collection's exact contents.
- Rejoin after the save status reports success. Ownership, equipment, and coin
  balance must match. A previously owned pass must restore without charging again.
- Try buying a collection when some components are already owned. Verify no
  duplicate charges for the same pass and no unintended progression rewards.
- Check an API/verification failure and a delayed profile save in the automated
  harness; also observe real-service failures if they occur. Do not interpret a
  failed network request as proof of non-ownership or manufacture a success event.

Real purchases may spend real Robux; use Roblox's currently supported pass test
facilities where available and a deliberate test budget for any paid transaction.
Neither automated tests nor a Studio purchase dialog prove paid settlement.
