---
name: android-to-ios-ui-migration
description: Migrate Android Jetpack Compose screens to production SwiftUI with measured visual parity.
---

# Android-to-iOS UI Migration

## Outcome

Produce an evidence-backed iOS UI migration brief before implementation. Treat Compose code as the
source for design intent and numeric tokens; use approved design files and runtime captures to
prove the rendered result. Do not translate Compose code line-for-line into SwiftUI.

## Load

- Android source for the target screen and its directly used components, theme, string resources,
  and navigation state.
- The approved Android design/screenshot or Pencil/Figma reference, if available.
- `docs/product/design_system.md` and the affected iOS SwiftUI code.
- `.agents/rules/ios-architecture.md` (skip if already loaded this session), `.agents/rules/swiftui-rules.md`,
  `.agents/rules/localization-rules.md`, `.agents/rules/navigation-rules.md`,
  `.agents/rules/implementation-rules.md` (skip if already loaded this session),
  `.agents/rules/testing-strategy.md` (auto-loaded as system rule — do not re-read),
  `.agents/rules/observability.md`, and `.agents/rules/analytics-rules.md`.
- `harness/templates/rule-applicability-template.md`.
- `references/compose-to-swiftui-mapping.md` for implementation mappings and measurement rules.

If the Android source or an approved visual reference is unavailable, state which evidence is
missing. Do not invent dimensions from a screenshot when Compose declares them, and do not claim
visual parity from source inspection alone.

## Workflow

### 1. Establish the migration boundary

Name the Android screen, its destination iOS screen, supported visual states, target simulator,
and approved reference. Separate product behavior from visual parity; route missing behavior
requirements to the normal specification workflow. Read the approved Rule Applicability matrix
and record the SUI, L10N, NAV, OBS, and ANL decisions before implementation. Android behavior
does not override an iOS rule without a documented user-approved exception.

### 2. Extract the Android UI contract

Read only the target's reachable UI surface. Record every rendered element in
`docs/current/android_ui_contract.json`:

- Compose file, composable, and stable semantics/test tag;
- layout direction, parent-child hierarchy, `dp` size/padding/spacing, weight, alignment, and
  shape/elevation;
- text string resource, semantic typography role, `sp` size, weight, line height, and truncation;
- color, typography, shape, and spacing tokens with their Android declaration path;
- normal, selected, disabled, loading, empty, error, and focused states;
- interaction, navigation destination, and visual bounds distinct from any larger touch target.
- analytics events or logging signals triggered by each interactive state, including the
  Android source location, event name/payload, and production outcome; record `analytics: none`
  when no product event is justified.

Read values through theme/component tokens before recording literals. Preserve the Android source
path and line number for every design-critical token or layout decision.

### 3. Map, do not mechanically convert

Create `docs/current/ios_design_mapping.md` with one row per design-critical contract item:

| Android evidence | iOS token/component or ViewModel action | Decision | Visual anchor | Exception |
|---|---|---|---|---|

Map colors, typography, radii, spacing, icons, and states to the existing iOS design system first.
Add a new iOS semantic token only when no existing token represents the Android intent. Never use
SwiftUI default controls as a proxy for Material controls when their padding, corner radius,
typography, or state behavior visibly differs.

Use the same numeric magnitude as the initial `dp`→pt baseline, then correct it from the approved
visual reference and target simulator measurement. Map `sp` by typography role and measured
rendered hierarchy, not by a blind one-to-one point conversion.

Document every deliberate platform adaptation and obtain explicit user approval before it can
override the approved visual reference.

For each Android analytics event, map the UI trigger to an iOS ViewModel action and preserve the
approved event name and payload. Do not place analytics calls in a SwiftUI View. Map diagnostic
logging to the appropriate iOS async/error boundary and use `os.Logger` only when OBS is required;
never log PII, secrets, or full user-generated content.

Before handoff, add or update the Rule Applicability reconciliation in the active specification:
record the decision, trigger/rationale, implementation location, and verification evidence for
SUI, L10N, NAV, OBS, and ANL. Keep the other rule rows present as well.

### 4. Define measurable parity anchors

Create `docs/current/design/design_anchors.json` for text/container heights, widths, margins,
gaps, and alignment coordinates that materially affect the visual composition. Use stable iOS
`accessibilityIdentifier` values for the visual element itself. Avoid measuring only a 44 pt touch
target when the visible icon or chip is smaller.

Use numeric pt expectations and tolerances from the approved design. Include all state-specific
anchors where selection, focus, sheet presentation, or navigation can shift layout.

### 5. Hand off implementation and verification

Implement through `ios-ui-layer` under the iOS architecture, SwiftUI, localization, navigation,
observability, analytics, implementation, and testing rules. Preserve behavior in ViewModels/
domain layers; do not move Android UI/business logic or analytics calls into SwiftUI Views.

The SwiftUI handoff must explicitly verify: stateless `Content` plus stateful `Screen`, no business
logic or data-layer calls in Views, semantic colors, localized user-visible text and accessibility
labels, stable accessibility identifiers on interactive elements, typed navigation when in scope,
and keyboard-visible behavior for text inputs. Do not add analytics or logs merely to satisfy a
not-applicable matrix row.

Run an XCUITest that captures numeric frames and screenshots for each anchored screen. Feed those
artifacts to `ui-verification`; its artifact gate must calculate the design-anchor deltas from
`evidence/ui_frames.json`. A screenshot review, a Compose source reading, or a report's own PASS
statement is not sufficient evidence.

### 6. Migrate Android UI tests to XCUITest

Read the Android UI test files for the target screen — Espresso tests, Compose test rules
(`createComposeRule`, `onNodeWithTag`, `onNodeWithText`, `performClick`, assertion chains), and
any screenshot/reference-image tests. Record the inventory in
`docs/current/android_ui_test_inventory.md`:

| Android test file | Test method | What it verifies | Mapped iOS test method | Status |
|---|---|---|---|---|

For each Android UI test, create the equivalent XCUITest following these rules:

- **Map selectors.** Android `testTag` / `contentDescription` → iOS `accessibilityIdentifier`.
  Android `onNodeWithText("…")` → iOS `app.staticTexts["…"]` only when the text is
  locale-stable; prefer identifier-based queries.
- **Map actions.** `performClick()` → `.tap()`, `performScrollTo()` → `swipeUp()` /
  `scrollViews.firstMatch.swipeUp()`, `performTextInput()` → `.typeText()`.
- **Map assertions.** `assertIsDisplayed()` → `XCTAssertTrue(element.exists)` +
  `waitForExistence(timeout:)`, `assertTextEquals()` → `XCTAssertEqual(element.label, …)`,
  `assertIsEnabled()` / `assertIsNotEnabled()` → `XCTAssertTrue/False(element.isEnabled)`.
- **Map state-driven tests.** Android tests that inject ViewModel state via Hilt/test modules →
  iOS tests that use launch arguments or environment variables to trigger fixture data.
- **One main scenario per test.** Do not bundle multiple Android test methods into one XCUITest.
- **No `sleep()`.** Use `waitForExistence(timeout:)` or XCTest expectations.
- **Cover every mapped state.** Initial loading, populated content, empty state, error state,
  refresh with cached content, selection/editing, navigation handoff, and action controls
  (sheet, menu, dialog) as identified in the Android test inventory.
- **Cover every mapped analytics trigger.** For each migrated Android event, assert the iOS
  ViewModel action emits the approved event and payload; if no event applies, retain the explicit
  `analytics: none` decision. Test logging behavior only for required observability boundaries,
  and assert that prohibited sensitive data is absent.

The migrated UI tests must be RED (failing or non-compiling) against the current iOS codebase
before any production code changes. Record RED evidence in the dated workspace
`evidence/red_ui_test_migration.txt`.

## Completion Criteria

- Android contract cites source evidence for all design-critical elements and states.
- iOS mapping cites an iOS design-system token/component or an explicit approved exception.
- Every critical visual size, spacing, and alignment relationship has a numeric anchor.
- SwiftUI behavior respects iOS architecture, localization, accessibility, and touch-target rules.
- SwiftUI implementation satisfies the approved Rule Applicability decisions for SUI, L10N, NAV,
  OBS, and ANL, with no unsupported `Not applicable` or unapproved exception.
- Every Android analytics event is mapped to an iOS ViewModel action, or the migration artifact
  explicitly records why analytics is not applicable.
- XCUITest evidence and the UI-verification gate pass on the declared portrait simulator target.
- Every Android UI test method is mapped to an equivalent XCUITest with documented selector,
  action, and assertion correspondence; migrated UI tests produce RED evidence before
  production implementation.
