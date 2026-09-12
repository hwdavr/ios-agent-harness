---
description: Implement an approved complex iOS feature slice through harness-generator stages.
---

# Workflow: Harness Generator

## When to use
Use this workflow when you are acting as the **Generator** (Implementer) agent. This workflow ensures that you are properly oriented, verify safety baselines, implement features surgical-by-surgical, test continuously, and commit clean states back to the repository.

## Planning Authorization

This workflow starts only after the user approves `feature_list.json` and `sprint-contract.md` in one dated `docs/product/<YYYY-MM-DD>-<feature-short-name>/` workspace created by `harness-planning`. That approval authorizes implementation of the selected slice. Do not generate or request approval for a duplicate implementation plan in this workflow; the active feature description, sprint acceptance criteria, design, and verification commands are the implementation plan of record.

Before implementation begins, preserve the approved Rule Applicability decisions from
the feature specification in the slice evidence and carry each Required row into its
implementation and verification records.

---

## Gate Semantics

Every required stage gate is a hard stop. A gate may advance only after its command exits `0` and its required evidence is recorded. Any failure or unavailable prerequisite must be recorded as `⚠️ Blocked` or non-passing, and the workflow must stop before the next stage.

---

---

## 🔄 Stage Execution Pipeline

> **Routing**: If the active feature's tracker status is `To be fixed`, **stop here** — this workflow does not apply. Instead, follow the **[harness-fix workflow](harness-fix.md)** in full. It runs the Fix Mode Pipeline (resolve every `code_review` / `test_review` finding and update the per-finding status inside those reports, then transition to `To be human reviewed`). Stages 1–8 below apply only when implementing a new slice (status `In Progress` / `Awaiting implementation approval`).

### Stage 1 — Orient
Before making any changes or planning code, gather complete session and git context. Select the next task to implement.
*   **Action**: **INVOKE** the `feature-orient` skill via the Skill tool (name: `feature-orient`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.
*   **Objective**: Run `bash harness/scripts/check-feature-lifecycle.sh`, select the approved `docs/product/` workspace from the Harness Feature Tracker by status, run `bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"`, and establish the sprint contract plus `feature_list.json` as the only requirement/execution authorities. The slice summary records their paths and hashes as Context Provenance; it does not duplicate scope, acceptance criteria, or the Rule Applicability matrix. Read and validate `$FEATURE_DIR/platform-capability-matrix.md` when the feature is platform-bound (`platform_validation.required: true`). If the index reports `affects_ui: true`, read `docs/product/design_system.md`, the approved feature `design.md`, and its mockups before implementation.

### Stage 2 — Setup
Verify target simulator runtime environment readiness.
*   **Action**:
    1. Check for booted simulators:
        ```bash
        xcrun simctl list devices | grep Booted
        ```
    2. If the command succeeds, **update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Setup** stage status as completed (✅) with notes and the current timestamp. If it fails, record Setup as `⚠️ Blocked` and stop.
*   **Objective**: Confirm simulator availability for runtime testing. Register progress in the summary.
*   **Gate**: The command must exit `0` and identify a booted simulator. If it exits non-zero or no booted simulator is found, mark Setup `⚠️ Blocked` with the raw output and stop the pipeline. Do not advance to Verify Baseline or Implement.

### Stage 3 — Verify Baseline
Ensure that the existing codebase compiles and all tests pass before making any changes. The previous session or developer may have introduced bugs or broken tests.
*   **Action**:
    1. Run the repository-wide source-rule bundle and test suites:
        ```bash
        bash harness/scripts/check-full-source-rules.sh
        xcodebuild -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' build
        xcodebuild -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' test
        ```
       The source-rule bundle always scans the complete production and test source
       trees. It runs every checker even when one fails and returns non-zero if any
       checker reports a violation; record the complete output before stopping.
    2. If all commands succeed, **update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Verify Baseline** stage status as completed (✅) with notes and the current timestamp. If any fails, record Verify Baseline as `⚠️ Blocked` and stop.
*   **Objective**: Confirm the repository is in a perfectly stable, compilable, and green state. If the baseline is broken, stop and fix existing regressions first! Register status in `$FEATURE_DIR/summary_{feature_id}.md`.
*   **Gate**: All commands must exit `0`. If any command fails, mark Verify Baseline `⚠️ Blocked`, record the command and raw failure output, and stop the pipeline. Do not begin implementation.

### Stage 4 — Implement
Build out the selected feature across the necessary layers.
*   **Action**:
    1. **INVOKE** the `ios-implementation` skill via the Skill tool (name: `ios-implementation`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.
    2. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Implement** stage status to completed (✅) with list of created/modified files.
*   **Objective**: Only the layers and conditional rules selected by the approved slice are implemented, `xcodebuild build` compiles cleanly, UI changes conform to `docs/product/design_system.md` plus approved feature exceptions, and progress is logged in the summary.

This workflow is implementation-first; do not insert a feature-level RED/TDD stage before Stage 4.

### Stage 5 — Test
Verify the correctness of the implemented behavior visually and logically.
*   **Action**:
    1. **INVOKE** the `ios-testing` skill via the Skill tool (name: `ios-testing`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism. Implement every `Acceptance Test Cases` row in the selected user story. The primary acceptance test must exercise the production entry point; an isolated helper or use-case test cannot substitute for user-visible or cross-layer behavior. Verify through the actual UI/API and meet code coverage targets (overall project **≥ 80%**, ViewModel & Use Case **≥ 90%**).
    2. If the selected slice declares `requires_visual_verification: true`, **INVOKE** the `ui-verification` skill via the Skill tool (name: `ui-verification`). After semantic approval of each non-anchor-only capture, promote it with `bash harness/scripts/compare-visual-evidence.sh --promote-golden "$FEATURE_DIR/visual_evidence/<capture>.png" --name "<capture>"`; do not promote an unreviewed capture. Its perceptual-comparison phase must then run `bash harness/scripts/compare-visual-evidence.sh --feature "$FEATURE_DIR" --crop-insets`, classify any Critical or unresolved Major deviation, and preserve the report and diff overlays. Finally run `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR" --evaluate`; this gate requires every non-anchor-only capture to have a promoted golden baseline and invokes the comparator. A missing baseline, missing reference, comparator failure, or unresolved visual finding is `⚠️ Blocked`.
    3. Run `bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --test "$FEATURE_ID"`. It must confirm that every acceptance Test ID for the selected slice names a real Swift test method, a suite-scoped `-only-testing` command, and each declared shared JSON scenario from that method. If it fails, record Test as `⚠️ Blocked` and stop.
    4. Run `bash harness/scripts/check-journey-registry.sh --run-all` to verify that the current implementation does not regress any existing critical journey. A failure blocks the pipeline.
    5. If all required tests, the visual gate when applicable, the traceability gate, and the mechanical coverage gate (`bash harness/scripts/check-coverage.sh ... --exclude-target SwiftMath`, plus `--min-file <path>=90` for each new ViewModel or domain use case) succeed, **update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Test** stage status as completed (✅), detailing coverage percentages, passed test counts, visual comparison results, and any blocked runtime explicitly. If any required check fails, record Test as `⚠️ Blocked` with the command and raw output and stop.
*   **Objective**: All local tests pass cleanly, coverage targets are fully met, and verification evidence is documented in the summary.

### Stage 6 — Code Quality Fix
Run all static check suites, lint rules, and custom compliance rules, and resolve all violations.
*   **Action**: **INVOKE** the `code-quality-fix` skill via the Skill tool (name: `code-quality-fix`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.
*   **Required gate**: The skill MUST run `bash harness/scripts/check-full-source-rules.sh` after its individual checks. This bundle is the authoritative repository-wide architecture, SwiftUI, localization, navigation, and test-assertion gate; do not substitute a changed-file invocation.
*   **Objective**: Diagnose and resolve all formatting, quality, localization, and architectural style guidelines issues, reconcile any newly discovered rule trigger with the approved matrix, and log check success in `$FEATURE_DIR/summary_{feature_id}.md`.
*   **Gate**: All required quality checks must exit `0`. If any check fails, record the failing command and raw output, mark this stage `⚠️ Blocked`, and stop the pipeline.

### Stage 7 — Update State
Verify all acceptance criteria, update project state, commit, and record progress.

> [!IMPORTANT]
> **Strict Verification Gate**: You **CANNOT** directly or arbitrarily change a feature's status to `passing` in `feature_list.json`. Transitioning a feature to `passing` is a gate controlled exclusively by executing successful verification commands.
>
> **Gate Check Policy**:
> 1. **Identify Gate Criteria**: Read the selected user story in `$FEATURE_DIR/sprint-contract.md`. Every `Acceptance Test Cases` command is a mandatory gate. The active feature's `"verification"` field must reference the same Test IDs and commands.
> 2. **Validate fresh evidence**: Reuse successful Test-stage evidence only after `bash harness/scripts/check-evidence-receipt.sh <receipt.json> --source <hash> --build-config <hash> --command <hash> --runtime <hash>` confirms that the production sources, build/test configuration, declared verification command, runtime target, exit code, and evidence file are unchanged. Re-run only the affected command when validation fails; do not repeat a green acceptance suite solely to copy its output into a later stage.
> 3. **On Failure — bounded diagnosis and retry**: If any verification command fails (exit code `non-zero`), keep the stage non-passing and diagnose, fix, and re-run that specific command up to three times. If it remains non-zero, record the gate as `⚠️ Blocked` or non-passing and stop before the next verification item.
> 4. **Validate & Attach Evidence**:
>    *   The status can **ONLY** transition to `passing` if **every** acceptance-test command eventually executes successfully (exit code `0`) — either on the first run or after resolution.
>    *   You **MUST** attach objective evidence for every Test ID, including the command, exit status, fix attempts (if any), and final result, inside the `"evidence"` field of the active feature object.
>    *   If any verification command remains unresolved after 3 fix attempts, the status must be marked as `blocked` or returned to `in_progress`. Document all unresolved items.
>    *   A visual-verification owner cannot transition to `passing` unless `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR" --evaluate` exits `0`. This requires a non-empty screenshot and a `visual_evidence/reference-anchor-verification.md` row for every visual Test ID; the row must connect the approved reference to a visual bounds `accessibilityIdentifier`, a runtime assertion, and a concrete measured relationship. Every non-anchor-only capture must also have an approved `UX/golden-baselines/<capture>.png`; the validator invokes `bash harness/scripts/compare-visual-evidence.sh --feature "$FEATURE_DIR" --crop-insets` and fails on a binding golden-regression failure or missing reference. Design-mockup comparisons remain informational and require semantic UI review.

*   **Action**:
    1. Execute the verification gate (see Gate Check Policy above). Attach evidence to `feature_list.json`, then run `bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --evaluate "$FEATURE_ID"`. A slice cannot transition to `passing` unless the recorded evidence command is scoped to every declared acceptance test suite.
    2. Once verification passes and evidence is attached, update `$FEATURE_DIR/feature_list.json` and `$FEATURE_DIR/progress.md`.
    3. Update `docs/product/product.md` directly:
        *   Update the **Product Portfolio Summary** to reflect the delivered slice.
        *   Add the feature to **Current Product Capabilities** with its delivered behavior and notable implementation notes.
        *   Remove the feature from the **Roadmap — Planned Features** section if it is fully delivered, or update its priority column to reflect remaining sub-features.
        *   Update the `*Document last updated*` date at the bottom of the file.
        *   If every feature in `$FEATURE_DIR/feature_list.json` is now `passing`, update the Harness Feature Tracker status to `To be reviewed` in place and update its date/notes (do not move or rename the workspace). **NEVER transition directly to `To be human reviewed`** — only the Evaluator agent (via `harness-evaluation`) is authorized to make that transition after scoring. Otherwise, keep the Harness Feature Tracker `In Progress` while slices remain.
        *   Run `bash harness/scripts/check-feature-lifecycle.sh` after the tracker update. Do not claim completion or commit if it fails.
    4. If the shipped slice has `production_journey.required: true`, register the journey in `docs/product/journey-registry.yaml` using the sprint-contract values. Run `bash harness/scripts/check-journey-registry.sh --validate` to confirm the entry is well-formed.
    5. Populate the `## Observability & Execution Metrics` section directly in `$FEATURE_DIR/summary_{feature_id}.md` (following [`harness/templates/summary-template.md`](../../harness/templates/summary-template.md), recording model name, duration, files modified, commands executed, retries, and the embedded `json:metrics` block). Run `bash harness/scripts/check-harness-metrics.sh --validate "$FEATURE_DIR/summary_{feature_id}.md"` to verify metrics integrity.
    6. Commit only the **source code, test changes, and product documentation** for the implemented feature:
        ```bash
        git commit -m "feat(<area>): <short description of implemented feature>"
        ```
    7. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Update State** stage status to completed (✅), logging the commit hash and verification execution outcome.
*   **Objective**: Ensure all state updates are backed by mechanical, verifiable evidence. The stable product workspace remains at the same path throughout delivery.

### Stage 8 — Clean Exit
Ensure that the final repository state is clean, verified, and fully prepared for the next developer or agent session.

> [!IMPORTANT]
> **Checklist & Handoff Policy**:
> 1. **Run Clean State Checklist**: Copy the Core checks and only the triggered conditional sections from **[`clean-state-checklist-template.md`](../../harness/templates/clean-state-checklist-template.md)**. Record every omitted trigger as `N/A — <feature-specific reason>`. Reference fresh Test and Code Quality evidence while its receipt remains valid; rerun only invalidated evidence. A failed required item keeps Clean Exit non-passing and stops the pipeline.
> 2. **Produce Session Handoff**: Create or update **`$FEATURE_DIR/session-handoff.md`** by strictly following the format and fields defined in **[`session-handoff-template.md`](../../harness/templates/session-handoff-template.md)**. Detail what is working, what changed, unverified paths, risks, unresolved gate items, and next steps.
> 3. **Verify Observability Metrics**: Run `bash harness/scripts/check-harness-metrics.sh --validate "$FEATURE_DIR/summary_{feature_id}.md"` to confirm execution metrics are complete.
> 4. **Never move the feature directory.** Its `docs/product/` path is stable; only tracker and per-slice statuses change.

*   **Action**:
    1. Verify all checklist criteria, reference fresh Test and Code Quality evidence, and write `$FEATURE_DIR/session-handoff.md`. Re-run only a verification command invalidated by a later relevant change.
    2. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Clean Exit** stage status to completed (✅), transition the selected slice summary to Complete, and document key outcomes, open items, and handoff decisions.
*   **Objective**: Leave the repository in a completely green, stable, and self-documenting state that a fresh session can immediately pick up and resume.

### Stage 9 — Install App To Simulator
Install the completed debug build to the simulator as the final generator step when the slice affects UI, requires instrumented/platform verification, or the user explicitly requests installation. Otherwise record `N/A — no iOS runtime or installation boundary in the approved scope`.

*   **Action**:
    1. Install the app to the booted simulator:
        ```bash
        xcrun simctl install booted Build/Products/Debug-iphonesimulator/NotesTakingAppiOS.app
        ```
    2. **Update `$FEATURE_DIR/summary_{feature_id}.md`** to mark the **Install App To Simulator** stage status to completed (✅), logging the simulator UDID, install command, timestamp, and exit status.
*   **Objective**: Leave the implemented feature installed on the simulator for immediate manual review.
*   **Gate**: When required, the install command must exit 0; failure or no booted simulator is `⚠️ Blocked`. When not required, the explicit N/A rationale completes the stage without an install command.
