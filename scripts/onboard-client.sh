#!/usr/bin/env bash
# onboard-client.sh — EPIC-2 task 2.17.
#
# Prints the `az role assignment create` invocations the CLIENT's
# Azure admin must run BEFORE we can apply the tenant stack into
# their subscription. The output is meant to be copy/pasted into a
# Cloud Shell session in the client tenant.
#
# Skeleton — implementation pending. The output should include:
#   * Our SP App ID (for the cross-sub Contributor + UA assignments)
#   * The role assignments needed at the subscription scope
#   * The Entra app registration consent grant the client must approve
#
# Usage (once implemented):
#   ./onboard-client.sh <tenant_id> <client_subscription_id>

set -euo pipefail

TENANT_ID="${1:-}"
CLIENT_SUB="${2:-}"

if [[ -z "$TENANT_ID" || -z "$CLIENT_SUB" ]]; then
  echo "Usage: $0 <tenant_id> <client_subscription_id>" >&2
  exit 1
fi

cat <<EOF
TODO — task 2.17. Will print az role assignment commands for tenant=${TENANT_ID} sub=${CLIENT_SUB}.
EOF
