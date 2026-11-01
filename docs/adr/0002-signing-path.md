# ADR 0002: Signing path for release builds

- Status: accepted (the studio's choice; the wrapper, guard and sandbox changes it needs are Richard's to merge)
- Date: 2026-11-01
- Deciders: Mobile Tech Lead; Richard decides and merges the shared-file changes
- Issue: DAPP-14

## Context
Today no agent can produce a signed release build for either store (`docs/APPS_ROLLOUT.md` in the Studio clone,
"Decisions for Richard"; skill `apps-release`, section 2):
- builds run inside the agents' sandbox, which hides the keychain, so nothing there can sign with a distribution
  identity;
- the guard blocks `xcodebuild -exportArchive` and `flutter build ipa --export-options-plist` for every role;
- the App Store Connect key is the store wrapper's alone (`ops/apps_store.py`), and the wrapper has no signing step;
- Android's upload key has no home: agents can't read `*.jks`, `*.keystore` or `*.p12`, and nothing keeps one.

Two more facts, found while writing this ADR:
- **`xcodebuild` can't run in the sandbox at all, even unsigned.** Xcode and SwiftPM save files atomically through
  a per-volume temporary folder (`/Volumes/Hermes/.TemporaryItems`) and the user's temporary folder
  (`/var/folders/…/T`, from `getconf DARWIN_USER_TEMP_DIR`), and the sandbox lets the apps roles write to neither.
  Tried on 2026-11-01 with Xcode 26.4 and Flutter 3.44.9, on a throwaway app:
  `xcodebuild … archive CODE_SIGNING_ALLOWED=NO` with a writable `-derivedDataPath` fails with
  `Couldn't create workspace arena folder …: Unable to write to info file`, and `flutter build ipa --no-codesign`
  fails on its default DerivedData folder. An earlier agency build on this Mac hit the same limit. So the first iOS
  step, the archive, is blocked before signing even comes up.
- **Cloud signing through an API key needs an Admin key.** `xcodebuild -exportArchive -allowProvisioningUpdates`
  with `-authenticationKeyPath`, `-authenticationKeyID` and `-authenticationKeyIssuerID` signs with Apple's
  cloud-managed distribution certificate. Apple lets Admins and the Account Holder use it by default (WWDC21,
  "Distribute apps in Xcode with cloud signing"; Apple's "Cloud-managed certificates" help page, read 2026-11-01).
  Projects that tried an App Manager or Developer API key report Xcode's "Cloud signing permission error"
  ("You haven't been given access to cloud-managed distribution certificates"). The examples are
  jthingelstad/changelog-ios#17 (2026-10) and actualbudget/actual#9324. Apple documents no way to give an API key the
  per-user "Access to Cloud Managed Distribution Certificate" permission. The key Richard saved in rollout step 4 is
  an App Manager key, so it can upload but can't cloud-sign.

Constraints that hold whatever we pick (rules, section 1): no agent reads the keychain or a signing key; store keys
are read only by the wrapper; nothing is built outside the sandbox and no signing material is copied to get there.

## Decision
**The agents build unsigned in the sandbox. The store wrapper signs, and only the wrapper.** It signs as one more step
of the upload actions the Mobile Tech Lead already runs, so a signed file never exists anywhere an agent can
change it. Signing never runs the apps repo's own code: no Gradle, Xcode run-script phase, CocoaPods hook or Flutter
plugin runs outside the sandbox.

### Android
- The app kit's release build type has **no signing config**. `flutter build appbundle --release` writes an unsigned
  `app-release.aab` (the Flutter template's fallback to the debug key is removed in the kit).
- `play-upload --aab <path>` signs the copy it already takes with **one studio upload key**. The key lives in the store-keys
  folder as `/Volumes/Hermes/Studio/secrets/apps-store/android_upload.p12` (PKCS12, alias `upload`), with its
  password in `android_upload.pass` beside it. Richard generates it once with `keytool` and keeps a copy in his
  password manager. The wrapper:
  1. refuses a bundle that is already signed (any `META-INF/*.SF`, `*.RSA`, `*.DSA` or `*.EC` entry), so a debug-signed
     or foreign-signed bundle never reaches Play;
  2. signs with `jarsigner` from a fixed JDK path (Homebrew's `openjdk@17`), `-sigalg SHA256withRSA -digestalg SHA-256`,
     the password through `-storepass:file`, with a scrubbed environment;
  3. checks the signature with `jarsigner -verify`, then uploads as today.
  `jarsigner` is what Google documents for app bundles; `apksigner` doesn't sign them.
- `play-sign --aab <path>` (new, Mobile Tech Lead): the same signing, then the signed bundle goes to
  `/Volumes/Hermes/Studio/secrets/apps-store/out/<slug>-<UTC time>.aab`, which Richard can read and agents can't.
  It exists for **the first Android build of each app**: Google Play takes an app's first bundle only through Play
  Console, by Richard's hand (his per-app steps). Play App Signing then keeps Google's app signing key, and this
  key is only the upload key for every studio app. Losing it is recoverable (an upload key reset in Play Console).
  A leaked copy alone can't publish: an upload also needs the Play service account.

### iOS
- **The archive is built in the sandbox**, once the apps build roles may write to the two temporary folders Xcode
  needs (below). The kit's release script runs `xcodebuild archive` with ad-hoc signing
  (`CODE_SIGN_IDENTITY=-`, `CODE_SIGN_STYLE=Manual`, `AD_HOC_CODE_SIGNING_ALLOWED=YES`, an explicit
  `-derivedDataPath` under the checkout), which needs no keychain identity and keeps the app's entitlements (iCloud
  backup, in-app purchase) in the archive for the export to carry over.
- `testflight --archive <path to .xcarchive>` (new option, beside `--ipa`): the wrapper copies the archive privately,
  then runs `/usr/bin/xcodebuild -exportArchive` with an export-options plist it writes itself:
  `method app-store-connect`, `signingStyle automatic`, the team ID from Richard's allow-list, `uploadSymbols true`.
  It adds `-allowProvisioningUpdates` and **a separate Admin API key used only for this step**
  (`asc_signing_key.json`, same format as `asc_api_key.json`). Xcode's cloud signing signs it: no keychain
  identity, no certificate file, and the App Store profile is made or refreshed on the way. The wrapper then checks
  the signed app's bundle ID against the allow-list and its entitlements against the archive's, refuses on a
  mismatch, and uploads with the existing App Manager key as `testflight --ipa` does today.
- Exporting only re-signs and packages what the archive holds. It runs none of the repo's build scripts, so the
  part of the iOS build that runs outside the sandbox is Apple's own tool on a copy the agent can no longer touch.

### What changes outside this repo (Richard's merges)
1. `ops/apps_store.py`: signing in `play-upload`, the `play-sign` action, `testflight --archive`, the new key files,
   an output folder for `play-sign`, larger tree limits for an `.xcarchive`, and tests in `tests/test_apps_store.py`.
2. `guard/guard.py`: `--archive` as a path option of `testflight`, `play-sign` for the Mobile Tech Lead only, the same
   tree limit; the export shapes stay blocked for every role.
3. `ops/apps_allow.py` and `studio.json`: the Apple team ID, once, in the `apps` section (an export needs it and the
   keys don't carry it).
4. `claude-home/roles/apps_tech_lead.json`, `apps_flutter_engineer_1.json`, `apps_flutter_engineer_2.json`:
   `sandbox.filesystem.allowWrite` gains `/Volumes/Hermes/.TemporaryItems` and the user's `/var/folders/…/T` and
   `/var/folders/…/C`, so `xcodebuild archive` runs sandboxed. Reads stay as they are: no keychain, no store-keys
   folder.
5. Richard's one-time steps: the upload key, the Admin signing key, the team ID, and enabling iCloud (with the
   app's container) and In-App Purchase on each app's bundle ID in his per-app checklist, so the exported profile
   carries the entitlements.

The proposal, its pull request and these steps are on the `needs-richard` child issue of DAPP-14.

### Options rejected
- **Building outside the sandbox** (`xcodebuild`, `flutter build` and `fvm flutter build` in the apps roles'
  `excludedCommands`). The build would sign with the keychain and run the repo's Gradle, Xcode run-script phases,
  CocoaPods hooks and Flutter plugins as Richard, outside every file and network limit. A script or dependency an
  agent adds could read the store keys and call the store APIs where the guard can't see it. This is the exception
  the rules forbid.
- **The wrapper archives too.** It would remove the sandbox change (item 4) but run the repo's build scripts
  outside the sandbox inside the wrapper, which is the same exposure with a narrower door.
- **Manual iOS signing** (a distribution certificate `.p12` and per-app profiles in the store-keys folder, imported
  into a temporary keychain the wrapper makes and deletes). It works with the App Manager key, but adds a private key
  file on disk, a yearly certificate renewal and per-app profiles for Richard, and keychain handling in the wrapper.
  Kept as the fallback if Richard doesn't want an Admin key on this Mac.
- **One key for everything** (replacing the App Manager key with an Admin key). It is simpler, but it gives Admin
  power to every wrapper action. A separate signing key is read by one code path and can be revoked alone.
- **A key per app for Android.** That adds a step to Richard's per-app setup and doesn't make the studio safer: an
  upload key can't publish without the Play service account, and a lost one can be reset.

## Consequences
- Once Richard has merged items 1–4 and done item 5, the release order in `apps-release` stays as it is. The
  first step becomes `testflight --archive <path>`, and Play bundles are signed inside `play-upload`. Until then the
  first TestFlight build and every app's first `.aab` wait, as `apps-release` already says.
- The Admin signing key adds to the exposure Richard is already deciding on in "Decisions for Richard". Programs that
  run outside the sandbox (the agency's unsandboxed builds) run as Richard, so they could read the store-keys folder,
  and an Admin key can also manage users and certificates on his account. This ADR recommends he settles that
  decision (another macOS user for the wrapper and keys, or the agency's builds sandboxed) before he saves the Admin
  key.
- The sandbox change lets the apps build roles write to two of the user's temporary folders that other programs also
  use. It grants no read of anything new. If Xcode still fails sandboxed after it, the Mobile Tech Lead raises it
  with the exact error (`apps-release`, section 2), and building outside the sandbox stays rejected.
- The first export is the test of the whole iOS path: the ad-hoc archive, cloud signing with the Admin key, and the
  entitlements check. The first upload goes to Richard's internal TestFlight group, so a failure reaches no user.
  If the ad-hoc archive doesn't keep the entitlements through the export, the fallback is manual signing (above).
- Kit work that follows (DAPP-5's release scripts): an unsigned Android release build, the iOS archive command above
  with its DerivedData folder, and both builds' outputs at fixed paths in the checkout for the wrapper to take.
- `apps-release` section 2 and the per-app checklist (`templates/app-setup-for-richard.md`) are updated once Richard
  has merged the change, not before.
