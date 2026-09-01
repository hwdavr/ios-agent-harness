#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WORKFLOW_DIR="$PROJECT_ROOT/.agents/workflows"

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

require_before() {
  local workflow_path="$1"
  local first_stage="$2"
  local second_stage="$3"
  local first_line second_line
  first_line=$(rg -n -F "$first_stage" "$workflow_path" | head -n 1 | cut -d: -f1 || true)
  second_line=$(rg -n -F "$second_stage" "$workflow_path" | head -n 1 | cut -d: -f1 || true)
  [ -n "$first_line" ] && [ -n "$second_line" ] && [ "$first_line" -lt "$second_line" ] ||
    fail_test "$(basename "$workflow_path") must place $first_stage before $second_stage"
}

for workflow in harness-generator.md harness-fix.md; do
  workflow_path="$WORKFLOW_DIR/$workflow"
  [ -f "$workflow_path" ] || fail_test "missing workflow: $workflow_path"
  if rg -n -i "Gate Failure Resolution Policy|do not stop the pipeline|continue to the next item|proceed to the next stage" "$workflow_path"; then
    fail_test "$workflow still allows a failed gate to advance the pipeline"
  fi
done

rg -Fq 'mark Setup `⚠️ Blocked`' "$WORKFLOW_DIR/harness-generator.md" ||
  fail_test "generator workflow does not block failed setup"
rg -Fq 'stop the pipeline. Do not advance' "$WORKFLOW_DIR/harness-generator.md" ||
  fail_test "generator workflow does not stop after failed setup"
rg -Fq 'keep the feature non-passing and stop the pipeline' "$WORKFLOW_DIR/harness-fix.md" ||
  fail_test "fix workflow does not stop after failed verification"
rg -Fq 'check-acceptance-test-traceability.sh' "$WORKFLOW_DIR/harness-generator.md" ||
  fail_test "generator workflow does not require acceptance-test traceability"
rg -Fq 'check-acceptance-test-traceability.sh' "$WORKFLOW_DIR/harness-evaluation.md" ||
  fail_test "evaluation workflow does not require acceptance-test traceability"
require_before "$WORKFLOW_DIR/harness-generator.md" '### Stage 4 — Test First' '### Stage 5 — Implement'
require_before "$WORKFLOW_DIR/feature-delivery.md" '### Stage 3 — Test First' '### Stage 4 — Implementation'

echo "PASS: failed gates stop the pipeline and both delivery workflows require tests before implementation."
