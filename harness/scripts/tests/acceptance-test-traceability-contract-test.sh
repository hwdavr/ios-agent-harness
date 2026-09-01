#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-acceptance-test-traceability.sh"
FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/acceptance-traceability-test.XXXXXX")
FEATURE_DIR="$FIXTURE_ROOT/docs/product/2026-09-01-fixture"
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

write_fixture() {
  rm -rf "$FEATURE_DIR"
  mkdir -p "$FEATURE_DIR" "$FIXTURE_ROOT/NotesTakingAppiOSTests" "$FIXTURE_ROOT/sharedContracts/test-scenarios"

  cat > "$FEATURE_DIR/feature_list.json" <<'JSON'
{
  "features": [{
    "id": "US-1",
    "status": "passing",
    "acceptance_test_ids": ["TC-US-1-01"],
    "evidence": [{
      "test_id": "TC-US-1-01",
      "executed_command": "xcodebuild test -only-testing:NotesTakingAppiOSTests/FixtureIntegrationTests",
      "exit_status": 0,
      "result": "Fixture test passed"
    }]
  }]
}
JSON

  cat > "$FEATURE_DIR/sprint-contract.md" <<'EOF'
# Sprint Contract

## Acceptance Test Cases

| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|---|
| TC-US-1-01 | AC-US-1-01 | Swift Testing integration | `NotesTakingAppiOSTests/FixtureIntegrationTests.swift#loadsSharedScenario` | `sharedContracts/test-scenarios/fixture_001.json` | Load the shared response through the production fixture path. | The shared scenario is decoded and the domain result is asserted. | `xcodebuild test -only-testing:NotesTakingAppiOSTests/FixtureIntegrationTests` |
EOF

  cat > "$FIXTURE_ROOT/NotesTakingAppiOSTests/FixtureIntegrationTests.swift" <<'EOF'
import Testing

struct FixtureIntegrationTests {
    @Test
    func loadsSharedScenario() {
        let scenario = "fixture_001.json"
        #expect(!scenario.isEmpty)
    }
}
EOF
  printf '%s\n' '{"id":"fixture_001"}' > "$FIXTURE_ROOT/sharedContracts/test-scenarios/fixture_001.json"
}

write_fixture
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-09-01-fixture --planning
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-09-01-fixture --test US-1
HARNESS_PROJECT_ROOT="$FIXTURE_ROOT" bash "$VALIDATOR" docs/product/2026-09-01-fixture --evaluate

# The former harness accepted a planning row whose method was never implemented.
sed 's/func loadsSharedScenario()/func missingSharedScenario()/' \
  "$FIXTURE_ROOT/NotesTakingAppiOSTests/FixtureIntegrationTests.swift" \
  > "$FIXTURE_ROOT/NotesTakingAppiOSTests/FixtureIntegrationTests.tmp"
mv "$FIXTURE_ROOT/NotesTakingAppiOSTests/FixtureIntegrationTests.tmp" \
  "$FIXTURE_ROOT/NotesTakingAppiOSTests/FixtureIntegrationTests.swift"
expect_failure "declared test method is missing" \
  bash "$VALIDATOR" docs/product/2026-09-01-fixture --test US-1

write_fixture
# A contract scenario cannot be claimed by a different helper or test method.
sed 's/fixture_001.json/other_fixture.json/' \
  "$FIXTURE_ROOT/NotesTakingAppiOSTests/FixtureIntegrationTests.swift" \
  > "$FIXTURE_ROOT/NotesTakingAppiOSTests/FixtureIntegrationTests.tmp"
mv "$FIXTURE_ROOT/NotesTakingAppiOSTests/FixtureIntegrationTests.tmp" \
  "$FIXTURE_ROOT/NotesTakingAppiOSTests/FixtureIntegrationTests.swift"
expect_failure "does not reference declared shared scenario fixture_001.json" \
  bash "$VALIDATOR" docs/product/2026-09-01-fixture --test US-1

write_fixture
# A generic full-suite result does not prove the declared test suite ran.
sed 's/-only-testing:NotesTakingAppiOSTests\/FixtureIntegrationTests//' \
  "$FEATURE_DIR/feature_list.json" > "$FEATURE_DIR/feature_list.tmp"
mv "$FEATURE_DIR/feature_list.tmp" "$FEATURE_DIR/feature_list.json"
expect_failure "has no successful evidence command scoped to FixtureIntegrationTests" \
  bash "$VALIDATOR" docs/product/2026-09-01-fixture --evaluate

echo "PASS: acceptance traceability validator rejects missing methods, scenario drift, and unscoped evidence."
