"""Tests for check.py: python3 -m unittest discover -s tool/data_upgrade -p '*_test.py'"""

import pathlib
import tempfile
import unittest

import check

STORE = "final notes = DataStore(directory: dir, appId: 'a', name: 'n', migrations: [], initial: () => {});\n"
HELPER = "void main() { dataUpgradeTests<Note>(fixtures: 'test/data_upgrade/fixtures'); }\n"


def repo(apps):
    """apps: {slug: {relative path: content}}"""
    root = pathlib.Path(tempfile.mkdtemp())
    for slug, files in apps.items():
        app = root / "apps" / slug
        app.mkdir(parents=True)
        (app / "pubspec.yaml").write_text(f"name: {slug}\n")
        for path, content in files.items():
            (app / path).parent.mkdir(parents=True, exist_ok=True)
            (app / path).write_text(content)
    return root


class MissingTest(unittest.TestCase):
    def test_app_that_saves_data_with_a_data_upgrade_test_passes(self):
        root = repo({"notes": {"lib/src/store.dart": STORE, "test/data_upgrade/notes_upgrade_test.dart": HELPER}})
        self.assertEqual(check.missing(root), [])

    def test_app_that_saves_data_without_one_fails_and_names_the_file(self):
        root = repo({"notes": {"lib/src/store.dart": STORE, "test/app_test.dart": HELPER}})
        [problem] = check.missing(root)
        self.assertIn("apps/notes opens a DataStore in lib/src/store.dart", problem)

    def test_a_file_not_named_test_or_without_the_helper_does_not_count(self):
        for path, content in [
            ("test/data_upgrade/notes_upgrade.dart", HELPER),
            ("test/data_upgrade/notes_upgrade_test.dart", "void main() {}\n"),
        ]:
            root = repo({"notes": {"lib/store.dart": STORE, path: content}})
            self.assertEqual(len(check.missing(root)), 1, path)

    def test_app_that_saves_nothing_needs_none(self):
        root = repo({"calc": {"lib/main.dart": "void main() {}\n"}})
        self.assertEqual(check.missing(root), [])

    def test_kit_example_always_needs_one(self):
        root = repo({"kit_example": {"lib/main.dart": "void main() {}\n"}})
        [problem] = check.missing(root)
        self.assertIn("apps/kit_example is the kit's worked example", problem)


if __name__ == "__main__":
    unittest.main()
