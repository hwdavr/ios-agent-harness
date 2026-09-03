---
name: ios-testing
description: Implements unit, integration, and UI tests according to the test plan.
---

# Skill — iOS Testing

## Purpose
Write all tests for the change and mechanically verify they pass.
This stage **generates** — it does not evaluate quality. That is the Test Review stage's job.

The article principle: write the failing test *before* touching the application code for bug fixes and new behavior.

---

## Load

**Always load:**
- `skills/ios-unit-test/SKILL.md`
- `skills/ios-ui-test/SKILL.md`
- `skills/shared-json-scenarios/SKILL.md`
- `rules/testing-strategy.md`
- `harness/templates/rule-applicability-template.md`

**Adhoc workflows** (`feature-delivery`, `bug-fixing`):
- `docs/current/test_plan_v<N>.md` — test cases, layers, and coverage targets approved by user
- `docs/current/spec_v<N>.md` — approved Rule Applicability decisions and triggers

**Harness workflow** (`harness-generator`):
- `$FEATURE_DIR/sprint-contract.md` — verification plan mapped to each acceptance criterion
- `$FEATURE_DIR/spec.md` — approved Rule Applicability decisions and triggers
- `$FEATURE_DIR/summary_{feature_id}.md` — active feature context and stage progress

---

## Execute

### 1. Execute Planned Tests
For ad-hoc workflows, read the approved `docs/current/test_plan_v<N>.md` and Rule
Applicability matrix in `spec_v<N>.md`. For the harness workflow, read the selected
user story and its acceptance-test rows in `$FEATURE_DIR/sprint-contract.md`, the
matching `verification` entry in `$FEATURE_DIR/feature_list.json`, and the matrix in
`$FEATURE_DIR/spec.md`. Map every `Required` rule to a test, static check, or explicit
review evidence. Preserve the rationale for non-applicable/exception rows; do not
invent analytics or logging tests without a trigger.

### 2. Unit tests (`NotesTakingAppiOSTests/`)
Write unit tests for all new or modified:
- Domain use case logic
- ViewModel state transitions
- Mapper logic (DTO → Domain, Domain → UI)
- Formatting and fallback logic

Rules:
- Use Swift Testing framework (`@Test`, `#expect`)
- Class/struct name ends with `Tests`
- One main scenario per test
- 90% line coverage target for new ViewModel and domain classes

### 3. Integration tests (`NotesTakingAppiOSTests/`)
Write integration tests if an API is involved.

For each changed API endpoint, test:
- Success response (2xx)
- 4xx client error
- 5xx server error
- Malformed or partial payload
- Network timeout / disconnect
- Unknown enum value (must not crash — must return fallback)

Rules:
- Use Swift Testing or XCTest with `async`/`await`
- **Use shared JSON scenarios — do not inline mock data** (read `skills/shared-json-scenarios/SKILL.md`)
- Store scenarios in `sharedContracts/test-scenarios/`
- If API used by a ViewModel: assert `expected.ui` from the scenario
- If API used only by repo / use case: assert `expected.domain`

### 4. UI tests (`NotesTakingAppiOSUITests/`)
Write UI tests only when simulator runtime or real UI rendering is required.

Rules:
- Use `XCUIApplication` with XCUITest
- Use `accessibilityIdentifier` to locate elements — not static text
- Do not use `sleep()` — use `waitForExistence` or expectations
- One main business scenario per test

### 5. Run and record results
```bash
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath Build -enableCodeCoverage YES
xcrun xccov view --report Build/Logs/Test/*.xcresult
bash harness/scripts/check-coverage.sh "$(find Build/Logs/Test -maxdepth 1 -type d -name '*.xcresult' -print -quit)" --exclude-target SwiftMath
```

Record every result number in the output report below. Do not summarize — copy actual pass/fail counts and coverage percentages verbatim from the tool output.

For the harness workflow, after writing tests and before marking Testing complete, run:
```bash
bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --test "$FEATURE_ID"
```
The gate requires every selected acceptance Test ID to name a real test method and suite-scoped command. A shared scenario declared by that Test ID must be referenced from the named method.

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
- [ ] At least one integration test per new or changed API endpoint
- [ ] Shared JSON scenarios used — no inline mock response data in test files
- [ ] UI tests pass (if added)
- [ ] Every required Rule Applicability row has the planned verification evidence
- [ ] Harness workflow: acceptance-test traceability gate passes for the selected slice

**APPROVED →** Return to the active workflow file and proceed to the next stage defined there.

**REVISION REQUIRED →**
- If `total_tests == 0` → return to the Testing stage, add missing tests
- If coverage < 80% → return to the Testing stage, add missing unit tests
- If test failures exist → fix the failing tests (which may require fixing application code)
- If a compilation error was introduced → return to the stage that caused it

**Iteration cap:** 2 rounds of test revision. If still failing, surface the specific failure to the user.
