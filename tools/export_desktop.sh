#!/usr/bin/env bash
# Build the pinned Godot release for desktop, including native Steam libraries.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
godot_binary="${GODOT_BIN:-godot}"
if ! command -v "$godot_binary" >/dev/null 2>&1 && [[ -x /Users/benthomas/Downloads/Godot.app/Contents/MacOS/Godot ]]; then
  godot_binary=/Users/benthomas/Downloads/Godot.app/Contents/MacOS/Godot
fi
if [[ "$("$godot_binary" --version)" != 4.7.2.stable.* ]]; then
  printf '%s\n' 'Exports require pinned Godot 4.7.2 stable. Set GODOT_BIN to that executable.' >&2
  exit 1
fi
platform="${1:-all}"
case "$platform" in all|windows|linux|macos) ;; *) printf '%s\n' 'Usage: tools/export_desktop.sh [all|windows|linux|macos]' >&2; exit 2 ;; esac
mkdir -p "$project_dir/build/windows" "$project_dir/build/linux" "$project_dir/build/macos"
touch "$project_dir/build/.gdignore"
copy_notices() {
  local destination="$1"
  mkdir -p "$destination/licenses"
  cp "$project_dir/licenses/GODOT_LICENSE.txt" "$destination/licenses/GODOT_LICENSE.txt"
  cp "$project_dir/addons/godotsteam/license.md" "$destination/licenses/GODOTSTEAM_LICENSE.md"
  cp "$project_dir/addons/godotsteam/PINNED_BUILD.json" "$destination/licenses/GODOTSTEAM_BUILD.json"
  cp "$project_dir/docs/STEAM_SETUP.md" "$destination/STEAM_SETUP.md"
}
"$godot_binary" --headless --path "$project_dir" --editor --import --quit
if [[ "$platform" == all || "$platform" == windows ]]; then
  "$godot_binary" --headless --path "$project_dir" --export-release 'Windows Desktop' "$project_dir/build/windows/RogueDice.exe"
  copy_notices "$project_dir/build/windows"
fi
if [[ "$platform" == all || "$platform" == linux ]]; then
  "$godot_binary" --headless --path "$project_dir" --export-release 'Linux Desktop' "$project_dir/build/linux/RogueDice.x86_64"
  copy_notices "$project_dir/build/linux"
fi
if [[ "$platform" == all || "$platform" == macos ]]; then
  "$godot_binary" --headless --path "$project_dir" --export-release 'macOS' "$project_dir/build/macos/RogueDice.zip"
  copy_notices "$project_dir/build/macos"
  python3 - "$project_dir" <<'PY'
import sys
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
root = Path(sys.argv[1])
with ZipFile(root / "build/macos/RogueDice.zip", "a", compression=ZIP_DEFLATED) as archive:
    app = next(name.split("/")[0] for name in archive.namelist() if ".app/" in name)
    for source in sorted((root / "build/macos/licenses").iterdir()):
        archive.write(source, f"{app}/Contents/Resources/licenses/{source.name}")
PY
fi
printf '%s\n' "Desktop export complete: $project_dir/build"
