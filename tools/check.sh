#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="$PWD/.tooling/bin:$PATH"
python3 tools/check.py
