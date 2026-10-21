# Launch checklist (version 0.7.0): what only a human in Studio can verify

Automated checks (`./tools/check.sh`) pass, but they use mocked Roblox boundaries. **None of the items below has been run
by the authors.** Do them in order; stop and report anything that fails. Budget: about 90 minutes plus one money test.

Open `dist/Catch-Me-If-You-Can-Final.rbxl` (XML twin: `.rbxlx`) in Roblox Studio.

## 1. Smoke test (5 min, Studio Play, 1 client)
- [ ] Output says `[Catch] CATCH MALL initialized. 0.7.0`; no red errors; no `Cosmetic ... has no implementation` warnings.
- [ ] Output shows no `[Catch] preview ...` warnings about detached accessories (they mean a preview fell back to a mannequin).
- [ ] You spawn in the hub; Shop and Locker buttons are on the right edge; chat does not overlap them.

## 2. Previews (the user's biggest complaint, so check carefully, 20 min)
- [ ] Shop > Skins: click all 14. Your own avatar wears each outfit; **hair/hats are not floating beside the model**;
      the whole model is in frame; Rotate/Front/Back/drag work; Golden Champion, Dragon Racer, Shadow Runner, Mall Phantom,
      Galaxy and Royal Trickster look special from front, side and back.
- [ ] Shop > Masks: all 12 visible and attached to the face.
- [ ] Shop > Trails: each of 10 trails shows a character running with a trail within ~2 s; REPLAY restarts it.
      Press **TEST RUN** (Trail Studio) for one trail: the real in-engine trail appears behind your running avatar, you
      cannot steer your character while in it, and leaving restores camera and controls (also by starting a round).
- [ ] Shop > Emotes: all 7 play immediately, loop, REPLAY restarts.
- [ ] Try one R6 avatar and one with large layered hair and a jacket.

## 3. Coins, saving and ownership (Studio uses a throwaway session unless Studio DataStores are enabled)
- [ ] Earn coins by playing, or temporarily raise `Rules.NewProfile` starting coins in a scratch copy (never commit that),
      then buy one coin item and one premium item with coins. Wallet drops once, item says OWNED, Equip/Unequip work, the
      equipped look appears on your avatar.
- [ ] Publish privately, play, buy something, leave, rejoin: ownership and equipment are still there.
- [ ] Join the same private server from a second account/client and from another phone to be sure the profile loads once.

## 4. Real Robux (only after you create passes/products as in MONETIZATION.md; private experience, test account)
- [ ] Items with an ID show BUY WITH ROBUX with the same price you set; items without one show only the coin button.
- [ ] Cancel a prompt: nothing granted, you can try again. Buy a pass: item appears within a few seconds; rejoin: still owned.
- [ ] Buy a coin pack: coins arrive once; rejoin: balance kept. Buying a collection you partly own grants only what is missing.

## 5. Chase gameplay with 2+ clients (Studio "Local Server", 2-3 players, then a published private server)
- [ ] Round starts, a hunter is chosen, hunters are held for the head start, runners can sprint, slide (C), vault.
- [ ] Hide in a spot (max 7 s, then cooldown), hunter can Search/Scan; tag range feels fair (5.8 studs); tagged runner goes to the lobby.
- [ ] Round ends with results and rewards that match the HUD; leaving mid-round does not break the round.
- [ ] Other players see your skin, trail, emote and footprints.
- [ ] Balance impression: hunters are slightly faster (27 vs 26 studs/s) and runners have slide/vault/hide/shortcuts. Note if one side wins
      almost always; tuning knobs are in `src/shared/Config.lua`.

## 6. Devices and performance
- [ ] Phone portrait and landscape: Shop and Locker open, scroll, buttons tappable, no cut-off text, trail studio and inspect usable.
- [ ] Low-end phone or Studio "Mobile" emulator on LOW graphics: no stutter in the mall, particles thin out at distance.
- [ ] 12 players on a published private server wearing heavy costumes: note frame rate and server heartbeat.

## 7. Before you flip the experience public
- [ ] Items 1 to 5 pass, Output is clean, saving verified across a rejoin, any Robux flows you enabled verified.
- [ ] Remove any test coins/ownership you granted yourself; if a Robux item misbehaves, set its ID back to `0` and republish.
