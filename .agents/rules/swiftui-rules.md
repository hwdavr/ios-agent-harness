# SwiftUI Rules

## Purpose
Rules for writing SwiftUI views in this project.

---

## View Responsibilities

A SwiftUI View should:
- Receive `@Observable` ViewModel state and event closures as parameters
- Render the current state
- Call closures on user interactions — it does not call the ViewModel directly

A SwiftUI View must NOT:
- Call use cases or repositories
- Contain business logic or data transformation
- Import domain or data layer classes directly inside the view body
- Use hardcoded strings — always use `LocalizedStringKey` or `String(localized:)`
- Use hardcoded colors — always use semantic color tokens from the design system

---

## Stateless / Stateful Pattern

Split screens into:

```swift
// Stateful wrapper — wires ViewModel (tested via integration tests)
struct NoteDetailScreen: View {
    @State private var viewModel = NoteDetailViewModel()

    var body: some View {
        NoteDetailContent(
            uiState: viewModel.uiState,
            onSave: { await viewModel.onSave() }
        )
    }
}

// Stateless content — tested in isolation via SwiftUI previews and unit tests
struct NoteDetailContent: View {
    let uiState: NoteDetailUIState
    let onSave: () async -> Void

    var body: some View { ... }
}
```

Always test `NoteDetailContent` (stateless) — not `NoteDetailScreen` (stateful) — in unit and snapshot tests.

---

## View File Boundaries

Each screen must live in its own SwiftUI source file.

Allowed:
- `EditorScreen.swift` contains `EditorScreen`, `EditorContent`, and private helpers used only by that screen
- `ProjectListScreen.swift` contains `ProjectListScreen`, `ProjectListContent`, and private helpers used only by that screen
- Shared or repeated UI is extracted to focused files under `Components/`

Not allowed:
- Multiple independent screens in one Swift file
- A single catch-all UI file that contains an entire feature flow
- Putting screen-specific implementations for unrelated destinations into one file because they share navigation or tab state

If a screen grows too large, extract sections into screen-owned files or reusable components. Do not combine screens into one file to avoid creating new files.

---

## Accessibility Identifiers

Add `.accessibilityIdentifier(...)` to all:
- Primary CTAs and action buttons
- Key content containers (note card, list items)
- Empty state and error state views
- Loading indicators
- Navigation elements (tabs, back buttons)

Use descriptive, stable names:
```swift
.accessibilityIdentifier("note_detail_save_button")     // ✅
.accessibilityIdentifier("button_\(note.id)")           // ❌ — unstable, ID-dependent
.accessibilityIdentifier("btn")                         // ❌ — not descriptive
```

Dynamic identifiers are allowed only when the interpolated value is an immutable,
domain-owned identifier or a fixed catalog key. Each must be registered in
`docs/harness/documented-dynamic-accessibility-identifiers.json`; the SwiftUI
checker validates the source file, approved template, source type, and line pattern.
Transient indexes, random IDs, timestamps, and user-generated text remain prohibited.

---

## String Localization

All user-visible text must use `LocalizedStringKey` or `String(localized:)`:
```swift
Text("note_detail_title", tableName: nil, bundle: .main)   // ✅ — via .xcstrings
Text("Note title")                                          // ❌
```

String key naming convention: `<screen>_<element>_<type>`
```
note_detail_title_label
home_empty_state_message
folders_create_button_label
```

---

## Colors

**Never hardcode colors inline in SwiftUI Views.** Hardcoded colors prevent theming and make Dark Mode impossible to implement.

```swift
Text("label").foregroundStyle(Color(hex: "#7281A7"))   // ❌ — hardcoded, cannot be themed
Text("label").foregroundStyle(.red)                     // ❌ — hardcoded

Text("label").foregroundStyle(.textSecondary)            // ✅ — semantic token
```

### Where to define colors

All shared colors must be defined in the Asset Catalog or a dedicated theme file:

```swift
extension ShapeStyle where Self == Color {
    static var textPrimary: Color { Color("TextPrimary") }
    static var textSecondary: Color { Color("TextSecondary") }
    static var backgroundSurface: Color { Color("BackgroundSurface") }
    static var commentHighlight: Color { Color("CommentHighlight") }
}
```

### Rules
- **All color values go in Asset Catalog or theme extensions** — no `Color(hex:)` or `Color(red:green:blue:)` elsewhere in the codebase
- **Access via semantic token** (`foregroundStyle(.textSecondary)`) — never via a hardcoded value
- **Name by semantic purpose** (`textSecondary`, `commentHighlight`) — not by value (`gray`, `yellow`)

---

## Component Extraction

Extract reusable SwiftUI Views to `Components/` when:
- The same UI structure appears in more than one screen
- A component has its own internal state or complexity
- A component is independently testable

Keep components focused — one visual responsibility per component.

---

## State Management

Always hoist state to the lowest common ancestor that needs it.
Do not hoist state higher than necessary.
Avoid `@State` for business logic in tests by keeping stateless content Views as the primary test surface.

Use `@Observable` ViewModels — not `@StateObject` / `@ObservedObject` (legacy `ObservableObject` pattern).

---

## Performance Rules

- Prefer `List` or `LazyVStack` over `VStack` with `ForEach` for scrollable lists
- Avoid unnecessary re-renders: pass stable value types as parameters
- Use `id:` parameter in `ForEach` when items have stable identifiers
- Avoid creating closures inside the view body — pass them as stored properties

---

## Keyboard / IME Behavior

**When screen content (or a sheet) contains text input, the bottom toolbar must dismiss while the keyboard is visible.**

- A bottom toolbar / bottom bar must never sit behind the keyboard, overlap the focused field, or shrink the visible typing area.
- Dismiss the bottom toolbar while keyboard is visible and restore it when the keyboard hides.
- Apply `.ignoresSafeArea(.keyboard)` or an equivalent insets strategy so the focused field and remaining controls stay visible and reachable above the keyboard.
- This rule applies to full screens and sheets alike. The design (`design.md`) must depict the keyboard-visible state for every screen or sheet whose content has text input; when the screen has a bottom toolbar, that state must show the bottom toolbar dismissed.

### Sheets with Text Input

- Tapping a text field inside a sheet must **not** dismiss the sheet. The sheet stays open and expands above the keyboard; only a scrim tap, swipe-down, or an explicit close action dismisses it.
- Apply keyboard avoidance to the sheet content so the focused field and remaining controls stay visible, and keep the sheet's results region scrollable.
- The design (`design.md`) must include a distinct keyboard-visible mockup showing the sheet **still open** with the keyboard, alongside the base mockup — never a dismissed sheet.

---

## SwiftUI Verification

Automated source evidence:

```bash
bash harness/scripts/check-swiftui-rules.sh
bash harness/scripts/check-localization-rules.sh
```

The full-source rules bundle is the required CI evidence. When the diff changes a
SwiftUI surface, review the semantic concerns it introduces: rendering versus
business-logic ownership, state hoisting and stateful/stateless boundaries,
component extraction, semantic token use, accessible interaction labels and
identifiers, list performance, and keyboard-visible behavior. Runtime and visual
claims require the declared UI evidence; they are not inferred from a source check.

Human approval and exceptions are handled by the review and merge workflow, not by
duplicated per-rule documentation.
