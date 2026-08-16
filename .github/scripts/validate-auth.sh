#!/usr/bin/env bash
set -euo pipefail

for var in SF_USERNAME SF_CLIENT_ID SF_JWT_KEY SF_INSTANCE_URL; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required GitHub Environment secret/variable: $var" >&2
    exit 1
  fi
done

echo "Salesforce authentication variables are configured."
