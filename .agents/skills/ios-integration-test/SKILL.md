---
name: ios-integration-test
description: Write integration tests for API endpoints, repositories, and SwiftData.
---

# Skill — iOS Integration Testing

## Purpose
Write integration tests covering ViewModel + repository + mocked API end-to-end flows.

---

## Load
- `skills/shared-json-scenarios/SKILL.md`
- `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read
- `rules/api-contract-rules.md`

---

## Execute

### Test coverage per API endpoint
For each changed API endpoint, test:
- Success response (2xx)
- 4xx client error
- 5xx server error
- Malformed or partial payload
- Network timeout / disconnect
- Unknown enum value (must not crash)

### Rules
- Use shared JSON scenarios — **no inline mock data**
- Store scenarios in `sharedContracts/test-scenarios/`
- If API used by ViewModel: assert `expected.ui`
- If API used only by repo/use case: assert `expected.domain`
- Use `URLProtocol` subclass for mocking URLSession
- Use in-memory `ModelConfiguration` for SwiftData integration tests

### Example
```swift
@Test func givenValidNote_whenSave_thenReturnsDomainModel() async throws {
    let scenario = try JSONScenario.load("note_save_success")
    URLProtocolMock.register(scenario.apiMocks)

    let repository = NoteRepository()
    let result = try await repository.save(scenario.input)

    #expect(result == scenario.expected.domain)
}
```

---

## Done When
- At least one integration test per changed API endpoint
- All error paths covered (4xx, 5xx, timeout, malformed, unknown enum)
- Shared JSON scenarios used
- Tests pass
