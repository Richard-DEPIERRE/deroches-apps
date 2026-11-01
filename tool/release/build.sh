#!/usr/bin/env bash
# Builds one app's release, unsigned, in the form ADR 0002 settles (ADR 0001, section 12):
#   tool/release/build.sh apps/<slug>
# Output: build/release/<slug>/<version>/ with <slug>.aab (unsigned), <slug>.xcarchive (ad-hoc signed),
# manifest.json (versions, commit, checksums) and one log per platform.
# It never signs for a store, exports or uploads: the Mobile Tech Lead runs the store wrapper by hand (README.md).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
[ $# -eq 1 ] && [ -f "$1/pubspec.yaml" ] || { echo "usage: tool/release/build.sh apps/<slug>" >&2; exit 2; }
app="$(cd "$1" && pwd)"
slug="$(basename "$app")"

read -r version build < <(python3 "$root/tool/release/release.py" check "$app")
echo "== $slug $version+$build"

"$root/tool/check.sh"

out="$root/build/release/$slug/$version"
rm -rf "$out"
mkdir -p "$out"
failed=()

echo "== Android App Bundle (unsigned)"
if (cd "$app" && flutter build appbundle --release --no-pub) >"$out/android.log" 2>&1; then
  cp "$app/build/app/outputs/bundle/release/app-release.aab" "$out/$slug.aab"
else
  failed+=(android)
fi

echo "== iOS archive (ad-hoc signed, for the wrapper's export)"
# Ad-hoc signing needs no keychain identity or profile (ADR 0002). HOME is passed as a build setting because
# xcodebuild resets it for script phases, and Flutter's phase must use the caller's HOME (in the sandbox, under TMPDIR).
if (cd "$app" && flutter build ios --release --config-only --no-codesign --no-pub &&
    xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release \
      -destination 'generic/platform=iOS' -archivePath "$out/$slug.xcarchive" \
      -derivedDataPath "$root/build/release/$slug/DerivedData" \
      CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual AD_HOC_CODE_SIGNING_ALLOWED=YES PROVISIONING_PROFILE_REQUIRED=NO \
      "HOME=$HOME" archive) \
    >"$out/ios.log" 2>&1; then
  :
else
  rm -rf "$out/$slug.xcarchive"
  failed+=(ios)
fi

commit="$(git -C "$root" rev-parse HEAD)"
dirty=0
[ -z "$(git -C "$root" status --porcelain)" ] || dirty=1
python3 "$root/tool/release/release.py" manifest "$out" "$slug" "$version" "$build" "$commit" "$dirty"

for platform in "${failed[@]+"${failed[@]}"}"; do
  echo "== $platform build failed; errors from $out/$platform.log:" >&2
  # Profile-loading lines are noise: the sandbox hides provisioning profiles and the build doesn't use them.
  grep -E "error:|Exception|Failed to|FAILED|ERROR :" "$out/$platform.log" | grep -v DVTProvisioningProfileManager | tail -n 15 >&2
done
echo "== $out"
ls -1 "$out"
[ ${#failed[@]} -eq 0 ]
