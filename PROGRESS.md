# Catch Me If You Can — preserved development state

## Current delivery — version 0.2.1

The existing implementation has been continued and integrated, not restarted.
`main` was created and the initial commit `c4fc037` pushed to
`haroonm2783-ops/Catch-Me-If-You-Can`. This correction extends the 0.2.0 delivery,
commit `14d04c6`, on that same
`main` branch. No gameplay systems or saved profile schema were restarted.

**Direct-open artifacts exist:**

- `dist/Catch-Me-If-You-Can-Final.rbxl` — binary Roblox place, recommended download.
- `dist/Catch-Me-If-You-Can-Final.rbxlx` — equivalent XML Roblox place.

These are freshly generated from version 0.2.1 source, not renamed old files.
The older `CatchMeIfYouCan` paths are also rebuilt as byte-identical compatibility
copies. `Workspace.CatchGameVersion`, Studio Output and the UI show **0.2.1**.

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
| Interface | Loading/lobby, role/timer/alive HUD, menus, shop/locker, ViewportFrame preview, quests, career, settings, server leaderboard, results, spectating | Five viewport-size construction checks and input/action/camera regression tests |
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
- **Data and shop:** 136 production-service checks with mocked Roblox APIs.
- **Gameplay:** 197 production-service checks with mocked timers, characters,
  raycasts, input, and lifecycle events.
- **Appearance:** 157,251 geometry/property/serialization/lifecycle assertions:
  all 42 skin/mask combinations in previews, live R15 and live R6; maximum 87
  avatar parts including Hunter identity. Counts include repeated coordinate
  and collision-flag checks, not independent Studio play scenarios.
- **Client controllers:** 430 mocked UI/input/camera/preview/feedback checks.
- **Map:** 28,292 geometry, spawn-clearance, route, and baked-map reuse assertions.
- **Places:** both `.rbxl` and `.rbxlx` deserialize and contain the expected city,
  15 exact embedded scripts, R15 settings, and complete game hierarchy.

Tool versions: Rojo 7.7.1, Luau 0.742, Lune 0.11.0. Linux bootstrap downloads were
verified against official release SHA-256 digests. No integrity checks were bypassed.

## Completed in the 0.2.1 roof/slide correction

The user tested 0.2.0 in Studio and reported that roofs still flickered and C
still did not slide. Their screenshot showed that version running. This pass
addresses two concrete defects missed by the earlier automated coverage:

- **R6 ground detection:** the old ray reached only 2.25 studs below a standard
  R6 root, which stands 3 studs above the floor. It rejected a grounded slide
  before creating its actuator. Ground support now includes R6 leg height;
  R15 keeps its own HipHeight calculation. Vault landing/clearance uses the same
  rig-aware offset. The floor-gap allowance stays bounded.
- Added standard/scaled R6 and R15 cases, right-leg fallback, airborne rejection,
  slide start/acceleration/cleanup and reset checks using finite-length rays.
  The existing C, controller B and touch input paths remain connected to the
  same server action, propulsion, cooldown and pose systems. Running these new
  tests against the previous movement source fails at R6 ground detection.
- **Roof flicker:** each roof panel and its cream support cornice had identical
  top elevations. Moved support tops to the panel underside while keeping all
  walking roof heights unchanged. Also removed duplicate broad top faces at the
  street foundation, footpath/island-wall corners and flat roof/bridge junctions.
  A scan of 162 broad level top faces finds zero coplanar overlaps, down from 29
  overlapping pairs in the previous place. Narrow decorative trim is excluded.
- Trimmed only bridge floor already supplied by a roof. Sloped routes, route
  widths, rails and spawn transforms are preserved. New geometry checks sample
  continuous floor support across all seven flat roof/deck seams, independently
  of existing parapet obstacles. Map schema version 3 replaces older geometry.
- Rebuilt both final place formats from current source. Part, collision and light
  counts remain 1,646 / 310 / 10; this fix adds no scene geometry or per-frame work.

These are verified code/geometry corrections. Roblox Humanoid physics and rendered
flicker still require the 0.2.1 Studio acceptance pass; no cloud test runs Studio.

## Completed in the 0.2.0 polish pass

- Replaced intermittent slide velocity pulses with a bounded planar LinearVelocity
  actuator while suspending the competing Humanoid ground controller. Sliding
  follows existing momentum, eases into/out of a 0.72-second move and has a
  server-enforced 3-second cooldown. No uploaded animation IDs are required.
- Added eased local/opponent R15/R6 slide poses and cleared stale menu-focus and
  respawn cooldown issues. Exercised wall, ledge, jump/vault, death, seat, teleport,
  disconnect and round-freeze cleanup. Fixed Physics-state recovery when a slide
  ends as a Hunter becomes frozen for the next round.
- Fixed premature appearance success on partial avatars and added R6 fitting,
  late-Humanoid/accessory/BodyColors recovery and profile-loading fallback. The
  free courier now has a teal jacket, dropped hood, undershirt, coral satchel,
  cargo pockets and sneakers. Hunter cuffs/outline preserve selected cosmetics.
- Refined premium silhouettes and faceted masks, retained independent equipment,
  and verified saved skin/mask selection across a mocked store release/rejoin.
  Corrected shop descriptions to match actual geometry; all paid IDs remain zero.
- Added district-specific roof silhouettes, fruit/washer landmarks, facade layers,
  antennas, a deeper skyline and an arrival canopy/podium frame. Source comparison
  found all 310 collision parts and all spawn/podium transforms unchanged by the
  art pass. Added art safety, finite-transform and old-map replacement checks.
- Reduced neon accents from 413 to 334, disabled distant skyline shadows, kept
  lights at 10 and map parts below 1,800. These are static budgets, not phone FPS.
- Enlarged the illuminated locker stage, added turn/front controls, improved shop
  hierarchy, responsive quests/results and HUD progress. Fixed results duration
  binding and tested all panels and purchase/equip acknowledgement flows.
- Added grounded slide streaks and landing cues with existing audio fallbacks.
- Fixed four vertical art beams whose collinear lookAt axes produced invalid
  serialized rotations. The bake now fails on every nonfinite part transform.
- Generated both requested Final place names from current source, reopened every
  delivery/compatibility file and verified exact embedded scripts and version.

That pass fixed locomotion/input hazards, but the user's subsequent Studio test
showed that it did not resolve their slide failure. The R6 ground-height rejection
above was found in this follow-up. Headless checks cannot establish physics feel.

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

The baked map has 1,646 parts, 334 neon accents, 22 signs, 10 shadowless local lights,
12 elevated traversal surfaces, and two moving shortcuts. Props are anchored,
noninteractive detail avoids unnecessary collision/query work, and no map parts
are generated repeatedly during rounds. All outfit geometry is noncolliding and
massless. The source uses original geometry, not downloaded free-model scripts.

`docs/city-backup-overview.png` is an architectural projection of the actual baked
geometry, generated by the optional `tools/render-overview.py` (Pillow + NumPy).
It is **not a Roblox Studio screenshot** or evidence of rendering performance.
`docs/Character-lineup.png` similarly depicts the actual costume geometry (all
seven outfits plus Hunter identity), not engine materials/lighting. Both images
were regenerated and visually inspected during the 0.2.0 art pass.

## Still required before public launch

The user confirmed running, sprinting and vaulting in the previous Studio build,
and reported that sliding and roof rendering remained broken in 0.2.0. The updated
0.2.1 physics and rendering have not been played in Studio here.

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
3. Next priority is the 0.2.1 acceptance checklist in `docs/UPDATE_0_2.md` and
   Studio/manual checklist, not adding unrelated systems.
   Record observed repro steps, client count, device, and Studio Output errors.
4. Fix the smallest source change for each observed issue and add meaningful
   regressions where the headless harness can model it. Rebuild the place with
   `./tools/build.sh` after changes; generated places must match current source.
5. For map changes rebuild/reopen, or remove the generated NeonHeights model before
   Play so its builder reruns. Do not assume a Rojo source sync rebakes an existing map.
6. Update this progress record with actual results, commit on main, and push when
   authorized. Never describe the mocked suites as Studio multiplayer playtesting.
