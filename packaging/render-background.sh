#!/bin/bash
# Renders dmg-background.html to dmg-background.png. Run once after editing
# the html; the png is committed so release.sh needs no browser installed.
#
# The png is rendered at 2x and stamped 144 dpi: Finder reads the dpi and
# draws it at point size, so it stays crisp on retina. A multi-image tiff
# (tiffutil -cathidpicheck) is the classic recipe but macOS 26's Finder
# silently rejects it — png is what actually works.
set -euo pipefail
cd "$(dirname "$0")"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

"${CHROME}" --headless=new --screenshot=bg2x.png --window-size=660,400 \
    --force-device-scale-factor=2 --hide-scrollbars \
    "file://$(pwd)/dmg-background.html" 2>/dev/null
sips -s dpiHeight 144 -s dpiWidth 144 bg2x.png --out dmg-background.png >/dev/null
rm -f bg2x.png
echo "yazıldı: $(pwd)/dmg-background.png"
