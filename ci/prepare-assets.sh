#!/bin/bash
set -euo pipefail
# Preserve the Android source artwork; only generate the native build size.
sips -z 1024 1024 ci/assets/AppIcon-source.png --out MoshiDopaApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png >/dev/null
mkdir -p LiveActivityWidget/Assets.xcassets/home_mascot_coin.imageset
cp MoshiDopaApp/Resources/Assets.xcassets/home_mascot_coin.imageset/Contents.json LiveActivityWidget/Assets.xcassets/home_mascot_coin.imageset/
cp MoshiDopaApp/Resources/Assets.xcassets/home_mascot_coin.imageset/*.png LiveActivityWidget/Assets.xcassets/home_mascot_coin.imageset/
