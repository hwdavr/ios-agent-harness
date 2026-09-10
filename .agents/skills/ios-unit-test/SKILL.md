---
name: ios-unit-test
description: Write Swift Testing unit tests for ViewModels, use cases, and mappers.
---

# Skill — iOS Unit Testing

## Purpose
Write unit tests for ViewModels, use cases, and mapper logic using Swift Testing framework.

---

## Load
- `rules/testing-strategy.md`

---

## Execute

### When to write unit tests
- ViewModel state transitions
- Domain use case logic
- Mapper logic (DTO → Domain, Domain → UI)
- Formatting and fallback logic

### Rules
- Use Swift Testing: `@Test func`, `#expect(...)`, `#require(...)`
- Test file name ends with `Tests`
- One main scenario per test function
- Follow AAA pattern (Arrange, Act, Assert)
- Test public API — not private implementation details
- Prefer real model instances over mock model objects

### Example
```swift
@Test func givenEmptyTitle_whenSaving_thenEmitsError() async throws {
    // Arrange
    let viewModel = EditorViewModel(repository: mockRepo)
    await mockRepo.setSaveBehavior { throw ValidationError.emptyTitle }

    // Act
    await viewModel.saveNote(Note(title: ""))

    // Assert
    #expect(viewModel.uiState.error != nil)
}
```

---

## Done When
- All ViewModel state transitions tested
- All use cases tested
- All mappers tested
- Tests pass: `xcodebuild test`
- New classes ≥ 90% coverage
