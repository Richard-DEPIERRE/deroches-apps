"""Tests for release.py: python3 -m unittest discover -s tool/release -p '*_test.py'"""

import hashlib
import json
import os
import tempfile
import unittest

import release


def app_dir(pubspec_version, released):
    d = tempfile.mkdtemp()
    with open(os.path.join(d, "pubspec.yaml"), "w") as f:
        f.write(f"name: notes\npublish_to: none\nversion: {pubspec_version}\n\nenvironment:\n  sdk: ^3.12.0\n")
    with open(os.path.join(d, "release.json"), "w") as f:
        json.dump(released, f)
    return d


class VersionCheckTest(unittest.TestCase):
    def test_accepts_version_and_build_both_above(self):
        d = app_dir("1.3.0+15", {"version": "1.2.0", "build": 14})
        self.assertEqual(release.check(d), ("1.3.0", 15))

    def test_refuses_build_number_not_above_last(self):
        for build in ("14", "13"):
            d = app_dir(f"1.3.0+{build}", {"version": "1.2.0", "build": 14})
            with self.assertRaisesRegex(release.Refused, "build number"):
                release.check(d)

    def test_refuses_version_not_above_last(self):
        for version in ("1.2.0", "1.1.9", "0.9.10"):
            d = app_dir(f"{version}+15", {"version": "1.2.0", "build": 14})
            with self.assertRaisesRegex(release.Refused, "version"):
                release.check(d)

    def test_compares_versions_as_numbers(self):
        d = app_dir("1.10.0+15", {"version": "1.9.0", "build": 14})
        self.assertEqual(release.check(d), ("1.10.0", 15))

    def test_refuses_pubspec_without_build_number(self):
        d = app_dir("1.3.0", {"version": "1.2.0", "build": 14})
        with self.assertRaisesRegex(release.Refused, "X.Y.Z\\+N"):
            release.check(d)

    def test_refuses_app_without_release_json(self):
        d = app_dir("1.3.0+15", {})
        os.remove(os.path.join(d, "release.json"))
        with self.assertRaisesRegex(release.Refused, "release.json"):
            release.check(d)


class ManifestTest(unittest.TestCase):
    def test_lists_files_and_folders_with_checksums(self):
        out = tempfile.mkdtemp()
        with open(os.path.join(out, "notes.aab"), "wb") as f:
            f.write(b"bundle")
        os.makedirs(os.path.join(out, "notes.xcarchive", "Products"))
        with open(os.path.join(out, "notes.xcarchive", "Products", "app"), "wb") as f:
            f.write(b"binary")

        m = release.manifest(out, slug="notes", version="1.3.0", build=15, commit="abc123", dirty=False)

        self.assertEqual(m["slug"], "notes")
        self.assertEqual((m["version"], m["build"], m["commit"], m["dirty"]), ("1.3.0", 15, "abc123", False))
        self.assertEqual(m["artifacts"]["notes.aab"], hashlib.sha256(b"bundle").hexdigest())
        # A folder's checksum covers each file's path and content, so a changed or added file changes it.
        before = m["artifacts"]["notes.xcarchive"]
        with open(os.path.join(out, "notes.xcarchive", "Info.plist"), "wb") as f:
            f.write(b"plist")
        after = release.manifest(out, "notes", "1.3.0", 15, "abc123", False)["artifacts"]["notes.xcarchive"]
        self.assertNotEqual(before, after)

    def test_skips_logs_and_the_manifest_itself(self):
        out = tempfile.mkdtemp()
        for name in ("android.log", "manifest.json"):
            open(os.path.join(out, name), "w").close()
        self.assertEqual(release.manifest(out, "notes", "1.3.0", 15, "abc123", False)["artifacts"], {})


if __name__ == "__main__":
    unittest.main()
