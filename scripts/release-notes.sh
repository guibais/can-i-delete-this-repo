#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${1:?usage: release-notes.sh <tag>}"
REPO="${GITHUB_REPOSITORY:-guibais/can-i-delete-this-repo}"
PREVIOUS="$(git describe --tags --abbrev=0 "${TAG}^" 2>/dev/null || true)"
RANGE="${PREVIOUS:+${PREVIOUS}..}${TAG}"

section() {
  local title="$1" pattern="$2"
  local lines
  lines="$(git log "$RANGE" --no-merges --format='%s|%h' | grep -E "^(${pattern})(\(.+\))?!?: " | sed -E "s/^[a-z]+(\(.+\))?!?: (.*)\|(.*)$/- \2 (\3)/" || true)"
  [ -z "$lines" ] && return 0
  printf '### %s\n\n%s\n\n' "$title" "$lines"
}

printf '## Install\n\n'
printf 'Download **CanIDeleteThisRepo-%s.dmg**, open it and drag the app to Applications.\n' "$TAG"
printf 'The app is not notarized yet, so on first launch run:\n\n'
printf '```bash\nxattr -dr com.apple.quarantine "/Applications/Can I Delete This Repo.app"\n```\n\n'

section "Features" "feat"
section "Bug Fixes" "fix"
section "Performance" "perf"
section "Refactoring" "refactor"
section "Documentation" "docs"

[ -n "$PREVIOUS" ] && printf '**Full changelog**: https://github.com/%s/compare/%s...%s\n' "$REPO" "$PREVIOUS" "$TAG"
exit 0
