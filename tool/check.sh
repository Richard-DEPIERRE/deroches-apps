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

flutter pub get ${PUB_OFFLINE:+--offline}  # PUB_OFFLINE=1 in the agent sandbox (AGENTS.md)

if [ "$step" != test ]; then
  flutter analyze --no-pub
fi

if [ "$step" != analyze ]; then
  echo "== every app that saves data has a data-upgrade test"
  python3 tool/data_upgrade/check.py

  members=$(sed -n '/^workspace:/,/^[^ ]/s/^  - //p' pubspec.yaml)
  for member in $members; do
    if [ -d "$member/test" ]; then
      echo "== flutter test $member"
      (cd "$member" && flutter test --no-pub)
    fi
  done

  echo "== python tests in tool/"
  python3 -m unittest discover -s tool/release_watch -p '*_test.py'
  python3 -m unittest discover -s tool/release -p '*_test.py'
  python3 -m unittest discover -s tool/data_upgrade -p '*_test.py'
fi
