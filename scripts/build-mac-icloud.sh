#!/bin/sh
# Builds the signed Debug Mac app with iCloud, for running on this Mac: scripts/build-mac-icloud.sh
# [development|production] (default development). "production" syncs categories with the same CloudKit
# environment as TestFlight and the App Store, in its own store file (Categories-cloud-production-debug);
# "development" uses the Development environment (Categories-cloud-development). Needs the Apple
# Developer account signed in to Xcode. Output: .build/schema/Build/Products/Debug/Daybook.app.
# For a build without signing or iCloud, use scripts/build-local-mac.sh.
cd "$(dirname "$0")/.." || exit 1
case "${1:-development}" in
  development) ENVIRONMENT=Development ;;
  production) ENVIRONMENT=Production ;;
  *) echo "usage: scripts/build-mac-icloud.sh [development|production]" >&2; exit 1 ;;
esac
xcodegen generate > /dev/null || exit 1
xcodebuild -project Daybook.xcodeproj -scheme Daybook -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/schema -allowProvisioningUpdates DEVELOPMENT_TEAM=XZR6HSC88P \
  DAYBOOK_CLOUDKIT_ENVIRONMENT="$ENVIRONMENT" -quiet build || exit 1
APP=.build/schema/Build/Products/Debug/Daybook.app
# The key has dots in it, which plutil reads as a path: PlistBuddy on a copy of the entitlements.
ENTITLEMENTS=$(mktemp)
codesign -d --entitlements - --xml "$APP" > "$ENTITLEMENTS" 2>/dev/null
SIGNED=$(/usr/libexec/PlistBuddy -c "Print :com.apple.developer.icloud-container-environment" "$ENTITLEMENTS" 2>/dev/null)
rm -f "$ENTITLEMENTS"
INFO=$(/usr/libexec/PlistBuddy -c "Print :DaybookCloudKitEnvironment" "$APP/Contents/Info.plist")
echo "$APP"
echo "CloudKit environment: signed $SIGNED, Info.plist $INFO"
[ "$SIGNED" = "$ENVIRONMENT" ] && [ "$INFO" = "$ENVIRONMENT" ] || { echo "error: expected $ENVIRONMENT" >&2; exit 1; }
