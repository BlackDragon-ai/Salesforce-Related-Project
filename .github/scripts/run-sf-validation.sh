#!/usr/bin/env bash
set -euo pipefail

BASE_REF="${1:-${GITHUB_BASE_REF:-HEAD~1}}"
OUTPUT_DIR="${2:-${RUNNER_TEMP:-/tmp}/sf-delta}"

bash .github/scripts/validate-auth.sh
bash .github/scripts/authenticate-sf.sh
bash .github/scripts/build-delta-package.sh --base-ref "$BASE_REF" --head-ref HEAD --output-dir "$OUTPUT_DIR"

if [[ ! -s "$OUTPUT_DIR/package.xml" ]]; then
  echo "No package.xml generated. No metadata changes to validate."
  exit 0
fi

grep -q '<members>' "$OUTPUT_DIR/package.xml" || {
  echo "No deployable metadata was identified for validation."
  exit 0
}

mapfile -t TEST_CLASSES < <(bash .github/scripts/sf-test-args.sh)
sf project deploy validate \
  --source-dir "$OUTPUT_DIR/delta" \
  --target-org "$SF_USERNAME" \
  --test-level RunSpecifiedTests \
  --tests "${TEST_CLASSES[@]}" \
  --wait 30 \
  --json > "$OUTPUT_DIR/validation-result.json"

echo "Salesforce validation completed successfully."
