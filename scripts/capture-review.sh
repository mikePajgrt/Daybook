#!/bin/sh
# Builds the app and captures the demo states into .impeccable/review/ for visual review.
# Run from the repo root. Needs iOS 26 simulators and Screen Recording permission for the Mac shots,
# which capture only the Daybook window (scripts/window-id.swift finds it).
# Override the devices with PHONE=<udid> TABLET=<udid>.
PHONE=${PHONE:-B60E068A-347B-4B91-AFCF-005F31FD355C}
TABLET=${TABLET:-0D46D1E7-BB64-4249-8520-77328AD92B02}
BUNDLE=app.daybook.Daybook
OUT=.impeccable/review
SIMAPP=.build/xcode/Build/Products/Debug-iphonesimulator/Daybook.app
MACAPP=.build/xcode/Build/Products/Debug/Daybook.app
mkdir -p "$OUT"

xcodegen generate > /dev/null || exit 1
xcodebuild -project Daybook.xcodeproj -scheme Daybook -destination 'platform=macOS' -derivedDataPath .build/xcode -quiet build || exit 1
xcodebuild -project Daybook.xcodeproj -scheme Daybook -destination "platform=iOS Simulator,id=$PHONE" -derivedDataPath .build/xcode -quiet build || exit 1

# Mac first: quitting the Mac app by name would also kill a simulator process of the same name.
# Only the Daybook window is captured, never the whole screen: other windows are private.
# macshot FILE [launch arguments...]
macshot() {
  file=$1
  shift
  pkill -x Daybook 2> /dev/null
  sleep 1
  # Ignore saved window state: a session that was killed can restore to no window at all.
  open -n "$MACAPP" --args -demo "$@" -ApplePersistenceIgnoreState YES
  sleep 6
  window=$(swift scripts/window-id.swift Daybook)
  if [ -n "$window" ]; then
    screencapture -x -o -l "$window" "$OUT/$file" || echo "mac capture refused: $file"
  else
    echo "no Daybook window found, skipped $file"
  fi
  pkill -x Daybook 2> /dev/null
}
rm -f "$OUT/mac-screen.png"
macshot mac.png -demo-dark
macshot mac-light.png -demo-light
macshot mac-week.png -demo-dark -demo-week
macshot mac-week-light.png -demo-light -demo-week
macshot mac-day.png -demo-dark -demo-day-view

# shot DEVICE FILE [launch arguments...]
shot() {
  device=$1
  file=$2
  shift 2
  xcrun simctl terminate "$device" "$BUNDLE" 2> /dev/null
  xcrun simctl launch "$device" "$BUNDLE" -demo "$@" > /dev/null
  sleep 6
  xcrun simctl io "$device" screenshot "$OUT/$file" 2> /dev/null
}

for device in "$PHONE" "$TABLET"; do
  xcrun simctl boot "$device" 2> /dev/null
  xcrun simctl bootstatus "$device" > /dev/null
  xcrun simctl install "$device" "$SIMAPP"
  xcrun simctl ui "$device" content_size large
  xcrun simctl ui "$device" appearance dark
done
sleep 4

shot "$PHONE" phone.png
shot "$PHONE" phone-day.png -demo-day
shot "$PHONE" phone-calendars.png -demo-calendars
shot "$PHONE" phone-off.png -demo-off
shot "$PHONE" phone-denied.png -demo-denied
xcrun simctl ui "$PHONE" content_size accessibility-large
shot "$PHONE" phone-large-type.png
shot "$PHONE" phone-week-large-type.png -demo-week
xcrun simctl ui "$PHONE" content_size large
shot "$PHONE" phone-light.png -demo-light
shot "$PHONE" phone-week.png -demo-week
shot "$PHONE" phone-week-light.png -demo-week -demo-light
shot "$PHONE" phone-day-view.png -demo-day-view

shot "$TABLET" tablet.png
shot "$TABLET" tablet-off.png -demo-off
shot "$TABLET" tablet-week.png -demo-week
shot "$TABLET" tablet-day-view.png -demo-day-view

shasum "$OUT"/*.png
