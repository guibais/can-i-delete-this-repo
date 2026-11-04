#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/Git Manager.app/Contents/MacOS/GitManager"
OUT="docs/screenshots"
mkdir -p "$OUT"

window_id() {
  swift -e 'import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let match = list.first { ($0["kCGWindowOwnerName"] as? String) == "Git Manager" && ($0["kCGWindowLayer"] as? Int) == 0 }
print(match?["kCGWindowNumber"] as? Int ?? 0)'
}

capture() {
  local name="$1" select="$2"
  pkill -x GitManager || true
  GITMANAGER_DEMO=1 GITMANAGER_DEMO_SELECT="$select" "$APP" >/dev/null 2>&1 &
  sleep 4
  osascript -e 'tell application "System Events" to set frontmost of (first process whose name is "GitManager") to true' || true
  sleep 1
  screencapture -o -x -l"$(window_id)" "$OUT/$name.png"
  pkill -x GitManager || true
}

capture overview none
capture detail aurora-web
capture safe atlas-api
capture onboarding onboarding
