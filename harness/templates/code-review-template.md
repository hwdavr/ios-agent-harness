# Code Review — <Feature ID or vN>

Use this template for feature-review and harness-evaluation code-review reports.

## Review Scope and Evidence Provenance

| Item | Value |
|---|---|
| Feature / slice | |
| Current commit | |
| Merge base / prior reviewed commit | |
| Requirement baseline | `spec_v<N>.md` / `$FEATURE_DIR/spec.md` |
| Plan baseline | `implementation_plan_v<N>.md`, `test_plan_v<N>.md` / sprint contract |
| Changed production files reviewed | |
| Changed test files reviewed | |

## Requirement-to-Production Traceability

| Source ID | Required behavior | Production entry point | Completion / cleanup path | Test evidence | Result |
|---|---|---|---|---|---|
| FR-001 | | | | | PASS / REVISION REQUIRED / N/A |

## Rule Applicability Reconciliation

Copy the approved decisions from the specification. Independently inspect the diff for
each trigger; `Not applicable` is valid only when the trigger is absent. A missing row,
unsupported decision, or exception without direct user approval is **REVISION
REQUIRED**. Do not require analytics events or logs when their trigger is absent.

| Rule ID | Approved decision / rationale | Diff trigger found? | Code or static-check evidence | Result |
|---|---|---|---|---|
| ARCH | | Yes / No | | PASS / REVISION REQUIRED |
| IMPL | | Yes / No | | PASS / REVISION REQUIRED |
| TEST | | Yes / No | | PASS / REVISION REQUIRED |
| SUI | | Yes / No | | PASS / REVISION REQUIRED / N/A |
| L10N | | Yes / No | | PASS / REVISION REQUIRED / N/A |
| NAV | | Yes / No | | PASS / REVISION REQUIRED / N/A |
| API | | Yes / No | | PASS / REVISION REQUIRED / N/A |
| OBS | | Yes / No | | PASS / REVISION REQUIRED / N/A |
| ANL | | Yes / No | | PASS / REVISION REQUIRED / N/A |
| SEC | | Yes / No | | PASS / REVISION REQUIRED / N/A |

## Rule Detail Findings

### Architecture, Implementation, and Testing

- [ ] Layer boundaries hold: Views do not call repositories; ViewModels do not call
  URLSession or data-layer implementations; DTOs remain in the data layer.
- [ ] Every changed function, branch, and callback performs the required behavior; no
  placeholder return, `fatalError("TODO")`, no-op handler, or dummy comment exists.
- [ ] The test layer selected by the plan provides sufficient evidence for the changed
  behavior.

### SwiftUI and Localization *(when SUI or L10N is Required)*

- [ ] SwiftUI views are rendering/event surfaces; business logic is outside the view.
- [ ] Stateless content/stateful screen boundaries, semantic colors, and stable
  `accessibilityIdentifier`s follow the rule.
- [ ] User-visible text uses `LocalizedStringKey` or `String(localized:)`; required
  keys are in `NotesTakingAppiOS/Localizable.xcstrings`.

### Navigation and API Contracts *(when NAV or API is Required)*

- [ ] Typed route/back-stack behavior, destination ownership, and cleanup match the
  approved navigation design.
- [ ] OpenAPI, DTO, mapper, error, and integration-test changes agree with the approved
  API contract.

### Observability and Analytics *(when OBS or ANL is Required)*

- [ ] Every added log uses `os.Logger`, a bundle-identifier subsystem, appropriate
  level, and no PII or sensitive user-generated content.
- [ ] Analytics is emitted from a ViewModel and contains only approved event data.

## State Completion and Reachability Audit

| Changed state, callback, task, or observer | Entry point | Completion / cleanup call site | Test-only substitute found? | Result |
|---|---|---|---|---|
| | | | Yes / No | PASS / REVISION REQUIRED |

Flag completion paths called only from tests, stale transition flags, ignored callbacks,
placeholder/no-op branches, and final-state rendering without a real production trigger.

## Build and Static-Check Evidence

The source-rule result in this table must come from the full-source bundle. Its
output supplies the per-rule details below; individual checker invocations are
diagnostic follow-ups only.

| Check | Exit code | Provenance | Result / failure scope |
|---|---:|---|---|
| `xcodebuild ... build` | | Independently executed / Recorded / Not run | PASS / FAIL |
| `xcodebuild ... test` | | Independently executed / Recorded / Not run | PASS / FAIL |
| `swiftlint` | | Independently executed / Recorded / Not run | PASS / FAIL |
| `check-full-source-rules.sh` or `check-full-source-rules.cmd` | | Independently executed / Recorded / Not run | PASS / FAIL | Includes architecture, SwiftUI, localization, navigation, and test-assertion checks over the complete source tree. |
| Suppression audit | | Independently executed / Recorded / Not run | PASS / FAIL | Confirm no new suppressions, ignores, baselines, or rule exclusions were added to make checks pass. |

Never label recorded, skipped, or unavailable evidence as a fresh pass. A required
non-zero check is a non-approved result even when its failure is pre-existing; record
the baseline scope clearly.

## UI Verification *(when SUI is Required)*

- [ ] Design-system and approved feature-design comparison completed.
- [ ] XCUITest evidence covers the approved interactive and navigation outcomes.
- [ ] Visual evidence/anchors are present when the sprint contract requires them.
- [ ] Remaining differences: <none or list>.

## Security and Privacy

- [ ] No secrets or tokens are hardcoded.
- [ ] No PII, sensitive user-generated content, credentials, or backend payloads are
  logged or sent in analytics without explicit product/privacy approval.
- [ ] External data is validated at the correct boundary.

## Findings

| Severity | Rule / source | File:line | Finding | Required resolution |
|---|---|---|---|---|
| Critical / Required / Suggested | | | | |

## Verdict

- **APPROVED** — all required reconciliation rows and checks pass.
- **REVISION REQUIRED** — list the owner and next stage for every blocking finding.
