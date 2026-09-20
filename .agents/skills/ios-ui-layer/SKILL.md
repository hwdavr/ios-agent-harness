---
name: ios-ui-layer
description: Implement SwiftUI views, ViewModels, UI models, and navigation flows.
---

# Skill — iOS UI Layer

## Purpose
Implement the UI Layer: ViewModels, UI models, mappers, and SwiftUI Views.

For a small UI-only adjustment to one existing screen or component, this skill is a
direct implementation lane. Do not create unrelated feature, bug-fixing, or
`create-ui-and-verify` workflow artifacts unless the change expands beyond the
skill's scope or explicitly requires their visual-verification contract.

---

## Load
- `rules/ios-architecture.md` (skip if already loaded this session — L1 is session-scoped)
- `rules/swiftui-rules.md`
- `rules/navigation-rules.md`
- `rules/localization-rules.md`
- `rules/analytics-rules.md`
- `rules/observability.md`
- `harness/templates/rule-applicability-template.md`
- `docs/product/design_system.md`

---

## Execute

Before editing, read the active specification's canonical Rule Applicability matrix.
Implement only the rows marked `Required`; keep non-applicable/exception rationales in
that specification and raise a specification update if the UI work introduces a new
trigger.

### 1. ViewModel
1. Mark as `@Observable` — expose single UI state struct per screen
2. Handle: loading, content, empty, error, retry, permission
3. Emit events via closures — not persistent state
4. Call use cases only — no direct repository/data source access
5. When ANL is `Required`, fire approved analytics from the ViewModel. When OBS is
   `Required`, add only the approved `os.Logger` diagnostics; neither is mandatory
   when its trigger is absent.

### 2. UI model + mapper
1. Map Domain → UI structs if formatting is needed
2. Mapper in ViewModel layer, not in SwiftUI View

### 3. SwiftUI View
1. Stateless `Content` + stateful `Screen` wrapper pattern
2. View mockups before coding UI
3. `LocalizedStringKey` — no hardcoded strings
4. `.accessibilityIdentifier(...)` on all interactive elements
5. Semantic color tokens — no hardcoded colors
6. Conform to `design_system.md`

### 4. Navigation + Strings
1. When NAV is `Required`, update navigation destinations with enum routes.
2. When L10N is `Required`, add strings to `Localizable.xcstrings`.

---

## Done When
- Stateless `Content` pattern used
- No business logic in Views
- No hardcoded strings or colors
- All interactive elements have `accessibilityIdentifier`
- UI matches design system
- Required Rule Applicability rows have the planned UI evidence; conditional telemetry was not added without a trigger
- Build passes
