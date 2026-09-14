# CI Checks

## Purpose
Defines the minimum set of checks that must pass before a change is considered ready to merge.

---

## Required Checks

### 1. Build
```bash
xcodebuild -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' build
```
**Must pass.** A failing build is a hard blocker.

### 2. Unit and Integration Tests
```bash
xcodebuild -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' test
```
**Must pass.** All tests in `NotesTakingAppiOSTests/` must be green.

### 3. Coverage
```bash
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath Build -enableCodeCoverage YES
xcrun xccov view --report Build/Logs/Test/*.xcresult
bash harness/scripts/check-coverage.sh "$(find Build/Logs/Test -maxdepth 1 -type d -name '*.xcresult' -print -quit)" --exclude-target SwiftMath
```
**Must pass threshold:**
- Overall project: ≥ 80% line coverage
- New ViewModel classes: ≥ 90%
- New domain use case classes: ≥ 90%

The checker computes weighted line coverage from `xccov` JSON. `SwiftMath` is an explicit third-party target exclusion; add per-file thresholds with `--min-file <path>=<percent>`.

### 4. SwiftLint (static analysis + formatting)
```bash
swiftlint
```
**Must pass.** Auto-fix with `swiftlint --fix` before committing.

### 5. Architecture Rules Check
```bash
bash harness/scripts/check-architecture-rules.sh
```
**Must pass.** Catches layer boundary violations:
- DTOs referenced outside the data layer
- SwiftUI/UIKit framework imports in domain layer
- ViewModel calling data sources directly
- Business logic in SwiftUI Views

### 6. Navigation Rules Check
```bash
bash harness/scripts/check-navigation-rules.sh
```
**Must pass.** Catches navigation violations:
- Missing typed root `NavigationStack`/`NavigationSplitView` destination handling
- Non-`Hashable` routes and complex route arguments
- Conditional root destination swapping and untyped destination links
- Destination booleans or persistent route state in ViewModels
- Auth exit paths that fail to clear route state

### 7. SwiftUI Rules Check
```bash
bash harness/scripts/check-swiftui-rules.sh
```
**Must pass.** Catches SwiftUI-specific violations:
- Hardcoded strings (must use `LocalizedStringKey`)
- Hardcoded colors (must use semantic tokens)
- Interactive elements without `.accessibilityIdentifier(...)`
- ViewModel or repository calls inside stateless `Content` Views
- Unstable `accessibilityIdentifier` values (string interpolation)

### 7a. Full Source Rules Bundle
```bash
bash harness/scripts/check-full-source-rules.sh
```
Windows:
```powershell
harness\scripts\check-full-source-rules.cmd
```
**Must pass.** This is the required repository-wide source-rule gate used by
generator, evaluation, fix, and CI flows. It passes `--all` to the architecture,
SwiftUI, and localization AST checkers, scans test roots for assertion quality,
runs navigation checks, executes every checker after earlier failures, and returns
non-zero if any checker reports a violation. Individual checker commands are useful
for diagnosis but cannot replace this bundle as evidence.

The bundle also runs the AI/WebView security evaluator and its negative-case
contract test. These checks are mandatory in every flow that invokes the
full-source bundle; no separate workflow invocation is required. The evaluator
rejects unsafe cleartext, WebView, Mermaid, AI-input logging, and untrusted-output
sink patterns, while the contract test proves unsafe fixtures fail and reports do
not leak fixture content.

### 7b. iOS Security Code Rules

Changes that touch an iOS security boundary must load
`.agents/rules/ios-security.md` and carry its boundary, failure-mode, and test
evidence into the review. The full-source bundle is the canonical CI enforcement
entry point; SwiftLint and the applicable instrumented boundary tests remain
required. A missing runtime or unavailable platform boundary is blocked evidence,
not a passing check.

### 8. Localization Check
```bash
bash harness/scripts/check-localization-rules.sh
```
**Must pass.** Detects hardcoded strings in SwiftUI Views.

### 9. Test Assertions Quality
```bash
bash harness/scripts/check-test-assertions-quality.sh
```
**Must pass.** Ensures tests do not use envelope-only or shallow assertions.

### 10. No Dummy Code
```bash
grep -rn "fatalError.*TODO\|#warning.*stub\|// dummy\|// placeholder\|// stub" NotesTakingAppiOS/ sharedContracts/
```
**Must pass.** Must return zero matches. No stubs, `fatalError("TODO")`, `#warning("stub")`, or `// dummy implementation` comments in production code.

### 11. Feature Lifecycle Validation
```bash
bash harness/scripts/check-feature-lifecycle.sh
```
**Must pass** before selecting a complex feature and after every tracker transition.

### 12. Visual Evidence Contract (when visual verification is required)
```bash
bash harness/scripts/check-visual-evidence-contract.sh "$FEATURE_DIR"
```
**Must pass.** Every visual verification method in the final owner's `feature_list.json` must have a matching sprint-contract row, acceptance-test ID, successful test evidence, a non-empty screenshot, and reference-anchor proof.

### 13. Keyboard-Visible Planning Mockup (when a planned screen or sheet has text input)
```bash
bash harness/scripts/check-keyboard-mockup-contract.sh "$FEATURE_DIR"
```
**Must pass during harness planning.** A design with text input must describe the keyboard-visible state and reference distinct non-empty base and keyboard-visible mockup assets.

### 13a. Existing-Surface Planning Baseline (when a planned screen is updated)
```bash
bash harness/scripts/check-existing-screen-baseline-contract.sh "$FEATURE_DIR"
bash harness/scripts/tests/existing-screen-baseline-contract-test.sh
```
**Must pass during harness planning.** Every `Updated` screen needs an unchanged, source-fed
simulator capture produced inside the named instrumented UI test. The design must trace the test file,
method, test-produced capture name, pulled `design/baseline_*.png` asset, and passing simulator
execution. Generic mockups and post-test command-line screencaps cannot satisfy this baseline.

### 14. Rule Applicability Harness Contract (when harness guidance changes)
```bash
bash harness/scripts/tests/rule-applicability-contract-test.sh
```
**Must pass** when changing `AGENTS.md`, workflows, skills, templates, or artifact gates
that govern requirements, planning, implementation, testing, or review. Ensures requirement
artifacts carry all ten rule decisions and that the stage gate rejects incomplete matrices.

### 15. Acceptance-Test Traceability Contract
```bash
bash harness/scripts/check-acceptance-test-traceability.sh "$FEATURE_DIR" --evaluate
```
**Must pass** before a harness slice is marked tested or evaluated. It proves that
each acceptance Test ID maps to one declared Swift test method, a suite-scoped
test command, its declared shared JSON scenario(s), and successful evidence.

### 16. Evaluation/Fix Lifecycle Contract
```bash
bash harness/scripts/tests/review-lifecycle-contract-test.sh
```
**Must pass** whenever the evaluator/fix workflows, review templates, or their
artifact validators change. It rejects free-form score/routing mismatches,
contradictory successful evidence, and fix passes that advance beyond a blocked
stage or leave review findings without in-report resolution status.

### 17. AST Rule-Checker Contract
```bash
bash harness/scripts/tests/ast-rule-checker-contract-test.sh
```
**Must pass** whenever one of the Swift-source rule checkers, the harness AST
package, or its fixtures changes. This resolves the pinned SwiftSyntax package,
runs visitor unit tests, and verifies valid, invalid, multiline, and
comment/string false-positive fixtures through the public shell wrappers.

### 18a. Full Source Rules Bundle Contract
```bash
bash harness/scripts/tests/full-source-rules-contract-test.sh
```
**Must pass.** Proves the bundle forces full-source scans, runs every checker even
when an earlier checker fails, and fails on an untouched source violation.

### 18b. Role-Profile Alignment Contract
```bash
bash harness/scripts/tests/role-profile-contract-test.sh
```
**Must pass** when role profiles, complex-feature workflows, or named skills change.
It rejects stale `docs/current` paths, obsolete task-selection instructions, invalid
template paths, and unavailable evaluator skill names in `.agents/agents/`.

---

## Conditional Checks

### UI tests (when UI changed)
```bash
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOSUITests -destination 'platform=iOS Simulator,name=iPhone 16'
```
Run when the change modifies SwiftUI screens or navigation.
