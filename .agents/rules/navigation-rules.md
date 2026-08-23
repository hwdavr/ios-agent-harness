# Navigation Rules

## Purpose
Rules for implementing navigation in this project using SwiftUI `NavigationStack` and `NavigationSplitView`.

---

## Route Definition

- Define all routes as enums — not raw strings inline
- Route arguments must be `Hashable` types (`String`, `Int`, `UUID`)
- Do not pass complex objects as navigation arguments — pass an ID and fetch the object from the destination

---

## Argument Rules

Pass the minimum data needed:
```swift
// ✅ Pass ID, fetch in destination
NavigationLink(value: NoteDetailRoute(noteId: "note-123"))

// ❌ Don't serialize full objects
NavigationLink(value: NoteDetailRoute(note: serializedNote))
```

Argument nullability:
- Optional arguments must have a `defaultValue` defined in the navigation destination
- Required arguments must use non-optional types — navigating without them is a programming error

---

## Navigation Destination Handling

Use `.navigationDestination(for:)` with typed routes:

```swift
NavigationStack(path: $navigationPath) {
    HomeScreen()
        .navigationDestination(for: NoteDetailRoute.self) { route in
            NoteDetailScreen(noteId: route.noteId)
        }
}
```

---

## Back Stack Behavior

Define back-stack behavior explicitly for each navigation action.

Common patterns:
- **Open detail**: push on stack — default behavior
- **Login → Home after auth**: clear navigation path — remove login from back stack
- **Tab switch**: maintain separate navigation paths per tab

Always verify back-stack behavior matches the intended UX during review.

---

## Navigation from ViewModel

Navigation events are emitted from ViewModel as closures or async streams, not as persistent state fields:

```swift
// In ViewModel
@Observable
class NoteDetailViewModel {
    var onNavigateBack: (() -> Void)?

    func saveAndDismiss() async {
        await repository.save(note)
        onNavigateBack?()
    }
}

// In Screen
NoteDetailScreen(
    viewModel: viewModel,
    onNavigateBack: { navigationPath.removeLast() }
)
```

Do not encode navigation destinations as boolean flags in UI state.

---

## Deep Links

If deep links are added:
- Define them in the navigation destination handler
- Validate all arguments from deep links — they are untrusted input
- Test with `xcrun simctl openurl booted "myapp://deeplink"`

---

## Testability

- Navigation routes must be reachable in tests without multi-step setup
- Add direct navigation helpers for test scenarios where needed
- Prefer deterministic fake/seed data at navigation entry points