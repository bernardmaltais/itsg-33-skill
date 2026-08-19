#!/usr/bin/env bash
# check-remote.sh — Check whether the repository has a usable remote.
#
# Usage: check-remote.sh
#
# Exits 0 and prints "remote" to stdout if at least one remote is configured.
# Exits 0 and prints "local" to stdout if no remote is configured.
# Exits nonzero on failure (e.g. not a git repo).

set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "check-remote: not inside a git repository" >&2
  exit 1
fi

REMOTES=$(git remote -v 2>/dev/null)

if [[ -z "$REMOTES" ]]; then
  echo "local"
else
  echo "remote"
fi
