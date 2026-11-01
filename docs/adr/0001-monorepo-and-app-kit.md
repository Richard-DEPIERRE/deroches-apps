# ADR 0001: One monorepo, and the app kit every studio app is built on

- Status: accepted
- Date: 2026-11-01
- Deciders: Mobile Tech Lead (review: Flutter Engineer 1, then Richard)
- Issue: DAPP-5

## Context

DeRoches Apps ships small, useful Flutter apps in a few weeks each: no server, free with paid extras, in French and
English from day one, each with its own website. Two Flutter Engineers build them; the Mobile Tech Lead reviews and
releases. To ship an app in about 3-4 weeks, everything that is the same from one app to the next (paywall, analytics,
crash reporting, languages, onboarding, settings, rating prompt, support and legal links, local data and its backup,
data-upgrade tests, screenshots, release builds) is built once, in a kit, and kept the same.

The studio rules (`apps/RULES.md` in `deroches-studio`) bind every choice below: no per-user server or LLM call
(anti-goal 1), no trick to make people pay (anti-goal 3), no secret in an app or the repo, store actions only through
the store wrapper, run by hand.

## Decision

### 1. One repository, one Dart workspace

```
deroches-apps/
  pubspec.yaml          Dart pub workspace root: every Flutter package and app below
  analysis_options.yaml one lint set for all (flutter_lints, plus the stricter rules listed there)
  .fvmrc                the Flutter version (3.44.9); everyone and CI use it
  packages/app_kit/     the app kit (a Flutter package)
  apps/<slug>/          one Flutter app per studio app; <slug> is the store wrapper's slug
  apps/kit_example/     the kit's sample app: wires every module, never shipped
  sites/                the site kit and every site (its stack is the site kit's own ADR, DAPP-6)
  docs/adr/             decisions (this file, then one per later decision)
  tool/                 check, screenshot and release-build scripts
```

- **Dart pub workspaces** (`workspace:` in the root `pubspec.yaml`, `resolution: workspace` in each member): one
  `flutter pub get` at the root, one lock file, one version of each dependency for every app. No melos: the few
  scripts we need live in `tool/`.
- The sites live in the same repository but are not Flutter (Flutter web is poor for search); the site kit's ADR
  picks their stack. Apps and sites share nothing at build time: an app links to its site's pages by URL.
- **Native code only where an app needs it.** Each app's `ios/` and `android/` folders are Flutter's, plus what a
  plugin needs. Native code shared by several apps becomes a plugin package under `packages/`, with its own ADR.

### 2. How an app uses the kit

An app adds only what is its own: its core feature and screens, an `AppConfig` (slug, names, bundle ID and Play
package, support address, legal URLs per language, the RevenueCat entitlement and plans, the public SDK keys), its
strings, its data schema and migrations, its fixtures and tests. It never copies or forks a kit module; a kit change is
its own issue. The kit's sample app shows the wiring and its placeholder screens never ship (anti-goal 2).

### 3. Architecture inside the kit and the apps

- **Plain Flutter state**: logic in plain Dart classes (`ChangeNotifier` or immutable state plus a controller),
  unit-tested test-first; widgets only present state (`ListenableBuilder`, `ValueListenableBuilder`). Services reach
  widgets through one `KitScope` (an `InheritedWidget`) built at start-up. No Riverpod, BLoC or GetX: fewer
  dependencies to keep current across many small apps, and every agent knows plain Flutter.
- Every service the kit wraps (purchases, analytics, crash reporting, rating, the file pickers) sits behind a small
  Dart interface with a fake in `package:app_kit/testing.dart`, so app tests never load an SDK.
- Navigation: apps use `go_router`; kit screens are plain widgets with callbacks, so they fit any router.

### 4. Paywall: RevenueCat, drawn by the kit, soft

- `purchases_flutter` (RevenueCat), one entitlement per app (`pro`), one offering (`default`) with the weekly,
  yearly and lifetime packages (`$rc_weekly`, `$rc_annual`, `$rc_lifetime`); each app's `AppConfig` says which of
  the three it sells. Richard creates the store products; the Mobile Tech Lead sets the offering up with the
  RevenueCat API. The app holds only RevenueCat's **public** SDK keys; the secret API key never reaches an app, the
  repo or CI.
- Users stay anonymous to RevenueCat (its own random app user id; we never log in a user). Purchase state is the
  entitlement; no receipt check of our own, no server. "Restore purchases" works through the store account.
- **The kit draws the paywall itself** rather than RevenueCat's remote paywall templates, so the honesty rules are
  code, with tests, in both languages, and no remote edit can remove them. Every paywall shows, before the button:
  each plan's price and period as the store gives them, when it renews and at what price, how to cancel (a plain line
  pointing to the store's subscription settings), "Restore purchases", the terms and privacy links, and a close button
  that works at once. No countdown, "only today", fake trial, guilt wording or delayed close button (anti-goal 3).
- **Soft paywall, enforced in code**: the kit refuses to show a paywall before onboarding is complete and the app has
  reported its first useful moment (`markFirstValue()`), so a hard paywall on day one can't be built by mistake. The
  core of every app stays free; where the paywall shows is the Product Lead's call through a validated epic.
- Prices come from the store through RevenueCat, never hard-coded.

### 5. Analytics: PostHog EU, anonymous

- `posthog_flutter`, EU host (`https://eu.i.posthog.com`), one studio project; `app_id` on every event separates the
  apps. The project key is public by design. Session replay, autocapture and person profiles are off; we never call
  `identify`, so events stay anonymous under PostHog's random install id. The project's "discard client IP" setting
  is on (a setup step for whoever creates the project).
- Events are named `[category].[action].[detail]` and go only through the kit's `Analytics` module, which checks the
  name against the kit's event list and adds the envelope: `app_id`, `app_version`, `platform`, `locale`,
  `days_since_install` (counted on the device from the install date the kit stores).
- Never a name, email, advertising id, store account id or anything the user typed or made, in any property.
- Settings carries a "share anonymous usage statistics" switch (on by default) and the privacy policy says what is
  sent. The design aims at the CNIL's consent exemption for audience measurement (first-party, anonymous, aggregate
  statistics only, no cross-app tracking, the right to object); that rule is checked again, with a date, at each
  app's first `TL-RELEASE-READY`, together with its store privacy answers.

### 6. Crash reporting

The tool (Sentry or Firebase Crashlytics) and the crash-free threshold are DAPP-12's ADR. The kit defines the
`CrashReporter` interface now (record an error with its stack, add a breadcrumb without personal data), wires
`FlutterError.onError` and `PlatformDispatcher.instance.onError` to it, and ships a no-op implementation until then.

### 7. French and English

Flutter's `gen-l10n` (`flutter_localizations`, `intl`), ARB files for the kit's own strings in the kit and for each
app in the app; English is the template file, French must be complete (a test fails on any untranslated message).
The language is the device's when it is French or English, English otherwise; the user can switch in settings and
the choice is saved. Dates, numbers and prices format by locale; plurals use ICU rules.

### 8. Local data: one versioned JSON document per app

- Data lives on the device, in the app's support directory, as a JSON document wrapped in an envelope:
  `{"format": "deroches.data", "schema": <int>, "app_id": "<slug>", "written_at": "<ISO 8601>", "data": {...}}`.
  The kit's own state (install date, onboarding done, language, analytics switch, rating prompt history) is a second
  document of the same kind. No `shared_preferences`: one mechanism, one set of tests.
- Writes are atomic (write a temporary file, flush, rename) and the previous good file is kept as `.bak`.
- **Migrations** are pure functions from schema `n` to `n + 1` on the `data` map, run in order on open. They write
  the new document before the old one is replaced; on failure the old file stays untouched and the user sees an
  error, never an empty app. A document from a newer schema than the app knows (a downgrade) is refused, not
  overwritten.
- **Data-upgrade tests**: each app keeps, under `test/data_upgrade/fixtures/`, a document written by each released
  version's own code, with made-up content. The kit's test helper loads every fixture, upgrades it to the current
  schema, decodes it with the app's current model, and checks every item is there and equal and the counts match. It
  also restores each old backup fixture. The first release creates the first fixture.
- Why not SQLite: our apps hold a few hundred to a few thousand small records; one JSON document is simpler to
  migrate, back up and test. An app that needs large data or queries picks SQLite (`drift`) in its own ADR and keeps
  the same envelope for backups and the same fixture rule.

### 9. Backup through the user's own iCloud or Google account

Two layers, no sign-in, no server, no per-app console step:

1. **Automatic**: the data documents sit where the platforms' own backups take them: the iCloud device backup on iOS
   (not excluded from backup) and Android Auto Backup to the user's Google account (`dataExtractionRules` and
   `fullBackupContent` include the data folder). Both restore on a new phone or a reinstall.
2. **By hand, in settings**: "Export a backup" writes the envelope (with `"kind": "backup"`) to a file and opens the
   system save dialog, where the user picks iCloud Drive or Google Drive (or anywhere else); "Restore a backup" opens
   the system file picker, reads and migrates the file with the same migrations, keeps a copy of the current data,
   and replaces it only after the whole file was read.

Rejected for now: CloudKit or an iCloud container (an iCloud capability and container per app, native code, more
console steps for Richard) and the Google Drive API (Google sign-in, an OAuth client and consent screen per app, a
new data type in the privacy answers). An app whose epic needs live sync between devices gets its own ADR.

### 10. Onboarding, settings, rating, support and legal links

- **Onboarding**: 2-4 pages the app provides, skippable from the first page, shown once; never a paywall.
- **Settings**: language, "Restore purchases", the backup export and restore, the analytics switch, "Rate the app",
  "Contact support", the legal links, and the app version.
- **Rating**: the platform's own prompt (`in_app_review`), only after a good moment the app reports, not before day 3,
  at most once every 120 days, never in exchange for anything and never gating a feature.
- **Support**: a `mailto:` link to the app's own support address, with the app name and version, the OS version and
  the language in the body; no install id or other identifier.
- **Legal**: legal notice, privacy policy and terms on the app's own site, in the user's language, from `AppConfig`.

### 11. Automated screenshots

Screenshots are widget tests (tag `screenshots`), so they run headless, in the sandbox and in CI, without a simulator.
Each app's screenshot tests render its key screens with made-up data, in French and English, at the store sizes (the
current required iPhone size and a Play phone size, checked with a date when the kit is built), with the app's bundled
fonts loaded, and write PNGs into the app's store folder (`apps/<slug>/store/ios/screenshots/`,
`apps/<slug>/store/android/`), which the store wrapper's `listing --metadata` reads. The same images serve the epic
posts on Discord. Apps are iPhone-only on iOS at first, so there are no iPad screenshots to make.

### 12. Release builds

`tool/release/` scripts build and package a release of one app: check the version and build number are above the
last released ones (recorded in `apps/<slug>/release.json`, updated in the release PR), run the checks, build the iOS
archive and the Android App Bundle, and put both under `build/release/<slug>/<version>/`. The Android template's debug
signing of release builds is removed, so a release `.aab` comes out unsigned. Signing and the iOS export are DAPP-14's
ADR and the store wrapper's job; the scripts produce the form that ADR settles. **A script never calls the store
wrapper**: the Mobile Tech Lead runs each wrapper command by hand (skill `apps-release`).

### 13. Dependencies and keys

- A new SDK (ads, attribution, another analytics tool, social login) needs its own ADR and a `PRIVACY` check; an ads
  SDK never comes in. Libraries named here are the kit's; apps add others only with a reason in their PR.
- Only public client keys (RevenueCat's public SDK keys, the PostHog project key, the crash reporter's client key)
  are in an app's `AppConfig`. A secret key in an app, the repo or a log is a hard stop at review.

### 14. Checks

`tool/check.sh` runs `flutter analyze` on the whole workspace and `flutter test` in every member. It is what an
engineer runs before review and what CI runs (DAPP-7).

## Consequences

- One kit change reaches every app at its next release; a kit change that breaks an app's tests is fixed in the same
  PR. Kit modules are reviewed by the Mobile Tech Lead like any code.
- Backup by hand depends on the user exporting; the automatic layer covers phone changes. Live sync waits for an app
  that needs it.
- The kit's event list may differ from the starting list in the `apps-kit-conventions` skill (backup events are
  `backup.complete.export` and `backup.complete.restore`: the app can't tell which cloud the user picked). The kit
  wins, and the skill is brought in line.
- The kit is built in child issues of DAPP-5 (one module each, about 1-2 days), riskiest first: local data and
  data-upgrade tests, then purchases and the paywall.
