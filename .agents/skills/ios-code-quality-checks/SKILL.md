---
name: ios-code-quality-checks
description: Runs SwiftLint, build validation, and custom harness rule check scripts.
---

# Skill — iOS Code Quality Checks

## Purpose
Run all automated quality checks before handing off to code review.

---

## Load
- `gates/ci-checks.md`

---

## Execute

### 1. Build Check
```bash
xcodebuild -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' build
```
Must pass — failing build is a hard blocker.

### 2. SwiftLint
```bash
swiftlint
```
Must pass with zero errors. Warnings should be reviewed.

### 3. Architecture Rules Check
```bash
bash harness/scripts/check-architecture-rules.sh
```
Verifies layer boundaries, no DTO leaks, no framework imports in domain layer.

### 4. Navigation Rules Check
```bash
bash harness/scripts/check-navigation-rules.sh
```
Verifies typed root navigation, Hashable route definitions, ID-style route arguments,
and ViewModel navigation-state constraints. The companion contract test can be run with
`bash harness/scripts/tests/navigation-rules-contract-test.sh`.

### 5. SwiftUI Rules Check
```bash
bash harness/scripts/check-swiftui-rules.sh
```
Verifies no hardcoded strings, no hardcoded colors, all interactive elements have `accessibilityIdentifier`.

### 6. Localization Check
```bash
bash harness/scripts/check-localization-rules.sh
```
Detects hardcoded strings in SwiftUI Views.

### 7. Test Assertions Quality
```bash
bash harness/scripts/check-test-assertions-quality.sh
```
Ensures no envelope-only assertions.

### 8. No Dummy Code
```bash
grep -rn "fatalError.*TODO\|#warning.*stub\|// dummy\|// placeholder\|// stub" NotesTakingAppiOS/ sharedContracts/
```
Must return zero matches.

### 9. Rule Applicability Harness Contract
```bash
bash harness/scripts/tests/rule-applicability-contract-test.sh
```
Verifies the requirements-to-review contract itself. This is required when harness
workflow, rule, skill, template, or gate sources change.

### 10. Rules-Matrix Contract
```bash
bash harness/scripts/tests/rules-matrix-contract-test.sh
```
Verifies that the canonical enforcement catalog matches every iOS matrix row, summary,
and scripted checker owner.

---

## Done When
- Build passes
- SwiftLint passes
- All custom rule check scripts exit 0
- No dummy code found
- Rule Applicability contract test passes when harness guidance changed
