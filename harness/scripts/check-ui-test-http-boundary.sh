#!/usr/bin/env bash
# Verify the fail-closed boundary between production composition and the UI-test
# loopback HTTP fixture. Runtime execution remains owned by XCUITest.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${UI_TEST_HTTP_PROJECT_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --project-root)
            [[ "$#" -ge 2 ]] || { echo "ERROR: --project-root requires a path" >&2; exit 2; }
            PROJECT_ROOT="$(cd "$2" && pwd -P)"
            shift 2
            ;;
        --help|-h)
            echo "Usage: check-ui-test-http-boundary.sh [--project-root <path>]"
            exit 0
            ;;
        *)
            echo "ERROR: unknown argument: $1" >&2
            exit 2
            ;;
    esac
done

APP_ROOT="$PROJECT_ROOT/NotesTakingAppiOS"
UI_TEST_ROOT="$PROJECT_ROOT/NotesTakingAppiOSUITests"
CONFIG="$APP_ROOT/Support/UITestLaunchConfiguration.swift"
HARNESS="$UI_TEST_ROOT/UITestHTTPTestCase.swift"

if [[ ! -d "$APP_ROOT" || ! -d "$UI_TEST_ROOT" ]]; then
    echo "PASS: UI-test HTTP boundary is not applicable (no iOS app/UI-test targets)"
    exit 0
fi

failures=0
fail() {
    echo "FAIL: $1" >&2
    failures=1
}

if rg -n --glob '*.swift' 'UITestFixtures|usesUITestFixtureStore' "$APP_ROOT"; then
    fail "production source still contains fixture seeding or sync-bypass symbols"
fi

[[ -f "$CONFIG" ]] || fail "missing composition launch configuration: $CONFIG"
[[ -f "$HARNESS" ]] || fail "missing shared UI-test HTTP harness: $HARNESS"

if [[ -f "$CONFIG" ]]; then
    grep -Fq 'guard arguments.contains(uiTestingArgument)' "$CONFIG" \
        || fail "launch configuration is not gated by -UITesting"
    grep -Fq 'host == "127.0.0.1" || host == "::1"' "$CONFIG" \
        || fail "launch configuration does not enforce loopback hosts"
    grep -Fq 'return .uiTestFailure' "$CONFIG" \
        || fail "launch configuration does not fail closed for invalid UI-test configuration"
fi

if [[ -f "$HARNESS" ]]; then
    grep -Fq 'try fixture.start()' "$HARNESS" || fail "UI-test harness does not start the server before launch"
    grep -Fq 'fixture.stop()' "$HARNESS" || fail "UI-test harness does not stop the server at teardown"
    grep -Fq 'fixture.configure(for: launchArguments)' "$HARNESS" \
        || fail "UI-test harness does not select server state before launch"
    grep -Fq '"-UITestAPIBaseURL"' "$HARNESS" \
        || fail "UI-test harness does not pass the loopback endpoint"
fi

while IFS= read -r file; do
    [[ "$file" == "$HARNESS" ]] && continue
    if grep -Eq 'class[[:space:]].*:[[:space:]]*XCTestCase' "$file"; then
        fail "fixture-dependent UI test bypasses UITestHTTPTestCase: $file"
    fi
done < <(rg -l --glob '*.swift' -- '-UITest[A-Za-z0-9_]+' "$UI_TEST_ROOT" || true)

if [[ "$failures" -ne 0 ]]; then
    exit 1
fi

echo "PASS: UI-test fixture state is test-target-owned and uses a fail-closed loopback HTTP boundary"
