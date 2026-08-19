#!/usr/bin/env bash
# create-needs-test-task.sh — Create a needs-test task for a gap that lacks a test runner.
#
# Usage: create-needs-test-task.sh <mode> <control-id> <body-file> [<ado_org> <ado_project>]
#
#   <mode>        One of: github, azure-devops, local
#   <control-id>  The ITSG-33 control identifier (e.g. AC-2)
#   <body-file>   Path to the description/body file (text for GH/local, HTML for ADO)
#   <ado_org>     Required for azure-devops mode
#   <ado_project> Required for azure-devops mode
#
# Creates the tracker artifact and prints its reference (issue number, work item ID,
# or file path) to stdout.

set -euo pipefail

MODE="${1:?Usage: create-needs-test-task.sh <mode> <control-id> <body-file> [<ado_org> <ado_project>]}"
CONTROL_ID="${2:?Usage: create-needs-test-task.sh <mode> <control-id> <body-file> [<ado_org> <ado_project>]}"
BODY_FILE="${3:?Usage: create-needs-test-task.sh <mode> <control-id> <body-file> [<ado_org> <ado_project>]}"

TITLE="[itsg-33:needs-test] ${CONTROL_ID} — write failing test"

case "$MODE" in
  github)
    bash "$(dirname "$0")/gh-create-issue.sh" "$TITLE" "itsg-33:needs-test" "$BODY_FILE"
    ;;
  azure-devops)
    ADO_ORG="${4:?azure-devops mode requires <ado_org> as 4th argument}"
    ADO_PROJECT="${5:?azure-devops mode requires <ado_project> as 5th argument}"
    bash "$(dirname "$0")/ado-create-work-item.sh" \
      "$ADO_ORG" "$ADO_PROJECT" "Issue" "$TITLE" "itsg-33:needs-test" "$BODY_FILE"
    ;;
  local)
    OUT_FILE="security/gaps/${CONTROL_ID}-needs-test.md"
    if [[ ! -f "$BODY_FILE" ]]; then
      echo "create-needs-test-task: body file not found: ${BODY_FILE}" >&2
      exit 1
    fi
    mkdir -p "$(dirname "$OUT_FILE")"
    cp "$BODY_FILE" "$OUT_FILE"
    echo "$OUT_FILE"
    ;;
  *)
    echo "create-needs-test-task: unknown mode '${MODE}' — expected github|azure-devops|local" >&2
    exit 1
    ;;
esac
