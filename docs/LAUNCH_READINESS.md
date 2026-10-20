# Launch readiness — version 0.3.0

**Verdict: NOT ready to publish.** The code passes every automated check, but nothing has been run in
Roblox Studio, on a phone, with real players, with a real DataStore, or with real Robux. Do not treat the
green checks as a playtest.

## What is verified (automated, mocked Roblox boundaries)
`./tools/check.sh`: compile (17 scripts), deterministic rebuild, both place files deserialize, and six suites:
rules 308, data/shop 150, gameplay 240, appearance 157,251, client 494, map 28,292.

## What is NOT verified (needs a human in Studio / published test place)
| Area | Why it matters | How to verify |
| --- | --- | --- |
| Brighter city (0.3.0) | Palette/lighting changed blind; may be washed out, neon may lose punch | Open place, Play, adjust `applyLighting()` and palette `P` in `MapBuilder.lua` |
| Slide + roof flicker (0.2.1 fixes) | User's last report was both broken in 0.2.0 | `docs/UPDATE_0_2.md` acceptance list |
| Infection / Swarm / Frenzy | Balance and feel are guesses (4s hold, 6s cutoff, 120s Swarm) | Test Server + 4/6/12 clients; tune `Modifiers.lua` |
| Infected respawn | Hold uses Anchored root; check no camera/anim glitch | Same test; watch the infected player |
| Onboarding / login card / achievements UI | Built against mocks; layout on real phones unseen | Phone emulator + real device; check text clipping |
| Multiplayer, late join, disconnects | Only mocked | `docs/TESTING.md` 2/7/12-client plans |
| Mobile performance | Only static part budgets (1,646 parts) | Measure FPS/memory on a low-end phone |
| DataStore saving, login streak across days | Studio is session-only by default | Private published test place with separate store; test rejoin, and a claim on consecutive UTC days |
| Purchases | All pass IDs are 0 (prompts disabled) | `docs/MONETIZATION.md` |

## Required Creator Dashboard / owner actions
1. Create the 9 game passes listed in `docs/MONETIZATION.md`, set prices, copy IDs into `src/shared/Catalog.lua`
   (`gamePassId`), rebuild with `./tools/build.sh`. Never use made-up IDs.
2. Set experience max players to **12**, avatar type **R15**.
3. Provide **licensed** audio asset IDs if you want music/custom SFX (`Config.Audio`; 0 = engine fallback/silent).
   I did not and cannot invent or buy assets.
4. Enable API services/Studio DataStore access only for testing in a separate test store.
5. Publish only after the manual gate passes. This work did not publish anything.

## Known gaps vs. the original brief (not done, by choice or limit)
- **No new map interactives** (jump pads, limited-use shortcuts): feel can't be judged without Studio; risk of
  breaking anti-cheat movement validation. Existing: timing gates, 12 routes, 6 ladders, vault routes.
- **No global leaderboard** (server-only roster) — needs OrderedDataStore + published place to verify.
- **No new shop items / animations / music** — need assets or Studio previews.
- Cosmetic shop unchanged apart from 5 milestone titles.
- Round modifiers are server-chosen only; no player voting.

## Security notes (reviewed in code, not penetration-tested)
New `ClaimLogin` action goes through the same envelope: rate limit (2 burst, 0.2/s), payload validation, profile-ready
check; server decides streak/amount/eligibility from UTC day. Achievement/login rewards are coins/XP only.
`tutorialDone` is the only new client-writable setting (boolean, whitelisted). Modifiers are not client-selectable.
Infected-player survival XP is computed server-side from timestamps.
