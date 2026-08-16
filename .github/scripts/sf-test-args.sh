#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SF_TEST_CLASSES:-}" ]]; then
  echo "SF_TEST_CLASSES is not configured. Set it in the GitHub Environment variables before running a deploy." >&2
  exit 1
fi

# Accept comma, newline or space separated values.
IFS=', ' read -r -a classes <<< "${SF_TEST_CLASSES}"
if [[ ${#classes[@]} -eq 0 ]]; then
  echo "SF_TEST_CLASSES is empty." >&2
  exit 1
fi

for test_name in "${classes[@]}"; do
  [[ -n "$test_name" ]] || continue
  printf '%s\n' "$test_name"
done
