#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="MacMouseFixPro"
STAGING_DIR="${TMPDIR:-/private/tmp}/$APP_NAME-release-$UID"
APP_DIR="$STAGING_DIR/$APP_NAME.app"
OUTPUT_APP_DIR="$ROOT_DIR/dist/$APP_NAME.app"
OUTPUT_ZIP="$ROOT_DIR/dist/$APP_NAME.zip"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"

cd "$ROOT_DIR"
swift build -c release

rm -rf "$STAGING_DIR" "$OUTPUT_APP_DIR" "$OUTPUT_ZIP"
mkdir -p "$MACOS_DIR"

cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>MacMouseFixPro</string>
  <key>CFBundleIdentifier</key>
  <string>local.macmousefixpro</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>MacMouseFixPro</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.2.0</string>
  <key>CFBundleVersion</key>
  <string>2</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR" >/dev/null
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

mkdir -p "$ROOT_DIR/dist"
COPYFILE_DISABLE=1 ditto "$APP_DIR" "$OUTPUT_APP_DIR"
COPYFILE_DISABLE=1 ditto -c -k --keepParent "$APP_DIR" "$OUTPUT_ZIP"
rm -rf "$STAGING_DIR"

echo "Built $OUTPUT_APP_DIR"
echo "Release archive $OUTPUT_ZIP"
