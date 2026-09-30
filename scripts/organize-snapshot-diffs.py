#!/usr/bin/env python3
"""Restore human-readable names on xcresulttool's exported attachments.

`xcrun xcresulttool export attachments` writes each attachment under an
opaque UUID filename and records the real name in manifest.json instead.
This rewrites the export directory in place, one subfolder per test, with
each file renamed back to its suggested name.

Usage: organize-snapshot-diffs.py <export-directory>
"""
import json
import pathlib
import re
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} <export-directory>", file=sys.stderr)
        return 1

    out = pathlib.Path(sys.argv[1])
    manifest_path = out / "manifest.json"
    if not manifest_path.exists():
        print(f"no manifest.json under {out} — nothing to organize")
        return 0

    manifest = json.loads(manifest_path.read_text())
    for entry in manifest:
        test_dir = re.sub(r"[^A-Za-z0-9_.-]", "_", entry["testIdentifier"])
        dest = out / test_dir
        dest.mkdir(parents=True, exist_ok=True)
        for attachment in entry["attachments"]:
            src = out / attachment["exportedFileName"]
            if src.exists():
                src.rename(dest / attachment["suggestedHumanReadableName"])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
