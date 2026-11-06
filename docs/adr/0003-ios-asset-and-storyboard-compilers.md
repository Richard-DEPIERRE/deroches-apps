# ADR 0003: Where the iOS archive's asset catalog and storyboards get compiled

- Status: accepted (the studio's choice; path 1 waits on Richard's pick on DAPP-48, path 2's wrapper change on his
  merge)
- Date: 2026-11-03
- Deciders: Mobile Tech Lead; Richard picks where CI runs (DAPP-48) and merges any shared-file change
- Issue: DAPP-51 (found on DAPP-50); amends ADR 0002's iOS archive step

## Context
ADR 0002 says the agents build the iOS archive in their sandbox once they may write Xcode's two `TemporaryItems`
folders (its item 4, merged in deroches-studio #162). That is true for compiling, linking, the Flutter script phase and
the archive step, but not for two of Apple's compilers that every iOS app runs:
- **`ibtool`** (storyboards: Flutter's `LaunchScreen.storyboard` and `Main.storyboard`) fails with
  `iOS 26.4 Platform Not Installed`.
- **`actool`** (the asset catalog, where the app icon must live) fails with
  `No available simulator runtimes for platform iphonesimulator. SimServiceContext supportedRuntimes=[]`. Run on its
  own (2026-11-03), it also needs to write scratch files straight into the user temp folder `T`, which the
  sandbox keeps closed. Its helper `ibtoold` ignores `TMPDIR`.

Both talk to **CoreSimulatorService** (`xcrun simctl list runtimes` fails the same way in the sandbox, retried
2026-11-03 after #162). With storyboards and asset catalogs excluded, the same archive succeeds in the sandbox
(DAPP-50, 2026-11-01, Xcode 26.4 17E192, Flutter 3.44.9). An App Store build can't drop the app icon.

**Why the service can't be reached** (DAPP-51):
- Richard ran both commands in a plain Terminal on the studio Mac on 2026-11-03. `simctl` lists iOS 26.4 (23E244)
  and `ibtool` compiles the storyboard with exit 0. The runtime is installed and the service works for his user.
- The agents run under Paperclip, a per-user LaunchAgent (`ing.deroches.paperclip`, no session limit), so they share
  Richard's GUI launchd session and the service is registered there. The "launchd job is not registered" wording
  in CoreSimulator's log is how it reports a lookup it was refused.
- The agents' Bash sandbox is Claude Code's Seatbelt profile (Claude Code 2.1.316). It starts `(deny default)` and
  allows `mach-lookup` only for a fixed list of system services, and CoreSimulator isn't on it. Claude Code's
  setting `sandbox.network.allowMachLookup` exists to add names to that list. Its own description names
  `com.apple.CoreSimulator.*` and the iOS Simulator, and warns: "Each entry lets sandboxed commands reach services
  outside the sandbox, and the sandbox does not confine what those services do for them."

So the cause is the agents' sandbox profile, not launchd and not Xcode.

## Decision
**The agents' sandbox stays closed to CoreSimulator.** The two compilers run somewhere they already work, on code
the studio has reviewed:

### Path 1: the release archive is built by CI on GitHub's macOS runner (if Richard picks A on DAPP-48)
- The CI work (DAPP-49) adds a `release-ios` job, run by hand (`workflow_dispatch`) on `main` only, with the app as
  an input. It runs on a pinned GitHub-hosted macOS image with a pinned Xcode, the one the App Store requires on the
  day (checked on Apple's upcoming-requirements page when the job is written). It builds the ad-hoc-signed archive
  with the kit's release script (ADR 0002: `CODE_SIGN_IDENTITY=-`, `CODE_SIGN_STYLE=Manual`) and uploads the
  `.xcarchive` as an artifact kept 1 day. `ibtool` and `actool` work there, since the runner is a normal macOS
  session.
- The Mobile Tech Lead downloads it into its checkout with `gh run download`, then runs
  `testflight --archive <path>` as ADR 0002 says. The wrapper's bundle ID and entitlements checks stay as they are.
- What it changes on the Mac: nothing. No sandbox, guard or wrapper change. The archive is built from reviewed code on
  `main`, on a throwaway VM that holds no key. That is better provenance than a sandboxed agent build, and the wrapper
  treats it the same way.
- Cost: $0 while `deroches-apps` is public (GitHub's Actions billing page, read 2026-11-03). If it went private, about
  $1.25 per release build (macOS at $0.062/min, ~20 min), counted against the $100 cap.
- Exposure: a public repo's artifacts can be downloaded by any signed-in GitHub user while they're kept. The archive
  holds the app binary and its symbols, nothing secret (no key ever goes in an app: rules, section 1), and the source
  is already public.

### Path 2: the wrapper compiles the icon catalog (if Richard picks B or C on DAPP-48)
- **The kit has no storyboards**, so `ibtool` never runs. `Info.plist` gets a `UILaunchScreen` dictionary instead of
  `UILaunchStoryboardName`, with no `UIMainStoryboardFile` or `UISceneStoryboardFile`, and the scene delegate creates
  the `FlutterViewController` window in code. `LaunchImage.imageset` goes with the launch storyboard.
- **The kit's archive leaves the catalog uncompiled.** The release script archives with
  `EXCLUDED_SOURCE_FILE_NAMES=*.xcassets` and copies `ios/Runner/Assets.xcassets`, which then holds only
  `AppIcon.appiconset`, into the archive as `AssetCatalog/Assets.xcassets`.
- **`testflight --archive` compiles it** in the wrapper (`ops/apps_store.py`, Richard's merge), on its private copy,
  before the export:
  1. It refuses a catalog holding anything other than `Contents.json` files and PNG files (signature checked, size
     capped) in `AppIcon.appiconset`. A missing catalog in an app with no `Assets.car` is refused too ("no app icon").
  2. It runs `/usr/bin/xcrun actool` with fixed flags (Xcode's own: `--app-icon AppIcon --compress-pngs --platform
     iphoneos`, the deployment target from the app's `MinimumOSVersion`, the device families from its
     `UIDeviceFamily`). The output goes into the copied `.app`.
  3. From actool's partial `Info.plist` it merges only `CFBundleIconName`, `CFBundleIcons` and `CFBundleIcons~ipad`
     into the app's `Info.plist`.
  4. It removes `AssetCatalog/` from the copy, re-seals the app ad hoc with
     `codesign --force --sign - --preserve-metadata=entitlements`, then exports and checks it as today.
- The wrapper runs outside the sandbox in the agents' launch session, where CoreSimulatorService answers. It runs
  only Apple's tool, on images and JSON. No code from the apps repo runs, as with the export. No guard change: the guard
  already takes `--archive`.
- The PR's test plan checks the two things nobody has run yet: `actool` from the wrapper, and an export of an archive
  re-sealed after the icon went in.

### Options rejected
- **`sandbox.network.allowMachLookup: ["com.apple.CoreSimulator.*"]` for the apps build roles.** It would fix the
  build with one line, but CoreSimulatorService runs as Richard, outside the sandbox, and does what it's asked. A
  sandboxed command (or a pub package's build script, or a CocoaPods hook) could boot a simulator and have it run a
  program (`simctl spawn`, or install and launch an app). Simulator processes run as Richard's user, outside the
  agents' file and network limits, so they could read the store keys and call the store APIs where the guard can't
  see. That is the escape ADR 0002 rejected for building outside the sandbox, through a side door, and the setting's
  own description says the sandbox doesn't confine it.
- **Opening `T` for writing** (actool's scratch files). ADR 0002 kept it closed, and it fixes nothing without
  CoreSimulator.
- **A launchd change.** The agents already share Richard's GUI session (above); launchd is not the cause.
- **Building outside the sandbox** stays rejected (ADR 0002).
- **Richard compiles the icon by hand** (a committed `Assets.car`). It works with no code, but it puts a Mac step on
  Richard for every icon change, and an icon he compiled can drift from the one in the repo.

## Consequences
- ADR 0002's iOS step "the archive is built in the sandbox" is replaced by this ADR: on path 1 the archive comes from
  CI, on path 2 from the sandbox with the icon compiled by the wrapper. Its item 4 (the `TemporaryItems` writes)
  stays useful: `xcodebuild` itself runs sandboxed.
- **Agents can't run iOS simulators**, so no `flutter run` on iOS and no iOS integration tests in the sandbox. Store
  screenshots are unaffected: they are widget tests and need no simulator (ADR 0001, section 11). On path 1, any iOS
  integration test runs in CI.
- Path 1 follow-ups: DAPP-49 gains the `release-ios` job, the kit's release script (DAPP-5) is written to run there,
  and `apps-release` section 2 says where the archive comes from. Path 2 follow-ups: a kit issue (no storyboards, the
  catalog copied into the archive) and the wrapper PR for Richard, then the same skill update.
- Whichever path, the first `testflight --archive` to Richard's internal TestFlight group is the end-to-end test, as in
  ADR 0002. A failure reaches no user.
