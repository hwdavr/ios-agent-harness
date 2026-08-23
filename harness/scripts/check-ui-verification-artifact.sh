#!/usr/bin/env bash
# Validates the ad-hoc UI verification JSON artifact. A PASS must be backed by
# a design-anchor manifest and a machine-readable XCUITest frame capture; this
# script calculates each anchor delta instead of trusting report prose.

set -e

DOCS_DIR="${1:-}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

require_relative_asset() {
  local path="$1"
  local label="$2"

  [ -n "$path" ] && [ "$path" != "null" ] \
    || fail "$REPORT must declare $label"
  case "$path" in
    /*|*..*) fail "$REPORT $label must stay under $DOCS_DIR" ;;
  esac
  [ -s "$DOCS_DIR/$path" ] \
    || fail "$REPORT references missing or empty $label $path"
}

require_runtime_asset() {
  local path="$1"

  [ -n "$path" ] && [ "$path" != "null" ] \
    || fail "$RUNTIME_EVIDENCE must declare a screenshot path"
  case "$path" in
    evidence/*) ;;
    *) fail "$RUNTIME_EVIDENCE screenshot must stay under evidence/" ;;
  esac
  case "$path" in
    *..*) fail "$RUNTIME_EVIDENCE screenshot path must not escape evidence/" ;;
  esac
  [ -s "$DOCS_DIR/$path" ] \
    || fail "$RUNTIME_EVIDENCE references missing or empty screenshot $path"
  screenshot_bytes=$(wc -c < "$DOCS_DIR/$path" | tr -d ' ')
  [ "$screenshot_bytes" -ge 1024 ] \
    || fail "$RUNTIME_EVIDENCE screenshot $path is too small to be reliable evidence"
}

if [ -z "$DOCS_DIR" ]; then
  echo "Usage: bash harness/scripts/check-ui-verification-artifact.sh <docs-directory>" >&2
  exit 2
fi

[ -d "$DOCS_DIR" ] || fail "missing artifact directory $DOCS_DIR"

REPORT="$DOCS_DIR/ui_verification.json"
[ -f "$REPORT" ] || fail "missing $REPORT"

# Validate it is parseable JSON
jq empty "$REPORT" 2>/dev/null \
  || fail "$REPORT is not valid JSON"

# Required top-level keys
for key in version reference_design design_anchors runtime_evidence \
           build_and_static_checks normalization scope structural_verification \
           defect_classification ai_visual_evaluation verdict; do
  jq -e ".$key" "$REPORT" >/dev/null 2>&1 \
    || fail "$REPORT is missing required key '$key'"
done

# Verdict must have a result
VERDICT_RESULT=$(jq -r '.verdict.result' "$REPORT" 2>/dev/null)
[ -n "$VERDICT_RESULT" ] && [ "$VERDICT_RESULT" != "null" ] \
  || fail "$REPORT verdict must declare a result"

# Reference design asset must exist on disk.
REFERENCE_ASSET=$(jq -r '.reference_design' "$REPORT" 2>/dev/null)
case "$REFERENCE_ASSET" in
  design/*) ;;
  *) fail "$REPORT reference_design must stay under design/" ;;
esac
require_relative_asset "$REFERENCE_ASSET" "reference_design asset"

# A PASS must point at source-of-truth design anchors and raw runtime frames.
DESIGN_ANCHORS=$(jq -r '.design_anchors' "$REPORT" 2>/dev/null)
case "$DESIGN_ANCHORS" in
  design/*) ;;
  *) fail "$REPORT design_anchors must stay under design/" ;;
esac
require_relative_asset "$DESIGN_ANCHORS" "design_anchors asset"

RUNTIME_EVIDENCE=$(jq -r '.runtime_evidence' "$REPORT" 2>/dev/null)
case "$RUNTIME_EVIDENCE" in
  evidence/*) ;;
  *) fail "$REPORT runtime_evidence must stay under evidence/" ;;
esac
require_relative_asset "$RUNTIME_EVIDENCE" "runtime_evidence asset"

jq empty "$DOCS_DIR/$DESIGN_ANCHORS" 2>/dev/null \
  || fail "$DESIGN_ANCHORS is not valid JSON"
jq empty "$DOCS_DIR/$RUNTIME_EVIDENCE" 2>/dev/null \
  || fail "$RUNTIME_EVIDENCE is not valid JSON"

jq -e '
  (type == "object") and
  ((.version | type) == "string" or (.version | type) == "number") and
  (.coordinate_space.unit == "pt") and
  (.anchors | type == "array" and length > 0) and
  all(.anchors[];
    (.screen | type == "string" and length > 0) and
    (.element_id | type == "string" and length > 0) and
    (.metric | IN("x", "y", "width", "height")) and
    (.expected | type == "number") and
    (.tolerance_pt | type == "number" and . >= 0)
  )
' "$DOCS_DIR/$DESIGN_ANCHORS" >/dev/null 2>&1 \
  || fail "$DESIGN_ANCHORS must declare non-empty pt anchors with numeric expected and tolerance_pt values"

ANCHOR_COUNT=$(jq '.anchors | length' "$DOCS_DIR/$DESIGN_ANCHORS")
ANCHOR_KEY_COUNT=$(jq '[.anchors[] | [.screen, .element_id, .metric] | join("\\u0001")] | unique | length' "$DOCS_DIR/$DESIGN_ANCHORS")
[ "$ANCHOR_COUNT" -eq "$ANCHOR_KEY_COUNT" ] \
  || fail "$DESIGN_ANCHORS contains duplicate screen, element_id, metric anchors"

jq -e '(type == "object") and ((.version | type) == "string" or (.version | type) == "number") and (.producer.kind == "XCUITest") and (.producer.test_name | type == "string" and length > 0) and (.coordinate_space.unit == "pt") and (.normalization.theme | type == "string" and length > 0) and (.normalization.font_scale | type == "number") and (.normalization.locale | type == "string" and length > 0) and (.screens | type == "array" and length > 0) and all(.screens[]; (.name | type == "string" and length > 0) and (.screenshot | type == "string" and length > 0) and (.elements | type == "object") and all(.elements[]; (.x | type == "number") and (.y | type == "number") and (.width | type == "number" and . >= 0) and (.height | type == "number" and . >= 0)))' "$DOCS_DIR/$RUNTIME_EVIDENCE" >/dev/null 2>&1 \
  || fail "$RUNTIME_EVIDENCE must be an XCUITest pt-frame capture with screenshots and numeric element frames"

SCREEN_COUNT=$(jq '.screens | length' "$DOCS_DIR/$RUNTIME_EVIDENCE")
SCREEN_NAME_COUNT=$(jq '[.screens[] | .name] | unique | length' "$DOCS_DIR/$RUNTIME_EVIDENCE")
[ "$SCREEN_COUNT" -eq "$SCREEN_NAME_COUNT" ] \
  || fail "$RUNTIME_EVIDENCE contains duplicate screen names"

while IFS= read -r screenshot; do
  require_runtime_asset "$screenshot"
done <<EOF
$(jq -r '.screens[].screenshot' "$DOCS_DIR/$RUNTIME_EVIDENCE")
EOF

# Normalization claims must agree with the runtime capture rather than merely
# being self-reported in the verification summary.
jq -e --slurpfile runtime "$DOCS_DIR/$RUNTIME_EVIDENCE" '
  .normalization.theme.match == true and
  .normalization.font_scale.match == true and
  .normalization.locale.match == true and
  .normalization.theme.runtime == $runtime[0].normalization.theme and
  .normalization.font_scale.runtime == $runtime[0].normalization.font_scale and
  .normalization.locale.runtime == $runtime[0].normalization.locale
' "$REPORT" >/dev/null 2>&1 \
  || fail "$REPORT normalization must match the runtime evidence and declare all matches true"

# Structural verification must have at least one check
CHECKS_COUNT=$(jq '.structural_verification.checks | length' "$REPORT" 2>/dev/null)
[ "$CHECKS_COUNT" -gt 0 ] 2>/dev/null \
  || fail "$REPORT needs at least one structural_verification check"

jq -e '
  .structural_verification.checks | type == "array" and
  all(.[];
    (.screen | type == "string" and length > 0) and
    (.element_id | type == "string" and length > 0) and
    (.metric | IN("x", "y", "width", "height")) and
    (has("expected") | not) and (has("actual") | not) and
    (has("within_tolerance") | not) and (has("result") | not)
  )
' "$REPORT" >/dev/null 2>&1 \
  || fail "$REPORT structural checks must identify screen, element_id, and metric without self-reported expected or actual values"

CHECK_KEY_COUNT=$(jq '[.structural_verification.checks[] | [.screen, .element_id, .metric] | join("\\u0001")] | unique | length' "$REPORT")
[ "$CHECKS_COUNT" -eq "$CHECK_KEY_COUNT" ] \
  || fail "$REPORT structural_verification contains duplicate screen, element_id, metric checks"

ANCHOR_KEYS=$(jq -c '[.anchors[] | [.screen, .element_id, .metric] | join("\\u0001")] | sort' "$DOCS_DIR/$DESIGN_ANCHORS")
CHECK_KEYS=$(jq -c '[.structural_verification.checks[] | [.screen, .element_id, .metric] | join("\\u0001")] | sort' "$REPORT")
[ "$ANCHOR_KEYS" = "$CHECK_KEYS" ] \
  || fail "$REPORT structural checks must cover every design anchor exactly once"

while IFS=$'\t' read -r screen element_id metric expected tolerance; do
  actual=$(jq -r --arg screen "$screen" --arg element_id "$element_id" --arg metric "$metric" '
    .screens[] | select(.name == $screen) | .elements[$element_id][$metric]
  ' "$DOCS_DIR/$RUNTIME_EVIDENCE")
  [ -n "$actual" ] && [ "$actual" != "null" ] \
    || fail "$RUNTIME_EVIDENCE is missing $screen/$element_id/$metric required by $DESIGN_ANCHORS"
  if ! awk -v actual="$actual" -v expected="$expected" -v tolerance="$tolerance" 'BEGIN {
    delta = actual - expected
    if (delta < 0) delta = -delta
    exit !(delta <= tolerance)
  }'; then
    fail "$screen/$element_id/$metric is outside tolerance: expected $expected pt ± $tolerance pt, measured $actual pt"
  fi
done <<EOF
$(jq -r '.anchors[] | [.screen, .element_id, .metric, .expected, .tolerance_pt] | @tsv' "$DOCS_DIR/$DESIGN_ANCHORS")
EOF

# AI visual evaluation must have a status
AI_STATUS=$(jq -r '.ai_visual_evaluation.status' "$REPORT" 2>/dev/null)
[ -n "$AI_STATUS" ] && [ "$AI_STATUS" != "null" ] \
  || fail "$REPORT ai_visual_evaluation must declare a status"

echo "PASS: UI verification evidence is valid; every design anchor was calculated from XCUITest frame evidence."
