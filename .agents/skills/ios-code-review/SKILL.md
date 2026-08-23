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
- `rules/swiftui-rules.md`
- `rules/navigation-rules.md`
- `rules/localization-rules.md`
- `rules/implementation-rules.md`
- `rules/analytics-rules.md`
- `rules/observability.md`
- `rules/api-contract-rules.md`

---

## Execute

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

### Observability Review
- [ ] `os.Logger` with proper subsystem/category
- [ ] Correct log levels (debug/info/warning/error/fault)
- [ ] No PII in logs
- [ ] Analytics fired from ViewModel layer

---

## Output
Code review findings with severity: Critical, Required, or Suggested.
Each finding references the violated rule file and specific line.