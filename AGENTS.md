# deroches-apps: how to work in this repo

The DeRoches Apps monorepo: the app kit, the site kit, every app and every site. The studio rules and handbook
(`apps/RULES.md`, `apps/HANDBOOK.md` in `deroches-studio`) come first; the decisions here are in `docs/adr/`.
Read ADR 0001 before your first change.

## Layout
- `packages/app_kit/`: the app kit. A change to a kit module is its own issue.
- `apps/<slug>/`: one Flutter app per studio app (`<slug>` is the store wrapper's slug).
- `sites/`: the site kit and the sites (their own conventions, from the site kit's ADR).
- `docs/adr/`: one file per decision, numbered; add one for any library, vendor or kit choice.
- `tool/`: `check.sh`, then the screenshot and release-build scripts.

## Before review
- Flutter version: `.fvmrc` (3.44.9). Put that SDK's `bin` first on `PATH`.
- Run `tool/check.sh` (pub get, `flutter analyze` on the workspace, `flutter test` in every member).
- Inside the agent sandbox: set `HOME` to a folder under `$TMPDIR` (Dart's telemetry can't write `~/.dart-tool` and
  the analysis server dies), and use the shared `PUB_CACHE` at `/Volumes/Hermes/Studio/cache/pub-cache`; if pub can't
  reach pub.dev (a TLS error), `flutter pub get --offline` resolves from that cache.
- A change to what an app saves ships with its migration and its data-upgrade test in the same PR (ADR 0001,
  section 8).
- Every user-visible string in French and English, through the localization files.

## Never
- A server or LLM call per user; a secret key in an app, the repo or a log (public client keys only, in `AppConfig`).
- A paywall before onboarding and the app's first useful moment; any trick to make people pay.
- A store action from a script: release scripts build and package, the Mobile Tech Lead runs the store wrapper by
  hand.
- Moving CI to GitHub-hosted runners.
