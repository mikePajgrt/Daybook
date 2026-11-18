#!/bin/bash
# Build phase of the app target (project.yml, "Stamp build number"). Runs last before signing.
# A Release build that still carries the development build number 1 gets the date-time build number
# (scripts/build-number.sh) and the short commit hash in its Info.plist, so an archive made in Xcode
# (Product > Archive) never repeats a build number App Store Connect already has. Builds from
# scripts/release.sh and scripts/build-local-mac.sh pass their own numbers and are left alone;
# Debug builds keep 1.
set -euo pipefail

[ "${CONFIGURATION:-}" = "Release" ] || exit 0
[ "${CURRENT_PROJECT_VERSION:-}" = "1" ] || exit 0

PLIST="$TARGET_BUILD_DIR/$INFOPLIST_PATH"
BUILD_NUMBER="$("$SRCROOT/scripts/build-number.sh")"
COMMIT="$(git -C "$SRCROOT" rev-parse --short HEAD 2>/dev/null || true)"
if [ -n "$COMMIT" ] && [ -n "$(git -C "$SRCROOT" status --porcelain 2>/dev/null)" ]; then
    COMMIT="$COMMIT-dirty"
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :DaybookCommit $COMMIT" "$PLIST"
echo "Daybook build number $BUILD_NUMBER, commit ${COMMIT:-unknown}"
