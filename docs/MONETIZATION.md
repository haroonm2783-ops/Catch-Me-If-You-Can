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
| `skin_shadow` | Shadow Runner | 299 |
| `skin_golden` | Golden Phantom | 599 |
| `skin_neon` | Neon Outlaw | 399 |
| `skin_crimson` | Crimson Hunter | 499 |
| `mask_phantom` | Phantom Mask | 149 |
| `mask_kitsune` | Kitsune Mask | 199 |
| `mask_skull` | Gold Skull Mask | 349 |
| `bundle_night` | Shadow Runner, Phantom Mask, Afterglow trail | 649 |
| `vip_founder` | Neon Outlaw, Prism Visor, Rooftop Shuffle | 699 |

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
- This version sells permanent **game passes**, not repeatable developer
  products. There is no developer-product `ProcessReceipt` flow. Do not put
  developer product IDs in `gamePassId` or sell repeatable currency packs through
  this implementation.

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
