---
name: ios-ui-test
description: Writes XCUITest instrumented UI tests for SwiftUI screens and navigation flows.
---

# Skill — iOS UI Testing

## Purpose
Write UI tests using XCUITest for SwiftUI screens, user gestures, and navigation flows.

---

## Load
- `rules/swiftui-rules.md`
- `rules/testing-strategy.md`

---

## Execute

### When to use
- SwiftUI rendering requires simulator runtime verification
- User gesture interaction (tap, swipe, scroll)
- Navigation between screens
- Critical multi-screen flows

### Rules
- Use `XCUIApplication` + `launch()`
- Locate elements via `.accessibilityIdentifier` — not static text
- Use `waitForExistence(timeout:)` and expectations — never `sleep()`
- One main business scenario per test
- Do not use real production backend — use mock server or launch arguments

### Example
```swift
func testSaveNoteButtonEnabledWhenTitleNotEmpty() throws {
    let app = XCUIApplication()
    app.launchArguments = ["-UITesting"]
    app.launch()

    let titleField = app.textFields["editor_title_field"]
    titleField.tap()
    titleField.typeText("My Note")

    let saveButton = app.buttons["editor_save_button"]
    XCTAssertTrue(saveButton.isEnabled)
}
```

### Visual verification
For screens requiring visual verification:
1. Render active screen state
2. Capture via `XCUIScreen.main.screenshot()`
3. Save to `$FEATURE_DIR/visual_evidence/` for review

---

## Done When
- All interactive elements have `accessibilityIdentifier`
- No `sleep()` calls — proper expectations used
- One main business scenario per test
- Tests pass on simulator