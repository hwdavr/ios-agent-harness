---
trigger: always_on
---

# Testing Strategy Rules

## Purpose
Rules for deciding what to test, at which layer, and how much coverage is required.

---

## Test Pyramid

```
      [UI tests (XCUITest)]           ← smallest layer
      [Integration tests (XCTest)]    ← primary verification layer
      [Unit tests (Swift Testing)]    ← foundation
```

Always start at the lowest layer that gives enough confidence.

---

## Layer Selection Rules

### Unit tests (`NotesTakingAppiOSTests/`)
Use for business rules, domain use case logic, ViewModel state transitions, mappers, formatters, reducers, and fallback logic that do not require iOS runtime or simulator services.

- Use Swift Testing (`@Test`, `#expect`)
- Test struct/class names end with `Tests`
- Keep one main scenario per test

### Integration tests (`NotesTakingAppiOSTests/`)
Use for repository + use case + ViewModel data flow, DTO parsing, error mapping, SwiftData in-memory store, retry, and fallback logic.

- Use Swift Testing or XCTest with `async`/`await`
- API tests use shared JSON scenarios; do not inline mock response data
- Assert `expected.ui` when the ViewModel owns the endpoint and `expected.domain` when only the repository or use case owns it

### UI tests (`NotesTakingAppiOSUITests/`)
Use only when SwiftUI rendering, user gestures, navigation, back-stack, lifecycle, iOS SDK behavior, device capabilities, permissions, or visual verification is part of the claim. Load `.agents/rules/testing-runtime-evidence.md` before planning, implementing, or reviewing such evidence.

Do not use UI tests for behavior that unit or integration tests prove completely.

---

## Coverage Requirements

| Scope | Minimum line coverage |
|---|---|
| Overall project | 80% |
| New ViewModel classes | 90% |
| New domain use case classes | 90% |
| SwiftUI Views | Excluded; verify with XCUITest semantic/visual evidence when triggered |

Machine-readable verification:
```bash
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath Build -enableCodeCoverage YES
xcrun xccov view --report --json Build/Logs/Test/*.xcresult
bash harness/scripts/check-coverage.sh "$(find Build/Logs/Test -maxdepth 1 -type d -name '*.xcresult' -print -quit)" --exclude-target SwiftMath
```

---

## Feature and Bug Policy

- Feature and enhancement workflows implement approved behavior before the Testing stage. The Testing stage then creates or completes the planned tests and verifies them GREEN.
- Bug fixing is the only TDD workflow: `bug-reproduction` must produce a relevant RED test before the approved fix is implemented, and the later Testing stage must prove it GREEN.
- Every new feature includes ViewModel/state tests, use-case tests when business logic changes, mapper tests when mapping is non-trivial, and at least one shared-scenario integration test per affected API endpoint.
- Every bug fix includes at least one regression test that proves the reported behavior.

---

## Evidence Invariants

- A test result is passing only when the declared command ran, exited 0, executed a non-zero test count when applicable, and produced the required source-fed evidence.
- Missing runtimes, simulators, devices, models, locales, permissions, services, skipped tests, empty output, fake-only platform evidence, and unexecuted commands cannot be recorded as passing.
- Reuse a prior successful command only when its source, build configuration, declared command, and runtime fingerprints are unchanged and `check-evidence-receipt.sh` accepts its receipt.
- Keep verbose output in a referenced log/report; summaries record the command, exit status, test count or coverage, evidence path, and fingerprint receipt.
- Load `.agents/rules/testing-practices.md` during test authoring and test review.

---

## Shared JSON Scenarios

Every affected API endpoint has at least one integration test backed by `sharedContracts/test-scenarios/`. A scenario may contain `apiMocks`, `expected.domain`, and `expected.ui`; each test asserts only the layer it owns.
