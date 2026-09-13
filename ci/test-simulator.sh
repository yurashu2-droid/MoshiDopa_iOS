#!/bin/bash
set -euo pipefail
mkdir -p artifacts/screenshots
# Choose an available iPhone from the selected Xcode runtime; persist the exact choice.
UDID=$(python3 - <<'PY'
import json
data = json.load(open('artifacts/devices.json'))['devices']
choices = [(runtime, d) for runtime, ds in data.items() for d in ds
           if d.get('isAvailable') and 'iPhone' in d['name']]
if not choices: raise SystemExit('No available iPhone simulator')
choices.sort(key=lambda item: (item[0], 'Pro' in item[1]['name'], item[1]['name']), reverse=True)
runtime, device = choices[0]
json.dump({'runtime':runtime, **device}, open('artifacts/selected-device.json','w'), indent=2)
print(device['udid'])
PY
)
xcrun simctl boot "$UDID" || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl status_bar "$UDID" override --time '9:41' --batteryState charged --batteryLevel 100
TEST_STATUS=0
xcodebuild -project MoshiDopa.xcodeproj -scheme MoshiDopa -configuration Debug \
  -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath build/simulator \
  -resultBundlePath artifacts/Tests.xcresult -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO test 2>&1 | tee artifacts/simulator-tests.log || TEST_STATUS=$?
printf '%s\n' "$TEST_STATUS" > artifacts/simulator-test-exit-code.txt
APP=build/simulator/Build/Products/Debug-iphonesimulator/MoshiDopa.app
ditto -c -k --sequesterRsrc --keepParent "$APP" artifacts/MoshiDopa-simulator.zip
xcrun simctl install "$UDID" "$APP"
for screen in home history settings counter receipt statement onboarding whatif measurement; do
  for fixture in empty populated large; do
    xcrun simctl terminate "$UDID" com.moshidopa.app || true
    xcrun simctl launch "$UDID" com.moshidopa.app --screen "$screen" --fixture "$fixture"
    sleep 2
    xcrun simctl io "$UDID" screenshot "artifacts/screenshots/$screen-$fixture.png"
  done
done
xcrun simctl terminate "$UDID" com.moshidopa.app || true
xcrun simctl launch "$UDID" com.moshidopa.app --screen whatif --fixture populated
xcrun simctl io "$UDID" recordVideo --codec=h264 artifacts/whatif-preview.mp4 &
VIDEO_PID=$!
sleep 22
kill -INT "$VIDEO_PID"
wait "$VIDEO_PID" || true

# Preserve test failures even when evidence capture succeeds.
exit "$TEST_STATUS"
