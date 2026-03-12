#!/bin/zsh

set -euo pipefail

APP_NAME="LimitBar"
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
DMG_NAME="${DMG_NAME:-$APP_NAME}"
DMG_ROOT="$DIST_DIR/dmg-root"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"

"$ROOT_DIR/scripts/build_app.sh"

APP_DIR="$DIST_DIR/$APP_NAME.app"

if [[ ! -d "$APP_DIR" ]]; then
  echo "App bundle not found: $APP_DIR" >&2
  exit 1
fi

echo "==> Preparing DMG contents"
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"
cp -R "$APP_DIR" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

echo "==> Creating DMG at $DMG_PATH"
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "Built DMG: $DMG_PATH"
