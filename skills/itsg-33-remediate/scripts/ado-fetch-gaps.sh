#!/usr/bin/env bash
# ado-fetch-gaps.sh — Fetch full details of ADO gap work items and output structured records.
#
# Usage: ado-fetch-gaps.sh <org> <project> <tag>
#
# For each open work item tagged <tag>, fetches full fields via `az boards work-item show`,
# parses control ID and name from the title format "[itsg-33:gap] <ID> — <Name>",
# and outputs a JSON array of records to stdout:
#   [{"id": <int>, "control_id": "<str>", "control_name": "<str>", "source_ref": "<url>"}]

set -euo pipefail

ORG="${1:?Usage: ado-fetch-gaps.sh <org> <project> <tag>}"
PROJECT="${2:?Usage: ado-fetch-gaps.sh <org> <project> <tag>}"
TAG="${3:?Usage: ado-fetch-gaps.sh <org> <project> <tag>}"

# Get the list of matching work item IDs
ITEMS_JSON=$(bash "$(dirname "$0")/ado-list-tagged-items.sh" "$ORG" "$PROJECT" "$TAG")

# For each item, fetch full details and parse
python3 -c "
import json, subprocess, sys, re

org = sys.argv[1]
project = sys.argv[2]
items = json.loads(sys.argv[3])

records = []
for item in items:
    wid = item['id']
    result = subprocess.run(
        ['az', 'boards', 'work-item', 'show', '--id', str(wid), '--org', org, '-o', 'json'],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f'ado-fetch-gaps: failed to fetch work item {wid}: {result.stderr}', file=sys.stderr)
        sys.exit(1)

    wi = json.loads(result.stdout)
    title = wi['fields'].get('System.Title', '')

    # Parse: [itsg-33:gap] <Control ID> — <Control Name>
    m = re.match(r'\[itsg-33:gap\]\s+(\S+)\s+[—-]\s+(.+)', title)
    if not m:
        print(f'ado-fetch-gaps: cannot parse title: {title}', file=sys.stderr)
        sys.exit(1)

    records.append({
        'id': wid,
        'control_id': m.group(1),
        'control_name': m.group(2).strip(),
        'source_ref': f'{org}/{project}/_workitems/edit/{wid}'
    })

print(json.dumps(records))
" "$ORG" "$PROJECT" "$ITEMS_JSON"
