#!/usr/bin/env bash
# Contract test for the UI-test loopback boundary checker. It proves the checker
# rejects the two regressions this migration is intended to prevent: production
# fixture branches and fixture-dependent suites bypassing the common harness.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CHECKER="$REPO_ROOT/harness/scripts/check-ui-test-http-boundary.sh"
fixture_root="$(mktemp -d "${TMPDIR:-/tmp}/ui-test-http-boundary.XXXXXX")"
trap 'rm -rf "$fixture_root"' EXIT

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

[ -x "$CHECKER" ] || fail "UI-test HTTP boundary checker is missing or not executable"

bash "$CHECKER" --project-root "$REPO_ROOT"

mkdir -p \
    "$fixture_root/NotesTakingAppiOS/Support" \
    "$fixture_root/NotesTakingAppiOSUITests"

cat > "$fixture_root/NotesTakingAppiOS/Support/UITestLaunchConfiguration.swift" <<'SWIFT'
guard arguments.contains(uiTestingArgument) else { return nil }
host == "127.0.0.1" || host == "::1"
return .uiTestFailure
SWIFT

cat > "$fixture_root/NotesTakingAppiOS/Support/NotesAppComposition.swift" <<'SWIFT'
let apiConfig = UITestLaunchConfiguration.apiConfiguration() ?? .live
SWIFT

cat > "$fixture_root/NotesTakingAppiOS/Support/LegacyFixture.swift" <<'SWIFT'
let usesUITestFixtureStore = true
SWIFT

cat > "$fixture_root/NotesTakingAppiOSUITests/UITestHTTPTestCase.swift" <<'SWIFT'
try fixture.start()
fixture.stop()
fixture.configure(for: launchArguments)
"-UITestAPIBaseURL"
SWIFT

cat > "$fixture_root/NotesTakingAppiOSUITests/BadFixtureUITests.swift" <<'SWIFT'
let fixtureArgument = "-UITestSeed"
final class BadFixtureUITests: XCTestCase {}
SWIFT

if output=$(bash "$CHECKER" --project-root "$fixture_root" 2>&1); then
    echo "$output" >&2
    fail "checker accepted production fixture logic and a bypassing UI test"
fi

printf '%s\n' "$output" | grep -Fq 'production source still contains fixture' \
    || { echo "$output" >&2; fail "checker missed the production fixture regression"; }
printf '%s\n' "$output" | grep -Fq 'fixture-dependent UI test bypasses UITestHTTPTestCase' \
    || { echo "$output" >&2; fail "checker missed the harness bypass regression"; }

echo "PASS: UI-test HTTP boundary checker rejects production fixture branches and direct fixture-test launches"
