#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PWD/.tooling/bin:$PATH"
mkdir -p dist
rojo build default.project.json -o dist/CatchMeIfYouCan.sources.rbxlx
lune run tools/bake-place.luau dist/CatchMeIfYouCan.sources.rbxlx
rm dist/CatchMeIfYouCan.sources.rbxlx
