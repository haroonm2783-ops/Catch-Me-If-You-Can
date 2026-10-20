# Verification and Studio playtest checklist

Roblox Studio, live Roblox physics/rendering, real DataStores, and real purchase
settlement have **not** been exercised in the cloud environment. The checks below
are the acceptance work still required. Record device, place version, client
count, result, and reproduction steps for each test; do not mark a check passed
from source inspection alone.

The user confirmed that the previous delivered place runs, sprints, and vaults
in Studio, and reported a broken C slide and insufficient visual quality. This
is evidence about that previous build. Follow-up feedback confirmed slide and
floor defects remained in 0.2.0. Begin the **0.2.1** regression pass with
[the update checklist](UPDATE_0_2.md); do not count prior play as verification of
the new slide, appearance, map decoration, or UI changes.

## 0.4.0 Catch Mall acceptance script (start here)

Do these in order in Studio (**Test → Server & Clients, 2 clients**), then repeat items 1–4 on a
real phone in a private published server. Nothing below has been run by the authors.

1. **Look.** Open the place before Play. The mall should read bright and colorful, not dark.
   Walk both floors, the atrium, food court, arcade and cinema. Note anything washed out,
   z-fighting, floating, or a collision snag. Tune `applyLighting()` and the palette `P` in
   `src/server/World/MallBuilder.lua` / `Mall/Kit.lua`.
2. **HUD.** In the lobby, in an active round as Runner and as Hunter, as a spectator and on the
   results screen: **SHOP and LOCKER must be visible and clickable at all times.** Open each
   during a round: the round must continue, you must still be taggable, and the panel must be a
   right-hand drawer. Check 1440×900, a 390×844 phone portrait, an 844×390 phone landscape and a
   320×568 small phone. Report clipped text.
3. **Hide / search.** As Runner, hold E at a fitting room, locker and stall. You should step in,
   see the HIDING meter, and be released after ≤7 s or by LEAVE / jump. As Hunter, hold E on an
   occupied cell: the runner must be flushed out and highlighted for ~2.5 s. A hidden runner must
   not be taggable. Try to exploit: hide in the same cell repeatedly (cooldown 12 s), walk out of
   the cell, and tag through the door.
4. **Coins and scan.** Collect coins (counter + ping sound + results rewards). As Hunter press Q:
   runners within ~45 studs highlight; occupied cells show "?" markers; cooldown 25 s.
5. **Escape routes.** Use the 8 escalators, 4 grand stairs, 2 skybridges, corner ladders and the
   balcony drop gaps. Try to leave the map, reach the roof or squeeze into a wall. Report every
   spot where you can get stuck, plus any hide cell a hunter cannot reach.
6. **Cosmetics.** In the Locker equip every skin and mask, change skin tone and hair color, then
   rejoin (needs a published test place with a separate DataStore). Equipping mid-round must say
   it applies after the round. Faces should change (smile, determined, grin, scared, joy, sad).
   Check hands raised on Win, slumped on Lose, glancing when Scared: **arm/head rotation signs are
   unverified; if an arm bends the wrong way, flip the sign in `MOOD_POSES` in `MovementController.lua`.**
7. **Round loop.** Play 5+ rounds with 2 and 7+ clients: roles, head start, results rewards
   breakdown, XP/coins arriving, level-ups, quests, daily login, tutorial first-run.
8. **Money (private test place only).** Create one game pass and one developer product, put the IDs
   in `Catalog.lua`, then check cancel, success, rejoin (no double charge) and that coins arrive
   exactly once and survive a rejoin.
9. **Performance.** On a low-end phone, record FPS, memory and join time in the full mall. If it is
   unplayable, consider enabling StreamingEnabled with `ReplicationFocus` and re-testing spectating.

## Reproduce automated checks

From the repository root:

```bash
./tools/bootstrap.sh
./tools/check.sh
./tools/build.sh
```

Tool versions are pinned in `aftman.toml` and `tools/bootstrap.sh`; use those
versions for repeatable output. The build produces both
`dist/Catch-Me-If-You-Can-Final.rbxl` and `dist/Catch-Me-If-You-Can-Final.rbxlx`, with the city baked
into the place and the gameplay scripts included. Open either final file using
**Roblox Studio → File → Open from File**. The intermediate sources-only place is
not the playable deliverable.

| Automated coverage | What it establishes | What it cannot establish |
| --- | --- | --- |
| Luau compilation | Source syntax compiles | All engine APIs behave correctly at runtime |
| `rules.spec.luau` | Rewards, ranks, profile normalization, quests, catalog invariants | Economy balance or player enjoyment |
| `data_service.spec.luau` | Production data/shop logic with mocked service boundaries, leases, retries, duplicate protection | Real DataStore quotas, availability, or paid settlement |
| `gameplay.spec.luau` | Production round and movement logic under deterministic inputs | Roblox network ownership, collision feel, or lag fairness |
| `map.spec.luau` | Generated geometry, spawns, routes, and analytic clearance checks | Engine navigation, visibility, streaming, or GPU performance |
| `appearance.spec.luau` | Cosmetic combinations, instance properties, equipment and podium construction | Visual quality and animation clipping on real R15/R6 avatars |
| `client_controllers.spec.luau` | Menu construction, input/focus, cameras and settings with simulated boundaries | Actual device ergonomics, engine layout/rendering, or audio audibility |
| Place serialization checks | Both final formats deserialize and contain required content | Studio loading and live gameplay |

See [PROGRESS.md](../PROGRESS.md) for the latest executed results, rather than
assuming that the existence of a test means it passed on your current changes.

## First Studio open

1. Open the final place and inspect the baked Catch Mall map before pressing
   Play. Confirm `CatchShared`, `CatchServer`, and `CatchClient` exist in the
   services mapped by `default.project.json`.
2. Open **Output** and run Play. Confirm the initialization message reads `[Catch] CATCH MALL initialized. 0.4.0`, no script
   errors, one map instance, a loaded avatar, and a responsive HUD. Stop and Play
   again to check cleanup/reinitialization.
3. Before published multiplayer testing, set the experience's maximum player
   count to **12** and avatar type to **R15** in Studio/Creator Dashboard settings.
   The code caps a round at 12, but it cannot configure your published server cap.
4. Keep the first test experience private. No custom external audio is required
   for gameplay: music ID zero is silent and zero SFX IDs use bundled cues.
   Configure only audio you own or can use, then test it in the published place.

## Multiplayer matrix

Use Studio's **Test → Server & Clients** / local server controls. Studio versions
may limit the number of local clients; if 12 cannot be launched locally, use
invited testers in one private published 12-player server. Local clients simulate
multiple players on one machine, not device performance or real internet latency.

| Clients | Expected behavior and required checks |
| ---: | --- |
| 1 | With default `StudioSolo=true`, the sole player becomes a Runner in explicitly labeled Studio practice. Explore all routes. A full practice round gives no XP, coins, rating, wins, or quest progress. A one-player **published** server waits for a second player. |
| 2 | One Hunter and one Runner. Exercise an entire catch victory and a full survival victory; repeat at least three rounds. |
| 7 | Two Hunters and five Runners. Check the role-count threshold, hunter rotation, simultaneous tag attempts, survivor awards, and three-person podium selection. |
| 12 | Two Hunters and ten Runners. Run at least ten consecutive rounds with late joins, disconnects, cosmetics, menu use, and device/network profiling. Check spawn separation and roster updates on every client. |

## Round, movement, and chase checks

- Waiting requires two ready players outside Studio practice. Intermission is
  **16 seconds**, then Runners get a **5-second head start** with Hunters held
  server-side. The active chase lasts a separate **180 seconds**. Results last
  **10 seconds**, then the next intermission begins.
- Head-start Hunters cannot walk, sprint, jump, vault, or tag. Releasing them
  must not interrupt a Runner already sprinting or vaulting. Role labels,
  announcements, cooldowns, and timers agree across clients.
- Only an active Hunter can tag. Test near/far edges of the **5.8-stud** range,
  solid walls between players, repeated input, two Hunters attempting the same
  Runner, and tagging exactly as the timer expires. A Runner cannot be tagged
  twice, and a late tag must not steal an expired-timer survival win.
- A tagged player leaves the arena and can cycle spectator targets. The final
  Runner and final **30 seconds** display their chase cues. Spectating handles
  the target leaving/resetting and restores the local camera next round.
- Reset or fall during head start/active play; disconnect the only Hunter, the
  last Runner, and a player during results. No frozen character, stuck round,
  double reward, or lingering avatar may remain. A late join spectates until the
  next round; a player whose profile/avatar is still loading is not drafted early.
- Survival victories reward surviving Runners, not eliminated teammates.
  Hunters win when every Runner is eliminated. Results, progression, roster,
  podium, and the next round must agree on the winner.
- Sprint, slide, jump, vault low obstacles, climb ladders, and traverse all ramps
  and bridges. Slide needs grounded motion (at least 4 studs/second), lasts 0.72 seconds and
  has a 3-second cooldown; vault
  requires a clear server-detected route and has a 1.1-second cooldown. Check
  ceiling clearance, edges, angled walls, landing, repeated inputs, and respawns.
- Start the slide check on an open, flat roof with a moving R6 avatar, then
  repeat with R15 and after respawning. Sweep the camera across all roofs and
  flat bridge junctions to check for the reported black/cream flicker. The
  Ember-to-Polar entrance has an existing low corner parapet: test jump/vault
  access there separately from open-floor sliding; the floor seam check alone
  does not establish an unobstructed walking route.
- Traverse both animated **TIMING / BYPASS** gates while they rise and lower.
  Their bypass paths must remain useful, collisions must not trap players, and
  legitimate traversal must not trigger a movement correction. Try each direction
  with simulated latency, sprint, slide, and vault.
- In Studio network emulation, repeat representative chases at 100–200 ms latency
  and modest packet loss. Record corrections, missed inputs, delayed tags, and
  whether the server and every client agree on the result.

## Controls, UI, cosmetics, and accessibility

| Action | Keyboard/mouse | Controller | Touch |
| --- | --- | --- | --- |
| Move / camera | Roblox defaults | Roblox defaults | Roblox thumbstick / drag |
| Sprint | Hold Shift | Toggle L3 | Toggle RUN |
| Slide | C | B while playing | SLIDE |
| Jump / vault attempt | Space | A while playing | Default jump button |
| Tag (Hunter) | F | R2 | TAG |
| Open locker | LOCKER button | Y | LOCKER button |
| Select / close menu | Click / close button or Escape | A / B | Tap / close button |

- Check desktop 1920×1080 and 1280×720, a small phone in portrait and landscape,
  a notched phone, a tablet, and a real gamepad. Studio's device emulator catches
  layout problems; physical devices are still required for input and performance.
- All shop categories, locker items, quest claims, career, roster, settings, and
  results remain readable and scrollable. Check safe insets, long names, category
  scrolling, preview sizing, and overlapping touch/jump/menu buttons.
- Opening a menu releases sprint. Gamepad B closes a menu without sliding; A
  selects without vaulting; Y opens/closes the locker. Focus survives a profile
  update. Spectator arrows are reachable on touch and gamepad.
- Try every available skin/mask pair in previews and on a live avatar. Masks must
  stay independent when switching skins; unequipping a mask or trail must remove
  it. Respawns/repeated equips must not accumulate accessories or alter gameplay
  speed/collision. Test scaled R15 body proportions and the R6 compatibility fallback. Reset while
  a profile is still loading; the complete free outfit must appear and then
  yield to the selected owned outfit when loading finishes.
- Check earned unlocks, coin debit once, insufficient balance, owned-item states,
  trails during sprinting, tag-effect variants, lobby/results emotes, and victory
  poses on the podium. Collection/VIP previews must represent their grants.
- Toggle reduced motion, camera shake, music, and SFX; check immediate behavior
  and saved preferences. A muted/unavailable sound must leave visual feedback.
  Music remains silent until an authorized asset ID is configured.

## Persistence and progression against Roblox

The default `Config.Persistence.UseStudioDataStores=false` deliberately gives
Studio temporary data. This is expected, even when Studio API access is enabled.
CAREER displays save status. The ROSTER leaderboard shows current-server players'
lifetime values; there is no implemented cross-server global leaderboard.

1. Publish a **separate private test experience**. Set
   `Config.Persistence.StoreName` to a test-only name such as
   `CatchMeIfYouCan_Test_v1`; rebuild and publish that configuration only there.
2. For Studio service testing only, also set `UseStudioDataStores=true` and enable
   **Game Settings → Security → Enable Studio Access to API Services** for that
   test experience. Never point destructive test fixtures at production profiles.
   Published servers use DataStores regardless of the Studio-only toggle.
3. Use actual accounts in a private published server to verify real IDs and
   real-service behavior. Complete competitive rounds, buy a coin cosmetic, equip
   it with a mask, claim a completed quest, and change settings. Wait for successful
   save status, leave, and rejoin another server; every value should restore.
4. Verify claim-once behavior, UTC daily quest rollover, level/rank thresholds,
   milestone cosmetics, and no practice rewards. The three daily quests track
   competitive rounds, tags, and survival time.
5. Check normal departure and server shutdown writes. If another session holds a
   profile lease, the second session must clearly report non-saving mode and must
   not overwrite the original. Autosave is normally 60 seconds; leases last
   180 seconds and are renewed during saves. Rejoin after leaving the old server
   to retry a blocked load.
6. Exercise unavailable storage, failed/retried saves, delayed loads during
   shutdown, and unsupported profile formats with the deterministic service tests.
   If a real outage occurs, preserve server logs and confirm the UI never reports
   a successful save for an unsuccessful write. Do not destroy a real profile to
   simulate failure.

Configure and test pass entitlements separately using [MONETIZATION.md](MONETIZATION.md).
Changing a store name is not a migration; retain the production name once real
players have progress, or implement an explicit migration before changing it.

## Visual review and performance acceptance

Review from street level, the lobby, bridges, rooftops, spectator cameras, and the
podium at low and high graphics settings. Check landmarks, route readability,
signs, atmospheric haze, lighting contrast, clipping, and streamer pop-in while
running. Adjust only after viewing the actual Studio/client render.

Use Roblox performance stats, Developer Console, and MicroProfiler on actual
devices. The following are **targets to measure**, not achieved benchmark claims:

- Desktop: aim for 60 FPS / 16.7 ms frame time in a full 12-player chase.
- Representative lower-end mobile: sustain at least 30 FPS / 33.3 ms frame time
  with responsive inputs and readable effects at the chosen graphics setting.
- Server: target 60 Hz simulation; investigate recurring frame spikes and any
  script consistently spending more than roughly 5 ms per frame.
- Run a 20-minute session with repeated rounds, menus, previews, respawns, tags,
  and podiums. Track instance count, memory, render/physics cost, and network
  traffic. Counts should settle after cleanup, without continuous growth.
- Capture worst-case frames with 12 equipped avatars, trails, tag effects, and
  podiums. Profile before reducing decoration; prioritize expensive shadows,
  excess lights, particles, and repeatedly rebuilt UI/geometry identified in the
  capture. Device-specific memory budgets must be established from measurements.

Do not publish as launch-ready until this matrix, live persistence, and configured
purchase tests have recorded passing results and remaining issues are triaged.

The current bounded map sets `StreamingEnabled=false` so spectators can see every
runner and all arena geometry. Validate memory/FPS on target phones; enabling
streaming later requires a proper spectator replication-focus implementation.
