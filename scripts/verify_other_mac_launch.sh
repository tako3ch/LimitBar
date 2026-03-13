#!/bin/zsh

set -euo pipefail

APP_PATH="${1:-/Applications/LimitBar.app}"
APP_NAME="LimitBar"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"
REPORT_DIR="${TMPDIR%/}/limitbar-launch-check"
LOG_FILE="$REPORT_DIR/report.txt"

mkdir -p "$REPORT_DIR"

exec > >(tee "$LOG_FILE") 2>&1

echo "== LimitBar other-mac launch verification =="
echo "Date: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo "Host: $(scutil --get ComputerName 2>/dev/null || hostname)"
echo "macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
echo "Arch: $(uname -m)"
echo "App path: $APP_PATH"
echo

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: app not found at $APP_PATH"
  exit 1
fi

echo "== codesign verify =="
codesign --verify --deep --strict "$APP_PATH" || true
echo

echo "== spctl assess =="
spctl --assess --type execute -vv "$APP_PATH" || true
echo

echo "== xattr =="
xattr -l "$APP_PATH" || true
echo

echo "== open app =="
open "$APP_PATH" || true
sleep 5

echo "== running after 5 seconds =="
pgrep -fl "$EXECUTABLE_PATH" || true
echo

echo "== running after 35 seconds =="
sleep 30
pgrep -fl "$EXECUTABLE_PATH" || true
echo

echo "== recent app logs =="
/usr/bin/log show --last 5m --style compact --predicate 'process == "LimitBar"' | /usr/bin/grep -v 'FrontBoard:SceneClient' | /usr/bin/grep -v 'NSSceneFenceAction' || true
echo

echo "== recent crash reports =="
find "$HOME/Library/Logs/DiagnosticReports" -maxdepth 1 -type f \( -name 'LimitBar*.crash' -o -name 'LimitBar*.ips' \) -mtime -1 -print || true
echo

echo "Report saved to: $LOG_FILE"
