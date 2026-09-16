#!/usr/bin/env bash

set -e

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
VALIDATOR="$REPO_ROOT/harness/scripts/check-visual-evidence-contract.sh"
fixture_root=$(mktemp -d "${TMPDIR:-/tmp}/visual-evidence-test.XXXXXX")
trap 'rm -rf "$fixture_root"' EXIT
export HARNESS_PROJECT_ROOT="$fixture_root"

write_valid_fixture() {
  local feature_dir="$1"
  mkdir -p "$feature_dir/design" "$feature_dir/visual_evidence"
  mkdir -p "$fixture_root/NotesTakingAppiOSUITests"
  mkdir -p "$fixture_root/harness/scripts"
  cp "$REPO_ROOT/harness/scripts/prepare-visual-runtime.sh" \
    "$fixture_root/harness/scripts/prepare-visual-runtime.sh"
  cp "$REPO_ROOT/harness/scripts/check-visual-theme.sh" \
    "$fixture_root/harness/scripts/check-visual-theme.sh"
  printf '%s\n' \
    'import XCTest' \
    '' \
    'class EmojiPickerVisualFlowTests: XCTestCase {' \
    '    func testEmojiPickerContentLightTheme() {' \
    '    }' \
    '}' \
    > "$fixture_root/NotesTakingAppiOSUITests/EmojiPickerVisualFlowTests.swift"
  # Real PNGs are required because the visual gate now runs the perceptual
  # comparator, not only the screenshot-size and anchor checks.
  python3 - "$feature_dir" <<'EOF'
import random
import sys
from PIL import Image

feature_dir = sys.argv[1]
rng = random.Random(42)
image = Image.new("RGB", (108, 234))
image.putdata([
    (rng.randrange(256), rng.randrange(256), rng.randrange(256))
    for _ in range(108 * 234)
])
image.save(f"{feature_dir}/design/mockup_picker.png")
image.save(f"{feature_dir}/visual_evidence/emoji_picker_content.png")
EOF
  printf '%s\n' \
    '{' \
    '  "version": 1,' \
    '  "target_id": "picker-target",' \
    '  "appearance": "light",' \
    '  "device": "iPhone-16",' \
    '  "logical_size_pt": { "width": 108, "height": 234 },' \
    '  "locale": "en-US",' \
    '  "states": {' \
    '    "picker-content": {' \
    '      "content_state_id": "picker-content",' \
    '      "reference": "design/mockup_picker.png",' \
    '      "content_state": "Deterministic picker fixture content.",' \
    '      "mask": [],' \
    '      "dynamic_regions": [' \
    '        { "kind": "time", "handling": "cropped-system-insets", "rationale": "Insets are cropped." },' \
    '        { "kind": "user-content", "handling": "fixture", "rationale": "Fixture content is deterministic." },' \
    '        { "kind": "identifier", "handling": "fixture", "rationale": "Fixture identifiers are deterministic." },' \
    '        { "kind": "keyboard", "handling": "not-present", "rationale": "No keyboard in this state." }' \
    '      ]' \
    '    }' \
    '  }' \
    '}' > "$feature_dir/visual_evidence/visual-target.json"
  printf '%s\n' \
    '{' \
    '  "version": 1,' \
    '  "target_manifest": "visual-target.json",' \
    '  "captures": {' \
    '    "emoji_picker_content.png": { "state_id": "picker-content" }' \
    '  }' \
    '}' > "$feature_dir/visual_evidence/reference-map.json"
  printf '%s\n' \
    '# Sprint Contract' \
    '' \
    '### US-3: Visual picker' \
    '' \
    '| Test ID | Covers AC | Test layer | Test file and method | Setup and action | Required assertions | Exact command |' \
    '|---|---|---|---|---|---|---|' \
    '| TC-US-3-VIS-001 | AC-US-3-03 | Visual verification | NotesTakingAppiOSUITests/EmojiPickerVisualFlowTests.swift#emojiPickerContentLightTheme | fixture; contentState: `picker-content` | screenshot saved at visual_evidence/emoji_picker_content.png | bash harness/scripts/prepare-visual-runtime.sh --target "$FEATURE_DIR/visual_evidence/visual-target.json" && xcodebuild test -parallel-testing-enabled NO -only-testing:NotesTakingAppiOSUITests/EmojiPickerVisualFlowTests/emojiPickerContentLightTheme |' \
    > "$feature_dir/sprint-contract.md"
  printf '%s\n' \
    '{' \
    '  "features": [{' \
    '    "id": "US-3",' \
    '    "requires_visual_verification": true,' \
    '    "acceptance_test_ids": ["TC-US-3-VIS-001"],' \
    '    "verification": [' \
    '      "bash harness/scripts/prepare-visual-runtime.sh --target $FEATURE_DIR/visual_evidence/visual-target.json && xcodebuild test -parallel-testing-enabled NO -only-testing:NotesTakingAppiOSUITests/EmojiPickerVisualFlowTests/emojiPickerContentLightTheme -PtestInstrumentationRunnerArguments.class=EmojiPickerVisualFlowTests#emojiPickerContentLightTheme"' \
    '    ],' \
    '    "evidence": [{"test_id": "TC-US-3-VIS-001", "exit_status": 0, "executed_command": "bash harness/scripts/prepare-visual-runtime.sh --target $FEATURE_DIR/visual_evidence/visual-target.json && env  ./xcodebuild xcodebuild test -parallel-testing-enabled NO"}]' \
    '  }]' \
    '}' \
    > "$feature_dir/feature_list.json"
  printf '%s\n' \
    '# Visual Reference Anchor Verification' \
    '' \
    '**Mockup bindings**: `visual_evidence/reference-map.json` → `visual_evidence/visual-target.json`' \
    '' \
    '**Runtime appearance**: `light`' \
    '' \
    '**Runtime device**: `iPhone-16`' \
    '' \
    '**Runtime logical size**: `108x234 pt`' \
    '' \
    '**Runtime locale**: `en-US`' \
    '' \
    '## Reference Anchor Verification' \
    '' \
    '| Visual Test ID | Reference anchor | Runtime proof | Measured relationship | Actual screenshot | Result |' \
    '|---|---|---|---|---|---|' \
    '| TC-US-3-VIS-001 | Picker visual top edge aligns to the reference safe-area anchor. | `EmojiPickerVisualFlowTest#emojiPickerContentLightTheme`; accessibilityIdentifier: `emoji_picker_visual` | `pickerBounds.top == safeAreaBounds.top + 16dp` | `visual_evidence/emoji_picker_content.png` | PASS |' \
    > "$feature_dir/visual_evidence/reference-anchor-verification.md"
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

valid="$fixture_root/valid"
write_valid_fixture "$valid"
(cd "$REPO_ROOT" && bash "$VALIDATOR" "$valid")

missing_runtime_setup="$fixture_root/missing-runtime-setup"
write_valid_fixture "$missing_runtime_setup"
  sed 's#bash harness/scripts/prepare-visual-runtime.sh --target "$FEATURE_DIR/visual_evidence/visual-target.json" && ##' \
  "$missing_runtime_setup/sprint-contract.md" > "$missing_runtime_setup/sprint-contract.tmp"
mv "$missing_runtime_setup/sprint-contract.tmp" "$missing_runtime_setup/sprint-contract.md"
jq '.features[0].verification[0] = "xcodebuild test -parallel-testing-enabled NO -only-testing:NotesTakingAppiOSUITests/EmojiPickerVisualFlowTests/emojiPickerContentLightTheme -PtestInstrumentationRunnerArguments.class=EmojiPickerVisualFlowTests#emojiPickerContentLightTheme"' \
  "$missing_runtime_setup/feature_list.json" > "$missing_runtime_setup/feature_list.tmp"
mv "$missing_runtime_setup/feature_list.tmp" "$missing_runtime_setup/feature_list.json"
expect_failure "must run prepare-visual-runtime.sh" bash "$VALIDATOR" "$missing_runtime_setup"

missing_runtime_locale="$fixture_root/missing-runtime-locale"
write_valid_fixture "$missing_runtime_locale"
sed 's# --target "$FEATURE_DIR/visual_evidence/visual-target.json"##' "$missing_runtime_locale/sprint-contract.md" > "$missing_runtime_locale/sprint-contract.tmp"
mv "$missing_runtime_locale/sprint-contract.tmp" "$missing_runtime_locale/sprint-contract.md"
jq '.features[0].verification[0] |= sub(" --target \\$FEATURE_DIR/visual_evidence/visual-target.json"; "")' "$missing_runtime_locale/feature_list.json" > "$missing_runtime_locale/feature_list.tmp"
mv "$missing_runtime_locale/feature_list.tmp" "$missing_runtime_locale/feature_list.json"
expect_failure "must pass the canonical visual-target.json" bash "$VALIDATOR" "$missing_runtime_locale"

stale_evidence="$fixture_root/stale-evidence"
write_valid_fixture "$stale_evidence"
jq '.features[0].evidence[0].executed_command = "env ./xcodebuild xcodebuild test -parallel-testing-enabled NO"' \
  "$stale_evidence/feature_list.json" > "$stale_evidence/feature_list.tmp"
mv "$stale_evidence/feature_list.tmp" "$stale_evidence/feature_list.json"
expect_failure "successful evidence must record prepare-visual-runtime.sh" bash "$VALIDATOR" "$stale_evidence"

missing_parallel_guard="$fixture_root/missing-parallel-guard"
write_valid_fixture "$missing_parallel_guard"
sed 's/ -parallel-testing-enabled NO//' \
  "$missing_parallel_guard/sprint-contract.md" > "$missing_parallel_guard/sprint-contract.tmp"
mv "$missing_parallel_guard/sprint-contract.tmp" "$missing_parallel_guard/sprint-contract.md"
jq '.features[0].verification[0] = "bash harness/scripts/prepare-visual-runtime.sh --target $FEATURE_DIR/visual_evidence/visual-target.json && xcodebuild test -only-testing:NotesTakingAppiOSUITests/EmojiPickerVisualFlowTests/emojiPickerContentLightTheme -PtestInstrumentationRunnerArguments.class=EmojiPickerVisualFlowTests#emojiPickerContentLightTheme"' \
  "$missing_parallel_guard/feature_list.json" > "$missing_parallel_guard/feature_list.tmp"
mv "$missing_parallel_guard/feature_list.tmp" "$missing_parallel_guard/feature_list.json"
expect_failure "must disable parallel simulator clones" bash "$VALIDATOR" "$missing_parallel_guard"

wrong_runtime_theme="$fixture_root/wrong-runtime-theme"
write_valid_fixture "$wrong_runtime_theme"
python3 - "$wrong_runtime_theme/visual_evidence/emoji_picker_content.png" <<'EOF'
import random
import sys
from PIL import Image

rng = random.Random(7)
image = Image.new("RGB", (108, 234))
image.putdata([
    (18 + rng.randrange(8), 18 + rng.randrange(8), 18 + rng.randrange(8))
    for _ in range(108 * 234)
])
image.save(sys.argv[1])
EOF
expect_failure "does not match declared runtime appearance light" bash "$VALIDATOR" "$wrong_runtime_theme"

app_shell_without_scope="$fixture_root/app-shell-without-scope"
write_valid_fixture "$app_shell_without_scope"
sed 's/| fixture; contentState: `picker-content` | screenshot saved at/| Render full-page app shell | screenshot saved at/' \
  "$app_shell_without_scope/sprint-contract.md" \
  > "$app_shell_without_scope/sprint-contract.tmp"
mv "$app_shell_without_scope/sprint-contract.tmp" "$app_shell_without_scope/sprint-contract.md"
expect_failure "must declare Capture scope: app-shell" \
  bash "$VALIDATOR" "$app_shell_without_scope"

app_shell_without_root_call="$fixture_root/app-shell-without-root-call"
write_valid_fixture "$app_shell_without_root_call"
sed 's/| fixture; contentState: `picker-content` | screenshot saved at/| Capture scope: app-shell; production root: `MainTabView`; contentState: `picker-content`. Render full-page app shell | screenshot saved at/' \
  "$app_shell_without_root_call/sprint-contract.md" \
  > "$app_shell_without_root_call/sprint-contract.tmp"
mv "$app_shell_without_root_call/sprint-contract.tmp" "$app_shell_without_root_call/sprint-contract.md"
expect_failure "must invoke declared production root MainTabView" \
  bash "$VALIDATOR" "$app_shell_without_root_call"

app_shell_with_root_call="$fixture_root/app-shell-with-root-call"
write_valid_fixture "$app_shell_with_root_call"
sed 's/| fixture; contentState: `picker-content` | screenshot saved at/| Capture scope: app-shell; production root: `MainTabView`; contentState: `picker-content`. Render full-page app shell | screenshot saved at/' \
  "$app_shell_with_root_call/sprint-contract.md" \
  > "$app_shell_with_root_call/sprint-contract.tmp"
mv "$app_shell_with_root_call/sprint-contract.tmp" "$app_shell_with_root_call/sprint-contract.md"
mkdir -p "$fixture_root/NotesTakingAppiOSUITests"
printf 'import XCTest\nclass EmojiPickerVisualFlowTests: XCTestCase {\n    func testEmojiPicker() {\n        let _ = MainTabView()\n    }\n}\n' \
  > "$fixture_root/NotesTakingAppiOSUITests/EmojiPickerVisualFlowTests.swift"
env HARNESS_PROJECT_ROOT="$fixture_root" bash "$VALIDATOR" "$app_shell_with_root_call"

functional_visual_class="$fixture_root/functional-visual-class"
write_valid_fixture "$functional_visual_class"
sed 's/EmojiPickerVisualFlowTests/FormattingToolbarUITests/g' \
  "$functional_visual_class/sprint-contract.md" > "$functional_visual_class/sprint-contract.tmp"
mv "$functional_visual_class/sprint-contract.tmp" "$functional_visual_class/sprint-contract.md"
expect_failure "functional test classes cannot produce visual evidence" \
  bash "$VALIDATOR" "$functional_visual_class"

class_scoped_visual_command="$fixture_root/class-scoped-visual-command"
write_valid_fixture "$class_scoped_visual_command"
jq '.features[0].verification = ["env  ./xcodebuild xcodebuild test -only-testing:NotesTakingAppiOSTests/EmojiPickerVisualFlowTests -PtestInstrumentationRunnerArguments.class=EmojiPickerVisualFlowTests#emojiPickerContentLightTheme"]' \
  "$class_scoped_visual_command/feature_list.json" > "$class_scoped_visual_command/feature_list.tmp"
mv "$class_scoped_visual_command/feature_list.tmp" "$class_scoped_visual_command/feature_list.json"
expect_failure "method-scoped -only-testing selector" \
  bash "$VALIDATOR" "$class_scoped_visual_command"

duplicate_screenshot="$fixture_root/duplicate-screenshot"
write_valid_fixture "$duplicate_screenshot"
grep -F '| TC-US-3-VIS-001 |' "$duplicate_screenshot/sprint-contract.md" \
  >> "$duplicate_screenshot/sprint-contract.md"
expect_failure "is used by more than one visual row" \
  bash "$VALIDATOR" "$duplicate_screenshot"

missing_anchor_report="$fixture_root/missing-anchor-report"
write_valid_fixture "$missing_anchor_report"
mv "$missing_anchor_report/visual_evidence/reference-anchor-verification.md" \
  "$missing_anchor_report/visual_evidence/reference-anchor-verification.missing"
expect_failure "missing $missing_anchor_report/visual_evidence/reference-anchor-verification.md" \
  bash "$VALIDATOR" "$missing_anchor_report"

missing_anchor_tag="$fixture_root/missing-anchor-tag"
write_valid_fixture "$missing_anchor_tag"
sed 's/accessibilityIdentifier:/boundsTag:/' "$missing_anchor_tag/visual_evidence/reference-anchor-verification.md" \
  > "$missing_anchor_tag/visual_evidence/reference-anchor-verification.tmp"
mv "$missing_anchor_tag/visual_evidence/reference-anchor-verification.tmp" \
  "$missing_anchor_tag/visual_evidence/reference-anchor-verification.md"
expect_failure "must name a visual bounds accessibilityIdentifier" bash "$VALIDATOR" "$missing_anchor_tag"

target_only_handle_anchor="$fixture_root/target-only-handle-anchor"
write_valid_fixture "$target_only_handle_anchor"
sed 's/emoji_picker_visual/emoji_picker_handle/' \
  "$target_only_handle_anchor/visual_evidence/reference-anchor-verification.md" \
  > "$target_only_handle_anchor/visual_evidence/reference-anchor-verification.tmp"
mv "$target_only_handle_anchor/visual_evidence/reference-anchor-verification.tmp" \
  "$target_only_handle_anchor/visual_evidence/reference-anchor-verification.md"
expect_failure "must name the handle's visual shape identifier, not interactive target emoji_picker_handle" \
  bash "$VALIDATOR" "$target_only_handle_anchor"

missing_screenshot="$fixture_root/missing-screenshot"
write_valid_fixture "$missing_screenshot"
mv "$missing_screenshot/visual_evidence/emoji_picker_content.png" \
  "$missing_screenshot/visual_evidence/emoji_picker_content.missing"
expect_failure "is missing non-empty screenshot visual_evidence/emoji_picker_content.png" \
  bash "$VALIDATOR" "$missing_screenshot"

tiny_screenshot="$fixture_root/tiny-screenshot"
write_valid_fixture "$tiny_screenshot"
printf 'too small' > "$tiny_screenshot/visual_evidence/emoji_picker_content.png"
expect_failure "likely a blank or transparent capture" \
  bash "$VALIDATOR" "$tiny_screenshot"

missing_mockup_map="$fixture_root/missing-mockup-map"
write_valid_fixture "$missing_mockup_map"
rm "$missing_mockup_map/visual_evidence/reference-map.json"
expect_failure "every runtime capture requires an explicit approved mockup mapping" \
  bash "$VALIDATOR" "$missing_mockup_map"

wrong_mockup_locale="$fixture_root/wrong-mockup-locale"
write_valid_fixture "$wrong_mockup_locale"
jq '.locale = "fr-FR"' \
  "$wrong_mockup_locale/visual_evidence/visual-target.json" > "$wrong_mockup_locale/visual_evidence/visual-target.tmp"
mv "$wrong_mockup_locale/visual_evidence/visual-target.tmp" "$wrong_mockup_locale/visual_evidence/visual-target.json"
expect_failure "visual target locale fr-FR must match runtime locale en-US" \
  bash "$VALIDATOR" "$wrong_mockup_locale"

missing_contract_row="$fixture_root/missing-contract-row"
write_valid_fixture "$missing_contract_row"
jq '.features[0].verification += ["env  ./xcodebuild xcodebuild test -only-testing:NotesTakingAppiOSUITests/EmojiPickerVisualFlowTests/emojiPickerExpandsToAvailableHeightWhenKeyboardIsVisible -PtestInstrumentationRunnerArguments.class=EmojiPickerVisualFlowTests#emojiPickerExpandsToAvailableHeightWhenKeyboardIsVisible"]' \
  "$missing_contract_row/feature_list.json" > "$missing_contract_row/feature_list.tmp"
mv "$missing_contract_row/feature_list.tmp" "$missing_contract_row/feature_list.json"
expect_failure "is not named by a US-3 visual row" bash "$VALIDATOR" "$missing_contract_row"

missing_feature_id="$fixture_root/missing-feature-id"
write_valid_fixture "$missing_feature_id"
jq '.features[0].acceptance_test_ids = []' \
  "$missing_feature_id/feature_list.json" > "$missing_feature_id/feature_list.tmp"
mv "$missing_feature_id/feature_list.tmp" "$missing_feature_id/feature_list.json"
expect_failure "missing from feature_list.json acceptance_test_ids" bash "$VALIDATOR" "$missing_feature_id"

missing_evidence="$fixture_root/missing-evidence"
write_valid_fixture "$missing_evidence"
jq '.features[0].evidence[0].exit_status = 1' \
  "$missing_evidence/feature_list.json" > "$missing_evidence/feature_list.tmp"
mv "$missing_evidence/feature_list.tmp" "$missing_evidence/feature_list.json"
expect_failure "has no successful connected-test evidence" bash "$VALIDATOR" "$missing_evidence"

missing_verification="$fixture_root/missing-verification"
write_valid_fixture "$missing_verification"
jq '.features[0].verification = []' \
  "$missing_verification/feature_list.json" > "$missing_verification/feature_list.tmp"
mv "$missing_verification/feature_list.tmp" "$missing_verification/feature_list.json"
expect_failure "is not listed in feature_list.json verification" bash "$VALIDATOR" "$missing_verification"

echo "PASS: visual evidence validator rejects missing approved mockup mappings, appearance/locale drift, blank screenshots, app-shell captures without their root, and unaligned methods, contract rows, screenshots, and structural-anchor evidence."
