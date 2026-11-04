#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

TAG="${1:?usage: package-release.sh <tag>}"
APP_NAME="Can I Delete This Repo"
SLUG="CanIDeleteThisRepo-${TAG}"
OUT="build/release"

rm -rf "$OUT"
mkdir -p "$OUT/dmg"

ditto -c -k --sequesterRsrc --keepParent "build/${APP_NAME}.app" "$OUT/${SLUG}-macos.zip"

cp -R "build/${APP_NAME}.app" "$OUT/dmg/"
ln -s /Applications "$OUT/dmg/Applications"
hdiutil create -volname "$APP_NAME" -srcfolder "$OUT/dmg" -ov -format UDZO "$OUT/${SLUG}.dmg" >/dev/null
rm -rf "$OUT/dmg"

(cd "$OUT" && shasum -a 256 "${SLUG}.dmg" "${SLUG}-macos.zip" > checksums.txt)
ls -1 "$OUT"
