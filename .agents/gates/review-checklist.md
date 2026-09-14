# Review Checklist

## Purpose
Checklist for reviewing any code change before it is considered complete.

---

## Merge Approval

- [ ] A designated human reviewer has reviewed the report and explicitly approved the change before merge.
- [ ] Any rule exception cites the user's direct approval and its exact boundary.

---

## Layer Boundaries

- [ ] UI layer does not call repositories or data sources directly
- [ ] ViewModel does not import URLSession, SwiftData, or data-layer classes
- [ ] Domain layer has no UIKit or framework imports
- [ ] DTOs are not exposed outside the data layer
- [ ] No domain models are used directly in Views without mapping to UI models (if formatting is needed)

---

## State and UI

- [ ] Each modified screen renders from a single state structure or `@Observable` ViewModel
- [ ] All user-visible text uses `LocalizedStringKey` or `String(localized:)` — no hardcoded strings
- [ ] All colors use semantic tokens (`AppColors`) — no hardcoded colors
- [ ] All interactive elements have `accessibilityIdentifier(...)` with stable names
- [ ] Loading, success, empty, and error states are all handled

---

## Testing

- [ ] New use cases, ViewModels, and mappers have unit tests
- [ ] At least one integration test per new API endpoint
- [ ] Shared JSON scenarios used — no inline mock data in test cases
- [ ] Platform capability matrix exists and covers minimum, target, and important API boundaries
- [ ] Unsupported runtime/device/model/locale/permission conditions fail loudly; no skipped environment is recorded as pass
- [ ] Platform-bound behavior has a real instrumented boundary test; fake recognizers and unit-only tests are supplemental only
- [ ] Navigation, state restoration, back-stack, view-recreation, and post-return persistence behavior has a named production-entry journey test
- [ ] Rich-text/inline-formatting appearance claims have source-fed visual evidence and an explicit pixel comparison in the named test method
- [ ] Code coverage ≥ 80% overall, ≥ 90% for new classes
- [ ] All tests pass: `xcodebuild test`
- [ ] Full-source rules bundle passes — run `bash harness/scripts/check-full-source-rules.sh` (or `harness\scripts\check-full-source-rules.cmd` on Windows); this includes the AI/WebView security evaluator and contract test
- [ ] Rendering/generation tests assert semantic content (node labels, shapes, connectors), not just envelope tags (`<svg>`, `<html>`) — confirm the test-assertion result from the full-source bundle or run `bash harness/scripts/check-test-assertions-quality.sh` for diagnosis

---

## Scope Discipline

- [ ] No unrelated changes mixed into this diff
- [ ] No speculative refactoring of files not required by the task
- [ ] Xcode project / package dependencies not changed unless explicitly required
- [ ] No broad theming redesign or repository-wide moves

---

## Security

- [ ] If an iOS security boundary changed, `.agents/rules/ios-security.md` was loaded and the review records its trust boundary, validation/failure behavior, and evidence; the full-source bundle's AI/WebView evaluator and contract passed
- [ ] No secrets, API keys, or tokens hardcoded in source
- [ ] No PII (name, email, phone) logged
- [ ] Sensitive data stored securely in Keychain, not in plaintext
- [ ] No unsafe WKWebView or universal link handling introduced
- [ ] Auth/session behavior not weakened

---

## Build and Quality

- [ ] `xcodebuild build` passes
- [ ] `xcodebuild test` passes
- [ ] `swiftlint` passes
- [ ] `bash harness/scripts/check-full-source-rules.sh` passes
