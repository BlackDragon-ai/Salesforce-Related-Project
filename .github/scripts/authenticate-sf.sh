#!/usr/bin/env bash
set -euo pipefail

for var in SF_USERNAME SF_CLIENT_ID SF_JWT_KEY SF_INSTANCE_URL; do
  if [[ -z "${!var:-}" ]]; then
    echo "Missing required GitHub Environment secret/variable: $var" >&2
    exit 1
  fi
done

jwt_key_path="${SF_JWT_KEY}"
if [[ "$jwt_key_path" == *"BEGIN "* ]]; then
  jwt_key_path="$(mktemp)"
  printf '%s\n' "$SF_JWT_KEY" > "$jwt_key_path"
elif [[ ! -f "$jwt_key_path" ]]; then
  echo "SF_JWT_KEY is not a valid private key file path or key content." >&2
  exit 1
fi

trap 'rm -f "$jwt_key_path" >/dev/null 2>&1 || true' EXIT

sf org login jwt \
  --username "$SF_USERNAME" \
  --jwt-key-file "$jwt_key_path" \
  --client-id "$SF_CLIENT_ID" \
  --instance-url "$SF_INSTANCE_URL" \
  --set-default

sf org display --target-org "$SF_USERNAME" --json >/tmp/sf-org-display.json
