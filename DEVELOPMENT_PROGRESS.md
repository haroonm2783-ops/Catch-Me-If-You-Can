# DEVELOPMENT_PROGRESS.md — live tracker (read this first in every session)

Older delivery history (0.2.x, verification detail, launch checklist): `PROGRESS.md`.
This file is the running log for the takeover/polish effort. Update it at every milestone.

## Ground rules for this effort
- No Roblox Studio/engine exists in the cloud container. Verified = `./tools/check.sh` (compile, rebuild,
  6 mocked-boundary suites, place deserialization). Anything about feel, rendering, audio, devices, real
  DataStores and Robux is **UNVERIFIED until a human plays it in Studio**.
- Never publish, spend money, or invent product/asset IDs. All pass IDs stay 0.
- Never overwrite `dist/` by hand: always `./tools/build.sh` (check.sh does it).
- **Push status:** the Claude GitHub App is not installed for this repo, so `git push` from the cloud is
  refused. Commits are local to the session container; see "Exact next steps" for how to get them out.

## Phase 1 audit (done) — state of the inherited game
Solid: server-authoritative rounds/movement/tagging, rate-limited remotes with payload validation,
DataStore leases + retries, ownership-verified passes, 6 test suites, deterministic build.
Weak (ranked by player impact):
1. City read as dark/dim dusk with purple haze and very dark base palette (user's top complaint).
2. Single round type; a tagged runner spectates up to ~3 min = dead time and low replay variety.
3. No first-time onboarding/tutorial beyond a toast.
4. Only 6 achievements, no titles, no daily login reward; progression feels thin.
5. Music/most SFX are engine fallbacks (no licensed asset IDs available to me — cannot invent them).
6. No global leaderboard (server-only), no map interactives (jump pads, etc.), no animations uploaded.
7. Nothing has ever been playtested with 2+ real clients or on mobile.

## Completed
- [x] Takeover audit, baseline `./tools/check.sh` green (all suites).
- [x] **Bright city pass:** late-afternoon lighting (ClockTime 15.2, high ambient, warm sun, light haze,
      saturation up), lifted the dark base palette (roads, concrete, navy, steel, glass, greens, teal, coral).
      Geometry/collision untouched. MAP_VERSION 3→4 so old baked maps are replaced. Tests updated.
      UNVERIFIED visually — needs a Studio look; tune `applyLighting()` / palette `P` in MapBuilder.lua.

- [x] **Round modifiers** (`src/shared/Modifiers.lua`, RoundService): Classic / Infection (tagged runners become
      hunters after a 4s server-held respawn; no infection in last 6s; infected share hunter win and keep survival
      XP) / Swarm (+1 hunter, 120s) / Slide Frenzy (slide+vault cooldown x0.5). Weighted, never repeats back-to-back,
      size-gated (Infection>=4, Swarm>=6), practice always Classic. Previewed at intermission, shown in HUD + banner.
      +43 gameplay checks.
- [x] **Progression:** shared `Achievements.lua` (16, coin rewards, progress shown in Career), 5 new milestone title
      nameplates, 7-day UTC login streak (`ClaimLogin`, server-owned, rate-limited, coins/XP only), QUESTS "!" flag.
- [x] **Onboarding:** 5-page first-run overlay (platform-aware controls), persisted via `settings.tutorialDone`,
      replayable from Settings > HOW TO PLAY, auto-dismissed when a round starts.
- [x] Version bumped to 0.3.0.

## Current task
Docs/QA pass for what exists, then pick the next item from Remaining.

## Remaining (priority order)
1. Map interactives (jump pads / limited-use shortcuts) — needs Studio feel testing; design in docs first.
2. Global leaderboard via OrderedDataStore (needs published-place verification).
3. Shop: more cosmetics (trails/emotes) and a featured/new rail; no timers/FOMO tricks.
4. Audio: wire licensed IDs once the owner supplies them (Config.Audio).
5. Full QA pass + launch-readiness report (`docs/LAUNCH_READINESS.md`).

## Known bugs / risks
- None confirmed from the user's last Studio run besides the 0.2.1 slide/roof fixes awaiting acceptance.
- Mobile performance, slide feel, camera, and avatar fit all unmeasured.

## Test results (latest)
`./tools/check.sh`: rules 308, data/shop 150, gameplay 240, appearance 157,251, client 494, map 28,292 — PASS.
(Mocked Roblox boundaries only. Zero Studio/engine playtests have been run by this effort.)

## Implementation decisions
- Keep the existing architecture (Rojo + services + pure Rules). Extend, don't rebuild.
- Modifiers are server logic only (no new remotes needed beyond snapshot fields) to stay testable headless.
- Rewards stay cosmetic/currency only; no gameplay advantage is purchasable.

## Exact next steps
1. `cd` repo, `./tools/bootstrap.sh && ./tools/check.sh` to confirm baseline.
2. Continue with the first unchecked item in "Remaining".
3. After each item: run check, update this file, commit.
4. Pushing: install the Claude GitHub App for `haroonm2783-ops/Catch-Me-If-You-Can`
   (https://github.com/apps/claude/installations/select_target) or reconnect GitHub in claude.ai settings.
