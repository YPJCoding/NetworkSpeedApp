#!/bin/zsh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT_DIR/.build/AppIcon.iconset"
OUTPUT="$ROOT_DIR/App/Resources/AppIcon.icns"
rm -rf "$ICONSET"
mkdir -p "$ICONSET" "$(dirname "$OUTPUT")"
for size in 16 32 128 256 512; do
    swift "$ROOT_DIR/scripts/generate-icon.swift" "$size" "$ICONSET/icon_${size}x${size}.png"
    swift "$ROOT_DIR/scripts/generate-icon.swift" "$((size * 2))" "$ICONSET/icon_${size}x${size}@2x.png"
done
iconutil -c icns "$ICONSET" -o "$OUTPUT"
echo "$OUTPUT"
