# Clean State Checklist

Run this before committing and at the end of a feature session. Record unavailable
runtime checks as blocked evidence, never as a pass.

## 1. Rule Applicability Contract

- [ ] The approved specification has all nine rows: ARCH, IMPL, TEST, SUI, L10N, NAV,
  API, OBS, and ANL.
- [ ] Each decision is `Required`, `Not applicable — <reason>`, or an explicitly
  user-approved exception.
- [ ] Plans and review reports preserve the decisions, rationale, and evidence.
- [ ] Analytics and observability were assessed without adding events/logs merely to
  satisfy the matrix.

## 2. Build, Static Analysis, and Suppressions

- [ ] `xcodebuild -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' build` passes when the simulator is available.
- [ ] `swiftlint` and applicable harness rule checks are recorded with exit codes.
- [ ] No new `swiftlint:disable`, broad exclusion, baseline, `@preconcurrency import`,
  or inline debug workaround hides a violation without documented user approval.

## 3. Architecture and Implementation

- [ ] Data, Domain, ViewModel, and SwiftUI boundaries are preserved; DTOs do not leak
  out of the data layer.
- [ ] Domain code has no SwiftUI/UIKit, SwiftData, URLSession, or data-layer imports.
- [ ] Every changed function, branch, and callback implements the approved behavior;
  no placeholders, stubs, dummy returns, or no-op handlers remain.
- [ ] Secrets are absent from source and configuration follows the `.xcconfig` / build
  configuration policy.

## 4. UI, Navigation, and Localization *(when required)*

- [ ] SwiftUI views contain rendering and event forwarding, not business logic.
- [ ] UI states, keyboard-visible behavior, semantic colors, and accessibility
  identifiers follow the approved design and SwiftUI rules.
- [ ] User-visible text and icon labels use localization keys in `Localizable.xcstrings`.
- [ ] Typed navigation, route arguments, back-stack behavior, and cleanup match the
  approved navigation contract.

## 5. Tests and Runtime Evidence

- [ ] `xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16'` passes, or the environment block is recorded.
- [ ] Test IDs cover the required Rule Applicability rows and all acceptance criteria.
- [ ] Changed API endpoints have shared-scenario integration tests; bug fixes have a
  red-then-green reproduction test.
- [ ] UI/visual evidence is captured by XCUITest when the sprint contract requires it.

## 6. Observability, Analytics, and Privacy *(when required)*

- [ ] Added logs use `os.Logger`, `Bundle.main.bundleIdentifier` subsystem, appropriate
  level, and no PII, secrets, or user-generated sensitive content.
- [ ] Added analytics is emitted from ViewModels with approved event names/data only.

## 7. Documentation and Handoff

- [ ] Summary and review reports cite the requirement, plan, test, and command evidence.
- [ ] Complex features have a valid lifecycle state, tracker update, and required
  workspace evidence.
- [ ] New reusable decisions or pitfalls are captured where future work needs them.
