#!/usr/bin/env python3
"""Crash-free users per release of one app, from Sentry (ADR 0005, section 3).

What the Release watch reads before it decides whether to pause a rollout:

    /usr/bin/python3 tool/release_watch/crash_free.py --app <slug>
    /usr/bin/python3 tool/release_watch/crash_free.py --app <slug> --issues <slug>@<version>+<build>

Prints one JSON line per release (or per issue with --issues). Observations only: the threshold and the
pause are the `apps-release` skill's. Exit 0 with data, 1 when Sentry can't be read (the number is MISSING),
2 on bad arguments. The token comes from SENTRY_AUTH_TOKEN and is never printed. Standard library only.
"""

import argparse
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

WINDOW = "24h"
SETTINGS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sentry.json")
SLUG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


class Missing(Exception):
    """Sentry could not be read; the reason is safe to print."""


def load_settings(path=SETTINGS):
    with open(path, encoding="utf-8") as f:
        settings = json.load(f)
    api, org = settings.get("api", ""), settings.get("organization", "")
    if not api.startswith("https://") or not SLUG.match(org):
        raise Missing(f"{path}: 'api' must be an https URL and 'organization' a Sentry org slug")
    return api.rstrip("/"), org


def get_json(url, token, opener=urllib.request.urlopen):
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        with opener(request, timeout=30) as response:
            return json.load(response)
    except urllib.error.HTTPError as e:
        raise Missing(f"Sentry answered HTTP {e.code} for {url.split('?')[0]}") from None
    except (urllib.error.URLError, OSError, ValueError) as e:
        raise Missing(f"Sentry could not be read ({type(e).__name__})") from None


def releases(api, org, app, token, opener=urllib.request.urlopen):
    """One dict per release of `app` seen in the window, most users first."""
    query = urllib.parse.urlencode(
        [
            ("project", app),
            ("field", "count_unique(user)"),
            ("field", "crash_free_rate(user)"),
            ("field", "sum(session)"),
            ("groupBy", "release"),
            ("statsPeriod", WINDOW),
            ("interval", "1h"),
            ("includeSeries", "0"),
            ("orderBy", "-count_unique(user)"),
        ]
    )
    body = get_json(f"{api}/organizations/{org}/sessions/?{query}", token, opener)
    rows = []
    for group in body.get("groups", []):
        totals = group.get("totals", {})
        users = totals.get("count_unique(user)") or 0
        rate = totals.get("crash_free_rate(user)")
        rows.append(
            {
                "app": app,
                "release": group.get("by", {}).get("release"),
                "window": WINDOW,
                "users": users,
                "sessions": totals.get("sum(session)") or 0,
                # None (no sessions) stays None: a gap is missing data, not 100%.
                "crash_free_users": None if rate is None else round(rate * 100, 2),
                "crashed_users": None if rate is None else round(users * (1 - rate)),
            }
        )
    return rows


def issues(api, org, app, release, token, opener=urllib.request.urlopen):
    """The release's issues seen in the window, most users hit first."""
    query = urllib.parse.urlencode(
        [
            ("project", app),
            ("query", f'release:"{release}"'),
            ("statsPeriod", WINDOW),
            ("sort", "user"),
            ("limit", "25"),
        ]
    )
    body = get_json(f"{api}/organizations/{org}/issues/?{query}", token, opener)
    return [
        {
            "app": app,
            "release": release,
            "title": issue.get("title"),
            "culprit": issue.get("culprit"),
            "users": issue.get("userCount"),
            "events": issue.get("count"),
            "unhandled": issue.get("isUnhandled"),
            "first_seen": issue.get("firstSeen"),
            "link": issue.get("permalink"),
        }
        for issue in body
    ]


def main(argv=None, opener=urllib.request.urlopen, environ=os.environ, settings_path=SETTINGS, out=sys.stdout):
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--app", required=True, help="the app's slug (its Sentry project slug)")
    parser.add_argument("--issues", metavar="RELEASE", help="list this release's issues instead")
    args = parser.parse_args(argv)
    if not SLUG.match(args.app):
        parser.error(f"--app {args.app!r} is not a slug")
    try:
        api, org = load_settings(settings_path)
        token = environ.get("SENTRY_AUTH_TOKEN", "")
        if not token:
            raise Missing("SENTRY_AUTH_TOKEN is not set (Richard adds it to apps/agents.json)")
        if args.issues:
            rows = issues(api, org, args.app, args.issues, token, opener)
        else:
            rows = releases(api, org, args.app, token, opener)
    except Missing as e:
        print(f"MISSING: {e}", file=sys.stderr)
        return 1
    for row in rows:
        print(json.dumps(row, ensure_ascii=False), file=out)
    if not rows:
        print(f"no {'issues' if args.issues else 'sessions'} for {args.app} in the last {WINDOW}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
