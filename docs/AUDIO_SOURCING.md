# Audio: what exists and what still has to be sourced

Nothing licensed is bundled and **no asset IDs were invented**. Every sound below either uses a
file that ships inside the Roblox client (`rbxasset://sounds/...`, silently skipped if a client lacks it)
or is silent until you paste an ID you own or are licensed to use into `Config.Audio` (0 = off).

| Need | Today | To finish it |
| --- | --- | --- |
| Footsteps / surface variation | Roblox's default character sounds (built into every avatar); `Sprint` loop uses `action_footsteps_plastic.mp3` | Optional: licensed per-material footstep set (marble, wood, carpet, metal) |
| Jump / land | `action_jump_land.mp3` for `Land`, default jump sound | Optional upgrade |
| Slide | `swoosh.wav` | Licensed slide/scuff sound |
| Vault | `action_jump.mp3` | Licensed whoosh + hand slap |
| Tag | `electronicpingshort.wav` (pitched) | Licensed tag hit / "gotcha" stinger |
| Countdown / final chase | pings (pitched) | Licensed tick + siren stinger |
| Win / lose | pings (pitched) | Licensed fanfare / sad trombone-style stinger |
| UI click, reward | `button.wav`, ping | Licensed UI click set, coin/reward chime |
| Mall ambience | **silent** (`Config.Audio.MallAmbience`) | Licensed loop: crowd murmur + soft HVAC, ~60-90 s, seamless |
| Arcade ambience | **silent** (`ArcadeAmbience`) | Licensed loop: chiptune bleeps, coin drops |
| Food court ambience | **silent** (`FoodCourtAmbience`) | Licensed loop: cutlery, sizzle, chatter |
| Plaza ambience | **silent** (`PlazaAmbience`) | Licensed loop: fountain, birds/wind, light crowd |
| Escalator hum | **not implemented** | Licensed short loop; attach to the two escalators |
| Music | **silent** (`Music`) | Licensed upbeat soundtrack |

How it works: ambience beds are looped `Sound`s that fade in only in their zone (arcade / food court /
Plaza / rest of the mall) and respect the MUSIC toggle and the new MUSIC VOLUME setting. Effects respect
SOUND EFFECTS and EFFECTS VOLUME. Both volumes are saved in the player profile (tenths, 0-1).
Audio was **not heard** by anyone in this build; fallback files and levels need an ear in Studio.
