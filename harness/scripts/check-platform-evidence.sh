#!/usr/bin/env bash
# Validates the platform-capability contract for a planned or evaluated slice.
#
# Usage: bash harness/scripts/check-platform-evidence.sh <feature-directory> [--planning|--evaluate] [--slice <id>]

set -e

DOCS_DIR="${1:-}"
MODE="${2:---evaluate}"
SLICE_ID=""

if [ "${3:-}" = "--slice" ]; then
  SLICE_ID="${4:-}"
fi

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

[ -n "$DOCS_DIR" ] || fail "feature directory is required"
[ "$MODE" = "--planning" ] || [ "$MODE" = "--evaluate" ] \
  || fail "mode must be --planning or --evaluate"
[ -d "$DOCS_DIR" ] || fail "feature directory $DOCS_DIR does not exist"

FEATURE_JSON="$DOCS_DIR/feature_list.json"
CONTRACT="$DOCS_DIR/sprint-contract.md"
[ -f "$FEATURE_JSON" ] || fail "missing $FEATURE_JSON"
[ -f "$CONTRACT" ] || fail "missing $CONTRACT"
jq empty "$FEATURE_JSON" 2>/dev/null || fail "$FEATURE_JSON is not valid JSON"

PLATFORM_REQUIRED=$(jq -r '.platform_validation.required | if . == null then "" else tostring end' "$FEATURE_JSON")
case "$PLATFORM_REQUIRED" in
  false)
    REASON=$(jq -r '.platform_validation.reason // empty' "$FEATURE_JSON")
    [ -n "$REASON" ] || fail "platform validation is not required but feature_list.json must explain why platform validation is not required"
    echo "PASS: platform validation explicitly not required: $REASON"
    exit 0
    ;;
  true)
    ;;
  *)
    fail "platform_validation.required must be true or false"
    ;;
esac

MATRIX_PATH=$(jq -r '.platform_validation.capability_matrix // empty' "$FEATURE_JSON")
[ -n "$MATRIX_PATH" ] || fail "platform_validation.capability_matrix is required"
case "$MATRIX_PATH" in
  /*|*..*) fail "platform capability matrix path must stay under the feature directory" ;;
esac
MATRIX="$DOCS_DIR/$MATRIX_PATH"
[ -f "$MATRIX" ] || fail "platform capability matrix is missing: $MATRIX_PATH"

grep -Eq '^\|[[:space:]]*Runtime/API[[:space:]]*\|' "$MATRIX" \
  || fail "platform capability matrix has no runtime matrix"
grep -Eq '^\|[[:space:]]*Runtime/API[[:space:]]*\|.*Status[[:space:]]*\|' "$MATRIX" \
  || fail "platform capability matrix has no status column"

if [ "$MODE" = "--evaluate" ]; then
  if grep -Eiq '^\|.*\|[[:space:]]*(Pending|Unavailable|Blocked|Skipped)[[:space:]]*\|[[:space:]]*$' "$MATRIX"; then
    fail "pending/unavailable/blocked/skipped platform runtime cannot pass evaluation"
  fi
fi

REAL_REQUIRED=$(jq -r '.platform_validation.real_boundary_test_required // empty' "$FEATURE_JSON")
[ "$REAL_REQUIRED" = "true" ] || fail "platform-bound features require real_boundary_test_required=true"

REAL_TEST_IDS=$(jq -r '.platform_validation.real_boundary_test_ids // [] | .[]' "$FEATURE_JSON")
[ -n "$REAL_TEST_IDS" ] || fail "platform_validation.real_boundary_test_ids is required"

REAL_TEST_FILES=$(jq -r '.platform_validation.real_boundary_test_files // [] | .[]' "$FEATURE_JSON")
[ -n "$REAL_TEST_FILES" ] || fail "platform_validation.real_boundary_test_files is required"

REAL_SIGNAL=$(jq -r '.platform_validation.real_boundary_test_signal // empty' "$FEATURE_JSON")
[ -n "$REAL_SIGNAL" ] || fail "platform_validation.real_boundary_test_signal is required"

if [ -n "$SLICE_ID" ]; then
  SLICE_OWNS_TEST=false
  for test_id in $REAL_TEST_IDS; do
    if jq -e --arg slice "$SLICE_ID" --arg test_id "$test_id" '
      any(.features[] | select(.id == $slice) | (.acceptance_test_ids // [])[]; . == $test_id)
    ' "$FEATURE_JSON" >/dev/null 2>&1; then
      SLICE_OWNS_TEST=true
      break
    fi
  done
  if [ "$SLICE_OWNS_TEST" != "true" ]; then
    fail "slice $SLICE_ID does not own a declared real platform boundary test"
  fi
fi

for test_id in $REAL_TEST_IDS; do
  grep -Fq "$test_id" "$CONTRACT" \
    || fail "$test_id is not declared in sprint-contract.md"
done

for test_file in $REAL_TEST_FILES; do
  case "$test_file" in
    /*|*..*) fail "real platform test file path must stay under the feature directory" ;;
  esac
  [ -f "$DOCS_DIR/$test_file" ] || fail "real platform test file is missing: $test_file"
  grep -Fq "$REAL_SIGNAL" "$DOCS_DIR/$test_file" \
    || fail "real platform boundary test has no real-platform signal '$REAL_SIGNAL'"
done

if [ "$MODE" = "--evaluate" ]; then
  for test_id in $REAL_TEST_IDS; do
    EVIDENCE_COUNT=$(jq --arg id "$test_id" '
      [
        .features[]
        | (.evidence // [])[]
        | select(.test_id == $id and .exit_status == 0 and ((.executed_command // "") | contains("xcodebuild test")))
      ] | length
    ' "$FEATURE_JSON")
    [ "$EVIDENCE_COUNT" -gt 0 ] \
      || fail "$test_id has no successful connected-test evidence"
  done
fi

echo "PASS: platform capability matrix, real boundary test declaration, signal, ownership, and evidence are valid."
