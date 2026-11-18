#!/bin/bash
# Archives Daybook for App Store Connect (the counterpart of Kastl's Scripts/release.sh, which signs for
# Developer ID instead). Archive and export only: nothing leaves this Mac unless --upload is given.
#
# Usage: scripts/release.sh [--dry-run] [--allow-dirty] [--platform ios|macos|all] [--upload [--allow-untagged]]
#   --dry-run         print every step and exit without running anything.
#   --allow-dirty     archive even with uncommitted changes in the working tree (the commit gets "-dirty").
#   --platform        ios (default), macos, or all.
#   --upload          upload the exported build to App Store Connect (TestFlight). HEAD must be tagged
#                     v<version> first (git tag v0.1.0); --allow-untagged skips that check.
#
# Version (CFBundleShortVersionString): DAYBOOK_VERSION, else the v* tag on HEAD without the "v", else
# MARKETING_VERSION from project.yml. App Store Connect takes up to three integers, e.g. 0.1.0 or 1.2.
# Build number (CFBundleVersion): the UTC date and time of the build, YYYYMMDD.HHMM (scripts/build-number.sh;
# DAYBOOK_BUILD_NUMBER overrides it). Commit: the short hash of HEAD in Info.plist's DaybookCommit, shown
# with the version in Settings and the Mac About panel, e.g. "0.1.0 (20261118.1045, 1d21270)".
#
# Steps: xcodegen generate; xcodebuild archive (Release, generic/platform=<platform>, automatic signing
# with the team in project.yml) into dist/Daybook-<platform>.xcarchive with the version, build number and
# commit on the command line (project.yml stays unchanged); a check that the archived Info.plist carries
# them; dist/ExportOptions-<platform>.plist (method app-store-connect, destination export, or upload with
# --upload); xcodebuild -exportArchive into dist/export-<platform>/.
# It does not bump MARKETING_VERSION, create or push tags, or submit anything for review.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"
DIST="$REPO_ROOT/dist"
DRY_RUN=0
ALLOW_DIRTY=0
UPLOAD=0
ALLOW_UNTAGGED=0
PLATFORM=ios

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --allow-dirty) ALLOW_DIRTY=1 ;;
        --upload) UPLOAD=1 ;;
        --allow-untagged) ALLOW_UNTAGGED=1 ;;
        --platform)
            shift
            PLATFORM="${1:-}" ;;
        --help|-h)
            sed -n '2,25p' "$0"
            exit 0 ;;
        *)
            echo "error: unknown argument: $1 (use --dry-run, --allow-dirty, --platform, --upload, --allow-untagged or --help)" >&2
            exit 1 ;;
    esac
    shift
done

case "$PLATFORM" in
    ios) PLATFORMS="iOS" ;;
    macos) PLATFORMS="macOS" ;;
    all) PLATFORMS="iOS macOS" ;;
    *) echo "error: --platform must be ios, macos or all" >&2; exit 1 ;;
esac

run() {
    if [ "$DRY_RUN" = 1 ]; then
        printf '+'; printf ' %q' "$@"; printf '\n'
    else
        "$@"
    fi
}

project_setting() {
    grep -E "^[[:space:]]*$1:" "$REPO_ROOT/project.yml" | head -n 1 \
        | sed -E 's/^[^:]*:[[:space:]]*"?([^"#]*[^"#[:space:]])"?.*$/\1/'
}

# Version: DAYBOOK_VERSION, the v* tag on HEAD, or project.yml.
TAGS="$(git -C "$REPO_ROOT" tag --points-at HEAD --list 'v*' 2>/dev/null || true)"
if [ -n "${DAYBOOK_VERSION:-}" ]; then
    VERSION="$DAYBOOK_VERSION"
elif [ -n "$TAGS" ]; then
    if [ "$(printf '%s\n' "$TAGS" | wc -l | tr -d ' ')" != 1 ]; then
        echo "error: several v* tags on HEAD ($(echo $TAGS)); set DAYBOOK_VERSION" >&2
        exit 1
    fi
    VERSION="${TAGS#v}"
else
    VERSION="$(project_setting MARKETING_VERSION)"
fi
if ! [[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    echo "error: invalid version '$VERSION' (App Store Connect takes up to three integers, e.g. 0.1.0)" >&2
    exit 1
fi
TEAM="$(project_setting DEVELOPMENT_TEAM)"
[ -n "$TEAM" ] || { echo "error: no DEVELOPMENT_TEAM in project.yml" >&2; exit 1; }

BUILD_NUMBER="$("$REPO_ROOT/scripts/build-number.sh")"
COMMIT="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
DIRTY="$(git -C "$REPO_ROOT" status --porcelain)"
if [ -n "$DIRTY" ]; then
    if [ "$ALLOW_DIRTY" = 0 ] && [ "$DRY_RUN" = 0 ]; then
        echo "error: the working tree has uncommitted changes:" >&2
        echo "$DIRTY" >&2
        echo "Commit or stash them, or run with --allow-dirty." >&2
        exit 1
    fi
    COMMIT="$COMMIT-dirty"
fi

if [ "$UPLOAD" = 1 ] && [ "$ALLOW_UNTAGGED" = 0 ] && ! printf '%s\n' "$TAGS" | grep -qx "v$VERSION"; then
    if [ "$DRY_RUN" = 0 ]; then
        echo "error: HEAD is not tagged v$VERSION; tag it first (git tag v$VERSION) or use --allow-untagged" >&2
        exit 1
    fi
    echo "note: HEAD is not tagged v$VERSION (the real run stops here)"
fi

for tool in xcodegen xcodebuild git plutil; do
    command -v "$tool" >/dev/null 2>&1 || { echo "error: required tool not found: $tool" >&2; exit 1; }
done

echo "Daybook $VERSION ($BUILD_NUMBER, $COMMIT), team $TEAM, platforms: $PLATFORMS, $([ "$UPLOAD" = 1 ] && echo "UPLOAD to App Store Connect" || echo "no upload")"

run mkdir -p "$DIST"
run xcodegen generate --quiet

for platform in $PLATFORMS; do
    ARCHIVE="$DIST/Daybook-$platform.xcarchive"
    EXPORT="$DIST/export-$platform"
    OPTIONS="$DIST/ExportOptions-$platform.plist"
    run rm -rf "$ARCHIVE" "$EXPORT"
    run xcodebuild -project "$REPO_ROOT/Daybook.xcodeproj" -scheme Daybook -configuration Release \
        -destination "generic/platform=$platform" -archivePath "$ARCHIVE" -allowProvisioningUpdates \
        MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" DAYBOOK_COMMIT="$COMMIT" \
        archive -quiet

    if [ "$platform" = iOS ]; then
        INFO="$ARCHIVE/Products/Applications/Daybook.app/Info.plist"
    else
        INFO="$ARCHIVE/Products/Applications/Daybook.app/Contents/Info.plist"
    fi
    if [ "$DRY_RUN" = 0 ]; then
        got="$(plutil -extract CFBundleShortVersionString raw "$INFO") ($(plutil -extract CFBundleVersion raw "$INFO"), $(plutil -extract DaybookCommit raw "$INFO"))"
        echo "archived $platform: $got"
        [ "$got" = "$VERSION ($BUILD_NUMBER, $COMMIT)" ] || { echo "error: the archive carries $got" >&2; exit 1; }
    fi

    DESTINATION=export
    [ "$UPLOAD" = 1 ] && DESTINATION=upload
    if [ "$DRY_RUN" = 1 ]; then
        echo "+ write $OPTIONS (method app-store-connect, destination $DESTINATION, team $TEAM)"
    else
        cat > "$OPTIONS" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>$DESTINATION</string>
    <key>teamID</key><string>$TEAM</string>
    <key>signingStyle</key><string>automatic</string>
    <key>manageAppVersionAndBuildNumber</key><false/>
    <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST
    fi
    run xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
        -exportOptionsPlist "$OPTIONS" -allowProvisioningUpdates
done

if [ "$DRY_RUN" = 1 ]; then
    echo "Dry run: nothing was built, exported or uploaded."
elif [ "$UPLOAD" = 1 ]; then
    echo "Uploaded $VERSION ($BUILD_NUMBER). It appears in App Store Connect, TestFlight, after processing."
else
    echo "Exported to $DIST/export-<platform>/. Nothing was uploaded; run again with --upload to send it."
fi
