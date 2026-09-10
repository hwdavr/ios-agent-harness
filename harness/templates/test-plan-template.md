# Test Plan Template

Use this template when producing the test plan in the **Implementation Plan** stage (alongside the implementation plan).

---

## Feature / Bug

> One line description of what is being tested.

## Rule Applicability Test Reconciliation

Copy the approved ten-row matrix and identify the test or explicit feature-specific reason for each decision. Every `Required` row needs a verification entry or a documented blocking failure.

| Rule ID | Rule document | Decision | Test/evidence |
|---|---|---|---|
| ARCH | `ios-architecture.md` | <decision> | |
| IMPL | `implementation-rules.md` | <decision> | |
| TEST | `testing-strategy.md` | <decision> | |
| SUI | `swiftui-rules.md` | <decision> | |
| L10N | `localization-rules.md` | <decision> | |
| NAV | `navigation-rules.md` | <decision> | |
| API | `api-contract-rules.md` | <decision> | |
| OBS | `observability.md` | <decision> | |
| ANL | `analytics-rules.md` | <decision> | |
| SEC | `ios-security.md` | <decision> | |

---

## Layer Selection

| Layer | Included | Reason |
|-------|----------|--------|
| Unit tests (`NotesTakingAppiOSTests/`) | ✅ / ❌ | |
| Integration tests (`NotesTakingAppiOSTests/`) | ✅ / ❌ | |
| UI tests (`NotesTakingAppiOSUITests/`) | ✅ / ❌ | |

---

## Production Journey Boundary

> **MANDATORY when `NAV` is `Required` for navigation, saved-state, back-stack,
> destination-recreation, or post-return persistence behavior.** Name the real
> instrumented journey that enters through the shipped App or NavigationStack,
> uses UI gestures, crosses the return boundary, and asserts the visible result.

- Test file: `<path under NotesTakingAppiOSUITests/>`
- Test method: `<named test method>`
- Production entry point: `<ContentView, App, or navigation container>`
- User actions: `<real UI gestures and stable accessibilityIdentifiers>`
- Return boundary: `<back/pop/dismiss selection and resulting return>`
- Post-return assertion: `<visible result asserted after returning>`

The stage gate invokes `bash harness/scripts/check-journey-test-contract.sh` for the
declared file and method. Direct ViewModel, internal UI state, and isolated view
tests remain supplemental and do not satisfy this section.

---

## Test Cases

List every test case grouped by the class under test. Assign a short ID (e.g. `T1`) so cases can be referenced in reviews and PRs.

### `<ClassName>Tests.swift` — Unit

| ID | Given | When | Then |
|----|-------|------|------|
| T1 | \<precondition\> | \<action / trigger\> | \<expected outcome\> |
| T2 | \<precondition\> | \<action / trigger\> | \<expected outcome\> |

### `<ClassName>IntegrationTests.swift` — Integration

> **MANDATORY**: Every new API endpoint must have at least one integration test using a shared JSON scenario.

| ID | Given | When | Then | Shared Scenario |
|----|-------|------|------|-----------------|
| T3 | \<precondition\> | \<action / trigger\> | \<expected outcome\> | `scenario.json` |
| T4 | API returns error | load data | show error UIState | `scenario-error.json` |

### `<ScreenName>UITests.swift` — UI

| ID | Given | When | Then |
|----|-------|------|------|
| T5 | \<UIState\> | render screen | \<visible / hidden elements\> |
| T6 | \<user gesture\> | tap element | \<navigation / state change\> |

### Visual Flow Tests *(only when `requires_visual_verification == true`)*

> **MANDATORY**: When visual verification is required, write XCUITest methods that render the active screen in each critical visual state, wait for rendering to complete, and capture a screenshot via `XCUIScreen.main.screenshot()`.

| ID | Visual State | View Under Test | Capture Method | Output File |
|----|-------------|-----------------|----------------|-------------|
| T-VIS-1 | \<state name (e.g. default content)\> | \<View name\> | `XCUIScreen.main.screenshot()` | `visual_evidence/<screen>_<state>.png` |
| T-VIS-2 | \<state name (e.g. expanded/fullscreen)\> | \<View name\> | `XCUIScreen.main.screenshot()` | `visual_evidence/<screen>_<state>.png` |

---

## Shared JSON Scenarios

| Scenario File | API Mock | Expected Domain | Expected UI |
|---------------|----------|-----------------|-------------|
| `scenario.json` | ✅ | ✅ | ✅ |

Location: `sharedContracts/test-scenarios/`

---

## Coverage Targets

| Scope | Minimum |
|-------|---------|
| Overall project | ≥ 80% line coverage |
| New ViewModel / UseCase classes | ≥ 90% line coverage |
| SwiftUI Views | excluded |

---

## Verification Commands

```bash
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16'
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath Build -enableCodeCoverage YES
xcrun xccov view --report Build/Logs/Test/*.xcresult
bash harness/scripts/check-coverage.sh "$(find Build/Logs/Test -maxdepth 1 -type d -name '*.xcresult' -print -quit)" --exclude-target SwiftMath
```
