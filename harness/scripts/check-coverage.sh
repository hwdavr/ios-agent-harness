#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: bash harness/scripts/check-coverage.sh <test-result.xcresult> [options]

Options:
  --exclude-target <name>       Explicitly exclude a target, repeatable.
  --min-overall <percent>       Minimum weighted line coverage (default: 80).
  --min-file <path>=<percent>   Minimum coverage for one file, repeatable.

Coverage from XCTest bundles is excluded automatically. The overall threshold
measures product targets only; use a separate UI-test run when validating which
application lines are exercised by UI tests.
EOF
  exit 2
}

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

is_percent() {
  awk -v value="$1" 'BEGIN { exit !(value ~ /^[0-9]+([.][0-9]+)?$/ && value >= 0 && value <= 100) }'
}

check_threshold() {
  local label="$1"
  local actual="$2"
  local minimum="$3"
  awk -v actual="$actual" -v minimum="$minimum" 'BEGIN { exit !(actual + 1e-9 >= minimum) }' \
    || fail "$label coverage ${actual}% is below the required ${minimum}%"
}

[ "$#" -ge 1 ] || usage

RESULT_BUNDLE="$1"
shift
[ -n "$RESULT_BUNDLE" ] || usage
[ -e "$RESULT_BUNDLE" ] || fail "test result bundle does not exist: $RESULT_BUNDLE"

MIN_OVERALL=80
EXCLUDED_TARGETS=()
MIN_FILES=()

while [ "$#" -gt 0 ]; do
  case "$1" in
    --exclude-target)
      [ "$#" -ge 2 ] || usage
      EXCLUDED_TARGETS+=("$2")
      shift 2
      ;;
    --min-overall)
      [ "$#" -ge 2 ] || usage
      is_percent "$2" || fail "invalid overall threshold: $2"
      MIN_OVERALL="$2"
      shift 2
      ;;
    --min-file)
      [ "$#" -ge 2 ] || usage
      case "$2" in
        *=*)
          file_path="${2%=*}"
          file_threshold="${2##*=}"
          [ -n "$file_path" ] || fail "file threshold has an empty path"
          is_percent "$file_threshold" || fail "invalid file threshold: $file_threshold"
          MIN_FILES+=("$2")
          ;;
        *)
          fail "file threshold must use <path>=<percent>: $2"
          ;;
      esac
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

command -v xcrun >/dev/null 2>&1 || fail "xcrun is required to read XCTest coverage"
command -v jq >/dev/null 2>&1 || fail "jq is required to parse xccov JSON"
command -v awk >/dev/null 2>&1 || fail "awk is required to compare coverage thresholds"

coverage_json=$(mktemp "${TMPDIR:-/tmp}/notes-coverage.XXXXXX")
trap 'rm -f "$coverage_json"' EXIT
xcrun xccov view --report --json "$RESULT_BUNDLE" > "$coverage_json" \
  || fail "xccov could not read $RESULT_BUNDLE"

jq -e 'type == "object" and (.targets | type == "array")' "$coverage_json" >/dev/null \
  || fail "xccov report has no target coverage data"

test_targets_json=$(jq -c '[.targets[] | select((.name // "") | endswith(".xctest")) | .name]' "$coverage_json")
excluded_json='[]'
if [ "$(jq 'length' <<< "$test_targets_json")" -gt 0 ]; then
  test_target_label=$(jq -r 'join(",")' <<< "$test_targets_json")
  echo "Coverage test targets excluded by default: $test_target_label"
fi
if [ "${#EXCLUDED_TARGETS[@]}" -gt 0 ]; then
  excluded_json=$(printf '%s\n' "${EXCLUDED_TARGETS[@]}" | jq -R -s 'split("\n") | map(select(length > 0))')
  for excluded_target in "${EXCLUDED_TARGETS[@]}"; do
    target_count=$(jq --arg target "$excluded_target" '[.targets[] | select(.name == $target)] | length' "$coverage_json")
    [ "$target_count" -eq 1 ] || fail "excluded target was not found exactly once: $excluded_target"
  done
fi

excluded_json=$(jq -cn --argjson explicit "$excluded_json" --argjson test_targets "$test_targets_json" \
  '$explicit + $test_targets | unique')

included_target_count=$(jq --argjson excluded "$excluded_json" '
  [.targets[] | select((.name as $name | ($excluded | index($name)) == null))] | length
' "$coverage_json")
[ "$included_target_count" -gt 0 ] || fail "all coverage targets were excluded"

read -r covered_lines executable_lines <<EOF
$(jq -r --argjson excluded "$excluded_json" '
  [.targets[]
   | select((.name as $name | ($excluded | index($name)) == null))
   | .files[]?]
  | (map(.coveredLines // 0) | add // 0) as $covered
  | (map(.executableLines // 0) | add // 0) as $executable
  | "\($covered) \($executable)"
' "$coverage_json")
EOF

[ "$executable_lines" -gt 0 ] || fail "coverage report contains no executable lines"
overall_percent=$(awk -v covered="$covered_lines" -v executable="$executable_lines" \
  'BEGIN { printf "%.2f", (covered / executable) * 100 }')

if [ "${#EXCLUDED_TARGETS[@]}" -gt 0 ]; then
  excluded_label=$(IFS=,; echo "${EXCLUDED_TARGETS[*]}")
  echo "Coverage targets excluded explicitly: $excluded_label"
fi
echo "Overall project-owned line coverage: ${overall_percent}% (${covered_lines}/${executable_lines})"
check_threshold "overall project-owned line" "$overall_percent" "$MIN_OVERALL"

while IFS=$'\t' read -r target_name target_percent; do
  [ -n "$target_name" ] || continue
  echo "Target: $target_name — ${target_percent}%"
done < <(jq -r --argjson excluded "$excluded_json" '
  .targets[]
  | select((.name as $name | ($excluded | index($name)) == null))
  | "\(.name)\t\((.lineCoverage * 100) | . * 100 | round / 100)"
' "$coverage_json")

if [ "${#MIN_FILES[@]}" -gt 0 ]; then
  for file_spec in "${MIN_FILES[@]}"; do
    file_path="${file_spec%=*}"
    file_threshold="${file_spec##*=}"
    matching_files=$(jq --arg file_path "$file_path" --argjson excluded "$excluded_json" '
      [.targets[]
       | select((.name as $name | ($excluded | index($name)) == null))
       | .files[]?
       | select((.path // "") == $file_path
         or ((.path // "") | endswith("/" + $file_path))
         or (.name // "") == $file_path)]
      | length
    ' "$coverage_json")
    [ "$matching_files" -eq 1 ] \
      || fail "expected exactly one coverage file matching '$file_path', found $matching_files"

    read -r file_covered file_executable <<EOF
$(jq -r --arg file_path "$file_path" --argjson excluded "$excluded_json" '
    [.targets[]
     | select((.name as $name | ($excluded | index($name)) == null))
     | .files[]?
     | select((.path // "") == $file_path
       or ((.path // "") | endswith("/" + $file_path))
       or (.name // "") == $file_path)]
    | "\(.[0].coveredLines // 0) \(.[0].executableLines // 0)"
' "$coverage_json")
EOF
    [ "$file_executable" -gt 0 ] || fail "coverage file has no executable lines: $file_path"
    file_percent=$(awk -v covered="$file_covered" -v executable="$file_executable" \
      'BEGIN { printf "%.2f", (covered / executable) * 100 }')
    echo "File: $file_path — ${file_percent}% (${file_covered}/${file_executable})"
    check_threshold "file $file_path" "$file_percent" "$file_threshold"
  done
fi

echo "PASS: coverage thresholds met."
