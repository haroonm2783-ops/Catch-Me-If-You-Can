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

## 0.6.0 cosmetics acceptance script (start here)

Nothing below has been run by the authors: there is no Roblox Studio in the build environment, and the automated
suites only prove geometry, pose math, definitions, budgets and data contracts. Open
`dist/Catch-Me-If-You-Can-Final.rbxl`, press Play and confirm Output says `[Catch] CATCH MALL initialized. 0.7.0`
with no red errors and no `[Catch] Cosmetic ... has no implementation` warnings. To try Robux-priced items on your own avatar before real passes exist, use a Studio-only scratch change (for
example, temporarily mark the item owned in `DataService` for your session). Do not commit fake pass IDs; the shipped
catalog keeps every `gamePassId` at 0; those items are bought with coins (give yourself coins in Studio to test).

### A. Solo checks (one Studio client)
1. **Skins on your real avatar (R15).** Equip every skin from the Locker. For each, look at front, side and back and
   confirm: your face, head shape and skin tone show; no floating hat or hair; shells wrap your torso, arms and legs
   without gaps or z-fighting at the elbows, knees and waist; capes, wings, scarf and tail hang naturally and do not
   pass through your legs when you run; the aura is subtle. Compare with `docs/previews/Character-lineup.png`.
2. **Different avatars.** Repeat with a tall avatar, a very slim one, a wide one, a Rthro avatar, an avatar with big
   layered-clothing hair and a jacket, and an **R6** avatar. Note any costume that looks wrong; hair, back items and
   layered clothing must be hidden under a costume and come back exactly when you switch to Original You.
3. **Masks.** Equip each mask on Original You and on three different skins. Check it sits on the face (not floating in
   front or buried), that glasses on your avatar are hidden while a mask is on, and that cat ears, pumpkin stem,
   antenna, planet ring and jester bells show only when the costume has no hat. Check hair does not poke through.
4. **Trail preview.** Open the Shop > Trails. For each of the 10 trails click it: a character must run laps on the
   track with the trail drawn behind it, within about two seconds. Press REPLAY: the lap restarts and the trail
   clears. Drag the preview to rotate, use the arrows, FRONT and BACK. Judge colors, length and density.
5. **Trail on your avatar.** Own or temporarily grant a trail, equip it, sprint in the lobby: the live trail must
   appear only while sprinting, match the preview's colors and shape, and turn off when you stop. Check Golden
   Footsteps leaves gold footprints on the floor (not floating, not sinking), alternating feet, fading in ~2 s.
6. **Side by side.** For every trail put the Shop preview next to the live trail and note differences (the preview is
   an emulation with plain parts; the live trail uses the engine's textures and blending). Report anything that looks
   clearly wrong, too faint, or too heavy.
7. **Emote preview.** Shop > Emotes: clicking each of the 7 emotes immediately plays it on your avatar; it loops;
   REPLAY restarts it; rotate and FULL work. Judge whether each reads as intended (wave, shuffle, sneaky tiptoe with
   a shush, chicken flaps and pecks, dramatic faint onto the floor and recovery, backflip with arms-up landing, royal
   spin and bow). Look for limbs passing through the body or costume.
8. **Emote in the game.** In the lobby play each owned emote from the Locker (PLAY ON MY AVATAR) and the dock EMOTE
   button: you must perform it, stop when you move or when a round starts, and be restored to normal afterwards. Try
   it while a layered-clothing avatar and a wing/cape costume are worn. Try spamming (1.5 s cooldown).
9. **Podium.** Win or fake a results phase: the winners' avatars wear their costumes and perform their equipped
   victory pose without the costume separating from the limbs.
10. **Shop states.** Check card status text and the detail button for: owned, equipped, locked milestone (progress
    shown), affordable, short of coins (exact shortfall), and every premium item (must show its coin price and a working coin button, no Robux button while its pass ID is 0). Buy one coin item and one free item end to end; confirm the wallet and inventory update
    once, and that nothing is charged twice if you press quickly.
11. **Framing.** In the detail panel and full-screen inspect, confirm no model is cut off at the head or feet at any
    rotation (Dragon Racer wings, Galaxy hat, jester crown, bunny ears, flip and faint emotes) and that the model is
    large enough to judge. Test windows from 1920x1080 down to a 320x568 phone.
12. **Mobile and PC layout.** At 390x844 portrait, 844x390 landscape and 1280x720: Shop and Locker buttons stay
    visible, the detail panel scrolls, controls (rotate, front, back, replay, full) are tappable, the inspect view does
    not cover the dock, and chat does not overlap the panel. Touch-drag rotates the model.
13. **Reduced motion.** Turn on Settings > Reduced motion: previews hold a still pose and a frozen trail.
14. **Round safety.** Open the Shop mid-round: the round continues; equipping shows the toast "shows up after this
    round"; emote buttons say they play in the lobby.
15. **Performance.** With the Developer Console (F9) and the MicroProfiler open, look at the Shop with a full thumbnail
    grid on desktop and on a mid-range phone; then play a round wearing the heaviest costume (Dragon Racer) with the
    heaviest trail (Cosmic Stardust). Note frame time, memory and particle counts; try MEDIUM and LOW graphics.
16. **Fonts and symbols.** Confirm the symbols used in the UI render (lock, check mark, play, coin, emoji icons); if any
    shows a box, replace it in `UIController.lua`.

### B. Needs two or more players
1. Other clients see your costume, aura, trail, footprints and emotes; the emote starts for them within a moment and
   ends when it ends. Late joiners see an emote that is already playing at the right moment.
2. Other players' emotes are interrupted correctly when a round starts or they walk away.
3. 12 clients wearing the heaviest costumes and trails: check client frame rate and that distant avatars drop their
   particles. 4. Equip changes mid-round are applied after the round for everyone.

### C. Data and money (published private test place only)
1. Equip a skin, mask, trail and emote, leave and rejoin: all four come back; unequip the trail, rejoin: it stays off.
2. A player who owned **Midnight Magician** in an older save now owns **Royal Trickster**.
3. Create passes for the Robux items, enter the IDs, buy one: it appears once, equips, persists, the collection grants all four
   pieces, and buying a collection piece you already own does not break anything. Cancel a prompt: nothing is granted.

## 0.5.0 acceptance script (art direction, hub, UI)

Nothing below has been run by the authors: there is no Roblox Studio in the build environment. Open
`dist/Catch-Me-If-You-Can-Final.rbxl`, press Play and confirm Output says `[Catch] CATCH MALL initialized. 0.5.0`
with no red errors. Then work through A (solo) and B (needs two or more players). Write down device, client
count and what you saw; a green automated check is not a pass.

### A. Solo Studio checks (one client is enough)

1. **Lighting technology.** In the Explorer open `Lighting`. **Technology should read ShadowMap.** The saved place
   sets it; if Studio shows Compatibility or Future, set ShadowMap and re-save. Then judge the look: warm and
   colorful, not washed out and not murky. If interiors are too dark or too bright, tune `Ambient`,
   `OutdoorAmbient` and `Brightness` in `applyLighting()` (`src/server/World/MallBuilder.lua`).
2. **Your own avatar.** You must spawn as your own Roblox avatar: face, hair, clothes and the normal run, jump and
   idle animations. Nothing should be recolored. Equip each skin in the Locker (left-hand `LOCKER` button): the
   overlay should sit on your avatar without clipping through limbs. **Check hats against your own hair**: hat
   skins hide your hair/hat accessories, back items never do. Try a tall or skinny bundle and an R6 avatar.
3. **Golden Champion** turns your limbs gold and stashes your shirt and pants (restored when you switch). Confirm
   your face stays visible and that un-equipping restores your exact colors and clothes.
4. **Shop previews match.** The preview in the Shop and Locker should be *your* avatar wearing the item. If the
   preview shows a plain blocky mannequin, `HumanoidDescription` previews failed: report the Output warning.
5. **Hub.** After spawning: the sunburst entrance, chevron path, podium, two leaderboards and the Shop and Locker
   kiosks are in front of you. Walk to a kiosk and press the prompt: the menu must open. The board above the
   entrance should show a countdown. Check nothing is empty, floating or blocking the spawn.
6. **HUD at every size.** Lobby, round (Runner and Hunter) and results at 1920x1080, 1280x720, a 390x844 phone
   portrait, an 844x390 landscape phone and a 320x568 small phone. **SHOP and LOCKER (right side) must always be
   visible and clickable**, including during a round and on the results card. Open each menu mid-round: the round
   keeps going, you remain taggable, and big menus become a narrow drawer. **Chat must stay in its default
   top-left corner and never overlap the HUD.** Report any clipped text.
7. **Practice round.** Solo in Studio starts a practice round. The HUD should say *PRACTICE / NOTHING IS SAVED*, coins
   you grab are labelled *Practice coins*, and the results card says nothing is saved. Your wallet must not change.
8. **Hiding, search, scan** (use the practice round and a second client for the search side). Fitting rooms, lockers,
   stalls, **air vents** (back corridors), toy chest, shoe box and dog house all work with E, last at most 7 s and
   cannot be used again for 12 s.
9. **Escape routes.** Escalators, grand stairs, skybridges, corner ladders, balcony drop gaps. Try to leave the map,
   reach the roof or wedge into a wall. Report any stuck spot.
10. **Performance.** On a low-end phone, record FPS, memory and join time in the full mall. The client graphics tier
    is the `CatchGraphicsTier` attribute on your Player (1 HIGH, 2 MEDIUM, 3 LOW). Try Settings > GRAPHICS.

### B. Needs two or more real players (cannot be proven by solo practice)

| # | What to test | Why a second player is required |
| ---: | --- | --- |
| 1 | Roles, 5 s head start, hunter release, tagging, tag range and line of sight | Only a real hunter and runner exercise server-side tag validation |
| 2 | A hunter searching a cell with a hidden runner inside; the reveal highlight; hidden runner not taggable | Needs one hider and one searcher |
| 3 | The hunter proximity glow (red screen edges) as a hunter closes in, and its absence while hidden | Needs a hunter within 34 studs |
| 4 | The other client sees your skin, mask, aura, trail and the hunter's red sash and outline | Replication to a second client |
| 5 | Equipping mid-round (look changes after the round) and equip bursts for Rare+ skins | Observed from both sides |
| 6 | **Real rewards and saving**: a competitive round grants XP and coins once; results card matches the wallet; rejoin keeps progress (published test place with its own DataStore) | Practice rounds never award anything |
| 7 | Round results: podium shows the winners' real avatars wearing their skins, victory pose plays | Needs winners |
| 8 | Hub leaderboards ordering with two accounts and live updates; kiosk opens the menu only for the presser | Needs two profiles |
| 9 | Late join during a round (spectates), disconnect mid-round, hunter leaving gives a runner win | Lifecycle with two players |
| 10 | 7 and 12 clients: spawn separation, two hunters, performance and network load | Scale |
| 11 | Round modifiers (Infection needs 4+, Swarm 6+) and infected respawn | Minimum player counts |
| 12 | Slide, vault and sprint as seen by *other* clients (slide pose is client-rendered per player) | Remote rendering |

### C. Before launch (owner actions)

1. **Money (private test place only).** Create game passes and developer products, put the IDs in `Catalog.lua`, then
   check cancel, success, rejoin (no double charge) and that coins arrive exactly once and persist.
2. **Audio.** Provide licensed asset IDs in `Config.Audio` if you want music; zero uses engine fallbacks or silence.
3. Publish privately, set max players to 12 and avatar type R15, then rerun A and B on the published server.

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
| `appearance.spec.luau` | Skin/mask/aura combinations on R15 and R6, reversible hair-hiding and gold tint, previews match live avatars, cosmetic service lifecycle | Visual quality and clipping on real avatars, real `HumanoidDescription` previews |
| `mall.spec.luau` | Mall geometry, 130 hiding spots, doors, navigation of both floors, part and light budgets, hub footprint | Collision feel, lighting, real frame rate |
| `hub.spec.luau` | Leaderboard sorting, status board text, kiosk menu requests and throttling | How the hub looks, real prompt interaction |
| `client_controllers.spec.luau` | Menu construction, input/focus, cameras and settings with simulated boundaries | Actual device ergonomics, engine layout/rendering, or audio audibility |
| Place serialization checks | Both final formats deserialize and contain required content | Studio loading and live gameplay |

See [PROGRESS.md](../PROGRESS.md) for the latest executed results, rather than
assuming that the existence of a test means it passed on your current changes.

## First Studio open

1. Open the final place and inspect the baked Catch Mall map before pressing
   Play. Confirm `CatchShared`, `CatchServer`, and `CatchClient` exist in the
   services mapped by `default.project.json`.
2. Open **Output** and run Play. Confirm the initialization message reads `[Catch] CATCH MALL initialized. 0.5.0`, no script
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
