#!/bin/sh
# Builds the app and captures the demo states into .impeccable/review/ for visual review.
# Run from the repo root. Needs iOS 26 simulators and Screen Recording permission for the Mac shots,
# which capture only the Daybook window (scripts/window-id.swift finds it).
# Override the devices with PHONE=<udid> TABLET=<udid>.
# Every shot is pinned to Czech (-demo-locale cs) whatever the device's language; a later
# -demo-locale en in a shot's arguments wins, for the English captures.
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
  open -n "$MACAPP" --args -demo -demo-locale cs "$@" -ApplePersistenceIgnoreState YES
  sleep 6
  window=$(swift scripts/window-id.swift Daybook)
  if [ -n "$window" ]; then
    screencapture -x -o -l "$window" "$OUT/$file" || echo "mac capture refused: $file"
  else
    echo "no Daybook window found, skipped $file"
  fi
  pkill -x Daybook 2> /dev/null
}
# macregion FILE [launch arguments...]: the Daybook window's rectangle, so its popover or sheet
# (separate windows on top of it) is in the picture. The window is frontmost, so nothing else is.
macregion() {
  file=$1
  shift
  pkill -x Daybook 2> /dev/null
  sleep 1
  open -n "$MACAPP" --args -demo -demo-locale cs "$@" -ApplePersistenceIgnoreState YES
  sleep 7
  bounds=$(swift scripts/window-id.swift Daybook --bounds)
  if [ -n "$bounds" ]; then
    screencapture -x -R "$bounds" "$OUT/$file" || echo "mac capture refused: $file"
  else
    echo "no Daybook window found, skipped $file"
  fi
  pkill -x Daybook 2> /dev/null
}
rm -f "$OUT/mac-screen.png"
# A locked screen captures as black: skip the Mac rather than write images that show nothing.
if ioreg -n Root -d1 | grep -q '"CGSSessionScreenIsLocked"=Yes'; then
  echo "the Mac's screen is locked: no Mac captures"
  MAC=no
fi
if [ "$MAC" != no ]; then
macshot mac.png -demo-dark
macshot mac-light.png -demo-light
macshot mac-week.png -demo-dark -demo-week
macshot mac-week-light.png -demo-light -demo-week
macshot mac-day.png -demo-dark -demo-day-view
macregion mac-detail.png -demo-dark -demo-detail
macregion mac-detail-readonly.png -demo-light -demo-detail-readonly
macregion mac-delete.png -demo-dark -demo-delete
macregion mac-editor-new.png -demo-dark -demo-editor-new
macregion mac-editor-new-light.png -demo-light -demo-editor-new
macregion mac-editor-edit.png -demo-dark -demo-editor-edit
macregion mac-new-calendar.png -demo-dark -demo-new-calendar
macshot mac-category-off.png -demo-dark -demo-category-off
macshot mac-uncategorized-off.png -demo-light -demo-uncategorized-off
macregion mac-category-editor.png -demo-dark -demo-category-editor
macregion mac-category-delete.png -demo-dark -demo-category-delete
macregion mac-editor-categories.png -demo-dark -demo-editor-categories
macregion mac-detail-categories.png -demo-light -demo-detail-categories
macshot mac-search.png -demo-dark -demo-search
macshot mac-search-empty.png -demo-light -demo-search-empty
macshot mac-search-none.png -demo-dark -demo-search-none -demo-category-off
macshot mac-search-en.png -demo-dark -demo-search -demo-locale en
macshot mac-scrolled.png -demo-dark -demo-scrolled
macshot mac-first-run.png -demo-light -demo-first-run
macshot mac-no-accounts.png -demo-dark -demo-no-accounts
macshot mac-en.png -demo-dark -demo-locale en
macshot mac-week-en.png -demo-light -demo-week -demo-locale en
macshot mac-week-off.png -demo-dark -demo-week -demo-off
macshot mac-collapsed.png -demo-dark -demo-rail-collapsed -demo-off
macshot mac-search-note.png -demo-dark -demo-search -demo-search-query strankovani
macregion mac-detail-attendees.png -demo-dark -demo-detail-attendees
macregion mac-delete-single.png -demo-dark -demo-delete-single
macregion mac-save-failure.png -demo-dark -demo-save-failure
macregion mac-discard.png -demo-dark -demo-discard
macshot mac-category-error.png -demo-dark -demo-category-error
fi

# shot DEVICE FILE [launch arguments...]
shot() {
  device=$1
  file=$2
  shift 2
  xcrun simctl terminate "$device" "$BUNDLE" 2> /dev/null
  xcrun simctl launch "$device" "$BUNDLE" -demo -demo-locale cs "$@" > /dev/null
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
shot "$PHONE" phone-editor-large-type.png -demo-editor-edit
shot "$PHONE" phone-detail-large-type.png -demo-day-view -demo-detail
shot "$PHONE" phone-categories-large-type.png -demo-categories
shot "$PHONE" phone-category-editor-large-type.png -demo-categories -demo-category-editor
shot "$PHONE" phone-editor-categories-large-type.png -demo-editor-categories
xcrun simctl ui "$PHONE" content_size large
shot "$PHONE" phone-light.png -demo-light
shot "$PHONE" phone-week.png -demo-week
shot "$PHONE" phone-week-light.png -demo-week -demo-light
shot "$PHONE" phone-day-view.png -demo-day-view
shot "$PHONE" phone-detail.png -demo-day-view -demo-detail
shot "$PHONE" phone-detail-readonly.png -demo-day-view -demo-detail-readonly
shot "$PHONE" phone-delete.png -demo-week -demo-delete
shot "$PHONE" phone-editor-new.png -demo-editor-new
shot "$PHONE" phone-editor-new-light.png -demo-editor-new -demo-light
shot "$PHONE" phone-editor-edit.png -demo-editor-edit
shot "$PHONE" phone-new-calendar.png -demo-calendars -demo-new-calendar
shot "$PHONE" phone-calendar-color.png -demo-calendars -demo-calendar-color
shot "$PHONE" phone-categories.png -demo-categories
shot "$PHONE" phone-categories-light.png -demo-categories -demo-light
shot "$PHONE" phone-category-off.png -demo-category-off
shot "$PHONE" phone-uncategorized-off.png -demo-uncategorized-off
shot "$PHONE" phone-category-editor.png -demo-categories -demo-category-editor
shot "$PHONE" phone-category-editor-icloud-light.png -demo-categories -demo-category-editor -demo-icloud-unavailable -demo-light
shot "$PHONE" phone-category-delete.png -demo-categories -demo-category-delete
shot "$PHONE" phone-editor-categories.png -demo-editor-categories
shot "$PHONE" phone-detail-categories.png -demo-day-view -demo-detail-categories
shot "$PHONE" phone-editor-categories-empty.png -demo-editor-categories -demo-no-categories
shot "$PHONE" phone-search.png -demo-search
shot "$PHONE" phone-search-empty.png -demo-search-empty
shot "$PHONE" phone-search-none.png -demo-search-none -demo-category-off
shot "$PHONE" phone-search-en.png -demo-search -demo-locale en
shot "$PHONE" phone-scrolled.png -demo-scrolled
shot "$PHONE" phone-first-run.png -demo-first-run
shot "$PHONE" phone-first-run-light.png -demo-first-run -demo-light
shot "$PHONE" phone-no-accounts.png -demo-no-accounts
shot "$PHONE" phone-en.png -demo-locale en
shot "$PHONE" phone-week-en.png -demo-week -demo-locale en
shot "$PHONE" phone-detail-en.png -demo-day-view -demo-detail -demo-locale en
shot "$PHONE" phone-editor-en.png -demo-editor-edit -demo-locale en
shot "$PHONE" phone-week-off.png -demo-week -demo-off
shot "$PHONE" phone-day-view-category-off.png -demo-day-view -demo-category-off
shot "$PHONE" phone-occurrence-categories.png -demo-occurrence-categories
shot "$PHONE" phone-editor-allday.png -demo-editor-allday
shot "$PHONE" phone-editor-allday-light.png -demo-editor-allday -demo-light
shot "$PHONE" phone-categories-syncing.png -demo-categories -demo-icloud-syncing
shot "$PHONE" phone-categories-not-saved.png -demo-categories -demo-not-saved
shot "$PHONE" phone-search-hidden.png -demo-search -demo-search-query retro -demo-category-off -demo-search-hidden
shot "$PHONE" phone-search-past.png -demo-search -demo-search-past
shot "$PHONE" phone-search-note.png -demo-search -demo-search-query strankovani
shot "$PHONE" phone-search-attendee.png -demo-search -demo-search-query svobodova
shot "$PHONE" phone-detail-attendees.png -demo-day-view -demo-detail-attendees
shot "$PHONE" phone-save-failure.png -demo-save-failure
shot "$PHONE" phone-discard.png -demo-discard
shot "$PHONE" phone-delete-single.png -demo-day-view -demo-delete-single
shot "$PHONE" phone-invite.png -demo-invite
shot "$PHONE" phone-category-error.png -demo-category-error
shot "$PHONE" phone-scrolled-end.png -demo-scrolled-end
xcrun simctl ui "$PHONE" increase_contrast enabled
shot "$PHONE" phone-contrast.png
shot "$PHONE" phone-contrast-light.png -demo-light
shot "$PHONE" phone-week-contrast.png -demo-week
shot "$PHONE" phone-editor-contrast.png -demo-editor-allday
xcrun simctl ui "$PHONE" increase_contrast disabled
xcrun simctl ui "$PHONE" content_size accessibility-large
shot "$PHONE" phone-search-large-type.png -demo-search
shot "$PHONE" phone-first-run-large-type.png -demo-first-run
xcrun simctl ui "$PHONE" content_size large
# The app icon as the home screen draws it: Daybook sits third in the second row of the first page.
xcrun simctl terminate "$PHONE" "$BUNDLE" 2> /dev/null
sleep 3
xcrun simctl io "$PHONE" screenshot "$OUT/phone-home.png" 2> /dev/null
swift scripts/crop-png.swift "$OUT/phone-home.png" "$OUT/phone-app-icon.png" 600 530 290 320

shot "$TABLET" tablet.png
shot "$TABLET" tablet-off.png -demo-off
shot "$TABLET" tablet-week.png -demo-week
shot "$TABLET" tablet-day-view.png -demo-day-view
shot "$TABLET" tablet-detail.png -demo-detail
shot "$TABLET" tablet-delete.png -demo-delete
shot "$TABLET" tablet-editor-edit.png -demo-editor-edit
shot "$TABLET" tablet-editor-new-light.png -demo-editor-new -demo-light
shot "$TABLET" tablet-new-calendar.png -demo-new-calendar
shot "$TABLET" tablet-categories-light.png -demo-light
shot "$TABLET" tablet-category-off.png -demo-category-off
shot "$TABLET" tablet-uncategorized-off.png -demo-uncategorized-off
shot "$TABLET" tablet-category-editor.png -demo-category-editor
shot "$TABLET" tablet-category-delete.png -demo-category-delete
shot "$TABLET" tablet-editor-categories.png -demo-editor-categories
shot "$TABLET" tablet-detail-categories.png -demo-detail-categories
shot "$TABLET" tablet-search.png -demo-search
shot "$TABLET" tablet-search-none.png -demo-search-none -demo-category-off
shot "$TABLET" tablet-search-en.png -demo-search -demo-locale en
shot "$TABLET" tablet-scrolled.png -demo-scrolled
shot "$TABLET" tablet-first-run.png -demo-first-run
shot "$TABLET" tablet-no-accounts.png -demo-no-accounts
shot "$TABLET" tablet-en.png -demo-locale en
shot "$TABLET" tablet-week-en.png -demo-week -demo-light -demo-locale en
shot "$TABLET" tablet-day-view-en.png -demo-day-view -demo-locale en
shot "$TABLET" tablet-week-off.png -demo-week -demo-off
shot "$TABLET" tablet-day-view-category-off.png -demo-day-view -demo-category-off
shot "$TABLET" tablet-collapsed.png -demo-rail-collapsed
shot "$TABLET" tablet-week-collapsed.png -demo-week -demo-rail-collapsed
shot "$TABLET" tablet-week-off-collapsed.png -demo-week -demo-off -demo-rail-collapsed
shot "$TABLET" tablet-day-view-off-collapsed.png -demo-day-view -demo-category-off -demo-uncategorized-off -demo-rail-collapsed
shot "$TABLET" tablet-search-hidden.png -demo-search -demo-search-query retro -demo-category-off -demo-search-hidden
shot "$TABLET" tablet-search-note.png -demo-search -demo-search-query strankovani
shot "$TABLET" tablet-detail-attendees.png -demo-detail-attendees
shot "$TABLET" tablet-categories-syncing.png -demo-icloud-syncing
shot "$TABLET" tablet-category-error.png -demo-category-error
shot "$TABLET" tablet-scrolled-end.png -demo-scrolled-end
xcrun simctl ui "$TABLET" increase_contrast enabled
shot "$TABLET" tablet-contrast-light.png -demo-light
shot "$TABLET" tablet-contrast.png
shot "$TABLET" tablet-week-contrast.png -demo-week
xcrun simctl ui "$TABLET" increase_contrast disabled
xcrun simctl ui "$TABLET" content_size accessibility-large
shot "$TABLET" tablet-week-large-type.png -demo-week
shot "$TABLET" tablet-categories-large-type.png -demo-categories
shot "$TABLET" tablet-first-run-large-type.png -demo-first-run
xcrun simctl ui "$TABLET" content_size large
# iPad landscape is not captured: simctl cannot rotate a device, and iPadOS 26 refuses an app's
# own request for landscape in its windowing mode.

shasum "$OUT"/*.png
