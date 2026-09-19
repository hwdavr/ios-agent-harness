# Runtime Testing Evidence Rules

## When to Load

Load this rule when the approved scope or submitted diff touches SwiftUI rendering, user gestures,
navigation/back stack, navigation state recreation, post-return persistence, iOS SDK behavior,
hardware/device capabilities, models, locales, permissions, or visual evidence.

## Runtime Selection and Execution

- Use the iOS Simulator (e.g. `iPhone 16`) for instrumented XCUITest flows.
- Use `XCUIApplication` with stable `accessibilityIdentifier` attributes for all interactive and structural elements.
- Do not use `sleep()` — use `waitForExistence(timeout:)` or asynchronous expectations.
- Do not call a real production backend; use deterministic local mocked endpoints.
- When a UI-test loopback server supplies the mocked endpoint, it must start before app launch, pass a validated
  loopback URL through the composition boundary, record redacted method/path/status receipts, and stop at teardown.
  Listener failure, missing URL, zero requests, or a live-network fallback is blocked evidence.

## Platform-Bound Evidence

A platform-bound feature requires a real instrumented boundary test in addition to deterministic
unit/integration tests. The test must exercise the shipped adapter against the declared iOS API or
resource and assert an observable platform result.

Fake adapters, fake callbacks, and seam instantiation are supplemental. If a required runtime,
simulator, model, locale, permission, or service is unavailable, the command must fail or record
`Blocked`/`Revise`; it cannot pass by skip or warning.

## Production Journey Boundary

For navigation, state preservation, back stack, destination recreation, or post-return persistence:

- Mount the production navigation hierarchy.
- Perform real UI gestures through stable `accessibilityIdentifier` tags.
- Cross the declared return boundary.
- Assert the visible result after returning.

Direct ViewModel calls, internal state mutation, manually invoked closures, and view-only tests
are supplemental. Register shipped required journeys in `docs/product/journey-registry.yaml` and
run `bash harness/scripts/check-journey-registry.sh --run-all` during verification.

## Visual Evidence Capture

When `requires_visual_verification` is true, dedicated UI tests must render every contract state and
capture visual evidence during active rendering using `XCUIScreen.main.screenshot()`. Save screenshots
to the feature's `visual_evidence/` directory.

Post-test external screencaps are prohibited because the test window has already been destroyed.
Every visual Test ID requires a non-empty screenshot and a reference-anchor row tied to an
accessibility identifier, runtime test method, measured relationship, and tolerance.

## Rendered Rich-Text Evidence

Claims that bold, italic, underline, strikethrough, code, monospace, or another inline style is
visibly rendered require concrete rendered pixels or measured attributes. Assert an explicit checked
pixel difference or attribute outcome.

Model marks, raw string contents, toolbar selection state, and a non-empty full-screen PNG are
supplemental and do not prove rendered appearance.

## Visual Comparison Contract

- Structural conformance is binding through reference-anchor bounds assertions.
- Approved mockup comparison is also binding at similarity >= 0.95 with zero high-severity violations (`compare-visual-evidence.sh`); both conditions are required.
- `visual_evidence/visual-target.json` is the canonical feature-owned target manifest. It defines appearance, concrete device, logical size, locale, and named deterministic content states. Mockup generation and simulator preflight must both read this manifest (`visual-target-prompt.sh` and `prepare-visual-runtime.sh --target`).
- `reference-map.json` must map every contract screenshot exactly once to one stable `state_id` from that manifest; filename/token inference, duplicated target metadata, source-baseline references, and `null` anchor-only entries are prohibited. The runtime preflight and anchor report must resolve the same target values.
- Time, user content, identifiers, and keyboard variation must each be explicitly fixed, cropped, absent, or narrowly masked with an approval rationale.
- Missing, ambiguous, or mismatched references fail; they are never silently skipped.
- Preserve actual captures, comparison reports, and diff overlays under `visual_evidence/`.
