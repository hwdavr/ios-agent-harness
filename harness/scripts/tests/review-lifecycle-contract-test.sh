#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-evaluation-fix-contract.sh"
FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/review-lifecycle-test.XXXXXX")
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$(HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" "$@" 2>&1); then
    fail_test "validator unexpectedly accepted fixture"
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "$output" >&2
    fail_test "validator did not report '$expected'"
  }
}

write_tracker() {
  local status="$1"
  mkdir -p "$FIXTURE_ROOT/docs/product/2026-08-29-fixture"
  printf '%s\n' \
    '# Fixture' \
    '<!-- HARNESS_TRACKER_START -->' \
    '| ID | Feature | Workspace | Status | Updated | Notes |' \
    '|---|---|---|---|---|---|' \
    "| fixture | Fixture | [docs/product/2026-08-29-fixture/](2026-08-29-fixture/) | $status | 2026-08-30 | Contract fixture |" \
    '<!-- HARNESS_TRACKER_END -->' \
    > "$FIXTURE_ROOT/docs/product/product.md"
}

write_feature() {
  local result_text="${1:-1 test passed}"
  local status="${2:-passing}"
  mkdir -p "$FIXTURE_ROOT/docs/product/2026-08-29-fixture"
  cat > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/feature_list.json" <<JSON
{
  "features": [{
    "id": "US-1",
    "status": "$status",
    "acceptance_test_ids": ["AC-US-1-01"],
    "evidence": [{
      "test_id": "TC-US-1-01",
      "executed_command": "xcodebuild test -only-testing:FixtureTests",
      "exit_status": 0,
      "result": "$result_text"
    }]
  }]
}
JSON
  printf '%s\n' \
    '# Sprint Contract' \
    '' \
    '| Acceptance ID | Story | Test ID |' \
    '|---|---|---|' \
    '| AC-US-1-01 | US-1 | TC-US-1-01 |' \
    > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/sprint-contract.md"
  printf '%s\n' '# Evaluator Rubric' > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/evaluator-rubric.md"
  printf '%s\n' '# Code Review' > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/code_review_fixture.md"
  printf '%s\n' '# Test Review' > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/test_review_fixture.md"
  printf '%s\n' '# Summary' > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/summary_fixture.md"
}

write_valid_evaluator_rubric() {
  cat > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/evaluator-rubric.md" <<'EOF'
# Evaluator Rubric

| Category | Question | Score (0-5) | Notes |
| --- | --- | ---: | --- |
| Correctness | | 5 | |
| Verification | | 5 | |
| Scope discipline | | 5 | |
| Reliability | | 5 | |
| Maintainability | | 5 | |
| Handoff readiness | | 5 | |
| Code & Test Review | | 5 | |
| Rule Applicability | | 5 | |

### Overall: 5.0 / 5

## Verdict

**Accept**
EOF
}

write_valid_fix_reports() {
  cat > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/code_review_fixture.md" <<'EOF'
# Code Review

## Required Findings

1. Fixture finding.
   > **Fix Status:** Fixed ✅ — fixture fix (commit `abc123`; verified: fixture, exit 0; 2026-08-30).

## Verdict

> **Fix Pass:** 1/1 findings fixed; 0 unresolved (2026-08-30).

**APPROVED**
EOF
  cat > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/test_review_fixture.md" <<'EOF'
# Test Review

## Fix Status Overlay

| Source ID / finding | Fix Status | Re-verification |
|---|---|---|
| AC-US-1-01 | Fixed ✅ | fixture |

## Fix Pass Summary

**Fixed:** 1/1. **Unresolved:** 0.

## Verdict

**APPROVED**
EOF
  cat > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/summary_fixture.md" <<'EOF'
# Fix Pass Summary

## Stage Status

| Fix-Stage 1 — Orient | ✅ Complete | |
| Fix-Stage 2 — Setup | ✅ Complete | |
| Fix-Stage 3 — Fix | ✅ Complete | |
| Fix-Stage 4 — Re-verify | ✅ Complete | |
| Fix-Stage 5 — Finalize | ✅ Complete | |
| Fix-Stage 6 — Install | ✅ Complete | |
EOF
}

# A valid evaluation uses the arithmetic mean and routes a perfect score to
# human review.
write_tracker "To be human reviewed"
write_feature
write_valid_evaluator_rubric
write_valid_fix_reports
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-08-29-fixture --evaluation

# The old workflow accepted a free-form score that disagreed with its rows.
sed 's/### Overall: 5.0/### Overall: 4.9/' \
  "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/evaluator-rubric.md" \
  > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/evaluator-rubric.tmp"
mv "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/evaluator-rubric.tmp" \
  "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/evaluator-rubric.md"
expect_failure "does not match arithmetic mean 5.0" \
  bash "$VALIDATOR" docs/product/2026-08-29-fixture --evaluation

# A successful-looking evidence result cannot contain an explicitly stalled
# or terminated run.
write_valid_evaluator_rubric
write_feature "coverage attempt stalled and terminated" "passing"
expect_failure "contradicts success" \
  bash "$VALIDATOR" docs/product/2026-08-29-fixture --evaluation

# A fix pass cannot advance beyond a blocked baseline or retain an unresolved
# review verdict.
write_feature
write_valid_evaluator_rubric
write_valid_fix_reports
write_tracker "To be human reviewed"
sed 's/| Fix-Stage 2 — Setup | ✅ Complete |/| Fix-Stage 2 — Setup | ⚠️ Blocked |/' \
  "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/summary_fixture.md" \
  > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/summary_fixture.tmp"
mv "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/summary_fixture.tmp" \
  "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/summary_fixture.md"
expect_failure "contains a blocked or incomplete fix stage" \
  bash "$VALIDATOR" docs/product/2026-08-29-fixture --fix

# Even with all stages complete, a stale REVISION REQUIRED verdict cannot be
# hidden by per-finding status lines.
write_feature
write_valid_evaluator_rubric
write_valid_fix_reports
write_tracker "To be human reviewed"
sed 's/\*\*APPROVED\*\*/**REVISION REQUIRED**/' \
  "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/code_review_fixture.md" \
  > "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/code_review_fixture.tmp"
mv "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/code_review_fixture.tmp" \
  "$FIXTURE_ROOT/docs/product/2026-08-29-fixture/code_review_fixture.md"
expect_failure "Verdict still reports a non-passing outcome" \
  bash "$VALIDATOR" docs/product/2026-08-29-fixture --fix

write_feature
write_valid_evaluator_rubric
write_valid_fix_reports
write_tracker "To be human reviewed"
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-08-29-fixture --fix

echo "PASS: review lifecycle rejects inconsistent scores, contradictory evidence, and blocked fix-stage advancement."
