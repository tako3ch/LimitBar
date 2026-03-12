#!/bin/zsh

set -euo pipefail

APP_NAME="LimitBar"
BUNDLE_ID="${BUNDLE_ID:-com.umidesign.LimitBar}"
VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
MIN_SYSTEM_VERSION="${MIN_SYSTEM_VERSION:-14.0}"
CONFIGURATION="${CONFIGURATION:-release}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIGURATION"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="$DIST_DIR/$APP_NAME.app"
EXECUTABLE_PATH="$BUILD_DIR/$APP_NAME"
RESOURCE_BUNDLE_PATH="$BUILD_DIR/${APP_NAME}_${APP_NAME}.bundle"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

if [[ "$CONFIGURATION" != "release" && "$CONFIGURATION" != "debug" ]]; then
  echo "Unsupported CONFIGURATION: $CONFIGURATION" >&2
  exit 1
fi

echo "==> Building $APP_NAME ($CONFIGURATION)"
cd "$ROOT_DIR"
swift build -c "$CONFIGURATION"

if [[ ! -f "$EXECUTABLE_PATH" ]]; then
  echo "Executable not found: $EXECUTABLE_PATH" >&2
  exit 1
fi

echo "==> Creating app bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$EXECUTABLE_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if [[ -d "$RESOURCE_BUNDLE_PATH" ]]; then
  cp -R "$RESOURCE_BUNDLE_PATH" "$APP_DIR/Contents/Resources/"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "==> Code signing app bundle with identity: $SIGN_IDENTITY"
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"

echo "Built app: $APP_DIR"
