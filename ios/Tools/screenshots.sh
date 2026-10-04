#!/usr/bin/env bash
# The App Store screenshots, captured from the app itself.
#
# Runs ScreenshotTests on each device class App Store Connect requires, with
# the status bar set to Apple's usual 9:41, full battery and full signal, and
# writes the images to ios/AppStore/Screenshots/<display> - <size>/, named for
# the App Store Connect slot each belongs in. They are generated,
# so they are gitignored: run this again after the interface changes.
#
# App Store Connect wants a 6.5-inch iPhone set as well as 6.9-inch. There is
# no 6.5-inch simulator for current iOS, so that set is the 6.9-inch one
# scaled to 1284 × 2778, one of the sizes it accepts; the two screens differ
# by under half a percent in shape, so the edges are trimmed rather than the
# picture stretched.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ios="$(cd "$here/.." && pwd)"
out="$ios/AppStore/Screenshots"

capture() {  # simulator name, folder
  local name="$1" folder="$out/$2" udid
  udid="$(xcrun simctl list devices available | grep -F "    $name (" | head -1 | grep -oE '[0-9A-F-]{36}')" || true
  if [[ -z "$udid" ]]; then
    echo "No '$name' simulator. Install it in Xcode > Settings > Components." >&2
    exit 1
  fi
  rm -rf "$folder" && mkdir -p "$folder"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl status_bar "$udid" override --time 9:41 --dataNetwork wifi --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
  echo "  $2: capturing on $name"
  (cd "$ios" && TEST_RUNNER_SCREENSHOT_DIR="$folder" xcodebuild test -quiet \
    -project QuirePDF.xcodeproj -scheme QuirePDF -destination "id=$udid" \
    -only-testing:QuirePDFUITests/ScreenshotTests)
  xcrun simctl status_bar "$udid" clear
  local count
  count="$(find "$folder" -name '*.png' | wc -l | tr -d ' ')"
  [[ "$count" -gt 0 ]] || { echo "  $2: the test wrote no screenshots" >&2; exit 1; }
  echo "  $2: $count screenshots, $(sips -g pixelWidth -g pixelHeight "$(find "$folder" -name '*.png' | head -1)" | awk '/pixel/ {printf "%s ", $2}')px"
}

capture "iPhone 17 Pro Max" "iPhone 6.9in - 1320x2868"
capture "iPad Pro 13-inch (M5)" "iPad 13in - 2064x2752"

# 6.5-inch: scale the 6.9-inch set to 1284 wide, then trim the height to 2778.
small="$out/iPhone 6.5in - 1284x2778"
rm -rf "$small" && mkdir -p "$small"
for shot in "$out/iPhone 6.9in - 1320x2868"/*.png; do
  sips --resampleWidth 1284 "$shot" --out "$small/$(basename "$shot")" >/dev/null
  sips --cropToHeightWidth 2778 1284 "$small/$(basename "$shot")" >/dev/null
done
echo "  iPhone 6.5in: $(ls "$small" | wc -l | tr -d ' ') screenshots, 1284 2778 px (from 6.9-inch)"

echo "screenshots in ${out#"$ios/"}"
