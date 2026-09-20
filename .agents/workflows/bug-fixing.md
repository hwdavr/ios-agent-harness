---
description: Diagnose and fix an iOS bug with RED reproduction, approved planning, and GREEN verification.
---

# Workflow: Bug Fixing

## When to use
- A defect, crash, or production issue
- A regression or test failure
- Unexpected app behavior

Do not use this workflow for a localized, intentional UI-only adjustment to an
existing screen when the change has no API, persistence, domain, ViewModel behavior,
navigation, or new user-journey impact. Route that request to the **Small UI Patch
Triage** direct `ios-ui-layer` skill lane; it does not need this workflow's RED
reproduction, fix-plan, or other workflow stages.

This workflow prioritises root-cause analysis over quick patching.

---

## Core Principle

Do not fix symptoms first. Do not guess — prove it with a failing test.
**The reproduction test must be RED before the Fix Plan is written.**
**The Fix Plan must be approved before any fix code is written.**

Pipeline: Bug Context & Root Cause → Bug Reproduction (TDD) → Fix Plan → [User Approval] → Implementation → Testing → Code Quality Fix → Install App To Simulator

---

## Stage Execution

### Stage 1 — Bug Context, Localization & Root Cause
**INVOKE** the `requirement-analysis` skill via the Skill tool (name: `requirement-analysis`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Adapt for bugs:
- Bug description, expected vs. actual behavior
- Fault localization (View → ViewModel → UseCase → Repository → API)
- Root cause statement (triggered when \<cond\>, causing \<behavior\>)
- Design the fix (UIState changes if needed)

Output: `docs/current/spec_v<N>.md` created; `docs/current/summary_v<N>.md` updated with Context Provenance and stage evidence. The summary references the approved Rule Applicability matrix in the spec rather than copying it.
The specification must assess only the fix scope and retain an explicit rationale for every non-applicable rule.
Gate: root cause is specific enough that a reproduction test can be written and all ten rule decisions are explicit. Run `bash harness/scripts/check-stage-artifacts.sh bug-fixing requirement-analysis` — must exit 0.

---

### Stage 2 — Bug Reproduction (TDD) ⛔ STOP
**INVOKE** the `bug-reproduction` skill via the Skill tool (name: `bug-reproduction`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Write a failing test that mechanically proves the root cause before any fix is written.

Output: Failing reproduction test file created; `docs/current/spec_v<N>.md` updated with a Reproduction Test section; `docs/current/summary_v<N>.md` updated.
Gate: test exits RED (non-zero), failure message matches root cause, no application code modified.
**STOP — if root cause cannot be reproduced by a test, surface to user before continuing.**

---

### Stage 3 — Fix Plan ⛔ STOP
**INVOKE** the `implementation-plan` skill via the Skill tool (name: `implementation-plan`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Adapt — the plan must include:
- Root cause (reference the reproduction test as evidence)
- Proposed fix (minimal)
- A link to the approved `spec_v<N>.md#rule-applicability` record plus implementation evidence for every `Required` rule, including changed triggers and verification evidence

Output: `docs/current/implementation_plan_v<N>.md` created; `docs/current/summary_v<N>.md` updated.
Gate: Run `bash harness/scripts/check-stage-artifacts.sh bug-fixing implementation-plan` — must exit 0. **STOP — present fix plan to user. Do not proceed until user explicitly approves.**

---

### Stage 4 — Implementation (Data + Domain + UI as needed)
**INVOKE** the `ios-implementation` skill via the Skill tool (name: `ios-implementation`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Adapt — only implement the layers the bug fix touches. Skip layers that are unaffected.

Output: `docs/current/summary_v<N>.md` updated with Implementation stage marked complete.
Gate: `xcodebuild -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' build` passes, all affected layer rules satisfied.

---

### Stage 5 — Testing
**INVOKE** the `ios-testing` skill via the Skill tool (name: `ios-testing`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

For navigation, saved-state, back-stack, destination-recreation, or post-return
persistence defects, the test plan must include a `## Production Journey Boundary`
section naming an XCUITest that mounts the production entry point, performs the
real UI actions, crosses the return boundary, and asserts the visible result after
return. Direct ViewModel or `*Content` tests are supplemental evidence only.

Output: Unit tests, integration tests, and shared JSON scenarios created or updated; `docs/current/summary_v<N>.md` updated with test count and coverage.
Gate: tests pass, coverage targets met. If `NAV` is `Required`, run
`bash harness/scripts/check-stage-artifacts.sh bug-fixing testing docs/current`; it
must exit 0.

---

### Stage 6 — Code Quality Fix
**INVOKE** the `code-quality-fix` skill via the Skill tool (name: `code-quality-fix`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Run the code-quality-fix stage to verify complete baseline correctness.

For bug fixes, additionally verify:
- The reproduction test is GREEN after the fix
- No regressions in the full suite
- The minimal-fix constraint: no unrelated changes slipped in

Output: `docs/current/summary_v<N>.md` updated with code quality results.
Gate:
- All conditions in `skills/code-quality-fix/SKILL.md` pass
- The reproduction test is GREEN after the fix

---

### Stage 7 — Install App To Simulator
Install the completed debug build to the simulator as the final delivery step.

**Actions**:
1. Build and install to the booted simulator:
    ```bash
    xcrun simctl install booted Build/Products/Debug-iphonesimulator/NotesTakingAppiOS.app
    ```
2. Record the install command, simulator UDID, and exit status in `docs/current/summary_v<N>.md`.

Output: Debug app installed on simulator.
Gate: install command exits with code 0. If no simulator is booted, mark this stage blocked with the `xcrun simctl list devices` output and do not claim delivery is fully complete.

---

## Human-in-the-Loop Confirmation Points

1. **After Bug Context, Localization & Root Cause** — if root cause is uncertain, ask user
2. **After Bug Reproduction** — if the bug cannot be reproduced by a test, surface to user *(mandatory stop)*
3. **After Fix Plan** — user approves fix plan *(mandatory always)*
