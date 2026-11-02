"""Release helpers for build.sh (ADR 0001, section 12). Standard library only.

  release.py check <app-dir>
      Prints "<version> <build>" from the app's pubspec.yaml, or exits 1 unless both are above the last released
      ones in <app-dir>/release.json ({"version": "X.Y.Z", "build": N}).
  release.py manifest <out-dir> <slug> <version> <build> <commit> <dirty: 0|1>
      Writes <out-dir>/manifest.json: versions, commit and a SHA-256 for each artifact in <out-dir>.
"""

import hashlib
import json
import os
import re
import sys


class Refused(Exception):
    pass


def _numbers(version):
    return tuple(int(n) for n in version.split("."))


def check(app_dir):
    with open(os.path.join(app_dir, "pubspec.yaml")) as f:
        found = re.search(r"^version:\s*['\"]?(\d+\.\d+\.\d+)\+(\d+)['\"]?\s*$", f.read(), re.MULTILINE)
    if not found:
        raise Refused("pubspec.yaml needs a version of the form X.Y.Z+N")
    version, build = found.group(1), int(found.group(2))

    path = os.path.join(app_dir, "release.json")
    if not os.path.exists(path):
        raise Refused(f'{path} is missing: add {{"version": "0.0.0", "build": 0}} before the first release')
    with open(path) as f:
        last = json.load(f)

    if _numbers(version) <= _numbers(last["version"]):
        raise Refused(f"version {version} is not above the last released version {last['version']}")
    if build <= int(last["build"]):
        raise Refused(f"build number {build} is not above the last released build number {last['build']}")
    return version, build


def _sha256(path):
    digest = hashlib.sha256()
    if os.path.isfile(path):
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                digest.update(chunk)
        return digest.hexdigest()
    # A folder (the .xcarchive): hash each file's relative path and content, in a fixed order.
    for root, dirs, files in os.walk(path):
        dirs.sort()
        for name in sorted(files):
            full = os.path.join(root, name)
            digest.update(os.path.relpath(full, path).encode() + b"\0" + _sha256(full).encode() + b"\n")
    return digest.hexdigest()


def manifest(out_dir, slug, version, build, commit, dirty):
    artifacts = {
        name: _sha256(os.path.join(out_dir, name))
        for name in sorted(os.listdir(out_dir))
        if name != "manifest.json" and not name.endswith(".log")
    }
    return {"slug": slug, "version": version, "build": build, "commit": commit, "dirty": dirty,
            "artifacts": artifacts}


def main(argv):
    if len(argv) == 3 and argv[1] == "check":
        try:
            print(*check(argv[2]))
        except Refused as e:
            print(f"release: refused: {e}", file=sys.stderr)
            return 1
        return 0
    if len(argv) == 8 and argv[1] == "manifest":
        out_dir, slug, version, build, commit, dirty = argv[2:]
        m = manifest(out_dir, slug, version, int(build), commit, dirty == "1")
        with open(os.path.join(out_dir, "manifest.json"), "w") as f:
            json.dump(m, f, indent=2)
            f.write("\n")
        return 0
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
