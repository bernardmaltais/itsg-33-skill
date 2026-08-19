#!/usr/bin/env bash
# update-gap-file-ticket.sh — Add or update the Remediation Ticket line in a gap file.
#
# Usage: update-gap-file-ticket.sh <gap-file> <pr-url>
#
# If the file already contains a "**Remediation Ticket:**" line, replaces it.
# Otherwise appends the line to the file.
# Exits nonzero if the gap file does not exist.

set -euo pipefail

GAP_FILE="${1:?Usage: update-gap-file-ticket.sh <gap-file> <pr-url>}"
PR_URL="${2:?Usage: update-gap-file-ticket.sh <gap-file> <pr-url>}"

if [[ ! -f "$GAP_FILE" ]]; then
  echo "update-gap-file-ticket: file not found: ${GAP_FILE}" >&2
  exit 1
fi

LINE="**Remediation Ticket:** ${PR_URL}"

if grep -q '^\*\*Remediation Ticket:\*\*' "$GAP_FILE"; then
  # Replace existing line
  sed -i "s|^\*\*Remediation Ticket:\*\*.*|${LINE}|" "$GAP_FILE"
  echo "==> Updated Remediation Ticket in ${GAP_FILE}" >&2
else
  # Append
  echo "" >> "$GAP_FILE"
  echo "$LINE" >> "$GAP_FILE"
  echo "==> Added Remediation Ticket to ${GAP_FILE}" >&2
fi
