#!/usr/bin/env bash
# The site kit's checks (CI's site job): install, lint, test, then build the kit's
# test site and every app's site. Uses the `node` and `npm` on PATH (Node 22+).
# Exits 0 with a note while the repo has no site kit yet (sites/package.json).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"

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
