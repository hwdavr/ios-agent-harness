---
name: ios-ui-test
description: Write XCUITest UI tests for SwiftUI screens and navigation flows.
---

# Skill — iOS UI Testing

## Purpose
Write UI tests using XCUITest for SwiftUI screens, user gestures, and navigation flows.

---

## Load
- `rules/swiftui-rules.md`
- `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read

---

## Execute
- **Scope**: Gestures, navigation flows, critical multi-screen paths, visual verification on simulator.
- **Framework**: `XCUIApplication()`, launch with UI test arguments.
- **Identifiers**: Locate elements via `.accessibilityIdentifier` — **never by static text**.
- **Timing**: Use `waitForExistence(timeout:)` and expectations — **never `sleep()`**.
- **Visual Verification**: When required, capture screen via `XCUIScreen.main.screenshot()` and save under `visual_evidence/`.

---

## Done When
- All interactive elements have `accessibilityIdentifier`
- No `sleep()` calls — proper expectations used
- One main business scenario per test
- Tests pass on simulator
