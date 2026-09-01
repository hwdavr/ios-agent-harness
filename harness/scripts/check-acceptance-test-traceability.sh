#!/usr/bin/env bash
# Verifies that every acceptance Test ID has a concrete Swift test method,
# an executable suite selector, and (where declared) a shared JSON scenario.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${HARNESS_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
FEATURE_DIR_INPUT="${1:-}"
MODE="${2:---evaluate}"
SLICE_ID="${3:-}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

usage() {
  echo "Usage: bash harness/scripts/check-acceptance-test-traceability.sh <feature-directory> [--planning|--test|--evaluate] [US-N]" >&2
  exit 2
}

[ -n "$FEATURE_DIR_INPUT" ] || usage
case "$MODE" in
  --planning|--test|--evaluate) ;;
  *) usage ;;
esac

case "$FEATURE_DIR_INPUT" in
  /*) FEATURE_DIR="$FEATURE_DIR_INPUT" ;;
  *) FEATURE_DIR="$PROJECT_ROOT/$FEATURE_DIR_INPUT" ;;
esac

case "$FEATURE_DIR" in
  "$PROJECT_ROOT"/docs/product/*) ;;
  *) fail "feature directory must stay under docs/product/" ;;
esac

FEATURE_JSON="$FEATURE_DIR/feature_list.json"
CONTRACT="$FEATURE_DIR/sprint-contract.md"
[ -f "$FEATURE_JSON" ] || fail "missing $FEATURE_JSON"
[ -f "$CONTRACT" ] || fail "missing $CONTRACT"

HEADER='| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |'
grep -Fq "$HEADER" "$CONTRACT" \
  || fail "sprint-contract.md must use the acceptance table with Test file and method, Shared scenario(s), and Exact command columns"

if [ -n "$SLICE_ID" ]; then
  jq -e --arg id "$SLICE_ID" 'any(.features[]?; .id == $id)' "$FEATURE_JSON" >/dev/null 2>&1 \
    || fail "feature_list.json has no slice $SLICE_ID"
fi

rows=$(
  awk -F'|' '
    function trim(value) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", value); return value }
    /^\| Test ID \| Covers AC \| Test layer \| Test file and method \| Shared scenario\(s\) \| Setup and action \| Required assertions \| Exact command \|[[:space:]]*$/ { in_table = 1; next }
    in_table && /^\|---/ { next }
    in_table && /^\|/ {
      id = trim($2)
      if (id ~ /^TC-US-[0-9]+-/) {
        print id "\t" trim($3) "\t" trim($4) "\t" trim($5) "\t" trim($6) "\t" trim($7) "\t" trim($8) "\t" trim($9)
      }
      next
    }
    in_table { in_table = 0 }
  ' "$CONTRACT"
)

[ -n "$rows" ] || fail "sprint-contract.md has no parseable acceptance Test ID rows"

seen_ids=""
checked=0
while IFS=$'\t' read -r test_id covers_ac test_layer test_target scenarios setup assertions command; do
  [ -n "$test_id" ] || continue

  owner=$(printf '%s' "$test_id" | sed -n 's/^TC-\(US-[0-9][0-9]*\)-.*/\1/p')
  [ -n "$owner" ] || fail "$test_id must use the TC-US-N-* naming convention"
  if [ -n "$SLICE_ID" ] && [ "$owner" != "$SLICE_ID" ]; then
    continue
  fi

  case "\n$seen_ids\n" in
    *"\n$test_id\n"*) fail "$test_id is declared more than once in sprint-contract.md" ;;
  esac
  seen_ids="$seen_ids\n$test_id"

  [ -n "$covers_ac" ] || fail "$test_id has no covered acceptance criterion"
  [ -n "$test_layer" ] || fail "$test_id has no test layer"
  [ -n "$setup" ] || fail "$test_id has no setup and action"
  [ -n "$assertions" ] || fail "$test_id has no required assertions"
  [ -n "$command" ] || fail "$test_id has no exact command"

  target=$(printf '%s' "$test_target" | sed 's/^`//; s/`$//')
  test_file=${target%%#*}
  test_method=${target#*#}
  [ "$test_file" != "$target" ] && [ -n "$test_method" ] \
    || fail "$test_id must declare Test file and method as NotesTakingAppiOSTests/...swift#method"
  case "$test_file" in
    NotesTakingAppiOSTests/*.swift|NotesTakingAppiOSUITests/*.swift) ;;
    *) fail "$test_id test file must be under NotesTakingAppiOSTests/ or NotesTakingAppiOSUITests/" ;;
  esac
  case "$test_file" in
    *..*|/*) fail "$test_id test file path must stay inside the repository" ;;
  esac
  printf '%s' "$test_method" | grep -Eq '^[A-Za-z_][A-Za-z0-9_]*$' \
    || fail "$test_id has an invalid Swift test method '$test_method'"

  suite=$(basename "$test_file" .swift)
  printf '%s' "$command" | grep -Eq 'xcodebuild[[:space:]].*test|xcodebuild.*[[:space:]]test' \
    || fail "$test_id exact command must execute xcodebuild test"
  printf '%s' "$command" | grep -Fq -- '-only-testing:' \
    || fail "$test_id exact command must scope execution with -only-testing"
  printf '%s' "$command" | grep -Eq -- "-only-testing:[^[:space:]]*/$suite(/[^[:space:]]+)?" \
    || fail "$test_id exact command does not target $suite"

  scenario_paths=$(printf '%s' "$scenarios" | grep -oE 'sharedContracts/test-scenarios/[A-Za-z0-9_.-]+\.json' || true)
  if [ -z "$scenario_paths" ]; then
    printf '%s' "$scenarios" | grep -Eq '^N/A[[:space:]]+—[[:space:]]+no API$' \
      || fail "$test_id Shared scenario(s) must list sharedContracts/test-scenarios/*.json or say 'N/A — no API'"
  fi

  jq -e --arg owner "$owner" --arg test_id "$test_id" '
    any(.features[]?; .id == $owner and ((.acceptance_test_ids // []) | index($test_id)))
  ' "$FEATURE_JSON" >/dev/null 2>&1 \
    || fail "$test_id is missing from $owner acceptance_test_ids in feature_list.json"

  if [ "$MODE" != "--planning" ]; then
    source_file="$PROJECT_ROOT/$test_file"
    [ -f "$source_file" ] || fail "$test_id declared test source is missing: $test_file"

    method_line=$(grep -n -E "^[[:space:]]*(@Test([[:space:]]*\\([^)]*\\))?[[:space:]]*)?(public|private|internal|fileprivate)?[[:space:]]*func[[:space:]]+$test_method[[:space:]]*\\(" "$source_file" | head -n 1 | cut -d: -f1 || true)
    [ -n "$method_line" ] || fail "$test_id declared test method is missing: $test_file#$test_method"

    if ! printf '%s' "$test_method" | grep -Eq '^test[A-Z_]'; then
      context_start=$((method_line - 8))
      [ "$context_start" -ge 1 ] || context_start=1
      sed -n "${context_start},${method_line}p" "$source_file" | grep -Fq '@Test' \
        || fail "$test_id declared method is not a Swift Testing @Test or XCTest test method: $test_file#$test_method"
    fi

    method_source=$(sed -n "${method_line},\$p" "$source_file" | awk '
      NR > 1 && /^[[:space:]]*(@Test([[:space:]]*\([^)]*\))?[[:space:]]*)?(public|private|internal|fileprivate)?[[:space:]]*func[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(/ { exit }
      { print }
    ')
    while IFS= read -r scenario_path; do
      [ -n "$scenario_path" ] || continue
      [ -f "$PROJECT_ROOT/$scenario_path" ] \
        || fail "$test_id declared shared scenario is missing: $scenario_path"
      scenario_name=$(basename "$scenario_path")
      printf '%s' "$method_source" | grep -Fq "$scenario_name" \
        || fail "$test_id method $test_file#$test_method does not reference declared shared scenario $scenario_name"
    done <<EOF
$scenario_paths
EOF
  fi

  if [ "$MODE" = "--evaluate" ]; then
    evidence_commands=$(jq -r --arg owner "$owner" --arg test_id "$test_id" '
      .features[]
      | select(.id == $owner)
      | (.evidence // [])[]?
      | select(.test_id == $test_id and .exit_status == 0)
      | .executed_command // empty
    ' "$FEATURE_JSON")
    [ -n "$evidence_commands" ] || fail "$test_id has no successful evidence in feature_list.json"
    evidence_targets_suite=0
    while IFS= read -r evidence_command; do
      [ -n "$evidence_command" ] || continue
      if printf '%s' "$evidence_command" | grep -Fq -- '-only-testing:' && \
        printf '%s' "$evidence_command" | grep -Eq -- "-only-testing:[^[:space:]]*/$suite(/[^[:space:]]+)?"; then
        evidence_targets_suite=1
      fi
    done <<EOF
$evidence_commands
EOF
    [ "$evidence_targets_suite" -eq 1 ] \
      || fail "$test_id has no successful evidence command scoped to $suite"
  fi

  checked=$((checked + 1))
done <<EOF
$rows
EOF

[ "$checked" -gt 0 ] || fail "no acceptance Test ID rows match the requested scope"
echo "PASS: $checked acceptance test row(s) have valid traceability in $MODE mode."
