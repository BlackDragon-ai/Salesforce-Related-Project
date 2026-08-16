#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SFDX_AUTH_URL:-}" ]]; then
  echo "Missing required GitHub Environment secret: SFDX_AUTH_URL" >&2
  exit 1
fi

auth_file="$(mktemp)"
trap 'rm -f "$auth_file" >/dev/null 2>&1 || true' EXIT
printf '%s\n' "$SFDX_AUTH_URL" > "$auth_file"

sf org login sfdx-url \
  --sfdx-url-file "$auth_file" \
  --set-default

sf org display --target-org default --json >/tmp/sf-org-display.json
