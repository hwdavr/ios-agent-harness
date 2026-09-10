---
name: context-management
description: Set up focused session context and project rules for the active task.
---

# Context Management

## Session Start — Load in Order

1. `AGENTS.md`
2. `rules/ios-architecture.md`
3. `rules/testing-strategy.md`
4. The workflow file that matches the task
5. The skill(s) for the current stage only
6. Source files for the specific feature area (ViewModel, use case, repository interface)

**Implementation-only:** load `rules/implementation-rules.md` only after the
Implementation stage is selected. Do not infer or preload iOS security guidance at session
start; the selected stage skill loads it only after inspected scope triggers its boundary.

**Rule:** Never preload all skills or conditional rules. Use the Rule Applicability trigger
catalog, or the complex-slice context index, and load only Required, excepted, or newly triggered
documents. During testing/review load `rules/testing-practices.md`; add
`rules/testing-runtime-evidence.md` only for runtime-bound claims.

---

## What to Load per Layer

| Layer | Load these files |
|-------|-----------------|
| UI / Presentation | SwiftUI View · UIState · ViewModel · UI model · mapper |
| Domain | Use case · domain model · repository protocol |
| Data | Repository impl · SwiftData Model · DTO · mapper |

---

## Workflow Selection

| Task type | File to load |
|-----------|-------------|
| New feature or enhancement | `workflows/feature-delivery.md` |
| Bug, crash, or regression | `workflows/bug-fixing.md` |
| UI implementation or update | `workflows/create-ui-and-verify.md` |
| API contract change | `workflows/api-contract-update.md` |

---

## Project Map Quick Reference

| Directory | Contains |
|-----------|----------|
| `NotesTakingAppiOS/` | App code (`Views/`, `ViewModels/`, `Domain/`, `Data/`) |
| `NotesTakingAppiOSTests/` | Unit and integration tests (Swift Testing + XCTest) |
| `NotesTakingAppiOSUITests/` | Instrumented UI tests (XCUITest) |
| `sharedContracts/` | API specs and shared JSON test scenarios |
| `docs/knowledge/` | Historical decisions and known pitfalls |

---

## Context Drift — Warning Signs

- Wrong directory structure or naming conventions
- View calling a repository directly
- `sleep()` in tests instead of `waitForExistence`
- Hardcoded strings instead of `LocalizedStringKey` / `String(localized:)`
- Missing `accessibilityIdentifier` on interactive elements
- DTO outside the data layer
- Hallucinated type or method names

## Context Drift — Recovery

1. Stop generating code
2. Re-read the violated rule file
3. Re-read the affected source files
4. State the correction explicitly before rewriting

---

## Session Start Checklist

- [ ] `AGENTS.md` + both L1 rule files loaded
- [ ] Correct workflow identified
- [ ] Only current-stage skill(s) loaded
- [ ] Implementation rules loaded only when the Implementation stage is selected
- [ ] Feature-area source files loaded
- [ ] No unresolved assumptions
