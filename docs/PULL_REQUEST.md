# Draft pull request: Catch Mall 0.4.0 launch-quality overhaul

Branch: `claude/launch-quality-overhaul` -> `main`. Opened as [haroonm2783-ops/Catch-Me-If-You-Can#1](https://github.com/haroonm2783-ops/Catch-Me-If-You-Can/pull/1); this file holds the full description text.
**Do not merge or publish on test results alone: the Studio playtest in `docs/TESTING.md` is the launch gate.**

## Summary
Replaces the Neon Heights prototype with **Catch Mall**, a two-floor shopping mall chase game, and overhauls characters,
UI, hiding gameplay, monetization plumbing and performance. All gameplay rules stay server-authoritative.

- **Characters:** 8 outfits, 8 masks, expressive faces and moods, free skin-tone/hair pickers, deferred mid-round look changes.
- **Map:** 324 x 304 studs, 2 floors + service ring, atrium and fountain, 8 escalators, 4 grand stairs, 2 skybridges, drop gaps,
  24 furnished stores/attractions, 111 hide cells (>= 2 per store), 55 coins, ambient particles, ~6,700 parts.
- **Gameplay:** hide (E, <= 7 s), search (E), hunter scan (Q), coin pickups, close calls, finds, reward breakdown on the results screen.
- **UI:** bright redesign; **Shop and Locker always visible** in every phase and screen size; menus never pause or protect the player
  (side drawer during rounds); objective card, hide meter, ability bar, rarity cards with thumbnails, coin-pack tab.
- **Mobile:** touch buttons laid out around the jump button (portrait and landscape), correct TextChat alignment API on keyboard
  devices, phone topbar chat left alone, default player list hidden on keyboard devices.
- **Performance:** part trims, `PerformanceController` (distance LOD, light culling, particle scaling, effect trimming,
  automatic step-down on sustained low FPS, Settings > GRAPHICS). `StreamingEnabled` intentionally left off (rationale in
  `docs/LAUNCH_READINESS.md`).
- **Monetization:** gamepasses (IDs 0) plus coin-pack developer products with an idempotent, save-before-grant `ProcessReceipt`.
- **Docs and tooling:** README, LAUNCH_READINESS (honest ratings), TESTING (Studio acceptance script), MONETIZATION, progress
  tracker, geometry previews; new mall-navigation, enum-validity and end-to-end suites.

## Test plan
Automated (all pass locally with `./tools/check.sh`, mocked Roblox boundaries only):
- [x] compile of all 32 production scripts and deterministic rebuild of both place formats
- [x] rules 398, data/shop/receipts 172, gameplay + end-to-end 287, appearance 283,138, client UI 1,393
- [x] legacy map 28,291, **mall 118,049** (navigation, doors, hide cells, budgets), enum validity 867 references

**Manual, required before launch (not done):**
- [ ] Studio look-through of lighting/palette; tune `applyLighting()`
- [ ] 2- and 7-client playtests: hide/search/scan fairness, rewards, spectating, disconnects
- [ ] Low-end phone: FPS, memory, join time, graphics tier behavior, touch buttons, chat overlap
- [ ] Mood poses (arm/neck rotation signs) on real R15 avatars
- [ ] Published private test place: DataStore save/rejoin, game pass and coin-pack purchases (IDs are all 0 until created)
- [ ] Optional licensed audio IDs in `Config.Audio`

## Risks
Mobile performance (never measured), visual quality (never seen in engine), balance numbers in `Config.Hide`, analytic (not
physics) stuck-spot checks, no uploaded animations or music. See `docs/LAUNCH_READINESS.md`; overall readiness rated **5/10**
until the manual checklist passes.
