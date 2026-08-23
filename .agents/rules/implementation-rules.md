# Implementation Rules

## Purpose

Rules for ensuring every line of generated code is the real implementation of the requirement — never a placeholder, stub, or dummy that merely satisfies the compiler. Dummy code that compiles but does not perform the specified behavior is treated as a missing implementation, not a deferred one.

---

## 1. No Dummy Code

All code generated for this project must be the actual implementation of the requirement it claims to fulfill. Dummy, stub, or placeholder code is forbidden in production sources.

**Scope**: every production source file — `NotesTakingAppiOS/`, `sharedContracts/`, and any module's main source set. Test sources (`NotesTakingAppiOSTests/`, `NotesTakingAppiOSUITests/`) are **exempt** — fakes, mocks, and stubs used as test doubles are permitted and expected there.

### 1.1 No stub / placeholder return values

A function must not return a hardcoded value where the requirement specifies a computation, query, or transformation.

```swift
// BAD — returns a constant instead of computing the actual sum
func totalPrice(items: [CartItem]) -> Double { 0.0 }

// BAD — returns an empty list instead of querying the repository
func searchNotes(query: String) async -> [Note] { [] }

// GOOD — implements the actual requirement
func searchNotes(query: String) async throws -> [Note] {
    try await repository.search(query).map(NoteUI.init)
}
```

### 1.2 No `fatalError("TODO")` / `#warning("stub")`

`fatalError("TODO")`, `preconditionFailure("not implemented")`, or any equivalent marker that lets a function compile without implementing its behavior is forbidden in production sources.

```swift
// BAD
func applyFilter(_ filter: Filter) -> Result {
    fatalError("TODO: not implemented")
}

// BAD
func loadUser(_ id: UserID) async -> User {
    preconditionFailure("will add later")
}
```

### 1.3 No dummy comments

Comments indicating the surrounding code is not the real implementation are forbidden. Examples:

- `// dummy implementation`
- `// placeholder`
- `// stub for now`
- `// TODO: real implementation later`
- `// temporary — replace before merge`
- `// hardcoded for now`

### 1.4 No no-op handlers

A callback, listener, or event handler must not have a `{ }` or log-only body when the requirement specifies the callback must perform a real action (navigate, persist, dispatch, etc.).

```swift
// BAD — requirement says "on save, persist note and navigate back"
onSaveClick = { /* TODO */ }

// BAD — requirement says "on error, show error state"; this only logs
onError = { error in Logger.app.error("Error occurred: \(error)") }

// GOOD — implements the actual requirement
onSaveClick = { await viewModel.onSave() }
```

### 1.5 No "compiles but doesn't implement" code

Any function, class, branch, or path that satisfies the type system and builds cleanly but does not perform the actual behavior defined in the active `spec.md`, `implementation_plan_v<N>.md`, `feature_list.json`, or `sprint-contract.md` requirement it claims to fulfill is a violation.

This includes:
- Branches that return early with a placeholder value before the real logic runs.
- Methods that delegate to another stub instead of implementing the behavior.
- Classes that satisfy a protocol by throwing or returning defaults for every method.
- Paths in a `switch` / `if` cascade that are reachable from an in-scope entry point but never produce the specified outcome.

### Allowed exceptions

The following are **not** violations:

- **Test sources** — `NotesTakingAppiOSTests/`, `NotesTakingAppiOSUITests/`. Fakes, mocks, and stubs used as test doubles are permitted and expected.
- **Protocol declarations** — a protocol has no body by design; this is not a stub. Concrete implementations must still follow this rule.
- **`#Preview` macros** — SwiftUI `#Preview` may use sample/hardcoded values because their purpose is rendering tooling, not production behavior. The UI state types themselves and all production views must still follow this rule.
- **Documented user-approved exception** — when a reviewer explicitly accepts a stub as a documented false positive, matching the AGENTS.md rule on suppressed violations. The exception must be recorded in the code review report with a justification.

### Enforcement

Every function, branch, and callback added or modified in a change must implement the actual requirement logic. Reviewers (Evaluator role) must reject any change containing the prohibited patterns above as **REVISION REQUIRED** — the Coder must return to implementation and deliver the real behavior. This rule is non-negotiable and cannot be waived by silence; only an explicit, documented user approval satisfies the exception clause.