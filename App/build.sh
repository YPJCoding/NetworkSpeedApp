#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/Network Speed.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ARM_BUILD="$ROOT_DIR/.build/release-arm64"
INTEL_BUILD="$ROOT_DIR/.build/release-x86_64"

cd "$ROOT_DIR"
if [[ ! -f "$ROOT_DIR/App/Resources/AppIcon.icns" ]]; then
    "$ROOT_DIR/scripts/make-icon.sh"
fi

swift build -c release --arch arm64 --scratch-path "$ARM_BUILD"
swift build -c release --arch x86_64 --scratch-path "$INTEL_BUILD"
ARM_BIN="$(swift build -c release --arch arm64 --scratch-path "$ARM_BUILD" --show-bin-path)/NetworkSpeedApp"
INTEL_BIN="$(swift build -c release --arch x86_64 --scratch-path "$INTEL_BUILD" --show-bin-path)/NetworkSpeedApp"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
lipo -create "$ARM_BIN" "$INTEL_BIN" -output "$MACOS_DIR/NetworkSpeedApp"
chmod 755 "$MACOS_DIR/NetworkSpeedApp"
cp "$ROOT_DIR/App/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/App/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"

codesign --force --deep --sign "${APP_IDENTITY:--}" "$APP_DIR"
echo "$APP_DIR"
