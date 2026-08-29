#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WORKFLOW_DIR="$PROJECT_ROOT/.agents/workflows"

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
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

echo "PASS: failed generator and fix gates stop the pipeline."
