#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
APP="build/Can I Delete This Repo.app/Contents/MacOS/CanIDeleteThisRepo"
OUT="docs/screenshots"
mkdir -p "$OUT"

window_id() {
  swift -e 'import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let match = list.first { ($0["kCGWindowOwnerName"] as? String) == "Can I Delete This Repo?" && ($0["kCGWindowLayer"] as? Int) == 0 }
print(match?["kCGWindowNumber"] as? Int ?? 0)'
}

capture() {
  local name="$1" select="$2"
  pkill -x CanIDeleteThisRepo || true
  CANIDELETE_DEMO=1 CANIDELETE_DEMO_SELECT="$select" "$APP" >/dev/null 2>&1 &
  sleep 6
  osascript -e 'tell application "System Events" to set frontmost of (first process whose name is "CanIDeleteThisRepo") to true' || true
  sleep 1
  screencapture -o -x -l"$(window_id)" "$OUT/$name.png"
  pkill -x CanIDeleteThisRepo || true
}

capture overview none
capture activity activity
capture detail aurora-web
capture safe atlas-api
capture onboarding onboarding
