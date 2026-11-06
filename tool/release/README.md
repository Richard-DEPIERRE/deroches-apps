# Release builds

`tool/release/build.sh apps/<slug>` builds one app's release, unsigned, in the form ADR 0002 settles (ADR 0001,
section 12). It never signs for a store, exports or uploads: the store wrapper does, run by hand by the Mobile Tech
Lead. The release order, rollout and pause rules are in the `apps-release` skill.

## What the script does
1. Reads `version: X.Y.Z+N` from `apps/<slug>/pubspec.yaml` and refuses unless both the version and the build number
   are above the last released ones in `apps/<slug>/release.json` (`{"version": "X.Y.Z", "build": N}`;
   `0.0.0` and `0` before the first release).
2. Runs `tool/check.sh`.
3. Builds into `build/release/<slug>/<version>/`:
   - `<slug>.aab`: `flutter build appbundle --release`, unsigned (the kit's release build type has no signing config);
   - `<slug>.xcarchive`: `xcodebuild archive`, ad-hoc signed (no keychain identity, no profile);
   - `manifest.json`: slug, version, build number, commit, whether the tree was dirty, and a SHA-256 per artifact;
   - `android.log`, `ios.log`.
   A failed platform doesn't stop the other; the script ends non-zero and prints that platform's errors.

In the agent sandbox, run it with `HOME` under `$TMPDIR`, the shared `PUB_CACHE` and `PUB_OFFLINE=1` (`AGENTS.md`).

## Where it runs: CI, on main (ADR 0003, path 1)
The sandbox can't compile the iOS icon and storyboards (ADR 0003), so the release build comes from CI, on the merged
release commit:
1. `gh workflow run app-builds.yml --ref main -f release=<slug>` (the `release` job, on GitHub's pinned macOS image and
   Xcode). It refuses any ref but `main`.
2. `gh run list --workflow app-builds.yml --branch main --limit 3 --json databaseId,status,conclusion`, then once it
   is `success`, from the root of the checkout: `gh run download <run-id> --name release-<slug> --dir build/ci`.
   The artifact is kept 1 day.
3. `tar -xf build/ci/release-<slug>.tar -C build/release` gives `build/release/<slug>/<version>/`, as below. Check
   `manifest.json` (`commit` is the release commit, `dirty` is false).

## Then, by hand (Mobile Tech Lead)
From the root of the `deroches-apps` checkout, on the merged release commit (the manifest's `commit`, `dirty: false`):
1. iOS: `/usr/bin/python3 /Volumes/Hermes/Studio/repos/deroches-studio/ops/apps_store.py testflight --app <slug> --archive build/release/<slug>/<version>/<slug>.xcarchive`
   (the wrapper exports, cloud-signs and uploads).
2. Android: `/usr/bin/python3 /Volumes/Hermes/Studio/repos/deroches-studio/ops/apps_store.py play-upload --app <slug> --aab build/release/<slug>/<version>/<slug>.aab --track internal`
   (the wrapper signs with the upload key; it refuses a bundle that is already signed). An app's first Android build
   goes through `play-sign` instead, and Richard uploads it in Play Console.
3. In the release PR, set `apps/<slug>/release.json` to the version and build number just released.

`--archive` and `play-sign` came with ADR 0002's wrapper change (DAPP-36); they also need Richard's one-time steps
(ADR 0002, item 5).

## Known sandbox limits (2026-11-01, Xcode 26.4, Flutter 3.44.9)
- iOS: `ibtool` and `actool` (storyboards, asset catalog) need CoreSimulator's `simdiskimaged`, which the sandbox
  can't reach: `Assets.xcassets: error: No available simulator runtimes for platform iphonesimulator`.
- Android: the shared Flutter SDK has no Android engine artifacts, and Dart can't download them in the sandbox
  (`HandshakeException … CERTIFICATE_VERIFY_FAILED`, while `curl` reaches the same URL; most likely because Dart
  checks certificates through the keychain, which the sandbox hides).
