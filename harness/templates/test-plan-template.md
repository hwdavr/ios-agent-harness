# Test Plan Template

Use this template when producing the test plan in the **Implementation Plan** stage (alongside the implementation plan).

---

## Feature / Bug

> One line description of what is being tested.

---

## Layer Selection

| Layer | Included | Reason |
|-------|----------|--------|
| Unit tests (`NotesTakingAppiOSTests/`) | ✅ / ❌ | |
| Integration tests (`NotesTakingAppiOSTests/`) | ✅ / ❌ | |
| UI tests (`NotesTakingAppiOSUITests/`) | ✅ / ❌ | |

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
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' -enableCodeCoverage YES
xcrun xccov view --report Build/Logs/Test/*.xcresult
```