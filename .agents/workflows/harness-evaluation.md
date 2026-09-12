---
description: Evaluate complex-feature code and test review evidence in a post-implementation review.
---

# Workflow: Harness Evaluation

## When to use
- Use this workflow when you are acting as the **Evaluator** agent.
- A change has been implemented and tested and is ready for review by the Generator agent.
- You want a **second-agent review** — a different model/agent reviews code it did not write
- Post-implementation self-review before presenting findings to the user

---

## 1. Core Operating Principles
1. **Be Adversarial & Skeptical**: Assume the Generator agent wrote incomplete, buggy, or "happy-path-only" code. Your job is to find the cracks.
2. **Demand Observability & Evidence**: Do not just check the source code. You must run build commands, run lint checks, run the application, and use simulator testing tools to interact with the UI like a real user.
3. **No Subjective Approvals**: All evaluations must be scored strictly using the categories in `evaluator-rubric.md` and the binary items in `sprint-contract.md`.
4. **Reject Over-forgiving Tendencies**: If a feature is 95% complete but missing a boundary check or styling detail, you **MUST** mark it as "Fail" / "Revise" and output explicit negative feedback. Do not rationalize or make excuses for the generator.

---

## 2. Evaluation Step-by-Step Workflow
When a feature is submitted for review, execute these steps in order:

### Stage 1: Read the Baselines
- Run `bash harness/scripts/check-feature-lifecycle.sh`; stop if lifecycle state is invalid.
- Select the active non-complete `FEATURE_DIR` from the Harness Feature Tracker in `docs/product/product.md`. Do not infer lifecycle state by scanning product directories.
- Read `$FEATURE_DIR/sprint-contract.md` to see the agreed **Acceptance Criteria**, **Scope**, and **Exclusions**.
- Read `$FEATURE_DIR/spec.md` to obtain the complete approved Rule Applicability matrix; independently compare every row with the submitted diff. A missing row, unsupported `Not applicable` outcome, or unapproved exception is a review failure.
- Read `$FEATURE_DIR/feature_list.json` to verify the target feature definition and its current status.
- Run `bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --evaluate`; a missing declared test method, scenario reference, suite-scoped command, or matching successful evidence is a review failure.
- Run `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate`; a platform-bound feature with a missing matrix, pending/unavailable/skipped runtime, fake-only boundary test, or missing successful `xcodebuild test` evidence is a review failure. Non-platform features must explicitly declare `platform_validation.required: false` with a feature-specific reason.
- When `feature_list.json` declares a visual-verification owner, validate visual traceability and perceptual evidence with `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR" --evaluate`; a visual method without a sprint-contract row, successful evidence, non-empty screenshot, reference-anchor proof, or a promoted golden baseline for each non-anchor-only contract screenshot is a review failure. The validator runs `compare-visual-evidence.sh --feature "$FEATURE_DIR" --crop-insets`; design-mockup pixel scores are informational review evidence and must be evaluated semantically for layout, hierarchy, and chrome.
- If the change affects UI, read `docs/product/design_system.md`, `$FEATURE_DIR/design.md`, and its visual assets. Treat unexplained deviations from the global design system as review findings.

---

### Stage 2: Test Review
**INVOKE** the `ios-test-review` skill via the Skill tool (name: `ios-test-review`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Evaluate test coverage, assertions, and shared JSON scenario completeness. Do not stop after this stage — proceed immediately to Stage 3.

**Output**:
- Test review report: `$FEATURE_DIR/test_review_{feature_id}.md`
- The report includes the Rule Applicability Test Reconciliation table.

---

### Stage 3: Code Review
**INVOKE** the `ios-code-review` skill via the Skill tool (name: `ios-code-review`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Perform static analysis and identify logic/architectural flaws. Do not stop after this stage — proceed immediately to Stage 4.

The skill MUST run the repository-wide source-rule bundle:

    bash harness/scripts/check-full-source-rules.sh

This command forces `--all` scans for architecture, SwiftUI, and localization,
checks all test sources for assertion quality, and runs navigation checks. It runs
every checker and aggregates failures; record its complete output and treat any
non-zero result as a review failure, including pre-existing findings.

**Output**:
- Code review report: `$FEATURE_DIR/code_review_{feature_id}.md`
- The report includes the Rule Applicability Reconciliation table.

---

### Stage 4: Execute Runtime Verification
- Execute local unit and integration tests to verify correctness: `xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16'`.
- Run UI tests to check interactivity and transitions: target the simulator.
- Execute every declared real platform boundary test from `platform_validation.real_boundary_test_ids` and require successful connected `xcodebuild test` evidence. Fake adapters, fake callbacks, and seam-only tests are supplemental; an unavailable simulator, permission, service, or other required capability is `Revise`/`Block`, never a skip.
- **If the feature touches the UI**, **INVOKE** the `ui-verification` skill via the Skill tool (name: `ui-verification`) to verify the implemented UI matches the approved mockup/design. Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Compare runtime screenshots against the design assets read in Stage 1 and `docs/product/design_system.md`; any Critical or unresolved Major deviation (wrong layout, spacing, typography, color, clipped text) is a review finding. Record the outcome as visual-evidence contract proof in `$FEATURE_DIR/visual_evidence/` and confirm `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR"` passes, including `reference-anchor-verification.md`.

---

### Stage 5: Quality Assessment ⛔ STOP
The Evaluator's primary deliverable is the final quality assessment report.

*   **`evaluator-rubric.md`**: Generated strictly by following the structure defined in the **[`evaluator-rubric-template.md`](../../harness/templates/evaluator-rubric-template.md)**.

> [!IMPORTANT]
> The Evaluator **MUST** execute the following grading policy inside `evaluator-rubric.md`:
> 1. **Category Scoring**: Evaluate and assign a quantitative score **(0-5)** to each core category based on objective mechanical evidence. Core categories are:
>    *   **Correctness**: Does the behavior match the request?
>    *   **Verification**: Did checks run, with evidence?
>    *   **Scope discipline**: Did it stay inside scope?
>    *   **Reliability**: Does it survive rerun?
>    *   **Maintainability**: Is code/docs clear?
>    *   **Handoff readiness**: Can work continue?
>    *   **Code & Test Review**: Rate the outcome of static analysis (SwiftLint), code structure, and test coverage/robustness from Stages 3 & 4.
> 2. **Calculate Overall Score**: Formulate a comprehensive overall score summarizing quality.
> 3. **Harness File Assessment**: Verify that every required repository harness file is present and assess its quality details:
>    *   `feature_list.json`
>    *   `progress.md`
>    *   `session-handoff.md`
>    *   `clean-state-checklist.md`
>    *   `evaluator-rubric.md` (This file itself)
> 4. **Issue Verdict & Follow-Up**: Document the final verdict (`Accept` | `Revise` | `Block`) and explicitly itemize any missing evidence, required fixes, or review triggers in the **Required Follow-Up** block.

**⛔ STOP — present all review reports and the evaluator rubric to the user.**
The findings are presented for transparency, but the status transition is **driven automatically by the overall score** (see the rule below), not by a manual accept/fix decision.

After presenting the evaluation results, update the Harness Feature Tracker in `docs/product/product.md` with a **score-based transition**:
*   **If the overall score is `5.0 / 5` (perfect)** → transition the feature status from `To be reviewed` → `To be human reviewed`.
*   **If the overall score is less than `5.0 / 5` (not perfect)** → transition the feature status from `To be reviewed` → `To be fixed`. This routes the feature to the **harness-fix workflow** (`.agents/workflows/harness-fix.md`): the Generator resolves every finding in `$FEATURE_DIR/code_review_{feature_id}.md` and `$FEATURE_DIR/test_review_{feature_id}.md`, updates the per-finding status inside those reports, and then transitions to `To be human reviewed`.
*   Update the date to today and add the evaluation verdict (`Accept` / `Revise` / `Block`) and overall score to the notes column.
*   Run `bash harness/scripts/check-feature-lifecycle.sh` after the tracker update. Do not claim completion if it fails.
*   Run `bash harness/scripts/check-evaluation-fix-contract.sh "$FEATURE_DIR" --evaluation`. This is a hard gate: it verifies that the eight category scores round to the declared arithmetic mean, every acceptance Test ID maps to a real declared test method and matching scenario evidence, failed hard-gate items cannot produce a perfect evaluation, every acceptance Test ID has successful evidence without contradictory failure state, and the tracker status matches the score-based route. A report or tracker transition that fails this contract is not an evaluation pass.

---

## Human-in-the-Loop Confirmation Points

1. **After Stage 5 (Quality Assessment)** — user sees all code findings, test findings, and the final evaluator rubric *(mandatory)*. The evaluator then applies the score-based transition automatically: `5.0 / 5` → `To be human reviewed`; `< 5.0 / 5` → `To be fixed` (the Generator then runs the **harness-fix workflow** — `.agents/workflows/harness-fix.md` — and transitions to `To be human reviewed`).
2. **Nit/Optional findings** — user decides which to accept *(optional but recommended)*
