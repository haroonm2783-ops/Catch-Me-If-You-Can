# Neon Heights 0.2 — visual and movement update

This update continues the existing game. The round rules, progression, saved
inventory, purchase architecture, and chase layout are preserved.

The player reported that the previous place runs in Studio and that running,
sprinting, and vaulting work. They also reported that pressing C does not slide
and that the default avatar and city need a substantial visual improvement.
That is user-reported evidence about the previous place, not a Studio test of
this update by Codex.

## Install the updated place

1. Stop the current Studio play session. Save any Studio-only edits separately;
   opening this place does not merge those edits into the source project.
2. Download the updated `dist/Catch-Me-If-You-Can-Final.rbxl` (or `.rbxlx`) from GitHub using
   **Download raw file**.
3. Choose **File → Open from File** and open that downloaded file. The city is
   already baked into it. No plugins, paid meshes, clothing uploads, or animation
   uploads are needed for the included procedural presentation.
4. Press **Play**. Studio Output should include
   `[Catch] Neon Heights initialized. 0.2.0`. Workspace also has a
   `CatchGameVersion` attribute. This distinguishes it from an older download.
5. Use two local clients for Hunter/Runner testing. Solo Studio practice makes
   the player a Runner and awards no competitive progression.

With Rojo, rebuild and reopen the place after a map update. Syncing Lua modules
alone does not replace a map already running in a Play session.

## First acceptance pass in Studio

Record pass/fail and any Output error for each item. This is intentionally
separate from the automated test results in `PROGRESS.md`.

| Check | Expected result |
| --- | --- |
| Default outfit | A complete streetwear outfit, shoes, and accessories appear on first spawn and reset, without an exposed yellow noob torso/limbs. |
| Existing equipment | Previously owned and selected skins/masks remain selected; mask selection is independent of skin. |
| Hunter identity | A Hunter is visually identifiable while retaining their selected cosmetics; the role treatment clears in the lobby. |
| Walk + C | While walking on a flat roof, C produces a visible forward slide and pose. Holding sprint is optional. |
| Slide exit | Forward momentum eases out; walking, sprinting, jumping, vaulting, and tagging still work afterward. |
| Slide restrictions | Repeated presses cannot extend the slide or bypass its cooldown. Stationary, airborne, and frozen players cannot initiate it. |
| Slide collision | A wall stops the slide; stepping off a ledge does not allow floating; jumping releases the slide. |
| Lifecycle | Reset during and after a slide, change rounds, and repeat. No stale force, frozen avatar, or broken controls remain. |
| Device controls | C, controller B, and the touch SLIDE button work during play. B closes an open menu without sliding. |
| Two clients | Both clients see appropriate poses and correct round roles; repeat movement with 100–200 ms simulated latency. |
| City | Inspect new silhouettes, facades, rooftop details, skyline, and lobby from actual chase cameras. Every existing route and spawn stays usable. |
| Locker/UI | Skin/mask previews, rotation controls, item selection, purchases/equip, quests, and results remain readable at phone/tablet/desktop sizes. |

Use `docs/TESTING.md` for the complete multiplayer, persistence, purchases,
accessibility, and performance matrix. All paid IDs remain configurable and must
be supplied and tested by the experience owner. The update does not enable
untested real-money purchasing.

## Asset and verification boundaries

The outfits and city are original stylized geometry built with Roblox parts,
welds, materials, lighting, and UI. They are not uploaded sculpted meshes or
layered-clothing assets. Movement uses procedural poses as a fallback; the
project does not invent animation IDs. Optional music still requires an audio
asset that the experience may use.

The cloud tools compile Luau, exercise production logic with mocked engine
boundaries, instantiate and serialize Roblox geometry, and verify both place
formats. They do not run Roblox's Humanoid simulation, renderer, animation
replication, or device input. Geometric preview images are inspection aids,
not Studio screenshots or mobile performance evidence.
