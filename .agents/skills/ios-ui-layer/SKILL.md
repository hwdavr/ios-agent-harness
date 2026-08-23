---
name: ios-ui-layer
description: Implements the UI layer (SwiftUI Views, ViewModels, UI models, and navigation).
---

# Skill — iOS UI Layer

## Purpose
Implement the UI Layer: ViewModels, UI models, mappers, and SwiftUI Views.

---

## Load
- `rules/ios-architecture.md`
- `rules/swiftui-rules.md`
- `rules/navigation-rules.md`
- `rules/localization-rules.md`
- `rules/analytics-rules.md`
- `rules/observability.md`
- `docs/product/design_system.md`

---

## Execute

### 1. ViewModel
1. Mark as `@Observable` — expose single UI state struct per screen
2. Handle: loading, content, empty, error, retry, permission
3. Emit events via closures — not persistent state
4. Call use cases only — no direct repository/data source access
5. Fire analytics from ViewModel, log per `rules/observability.md`

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
1. Update navigation destinations with enum routes
2. Add strings to `Localizable.xcstrings`

---

## Done When
- Stateless `Content` pattern used
- No business logic in Views
- No hardcoded strings or colors
- All interactive elements have `accessibilityIdentifier`
- UI matches design system
- Build passes