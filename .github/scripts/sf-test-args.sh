#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${SF_TEST_CLASSES:-}" || "${SF_TEST_CLASSES}" == "null" ]]; then
  echo "No Apex test classes configured; skipping test execution."
  exit 0
fi

# Accept comma, newline or space separated values.
IFS=', ' read -r -a classes <<< "${SF_TEST_CLASSES}"
if [[ ${#classes[@]} -eq 0 ]]; then
  echo "SF_TEST_CLASSES is empty; skipping test execution."
  exit 0
fi

for test_name in "${classes[@]}"; do
  [[ -n "$test_name" ]] || continue
  printf '%s\n' "$test_name"
done
