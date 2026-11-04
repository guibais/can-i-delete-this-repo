#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh <version>  e.g. release.sh 0.2.0}"
TAG="v${VERSION#v}"

[ "$(git branch --show-current)" = "main" ] || { echo "Switch to main first."; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "Working tree is not clean."; exit 1; }
git pull --ff-only
git rev-parse "$TAG" >/dev/null 2>&1 && { echo "Tag $TAG already exists."; exit 1; }

git tag -a "$TAG" -m "$TAG"
git push origin "$TAG"
echo "Pushed $TAG. The Release workflow will build and publish it."
