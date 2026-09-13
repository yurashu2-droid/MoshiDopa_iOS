#!/bin/bash
set -euo pipefail
# Preserve the Android source artwork; only generate the native build size.
sips -z 1024 1024 ci/assets/AppIcon-source.png --out MoshiDopaApp/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png >/dev/null
