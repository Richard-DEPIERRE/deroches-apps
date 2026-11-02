#!/usr/bin/env bash
# Runs the checks every PR needs (ADR 0001, section 14): analyze the whole
# workspace, then test every member that has tests. Uses the `flutter` on PATH
# (the version in .fvmrc).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

flutter pub get ${PUB_OFFLINE:+--offline}  # PUB_OFFLINE=1 in the agent sandbox (AGENTS.md)
flutter analyze --no-pub

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
