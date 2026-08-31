#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
if [[ ! -d "$PROJECT_ROOT/NotesTakingAppiOS" && -d "$PROJECT_ROOT/../NotesTakingAppiOS" ]]; then
    PROJECT_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
fi
CHECKER="$PROJECT_ROOT/harness/scripts/check-navigation-rules.sh"
FIXTURE_ROOT="$PROJECT_ROOT/harness/scripts/fixtures/navigation-rules"
INVALID_FIXTURE="$FIXTURE_ROOT/invalid"
VALID_FIXTURE="$FIXTURE_ROOT/valid"

fail() {
    echo "RED: $1"
    exit 1
}

assert_contains() {
    local output="$1"
    local expected="$2"
    printf '%s\n' "$output" | rg -Fq "$expected" || \
        fail "expected checker output to contain: $expected"
}

if [[ ! -x "$CHECKER" ]]; then
    fail "navigation checker is missing or not executable: $CHECKER"
fi

set +e
invalid_output=$(NAVIGATION_SOURCE_ROOT="$INVALID_FIXTURE" bash "$CHECKER" 2>&1)
invalid_status=$?
set -e

if [[ $invalid_status -eq 0 ]]; then
    echo "$invalid_output"
    fail "invalid navigation fixture unexpectedly passed"
fi

assert_contains "$invalid_output" "root screen must define NavigationStack or NavigationSplitView"
assert_contains "$invalid_output" "do not conditionally replace the root with a destination"
assert_contains "$invalid_output" "route/destination enums must conform to Hashable"
assert_contains "$invalid_output" "optional route arguments require an explicit defaultValue"
assert_contains "$invalid_output" "non-Hashable or complex type"
assert_contains "$invalid_output" "navigation destination as a boolean ViewModel flag"
assert_contains "$invalid_output" "persistent ViewModel route state"
assert_contains "$invalid_output" "auth exit path must clear"

set +e
valid_output=$(NAVIGATION_SOURCE_ROOT="$VALID_FIXTURE" bash "$CHECKER" 2>&1)
valid_status=$?
set -e

if [[ $valid_status -ne 0 ]]; then
    echo "$valid_output"
    fail "compliant navigation fixture failed"
fi

assert_contains "$valid_output" "All navigation rules passed"

set +e
production_output=$(bash "$CHECKER" 2>&1)
production_status=$?
set -e

if [[ $production_status -ne 0 ]]; then
    echo "$production_output"
    fail "compliant production navigation source failed"
fi

assert_contains "$production_output" "All navigation rules passed"

echo "GREEN: navigation checker contract passed for invalid, valid, and production scans."
