#!/usr/bin/env bash
# Contract test for the Critical Journey Registry validator and runner.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-journey-registry.sh"
FIXTURE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/journey-registry-contract.XXXXXX")"
trap 'rm -rf "$FIXTURE_ROOT"' EXIT

fail_test() {
  echo "FAIL: $1" >&2
  exit 1
}

expect_success() {
  local output
  if ! output=$("$@" 2>&1); then
    echo "$output" >&2
    fail_test "command unexpectedly failed: $*"
  fi
}

expect_failure() {
  local expected_exit="$1"
  local expected_text="$2"
  shift 2
  local output
  set +e
  output=$("$@" 2>&1)
  local status=$?
  set -e

  if [ "$status" -eq 0 ]; then
    echo "$output" >&2
    fail_test "command unexpectedly succeeded: $*"
  fi

  if [ "$status" -ne "$expected_exit" ]; then
    echo "$output" >&2
    fail_test "expected exit code $expected_exit, got $status: $*"
  fi

  printf '%s\n' "$output" | grep -Fq "$expected_text" || {
    echo "$output" >&2
    fail_test "output did not contain expected text '$expected_text': $*"
  }
}

# Setup dummy project fixture
mkdir -p "$FIXTURE_ROOT/docs/product"
mkdir -p "$FIXTURE_ROOT/NotesTakingAppiOSUITests"

cat << 'EOF' > "$FIXTURE_ROOT/NotesTakingAppiOSUITests/DummyJourneyTests.swift"
import XCTest

final class DummyJourneyTests: XCTestCase {
    func validJourneyMethod() {
    }
}
EOF

# Case 1: Valid registry passes validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "Home -> Editor -> save -> return to Home"
    introduced_by: test-feature/US-1
    destinations:
      - home
      - editor
    test_file: NotesTakingAppiOSUITests/DummyJourneyTests.swift
    test_method: validJourneyMethod
    xcode_selector: "NotesTakingAppiOSUITests/DummyJourneyTests/validJourneyMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
EOF

expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --validate

# Case 2: Missing registry file fails
expect_failure 2 "Journey registry file not found" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/harness/non-existent.yaml" \
  --validate

# Case 3: Missing required field fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "Home -> Editor -> save"
    introduced_by: test-feature/US-1
    destinations:
      - home
    test_file: NotesTakingAppiOSUITests/DummyJourneyTests.swift
    # Missing test_method, xcode_selector, boundary, post_return_assertion
EOF

expect_failure 2 "missing required field 'test_method'" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --validate

# Case 4: Non-existent test_file fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "Home -> Editor -> save"
    introduced_by: test-feature/US-1
    destinations:
      - home
    test_file: NotesTakingAppiOSUITests/NoSuchTests.swift
    test_method: validJourneyMethod
    xcode_selector: "NotesTakingAppiOSUITests/NoSuchTests/validJourneyMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
EOF

expect_failure 2 "test_file does not exist" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --validate

# Case 5: Non-existent test_method in existing test file fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "Home -> Editor -> save"
    introduced_by: test-feature/US-1
    destinations:
      - home
    test_file: NotesTakingAppiOSUITests/DummyJourneyTests.swift
    test_method: noSuchMethod
    xcode_selector: "NotesTakingAppiOSUITests/DummyJourneyTests/noSuchMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
EOF

expect_failure 2 "test_method 'noSuchMethod' not found" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --validate

# Case 6: Duplicate journey ID fails validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "Home -> Editor -> save"
    introduced_by: test-feature/US-1
    destinations:
      - home
    test_file: NotesTakingAppiOSUITests/DummyJourneyTests.swift
    test_method: validJourneyMethod
    xcode_selector: "NotesTakingAppiOSUITests/DummyJourneyTests/validJourneyMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
  - id: J-DUMMY-JOURNEY
    description: "Another journey with duplicate ID"
    introduced_by: test-feature/US-2
    destinations:
      - home
    test_file: NotesTakingAppiOSUITests/DummyJourneyTests.swift
    test_method: validJourneyMethod
    xcode_selector: "NotesTakingAppiOSUITests/DummyJourneyTests/validJourneyMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
EOF

expect_failure 2 "duplicate journey id 'J-DUMMY-JOURNEY'" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --validate

# Case 7: Placeholder values fail validation
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "{insert description}"
    introduced_by: test-feature/US-1
    destinations:
      - home
    test_file: NotesTakingAppiOSUITests/DummyJourneyTests.swift
    test_method: validJourneyMethod
    xcode_selector: "NotesTakingAppiOSUITests/DummyJourneyTests/validJourneyMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
EOF

expect_failure 2 "has empty or placeholder value" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --validate

# Case 8: --run-one with unknown ID fails with code 2
cat << 'EOF' > "$FIXTURE_ROOT/docs/product/journey-registry.yaml"
journeys:
  - id: J-DUMMY-JOURNEY
    description: "Home -> Editor -> save"
    introduced_by: test-feature/US-1
    destinations:
      - home
    test_file: NotesTakingAppiOSUITests/DummyJourneyTests.swift
    test_method: validJourneyMethod
    xcode_selector: "NotesTakingAppiOSUITests/DummyJourneyTests/validJourneyMethod"
    boundary: "Editor pops back to Home"
    post_return_assertion: "Saved note visible in Home list"
EOF

expect_failure 2 "Journey ID 'J-UNKNOWN' not found in registry" bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --run-one J-UNKNOWN

# Case 9: --run-one and --run-all with --dry-run succeed with code 0
expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --run-one J-DUMMY-JOURNEY \
  --dry-run

expect_success bash "$VALIDATOR" \
  --project-root "$FIXTURE_ROOT" \
  --registry "$FIXTURE_ROOT/docs/product/journey-registry.yaml" \
  --run-all \
  --dry-run

echo "PASS: All 9 journey-registry contract test cases passed."
