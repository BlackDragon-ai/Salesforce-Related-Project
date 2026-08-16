#!/usr/bin/env bash
set -euo pipefail

BASE_REF="${1:-${GITHUB_BASE_REF:-HEAD~1}}"
OUTPUT_DIR="${2:-${RUNNER_TEMP:-/tmp}/sf-delta}"

bash .github/scripts/validate-auth.sh
bash .github/scripts/authenticate-sf.sh
bash .github/scripts/build-delta-package.sh --base-ref "$BASE_REF" --head-ref HEAD --output-dir "$OUTPUT_DIR"

if [[ ! -s "$OUTPUT_DIR/package.xml" ]]; then
  echo "No metadata changes detected for deployment."
  exit 0
fi

grep -q '<members>' "$OUTPUT_DIR/package.xml" || {
  echo "No deployable metadata was identified."
  exit 0
}

mapfile -t TEST_CLASSES < <(bash .github/scripts/sf-test-args.sh || true)

if [[ -s "$OUTPUT_DIR/destructiveChanges.xml" ]]; then
  if [[ ${#TEST_CLASSES[@]} -gt 0 ]]; then
    sf project deploy start \
      --manifest "$OUTPUT_DIR/package.xml" \
      --pre-destructive-changes "$OUTPUT_DIR/destructiveChanges.xml" \
      --target-org default \
      --test-level RunSpecifiedTests \
      --tests "${TEST_CLASSES[@]}" \
      --wait 30 \
      --json > "$OUTPUT_DIR/deployment-result.json"
  else
    sf project deploy start \
      --manifest "$OUTPUT_DIR/package.xml" \
      --pre-destructive-changes "$OUTPUT_DIR/destructiveChanges.xml" \
      --target-org default \
      --test-level NoTestRun \
      --wait 30 \
      --json > "$OUTPUT_DIR/deployment-result.json"
  fi
else
  if [[ ${#TEST_CLASSES[@]} -gt 0 ]]; then
    sf project deploy start \
      --manifest "$OUTPUT_DIR/package.xml" \
      --target-org default \
      --test-level RunSpecifiedTests \
      --tests "${TEST_CLASSES[@]}" \
      --wait 30 \
      --json > "$OUTPUT_DIR/deployment-result.json"
  else
    sf project deploy start \
      --manifest "$OUTPUT_DIR/package.xml" \
      --target-org default \
      --test-level NoTestRun \
      --wait 30 \
      --json > "$OUTPUT_DIR/deployment-result.json"
  fi
fi

echo "Salesforce deployment completed successfully."
