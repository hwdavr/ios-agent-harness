---
name: ios-testing
description: Implement unit, integration, and UI tests according to the test plan.
---

# Skill — iOS Testing

## Purpose
After implementation, write or complete all approved tests and mechanically verify they pass.
This stage **generates** — it does not evaluate quality. That is the Test Review stage's job.

Bug fixes perform RED reproduction through the `bug-reproduction` skill before implementation;
this skill performs the later GREEN verification. Feature and enhancement workflows implement
approved behavior before invoking this skill.

---

## Load

**At a new session, load L1:**
- `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read

**Then load only the selected test-layer guidance:**
- `rules/testing-practices.md` for test structure, doubles, reliability, and assertion quality
- `skills/ios-unit-test/SKILL.md` for unit or integration coverage
- `skills/ios-ui-test/SKILL.md` for UI, navigation, visual, or platform-bound coverage
- `rules/testing-runtime-evidence.md` only for UI, navigation, visual, platform, or runtime claims
- `skills/shared-json-scenarios/SKILL.md` only when an API endpoint or shared fixture is in scope
- `rules/ios-security.md` when the test covers a security boundary; use its
  required real-runtime boundary evidence and fail loudly when the runtime is unavailable

**Adhoc workflows** (`feature-delivery`, `bug-fixing`):
- `docs/current/test_plan_v<N>.md` — test cases, layers, and coverage targets approved by user
- `docs/current/spec_v<N>.md` — approved Rule Applicability decisions and triggers

**Harness workflow** (`harness-generator`):
- Run `bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"`.
- Read only the selected acceptance-test rows and matching `feature_list.json` entry. Read the summary only for prior evidence, blockers, and handoff decisions.

---

## Execute

### 1. Execute Planned Tests
For ad-hoc workflows, read the approved `docs/current/test_plan_v<N>.md` and Rule
Applicability matrix in `spec_v<N>.md`. For the harness workflow, read the selected
user story and its acceptance-test rows in `$FEATURE_DIR/sprint-contract.md`, the
matching `verification` and `production_journey` entries in `$FEATURE_DIR/feature_list.json`,
and the matrix in `$FEATURE_DIR/spec.md`. When `production_journey.required` is `true`,
implement the named acceptance-test owner as a production-entry journey with the declared
actions, return boundary, and visible post-return assertion. Map every `Required` rule
to a test, static check, or explicit review evidence. Preserve the rationale for
non-applicable/exception rows; do not invent analytics or logging tests without a trigger.

### 2. Unit tests (`NotesTakingAppiOSTests/`)
Write unit tests for all new or modified use cases, ViewModels, mappers, and formatters.
Follow `skills/ios-unit-test/SKILL.md` for framework, naming, and coverage rules.

### 3. Integration tests (`NotesTakingAppiOSTests/` or `NotesTakingAppiOSUITests/` loopback boundary)
Write integration tests if an API is involved. Test success, 4xx, 5xx, malformed payload, timeout, and unknown enum fallback per endpoint.
Follow `skills/ios-integration-test/SKILL.md` — use shared JSON scenarios, do not inline mock data. When the test
target owns a loopback server, start it before `XCUIApplication.launch()`, drive the shipped `URLSession` client,
assert redacted request receipts and decoded results, and fail if the listener or endpoint setup is unavailable.

### 4. UI tests (`NotesTakingAppiOSUITests/`)
Write UI tests only when simulator runtime or real UI rendering is required.
Follow `skills/ios-ui-test/SKILL.md` — use `accessibilityIdentifier`, not static text; no `sleep()`.

### 5. Run and record results
```bash
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath Build -enableCodeCoverage YES
xcrun xccov view --report Build/Logs/Test/*.xcresult
bash harness/scripts/check-coverage.sh "$(find Build/Logs/Test -maxdepth 1 -type d -name '*.xcresult' -print -quit)" --exclude-target SwiftMath
```

Record the exact command, exit code, test count, and coverage percentage in the stage evidence. Keep verbose tool output in a referenced log or generated report; do not copy it into the summary.

For the harness workflow, after writing tests and before leaving this stage, run the
acceptance-test traceability checker in evaluation mode:
```bash
bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --evaluate "$FEATURE_ID"
```
The gate requires every selected acceptance Test ID to name a real test method and
suite-scoped command. A shared scenario declared by that Test ID must be referenced
from the named method. For a required production journey, also run
`bash harness/scripts/check-journey-test-contract.sh` with the planned test file,
method, and production entry point; the source checker must find the real navigation,
gestures, return boundary, and visible post-return assertion.

---

## Output

New or updated test files.
New or updated shared JSON scenarios in `sharedContracts/test-scenarios/`.

Update `summary_{feature_id}.md` (or `summary_v<N>.md` depending on the active workflow): mark the Testing stage complete with test count and coverage.

---

## Done When

**This stage is complete when all of the following are true — all must be mechanically verifiable:**
- [ ] `xcodebuild test` — exit code 0
- [ ] Coverage gate passes: overall project-owned coverage ≥ 80%, new classes ≥ 90% (via `harness/scripts/check-coverage.sh` and `--min-file` thresholds)
- [ ] Total test count `> 0` (not `0/0` — this is a gate failure)
- [ ] At least one integration test per new or changed API endpoint (when API is in scope), owned by the lowest useful target; a UI-test loopback boundary is valid when the real app process is part of the claim
- [ ] Shared JSON scenarios used — no inline mock response data in test files (when API is in scope)
- [ ] UI tests pass (if added)
- [ ] Every `Required` Rule Applicability row from the canonical specification has the planned verification evidence
- [ ] Harness workflow: acceptance-test traceability gate passes for the selected slice

**APPROVED →** Return to the active workflow file and proceed to the next stage defined there.

**REVISION REQUIRED →**
- If `total_tests == 0` → return to the Testing stage, add missing tests
- If coverage < 80% → return to the Testing stage, add missing unit tests
- If test failures exist → fix the failing tests (which may require fixing application code)
- If a compilation error was introduced → return to the stage that caused it

**Iteration cap:** 2 rounds of test revision. If still failing, surface the specific failure to the user.
