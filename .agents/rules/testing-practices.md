# Testing Authoring and Review Practices

## Structure

- Use Arrange, Act, Assert (AAA) with clear visual separation between the three phases.
- Keep one main business scenario and one assertion concept per test.
- Prefer descriptive, self-contained tests (DAMP over DRY) so each test tells a self-contained story.
- Test public inputs, state transitions, and outputs rather than private implementation details or interaction ordering.
- Recreate mutable test state in `init()` or setup; tests must be isolated and rerunnable.

## Test Doubles

- Prefer real domain models, mappers, and deterministic in-memory SwiftData stores or fakes.
- Mock only external network boundaries (`URLSession`) or non-deterministic APIs.
- Fakes, mocks, stubs, and fixture constants are allowed in test target source sets.
- API response bodies belong in shared JSON scenarios under `sharedContracts/test-scenarios/`, not inline test strings.

## Reliability

- Use Swift async/await expectations and XCTest `waitForExistence` instead of timing assumptions or `sleep()`.
- A test that passes with `0/0` assertions, is disabled/skipped, or fails for fixture compilation does not prove behavior.
- Expected negative fixtures must assert the non-zero exit and the intended diagnostic.

## Assertion Quality

- Assert observable semantic behavior, not only that an envelope such as HTML, SVG, or JSON is non-empty.
- For rendered-output claims, follow `.agents/rules/testing-runtime-evidence.md`.
- Run `bash harness/scripts/check-test-assertions-quality.sh` for repository test sources.

## Naming and Frameworks

- Unit test suites use Swift Testing (`@Test`, `#expect`) or XCTest, ending with `Tests.swift`.
- Integration tests use Swift Testing or XCTest with `async`/`await`.
- UI tests use XCUITest (`XCUIApplication`) in `NotesTakingAppiOSUITests/`.
- Do not use fully qualified names or wildcard imports inline; keep explicit imports sorted.
