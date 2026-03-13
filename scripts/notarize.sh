#!/bin/zsh

# 公証（Notarization）& ステープルスクリプト
#
# 事前準備（初回のみ）:
#   xcrun notarytool store-credentials "LimitBar" \
#     --apple-id "your@apple.com" \
#     --team-id "95U36FYLHZ" \
#     --password "<app-specific-password>"
#
# 使い方:
#   ./scripts/notarize.sh              # dist/LimitBar.app を公証
#   TARGET=dist/LimitBar.dmg ./scripts/notarize.sh  # DMG を公証

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_PLIST="$ROOT_DIR/LimitBar/Sources/LimitBar/Resources/AppVersion.plist"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :MarketingVersion' "$VERSION_PLIST")}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist/v$VERSION}"
TARGET="${TARGET:-$DIST_DIR/LimitBar.dmg}"
KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-LimitBar}"

if [[ ! -e "$TARGET" ]]; then
  echo "Target not found: $TARGET" >&2
  exit 1
fi

# ZIP にまとめてから提出（.app の場合）
if [[ "$TARGET" == *.app ]]; then
  ZIP_PATH="$DIST_DIR/_notarize_upload.zip"
  echo "==> Creating ZIP for notarization"
  ditto -c -k --keepParent "$TARGET" "$ZIP_PATH"
  SUBMIT_PATH="$ZIP_PATH"
else
  SUBMIT_PATH="$TARGET"
fi

echo "==> Submitting for notarization: $SUBMIT_PATH"
xcrun notarytool submit "$SUBMIT_PATH" \
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait

[[ -n "${ZIP_PATH:-}" ]] && rm -f "$ZIP_PATH"

echo "==> Stapling notarization ticket to: $TARGET"
xcrun stapler staple "$TARGET"
xcrun stapler validate "$TARGET"

echo "Notarization complete: $TARGET"
