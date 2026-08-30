#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CHECKER="$REPO_ROOT/harness/scripts/check-coverage.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/coverage-contract-test.XXXXXX")
fake_bin="$fixture_root/bin"
result_bundle="$fixture_root/Test.xcresult"
mkdir -p "$fake_bin" "$result_bundle"
trap 'rm -rf "$fixture_root"' EXIT

fixture_json='{
  "targets": [
    {
      "name": "NotesTakingAppiOS.app",
      "lineCoverage": 0.85,
      "files": [
        {"name": "NewViewModel.swift", "path": "/project/NotesTakingApp/ViewModels/NewViewModel.swift", "coveredLines": 9, "executableLines": 10},
        {"name": "AppSupport.swift", "path": "/project/NotesTakingApp/AppSupport.swift", "coveredLines": 8, "executableLines": 10}
      ]
    },
    {
      "name": "NotesTakingAppiOSTests.xctest",
      "lineCoverage": 1.0,
      "files": [
        {"name": "NewViewModelTests.swift", "path": "/project/NotesTakingAppTests/NewViewModelTests.swift", "coveredLines": 10, "executableLines": 10}
      ]
    },
    {
      "name": "SwiftMath",
      "lineCoverage": 0.0,
      "files": [
        {"name": "ThirdParty.swift", "path": "/packages/SwiftMath/ThirdParty.swift", "coveredLines": 0, "executableLines": 100}
      ]
    }
  ]
}'

printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\\n" "$COVERAGE_FIXTURE_JSON"' \
  > "$fake_bin/xcrun"
chmod +x "$fake_bin/xcrun"

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$(PATH="$fake_bin:$PATH" COVERAGE_FIXTURE_JSON="$fixture_json" "$@" 2>&1); then
    echo "FAIL: coverage checker unexpectedly passed" >&2
    exit 1
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "FAIL: coverage checker did not report '$expected'" >&2
    printf '%s\n' "$output" >&2
    exit 1
  }
}

PATH="$fake_bin:$PATH" COVERAGE_FIXTURE_JSON="$fixture_json" \
  bash "$CHECKER" "$result_bundle" --exclude-target SwiftMath \
  --min-file NewViewModel.swift=90

expect_failure "overall project-owned line coverage 20.77% is below" \
  bash "$CHECKER" "$result_bundle"

expect_failure "excluded target was not found exactly once: MissingTarget" \
  bash "$CHECKER" "$result_bundle" --exclude-target MissingTarget

expect_failure "file NewViewModel.swift coverage 90.00% is below" \
  bash "$CHECKER" "$result_bundle" --exclude-target SwiftMath \
  --min-file NewViewModel.swift=95

echo "PASS: coverage checker enforces weighted thresholds, explicit exclusions, and per-file thresholds."
