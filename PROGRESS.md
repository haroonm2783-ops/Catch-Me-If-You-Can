# Catch Me If You Can — preserved development state

## Current delivery

The existing implementation has been continued and integrated, not restarted.
`main` was created and the initial commit `c4fc037` pushed to
`haroonm2783-ops/Catch-Me-If-You-Can`. The current integration, documentation,
regressions, and rebuilt artifacts extend that same `main` branch.

**Direct-open artifacts exist:**

- `dist/CatchMeIfYouCan.rbxl` — binary Roblox place, recommended download.
- `dist/CatchMeIfYouCan.rbxlx` — equivalent XML Roblox place.

Both contain all 15 production scripts, the complete baked city, lighting, spawn
metadata, R15 settings, and runtime service hierarchy. Both were deserialized
successfully after generation; every embedded script was compared to its source.
The large line count primarily reflects the serialized scene XML, not additional
hand-written gameplay or evidence that Studio gameplay has been tested.

## Implemented and connected

| Area | Current implementation | Verified here |
| --- | --- | --- |
| Round flow | Waiting, 16s intermission, 5s head start, 180s active chase, 10s results; 12-player roster; fair hunter rotation; small lobbies; Studio practice | Production services exercised with deterministic mocked boundaries |
| Movement/tagging | Server-owned sprint/slide/vault; cooldowns; geometry/LOS/range validation; movement correction; death/reset/departure elimination | Geometry/cooldown/role/deadline tests; actual engine physics pending |
| Neon Heights | Six distinct roof districts, 12 bridge/ramp routes, six ladders, two timing gates, street loop, skyline, social lobby, three podiums | Builder executed; geometry/spawn-clearance checks; valid serialized places |
| Interface | Loading/lobby, role/timer/alive HUD, menus, shop/locker, ViewportFrame preview, quests, career, settings, server leaderboard, results, spectating | Four viewport-size construction checks and input/action/camera regression tests |
| Cosmetics | Seven original outfits, five independent masks, trails, tag effects, two emotes, two victory presentations, nameplates | All 42 outfit/mask combinations instantiated, serialized, reapplied; podium/emote logic tested |
| Shop | Coins, free/milestone items, permanent gamepasses, Nightfall collection and cosmetic VIP | Ownership verification, prompt cancellation/failure, duplicate/debit tests; no real transactions |
| Progression | Levels/XP/coins, role stats, win streaks, win/loss rating ranks, three UTC daily quests, six achievements, milestone unlocks | Pure rules and production DataService tests |
| Saving | Versioned profiles, UpdateAsync leases, bounded retry, concurrent-write coordination, autosave, shutdown release, truthful statuses | Mocked failure/concurrency/reconnect/shutdown cases; Roblox DataStore verification pending |
| Feedback | Bundled SFX fallback, optional audio overrides, camera FOV/lean, tag bursts, countdown/final/last-runner cues, reduced motion | Client logic tests; real audibility/rendering/animation feel pending |
| Devices | Native movement/jump plus custom PC/touch/controller abilities, menu focus navigation | Mocked inputs and layouts; real devices pending |

## Verified commands and results

Run `./tools/check.sh` from the repository root. It compiles all production and
test Luau files, rebuilds both places, verifies their source and geometry content,
runs all six suites, and checks Git whitespace errors. The underlying command exit
codes are preserved. The latest complete run passed:

- **Rules:** 301 economy/profile/rank/quest/catalog assertions.
- **Data and shop:** 113 production-service checks with mocked Roblox APIs.
- **Gameplay:** 89 production-service checks with mocked timers, characters,
  raycasts, input, and lifecycle events.
- **Appearance:** 45,257 geometry/property/serialization/behavior assertions across
  42 skin/mask combinations and service cases; maximum 69 avatar parts. This large
  assertion count includes repeated finite-coordinate and collision-flag checks.
- **Client controllers:** 243 mocked UI/input/camera/preview/feedback checks.
- **Map:** 4,734 geometry, spawn-clearance, route, and baked-map reuse assertions.
- **Places:** both `.rbxl` and `.rbxlx` deserialize and contain the expected city,
  15 exact embedded scripts, R15 settings, and complete game hierarchy.

Tool versions: Rojo 7.7.1, Luau 0.742, Lune 0.11.0. Linux bootstrap downloads were
verified against official release SHA-256 digests. No integrity checks were bypassed.

## Concrete issues fixed during integration

- Prevented tags or reset events arriving after the 180-second deadline from
  stealing a runner victory between timer updates.
- Preserved runner movement history/vaults when releasing held hunters.
- Applied travel validation to vertical ladder climbing.
- Fixed shutdown accounting so delayed profile loads finish their final save and
  release their session lease before close accounting completes.
- Fixed a permanent-freeze risk when equipping trails during a frozen head start
  or vault: only showroom cosmetics can be anchored.
- Fixed short landscape shop layouts, mobile unequip, gamepad close/slide conflicts,
  restored controller focus, and initial/respawn/spectator camera recovery.
- Fixed collection previews to show included skins/masks/trails, added default-look
  restoration, and made empty nameplate/tag-effect equipment behave consistently.
- Connected sprint-trail visibility to actual sprint movement; added a distinct
  last-runner announcement before the final 30 seconds.
- Moved two ladders out of solid building facades and removed collision from the
  unreachable backdrop floor beneath the arena.
- Baked the authored city into both place formats; reused it at runtime rather
  than generating a duplicate map. Corrected enum/font serialization compatibility.
- Disabled streaming for this bounded map to keep distant spectator targets and
  arena geometry available. This requires actual mobile profiling before launch.

## Geometry and presentation budgets

The baked map has 1,528 parts, 413 neon accents, 22 signs, 10 shadowless local lights,
12 elevated traversal surfaces, and two moving shortcuts. Props are anchored,
noninteractive detail avoids unnecessary collision/query work, and no map parts
are generated repeatedly during rounds. All outfit geometry is noncolliding and
massless. The source uses original geometry, not downloaded free-model scripts.

`docs/NeonHeights-overview.png` is an architectural projection of the actual baked
geometry, generated by the optional `tools/render-overview.py` (Pillow + NumPy).
It is **not a Roblox Studio screenshot** or evidence of rendering performance.

## Still required before public launch

No Roblox Studio runtime is available in this cloud container. The following
remain unverified and are required outside it:

1. Open either generated place in Studio. Perform real 1/2/7/12-client tests from
   `docs/TESTING.md`, including late joins, resets, disconnects, full 180s timing,
   repeat rounds, vault collisions, moving gates, spectating, and podium cleanup.
2. Review the actual rendered city, lighting, avatar fit, camera, animation
   replication, UI text/overlap, and built-in audio. Adjust only observed problems.
3. Measure frame rate, memory, network traffic, and input ergonomics on phones,
   tablets, PC, and controller. Geometry budgets are not performance measurements.
4. Validate DataStore saving/rejoin/lease behavior in a private published test
   experience with a separate test store. Studio is explicitly session-only by
   default (`UseStudioDataStores=false`). Never claim mock saves reached Roblox.
5. Configure real pass IDs and sale prices using `docs/MONETIZATION.md`. All nine
   premium catalog entries currently use ID 0; paid prompts are disabled. Test
   real ownership, cancellation, restored passes, and collection entitlements.
6. Confirm the published experience uses R15 and max 12 players. Publish only after
   the manual gate passes. The game has not been published to Roblox by this task.
7. Playtest balance and long-term retention. Movement values and +24/−14 win/loss
   rating are initial tuning, not results of competitive balance studies.

Optional later improvements: original licensed/uploaded music (Music ID is 0),
richer custom uploaded animation/audio assets, global cross-server leaderboards,
ranked matchmaking, more cosmetics after the existing map/gameplay is validated.
Current leaderboards cover the server; ranks do not perform matchmaking.

## Exact continuation instructions

1. Use the existing checkout on `main`; do not create another project or worktree.
2. Read this file and README, then inspect `git status` and recent commits. Preserve
   any newer user work. Run `./tools/check.sh` to establish the current baseline.
3. Next priority is the Studio/manual checklist, not adding unrelated systems.
   Record observed repro steps, client count, device, and Studio Output errors.
4. Fix the smallest source change for each observed issue and add meaningful
   regressions where the headless harness can model it. Rebuild the place with
   `./tools/build.sh` after changes; generated places must match current source.
5. For map changes rebuild/reopen, or remove the generated NeonHeights model before
   Play so its builder reruns. Do not assume a Rojo source sync rebakes an existing map.
6. Update this progress record with actual results, commit on main, and push when
   authorized. Never describe the mocked suites as Studio multiplayer playtesting.
