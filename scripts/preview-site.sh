#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p site/assets
cp docs/media/git-manager.mp4 docs/screenshots/*.png Support/AppIcon.png site/assets/
cd site
echo "Serving on http://localhost:${PORT:-4173}"
python3 -m http.server "${PORT:-4173}"
