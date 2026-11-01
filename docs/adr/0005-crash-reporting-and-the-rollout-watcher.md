# ADR 0005: Crash reporting with Sentry (EU), and what the Release watch reads

- Status: proposed
- Date: 2026-11-01
- Deciders: Mobile Tech Lead (review: Flutter Engineer 1, then Richard)
- Issue: DAPP-12 (the kit module is DAPP-33)

## Context

ADR 0001 section 6 left two things open: the crash-reporting tool behind the kit's `CrashReporter` seam, and how the
`Release watch` (the Mobile Tech Lead's routine, every 4 hours) learns that an update's rollout has crossed the
crash-free threshold in the `apps-release` skill, so it pauses it with the store wrapper (`pause-ios --app <slug>`,
`play-halt --app <slug> --rollout <current fraction>`).

What binds the choice:
- No per-user running cost (rules, anti-goal 1): a free tier that drops data past its cap, never one that bills.
- The Release watch is an agent run with a shell: it needs the number **from a command**, within a few hours of the
  users producing it, with a read-only key. No agent drives a console in a browser.
- Anonymous by design, like analytics (ADR 0001 section 5): no user id, IP, device name or user text.
- Every console step is one more step on Richard's per-app checklist.

Facts checked on 2026-11-01:
- **Sentry**: the Developer plan is free, with 1 user, unlimited projects and 5,000 errors a month; Release Health is
  included (sentry.io/pricing). Events past the quota "will not be accepted" (docs.sentry.io/pricing/quotas): they are
  dropped, not billed, and the Developer plan has no pay-as-you-go spend to turn on. The sessions API
  (`GET /api/0/organizations/{org}/sessions/`) returns `crash_free_rate(user)`, `count_unique(user)` and
  `sum(session)` grouped by project and release, with `statsPeriod=24h`, at hourly resolution, for a token with the
  `org:read` scope. Organizations can live in the EU region (`de.sentry.io`), which answers from the agents' sandbox.
  The Flutter SDK sends no IP, user or device name unless `sendDefaultPii` is on
  (docs.sentry.io/platforms/dart/guides/flutter/data-management/data-collected).
- **Firebase Crashlytics**: free and uncapped, and crash-free users no longer need Google Analytics with current
  SDKs. But there is no public API for crash-free users: the documented way is the BigQuery export of Crashlytics and
  Firebase sessions data, a daily batch (realtime only with streaming export), queried with a Google Cloud service
  account (firebase.google.com/docs/crashlytics/bigquery-export, bigquery-run-queries). Each app also needs a Firebase
  app and its `google-services.json` / `GoogleService-Info.plist`.

## Decision

### 1. The tool: Sentry, one organization in the EU region, one project per app

- `sentry_flutter` in the kit, behind `CrashReporter` (DAPP-33). It also catches native iOS and Android crashes.
- One Sentry organization for the studio, created by Richard in the **EU region** on the free Developer plan (no
  payment method). One **project per app**, its slug the app's slug, created by Richard in his per-app steps (two
  minutes, added to the app-setup template), so each app's crash-free users is its own number and its DSN can carry
  its own rate limit. The project's "Prevent storing of IP addresses" setting is on.
- The DSN is a public client key (ADR 0001 section 13): it goes in the app's `AppConfig`, never a secret.

Rejected: **Crashlytics**, because the Release watch could only read it through a BigQuery export (a Google Cloud
project, a service-account key to hand an agent, and day-old numbers unless streaming is paid for), on top of a
Firebase app and config files per app. A rollout can move on Apple's phased release while a daily export catches up;
a 4-hourly watch needs a number from the last hours. **One Sentry project for all apps** (releases told apart by
name) was simpler for Richard but lets one app's error storm eat the others' share, and per-app alerting gets harder.

### 2. What the kit sends (DAPP-33 implements it)

- Release builds only; debug and profile builds send nothing (no DSN, no transport).
- Release name `<slug>@<version>+<build>` (for example `notes-de-frais@1.2.0+14`), environment `production`. The
  watcher filters on that name.
- `sendDefaultPii: false`; no `setUser`; a `beforeSend` that drops request data, server name and any user field the
  SDK fills; breadcrumbs only from the kit's own analytics event names (no navigation route arguments, no HTTP URLs,
  no console logs).
- Session tracking on (the default): crash-free users counts the SDK's random installation id, which identifies an
  install, not a person, and is never joined with anything else. Without it there is no crash-free *users* number.
- Errors sampled at 100%. The 5,000-a-month cap is shared by all apps; when an app nears it, its DSN gets a rate
  limit, not a lower sample rate (a sampled crash count would skew the threshold).
- The settings switch from ADR 0001 section 5 covers both: "Share anonymous usage statistics and crash reports",
  on by default. Off means no crash reports and no sessions from that install.
- No debug-symbol upload for now: release builds are not obfuscated, so Dart stack traces keep their names. Native
  symbol upload needs a CI token with `project:releases`; it gets its own issue when a native crash needs it.

Privacy answers it adds (A3 of `templates/app-setup-for-richard.md`, checked again at each app's first
`TL-RELEASE-READY`): Apple, **Crash Data** and **Other Diagnostic Data**: collected, not linked to the user, not used
for tracking, purpose App Functionality. Google Play data safety, **App info and performance: Crash logs,
Diagnostics**: collected, not shared (Sentry is our processor), encrypted in transit, optional (the switch).

### 3. The rollout watcher: what the Release watch reads

`tool/release_watch/crash_free.py` (Python standard library only, so it runs with `/usr/bin/python3` and no install):

```
/usr/bin/python3 /Volumes/Hermes/Studio/repos/deroches-apps/tool/release_watch/crash_free.py --app <slug>
```

- It asks Sentry's sessions API for the app's project over the last 24 hours, grouped by release, and prints one JSON
  line per release: `release`, `users`, `sessions`, `crash_free_users`, `crashed_users`, and the window. With
  `--issues <release>` it lists that release's issues seen in the last 24 hours (title, users hit, first seen), for
  the rules that apply below the minimum sample (a crash on launch, one crash hitting three users, a crash in the
  purchase, restore or data-upgrade flow).
- It reports observations only (handbook section 3); the Mobile Tech Lead applies the threshold in `apps-release`
  and pauses. It writes nothing and never calls the store wrapper.
- Exit 0 with data; exit 1 when Sentry can't be read (no token, network, API error), with the reason, so a missing
  number is `MISSING`, never a zero and never a green.
- Its settings (API host and organization slug, not secret) live in `tool/release_watch/sentry.json`. The token comes
  from `SENTRY_AUTH_TOKEN`: a Sentry user auth token with the read scopes `org:read`, `project:read` and
  `event:read` only, added by Richard to the Mobile Tech Lead's secrets in `apps/agents.json` (rules section 1).
  The script never prints it.

### 4. The threshold

The `apps-release` skill already sets it, and this ADR keeps it: **pause when crash-free users on the new version,
over the last 24 hours, fall below 99.0% with at least 100 users on it**; below 100 users the rate is
`NOT ASSESSED (n=<count>)` and the skill's small-sample rules apply. 99.0% sits just inside Google Play's bad-behaviour
line (1.09% of daily users with a user-perceived crash), the point where Play starts hiding an app. The Studio
Rulebook change that names Sentry and this command in `apps-release`, and says what to do when the number is
`MISSING`, is a child of DAPP-12.

## Consequences

- Richard: one account (Sentry, EU, free), one read-only token into `apps/agents.json`, and a Sentry project per app
  in his per-app steps. All three are `needs-richard` work under DAPP-12; until the token is merged the watcher exits
  1 and every number is `MISSING`.
- The 5,000 errors a month is shared by all apps. A crash storm past it drops reports (no bill), which is also when a
  rollout should already be paused. The Studio Director's Friday digest can show usage once we watch it.
- Sentry's quotas page does not say whether sessions count against a quota; if they ever do, crash-free users would
  stop at the cap. Checked again at the first app's `TL-RELEASE-READY`.
- An app that changes crash tool, or adds performance tracing or session replay, needs a new ADR and a `PRIVACY`
  check; replay never comes in (it would capture what users type).
