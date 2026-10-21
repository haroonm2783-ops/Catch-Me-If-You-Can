# DEVELOPMENT_PROGRESS.md — live tracker (read this first in every session)

Older history: `PROGRESS.md`. Launch assessment: `docs/LAUNCH_READINESS.md`. Visual identity: `docs/ART_DIRECTION.md`.
Cosmetics reference: `docs/COSMETICS.md`. Playtest scripts: `docs/TESTING.md` ("0.6.0 cosmetics acceptance script" first, then "0.5.0 acceptance script", including everything that needs two players).

## Ground rules for this effort
- No Roblox Studio/engine exists in the cloud container. Verified = `./tools/check.sh` (compile, rebuild, 10 mocked-boundary
  suites, place deserialization). Anything about feel, rendering, lighting, audio, devices, real DataStores and Robux is
  **UNVERIFIED until a human plays it in Studio**. Software previews in `docs/previews` are not screenshots.
- Never publish, spend money, or invent product/asset IDs. All `gamePassId` and `Products[n].productId` stay 0.
- Never overwrite `dist/` by hand: always `./tools/build.sh` (check.sh does it).
- Branch: `claude/visual-overhaul-v2` (built on `claude/launch-quality-overhaul`, PR #1).

## Version 0.6.0 — cosmetics and Shop overhaul
- [x] **Skins:** 14 full costumes (`suit()` shells + props), `hides = "outfit"` tucks away hair/hats/layered clothing
      (restored exactly), `headwear` flag keeps masks clear of hats, tiers measurably more elaborate, auras for Epic+.
- [x] **Masks:** 12 (smiley, kitty, pumpkin, phantom half-mask, astral visor...), `Top...` pieces, face accessories hidden.
- [x] **Trails:** `Trails.lua` — 10 definitions drive live `Trail`/`ParticleEmitter` objects AND `Trails.Emulator` (parts) for
      viewports; golden footprints via `Trails.Footprints`; `CosmeticsController` stamps them and thins particles by tier.
- [x] **Emotes:** `Poses.lua` + `Emotes.lua`; server validates and announces (`CatchEmote`/`CatchEmoteAt`), clients play;
      7 emotes + 3 podium victories; any owned emote playable.
- [x] **Showroom:** `PreviewStage.lua` (auto-frame, orbit, drag, replay, trail track, burst, reduced motion), thumbnails per
      category, item states, full-screen inspect, collection chips, `Catalog.IsReady` sale gate (client + server).
- [x] **Collections:** 5 matching sets, priced under their pieces; `Catalog.Renamed` keeps Midnight Magician owners.
- [x] **Tests:** `tests/cosmetics.spec.luau` (new), appearance/client/data suites extended; `tools/export-*` updated.
- [ ] **Not started:** the mall-gameplay request (fuller stores, shortcuts, vents, kiosks, flat-area polish).
- [ ] **Needs Studio:** everything in the cosmetics acceptance script (looks, feel, real avatars, real previews, phones).

## Version 0.5.0 — art-direction change ("Sunburst Mall")
- [x] **Characters:** avatar-first. `LoadCharacterAppearance = true`; `Appearance.lua` v4 builds optional overlays only
      (13 skins, 4 rarity tiers, auras, reversible hair-hide and gold tint, 8 masks). Mood poses removed from
      `MovementController` (only the slide pose and a light lean remain). Previews use the player's `HumanoidDescription`.
      Podium winners are real avatars. Tones/hair-color categories removed (legacy saves are sanitized, tested).
- [x] **Art:** new palette (`Kit.P`), neon policy (`Kit.GlowNames`), ShadowMap lighting preset, tile floors, per-store themes
      (`Mall/Style.lua`), storefront awnings and icon blade signs, pendant lamps, trim.
- [x] **Hub:** compact plaza (`Mall/Exterior.lua`, `Mall/Decor.lua`), sunburst gate, live boards and kiosks (`HubService`).
- [x] **Hiding:** 130 spots (air vents in back corridors, toy chest, shoe box, dog house added).
- [x] **UI:** compact HUD, right-hand dock with More popover, mid-size Shop/Locker panel (drawer in rounds), small cards,
      compact results and tutorial, banners clear of the dock, chat untouched, collection counters, rarity outlines.
- [x] **Feel:** dust puffs, hunter proximity vignette, Epic/Legendary unlock banners and equip bursts.
- [x] **Practice rewards:** wording unified; practice coins labelled "not saved" (server behavior was already correct).
- [x] **Performance:** 6,479 parts (down from 6,731) with more detail; budgets tightened in tests.
- [x] **Tooling:** `tools/render-view.py`, `export-ui.luau` + `render-ui.py`, updated character export; `tests/hub.spec.luau`.

## Test results (latest `./tools/check.sh`)
See the end of `docs/LAUNCH_READINESS.md`. All nine suites pass with mocked Roblox boundaries only.
**Zero Studio/engine playtests have been run.**

## Known risks (ranked)
1. **Lighting/exposure** was retuned blind (ShadowMap, ambient 138/134/152). Check first in Studio.
2. **Avatar overlays on real avatars** (clipping, R6, tall bundles) and the async `HumanoidDescription` preview path.
3. **Mobile performance**: budgets enforced, nothing measured.
4. **Slide/vault feel** without custom animations; hide/search balance numbers are guesses (`Config.Hide`).
5. **Store layouts were restyled, not redesigned**; no new shortcut routes.
6. No audio assets.

## Exact next steps
1. `./tools/bootstrap.sh && ./tools/check.sh` to confirm the baseline is green.
2. Open `dist/Catch-Me-If-You-Can-Final.rbxl`; run `docs/TESTING.md` sections A and B.
3. Fix what it finds: Output errors, stuck spots, HUD clipping, performance, then look and feel.
4. Create passes/products (`docs/MONETIZATION.md`), paste IDs, rebuild, test on a private place.
5. Add licensed audio IDs to `Config.Audio`. Only then publish.

## Later ideas (not started)
Global leaderboard (OrderedDataStore), jump pads / limited shortcuts, new store layouts, voting on modifiers,
seasonal store reskins, uploaded animations, streaming with `ReplicationFocus` if mobile memory demands it.

## Implementation decisions
- Players' own avatars are never repainted or replaced; cosmetics are reversible overlays.
- The art direction lives in one place per concern: palette and neon policy in `Kit`, store themes in `Style`,
  lighting in `MallBuilder.applyLighting`.
- Server owns hide/search/scan, coins and rewards; the client presents and sends intent. Hub kiosks only ask a
  client to open its own menu.
- Chat is left in Roblox's default position; the HUD is arranged around it, not the other way round.
