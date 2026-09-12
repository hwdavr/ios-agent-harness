# Sprint Contract Template

Use this template when producing the sprint contract in the **Requirement Analysis & Scoping** stage of the Planner agent.

---

## 🏃 Sprint Overview

*   **Sprint:** `{sprint-id}` (e.g., P05-03)
*   **Feature:** `{feature-name}` (e.g., Multi-turn Q&A conversation history)
*   **Duration:** `{sprint-duration}` (e.g., 1 sprint)

---

## 🎯 Scope

### In Scope
> Explicit list of target capabilities, user flows, and technical components to be implemented.
*   [ ] `{In-scope capability 1}`
*   [ ] `{In-scope capability 2}`
*   [ ] `{In-scope capability 3}`

### Out of Scope
> Explicit list of boundaries, exclusions, and related features deferred to future sprints.
*   *   `{Out-of-scope item 1}` (separate feature/deferred)
*   *   `{Out-of-scope item 2}` (separate feature/deferred)

## Platform Capability & Environment Contract *(required)*

Every feature declares the root `platform_validation` object in `feature_list.json` — `required`, `unsupported_environment_policy: "fail_loudly"`, and, for non-platform features, an explicit `reason`. The `platform-capability-matrix.md` artifact is generated **only for platform-bound features** (`platform_validation.required: true`); for all others the JSON declaration plus reason is the whole contract and no matrix is written.

When the feature is platform-bound, link the workspace artifact `platform-capability-matrix.md`. The matrix MUST declare the minimum API, target API, every important API boundary, the single owner of each device resource, the input/output contract, and the required fallback for unsupported platforms. A missing emulator, device, model, locale, permission, hardware capability, or platform service is an evidence failure—not a passing skip. The exact failure policy is `fail_loudly`: the command must exit non-zero or the feature must be marked `Blocked`/`Revise`.

Platform-bound features MUST declare at least one real instrumented boundary test. A fake adapter, fake recognizer, iOS simulator-only intent test, or manually emitted callback is supplemental evidence and cannot satisfy the platform gate by itself. The test must exercise the shipped iOS platform boundary and record a successful `xcodebuild test (UI Tests)` result in `feature_list.json` evidence.

## Rule Applicability Contract *(required)*

Copy the approved ten-row matrix from the requirement artifact. The decision must be `Required`, `Not applicable — <feature-specific reason>`, or `Exception — approved by <user/date>`. Every `Required` row must map to implementation and verification evidence before a slice can pass.

| Rule ID | Rule document | Decision | Slice evidence |
|---|---|---|---|
| ARCH | `ios-architecture.md` | <decision> | |
| IMPL | `implementation-rules.md` | <decision> | |
| TEST | `testing-strategy.md` | <decision> | |
| SUI | `swiftui-rules.md` | <decision> | |
| L10N | `localization-rules.md` | <decision> | |
| NAV | `navigation-rules.md` | <decision> | |
| API | `api-contract-rules.md` | <decision> | |
| OBS | `observability.md` | <decision> | |
| ANL | `analytics-rules.md` | <decision> | |
| SEC | `ios-security.md` | <decision> | |

---

## Generated Context Index *(execution aid — no new authority)*

At the start of each complex-feature slice, run:

```bash
bash harness/scripts/print-context-index.sh --feature-dir "$FEATURE_DIR" --slice "$FEATURE_ID"
```

The output is derived from this approved contract and `feature_list.json`. It reports
the selected slice, source hashes, rule IDs that are `Required` or exceptions, and
execution flags. It is a disposable lookup for selecting context, never an approval
artifact. Do not copy its contents, this matrix, or acceptance criteria into the slice
summary; cite these authoritative source paths and hashes instead.

---

## Spec Coverage Matrix *(required)*

Map every `FR-*` and `AC-*` from the approved source spec. Also map each edge case, non-functional constraint, verification expectation, and changed design requirement to a user story, or record the approved out-of-scope reason. Preserve source IDs verbatim.

An `FR-*` that promises multiple outcomes (happy path plus fallback/error/boundary/compatibility) must have one `AC-*` per outcome, each with its own acceptance test. A single AC for a multi-outcome FR is a coverage gap; if the spec did not decompose it, add the missing ACs here rather than silently mapping only the happy path.

| Source requirement | Requirement summary | Primary user story | Primary acceptance test | Handling |
|---|---|---|---|---|
| FR-001 | `{concise requirement text}` | US-1 | TC-US-1-01 | In scope |
| AC-001 | `{concise acceptance text}` | US-1 | TC-US-1-01 | In scope |
| Edge case: `{name}` | `{required behavior}` | US-2 | TC-US-2-02 | In scope |
| NFR: `{name}` | `{constraint}` | US-2 | TC-US-2-01 | In scope |
| Design: `{name}` | `{changed design behavior}` | US-3 | TC-US-3-01 | In scope |

---

## User Scenarios & Testing *(mandatory)*

### US-1: [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently - e.g., "Can be fully tested by [specific action] and delivers [specific value]"]

**Acceptance Criterion**:

1. **AC-US-1-01 Given** [initial state], **When** [action], **Then** [observable expected outcome]
2. **AC-US-1-02 Given** [initial state], **When** [action], **Then** [observable expected outcome]

**Acceptance Test Cases** *(required for implementation authorization)*:

Every acceptance criterion must have exactly one primary automated test case. A secondary test may be listed only when it verifies a distinct layer. Do not use manual inspection as the sole proof of a user-visible criterion. Do not let one AC bundle multiple named outcomes — split it so each outcome gets its own test; a fallback, error, boundary, or compatibility path promised by an FR needs its own AC and test, not a secondary assertion inside the happy-path test.

| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|---|
| TC-US-1-01 | AC-US-1-01 | iOS simulator integration | `NotesTakingAppiOSTests/[Class]Tests.swift#[method]` | `sharedContracts/test-scenarios/<scenario>.json` | Given [fixture], when [event] | Assert [state, output, and observable result] | `xcodebuild test -only-testing:<test-target>/<Class>` |
| TC-US-1-02 | AC-US-1-02 | Swift Testing unit | `NotesTakingAppiOSTests/[Class]Tests.swift#[method]` | N/A — no API | Given [fixture], when [event] | Assert [state, output, and observable result] | `xcodebuild test -only-testing:<test-target>/<Class>` |
| TC-US-1-VIS | AC-US-1-01 | Visual verification *(only for the final user-reachable slice with `requires_visual_verification == true`)* | `NotesTakingAppiOSUITests/<Feature>VisualFlowTests.swift#<captureMethod>` | N/A — no API | Capture scope: component. Given the target production SwiftUI View is rendered in the target visual state inside a `XCUIApplication()` test, when the UI is idle and `XCUIScreen.main.screenshot()` captures the active window | The in-test capture produces a non-empty PNG on device at `/var/tmp/<screen_id>_<state>.png`, copied to `$FEATURE_DIR/visual_evidence/<screen_id>_<state>.png` for visual review against `$FEATURE_DIR/design.md` | `xcodebuild test -only-testing:<test-target>/<Feature>VisualFlowTests/<captureMethod> && cp /var/tmp/<screen_id>_<state>.png "$FEATURE_DIR/visual_evidence/<screen_id>_<state>.png" && test -s "$FEATURE_DIR/visual_evidence/<screen_id>_<state>.png"` |

**Verification Rules**:

1. The test must execute the production entry point for this user story. A unit test of an uncalled helper or use case is insufficient.
2. A user-visible flow that crosses presentation, domain, or data boundaries must include an integration or instrumented test covering the complete path.
3. The assertions must cover every named outcome in the linked AC, including fallback, error, and persistence behavior where required.
4. Record the Test ID, command, exit status, and result in the feature evidence before a status can become `passing`.
5. Run `bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --test "$FEATURE_ID"` before the test stage is complete, then run it again with `--evaluate "$FEATURE_ID"` after successful evidence is recorded. The first command proves the declared Swift method and scenario reference; the second also proves suite-scoped evidence.
6. **Visual verification gate** *(applies only when the slice's `requires_visual_verification` flag in `feature_list.json` is `true`)*: select one final user story that has a stable production entry point and makes the completed visual flow reviewable. That story MUST include one `TC-US-*-VIS` row per visually distinct completed-flow state that needs visual assessment; intermediate UI slices do not need screenshot rows. Each visual row MUST name a dedicated `*VisualFlowTests.swift` file and method, separate from functional UI tests. Its exact command MUST use a method-scoped `-only-testing:<test-target>/<Feature>VisualFlowTests/<method>` selector, render the active SwiftUI View, ensure the UI is idle, and capture a screenshot from within the running test via `XCUIScreen.main.screenshot()`, saving to `/var/tmp/<name>.png`. The command then copies the file to `$FEATURE_DIR/visual_evidence/<name>.png` and verifies it is non-empty. **Prohibition**: Post-test external screencaps (such as chaining CLI screenshots after `xcodebuild test`) are strictly forbidden because the test window is already destroyed when the test runner finishes, resulting in captures of the simulator home screen rather than the intended UI state. The Generator cannot transition the visual-verification owner to `passing` until every declared `TC-US-*-VIS` row has exit code 0, a saved screenshot from an in-test capture, and recorded target-state proof. The Evaluator then visually compares the captured screenshot against `$FEATURE_DIR/design.md` and records any deviation in layout, typography, color, spacing, or control placement as a review finding — canvas/photo content may legitimately differ between mockup and real app, so the comparison focuses on UI chrome, not image content.
   Before the visual owner can pass, create `$FEATURE_DIR/visual_evidence/reference-anchor-verification.md` from `harness/templates/visual-reference-anchor-verification-template.md`. It must contain exactly one row per `TC-US-*-VIS-*`, cite the non-empty approved `design/` asset and matching actual screenshot, name the visual-bounds `accessibilityIdentifier` and runtime test method, and state a concrete bounds relation. If a row claims app-shell chrome (for example global navigation, system bars, or a full-page shell), its Setup and action must declare `Capture scope: app-shell; production root: <ViewOrWindowRoot>.` and the named test must invoke that root; a content-only screen capture is supplemental only. If the reference concerns a visual that sits inside a larger touch target, measure a test tag attached to the visual shape—not only the touch target.
   The visual owner's `feature_list.json` must mirror these rows in `acceptance_test_ids`, include each visual method in `verification`, and record successful connected-test evidence for each row. Run `bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR"` to enforce this alignment.
7. **Platform verification gate**: run `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --planning` during planning. During delivery, run `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate --slice "$FEATURE_ID"`; a slice that owns a declared real-boundary test cannot be accepted or marked `passing` until this exits 0. A non-owning slice validates the planned contract with the same slice-scoped command, while `bash harness/scripts/check-platform-evidence.sh "$FEATURE_DIR" --evaluate` remains mandatory before final feature evaluation.

---

### US-2: [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Criterion**:

1. **AC-US-2-01 Given** [initial state], **When** [action], **Then** [observable expected outcome]

**Acceptance Test Cases** *(required for implementation authorization)*:

| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|---|
| TC-US-2-01 | AC-US-2-01 | iOS simulator integration | `NotesTakingAppiOSTests/[Class]Tests.swift#[method]` | `sharedContracts/test-scenarios/<scenario>.json` | Given [fixture], when [event] | Assert [state, output, and observable result] | `xcodebuild test -only-testing:<test-target>/<Class>` |

---

### US-3: [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Criterion**:

1. **AC-US-3-01 Given** [initial state], **When** [action], **Then** [observable expected outcome]

**Acceptance Test Cases** *(required for implementation authorization)*:

| Test ID | Covers AC | Test layer | Test file and method | Shared scenario(s) | Setup and action | Required assertions | Exact command |
|---|---|---|---|---|---|---|---|
| TC-US-3-01 | AC-US-3-01 | iOS simulator integration | `NotesTakingAppiOSTests/[Class]Tests.swift#[method]` | `sharedContracts/test-scenarios/<scenario>.json` | Given [fixture], when [event] | Assert [state, output, and observable result] | `xcodebuild test -only-testing:<test-target>/<Class>` |
---

[Add more user stories as needed (US-4, US-5, …), each with an assigned priority]

---

## 📊 Sprint Log
> The audit trail tracking each agent's execution phase, revisions, and evaluation scores.

| Phase | Agent | Target / Outcome | Notes & Core Decisions |
| :--- | :--- | :--- | :--- |
| **Planning** | Planner | `sprint-contract.md` compiled | Criteria defined and scope boundaries set. |
| **Implementation** | Generator | `{Initial implementation / Code written}` | |
| **Review 1** | Evaluator | `{Score X/5 / Findings list}` | |
| **Revision 1** | Generator | `{Fixes applied}` | |
| **Final Review** | Evaluator | APPROVED (Score: `X/5`) | All criteria successfully validated. |
