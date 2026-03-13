#!/bin/zsh

# DMG 作成スクリプト
#
# 事前条件:
#   dist/LimitBar.app が公証済みであること
#   （build_app.sh → notarize.sh TARGET=dist/LimitBar.app の順で実行済み）
#
# 使い方:
#   ./scripts/build_dmg.sh

set -euo pipefail

APP_NAME="LimitBar"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_PLIST="$ROOT_DIR/LimitBar/Sources/LimitBar/Resources/AppVersion.plist"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :MarketingVersion' "$VERSION_PLIST")}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/v$VERSION}"
DMG_NAME="${DMG_NAME:-$APP_NAME}"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"
APP_DIR="$DIST_DIR/$APP_NAME.app"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-LimitBar}"

if [[ ! -d "$APP_DIR" ]]; then
  echo "ERROR: App bundle not found: $APP_DIR" >&2
  echo "先に build_app.sh と notarize.sh を実行してください。" >&2
  exit 1
fi

# 公証済みか確認
if ! spctl --assess --verbose "$APP_DIR" 2>&1 | grep -q "accepted"; then
  echo "ERROR: $APP_DIR が公証されていません。先に notarize.sh を実行してください。" >&2
  exit 1
fi

echo "==> Preparing DMG contents"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP_DIR" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

echo "==> Creating DMG (HFS+) at $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  -fs "HFS+" \
  "$DMG_PATH"

rm -rf "$DMG_ROOT"

echo "==> Notarizing DMG"
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

echo "==> Stapling notarization ticket to DMG"
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "Built DMG: $DMG_PATH"
