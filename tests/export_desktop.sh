#!/usr/bin/env bash
# Run after the game project passes its tests. Godot 4.6.3 export templates
# must be installed under XDG_DATA_HOME/godot/export_templates/4.6.3.stable.
set -euo pipefail
PROJECT="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$(dirname "$PROJECT")"
TOOLCHAIN="${GODOT_TOOLCHAIN_ROOT:-$WORKSPACE/.godot-toolchain}"
export XDG_DATA_HOME="${GODOT_DATA_HOME:-$TOOLCHAIN/data}"
export XDG_CONFIG_HOME="${GODOT_CONFIG_HOME:-$TOOLCHAIN/config}"
export XDG_CACHE_HOME="${GODOT_CACHE_HOME:-$TOOLCHAIN/cache}"
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" \
  "$PROJECT/build/windows" "$PROJECT/build/linux"
GODOT="${GODOT:-godot}"
"$GODOT" --headless --path "$PROJECT" --editor --import --quit
"$GODOT" --headless --path "$PROJECT" --export-release "Windows Desktop" \
  "$PROJECT/build/windows/OneKeyGravity.exe"
"$GODOT" --headless --path "$PROJECT" --export-release "Linux" \
  "$PROJECT/build/linux/OneKeyGravity.x86_64"
chmod +x "$PROJECT/build/linux/OneKeyGravity.x86_64"
"$PROJECT/build/linux/OneKeyGravity.x86_64" --headless --quit-after 5
