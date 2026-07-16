#!/usr/bin/env python3
"""Validate and merge a classification pass into security/file-roles.yaml.

Usage: merge-file-roles.py <input-json-path> <old-roles-path> <new-roles-path>

Reads the classification subagent's per-path role assignments as JSON, validates
them, and merges them into the existing file-roles cache (itself JSON, despite the
`.yaml` name — same convention `merge-state.py` already uses for
`assessment-state.yaml`). This script is the sole writer of `security/file-roles.yaml`:
paths present in the input overwrite/insert their entry; every other path already in
<old-roles-path> passes through untouched. Exits non-zero with a specific message on
any validation failure so the calling orchestrator can fix the input and retry, per
SKILL.md Step 2's "malformed output" failure handling (same posture as
`write-fragment.py`).

Input JSON shape:
{
  "classifications": {
    "<path>": {"roles": ["<role>", ...], "content_hash": "<sha256 hex>"}
  }
}

<old-roles-path> may not exist (cold start / first run); it is then treated as having
no prior entries. <new-roles-path> may be the same path as <old-roles-path> for an
in-place update — the old file is fully read before the new one is written.
"""
import json
import os
import re
import sys

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")


def fail(message):
    print(f"merge-file-roles: {message}", file=sys.stderr)
    sys.exit(1)


def load_old_roles(path):
    if not os.path.exists(path):
        return {}
    try:
        with open(path) as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        fail(f"existing file-roles file {path} is not valid json: {e}")
        return {}
    if not isinstance(data, dict):
        fail(f"existing file-roles file {path} must contain a JSON object")
        return {}
    return data


def load_classifications(input_path):
    try:
        with open(input_path) as f:
            raw = f.read()
    except OSError as e:
        fail(f"cannot read input file: {e}")
        return {}

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        fail(f"input is not valid json: {e}")
        return {}

    if not isinstance(data, dict):
        fail("top-level JSON must be an object")
    classifications = data.get("classifications")
    if not isinstance(classifications, dict):
        fail("'classifications' must be an object")

    for path, entry in classifications.items():
        if not isinstance(path, str) or not path.strip():
            fail(f"invalid path key: {path!r}")
        if not isinstance(entry, dict):
            fail(f"{path}: entry must be an object")

        roles = entry.get("roles")
        if not isinstance(roles, list):
            fail(f"{path}: 'roles' must be a list")
        for role in roles:
            if not isinstance(role, str) or not role.strip():
                fail(f"{path}: roles entry {role!r} must be a non-empty string")

        content_hash = entry.get("content_hash")
        if not isinstance(content_hash, str) or not SHA256_RE.match(content_hash):
            fail(f"{path}: 'content_hash' is not a 64-char lowercase SHA-256 hex "
                 f"digest: {content_hash!r}")

    return classifications


def main():
    if len(sys.argv) != 4:
        fail("usage: merge-file-roles.py <input-json-path> <old-roles-path> <new-roles-path>")
    input_path, old_roles_path, new_roles_path = sys.argv[1:4]

    old_roles = load_old_roles(old_roles_path)
    classifications = load_classifications(input_path)

    merged = dict(old_roles)
    for path, entry in classifications.items():
        merged[path] = {"roles": entry["roles"], "content_hash": entry["content_hash"]}

    with open(new_roles_path, "w") as f:
        json.dump(merged, f, indent=2, sort_keys=True)
        f.write("\n")

    print(f"merge-file-roles: wrote {len(merged)} paths to {new_roles_path} "
          f"({len(classifications)} reclassified this run)")


if __name__ == "__main__":
    main()
