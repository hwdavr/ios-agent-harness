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
Use for:
- Business rules and domain use case logic
- ViewModel state transitions
- Mapper logic (DTO → Domain, Domain → UI)
- Formatters, reducers, fallback logic
- UIState creation and state transition logic

Rules:
- Use Swift Testing framework (`@Test`, `#expect`)
- Class/struct name ends with `Tests`
- One main scenario per test

### Integration tests (`NotesTakingAppiOSTests/`)
Use for:
- ViewModel + repository + mocked API end-to-end
- API response → repository → use case → ViewModel → UIState
- API error handling (4xx, 5xx, malformed, timeout)
- DTO parsing and domain mapping
- SwiftData behavior with in-memory store
- Retry and fallback logic

Rules:
- Use Swift Testing or XCTest with `async`/`await`
- Use shared JSON scenarios — do not inline mock data
- If API used by ViewModel: assert `expected.ui` from shared scenario
- If API used only by repo/use case: assert `expected.domain`

### UI tests (`NotesTakingAppiOSUITests/`)
Use for:
- SwiftUI rendering that must be verified in simulator runtime
- User gesture interaction
- Navigation between screens
- Critical multi-screen flows

Rules:
- Use `XCUIApplication` and XCUITest
- Use `accessibilityIdentifier` to locate elements — not static text
- Do not use `sleep()` — use `waitForExistence` or expectations
- One main business scenario per test
- Do not use real production backend — use mocked data

Dedicated Visual Verification tests:
- When a feature introduces or modifies UI screens/components that require visual verification, write XCUITest methods that exercise the active screens in their critical visual states.
- The test must capture visual evidence using `XCUIScreen.main.screenshot()` during active rendering.
- Screenshots are saved and reviewed against design mockups.

Do NOT use UI tests for:
- ViewModel + repository + mocked backend verification when unit/integration tests can cover it

#### Journey Registry Regression Gate

Every journey declared in `docs/product/journey-registry.yaml` is a permanent
regression gate. The harness-generator and feature-delivery workflows must
run all registered journeys during the Test/Verification stage. A regression
in any registered journey blocks the pipeline regardless of which feature
introduced it.

New journeys are registered when a slice ships with
`production_journey.required: true`. A journey is removed only when the
product feature is intentionally deprecated.

#### Level 5 Semantic & Visual Verification Engine

Visual verification is layered, and only layers with deterministic pixels are gated:

- **Structure (binding)**: the reference-anchor bounds contract in `reference-anchor-verification.md` proves layout geometry content-independently (accessibilityIdentifier bounds, measured relationships).
- **Golden regression (binding)**: pixel comparison against a promoted golden baseline (`UX/golden-baselines/<screen>.png`) via `bash harness/scripts/compare-visual-evidence.sh`. Both sides share the rendering pipeline and deterministic fixture content, so the pass threshold is meaningful: similarity $\ge 0.95$ ($\le 5.0\%$ diff) with zero high-severity violations. A regression below threshold blocks the pipeline.
- **Mockup conformance (informational)**: pixel comparison against `design/mockup_*.png` is recorded as `INFO` rows with diff overlays for human/AI design review. Mockups carry fictional copy and AI-generated rendering that can never pixel-match a real implementation, so mockup scores never pass/fail the gate.
- **Golden promotion is part of slice approval**: when a visual-verification owner is approved, every contract screenshot not declared anchor-only must be promoted via `bash harness/scripts/compare-visual-evidence.sh --promote-golden <actual.png> --name <screen_name>`. The `--evaluate` visual gate fails with the exact promote command while a golden is missing; intentional visual updates replace the golden through the same promotion command.
- **Reference resolution is deterministic and explicit** in batch mode (`--feature`): an explicit `visual_evidence/reference-map.json` entry takes precedence. For unmapped captures, both the exact-name golden baseline (binding regression check) and the most specific `design/mockup_*.png` token match (informational design review) are evaluated and recorded so that golden baseline promotion does not silence mockup conformance evidence. Pairings are never chosen by filesystem iteration order, and a capture with no resolvable reference fails the gate as `NO_REFERENCE` (exit 2) instead of being silently skipped.
- `reference-map.json` maps a capture filename to `null` (anchor-only — no pixel comparison; the reference-anchor bounds row remains binding), a feature-relative reference path string, or `{"reference": "<path>", "mask": [{"x": 0, "y": 0, "w": 1080, "h": 400}]}` to exclude dynamic content regions from the comparison.
- A capture whose state has no applicable pixel reference (e.g., a dark-theme state with no dark mockup) must be declared anchor-only in `visual_evidence/reference-map.json`; it is recorded as `ANCHOR_ONLY` in `visual_comparison_report.md` and must still pass its reference-anchor bounds row — it is never silently compared against an inapplicable mockup.
- The comparison engine performs automated insets normalization (`--crop-insets` for status/nav bars), anti-aliasing color tolerance, and pixel divergence clustering.
- A visual diff overlay (`<name>_diff.png`) highlighting divergent regions in neon magenta must be generated and preserved alongside the actual screenshot in `visual_evidence/` for every compared row.

---

## Coverage Requirements

| Scope | Minimum Coverage |
|-------|-----------------|
| Overall project | 80% line coverage |
| New ViewModel classes | 90% line coverage |
| New domain use case classes | 90% line coverage |
| SwiftUI Views | excluded from coverage requirement |

Verify with:
```bash
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath Build -enableCodeCoverage YES
xcrun xccov view --report --json Build/Logs/Test/*.xcresult
bash harness/scripts/check-coverage.sh "$(find Build/Logs/Test -maxdepth 1 -type d -name '*.xcresult' -print -quit)" --exclude-target SwiftMath
```

---

## Shared JSON Scenarios

- **Mandatory**: All API endpoints must have at least one integration test using shared JSON scenarios
- Do not create mock response data inline in test code
- Store scenarios in `sharedContracts/test-scenarios/`
- Use the shared-json-scenarios skill to load or generate scenarios
- A scenario may contain `apiMocks`, `expected.domain`, and `expected.ui`
- Each test asserts the layer it owns — do not assert both in one test

---

## Mandatory Test Coverage for New Features

At minimum, every new feature must include:
- ViewModel / state transition tests
- Use case tests if new business logic is added
- Mapper tests if mapping logic is non-trivial
- At least one integration test per API endpoint involved, using shared JSON scenarios

---

## Mandatory Test Coverage for Bug Fixes

Every bug fix must include at least one test that fails before the fix and passes after. Write this test before touching application code when feasible.

**Triage by bug type:**
- **Logic/Calculation bugs**: Unit test (Swift Testing)
- **Data flow/API mapping/Error state bugs**: Integration test (XCTest)
- **Visual glitches/Unresponsive elements**: UI test (XCUITest)
- **Navigation crashes/Deep-link issues**: UI test (XCUITest)

---

## Testing Best Practices

### 1. Arrange-Act-Assert (AAA) Pattern
Structure each test cleanly into three visual blocks separated by empty lines:
```swift
@Test func givenNoteWithEmptyTitle_whenSaving_thenEmitsError() async throws {
    // Arrange: Set up mock responses, parameters, and view models
    let note = Note(id: "1", title: "")
    let viewModel = EditorViewModel(repository: mockRepository)
    await mockRepository.setSaveError(ValidationError.emptyTitle)

    // Act: Invoke the action being tested
    await viewModel.saveNote(note)

    // Assert: Verify the expected outcome
    #expect(viewModel.uiState == .error("Title cannot be empty"))
}
```

### 2. DAMP Over DRY in Tests
In production code, DRY (Don't Repeat Yourself) is preferred. In tests, prefer **DAMP (Descriptive And Meaningful Phrases)**. Each test should tell a self-contained story without requiring the reader to jump to shared setup helpers to understand the test input configuration.

### 3. Test State, Not Interactions
Verify the *outcome* of an operation (state changes) rather than the internal implementation details (which methods were called in which order). Testing interaction sequences makes tests fragile and prone to breaking during refactoring, even if behavior remains correct.

### 4. One Assertion Per Concept
Each test should verify exactly one logical behavior. Do not bundle multiple unrelated assertions into a single test case.

### 5. Prefer Real Implementations Over Mocks
Catches integration bugs earlier. Use real SwiftData in-memory store, domain mappers, or in-memory fakes. Mock only at external network boundaries or non-deterministic APIs.

---

## Test Anti-Patterns to Avoid

| Anti-Pattern | Description | Remediation |
|---|---|---|
| Testing implementation details | Verifying internal helper functions or private fields | Test public inputs, state transitions, and outputs only |
| Flaky tests | Tests that fail intermittently due to delays or threads | Avoid `sleep()` or timing assumptions. Use `waitForExistence` or Swift async expectations |
| Testing framework code | Verifying SwiftData or URLSession libraries actually save/fetch | Rely on libraries being tested by their authors. Only test your custom business code and mappings |
| Lack of test isolation | Test class state carrying over between runs | Recreate mock objects and stores in each test or `init()` block |
| Mocking everything | Mocking domain models or standard library arrays | Use real objects for simple models. Mock only boundaries |
| Envelope-only assertions | Asserting `contains("<svg")` or `contains("<html")` on rendered output without checking semantic content | Assert specific visual elements: labels, structural shapes, connectors. Run `bash harness/scripts/check-test-assertions-quality.sh` |
