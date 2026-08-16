#!/usr/bin/env bash
set -euo pipefail

for var in SFDX_AUTH_URL; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required GitHub Environment secret: $var" >&2
    exit 1
  fi
done

echo "Salesforce SFDX auth URL is configured."
