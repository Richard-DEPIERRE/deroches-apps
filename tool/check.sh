#!/usr/bin/env bash
# Runs the checks every PR needs (ADR 0001, section 14): analyze the whole
# workspace, then test every member that has tests. Uses the `flutter` on PATH
# (the version in .fvmrc).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

flutter pub get
flutter analyze

members=$(sed -n '/^workspace:/,/^[^ ]/s/^  - //p' pubspec.yaml)
for member in $members; do
  if [ -d "$member/test" ]; then
    echo "== flutter test $member"
    (cd "$member" && flutter test)
  fi
done

echo "== python tests in tool/"
python3 -m unittest discover -s tool/release_watch -p '*_test.py'
