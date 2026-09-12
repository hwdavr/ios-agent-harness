# Visual Reference Anchor Verification

**Reference design**: `design/<approved_mockup_or_screenshot>.png`

Record one row for every `TC-US-*-VIS-*` visual test. The reference asset and actual screenshot
must be non-empty. A visual inside a larger touch target must use the visual shape's own bounds
tag, not only the target's tag. Handle anchors must not use an interactive identifier ending in
`_handle` or `-handle`; use a distinct visual-shape identifier such as `*_handle_visual`.

**Screenshot capture requirement**: The `Runtime proof` column must reference a dedicated
`*VisualFlowTests.swift` test method that captures the screenshot from within the running test via
`XCUIScreen.main.screenshot()` or in-test capture helper during idle test execution. Post-test CLI
screencaps are prohibited because the test window is already destroyed when the test runner finishes.

**Capture scope requirement**: When the paired visual acceptance row claims app-shell chrome
(for example global tabs, system bars, or a full-page shell), its `Setup and action` cell must
declare `Capture scope: app-shell; production root: <ViewOrWindowRoot>.` The named
`VisualFlowTests` must invoke that root. Use `Capture scope: component` only when shell chrome is
explicitly outside the proof. Record the same scope and root in the `Runtime proof` cell.

## Reference Anchor Verification

| Visual Test ID | Reference anchor | Runtime proof | Measured relationship | Actual screenshot | Result |
|----------------|------------------|---------------|-----------------------|-------------------|--------|
| TC-US-1-VIS-01 | <exact relationship from the approved reference> | `<Feature>VisualFlowTests#test<State>`; captureScope: component; accessibilityIdentifier: `<visual_bounds_identifier>` | `<visualBounds>.<edge> == <anchorBounds>.<edge> ± <tolerance>pt` | `visual_evidence/<screen>_<state>.png` | PASS / FAIL |
