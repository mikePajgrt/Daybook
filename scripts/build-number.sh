#!/bin/bash
# Prints the build number (CFBundleVersion) for a build made now: the UTC date and time as YYYYMMDD.HHMM,
# e.g. 20261118.1045 (the convention of the Kastl repo). It grows with every build, so App Store Connect
# accepts every new upload of the same version, and it is greater than the build 1 uploaded first.
# UTC keeps the order across daylight saving changes.
# DAYBOOK_BUILD_NUMBER overrides it (e.g. to rebuild an exact number); it must look like 20261118.1045 or 2.
set -euo pipefail

if [ -n "${DAYBOOK_BUILD_NUMBER:-}" ]; then
    if ! [[ "$DAYBOOK_BUILD_NUMBER" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
        echo "error: invalid DAYBOOK_BUILD_NUMBER '$DAYBOOK_BUILD_NUMBER' (up to three dot-separated integers)" >&2
        exit 1
    fi
    printf '%s\n' "$DAYBOOK_BUILD_NUMBER"
else
    date -u +%Y%m%d.%H%M
fi
