---
name: ios-code-review
description: Reviews iOS code for architecture, correctness, SwiftUI patterns, and maintainability.
---

# Skill — iOS Code Review

## Purpose
Conduct structured code review of iOS changes: architecture, correctness, SwiftUI patterns, security, and maintainability.

---

## Load
- `rules/ios-architecture.md`
- `rules/implementation-rules.md`
- `rules/testing-strategy.md`
- `rules/swiftui-rules.md`
- `rules/navigation-rules.md`
- `rules/localization-rules.md`
- `rules/analytics-rules.md`
- `rules/observability.md`
- `rules/api-contract-rules.md`
- `harness/templates/rule-applicability-template.md`

---

## Execute

### 1. Build and Static Quality Checks

Run all checks and record results. The repository-wide source-rule bundle is
mandatory even when the reviewed diff is small:
```bash
xcodebuild -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' build
swiftlint
bash harness/scripts/check-full-source-rules.sh
```

`check-full-source-rules.sh` passes `--all` to the architecture, SwiftUI, and
localization AST checkers, scans test roots for assertion quality, and runs
navigation checks, then runs the AI/WebView security evaluator and its contract
test. It executes every checker and aggregates failures; record its complete
output and treat any non-zero result as a review failure, including
pre-existing findings.

On Windows (using PowerShell or Command Prompt), run the native script launcher:
```powershell
harness\scripts\check-full-source-rules.cmd
```

### 2. Rule Applicability Reconciliation

1. Read the approved matrix from the active specification and implementation plan.
2. Inspect the diff independently for a trigger for each of ARCH, IMPL, TEST, SUI,
   L10N, NAV, API, OBS, and ANL.
3. For every rule, record the approved decision, observed trigger, code/static-check
   evidence, and result in the code-review report.
4. A missing row, a trigger under `Not applicable`, or an exception without the cited
   user approval is **Required** severity. Do not require analytics events or logs when
   the matrix validly marks them not applicable.

### Architecture Review
- [ ] No View calling repository directly
- [ ] No ViewModel calling URLSession directly
- [ ] No DTOs outside data layer
- [ ] No business logic in SwiftUI Views
- [ ] No framework imports in domain layer
- [ ] Use cases are single-responsibility
- [ ] Mappers are in correct layers

### SwiftUI Review
- [ ] Stateless `Content` + stateful `Screen` pattern used
- [ ] No hardcoded strings — all `LocalizedStringKey`
- [ ] No hardcoded colors — semantic tokens used
- [ ] All interactive elements have `accessibilityIdentifier`
- [ ] View conforms to `design_system.md`

### Correctness Review
- [ ] All UI states covered: loading, content, empty, error, retry
- [ ] No `fatalError("TODO")`, `#warning("stub")`, or dummy code
- [ ] Error handling at every async boundary
- [ ] Enums have `unknown` fallback
- [ ] Navigation back-stack behavior correct

### Observability and Analytics Review *(when OBS or ANL is Required)*
- [ ] `os.Logger` with proper subsystem/category
- [ ] Correct log levels (debug/info/warning/error/fault)
- [ ] No PII in logs
- [ ] Analytics fired from ViewModel layer when ANL is Required

---

## Output
Code review findings with severity: Critical, Required, or Suggested.
Each finding references the violated rule file and specific line. Include a complete
Rule Applicability Reconciliation table with the approved decision, diff trigger,
evidence, and result for all nine rules.
