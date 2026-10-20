# Performance budget (baked map, measured from the place file)

Counts are real; **frame rate is not measured** (no engine here). Phones are the target to profile first.

```
folder          parts  collide  shadow  transparent  neon lights
MallShell         201       14     120           79     9      0
Floors            116       29      86           24    30      0
Atrium            174       41      81           52    43      8
Stores           2593      181     875          420   624      9
FoodCourt         314       36     127           22    65      2
Arcade            248       40      63           81   127      2
ParkourRoutes     124       51      88           24    26      0
Decor             366       74     240           12    28      0
PlazaHub         1065      119     270          158   345     12
DistantSkyline    106        0       0            0    69      0
TOTAL            5307      585    1950          872  1366     33   (+107 SurfaceGuis)
```

Notes
- All map parts are anchored. Small decorative parts do not cast shadows (`art()` rule); the distant skyline casts none.
- 33 point lights, none with shadows. Two particle emitters (fountains, rate <= 26).
- 107 SurfaceGuis (signs); each has a 260-stud `MaxDistance`.
- Streaming is off by design (whole mall visible to spectators). If phones struggle, the first levers are:
  (1) enable StreamingEnabled with the mall in one model group, (2) lower `Stores` prop counts, (3) set
  `Lighting.GlobalShadows=false` on low graphics, (4) reduce neon strips in `shelf()`.
- Avatar budget unchanged: at most 87 parts per avatar including Hunter accessories.
- Test gate: `tests/map.spec.luau` fails above 7,600 parts or 64 lights.
