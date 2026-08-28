---
description: Migrate Android behavior and business logic (including affected UI interactions) to iOS with test-first parity and dated feature-folder artifacts.
---

# Workflow: Android → iOS Migration

## When to use
- Migrating any Android feature behavior from `../NotesTakingApp` to iOS, including ViewModels, use cases, repository behavior, screen interactions, loading/empty/error states, navigation, and visible controls
- Porting Android behavior while preserving the iOS architecture (`View → ViewModel → Domain ← Data`) and the existing SwiftUI design system
- For any affected SwiftUI screen, this workflow must also invoke `android-to-ios-ui-migration` and include interaction/state verification; use `create-ui-and-verify` only for UI work that is not part of an Android migration
- Not for API contract changes (use the api-contract-update path) or brand-new non-migrated product behavior (use feature-delivery)

## Core Principle

- **Android source is the behavior authority.** Every Android class/method that affects the feature must be read and mapped; iOS architecture rules constrain how the behavior is re-implemented.
- **Test-first.** Migrate/port the test cases *before* the production code. The tests encode Android-parity behavior and must be RED (failing or non-compiling against the current iOS API) before implementation starts.
- **Dated feature workspace.** Spec, plans, design/visual assets, and evidence live in `docs/product/<YYYY-MM-DD>-<feature-short-name>/`, not `docs/current/`. Keep a stable workspace for the feature's whole lifecycle.
- **Clarify before writing.** Surface every material open question to the user via `ask_questions` before producing the spec. No unresolved assumptions in the spec.
- **Every stage gate must pass before advancing.** The implementation authorization gate is mandatory.

Pipeline: Android Behavior + UI Analysis → Clarification & Specification → [User Approval] → Implementation & Test Plan → [User Approval] → Test Migration (RED) → Implementation (GREEN) → UI/Integration Verification → Testing → Code Quality Fix → Product Document Update & Knowledge Capture

---

## Stage Execution

### Stage 1 — Android Behavior Analysis
**INVOKE** the `requirement-analysis` skill via the Skill tool (name: `requirement-analysis`) — reading SKILL.md manually is not a substitute. Adapt for migration: the requirement is the complete Android behavior contract, not only domain logic.

If Android screen code, SwiftUI views, or visible interactions are affected, also **INVOKE** `android-to-ios-ui-migration` via the Skill tool. Do not classify the work as logic-only merely because the ViewModel is the primary implementation surface.

Load:
- The Android source for the feature: ViewModels, domain repositories, repository implementations, DAOs/contracts, UI models, screen layouts, callbacks, navigation wiring, loading/refresh behavior, and action-sheet/menu behavior
- The frozen shared contracts (`sharedContracts/openapi.yaml`, `sharedContracts/local-storage-contract.md`)
- `.agents/rules/ios-architecture.md` and `.agents/rules/testing-strategy.md`

Create the dated workspace `docs/product/<YYYY-MM-DD>-<feature-short-name>/` with:
- `android_logic_map.md` — one row per Android class/method/behavior: Android source path (cite file + line), iOS equivalent, parity decision (exact port / platform adaptation / deferred), and any data-layer or contract gap found. Include UI states, gestures, controls, presentation styles, accessibility semantics, and responsive bounds when applicable.
- `assets/` — screenshots, state captures, measurement notes, and other migration evidence when UI is affected.
- `summary.md` — stage progress table (use `harness/templates/progress-template.md` and the workflow stage table below).

Gate: `bash harness/scripts/check-stage-artifacts.sh android-to-ios-migration android-analysis docs/product/<date>-<feature>` exits 0; every Android behavior affecting the feature is mapped or explicitly recorded out of scope. UI-affected migrations must also identify the `android-to-ios-ui-migration` analysis and assets.

### Stage 2 — Clarification & Specification ⛔ STOP
1. **Ask the user every material open question** with `ask_questions` — scope (full parity vs read-only), repository wiring, fixture policy, navigation/handoff behavior, data-layer gaps found in Stage 1, artifact supersession, UI-test fixture strategy. Do not guess.
2. Write `spec.md` in the dated workspace using `harness/templates/spec-template.md` (ad-hoc) adapted to the workspace layout. Include: functional requirements with stable IDs (FR-xxx), acceptance criteria, Android-parity edge cases, explicit assumptions, and a fully answered open-questions table.
3. Produce `design.md` only when the migration changes visible UI; otherwise state "logic-only, no design artifact" in the summary.

Gate: no open questions remain; `bash harness/scripts/check-stage-artifacts.sh android-to-ios-migration specification <dated-workspace>` exits 0.
**STOP — present the spec (and design, if produced) to the user and obtain explicit scope confirmation before planning or test migration.**

### Stage 3 — Implementation & Test Plan ⛔ STOP
**INVOKE** the `implementation-plan` skill via the Skill tool (name: `implementation-plan`). Produce `implementation_plan.md` and `test_plan.md` in the dated workspace (structure from `harness/templates/implementation-plan-template.md` / `test-plan-template.md`).

The plan must:
- Map every parity decision in `android_logic_map.md` to files (create/modify/delete) and change types.
- Include the data-layer gaps found in Stage 1 (e.g., repository methods missing Android semantics) with explicit fixes.
- Define the iOS public API surface the migrated tests will target.
- Order the work as: tests first (RED), then implementation (GREEN).

Gate: `bash harness/scripts/check-stage-artifacts.sh android-to-ios-migration implementation-plan <dated-workspace>` exits 0.
**STOP — present the plan. Do not write tests or production code until the user explicitly approves the plan.**

### Stage 4 — Test Migration (RED)
**INVOKE** the `ios-testing` skill via the Skill tool (name: `ios-testing`). If UI is affected, also **INVOKE** `ui-verification` and encode the Android states/interactions as UI tests. Port/encode the Android behavior as tests *before* production changes:

- Unit tests (Swift Testing) for projections, filtering, tree building, validation, counts, and state transitions.
- Integration tests (Swift Testing/XCTest) for ViewModel + fake repository and data-layer parity fixes.
- Shared JSON scenarios from `sharedContracts/test-scenarios/` for any API-touching integration tests.
- Update existing tests that assert the old production behavior being removed.
- UI tests must cover every mapped user-facing state and interaction: initial loading, refresh with cached content, empty/error states, overflow or horizontal scrolling, each action control, navigation handoff, and the platform-adapted presentation (sheet/menu/dialog) where applicable.
- Give every interactive element a stable accessibility identifier and verify the identifier and accessible frame, not just screen existence.

Run the test suite (or `xcodebuild build-for-testing` for the test target) and record RED evidence — failing assertions or a non-compiling test target against the current iOS API — in `<dated-workspace>/evidence/red_test_migration.txt`. Do not modify production code in this stage.

Gate: tests exist, encode Android-parity behavior, and are RED with recorded evidence; production code untouched.

### Stage 5 — Implementation (GREEN)
**INVOKE** the `ios-implementation` skill via the Skill tool (name: `ios-implementation`). Implement the mapped behavior so the migrated tests turn GREEN:

1. Data layer: fix gaps found in Stage 1 (e.g., folder rename parity), keeping DTOs and mappings in the data layer.
2. Domain layer: add framework-independent model helpers the migration needs (e.g., `NoteDocument.toPlainText()` port).
3. ViewModel layer: repository-backed projections, actions, validation, refresh/sync orchestration, error notices, navigation handoff — no data-layer imports.
4. UI layer: render the new state while preserving the visual shell, semantic tokens, and accessibility identifiers. Preserve Android interaction and presentation semantics, using an explicitly documented iOS adaptation where the platform differs.

Gate: `xcodebuild -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' build` passes; all layer rules satisfied; migrated tests pass.

### Stage 6 — UI/Integration Verification
For UI-affected migrations, run the seeded and empty/error UI flows, inspect accessibility hierarchy and frames, and capture screenshots or equivalent evidence in `<dated-workspace>/assets/` or `<dated-workspace>/evidence/`. Verify refresh/loading, overflow/scrolling, action controls, and sheet/menu presentation. When the migration changes icon identity, visible label treatment, metadata placement, or secondary/destructive actions, the version 2+ `ui_verification.json` must declare a `visual_contract` with runtime-backed XCUITest proof for those risks; button existence and touch-target size alone are insufficient. The final UI evidence must use `ui_verification.json`, `design/design_anchors.json`, and XCUITest-produced `evidence/ui_frames.json`; run `bash harness/scripts/check-ui-verification-artifact.sh <dated-workspace>` before recording the stage as complete. For compact visuals inside larger hit targets (including table handles), anchors must measure the visual shape's own accessibility identifier, not only the interactive target frame.

### Stage 7 — Testing
Run the full suite and coverage:

```bash
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' -enableCodeCoverage YES
xcrun xccov view --report Build/Logs/Test/*.xcresult
```

Gate: `xcodebuild test` exits 0; overall coverage ≥ 80%; new ViewModel/domain logic ≥ 90%; RED tests now GREEN.

### Stage 8 — Code Quality Fix
**INVOKE** the `code-quality-fix` skill via the Skill tool (name: `code-quality-fix`). Run `swiftlint` and the harness check scripts. No dummy code, no suppressed violations.

Gate: `swiftlint` and custom check scripts exit 0.

### Stage 9 — Product Document Update & Knowledge Capture
1. Update `docs/product/product.md`: move delivered capabilities to Done, update the Harness Feature Tracker, and adjust the roadmap.
2. Record the migration decisions and any Android→iOS adaptations (e.g., stable color hash, reactive-primitive differences) in the dated workspace `summary.md` and `docs/knowledge/` if a reusable pitfall exists.
3. Record the final stage table, build/test evidence, and install/verification results in `summary.md`.

Gate: `docs/product/product.md` reflects the new state; `summary.md` has stage evidence.

---

## Stage Progress Table (feature-delivery-style, for `summary.md`)

| Stage | Status | Timestamp | Notes |
|-------|--------|-----------|-------|
| Android Behavior Analysis | ⏳ In Progress | YYYY-MM-DD HH:MM | `android_logic_map.md` and UI skill evidence — |
| Clarification & Specification | | | Approved by user: — |
| Implementation & Test Plan | | | Approved by user: — |
| Test Migration (RED) | | | RED evidence: — |
| Implementation (GREEN) | | | |
| UI/Integration Verification | | | assets/evidence — |
| Testing | | | |
| Code Quality Fix | | | APPROVED / REVISION REQUIRED |
| Product Document Update & Knowledge Capture | | | |

## Rollback Routes

| Failure | Return to |
|---------|-----------|
| Open question or rejected scope | Clarification & Specification |
| Plan rejection | Implementation & Test Plan |
| RED cannot be produced (tests pass against current API) | Android Logic Analysis — the mapping or test target is wrong |
| Compilation error | Implementation (GREEN) |
| Test failure or coverage gap | Testing (fix implementation if needed, then re-test) |
| Quality check violation | Code Quality Fix (fix root cause, re-run checks) |

## Human-in-the-Loop Confirmation Points

1. **After Clarification & Specification** — user confirms scope (mandatory)
2. **After Implementation & Test Plan** — user approves plan (mandatory always)
3. **After Test Migration (RED)** — if RED evidence cannot be produced, surface to the user before implementing
