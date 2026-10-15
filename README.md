# Catch Me If You Can

A Roblox multiplayer parkour chase game set in the original Neon Heights city.

Implementation is being integrated. See [PROGRESS.md](PROGRESS.md) for the verified
checkpoint and exact remaining steps. The source is Rojo-compatible; dependency
versions are pinned in `aftman.toml` and `tools/bootstrap.sh`.

```bash
./tools/bootstrap.sh
.tooling/bin/luau tests/rules.spec.luau
.tooling/bin/rojo build default.project.json -o dist/CatchMeIfYouCan.rbxlx
```

The final deliverable will be `dist/CatchMeIfYouCan.rbxlx`, with a city baked into the
place for direct opening in Roblox Studio. Studio gameplay validation is required.
