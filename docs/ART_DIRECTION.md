# Art direction: "Sunburst Mall"

The goal is a cheerful, colorful, readable Roblox game that feels social and fun at a glance: bold shapes, saturated
but mid-tone colors, chunky props, inviting light. It is **not** futuristic, neon, or a tech demo. Everything is
original project geometry; no assets or layouts are copied from other games.

## Brand
- **Name and mark:** Catch Mall, a yellow **sunburst** (disc plus rays) over a coral-and-teal entrance gate.
- **Colors** (`Mall/Kit.lua` `Kit.P`): coral `#FF5E54`, sun yellow `#FFC41E`, teal `#00AFB4`, sky `#3296FF`, violet,
  pink, mint, orange; warm neutrals (cream, sand, honey, terracotta) for big surfaces; ink navy `#282C4E` for signs.
- **Type:** Fredoka One for signs and big UI numbers, Gotham for small labels.
- **Rule of thumb:** large surfaces (floors, walls) stay mid-tone. Pure white is only for small accents. If a surface
  fills the screen and is lighter than a warm cream, it is probably too bright.

## Materials and glow
- Floors use `Slate` (warm paver sand, honey upper deck) with a terracotta checker; store floors use `WoodPlanks`,
  `Fabric` or `Slate` per theme. Walls are painted `SmoothPlastic`. Awnings are `Fabric`.
- **Neon policy:** `Kit.part` converts any `Neon` request to plain plastic unless the part name is in `Kit.GlowNames`
  (coins, bulbs, TV and arcade screens, status board, a few marquee pieces). Do not add names to that list casually.
  Cosmetics never use Neon (tested).
- **Lighting** (`applyLighting()` in `MallBuilder.lua`, `Technology = ShadowMap` set by the bake): warm afternoon sun,
  mid ambient, almost no haze, bloom threshold high enough that only real glow blooms.

## Stores
Each store has a theme in `Mall/Style.lua`: wall, floor color and material, trim, a two-color awning and an emoji icon.
`StoreShell.lua` turns that into a striped awning over the windows, a projecting **blade sign** with the icon (readable
from along the corridor), pendant lamps, baseboard, cornice and a painted band. Interiors keep their own props
(runway, teddy bear, giant sneaker, TV wall, aquarium, boxing ring...). To add a store: add a definition in
`StoresA/B/Zones.lua`, add its name to `Style.lua`, and run `tests/mall.spec.luau` (it checks doors, clearances,
hiding spots and navigation).

## Characters
- **Players keep their own Roblox avatar** (face, head, proportions, animations). `LoadCharacterAppearance` is on.
- A **skin** is an optional *costume* of chunky welded parts built in `Appearance.lua`: body-conforming shells for the
  torso, arms, legs and shoes (slightly larger than the avatar's own parts, so every body shape still fits) plus
  hats, hoods, capes, wings, scarves and tails. Silhouette and story come from the props; color blocking and trim
  come from the shells. Rarity: Common (cheap, simple), Rare, Epic (more pieces, an aura), Legendary (showpieces).
- While a costume is worn the player's own hair, hats and layered clothing are tucked away (restored exactly), so
  nothing clips. Golden Champion also tints the limbs and stashes classic clothing (restored).
- **Masks** sit in front of the real face; pieces that sit on top of the head are left off under headwear.
- **Trails, emotes and previews:** see [COSMETICS.md](COSMETICS.md).
- **Hunters** get a bold red sash, cuffs and an outline.
- **Previews** are the player's own avatar (from `HumanoidDescription`) wearing the same overlay code path as the live
  character; a neutral mannequin is only a fallback.
- Cosmetics are fair: no speed, hitbox, tag, hide, XP or coin effect, enforced by tests.

## Interface
- Compact top chips (timer, wallet), one-line objective, ability bar at the bottom center.
- **Shop and Locker** are the two big dock buttons, always visible, on the **right**; **More** holds the rest.
- Shop and Locker: roomy panel (narrow drawer in a round). Everything else: a small card.
- **Chat is left alone** (default top-left, only narrowed). The HUD keeps the left edge free.
- Colors: ink-navy panels, coral Shop, blue Locker, amber More; rarity colors Common grey-blue, Rare blue, Epic purple,
  Legendary gold.

## Hub
A compact plaza facing the sunburst entrance, built in `Mall/Exterior.lua` with `Mall/Decor.lua` pieces: chevron path
from the spawn pad to the winners' podium, two leaderboards, Shop and Locker kiosks, palms, benches, lamp posts,
bunting and a balloon arch. `HubService` fills the leaderboards and the status board and opens menus from the kiosks.

## Previews
`docs/previews/` holds **software geometry previews** (flat colors; not Studio screenshots). Regenerate with
`tools/export-map.luau` + `tools/render-view.py`, `tools/export-characters.luau` + `tools/render-characters.py`, and
`tools/export-ui.luau` + `tools/render-ui.py`.
