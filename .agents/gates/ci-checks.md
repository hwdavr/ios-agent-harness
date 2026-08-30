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

### 14. Rule Applicability Harness Contract (when harness guidance changes)
```bash
bash harness/scripts/tests/rule-applicability-contract-test.sh
```
**Must pass** when changing `AGENTS.md`, workflows, skills, templates, or artifact gates
that govern requirements, planning, implementation, testing, or review.

### 15. Rules-Matrix Contract
```bash
bash harness/scripts/tests/rules-matrix-contract-test.sh
```
**Must pass** whenever a rules-enforcement matrix, its catalog, or a scripted rule
owner changes. The catalog is the source of truth for every matrix row, summary count,
and scripted checker owner; stale summaries and unknown owners are hard failures.

---

## Conditional Checks

### UI tests (when UI changed)
```bash
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOSUITests -destination 'platform=iOS Simulator,name=iPhone 16'
```
Run when the change modifies SwiftUI screens or navigation.
