"""Tests for crash_free.py, with a fake Sentry: python3 -m unittest discover -s tool/release_watch -p '*_test.py'"""

import io
import json
import os
import tempfile
import unittest
import urllib.error
import urllib.parse

import crash_free

TOKEN = "test-token-not-real"


class FakeSentry:
    """Answers like Sentry and records each request."""

    def __init__(self, body=None, error=None):
        self.body, self.error, self.requests = body, error, []

    def __call__(self, request, timeout):
        self.requests.append(request)
        if self.error:
            raise self.error
        return io.BytesIO(json.dumps(self.body).encode())

    def params(self, i=0):
        return urllib.parse.parse_qs(urllib.parse.urlsplit(self.requests[i].full_url).query)


SESSIONS = {
    "groups": [
        {"by": {"release": "notes@1.2.0+14"},
         "totals": {"count_unique(user)": 400, "crash_free_rate(user)": 0.985, "sum(session)": 1900}},
        {"by": {"release": "notes@1.1.0+12"},
         "totals": {"count_unique(user)": 50, "crash_free_rate(user)": None, "sum(session)": 0}},
    ]
}


class CrashFreeTest(unittest.TestCase):
    def setUp(self):
        folder = tempfile.mkdtemp()
        self.settings = os.path.join(folder, "sentry.json")
        with open(self.settings, "w") as f:
            json.dump({"api": "https://de.sentry.io/api/0", "organization": "studio"}, f)

    def run_main(self, argv, sentry, environ=None):
        out, err = io.StringIO(), io.StringIO()
        environ = {"SENTRY_AUTH_TOKEN": TOKEN} if environ is None else environ
        stderr, crash_free.sys.stderr = crash_free.sys.stderr, err
        try:
            code = crash_free.main(argv, opener=sentry, environ=environ, settings_path=self.settings, out=out)
        finally:
            crash_free.sys.stderr = stderr
        return code, [json.loads(line) for line in out.getvalue().splitlines()], err.getvalue()

    def test_reads_crash_free_users_per_release_over_24_hours(self):
        sentry = FakeSentry(SESSIONS)
        code, rows, _ = self.run_main(["--app", "notes"], sentry)
        self.assertEqual(code, 0)
        self.assertEqual(
            rows[0],
            {"app": "notes", "release": "notes@1.2.0+14", "window": "24h", "users": 400, "sessions": 1900,
             "crash_free_users": 98.5, "crashed_users": 6},
        )
        request = sentry.requests[0]
        self.assertTrue(request.full_url.startswith("https://de.sentry.io/api/0/organizations/studio/sessions/?"))
        self.assertEqual(request.get_header("Authorization"), f"Bearer {TOKEN}")
        params = sentry.params()
        self.assertEqual(params["project"], ["notes"])
        self.assertEqual(params["statsPeriod"], ["24h"])
        self.assertEqual(params["groupBy"], ["release"])
        self.assertIn("crash_free_rate(user)", params["field"])

    def test_a_release_without_sessions_is_missing_not_crash_free(self):
        _, rows, _ = self.run_main(["--app", "notes"], FakeSentry(SESSIONS))
        self.assertIsNone(rows[1]["crash_free_users"])
        self.assertIsNone(rows[1]["crashed_users"])

    def test_lists_a_releases_issues(self):
        sentry = FakeSentry([{"title": "StateError: bad", "culprit": "main.dart", "userCount": 3, "count": "7",
                              "isUnhandled": True, "firstSeen": "2026-11-01T10:00:00Z", "permalink": "https://x"}])
        code, rows, _ = self.run_main(["--app", "notes", "--issues", "notes@1.2.0+14"], sentry)
        self.assertEqual(code, 0)
        self.assertEqual(rows[0]["users"], 3)
        self.assertTrue(rows[0]["unhandled"])
        self.assertIn("/organizations/studio/issues/?", sentry.requests[0].full_url)
        self.assertEqual(sentry.params()["query"], ['release:"notes@1.2.0+14"'])

    def test_no_token_is_missing_and_sends_nothing(self):
        sentry = FakeSentry(SESSIONS)
        code, rows, err = self.run_main(["--app", "notes"], sentry, environ={})
        self.assertEqual((code, rows, sentry.requests), (1, [], []))
        self.assertIn("MISSING: SENTRY_AUTH_TOKEN", err)

    def test_an_http_error_is_missing_and_never_prints_the_token(self):
        error = urllib.error.HTTPError("https://de.sentry.io/x", 403, "Forbidden", {}, None)
        code, rows, err = self.run_main(["--app", "notes"], FakeSentry(error=error))
        self.assertEqual((code, rows), (1, []))
        self.assertIn("HTTP 403", err)
        self.assertNotIn(TOKEN, err)

    def test_a_network_error_is_missing(self):
        code, _, err = self.run_main(["--app", "notes"], FakeSentry(error=urllib.error.URLError("down")))
        self.assertEqual(code, 1)
        self.assertIn("MISSING: Sentry could not be read", err)

    def test_refuses_a_slug_that_could_change_the_query(self):
        with self.assertRaises(SystemExit) as raised:
            self.run_main(["--app", "notes&project=-1"], FakeSentry(SESSIONS))
        self.assertEqual(raised.exception.code, 2)

    def test_the_committed_settings_point_at_the_eu_region(self):
        api, org = crash_free.load_settings()
        self.assertEqual(api, "https://de.sentry.io/api/0")
        self.assertTrue(org)


if __name__ == "__main__":
    unittest.main()
