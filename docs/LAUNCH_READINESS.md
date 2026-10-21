# Launch readiness — version 0.7.0 (launch sprint)

**Verdict: code-complete candidate, NOT verified for launch.** All ten automated suites pass, but nothing has run in Roblox
Studio, on a phone, with real players, a real DataStore or real Robux. Complete [LAUNCH_CHECKLIST.md](LAUNCH_CHECKLIST.md)
before making the experience public. I do not claim multiplayer, Marketplace or mobile-performance results.

## 0.7.0 launch sprint, in priority order
1. **Saving/security.** Audited remotes, rewards, purchases and persistence (rate limits, payload validation, server-side
   prices, receipt dedupe, session leases). Fix: coin packs are paused and unprocessed receipts are left for Roblox to
   re-send on a profile that cannot save (locked/unavailable), so nobody pays for coins that vanish (new tests).
2. **Cosmetics.** Every skin, mask, trail, emote and collection is implemented and obtainable with coins now; Robux checkout
   exists only for items whose pass ID you enter. Premium skins redesigned (Shadow Runner, Mall Phantom, Golden Champion
   sunburst and more). Previews: joint/weld solving, live-avatar clone, audit with mannequin fallback, trail run on a track,
   a real-effect "Trail Studio" stage, emotes that play at once. All of this is **unverified until you look in Studio**.
3. **Monetization.** Step-by-step Creator Dashboard instructions and exactly where IDs go: [MONETIZATION.md](MONETIZATION.md).
4. **Gameplay/mall/UI.** Reviewed, no logic defects found beyond the above; tuned values unchanged. Mall (24 stores, 130
   hiding spots, 6,479 parts) and hub tests pass. Balance and feel need real playtests.

## What changed in 0.6.0 (cosmetics and the Shop; the rest of the game is unchanged)
| Area | Before (0.5.0) | Now |
| --- | --- | --- |
| Skins | 13 overlays that were mostly a hat or a back item on your own clothes | **14 full costumes**: body-conforming shells for torso, arms, legs and shoes plus props, your hair/hats/layered clothing tucked away and restored exactly. Shadow Runner, Mall Phantom, Street Legend, Royal Trickster, Galaxy Escape Artist, Dragon Racer, Jet Runner, Candy Pop and more; Epic/Legendary measurably more elaborate and with an aura |
| Masks | 8, several full-face boxes | **12**: smiley, kitty, jack-o'-lantern, phantom half-mask, astral visor and more; ears/stems/rings left off under headwear; hide face accessories; no clipping with any costume (tested for every pair) |
| Trails | 5 ribbons, **no working preview** | **10**, each drawn by real `Trail` and `ParticleEmitter` objects: speed streaks, electric sparks, cosmic stardust, shadow smoke, golden footprints, candy, flame, rainbow... One definition table drives the live objects and the Shop's emulation (viewports do not draw trails) |
| Emotes | 2 hand-written server loops, **no preview** | **7** procedural emotes + 3 podium victories from one pose system; played locally from announced attributes; same pose in Shop, game and podium; no uploaded animations or permissions |
| Previews | Static avatar; trails and emotes not shown | Auto-framed 3D preview of **your** avatar for every category: trail test run on a looping track, emotes that play at once, front/back/rotate/drag, replay, full-screen inspect, collection chips, still frames under reduced motion |
| Shop | Basic cards | Real thumbnails per category, rarity, owned/equipped/locked (with progress)/short-of-coins (exact shortfall)/coming-soon/not-ready states, honest coin and Robux wording, sale gate that refuses unimplemented items on the client and the server |
| Paid cosmetics | 3 bundles of recolors | **5 matching collections** (outfit + mask + trail + emote), priced under their pieces, no fake scarcity, all unconfigured until real pass IDs exist |

## What 0.5.0 changed (unchanged and still relevant)
| Area | Now |
| --- | --- |
| Characters | Players keep **their own Roblox avatar and animations**; costumes are optional overlays |
| Art | Warm saturated "Sunburst" palette, themed storefronts, ShadowMap lighting |
| Hub | Compact plaza, podium, live boards, kiosks |
| UI | Compact HUD, Shop and Locker always visible on the right |
| Performance | 6,479 parts |

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
Compile of 40 production scripts, deterministic rebuild, both place formats deserialize (ShadowMap and
`LoadCharacterAppearance = true` are asserted in the saved file), and ten suites:
rules 423 · data/shop/receipts 208 (equipment of all four kinds persists across a reconnect, legacy-id migration, the
sale gate) · gameplay + end-to-end 287 · appearance 622,677 (every skin x every mask on R15 and R6, hair/hat/layered
clothing/face-accessory hiding and exact restoration, trail objects, server emote lifecycle, podium) · **cosmetics
406,346** (see below) · client UI 2,087 (dock, menus, banners at 6 sizes; showroom previews; trail runs and replay;
emotes playing; drag/rotate/front/back; full-screen inspect clear of the dock; every item state; every card
thumbnail; client emote playback on every character; footprints; particle LOD) · legacy map 28,291 · mall 106,320 ·
hub 35 · enum validity 922 references.

**The cosmetics audit (`tests/cosmetics.spec.luau`) checks, for every item:** it is in the catalog and implemented
(and vice versa); each emote is finite, moves the body, keeps the feet near the floor, starts and ends at rest, loops
seamlessly or ends, and the costume stays glued to the limb through the whole pose; each trail builds real engine
objects whose colors, fades, taper, lifetime and particle settings equal the definition the preview emulates, stays
inside the mobile budget and shows a visible trail while running and none when standing; every skin is a 20-62 piece
costume covering the body with no floating, invisible or neon piece, and a higher tier means more pieces; no mask
piece overlaps a costume piece for any skin/mask pair; the preview camera frames the whole model at three aspect
ratios; collections are complete, priced under their pieces and free of fake scarcity; every Robux item has
`gamePassId = 0`.

### What the preview images are
`docs/previews/*.png` are **software geometry previews** produced by `tools/render-view.py`, `tools/render-characters.py`
(skins, masks, trail frames, emote key frames) and `tools/render-ui.py`: flat colors, no real materials, shadows, bloom, fonts, emoji or player avatars. They exist to
check composition, palette balance, sight lines and UI overlap without Studio. They are not screenshots of the game.

## NOT verified (needs a human in Studio, on a phone, or a published place)
| Area | Why it matters | How to verify |
| --- | --- | --- |
| **Lighting and exposure** | The biggest unknown. Ambient `(138,134,152)`, Brightness 2.1, ShadowMap and a light haze are reasoned values; interiors may read too dark or too bright | TESTING A1; tune `applyLighting()` |
| Real material look | Slate/Granite/WoodPlanks/Fabric textures tint differently from flat colors | Walk the mall in Studio |
| **Costumes on real avatars** | Shells are sized from the avatar's real part sizes, but tall/slim/wide/Rthro/R6 bodies, big layered-clothing hair and jackets, and the gold tint were never seen | cosmetics script A1-A3 |
| **Trail preview vs live trail** | The Shop shows a parts emulation of the same definition (viewports cannot draw trails); engine textures and blending will differ | cosmetics script A4-A6 |
| **Emote look and timing** | Poses are checked for finite, grounded, glued-to-body motion, not for charm or for limbs clipping a given costume | cosmetics script A7-A9 |
| **Showroom in a real ViewportFrame** | Auto-framing, drag-rotate, replay, full-screen and thumbnails run on mocks; real `ViewportFrame` lighting, `WorldModel` behavior and the avatar clone path are unproven | cosmetics script A10-A12 |
| Avatar overlays on real avatars (0.5.0) | Hat/hair clipping, tall/skinny bundles, R6, Rthro; gold tint on real limbs; restored clothes | TESTING A2–A3 |
| `HumanoidDescription` previews | `CreateHumanoidModelFromDescription` is async and unproven here; a mannequin shows if it fails | TESTING A4 |
| Slide and vault feel | Only the slide pose is authored; mood poses were removed so Roblox animations drive everything else | Two clients, TESTING B12 |
| Signs with emoji | Icons on blade signs and dock buttons depend on the client font | Look at storefronts and the dock |
| Multiplayer, late join, disconnects, 7 and 12 clients | Only mocked | TESTING section B |
| Mobile performance | Only part and light budgets; PerformanceController tiers unmeasured | Low-end phone |
| DataStore saving, passes, coin packs | All pass and product IDs are 0; no real settlement | MONETIZATION.md on a private test place |

## Honest ratings (out of 10, estimated from source and software previews — not measured)
| Area | Score | Why it is not higher |
| --- | ---: | --- |
| Skins and masks | 7 | Full costumes with a clear rarity ladder and tested no-clip/no-float rules, and the lineup reads well in the software preview. They are built from blocks and cylinders: they will look classic Roblox, not sculpted. Never seen on a real avatar or lit. |
| Trails | 7 | Ten distinct designs on real engine objects with a working, replayable preview and a mobile budget. The preview is an emulation; real textures and blending are unseen. |
| Emotes | 6 | Seven poses that visibly perform and are checked mathematically; procedural poses are stiffer than authored animation and cannot bend layered clothing. |
| Shop and previews | 7 | Every category previews, controls and states are tested at three sizes. The real ViewportFrame, fonts and thumbs on a phone are unseen. |
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
- Shop previews depend on a runtime `HumanoidDescription` call that could not be exercised (a mannequin is shown if it fails).
- Emotes are procedural poses, not authored animations: they are stiffer, they do not bend layered clothing (costumes hide it), and they are tuned to standard R15 proportions.
- Cosmetics are blocks and cylinders (no meshes, textures or custom accessories), so they read as classic Roblox rather than sculpted; real authored assets would need licensing and upload outside this repo.
- **The mall-gameplay request** (fuller store interiors, more shortcut routes, vents, kiosks, obstacles, flat-area polish) was **not started** in this pass: the cosmetics overhaul was prioritized.
- No HUD scale-up for large monitors: an attempt using `UIScale` was dropped because how `UIScale` treats `Position` offsets could not be confirmed without Studio. Check HUD text size on a 1080p/4K monitor and, if too small, scale the whole HUD through one full-screen container.
- The two-player Studio checklist (TESTING B) is the list of everything solo practice cannot prove.

## Owner actions
1. Open the place, check `Lighting.Technology` reads ShadowMap, and tune `applyLighting()` if needed.
2. Run the cosmetics script, then TESTING sections A and B. Fix what they find, in this order: Output errors, stuck spots, HUD clipping, performance, look.
3. Create passes and products (`MONETIZATION.md`), paste real IDs, rebuild with `./tools/build.sh`. Never use made-up IDs.
4. Provide licensed audio IDs in `Config.Audio` if wanted. Publish privately first; set max players to 12 and avatars to R15.
