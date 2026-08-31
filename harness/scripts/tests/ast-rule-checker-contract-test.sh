#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
FIXTURE_ROOT="$PROJECT_ROOT/harness/scripts/fixtures/ast-checker"
ARCHITECTURE_CHECKER="$PROJECT_ROOT/harness/scripts/check-architecture-rules.sh"
SWIFTUI_CHECKER="$PROJECT_ROOT/harness/scripts/check-swiftui-rules.sh"
LOCALIZATION_CHECKER="$PROJECT_ROOT/harness/scripts/check-localization-rules.sh"
NAVIGATION_CHECKER="$PROJECT_ROOT/harness/scripts/check-navigation-rules.sh"
NAVIGATION_FIXTURE_ROOT="$PROJECT_ROOT/harness/scripts/fixtures/navigation-rules"

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

expect_success() {
    local label="$1"
    shift
    local output status
    set +e
    output=$("$@" 2>&1)
    status=$?
    set -e
    if [[ $status -ne 0 ]]; then
        echo "$output" >&2
        fail "$label unexpectedly failed"
    fi
}

expect_failure_with() {
    local label="$1"
    local expected="$2"
    shift 2
    local output status
    set +e
    output=$("$@" 2>&1)
    status=$?
    set -e
    if [[ $status -eq 0 ]]; then
        echo "$output" >&2
        fail "$label unexpectedly passed"
    fi
    printf '%s\n' "$output" | rg -Fq "$expected" || {
        echo "$output" >&2
        fail "$label did not report: $expected"
    }
}

expect_success "architecture valid fixture" \
    env ARCHITECTURE_SOURCE_ROOT="$FIXTURE_ROOT/valid/architecture" \
    bash "$ARCHITECTURE_CHECKER" --all
expect_failure_with "architecture invalid fixture" "Domain file importing SwiftUI/UIKit" \
    env ARCHITECTURE_SOURCE_ROOT="$FIXTURE_ROOT/invalid/architecture" \
    bash "$ARCHITECTURE_CHECKER" --all
expect_success "architecture comment/string false-positive fixture" \
    env ARCHITECTURE_SOURCE_ROOT="$FIXTURE_ROOT/false-positive/architecture" \
    bash "$ARCHITECTURE_CHECKER" --all

expect_success "SwiftUI valid fixture" \
    bash "$SWIFTUI_CHECKER" --all "$FIXTURE_ROOT/valid/swiftui"
expect_failure_with "SwiftUI invalid fixture" "VStack with ForEach" \
    bash "$SWIFTUI_CHECKER" --all "$FIXTURE_ROOT/invalid/swiftui"
expect_success "SwiftUI comment/string false-positive fixture" \
    bash "$SWIFTUI_CHECKER" --all "$FIXTURE_ROOT/false-positive/swiftui"

expect_success "localization valid fixture" \
    env LOCALIZATION_SOURCE_ROOT="$FIXTURE_ROOT/valid/localization" \
    bash "$LOCALIZATION_CHECKER"
expect_failure_with "localization invalid fixture" "NSLocalizedString is not allowed" \
    env LOCALIZATION_SOURCE_ROOT="$FIXTURE_ROOT/invalid/localization" \
    bash "$LOCALIZATION_CHECKER"
expect_success "localization comment/string false-positive fixture" \
    env LOCALIZATION_SOURCE_ROOT="$FIXTURE_ROOT/false-positive/localization" \
    bash "$LOCALIZATION_CHECKER"

expect_success "navigation valid fixture" \
    env NAVIGATION_SOURCE_ROOT="$NAVIGATION_FIXTURE_ROOT/valid" \
    bash "$NAVIGATION_CHECKER"
expect_failure_with "navigation invalid fixture" "route/destination enums must conform to Hashable" \
    env NAVIGATION_SOURCE_ROOT="$NAVIGATION_FIXTURE_ROOT/invalid" \
    bash "$NAVIGATION_CHECKER"
expect_success "navigation comment false-positive fixture" \
    env NAVIGATION_SOURCE_ROOT="$FIXTURE_ROOT/false-positive/navigation" \
    bash "$NAVIGATION_CHECKER"

echo "PASS: AST checker contracts cover valid, invalid, multiline, and comment/string false-positive fixtures."
