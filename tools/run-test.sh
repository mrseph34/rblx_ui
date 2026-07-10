#!/usr/bin/env bash
# Headless test runner: builds the place with Rojo and runs a Luau script
# against it via run-in-roblox, streaming print/warn/error back to this
# terminal. Use this for automated smoke tests; use Argon for live-sync
# editing in Studio.
#
# Usage: tools/run-test.sh path/to/script.lua
set -euo pipefail

if [ -z "${1:-}" ]; then
    echo "Usage: tools/run-test.sh <script.lua>" >&2
    exit 1
fi

SCRIPT_PATH="$1"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLACE_PATH="$ROOT_DIR/tools/_test.rbxl"

export PATH="$PATH:$HOME/.rokit/bin"

cleanup() { rm -f "$PLACE_PATH"; }
trap cleanup EXIT

rojo build "$ROOT_DIR/default.project.json" -o "$PLACE_PATH"
run-in-roblox --place "$PLACE_PATH" --script "$SCRIPT_PATH"
