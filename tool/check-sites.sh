#!/usr/bin/env bash
# CI's site job. The report page (reports/, ADR 0004): install, lint, test (its
# build reads Paperclip, so it is only built when published). The site kit
# (sites/): install, lint, test, then build the kit's test site and every app's
# site. Uses the `node` and `npm` on PATH (Node 22+). A part missing from this
# tree is skipped with a note.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

if [ -f reports/package.json ]; then
  echo "== reports: lint and test"
  (cd reports && npm ci && npm run lint && npm test)
else
  echo "No report page in this tree (reports/package.json is missing)."
fi

if [ ! -f sites/package.json ]; then
  echo "No site kit in this tree (sites/package.json is missing): nothing to build."
  exit 0
fi

cd sites
npm ci
npm run lint
npm test

out="$(mktemp -d)"
trap 'rm -rf "$out"' EXIT

echo "== build kit/test/fixture"
node kit/build.mjs kit/test/fixture "$out/fixture"

for config in */site.json; do
  [ -e "$config" ] || continue
  site="${config%/site.json}"
  echo "== build $site"
  node kit/build.mjs "$site" "$out/$site"
done
