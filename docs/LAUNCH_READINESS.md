# Launch readiness — version 0.5.0 (Sunburst art direction)

**Verdict: NOT ready to publish.** Every automated check passes, but **nothing has been run in Roblox Studio**, on a
phone, with real players, with a real DataStore or with real Robux. The green checks prove logic and layout contracts
with mocked Roblox boundaries; they do not prove the game *looks* or *feels* good. This report deliberately does not
claim 9/10 or "launch ready". Run [the acceptance script](TESTING.md#050-acceptance-script-start-here) first.

## What changed in 0.5.0 (a deliberate art-direction change)
| Area | Before | Now |
| --- | --- | --- |
| Characters | Custom blocky bodies repainted over every player, custom faces, procedural mood poses | Players keep **their own Roblox avatar and animations**. Skins are optional overlays (hats, back items, capes, wings, tails). Epic and Legendary add an aura; Golden Champion tints your limbs (reversible). Masks sit on your real face. |
| Cosmetics | 8 skins, tone and hair pickers | **13 skins in four rarity tiers**, 8 masks, 5 trails, 4 tag effects, collection counters (`4/13`), rarity outlines, rarity-colored equip bursts and unlock banners. Previews are *your* avatar wearing the item. |
| Art | Near-white marble, cream and pale pastels, ~700 neon parts, haze, positive exposure | Warm saturated "Sunburst" palette, mid-tone floors with a bold tile checker, per-store wall/floor/awning identity, neon only for screens, bulbs and coins, ShadowMap lighting, light haze. |
| Stores | Same box storefront everywhere | Every store has a theme (colors, material, striped awning, icon blade sign visible from the corridor), pendant lamps, trim and a painted band. Existing interiors (runway, teddy bear, giant sneaker, TV wall, aquarium, ring…) kept. |
| Hiding spots | 111 | **130**: added air vents in the back corridors, a toy chest, a giant shoe box and a dog house. |
| Hub | 130 x 90 empty deck far from the mall | Compact 100 x 78 plaza facing a sunburst entrance: chevron path, winners' podium with backdrop, **two live leaderboards**, **Shop and Locker kiosks**, live status board over the doors, palms, benches, bunting. |
| UI | Large left dock (7 buttons), big panels, hero card, full-size results and tutorial | Compact timer chip and wallet pill; **Shop and Locker always visible** on the right with one **More** button; mid-size Shop/Locker panel (narrow drawer in rounds); small cards for everything else; compact results card; small tip-card tutorial. Chat stays in its default corner. |
| Feel | — | Dust puffs on slides, vaults and hard landings; hunter proximity vignette; Epic/Legendary unlock banners. |
| Performance | 6,731 parts | **6,479 parts** (fewer, bigger shelf/book blocks; no hidden-cell clutter) while adding more detail. |

## Practice-mode rewards inconsistency — findings and fix
**Symptom:** the practice results screen said no XP or coins were awarded while other screens showed coins and XP.
**Cause (code review plus tests; no engine needed to see it):**
1. The wallet and CAREER screens always show your *saved* coins/XP, which is correct.
2. In practice, `HideService` still lets you collect mall coins "for the feel of it", so the HUD showed `Coins 6/25` and
   played pickup effects, while `DataService:AwardRound` correctly refuses practice rounds.
3. The results screen then said nothing was awarded. Each statement was true; together they read as a contradiction.

**Server behavior was never wrong:** `AwardRound` returns `false` for practice and the gameplay suite proves practice
never changes coins, XP, rating, wins or quests. **Fix is presentation:** the HUD says *PRACTICE / NOTHING IS SAVED*,
coins are labelled *Practice coins*, and the results card says "Practice rounds are not saved" and lists practice coins as
not saved. To verify real rewards and saving you need a real round with two clients (TESTING.md section B6).

## Verified (automated, mocked Roblox boundaries) — `./tools/check.sh`
Compile of 35 production scripts, deterministic rebuild, both place formats deserialize (ShadowMap and
`LoadCharacterAppearance = true` are asserted in the saved file), and nine suites:
rules 379 · data/shop/receipts 181 (reveal payloads, legacy-save migration) · gameplay + end-to-end 287 ·
appearance 276,756 (13 skins x 9 mask options on R15 and R6, reversible hair-hiding and gold tint, previews match live
avatars, no neon cosmetics) · client UI 1,902 (dock, menus, banners and More popover fit and stay clear of each other at
6 screen sizes; danger vignette; reveal banners) · legacy map 28,291 · **mall 106,320** (navigation of both floors,
130 hiding spots reachable and sized for an avatar, doors, part/light/emitter budgets, hub footprint) · hub 35 ·
enum validity 900 references.

### What the preview images are
`docs/previews/*.png` are **software geometry previews** produced by `tools/render-view.py`, `tools/render-characters.py`
and `tools/render-ui.py`: flat colors, no real materials, shadows, bloom, fonts, emoji or player avatars. They exist to
check composition, palette balance, sight lines and UI overlap without Studio. They are not screenshots of the game.

## NOT verified (needs a human in Studio, on a phone, or a published place)
| Area | Why it matters | How to verify |
| --- | --- | --- |
| **Lighting and exposure** | The biggest unknown. Ambient `(138,134,152)`, Brightness 2.1, ShadowMap and a light haze are reasoned values; interiors may read too dark or too bright | TESTING A1; tune `applyLighting()` |
| Real material look | Slate/Granite/WoodPlanks/Fabric textures tint differently from flat colors | Walk the mall in Studio |
| Avatar overlays on real avatars | Hat/hair clipping, tall/skinny bundles, R6, Rthro; gold tint on real limbs; restored clothes | TESTING A2–A3 |
| `HumanoidDescription` previews | `CreateHumanoidModelFromDescription` is async and unproven here; a mannequin shows if it fails | TESTING A4 |
| Slide and vault feel | Only the slide pose is authored; mood poses were removed so Roblox animations drive everything else | Two clients, TESTING B12 |
| Signs with emoji | Icons on blade signs and dock buttons depend on the client font | Look at storefronts and the dock |
| Multiplayer, late join, disconnects, 7 and 12 clients | Only mocked | TESTING section B |
| Mobile performance | Only part and light budgets; PerformanceController tiers unmeasured | Low-end phone |
| DataStore saving, passes, coin packs | All pass and product IDs are 0; no real settlement | MONETIZATION.md on a private test place |

## Honest ratings (out of 10, estimated from source and software previews — not measured)
| Area | Score | Why it is not higher |
| --- | ---: | --- |
| Characters and cosmetics | 7 | The avatar-first design removes the biggest risk (awkward custom bodies) and the lineup is strong, but clipping on real avatars and the real preview path are unseen. |
| Mall art direction | 6 | Palette and storefront identity are a clear step up in previews, but lighting/exposure and materials have never been seen in the engine. |
| Stores and hiding | 7 | Distinct themes, 130 spots and a validated navigation model. Store *layouts* were kept, not redesigned; no new shortcuts were added. |
| Hub | 7 | Compact and full of purpose; boards, kiosks and status board are tested for wiring, not for looks. |
| UI | 7 | Clean layout contracts at six sizes; real fonts, emoji and thumb ergonomics unseen. |
| Chase gameplay feel | 6 | Feedback added (dust, danger glow); balance numbers in `Config.Hide` are guesses and need real players. |
| Performance | 6 | Part count down, budgets enforced, tiers exist; nothing measured on a phone. |
| Monetization plumbing | 7 | Fair and cosmetic-only, end-to-end tested with mocks; never settled for real. |

## Known gaps vs the brief (not done, by choice or limit)
- No uploaded animations, music or audio (no assets could be created or licensed here); engine fallbacks only.
- No new store *layouts* or shortcut routes; the 24 existing interiors were restyled and extended with hiding spots.
- Shop previews depend on a runtime `HumanoidDescription` call that could not be exercised.
- No HUD scale-up for large monitors: an attempt using `UIScale` was dropped because how `UIScale` treats `Position` offsets could not be confirmed without Studio. Check HUD text size on a 1080p/4K monitor and, if too small, scale the whole HUD through one full-screen container.
- The two-player Studio checklist (TESTING B) is the list of everything solo practice cannot prove.

## Owner actions
1. Open the place, check `Lighting.Technology` reads ShadowMap, and tune `applyLighting()` if needed.
2. Run TESTING sections A and B. Fix what they find, in this order: Output errors, stuck spots, HUD clipping, performance, look.
3. Create passes and products (`MONETIZATION.md`), paste real IDs, rebuild with `./tools/build.sh`. Never use made-up IDs.
4. Provide licensed audio IDs in `Config.Audio` if wanted. Publish privately first; set max players to 12 and avatars to R15.
