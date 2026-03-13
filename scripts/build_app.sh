#!/bin/zsh

set -euo pipefail

APP_NAME="LimitBar"
BUNDLE_ID="${BUNDLE_ID:-com.umidesign.LimitBar}"
MIN_SYSTEM_VERSION="${MIN_SYSTEM_VERSION:-14.0}"
CONFIGURATION="${CONFIGURATION:-release}"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_PLIST="$ROOT_DIR/LimitBar/Sources/LimitBar/Resources/AppVersion.plist"
DEFAULT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :MarketingVersion' "$VERSION_PLIST")"
DEFAULT_BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :BuildNumber' "$VERSION_PLIST")"
VERSION="${VERSION:-$DEFAULT_VERSION}"
BUILD_NUMBER="${BUILD_NUMBER:-$DEFAULT_BUILD_NUMBER}"
BUILD_DIR_ARM64="$ROOT_DIR/.build/arm64-apple-macosx/$CONFIGURATION"
BUILD_DIR_X86="$ROOT_DIR/.build/x86_64-apple-macosx/$CONFIGURATION"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/v$VERSION}"
APP_DIR="$DIST_DIR/$APP_NAME.app"
EXECUTABLE_PATH_ARM64="$BUILD_DIR_ARM64/$APP_NAME"
EXECUTABLE_PATH_X86="$BUILD_DIR_X86/$APP_NAME"
RESOURCE_BUNDLE_PATH="$BUILD_DIR_ARM64/${APP_NAME}_${APP_NAME}.bundle"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application: UMI.DESIGN LIMITED LIABILITY COMPANY (95U36FYLHZ)}"
ENTITLEMENTS="$ROOT_DIR/LimitBar/Sources/LimitBar/Resources/LimitBar.entitlements"

if [[ "$CONFIGURATION" != "release" && "$CONFIGURATION" != "debug" ]]; then
  echo "Unsupported CONFIGURATION: $CONFIGURATION" >&2
  exit 1
fi

echo "==> Building $APP_NAME ($CONFIGURATION) — arm64"
cd "$ROOT_DIR"
swift build -c "$CONFIGURATION" --arch arm64

echo "==> Building $APP_NAME ($CONFIGURATION) — x86_64"
swift build -c "$CONFIGURATION" --arch x86_64

if [[ ! -f "$EXECUTABLE_PATH_ARM64" ]]; then
  echo "Executable not found: $EXECUTABLE_PATH_ARM64" >&2
  exit 1
fi
if [[ ! -f "$EXECUTABLE_PATH_X86" ]]; then
  echo "Executable not found: $EXECUTABLE_PATH_X86" >&2
  exit 1
fi

echo "==> Creating app bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

echo "==> Creating universal binary (arm64 + x86_64)"
lipo -create "$EXECUTABLE_PATH_ARM64" "$EXECUTABLE_PATH_X86" \
  -output "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Sparkle.framework を検索するための rpath を追加
install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_DIR/Contents/MacOS/$APP_NAME"

if [[ -d "$RESOURCE_BUNDLE_PATH" ]]; then
  cp -R "$RESOURCE_BUNDLE_PATH" "$APP_DIR/Contents/Resources/"
fi

# アイコンを生成（PNG → icns）
ICON_PNG="$ROOT_DIR/LimitBar/Sources/LimitBar/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
if [[ -f "$ICON_PNG" ]]; then
  echo "==> Generating AppIcon.icns"
  ICONSET_DIR="$(mktemp -d)/AppIcon.iconset"
  mkdir -p "$ICONSET_DIR"
  sips -z 16   16   "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png"    > /dev/null
  sips -z 32   32   "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" > /dev/null
  sips -z 32   32   "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png"    > /dev/null
  sips -z 64   64   "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" > /dev/null
  sips -z 128  128  "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png"  > /dev/null
  sips -z 256  256  "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" > /dev/null
  sips -z 256  256  "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png"  > /dev/null
  sips -z 512  512  "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" > /dev/null
  sips -z 512  512  "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png"  > /dev/null
  cp "$ICON_PNG" "$ICONSET_DIR/icon_512x512@2x.png"
  iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns"
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
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
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
  <key>SUFeedURL</key>
  <string>https://tako3ch.github.io/LimitBar/appcast.xml</string>
  <key>SUEnableAutomaticChecks</key>
  <true/>
  <key>SUPublicEDKey</key>
  <string>rxYJG4tCCTjsro95/zsWsoMoxL39+TVGaSJmuj7JdEU=</string>
</dict>
</plist>
PLIST

# Sparkle.framework を埋め込み
SPARKLE_FRAMEWORK=$(find "$ROOT_DIR/.build/artifacts" -path "*/macos-arm64_x86_64/Sparkle.framework" 2>/dev/null | head -1)
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  SPARKLE_FRAMEWORK=$(find "$ROOT_DIR/.build/artifacts" -name "Sparkle.framework" -maxdepth 8 2>/dev/null | head -1)
fi
if [[ -d "$SPARKLE_FRAMEWORK" ]]; then
  echo "==> Embedding Sparkle.framework from $SPARKLE_FRAMEWORK"
  mkdir -p "$APP_DIR/Contents/Frameworks"
  cp -R "$SPARKLE_FRAMEWORK" "$APP_DIR/Contents/Frameworks/"

  # 非サンドボックスアプリは XPC サービスを Sparkle.framework 内に置く
  # Contents/XPCServices/ へのコピーはサンドボックスアプリのみ必要
else
  echo "WARNING: Sparkle.framework not found — skipping embed" >&2
fi

echo "==> Code signing app bundle with identity: $SIGN_IDENTITY"
xattr -cr "$APP_DIR"

# Sparkle.framework の内部コンポーネントを内側から順番に署名
SPARKLE_EMBED="$APP_DIR/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE_EMBED" ]]; then
  # 1. Autoupdate バイナリ
  [[ -f "$SPARKLE_EMBED/Versions/B/Autoupdate" ]] && \
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
      "$SPARKLE_EMBED/Versions/B/Autoupdate"

  # 2. Updater.app
  [[ -d "$SPARKLE_EMBED/Versions/B/Updater.app" ]] && \
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
      "$SPARKLE_EMBED/Versions/B/Updater.app"

  # 3. Framework 内の XPCServices
  for xpc in "$SPARKLE_EMBED/Versions/B/XPCServices/"*.xpc; do
    [[ -d "$xpc" ]] && \
      codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$xpc"
  done

  # 4. Sparkle.framework 本体
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
    "$SPARKLE_EMBED"
fi

# 5. アプリ本体を署名
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" \
  "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "Built app: $APP_DIR"
