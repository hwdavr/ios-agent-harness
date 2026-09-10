---
description: Implement or update iOS UI from a provided screenshot or approved mockup, then verify it.
---

# Workflow: Create UI and Verify

## When to use
Use this workflow when:
- Implementing a new screen from a design screenshot or generated mockup
- Updating an existing screen to match a revised design

---

## Stages

### Stage 0 — Reference Design Gate
Before implementation, classify every supplied image as either an approved design reference or
defect evidence. A screenshot showing the current/wrong behavior is evidence only and is not a
design reference.

- **Approved reference provided:** Save the image to `docs/current/design/` and use it as the
  original design reference. Do not invoke `ux-design` for this task.
- **Defect evidence provided, or no approved reference:** Save defect evidence separately under
  `docs/current/evidence/`, then **INVOKE** the `ux-design` skill via the Skill tool (name:
  `ux-design`). The skill must read `docs/product/design_system.md`, create the feature design
  specification and mockup(s) under `docs/current/`, and record any deliberate exceptions to the
  design system. Do not begin UI implementation until the generated mockup and design decisions
  are approved by the user.
- **Reference path unavailable:** Stop and ask the user to attach the missing screenshot again;
  do not substitute an inferred design.

The active plan must cite the approved design reference/mockup path and keep defect evidence
separate. A generated mockup becomes the Stage 2 design reference only after user approval.

Before Stage 1, the active `docs/current/spec_v<N>.md` must contain the complete Rule
Applicability matrix. If no active specification exists, **INVOKE** `requirement-analysis`
to create one; then run `bash harness/scripts/check-stage-artifacts.sh feature-delivery
requirement-analysis`. For UI work, SUI is required and L10N/NAV/OBS/ANL must still be
explicitly assessed. Do not begin implementation until the design and rule decisions are
approved by the user.

### Stage 1 — UI Implementation
**INVOKE** the `ios-ui-layer` skill via the Skill tool (name: `ios-ui-layer`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Read `docs/product/design_system.md`, then implement the UI changes using the approved reference
from Stage 0. If the reference intentionally differs from the project design system, record the
explicit user-approved exception in `docs/current/design.md`; otherwise reuse the project tokens
and component patterns.
Read the approved Rule Applicability matrix and implement only its required rows; a new
trigger requires a specification update before implementation continues.

### Stage 2 — UI Verification ↩️ Loop
**INVOKE** the `ui-verification` skill via the Skill tool (name: `ui-verification`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Compare the implemented UI against the approved generated mockup or original design screenshot
in `docs/current/design/`, never against defect evidence in `docs/current/evidence/`, and against
`docs/product/design_system.md`. Any deviation from either source must be an explicit approved
exception.

Before recording a PASS, create `docs/current/ui_verification.json` using the `ui-verification`
skill's required report schema and run:

```bash
bash harness/scripts/check-stage-artifacts.sh create-ui-and-verify ui-verification docs/current
```

For every design-critical spatial relationship—such as text hierarchy, component size, edges that
meet a border, center alignment, overlay anchoring, spacing, or a compact visual inside a larger
touch target—create one design anchor in `design/design_anchors.json`. Each anchor names the
visual bounds `accessibilityIdentifier` (not only the outer touch target), one `x`, `y`, `width`,
or `height` metric in pt, the numeric value measured from the approved reference, and a numeric
tolerance.

Run an XCUITest that writes `evidence/ui_frames.json` plus one actual screenshot for every
anchored screen. The frame capture must identify itself as `XCUITest`, name the producing test,
and record numeric `x`, `y`, `width`, and `height` values in pt for every anchored identifier.
The report's `structural_verification.checks` is an inventory of anchor IDs only: it must not
copy expected/actual measurements or self-declare PASS. The artifact validator calculates the
delta itself and fails if an anchor is missing, outside tolerance, is based on non-XCUITest
evidence, or lacks a screenshot.

For version 2+ reports, declare a `visual_contract` with the visual-risk roles present in the
changed surface (for example `icon_identity`, `layout_relationship`, and `action_presence`).
Each role must name a runtime-backed identifier, the producing XCUITest method, and the concrete
visual assertion being proved. A button's existence or 48 pt touch-target frame is not proof of
its visible icon, label treatment, relative placement, or presence of a secondary action.

A broad screenshot with a statement such as "matches design", an assertion that only checks a
larger touch target, or a hand-written frame value is not sufficient proof of placement or size.
If an XCUITest frame capture cannot be produced, record a verification FAIL/BLOCKED result; do
not record PASS.

**Loop rule — if verification FAILS:**
- Return to **Stage 1 — UI Implementation** to fix the implementation.
- Re-run **Stage 2 — UI Verification** after each fix.
- **Maximum 3 loops total.**
- If still failing after 3 loops, stop and surface the deviation to the user with the screenshot attached.

**PASS →** the UI verification artifact gate above exits 0; then proceed to Stage 3 — Code + Test Review.

### Stage 3 — Code Quality Fix ⛔ STOP
**INVOKE** the `code-quality-fix` skill via the Skill tool (name: `code-quality-fix`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Run the code-quality-fix stage to verify complete baseline correctness.

Then **INVOKE** `ios-test-review` and `ios-code-review` to create review reports that
reconcile all nine Rule Applicability rows against the final UI diff.

Gate:
- All conditions in `skills/code-quality-fix/SKILL.md` pass
- Both review reports contain complete rule-applicability reconciliation tables
- **⛔ STOP — present results to user. Do not proceed until user explicitly approves.**

## Best Practices
- **Handling Long Content**: For scrollable screens or sheets, ensure the UI handles scrolling properly. In UI tests, use `swipeUp()` to reach off-screen elements.
- **Sheets**: Use `.presentationDetents` for sheets with significant content to improve immediate visibility.
- **Duplicate Text**: When multiple elements share the same text, use `accessibilityIdentifier` to disambiguate in assertions.
