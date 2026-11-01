#!/usr/bin/env bash
# Runs the checks every PR needs (ADR 0001, section 14): analyze the whole
# workspace, then test every member that has tests. Uses the `flutter` on PATH
# (the version in .fvmrc).
#
#   tool/check.sh            pub get, analyze, then test (what you run before review)
#   tool/check.sh analyze    pub get, analyze only (CI's lint job)
#   tool/check.sh test       pub get, test only (CI's test job)
set -euo pipefail

step="${1:-all}"
case "$step" in
  all | analyze | test) ;;
  *)
    echo "usage: tool/check.sh [all|analyze|test]" >&2
    exit 2
    ;;
esac

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

flutter pub get

if [ "$step" != test ]; then
  flutter analyze
fi

if [ "$step" != analyze ]; then
  members=$(sed -n '/^workspace:/,/^[^ ]/s/^  - //p' pubspec.yaml)
  for member in $members; do
    if [ -d "$member/test" ]; then
      echo "== flutter test $member"
      (cd "$member" && flutter test)
    fi
  done
fi
