#!/bin/zsh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/Network Speed.app"
DIST_DIR="$ROOT_DIR/dist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$ROOT_DIR/App/Info.plist")"
PACKAGE_FORMAT="${PACKAGE_FORMAT:-all}"
ZIP_ARCHIVE="$DIST_DIR/Network-Speed-${VERSION}-macOS-universal.zip"
DMG_ARCHIVE="$DIST_DIR/Network-Speed-${VERSION}-macOS-universal.dmg"

case "$PACKAGE_FORMAT" in
    all|zip|dmg) ;;
    *) echo "不支持的打包格式：$PACKAGE_FORMAT" >&2; exit 2 ;;
esac

"$ROOT_DIR/App/build.sh"
mkdir -p "$DIST_DIR"

if [[ "$PACKAGE_FORMAT" == "all" || "$PACKAGE_FORMAT" == "zip" ]]; then
    rm -f "$ZIP_ARCHIVE" "$ZIP_ARCHIVE.sha256"
    ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ZIP_ARCHIVE"
    shasum -a 256 "$ZIP_ARCHIVE" > "$ZIP_ARCHIVE.sha256"
    echo "$ZIP_ARCHIVE"
fi

if [[ "$PACKAGE_FORMAT" == "all" || "$PACKAGE_FORMAT" == "dmg" ]]; then
    DMG_STAGE="$(mktemp -d "$DIST_DIR/.dmg-stage.XXXXXX")"
    trap 'rm -rf "$DMG_STAGE"' EXIT
    rm -f "$DMG_ARCHIVE" "$DMG_ARCHIVE.sha256"
    ditto "$APP_DIR" "$DMG_STAGE/Network Speed.app"
    ln -s /Applications "$DMG_STAGE/Applications"
    hdiutil create \
        -volname "网络速度" \
        -srcfolder "$DMG_STAGE" \
        -ov \
        -format UDZO \
        "$DMG_ARCHIVE"
    shasum -a 256 "$DMG_ARCHIVE" > "$DMG_ARCHIVE.sha256"
    echo "$DMG_ARCHIVE"
fi
