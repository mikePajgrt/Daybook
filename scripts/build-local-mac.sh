#!/bin/sh
# Builds the Mac app for running on this machine without an Apple Developer login:
# ad-hoc signature, no iCloud (categories stay on this Mac). Run from the repo root.
xcodegen generate > /dev/null || exit 1
xcodebuild -project Daybook.xcodeproj -scheme Daybook -destination 'platform=macOS' \
  -derivedDataPath .build/local -quiet build \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= PROVISIONING_PROFILE_SPECIFIER= \
  CODE_SIGN_ENTITLEMENTS=App/Daybook.entitlements DAYBOOK_CLOUDKIT_CONTAINER= || exit 1
echo ".build/local/Build/Products/Debug/Daybook.app"
