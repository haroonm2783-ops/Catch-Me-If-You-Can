#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
  echo 'This bootstrap supports Linux x86_64. On other platforms install the versions in aftman.toml and Luau 0.742 from their official releases.' >&2
  exit 1
fi
mkdir -p .tooling/bin .tooling/downloads
fetch() {
  local name="$1" url="$2" digest="$3" archive=".tooling/downloads/$1.zip"
  if [[ ! -f "$archive" ]]; then curl --fail --location --show-error --silent --retry 2 "$url" -o "$archive"; fi
  if ! echo "$digest  $archive" | sha256sum --check --status; then
    echo "Checksum mismatch for $name; remove $archive and investigate before retrying." >&2
    exit 1
  fi
  unzip -oq "$archive" -d ".tooling/bin"
}
# SHA-256 digests published on the corresponding official GitHub release asset pages.
fetch rojo https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-linux-x86_64.zip 00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4
fetch luau https://github.com/luau-lang/luau/releases/download/0.742/luau-ubuntu.zip 152058b98c60ff1f5b5ec9bca0b8eb37793cae161dd3a05608cc3d8738ba1a4d
fetch lune https://github.com/lune-org/lune/releases/download/v0.11.0/lune-0.11.0-linux-x86_64.zip 5a0ea32c3e13e5e3b1dc415c2056bcfe44258b3a811dcd473c50e3b437d10f72
chmod +x .tooling/bin/rojo .tooling/bin/luau .tooling/bin/luau-compile .tooling/bin/luau-analyze .tooling/bin/lune
.tooling/bin/rojo --version
.tooling/bin/lune --version
