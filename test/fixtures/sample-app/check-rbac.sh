#!/bin/bash
# check-rbac.sh [path-to-rbac-yaml]
#
# Fails (exit 1) if the given RBAC manifest contains a ClusterRoleBinding
# whose roleRef.name is the built-in cluster-admin role. Passes (exit 0)
# otherwise. Defaults to k8s/rbac.yaml relative to the current directory.
set -euo pipefail

RBAC_FILE="${1:-k8s/rbac.yaml}"

if [ ! -f "$RBAC_FILE" ]; then
  echo "check-rbac: $RBAC_FILE not found" >&2
  exit 1
fi

if awk '
  /^kind: *ClusterRoleBinding/ { in_crb = 1; next }
  /^---/ { in_crb = 0; in_roleref = 0; next }
  in_crb && /^ *roleRef:/ { in_roleref = 1; next }
  in_crb && in_roleref && /^ *name: *cluster-admin *$/ { found = 1 }
  END { exit(found ? 0 : 1) }
' "$RBAC_FILE"; then
  echo "check-rbac: FAIL - ClusterRoleBinding to cluster-admin found in $RBAC_FILE" >&2
  exit 1
fi

echo "check-rbac: PASS - no ClusterRoleBinding to cluster-admin in $RBAC_FILE"
exit 0
