"""Fails when an app that saves data has no data-upgrade test (ADR 0001, section 8).

`flutter test` only runs the tests that exist, so an app that saves data and has no data-upgrade test would pass
quietly. This check makes that a failure. An app needs one when its own `lib/` opens a kit `DataStore`; the kit's
example app always needs one, as the worked example every app copies. A data-upgrade test is a
`test/data_upgrade/**/*_test.dart` file that calls the kit's `dataUpgradeTests` (which itself fails with no fixture).

    python3 tool/data_upgrade/check.py [<repo root>]
"""

import pathlib
import re
import sys

ALWAYS = {"kit_example"}
SAVES_DATA = re.compile(r"\bDataStore\s*\(")
HELPER = re.compile(r"\bdataUpgradeTests\s*(<[^>]*>)?\s*\(")


def _any_file(files, pattern):
    return next((f for f in files if pattern.search(f.read_text(encoding="utf-8"))), None)


def missing(root):
    """One message per app under apps/ that needs a data-upgrade test and has none."""
    problems = []
    for app in sorted(p.parent for p in pathlib.Path(root, "apps").glob("*/pubspec.yaml")):
        saver = _any_file(sorted(app.joinpath("lib").rglob("*.dart")), SAVES_DATA)
        if saver is None and app.name not in ALWAYS:
            continue
        if _any_file(sorted(app.joinpath("test", "data_upgrade").rglob("*_test.dart")), HELPER):
            continue
        why = f"opens a DataStore in {saver.relative_to(app)}" if saver else "is the kit's worked example"
        problems.append(
            f"apps/{app.name} {why} but has no data-upgrade test: add "
            f"test/data_upgrade/<name>_test.dart calling dataUpgradeTests (ADR 0001, section 8)"
        )
    return problems


def main(argv):
    root = argv[1] if len(argv) > 1 else pathlib.Path(__file__).resolve().parents[2]
    problems = missing(root)
    for p in problems:
        print(f"error: {p}", file=sys.stderr)
    if not problems:
        print("data-upgrade tests: every app that saves data has one")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
