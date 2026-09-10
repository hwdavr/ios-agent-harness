#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
if [[ ! -d "$PROJECT_ROOT/NotesTakingAppiOS" && -d "$PROJECT_ROOT/../NotesTakingAppiOS" ]]; then
    PROJECT_ROOT="$(cd "$PROJECT_ROOT/.." && pwd)"
fi

TEMPLATE="$PROJECT_ROOT/harness/templates/rule-applicability-template.md"
STAGE_CHECKER="$PROJECT_ROOT/harness/scripts/check-stage-artifacts.sh"
HARNESS_AGENTS="$PROJECT_ROOT/.harness/AGENTS.md"

fail() {
    echo "RED: $1"
    exit 1
}

assert_contains() {
    local file="$1"
    local expected="$2"
    rg -Fq "$expected" "$file" || fail "expected $file to contain: $expected"
}

assert_not_contains() {
    local file="$1"
    local unexpected="$2"
    if rg -Fq "$unexpected" "$file"; then
        fail "did not expect $file to contain: $unexpected"
    fi
}

assert_exists() {
    local file="$1"
    [[ -f "$file" ]] || fail "expected file: $file"
}

for required_file in \
    "$TEMPLATE" \
    "$PROJECT_ROOT/harness/templates/requirement-summary-template.md" \
    "$STAGE_CHECKER" \
    "$PROJECT_ROOT/AGENTS.md" \
    "$HARNESS_AGENTS" \
    "$PROJECT_ROOT/.agents/skills/requirement-analysis/SKILL.md" \
    "$PROJECT_ROOT/.agents/skills/feature-specification/SKILL.md" \
    "$PROJECT_ROOT/.agents/skills/requirement-capture/SKILL.md" \
    "$PROJECT_ROOT/.agents/skills/implementation-plan/SKILL.md" \
    "$PROJECT_ROOT/.agents/skills/ios-testing/SKILL.md" \
    "$PROJECT_ROOT/.agents/skills/feature-orient/SKILL.md" \
    "$PROJECT_ROOT/.agents/skills/android-to-ios-ui-migration/SKILL.md" \
    "$PROJECT_ROOT/.agents/skills/code-quality-fix/SKILL.md" \
    "$PROJECT_ROOT/.agents/skills/ios-code-quality-checks/SKILL.md" \
    "$PROJECT_ROOT/.agents/skills/ios-code-review/SKILL.md" \
    "$PROJECT_ROOT/.agents/skills/ios-test-review/SKILL.md" \
    "$PROJECT_ROOT/.agents/skills/code-review-and-quality/SKILL.md" \
    "$PROJECT_ROOT/harness/scripts/print-context-index.sh" \
    "$PROJECT_ROOT/harness/scripts/tests/context-index-contract-test.sh" \
    "$PROJECT_ROOT/.agents/workflows/create-ui-and-verify.md" \
    "$PROJECT_ROOT/.agents/workflows/harness-generator.md" \
    "$PROJECT_ROOT/.agents/workflows/harness-fix.md" \
    "$PROJECT_ROOT/.agents/gates/ci-checks.md" \
    "$PROJECT_ROOT/harness/templates/code-review-template.md" \
    "$PROJECT_ROOT/harness/templates/test-review-template.md" \
    "$PROJECT_ROOT/harness/templates/summary-profiles/feature-delivery.md" \
    "$PROJECT_ROOT/harness/templates/summary-profiles/bug-fixing.md"; do
    assert_exists "$required_file"
done

for rule_id in ARCH IMPL TEST SUI L10N NAV API OBS ANL SEC; do
    assert_contains "$TEMPLATE" "| $rule_id |"
done

assert_contains "$TEMPLATE" "Not applicable — <feature-specific reason>"
assert_contains "$TEMPLATE" "Exception — approved by <user/date>"
assert_contains "$TEMPLATE" "analytics: none"
assert_contains "$STAGE_CHECKER" "require_rule_applicability"
assert_contains "$STAGE_CHECKER" "check-acceptance-test-traceability.sh"
assert_contains "$PROJECT_ROOT/.agents/skills/requirement-analysis/SKILL.md" "Rule Applicability"
assert_contains "$PROJECT_ROOT/.agents/skills/feature-specification/SKILL.md" "Rule Applicability"
assert_contains "$PROJECT_ROOT/.agents/skills/requirement-capture/SKILL.md" "Rule Applicability"
assert_contains "$PROJECT_ROOT/.agents/skills/implementation-plan/SKILL.md" "Rule Applicability Implementation"
assert_contains "$PROJECT_ROOT/.agents/skills/ios-implementation/SKILL.md" "Analytics and observability are conditional"
assert_contains "$PROJECT_ROOT/.agents/skills/ios-ui-layer/SKILL.md" "neither is mandatory"
assert_contains "$PROJECT_ROOT/.agents/skills/android-to-ios-ui-migration/SKILL.md" "Cover every mapped analytics trigger"
assert_contains "$PROJECT_ROOT/.agents/skills/android-to-ios-ui-migration/SKILL.md" "SwiftUI handoff must explicitly verify"
assert_contains "$PROJECT_ROOT/.agents/skills/ios-testing/SKILL.md" "Every required Rule Applicability row"
assert_contains "$PROJECT_ROOT/.agents/skills/feature-orient/SKILL.md" "print-context-index.sh"
assert_contains "$PROJECT_ROOT/.agents/skills/code-quality-fix/SKILL.md" "Rule Applicability matrix"
assert_contains "$PROJECT_ROOT/.agents/skills/ios-code-quality-checks/SKILL.md" "Rule Applicability Harness Contract"
assert_contains "$PROJECT_ROOT/.agents/skills/ios-code-review/SKILL.md" "Rule Applicability Reconciliation"
assert_contains "$PROJECT_ROOT/.agents/skills/ios-test-review/SKILL.md" "Rule Applicability Test Reconciliation"
assert_contains "$PROJECT_ROOT/.agents/skills/code-review-and-quality/SKILL.md" "Reconcile the Approved Rule Contract"
assert_contains "$PROJECT_ROOT/.agents/skills/ios-implementation/SKILL.md" "only triggered context"
assert_contains "$PROJECT_ROOT/harness/templates/sprint-contract-template.md" "Generated Context Index"
assert_contains "$PROJECT_ROOT/harness/templates/summary-template.md" "Context Provenance"
assert_contains "$PROJECT_ROOT/harness/templates/summary-profiles/feature-delivery.md" "Product Document Update"
assert_contains "$PROJECT_ROOT/harness/templates/summary-profiles/bug-fixing.md" "Ad-hoc Bug Fix"
assert_contains "$PROJECT_ROOT/.agents/workflows/create-ui-and-verify.md" "approved Rule Applicability matrix"
assert_contains "$PROJECT_ROOT/.agents/workflows/harness-generator.md" "approved Rule Applicability decisions"
assert_contains "$PROJECT_ROOT/.agents/workflows/harness-fix.md" "Reconcile all Rule Applicability rows again"
assert_contains "$PROJECT_ROOT/.agents/gates/ci-checks.md" "Rule Applicability Harness Contract"
assert_contains "$PROJECT_ROOT/.agents/gates/ci-checks.md" "Acceptance-Test Traceability Contract"
assert_contains "$PROJECT_ROOT/harness/templates/code-review-template.md" "Rule Applicability Reconciliation"
assert_contains "$PROJECT_ROOT/harness/templates/test-review-template.md" "Rule Applicability Test Reconciliation"
assert_contains "$PROJECT_ROOT/AGENTS.md" "rule-applicability-template.md"
assert_contains "$PROJECT_ROOT/AGENTS.md" "feature-specific evidence"
assert_contains "$PROJECT_ROOT/AGENTS.md" "print-context-index.sh"
cmp -s "$PROJECT_ROOT/AGENTS.md" "$HARNESS_AGENTS" || \
    fail "harness AGENTS.md does not match the repository AGENTS.md"
assert_not_contains "$PROJECT_ROOT/.agents/skills/feature-specification/SKILL.md" "rules/compose-rules.md"
assert_not_contains "$PROJECT_ROOT/.agents/skills/api-contract-update/SKILL.md" "./gradlew"
assert_not_contains "$PROJECT_ROOT/.agents/skills/code-quality-fix/SKILL.md" "Ktlint"
assert_not_contains "$PROJECT_ROOT/harness/templates/code-review-template.md" "strings.xml"
assert_not_contains "$PROJECT_ROOT/harness/templates/code-review-template.md" "Composable"
assert_not_contains "$PROJECT_ROOT/harness/templates/test-review-template.md" "koverLog"

TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/rule-applicability-contract.XXXXXX")"
trap 'rm -rf "$TEMP_ROOT"' EXIT

VALID_DOCS="$TEMP_ROOT/valid"
INVALID_DOCS="$TEMP_ROOT/invalid"
mkdir -p "$VALID_DOCS" "$INVALID_DOCS"

create_spec() {
    local output="$1"
    local omit_rule_id="${2:-}"
    local rule_id

    printf '%s\n' '# Spec' '' '## Rule Applicability' '' \
        '| Rule ID | Rule document | Default | Decision for this change | Trigger / rationale | Planned evidence |' \
        '|---|---|---|---|---|---|' > "$output"
    for rule_id in ARCH IMPL TEST SUI L10N NAV API OBS ANL SEC; do
        if [[ "$rule_id" != "$omit_rule_id" ]]; then
            printf '| %s | rule.md | Always | Required | contract test | shell evidence |\n' "$rule_id" >> "$output"
        fi
    done
}

touch "$VALID_DOCS/summary_v1.md" "$INVALID_DOCS/summary_v1.md"
create_spec "$VALID_DOCS/spec_v1.md"
create_spec "$INVALID_DOCS/spec_v1.md" "SEC"

if ! bash "$STAGE_CHECKER" feature-delivery requirement-analysis "$VALID_DOCS" >/dev/null; then
    fail "complete rule-applicability matrix did not pass the requirement gate"
fi

set +e
invalid_output=$(bash "$STAGE_CHECKER" feature-delivery requirement-analysis "$INVALID_DOCS" 2>&1)
invalid_status=$?
set -e

if [[ $invalid_status -eq 0 ]]; then
    fail "incomplete rule-applicability matrix unexpectedly passed the requirement gate"
fi
printf '%s\n' "$invalid_output" | rg -Fq "missing the SEC rule-applicability row" || \
    fail "incomplete matrix did not report the missing rule row"

echo "GREEN: rule-applicability contract passes valid and rejects incomplete requirement artifacts."
