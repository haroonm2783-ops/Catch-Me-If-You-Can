# Cosmetics and Robux setup

The shop, locker, previews, coin purchases, equipment, and server-side pass checks
are implemented. **Real Roblox purchases have not been tested.** Every Robux item
currently has `gamePassId = 0`, so its purchase button says **NOT CONFIGURED** and
cannot open a paid prompt. No fake product IDs are supplied.

## Activate passes

1. Open the generated place in Roblox Studio and publish it to the intended
   experience. Use a private test experience first.
2. In [Creator Dashboard](https://create.roblox.com/dashboard/creations), select
   that experience, then **Monetization → Passes → Create a Pass**. Create a pass
   for each collection or cosmetic you want to sell. Use artwork you own and a
   description that accurately lists the cosmetic entitlement.
3. Open each pass's sales settings, enable sale, and set the desired Robux price.
   Copy its **pass ID**, not the experience ID, place ID, asset image ID, or a
   developer product ID. Dashboard navigation labels can change.
4. Replace the corresponding `gamePassId = 0` in
   [`src/shared/Catalog.lua`](../src/shared/Catalog.lua). Use a distinct pass per
   item unless you deliberately want one pass to grant multiple catalog entries.
5. Run `./tools/check.sh` and `./tools/build.sh`, then open and publish the rebuilt
   `dist/CatchMeIfYouCan.rbxl` or `dist/CatchMeIfYouCan.rbxlx`. Ensure published
   servers use this version before testing purchases.
6. Follow the real-service checks below. Keep the experience private until the
   entitlement, saving, and cancellation cases pass.

The catalog's `price` field is a design reference for Robux items; changing it
does not change Roblox's charge. Configured shop cards say **VIEW ROBUX PRICE**.
The Roblox purchase prompt supplies the authoritative current price, including
any applicable regional or dynamic pricing. Do not replace this with an assumed
fixed charge. Coin prices are enforced from the server's catalog.

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
Until a pass ID is entered, the Shop shows the item as **COMING SOON** with the planned price and sends nothing.

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
All four packs ship with `productId = 0`: the shop shows **COMING SOON** and nothing can
prompt. To activate one:

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
