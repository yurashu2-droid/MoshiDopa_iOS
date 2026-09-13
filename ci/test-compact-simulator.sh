#!/bin/bash
set -euo pipefail
# A second, narrow viewport catches fixed-width money and bottom-navigation regressions.
COMPACT_UDID=$(python3 - <<'PY'
import json
choices = [(runtime, device) for runtime, devices in json.load(open('artifacts/devices.json'))['devices'].items()
           for device in devices if device.get('isAvailable') and device['name'] == 'iPhone SE (3rd generation)']
if not choices: raise SystemExit('No compact iPhone SE simulator available for visual acceptance')
runtime, device = sorted(choices, key=lambda item: item[0], reverse=True)[0]
json.dump({'runtime': runtime, **device}, open('artifacts/compact-device.json', 'w'), indent=2)
print(device['udid'])
PY
)
xcrun simctl boot "$COMPACT_UDID" || true
xcrun simctl bootstatus "$COMPACT_UDID" -b
xcrun simctl status_bar "$COMPACT_UDID" override --time '9:41' --batteryState charged --batteryLevel 100
TEST_STATUS=0
xcodebuild -project MoshiDopa.xcodeproj -scheme MoshiDopa -configuration Debug \
  -destination "platform=iOS Simulator,id=$COMPACT_UDID" -derivedDataPath build/simulator \
  -resultBundlePath artifacts/Compact.xcresult -parallel-testing-enabled NO \
  -only-testing:MoshiDopaUITests/VisualFlowTests/testTabNavigationAndCounterSettings \
  -only-testing:MoshiDopaUITests/VisualFlowTests/testHistoryOpensSelectedReceipt \
  CODE_SIGNING_ALLOWED=NO test-without-building 2>&1 | tee artifacts/compact-tests.log || TEST_STATUS=$?
xcrun simctl install "$COMPACT_UDID" build/simulator/Build/Products/Debug-iphonesimulator/MoshiDopa.app
mkdir -p artifacts/screenshots/compact
for screen in home history settings counter receipt statement whatif; do
  xcrun simctl terminate "$COMPACT_UDID" com.moshidopa.app || true
  xcrun simctl launch "$COMPACT_UDID" com.moshidopa.app --screen "$screen" --fixture large
  sleep 2
  xcrun simctl io "$COMPACT_UDID" screenshot "artifacts/screenshots/compact/$screen-large.png"
done
exit "$TEST_STATUS"
