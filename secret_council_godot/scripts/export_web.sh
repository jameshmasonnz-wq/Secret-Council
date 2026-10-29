#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-godot}"
OUT_DIR="${WEB_OUT_DIR:-$ROOT/build/web}"
OUT_FILE="$OUT_DIR/index.html"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
  echo "ERROR: Godot executable '$GODOT_BIN' was not found." >&2
  echo "Install Godot 4.7 and export templates, or set GODOT_BIN=/path/to/godot." >&2
  exit 127
fi

mkdir -p "$OUT_DIR"
"$GODOT_BIN" --headless --path "$ROOT" --editor --quit
"$GODOT_BIN" --headless --path "$ROOT" --export-release "Web" "$OUT_FILE"

for required in index.html index.js index.wasm index.pck; do
  if [[ ! -f "$OUT_DIR/$required" ]]; then
    echo "ERROR: Expected export file missing: $OUT_DIR/$required" >&2
    echo "Check the Web preset and installed export templates; Godot versions may name files differently." >&2
    exit 2
  fi
done

echo "Web export created at: $OUT_DIR"
echo "Publish the ENTIRE directory, not just index.html."
