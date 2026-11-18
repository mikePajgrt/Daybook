#!/bin/sh
# Builds the Mac app for running on this machine without an Apple Developer login:
# ad-hoc signature, no iCloud (categories stay on this Mac). Run from the repo root.
# Version from project.yml; build number and commit as for scripts/release.sh (date-time build number,
# short hash, "-dirty" for a modified tree), shown in Settings and the About panel.
BUILD_NUMBER=$(scripts/build-number.sh) || exit 1
COMMIT=$(git rev-parse --short HEAD)
[ -z "$(git status --porcelain)" ] || COMMIT="$COMMIT-dirty"
xcodegen generate > /dev/null || exit 1
xcodebuild -project Daybook.xcodeproj -scheme Daybook -destination 'platform=macOS' \
  -derivedDataPath .build/local -quiet build \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" DAYBOOK_COMMIT="$COMMIT" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
  CODE_SIGN_ENTITLEMENTS=App/Daybook.entitlements DAYBOOK_CLOUDKIT_CONTAINER= || exit 1
echo ".build/local/Build/Products/Debug/Daybook.app"
