# Catch Me If You Can

An original Roblox multiplayer chase game set in **Catch Mall**: a bright, two-floor
shopping mall with a fountain atrium, escalators, a food court, an arcade, a cinema and
24 themed stores. Runners grab spinning coins and duck into fitting rooms, lockers and
stalls; hunters search the hiding spots, scan for movement and tag everyone they find.

**Version 0.5.0 is a deliberate art-direction change.** The game now aims to look and feel like a
cheerful, colorful, popular Roblox experience rather than a tech demo:

- **You play as your own Roblox avatar**, with Roblox's normal animations. Skins are *optional* overlays
  (hats, backpacks, capes, wings, tails, auras) and masks sit on your real face. No more custom blocky bodies.
- **"Sunburst Mall"**: a bold, warm, saturated palette, themed storefronts with striped awnings and icon signs,
  neon only for screens, bulbs and coins, and a gentler lighting setup that avoids washed-out surfaces.
- **A compact spawn hub** with a sunburst mall entrance, chevron path, winners' podium, live leaderboards,
  Shop and Locker kiosks and a status board.
- **A simpler interface**: small timer and wallet chips, **Shop and Locker always visible**, one More button,
  compact menus and results, chat left alone in its familiar corner.

Live status and next steps are in [DEVELOPMENT_PROGRESS.md](DEVELOPMENT_PROGRESS.md), the visual identity is
in [docs/ART_DIRECTION.md](docs/ART_DIRECTION.md) and the honest launch assessment is
[docs/LAUNCH_READINESS.md](docs/LAUNCH_READINESS.md).

**Version 0.6.0 is a cosmetics and Shop overhaul** (details in [docs/COSMETICS.md](docs/COSMETICS.md)):

- **Skins are full costumes** fitted to your own avatar (Shadow Runner, Mall Phantom, Street Legend, Royal Trickster,
  Galaxy Escape Artist, Dragon Racer and more), in four rarity tiers; **12 masks**; **10 trails** built from real
  `Trail` and `ParticleEmitter` objects (speed streaks, electric sparks, cosmic stardust, shadow smoke, golden
  footprints); **7 emotes** that actually perform (procedural poses, no uploaded animations).
- **The Shop is a showroom**: a large auto-framed 3D preview of *your* avatar for every category, a trail test run on a
  looping track, emotes that play the moment you click them, drag/arrow/front/back rotation, replay, full-screen
  inspect, and clear owned / equipped / locked / affordable / coming-soon states.
- **Matching collections** (outfit + mask + trail + emote), all cosmetic only, all unconfigured Robux items until you
  enter real pass IDs.

**Nothing in this version has been run in Roblox Studio.** Every check below uses deterministic mocks of the
Roblox boundary. Lighting, feel, rendering, audio, phones, real DataStores and real Robux remain unverified; the
images below are **software geometry previews**, not screenshots. See the launch report and
[the Studio acceptance scripts](docs/TESTING.md#060-cosmetics-acceptance-script-start-here), including the list of checks that
need two or more real players.

![Spawn hub and sunburst entrance. Software preview, not a Studio screenshot](docs/previews/hub-spawn.png)
![Atrium. Software preview, not a Studio screenshot](docs/previews/atrium-ground.png)
![Toy Kingdom interior. Software preview, not a Studio screenshot](docs/previews/store-toys.png)
![Skins. Software preview on a stand-in avatar, not a Studio screenshot](docs/previews/Character-lineup.png)
![Trails drawn behind a running stand-in avatar. Software preview, not a Studio screenshot](docs/previews/Trail-previews.png)
![Emote key frames. Software preview, not a Studio screenshot](docs/previews/Emote-frames.png)

## Open the game directly — no plugins required

1. Download **[dist/Catch-Me-If-You-Can-Final.rbxl](dist/Catch-Me-If-You-Can-Final.rbxl)**. On GitHub,
   open the file and use **Download raw file**. The XML alternative is
   **[dist/Catch-Me-If-You-Can-Final.rbxlx](dist/Catch-Me-If-You-Can-Final.rbxlx)**; both contain the same
   game. Download one, not the GitHub HTML page.
2. In Roblox Studio, choose **File → Open from File** and select the downloaded
   place. Catch Mall is already present in the editor; it is not an empty place
   that requires pasting scripts. The map is reused at runtime.
3. Press **Play**. Output should say `CATCH MALL initialized. 0.7.0`; if it
   shows an older version, download and open the updated file. A solo Studio
   session enters a clearly labeled practice round
   after the 16-second intermission and 5-second head start. Practice awards no
   XP, coins, rank, or wins. The avatar and game interface appear during Play.
4. For competitive testing, use Studio's **Server & Clients / Local Server** test
   controls with at least **2 clients**. For the full lobby use **12 clients**.
5. Before publishing, use an R15 avatar configuration and set the experience's
   maximum server size to **12**. The generated place sets R15; confirm published
   experience settings retain it. Follow [the testing checklist](docs/TESTING.md).

The `Final` filename identifies this requested delivery, not launch certification.
The older `dist/CatchMeIfYouCan.rbxl` / `.rbxlx` paths are rebuilt as byte-identical
compatibility copies; use the **Final** links above to avoid an older local download.

You can edit modules directly in Studio. For source-controlled work, edit `src/`
and rebuild; direct edits to a generated place are not automatically copied back
into the source tree.

## What is connected

- **Chase rounds:** up to 12 players, 1 hunter for 2–6 players and 2 for 7–12;
  180-second active rounds; 16-second intermissions; 5-second runner head starts;
  10-second results; round modifiers (Classic, Infection, Swarm, Slide Frenzy); fair
  hunter rotation, late-join spectating, death/reset and disconnect handling.
- **Catch Mall:** 324 × 304 studs, two floors plus a back-of-house service ring, a
  fountain atrium with a glass roof, 8 escalators, 4 grand stairs, 2 skybridges, balconies
  with 8 drop gaps, ladders, a food court, restrooms, an arcade, a cinema and 24 distinct,
  furnished stores whose interiors connect so chases loop through them. About 6,700 parts.
- **Hiding and searching:** 130 hide spots (fitting rooms, stalls, lockers, booths, vents, a toy chest, a
  shoe box, a dog house and more). Hold E to hide for at most 7 seconds (12 s cooldown). Hidden runners
  cannot be tagged, but hunters can search a spot (E) to flush the occupant out, and SCAN (Q, 25 s cooldown)
  shows movement and anonymous "occupied" markers within 45 studs.
- **Coins and close calls:** 55 spinning coins; each runner can pick up 25 per round
  (+1 coin, +3 XP each); close calls with hunters pay XP; hunters earn XP for finds. Practice rounds
  collect *practice coins* that are clearly labelled as not saved.
- **Characters and cosmetics:** your own avatar, plus 13 optional skins in four rarity tiers (Epic and Legendary
  have ambient auras; Golden Champion turns you gold), 8 masks, 5 trails, 4 tag effects, emotes, nameplates and
  collection counters. Equipping mid-round applies after the round. Nothing changes speed or any rule.
- **Spawn hub:** compact plaza with the winners' podium, two live leaderboards (wins and tags in this server),
  Shop and Locker kiosks, and a status board over the mall entrance.
- **Interface:** a timer chip, wallet pill, one-line objective, and a dock on the right where **Shop and Locker are
  always visible** (lobby, rounds, spectating, results) beside a More button for quests, career, crew and
  settings. Shop and Locker open a mid-size panel (a narrow drawer during a round), everything else a small card.
  Results are a compact card. Menus never pause the round or protect the player.
- **Progression and economy:** XP/levels, coins, ratings, wins/streaks, daily missions, a
  7-day login streak, 20 achievements and milestone cosmetics. Coins buy cosmetics only.
- **Persistence and shop:** server-owned inventory, DataStore retries with session leases,
  truthful save status, verified permanent game-pass entitlements, and developer-product
  coin packs through an idempotent `ProcessReceipt`. All IDs are 0 until you create them.
- **Feedback:** transient visual effects, camera lean, reduced-motion option, engine-bundled
  SFX fallbacks for coins, hiding, scanning, close calls and finds. Optional music, ambience
  and SFX overrides go in `Config.Audio`; no asset IDs are invented.

The leaderboard ranks players in the **current server** using their persistent
statistics. There is no global cross-server leaderboard or ranked matchmaking.
Rank is a transparent win/loss rating (+24 / −14), not a matchmaking skill estimate.

## Controls

| Action | PC | Controller | Touch |
| --- | --- | --- | --- |
| Move / look | WASD / mouse | Left / right stick | Roblox joystick / drag |
| Sprint | Hold Shift | Toggle L3 | Toggle RUN |
| Slide | C while moving | B while moving | SLIDE |
| Jump / attempt vault | Space | A | Native jump button |
| Tag as hunter | F | R2 | TAG |
| Hide / search / leave a spot | Hold E (jump to step out) | Hold the prompt button | Tap the prompt |
| Hunter scan | Q | X | SCAN |
| Shop / Locker | On-screen buttons or the hub kiosks | Y opens the Locker | On-screen buttons |
| Close menu / More | Close button / Escape | B | Close button |
| Spectate | On-screen arrows | Select arrows with UI navigation | On-screen arrows |

A vault request keeps normal jumping available when no suitable obstacle exists.
Movement ability cooldowns appear only after server acknowledgment. Opening menus
releases sprint; an open collection does not opt a player out of automatic rounds.

## Build and check the source

Linux x86_64 (Python 3, curl, unzip, and Git required):

```bash
./tools/bootstrap.sh       # Pinned official tools; SHA-256 verified
./tools/check.sh           # Compile, rebuild, deserialize, and run all nine suites
./tools/build.sh           # Rebuild just the two deliverable place files
```

Pinned versions: **Rojo 7.7.1**, **Luau 0.742**, **Lune 0.11.0**. Linux tools live
in ignored `.tooling/bin`. `aftman.toml` pins Rojo and Lune for other platforms;
install the corresponding official Luau CLI release separately. With those tools
and Python on PATH, Windows/macOS can run:

```text
python tools/check.py
```

For only a place build on any supported platform:

```text
rojo build default.project.json -o dist/CatchMeIfYouCan.sources.rbxlx
lune run tools/bake-place.luau dist/CatchMeIfYouCan.sources.rbxlx
```

Rojo creates the script/service hierarchy. Lune executes the authored map builder
with Roblox data types, bakes its geometry/lighting/spawns, and serializes **both**
place formats. The build then reopens both files and verifies their content. Lune
does not simulate the Roblox engine. A plain `rojo build` still runs the map builder
at Play time, but the two-step build is required for the city to be visible in Edit.

For live source editing, `rojo serve default.project.json` can sync scripts through
the Rojo Studio plugin. After map source changes, rebuild/reopen the place, or
remove the generated `Workspace.CatchMall` model before the next Play session so
`MapBuilder` regenerates it. Existing baked map geometry is deliberately reused (`MAP_VERSION`).

## Configuration and release checks

- [`Config.lua`](src/shared/Config.lua): round/movement tuning, data store, audio.
  Studio defaults to **temporary session-only data** and says so in the interface.
- [`Catalog.lua`](src/shared/Catalog.lua): cosmetics, coin prices, milestones, and
  real pass IDs. All Robux IDs are **0**, which disables paid purchase prompts.
- [Monetization guide](docs/MONETIZATION.md): create passes, set prices/IDs, publish,
  and test server-verified ownership. No real Robux transactions were tested here.
- [Testing checklist](docs/TESTING.md): required Studio, device, network, persistence,
  and performance checks before launch.
- [Progress and continuation](PROGRESS.md): verified results and remaining work.

**Performance design.** The mall is only 324 x 304 studs and the lobby sits about 90 studs outside it,
so any streaming radius that keeps chases and spectating correct would still load nearly the whole
map; `StreamingEnabled` is therefore left off, and weaker devices save work on the client instead
(`PerformanceController`): about 1,500 small decoration parts and the 51 lights are hidden beyond a
radius on MEDIUM/LOW, ambient particles are halved or stopped, sun rays/bloom/shadows are trimmed on
LOW, and the quality steps down automatically after sustained low FPS. Phones start on MEDIUM; the
player can pick AUTO/HIGH/MEDIUM/LOW in Settings > GRAPHICS. Budgets (enforced by tests): at most
6,600 parts, 600 transparent parts, 70 lights, 24 emitters, 150 signs, 130 parts per avatar.
These are budgets, **not measured frame rates**: measure on a real low-end phone before launch.

## Source layout

```text
src/shared/                   Configuration, catalog, pure rules, cosmetic overlays (Appearance.lua)
src/server/Main.server.lua    Remotes, rate limits, service wiring
src/server/Services/          Rounds, movement, hiding, data, purchases, cosmetics, hub boards and kiosks
src/server/World/MallBuilder.lua Catch Mall (src/server/World/Mall/*: Kit palette, Style themes, Decor, Exterior hub), legacy MapBuilder.lua kept
src/client/Main.client.lua    Snapshot/event synchronization and controllers
src/client/Controllers/       UI, inputs/camera/poses, hiding, sound and visual feedback
tests/                        Rules, services, client, appearance, mall, enum regressions
tools/                        Verified tool bootstrap, build, and validation
dist/                         Direct-open Studio place files
```

Optional inspection tools (Pillow and NumPy, never game dependencies; none are Roblox renders):
`tools/export-map.luau` + `tools/render-view.py` (eye-level perspective previews) and `tools/render-map.py` (plans),
`tools/export-characters.luau` + `tools/render-characters.py` (skin and mask lineups) and
`tools/export-ui.luau` + `tools/render-ui.py` (HUD layouts at any screen size, with the chat region marked).

All map and costume geometry is original project code. No free-model scripts,
external meshes, third-party asset packages, or paid movement advantages are used.
