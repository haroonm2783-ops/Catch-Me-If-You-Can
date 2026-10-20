# Launch readiness — version 0.4.0 (Catch Mall)

**Verdict: NOT ready to publish yet — but close enough that one focused Studio playtest session decides it.**
The code passes every automated check, but **nothing has been run in Roblox Studio**, on a phone, with real
players, with a real DataStore, or with real Robux. The green checks are not a playtest. Run the script in
[TESTING.md](TESTING.md#040-catch-mall-acceptance-script-start-here) first; fix what it finds; then launch.

## What changed in 0.4.0
Characters (8 outfits, 8 masks, faces, moods), a new two-floor Catch Mall map with 24 stores/attractions and
106 hiding cells, hide / search / scan / coin / close-call gameplay, a redesigned bright UI with Shop and
Locker always visible, procedural mood poses, a reward-breakdown results screen, developer-product coin packs,
and new tests (mall navigation, enum validity, hiding, UI visibility, receipts).

## What is verified (automated, mocked Roblox boundaries)
`./tools/check.sh` (eight suites + compile + deterministic rebuild + both place files deserialize):
rules 398 · data/shop/receipts 172 · gameplay 270 · appearance 283,138 · client UI 1,309 ·
Neon Heights legacy map 28,291 · **mall 125,020** · enum validity 856 references.

Specifically proven in those suites (mock/analytic, not engine):
- Every one of the 24 stores has ≥3 doors, clear doorways on both sides, furniture and coins; every hide cell
  fits an avatar and its exit is reachable; escalator bases/tops, drop-gap landings and spawns are clear.
- An analytic navigation model finds no way out of the footprint, onto the roof, or between the sealed lobby
  deck and the arena.
- Hiding rules: runner-only, ≤7 s, cooldowns, no tagging while hidden, hunter search ejects and reveals,
  scan lists visible runners and anonymous occupied cells, coin cap, close-call cap, reset on new round.
- Shop and Locker buttons exist, are visible and fit on screen in 6 screen sizes × 7 round phases; menus are
  not closed by a round starting; no gameplay attribute is touched by menus.
- Coin pack receipts: grant once per `PurchaseId`, only after a successful save, retry-safe, unknown/malformed
  receipts never granted, unconfigured packs never prompt.

## Honest ratings (out of 10)
Nothing here is 9/10 because nothing has been seen in the real engine.

| Area | Score | Why |
| --- | ---: | --- |
| Characters, skins, masks | 6 | Geometry and faces rendered with a software rasterizer only; poses/arm-bend signs unverified; fit on real R15 avatars unseen. |
| Mall layout and scale | 7 | Structure and navigation are the most rigorously checked part. Looks, lighting, collision snags unseen. |
| Stores and landmarks | 6 | 24 distinct, furnished, themed; whether they read as distinctive in-engine is unknown. Some are still plain. |
| Hiding / search / chase gameplay | 6 | Rules are tested; fairness and fun need real players. Balance numbers are guesses. |
| UI / UX | 6 | Layout contracts tested; actual look, text fit and touch ergonomics unseen. |
| Replayability / core loop | 6 | Coins, close calls, finds, rewards, modifiers, daily quests give reasons to replay; no long-term content calendar. |
| Animation, audio, atmosphere | 4 | Procedural poses and engine-bundled SFX only. No licensed music; no uploaded animations. Weakest area. |
| Progression and monetization | 7 | Fair, cosmetic-only; passes and coin packs implemented but all IDs are 0 and never settled for real. |
| Security / saves | 7 | Rate-limited, validated remotes; session-leased saves; idempotent receipts. Not penetration-tested; no real DataStore run. |
| Performance | 4 | ~7,200 parts, 51 lights, StreamingEnabled off. Never measured. Biggest launch risk on phones. |
| **Launch readiness overall** | **5** | Content-complete and well-tested on paper; zero engine playtests. |

## What is NOT verified (needs a human in Studio / published test place)
| Area | Why it matters | How to verify |
| --- | --- | --- |
| Visual quality of the mall | Colors, lighting and bloom were tuned blind | Studio look-through; tune `applyLighting()` and palette `P` |
| Mobile performance and memory | 7.2k parts, no streaming | Test on a low-end phone; consider StreamingEnabled + `ReplicationFocus` |
| Hide / search / scan feel and fairness | Numbers (7 s hide, 12 s cooldown, 45 stud scan) are guesses | Playtest with 2–7 players; tune `Config.Hide` |
| Procedural poses | Rotation signs for shoulders/neck/elbows are derived by hand | Check Win/Lose/Scared/Hunt poses; flip signs in `MOOD_POSES` |
| Stuck spots and exploits | Navigation test is analytic, not physics | Use the escape-route step in TESTING.md |
| UI at real resolutions | Only mock layout math | Phone emulator + real device |
| Multiplayer, late join, disconnects | Only mocked | 2/7/12-client plans in TESTING.md |
| DataStore saving, rejoin | Studio is session-only by default | Private published place with a separate store |
| Purchases and coin packs | All IDs are 0 | `docs/MONETIZATION.md` |
| Audio | Engine-bundled fallbacks only | Supply licensed IDs in `Config.Audio` and test |

## Required Creator Dashboard / owner actions
1. Create the 10 game passes and the 4 coin-pack developer products listed in `docs/MONETIZATION.md`, set prices,
   copy the IDs into `src/shared/Catalog.lua` (`gamePassId`, `Products[n].productId`), rebuild with
   `./tools/build.sh`. Never use made-up IDs.
2. Set experience max players to **12**, avatar type **R15**.
3. Provide **licensed** audio asset IDs if you want music/ambience/custom SFX (`Config.Audio`; 0 = engine
   fallback/silent). I did not and cannot invent or buy assets.
4. Enable API services / Studio DataStore access only for testing in a separate test store.
5. Publish only after the manual gate passes. This work did not publish anything.

## Known gaps vs. the original brief (honest list)
- **Hand-made animations and music are not included.** Mood poses are procedural; audio uses engine fallbacks.
- **No global leaderboard** (server-only roster) — needs OrderedDataStore + a published place to verify.
- **Store identity is geometry-only.** Stores are distinct by layout, color and props, not custom meshes or logos.
- **No streaming.** The whole mall replicates to every client; this is the first thing to measure on mobile.
- **Round modifiers** are server-chosen; no player voting.
- **Jump pads / limited-use shortcuts** are not built (movement validation risk without Studio).

## Security notes (reviewed in code, not penetration-tested)
New actions `Scan`, `Unhide` and `BuyCoins` use the same envelope as the rest: default-deny action table, token-bucket
rate limits, payload shape validation, profile-ready check. Hide/search are server `ProximityPrompt` events with a
server-side range check; the client only relabels prompts. Coins are credited from `ProcessReceipt` only, keyed by
`PurchaseId`, and never from a client request. Menus change no gameplay state. `tutorialDone` remains the only
client-writable setting (boolean whitelist). Modifiers are not client-selectable.
