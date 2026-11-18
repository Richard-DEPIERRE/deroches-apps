#!/usr/bin/env bash
# Makes an app's store screenshots (ADR 0001, section 11): runs its tests tagged
# `screenshots`, which write <app-dir>/store/ios/screenshots/<locale>/ and
# <app-dir>/store/android/<locale>/images/phoneScreenshots/, the folders the
# store wrapper's `listing --metadata <app-dir>/store` reads, and the Play
# feature graphic (<app-dir>/store/android/<locale>/images/featureGraphic.png).
# Old shots are removed first, so a renamed screen leaves no stale image behind.
# A shipping app commits the result, so `git diff` shows what a re-run changed.
#   tool/screenshots.sh apps/kit_example
set -euo pipefail

app="${1:?usage: tool/screenshots.sh <app-dir>}"
cd "$app"

flutter pub get ${PUB_OFFLINE:+--offline}  # PUB_OFFLINE=1 in the agent sandbox (AGENTS.md)
rm -rf store/ios/screenshots store/android/*/images/phoneScreenshots store/android/*/images/featureGraphic.png build/screenshots-dark
flutter test --no-pub --tags screenshots
find store -name '*.png' | sort
