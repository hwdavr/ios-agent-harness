#!/usr/bin/env bash

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-ui-verification-artifact.sh"
STAGE_VALIDATOR="$REPO_ROOT/harness/scripts/check-stage-artifacts.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/ui-verification-artifact-test.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT

write_valid_fixture() {
  local docs_dir="$1"
  mkdir -p "$docs_dir/design" "$docs_dir/evidence"
  printf 'reference mockup' > "$docs_dir/design/mockup_editor.png"
  printf '%2048s' 'x' > "$docs_dir/evidence/editor_actual.png"
  cat > "$docs_dir/design/design_anchors.json" <<'FIXTURE'
{
  "version": "1",
  "coordinate_space": { "unit": "pt" },
  "anchors": [
    {
      "screen": "editor",
      "element_id": "editor_row_handle_visual",
      "metric": "height",
      "expected": 24,
      "tolerance_pt": 2
    }
  ]
}
FIXTURE
  cat > "$docs_dir/evidence/ui_frames.json" <<'FIXTURE'
{
  "version": "1",
  "producer": {
    "kind": "XCUITest",
    "test_name": "NotesTakingAppiOSUITests/testEditorVisualAnchors"
  },
  "coordinate_space": { "unit": "pt" },
  "normalization": { "theme": "light", "font_scale": 1, "locale": "en-US" },
  "screens": [
    {
      "name": "editor",
      "screenshot": "evidence/editor_actual.png",
      "elements": {
        "editor_row_handle_visual": { "x": 344, "y": 288, "width": 24, "height": 25 }
      }
    }
  ]
}
FIXTURE
  cat > "$docs_dir/ui_verification.json" <<'FIXTURE'
{
  "version": "2",
  "reference_design": "design/mockup_editor.png",
  "design_anchors": "design/design_anchors.json",
  "runtime_evidence": "evidence/ui_frames.json",
  "build_and_static_checks": { "xcodebuild build": "PASS", "swiftlintCheck": "PASS" },
  "instrumented_tests": { "passed": "1", "total": "1" },
  "normalization": {
    "reference_resolution": "390x844",
    "runtime_resolution": "393x873",
    "theme": { "reference": "light", "runtime": "light", "match": true },
    "font_scale": { "reference": 1, "runtime": 1, "match": true },
    "locale": { "reference": "en-US", "runtime": "en-US", "match": true }
  },
  "scope": { "type": "partial", "area_of_interest": "table handle", "rationale": "spec US-2", "in_scope_regions": ["table_handle"], "out_of_scope_regions": ["header"] },
  "region_decomposition": [{ "region": "table_handle", "bounds_dp": { "x_start": 0, "x_end": 390, "y_start": 200, "y_end": 600 } }],
  "structural_verification": {
    "checks": [{ "region": "table_handle", "screen": "editor", "element_id": "editor_row_handle_visual", "metric": "height", "note": "The handle stays compact." }]
  },
  "defect_classification": [],
  "ai_visual_evaluation": { "status": "PASS", "area_of_interest": "table handle", "issues": [], "regression_summary": { "header": "PASS" } },
  "verdict": { "result": "PASS", "reason": "", "critical_findings": 0, "major_findings_unresolved": 0, "minor_findings_warnings": 0 }
}
FIXTURE
}

expect_failure() {
  local expected="$1"
  shift
  local output
  if output=$("$@" 2>&1); then
    echo "FAIL: validator unexpectedly accepted fixture" >&2
    exit 1
  fi
  printf '%s\n' "$output" | grep -Fq "$expected" || {
    echo "FAIL: validator did not report '$expected'." >&2
    printf '%s\n' "$output" >&2
    exit 1
  }
}

# Test 1: measured XCUITest frame evidence passes both artifact gates.
valid="$fixture_root/valid"
write_valid_fixture "$valid"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$valid")
(cd "$REPO_ROOT" && bash "$STAGE_VALIDATOR" create-ui-and-verify ui-verification "$valid")

# Test 2: an oversized component cannot self-attest PASS; the validator uses
# the captured 32 pt height rather than any report claim.
oversized="$fixture_root/oversized-self-attestation"
write_valid_fixture "$oversized"
jq '.screens[0].elements.editor_row_handle_visual.height = 32' \
  "$oversized/evidence/ui_frames.json" > "$oversized/evidence/ui_frames.tmp"
mv "$oversized/evidence/ui_frames.tmp" "$oversized/evidence/ui_frames.json"
expect_failure "editor/editor_row_handle_visual/height is outside tolerance: expected 24 pt ± 2 pt, measured 32 pt" \
  bash "$VALIDATOR" "$oversized"

# Test 3: the previous free-text schema is a false pass and must now fail.
legacy="$fixture_root/legacy-free-text"
write_valid_fixture "$legacy"
jq 'del(.design_anchors, .runtime_evidence) | .structural_verification.checks = [{"element":"editor_row_handle_visual", "expected":"24 pt", "actual":"24 pt", "result":"PASS"}]' \
  "$legacy/ui_verification.json" > "$legacy/ui_verification.tmp"
mv "$legacy/ui_verification.tmp" "$legacy/ui_verification.json"
expect_failure "missing required key 'design_anchors'" bash "$VALIDATOR" "$legacy"

# Test 4: missing runtime screenshot evidence fails even when frames are present.
missing_screenshot="$fixture_root/missing-screenshot"
write_valid_fixture "$missing_screenshot"
rm "$missing_screenshot/evidence/editor_actual.png"
expect_failure "references missing or empty screenshot evidence/editor_actual.png" \
  bash "$VALIDATOR" "$missing_screenshot"

# Test 5: a token file cannot stand in for a real screenshot capture.
tiny_screenshot="$fixture_root/tiny-screenshot"
write_valid_fixture "$tiny_screenshot"
printf 'not a capture' > "$tiny_screenshot/evidence/editor_actual.png"
expect_failure "screenshot evidence/editor_actual.png is too small to be reliable evidence" \
  bash "$VALIDATOR" "$tiny_screenshot"

echo "PASS: UI verification artifact validator calculates XCUITest frame deltas and rejects self-attested false passes."
