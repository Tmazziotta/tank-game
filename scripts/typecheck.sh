#!/usr/bin/env bash
# Strict type-check all game code with luau-lsp against Roblox API definitions.
# Usage: scripts/typecheck.sh            (set REFRESH_TYPES=1 to re-download definitions)
set -euo pipefail

cd "$(dirname "$0")/.."

CACHE_DIR=".luau-cache"
DEFS="$CACHE_DIR/globalTypes.d.luau"
DEFS_URL="https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.None.d.luau"

mkdir -p "$CACHE_DIR"
if [[ ! -s "$DEFS" || "${REFRESH_TYPES:-0}" == "1" ]]; then
	echo "Downloading Roblox type definitions..."
	curl -fsSL "$DEFS_URL" -o "$DEFS"
fi

rojo sourcemap default.project.json --output sourcemap.json

luau-lsp analyze \
	--definitions="$DEFS" \
	--sourcemap=sourcemap.json \
	--base-luaurc=.luaurc \
	--no-strict-dm-types \
	src
