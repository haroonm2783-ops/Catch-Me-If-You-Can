# DEVELOPMENT_PROGRESS.md — live tracker (read this first in every session)

Older delivery history (0.2.x, verification detail): `PROGRESS.md`. Launch assessment: `docs/LAUNCH_READINESS.md`.
Playtest script: `docs/TESTING.md` ("0.4.0 Catch Mall acceptance script").

## Ground rules for this effort
- No Roblox Studio/engine exists in the cloud container. Verified = `./tools/check.sh` (compile, rebuild,
  8 mocked-boundary suites, place deserialization). Anything about feel, rendering, audio, devices, real
  DataStores and Robux is **UNVERIFIED until a human plays it in Studio**.
- Never publish, spend money, or invent product/asset IDs. All `gamePassId` and `Products[n].productId` stay 0.
- Never overwrite `dist/` by hand: always `./tools/build.sh` (check.sh does it).
- Branch: `claude/launch-quality-overhaul` (not merged; no PR opened).

## Version 0.4.0 — launch-quality overhaul (this session)
All of the following are implemented, tested against mocks, and committed:
- [x] **Characters** (`src/shared/Appearance.lua` v3): expressive face parts toggled by mood, hair, 8 outfits,
      8 masks, free skin tone + hair color, preview rig, deferred mid-round look changes (`CosmeticService`).
- [x] **Catch Mall** (`src/server/World/MallBuilder.lua` + `Mall/*`): 324×304 studs, 2 floors + service ring,
      atrium, 8 escalators, 4 grand stairs, 2 skybridges, 8 drop gaps, corner ladders, food court, arcade,
      cinema, restrooms, 24 stores/attractions, 106 hide cells, 55 coins, sealed lobby deck, bright lighting.
- [x] **Hiding gameplay** (`HideService`): hide / search / scan / coins / close calls, rewards, reset per round.
- [x] **UI** (`UIController`): bright theme, always-visible Shop/Locker dock (vertical, or horizontal on short
      screens), objective card, hide meter, ability bar, rarity cards with thumbnails, results reward breakdown,
      coin-pack tab, side-drawer menus during rounds (no pausing, no protection).
- [x] **Client systems:** `HidingController` (role-based prompt labels, scan/reveal highlights, coin spin),
      Scan binding + jump-to-unhide in `MovementController`, procedural mood poses sharing its single joint
      writer, mall feedback sounds/banners in `EffectsController`, optional ambience loop slot.
- [x] **Monetization:** developer-product coin packs, idempotent `ProcessReceipt` (granted only after save),
      `BuyCoins` action; docs in `docs/MONETIZATION.md`.
- [x] **Tests:** mall navigation suite (125k checks), enum-validity suite, new client/data/gameplay checks.
- [x] **Docs:** README, LAUNCH_READINESS, TESTING, MONETIZATION updated; map previews `docs/Mall-*.png`
      and character sheets `docs/*-lineup.png` regenerated (software renders, not Studio screenshots).

## Test results (latest `./tools/check.sh`)
rules 398 · data/shop/receipts 172 · gameplay 270 · appearance 283,138 · client 1,309 · legacy map 28,291 ·
mall 125,020 · enums 856 refs — PASS. Mocked Roblox boundaries only. **Zero Studio/engine playtests have been run.**

## Known risks (ranked)
1. **Mobile performance** — ~7,200 parts, StreamingEnabled off. Unmeasured.
2. **Visual quality** — mall palette/lighting/UI never seen in the engine.
3. **Mood pose rotation signs** (`MOOD_POSES` in `MovementController.lua`) are derived by hand; may need flipping.
4. **Hide/search balance** numbers (`Config.Hide`) are guesses; fairness needs real players.
5. **Stuck spots** — navigation checks are analytic, not physics.
6. **No audio assets** — engine fallbacks only (`Config.Audio` slots exist for owner-supplied IDs).

## Exact next steps for whoever continues
1. `./tools/bootstrap.sh && ./tools/check.sh` to confirm the baseline is green.
2. Open `dist/Catch-Me-If-You-Can-Final.rbxl` in Studio; run the 0.4.0 acceptance script in `docs/TESTING.md`.
3. Fix what it finds, in this priority: crashes/errors in Output → stuck spots/exploits → HUD clipping on phone →
   performance → look and feel. Tune `Config.Hide`, `applyLighting()`, palette `P`, `MOOD_POSES`.
4. Create passes/products (see `docs/MONETIZATION.md`), paste IDs, rebuild, test on a private place.
5. Add licensed audio IDs to `Config.Audio` and test.
6. Only then publish. After each change: run check, update this file, commit.

## Later ideas (not started)
Global leaderboard (OrderedDataStore), jump pads / limited shortcuts, player voting on modifiers, seasonal store
reskins, uploaded animations, streaming with `ReplicationFocus` if mobile memory demands it.

## Implementation decisions
- Keep the existing architecture (Rojo + services + pure Rules). Extend, don't rebuild.
- The server owns hide/search/scan, coins and rewards; the client only presents and sends intent.
- Rewards stay cosmetic/currency only; no gameplay advantage is purchasable.
- Mood poses share MovementController's joint writer to avoid two scripts fighting over C0.
- Hide cells always show a closed door (occupancy is not visible); hunters get a search and a scan instead.
