#!/usr/bin/env bash
# Ensures every final visual verification command is declared in the sprint
# contract, has successful connected-test evidence, and is accompanied by
# reference-anchor proof before a feature passes.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FEATURE_DIR="${1:-}"
MODE="${2:---evaluate}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

if [ -z "$FEATURE_DIR" ]; then
  echo "Usage: bash harness/scripts/check-visual-evidence-contract.sh <feature-directory> [--planning|--evaluate]" >&2
  exit 2
fi
[ "$MODE" = "--planning" ] || [ "$MODE" = "--evaluate" ] || fail "mode must be --planning or --evaluate"

FEATURE_JSON="$FEATURE_DIR/feature_list.json"
CONTRACT="$FEATURE_DIR/sprint-contract.md"
ROOT_DIR="${HARNESS_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
[ -f "$FEATURE_JSON" ] || fail "missing $FEATURE_JSON"
[ -f "$CONTRACT" ] || fail "missing $CONTRACT"

VISUAL_OWNER_COUNT=$(jq '[.features[]? | select(.requires_visual_verification == true)] | length' "$FEATURE_JSON")
if [ "$VISUAL_OWNER_COUNT" -eq 0 ]; then
  echo "PASS: no visual-verification owner is declared."
  exit 0
fi
[ "$VISUAL_OWNER_COUNT" -eq 1 ] || fail "feature_list.json must declare exactly one visual-verification owner"

VISUAL_OWNER=$(jq -r '.features[] | select(.requires_visual_verification == true) | .id' "$FEATURE_JSON")
CONTRACT_ROWS=$(grep -E "^\|[[:space:]]*TC-${VISUAL_OWNER}-VIS-[^|[:space:]]+[[:space:]]*\|" "$CONTRACT" || true)
[ -n "$CONTRACT_ROWS" ] || fail "visual-verification owner $VISUAL_OWNER has no visual rows in sprint-contract.md"

CONTRACT_IDS=$(printf '%s\n' "$CONTRACT_ROWS" | sed -n 's/^|[[:space:]]*\(TC-[^|[:space:]]*-VIS-[^|[:space:]]*\)[[:space:]]*|.*/\1/p')
[ -n "$CONTRACT_IDS" ] || fail "visual rows for $VISUAL_OWNER have no parseable Test IDs"

VISUAL_DETAIL_ROWS=$(printf '%s\n' "$CONTRACT_ROWS" | grep -E 'VisualFlowTests?(\.swift)?#[A-Za-z0-9_]+' || true)
[ -n "$VISUAL_DETAIL_ROWS" ] \
  || fail "visual rows must include a dedicated *VisualFlowTests.swift test method; functional test classes cannot produce visual evidence"

while IFS= read -r contract_row; do
  [ -n "$contract_row" ] || continue
  printf '%s\n' "$contract_row" | grep -Eq 'VisualFlowTests?(\.swift)?#[A-Za-z0-9_]+' \
    || fail "visual rows must name a dedicated *VisualFlowTests.swift test method; functional test classes cannot produce visual evidence"
done <<EOF
$VISUAL_DETAIL_ROWS
EOF

FEATURE_IDS=$(jq -r --arg owner "$VISUAL_OWNER" '
  .features[]
  | select(.id == $owner)
  | (.acceptance_test_ids // [])[]
  | select(test("-VIS-"))
' "$FEATURE_JSON")

for test_id in $CONTRACT_IDS; do
  printf '%s\n' "$FEATURE_IDS" | grep -Fxq "$test_id" \
    || fail "$test_id is declared in sprint-contract.md but missing from feature_list.json acceptance_test_ids"

  EVIDENCE_COUNT=$(jq --arg owner "$VISUAL_OWNER" --arg id "$test_id" '
    [
      .features[]
      | select(.id == $owner)
      | (.evidence // [])[]
      | select(.test_id == $id and .exit_status == 0 and ((.executed_command // "") | contains("xcodebuild test")))
    ] | length
  ' "$FEATURE_JSON")
  if [ "$MODE" = "--evaluate" ]; then
    [ "$EVIDENCE_COUNT" -gt 0 ] \
      || fail "$test_id has no successful connected-test evidence in feature_list.json"
  fi
done

for test_id in $FEATURE_IDS; do
  printf '%s\n' "$CONTRACT_IDS" | grep -Fxq "$test_id" \
    || fail "$test_id is in feature_list.json but missing from sprint-contract.md"
done

VISUAL_COMMANDS=$(jq -r --arg owner "$VISUAL_OWNER" '
  .features[]
  | select(.id == $owner)
  | (.verification // [])[]
  | select(test("xcodebuild test") and test("testInstrumentationRunnerArguments.class=.*#"))
' "$FEATURE_JSON")
VISUAL_METHODS=""
while IFS= read -r command; do
  [ -n "$command" ] || continue
  printf '%s\n' "$command" | grep -Eq -- '-only-testing:[^[:space:]\"]*/[^[:space:]\"]*VisualFlowTests?/[A-Za-z0-9_]+' \
    || fail "visual verification commands must use a method-scoped -only-testing selector for a dedicated *VisualFlowTests class"
  method=$(printf '%s\n' "$command" | sed -n 's/.*#\([^[:space:]\"]*\).*/\1/p')
  [ -n "$method" ] || continue
  VISUAL_METHODS="$VISUAL_METHODS
$method"
  printf '%s\n' "$CONTRACT_ROWS" | grep -Fq "$method" \
    || fail "visual verification method $method is not named by a $VISUAL_OWNER visual row"
done <<EOF
$VISUAL_COMMANDS
EOF

CONTRACT_METHODS=$(printf '%s\n' "$CONTRACT_ROWS" | sed -n 's/.*#\([^`|[:space:]]*\).*/\1/p')
[ -n "$CONTRACT_METHODS" ] || fail "visual rows for $VISUAL_OWNER have no parseable test methods"
for method in $CONTRACT_METHODS; do
  printf '%s\n' "$VISUAL_METHODS" | grep -Fxq "$method" \
    || fail "visual contract method $method is not listed in feature_list.json verification"
done

# A component-only composition cannot prove app-shell chrome. Make shell claims explicit at
# planning time and require the named visual test source to invoke the declared production root.
ROOT_DIR="${HARNESS_PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

for test_id in $CONTRACT_IDS; do
  CONTRACT_ROW=$(printf '%s\n' "$CONTRACT_ROWS" | grep -E "^\\|[[:space:]]*$test_id[[:space:]]*\\|" || true)
  if ! printf '%s\n' "$CONTRACT_ROW" | grep -Eqi \
    'app[[:space:]-]*shell|full[[:space:]-]*page[[:space:]-]*shell|bottom[[:space:]-]*navigation|navigationbar|system[[:space:]-]*bar'; then
    continue
  fi

  printf '%s\n' "$CONTRACT_ROW" | grep -Fq "Capture scope: app-shell" \
    || fail "$test_id claims app-shell chrome and must declare Capture scope: app-shell"
  PRODUCTION_ROOT=$(printf '%s\n' "$CONTRACT_ROW" |
    sed -n 's/.*production root:[[:space:]]*`\([A-Za-z_][A-Za-z0-9_]*\)`.*/\1/p' | head -n 1)
  [ -n "$PRODUCTION_ROOT" ] \
    || fail "$test_id app-shell visual row must name production root: \`<ViewOrWindowRoot>\`"

  VISUAL_TARGET=$(printf '%s\n' "$CONTRACT_ROW" |
    sed -n -E 's/.*`([^`]*VisualFlowTests?(\.swift)?#[A-Za-z_][A-Za-z0-9_]*)`.*/\1/p' | head -n 1)
  if [ -z "$VISUAL_TARGET" ]; then
    VISUAL_TARGET=$(printf '%s\n' "$CONTRACT_ROW" |
      sed -n -E 's/.*(NotesTakingAppiOSUITests\/[^|[:space:]]*VisualFlowTests?(\.swift)?#[A-Za-z_][A-Za-z0-9_]*).*/\1/p' | head -n 1)
  fi
  [ -n "$VISUAL_TARGET" ] \
    || fail "$test_id app-shell visual row must name a VisualFlowTests.swift#method target"
  VISUAL_FILE="${VISUAL_TARGET%%#*}"
  [ -f "$ROOT_DIR/$VISUAL_FILE" ] \
    || fail "$test_id app-shell visual test source is missing: $VISUAL_FILE"
  grep -Eq "$PRODUCTION_ROOT[[:space:]]*[<(]" "$ROOT_DIR/$VISUAL_FILE" \
    || fail "$test_id app-shell visual test $VISUAL_FILE must invoke declared production root $PRODUCTION_ROOT"
done

if [ "$MODE" = "--evaluate" ]; then
  ANCHOR_REPORT="$FEATURE_DIR/visual_evidence/reference-anchor-verification.md"
  [ -f "$ANCHOR_REPORT" ] || fail "missing $ANCHOR_REPORT; visual evidence needs reference-anchor verification"
  grep -Fq "## Reference Anchor Verification" "$ANCHOR_REPORT" \
    || fail "$ANCHOR_REPORT has no '## Reference Anchor Verification' section"
  grep -Fq "| Visual Test ID | Reference anchor | Runtime proof | Measured relationship | Actual screenshot | Result |" "$ANCHOR_REPORT" \
    || fail "$ANCHOR_REPORT has no required reference-anchor table header"

  RUNTIME_APPEARANCE=$(sed -n -E 's/^\*\*Runtime appearance\*\*:[[:space:]]*`(light|dark)`[[:space:]]*$/\1/p' "$ANCHOR_REPORT" | head -n 1)
  [ -n "$RUNTIME_APPEARANCE" ] \
    || fail "$ANCHOR_REPORT must declare the runtime appearance as \`light\` or \`dark\`"
  RUNTIME_DEVICE=$(sed -n -E 's/^\*\*Runtime device\*\*:[[:space:]]*`([^`]+)`[[:space:]]*$/\1/p' "$ANCHOR_REPORT" | head -n 1)
  [ -n "$RUNTIME_DEVICE" ] \
    || fail "$ANCHOR_REPORT must declare one concrete runtime device"
  RUNTIME_LOGICAL_SIZE=$(sed -n -E 's/^\*\*Runtime logical size\*\*:[[:space:]]*`([0-9]+x[0-9]+) pt`[[:space:]]*$/\1/p' "$ANCHOR_REPORT" | head -n 1)
  [ -n "$RUNTIME_LOGICAL_SIZE" ] \
    || fail "$ANCHOR_REPORT must declare a runtime logical size such as \`393x852 pt\`"
  RUNTIME_LOGICAL_WIDTH="${RUNTIME_LOGICAL_SIZE%x*}"
  RUNTIME_LOGICAL_HEIGHT="${RUNTIME_LOGICAL_SIZE#*x}"
  RUNTIME_LOCALE=$(sed -n -E 's/^\*\*Runtime locale\*\*:[[:space:]]*`([A-Za-z]{2,3}-[A-Za-z]{2})`[[:space:]]*$/\1/p' "$ANCHOR_REPORT" | head -n 1)
  [ -n "$RUNTIME_LOCALE" ] \
    || fail "$ANCHOR_REPORT must declare one concrete runtime locale such as \`en-US\`"
  PREPARE_RUNTIME="$ROOT_DIR/harness/scripts/prepare-visual-runtime.sh"
  [ -x "$PREPARE_RUNTIME" ] \
    || fail "missing executable visual runtime preflight: $PREPARE_RUNTIME"
  CHECK_THEME="$ROOT_DIR/harness/scripts/check-visual-theme.sh"
  [ -x "$CHECK_THEME" ] \
    || fail "missing executable visual theme check: $CHECK_THEME"
  REFERENCE_MAP="$FEATURE_DIR/visual_evidence/reference-map.json"
  [ -f "$REFERENCE_MAP" ] \
    || fail "missing $REFERENCE_MAP; every runtime capture requires an explicit approved mockup mapping"
  jq -e 'type == "object" and .version == 1 and (.captures | type == "object") and (.target_manifest | type == "string")' "$REFERENCE_MAP" >/dev/null 2>&1 \
    || fail "$REFERENCE_MAP must use version 1 with target_manifest and captures object"
  TARGET_MANIFEST_REL=$(jq -r '.target_manifest' "$REFERENCE_MAP")
  case "$TARGET_MANIFEST_REL" in
    visual-target.json) ;;
    *) fail "$REFERENCE_MAP target_manifest must be visual-target.json so mockup generation and simulator capture share one source" ;;
  esac
  TARGET_MANIFEST="$FEATURE_DIR/visual_evidence/$TARGET_MANIFEST_REL"
  [ -f "$TARGET_MANIFEST" ] || fail "missing visual target manifest $TARGET_MANIFEST"
  jq -e 'type == "object" and .version == 1 and (.target_id | type == "string") and (.appearance | IN("light", "dark")) and (.device | type == "string") and (.logical_size_pt.width > 0) and (.logical_size_pt.height > 0) and (.locale | type == "string") and (.states | type == "object")' "$TARGET_MANIFEST" >/dev/null 2>&1 \
    || fail "$TARGET_MANIFEST must declare version, target_id, appearance, device, logical_size_pt, locale, and states"
  TARGET_APPEARANCE=$(jq -r '.appearance' "$TARGET_MANIFEST")
  [ "$TARGET_APPEARANCE" = "$RUNTIME_APPEARANCE" ] \
    || fail "visual target appearance $TARGET_APPEARANCE must match runtime appearance $RUNTIME_APPEARANCE"
  TARGET_DEVICE=$(jq -r '.device' "$TARGET_MANIFEST")
  [ "$TARGET_DEVICE" = "$RUNTIME_DEVICE" ] \
    || fail "visual target device $TARGET_DEVICE must match runtime device $RUNTIME_DEVICE"
  TARGET_WIDTH=$(jq -r '.logical_size_pt.width' "$TARGET_MANIFEST")
  TARGET_HEIGHT=$(jq -r '.logical_size_pt.height' "$TARGET_MANIFEST")
  [ "$TARGET_WIDTH" = "$RUNTIME_LOGICAL_WIDTH" ] && [ "$TARGET_HEIGHT" = "$RUNTIME_LOGICAL_HEIGHT" ] \
    || fail "visual target logical size must match runtime size ${RUNTIME_LOGICAL_WIDTH}x${RUNTIME_LOGICAL_HEIGHT} pt"
  TARGET_LOCALE=$(jq -r '.locale' "$TARGET_MANIFEST")
  [ "$TARGET_LOCALE" = "$RUNTIME_LOCALE" ] \
    || fail "visual target locale $TARGET_LOCALE must match runtime locale $RUNTIME_LOCALE"

  # A launch argument controls the app process, but not system UI such as the
  # keyboard. Require every visual command to configure the concrete simulator
  # appearance and disable test clones before it captures evidence.
  while IFS= read -r visual_command; do
    [ -n "$visual_command" ] || continue
    printf '%s\n' "$visual_command" | grep -Fq 'harness/scripts/prepare-visual-runtime.sh' \
      || fail "visual verification commands must run prepare-visual-runtime.sh before capture"
    printf '%s\n' "$visual_command" | grep -Eq -- '--(target|visual-target)[[:space:]]' \
      || fail "visual verification commands must pass the canonical visual-target.json to prepare-visual-runtime.sh"
    printf '%s\n' "$visual_command" | grep -Fq 'visual-target.json' \
      || fail "visual verification commands must reference visual_evidence/visual-target.json"
    printf '%s\n' "$visual_command" | grep -Fq -- '-parallel-testing-enabled NO' \
      || fail "visual verification commands must disable parallel simulator clones"
  done <<EOF
$VISUAL_COMMANDS
EOF

  # A declared command is not proof that the recorded successful evidence was
  # produced by that command. Require each successful evidence row to preserve
  # the same runtime setup, so stale pre-retro captures cannot remain green.
  for test_id in $CONTRACT_IDS; do
    EVIDENCE_COMMANDS=$(jq -r --arg owner "$VISUAL_OWNER" --arg id "$test_id" '
      .features[]
      | select(.id == $owner)
      | (.evidence // [])[]
      | select(.test_id == $id and .exit_status == 0 and ((.executed_command // "") | contains("xcodebuild test")))
      | .executed_command
    ' "$FEATURE_JSON")
    while IFS= read -r evidence_command; do
      [ -n "$evidence_command" ] || continue
      printf '%s\n' "$evidence_command" | grep -Fq 'harness/scripts/prepare-visual-runtime.sh' \
        || fail "$test_id successful evidence must record prepare-visual-runtime.sh"
      printf '%s\n' "$evidence_command" | grep -Eq -- '--(target|visual-target)[[:space:]]' \
        || fail "$test_id successful evidence must record the canonical visual-target.json"
      printf '%s\n' "$evidence_command" | grep -Fq 'visual-target.json' \
        || fail "$test_id successful evidence must record visual_evidence/visual-target.json"
      printf '%s\n' "$evidence_command" | grep -Fq -- '-parallel-testing-enabled NO' \
        || fail "$test_id successful evidence must record disabled parallel simulator clones"
    done <<EOF
$EVIDENCE_COMMANDS
EOF
  done

  SEEN_SCREENSHOT_PATHS=""
  for test_id in $CONTRACT_IDS; do
    CONTRACT_ROW=$(printf '%s\n' "$CONTRACT_ROWS" | grep -E "^\\|[[:space:]]*$test_id[[:space:]]*\\|" || true)
    SCREENSHOT_PATH=$(printf '%s\n' "$CONTRACT_ROW" | grep -oE 'visual_evidence/[[:alnum:]_./-]+\.png' | head -n 1 || true)
    [ -n "$SCREENSHOT_PATH" ] \
      || fail "$test_id has no visual_evidence PNG artifact path in sprint-contract.md"
    case "$SCREENSHOT_PATH" in
      *..*) fail "$test_id visual evidence path must stay under visual_evidence/" ;;
    esac
    [ -s "$FEATURE_DIR/$SCREENSHOT_PATH" ] \
      || fail "$test_id is missing non-empty screenshot $SCREENSHOT_PATH"
    SCREENSHOT_SIZE=$(wc -c < "$FEATURE_DIR/$SCREENSHOT_PATH" | tr -d ' ')
    MIN_SCREENSHOT_BYTES=5120
    [ "$SCREENSHOT_SIZE" -ge "$MIN_SCREENSHOT_BYTES" ] \
      || fail "$test_id screenshot $SCREENSHOT_PATH is only ${SCREENSHOT_SIZE} bytes (minimum ${MIN_SCREENSHOT_BYTES}); likely a blank or transparent capture"
    bash "$CHECK_THEME" \
      --expected "$RUNTIME_APPEARANCE" \
      --image "$FEATURE_DIR/$SCREENSHOT_PATH" \
      || fail "$test_id screenshot $SCREENSHOT_PATH does not match declared runtime appearance $RUNTIME_APPEARANCE"

    if printf '%s\n' "$SEEN_SCREENSHOT_PATHS" | grep -Fxq "$SCREENSHOT_PATH"; then
      fail "${SCREENSHOT_PATH} is used by more than one visual row"
    fi
    SEEN_SCREENSHOT_PATHS="${SEEN_SCREENSHOT_PATHS}${SCREENSHOT_PATH}"$'\n'

    CAPTURE_NAME="$(basename "$SCREENSHOT_PATH")"
    MAP_ENTRY=$(jq -c --arg f "$CAPTURE_NAME" '.captures[$f] // empty' "$REFERENCE_MAP")
    [ -n "$MAP_ENTRY" ] \
      || fail "$test_id screenshot $SCREENSHOT_PATH has no explicit mockup mapping in $REFERENCE_MAP"
    printf '%s' "$MAP_ENTRY" | jq -e 'type == "object" and ((keys | sort) == ["state_id"])' >/dev/null \
      || fail "$test_id mockup mapping must contain only an explicit state_id; target metadata belongs in visual-target.json"
    MAP_CONTENT_STATE_ID=$(printf '%s' "$MAP_ENTRY" | jq -r '.state_id // empty')
    [ -n "$MAP_CONTENT_STATE_ID" ] \
      || fail "$test_id mockup mapping must declare a stable content_state_id"
    STATE_JSON=$(jq -c --arg state "$MAP_CONTENT_STATE_ID" '.states[$state] // empty' "$TARGET_MANIFEST")
    [ -n "$STATE_JSON" ] && [ "$STATE_JSON" != "null" ] \
      || fail "$test_id mockup state $MAP_CONTENT_STATE_ID is not declared in visual-target.json"
    STATE_ID_FROM_MANIFEST=$(printf '%s' "$STATE_JSON" | jq -r '.content_state_id // empty')
    [ "$STATE_ID_FROM_MANIFEST" = "$MAP_CONTENT_STATE_ID" ] \
      || fail "$test_id visual target state must carry matching content_state_id $MAP_CONTENT_STATE_ID"
    REFERENCE_ASSET=$(printf '%s' "$STATE_JSON" | jq -r '.reference // empty')
    case "$REFERENCE_ASSET" in
      design/mockup_*.png) ;;
      *) fail "$test_id mockup mapping must reference an approved design/mockup_*.png asset" ;;
    esac
    case "$REFERENCE_ASSET" in
      *..*) fail "$test_id mockup mapping must stay under design/" ;;
    esac
    [ -s "$FEATURE_DIR/$REFERENCE_ASSET" ] \
      || fail "$test_id mockup mapping references missing or empty asset $REFERENCE_ASSET"
    MAP_CONTENT_STATE=$(printf '%s' "$STATE_JSON" | jq -r '.content_state // empty')
    [ -n "$MAP_CONTENT_STATE" ] \
      || fail "$test_id mockup mapping must declare the intended content state"
    printf '%s\n' "$CONTRACT_ROW" | grep -Fq "contentState: \`$MAP_CONTENT_STATE_ID\`" \
      || fail "$test_id contract row must declare contentState: \`$MAP_CONTENT_STATE_ID\` to bind the runtime fixture to its mockup"
    bash "$CHECK_THEME" \
      --expected "$RUNTIME_APPEARANCE" \
      --image "$FEATURE_DIR/$REFERENCE_ASSET" \
      || fail "$test_id mockup $REFERENCE_ASSET does not match runtime appearance $RUNTIME_APPEARANCE"

    REPORT_ROWS=$(grep -E "^\\|[[:space:]]*$test_id[[:space:]]*\\|" "$ANCHOR_REPORT" || true)
    REPORT_ROW_COUNT=$(printf '%s\n' "$REPORT_ROWS" | sed '/^[[:space:]]*$/d' | wc -l | tr -d ' ')
    [ "$REPORT_ROW_COUNT" -eq 1 ] \
      || fail "$ANCHOR_REPORT must contain exactly one reference-anchor row for $test_id"
    REPORT_ROW=$(printf '%s\n' "$REPORT_ROWS" | sed '/^[[:space:]]*$/d')
    printf '%s\n' "$REPORT_ROW" | grep -Eq 'accessibilityIdentifier:[[:space:]]*`[^`]+`' \
      || fail "$test_id reference-anchor row must name a visual bounds accessibilityIdentifier"
    VISUAL_ID=$(printf '%s\n' "$REPORT_ROW" | sed -n 's/.*accessibilityIdentifier:[[:space:]]*`\([^`]*\)`.*/\1/p')
    case "$VISUAL_ID" in
      *_handle|*-handle)
        fail "$test_id reference-anchor row must name the handle's visual shape identifier, not interactive target $VISUAL_ID"
        ;;
    esac
    printf '%s\n' "$REPORT_ROW" | grep -Eq '`[^`]*#[A-Za-z_][A-Za-z0-9_]*`' \
      || fail "$test_id reference-anchor row must name the runtime test method"
    printf '%s\n' "$REPORT_ROW" | grep -Eq '[A-Za-z]+Bounds(\.[A-Za-z]+)?[[:space:]]*(==|>=|<=|>|<)' \
      || fail "$test_id reference-anchor row must record a concrete bounds relationship"
    printf '%s\n' "$REPORT_ROW" | grep -Fq "$SCREENSHOT_PATH" \
      || fail "$test_id reference-anchor row must cite $SCREENSHOT_PATH"
    printf '%s\n' "$REPORT_ROW" | grep -Eq '\|[[:space:]]*PASS[[:space:]]*\|[[:space:]]*$' \
      || fail "$test_id reference-anchor row must end with PASS"
  done

  [ -f "$SCRIPT_DIR/compare-visual-evidence.sh" ] \
    || fail "missing required comparator: $SCRIPT_DIR/compare-visual-evidence.sh"
  echo "Running perceptual visual comparison checks..."
  bash "$SCRIPT_DIR/compare-visual-evidence.sh" \
    --feature "$FEATURE_DIR" \
    --crop-insets \
    --project-root "$ROOT_DIR" \
    || fail "perceptual visual comparison failed"
fi

echo "PASS: visual methods, contract rows, acceptance IDs, connected evidence, screenshots, and reference-anchor proof are aligned."
