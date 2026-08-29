# Implementation Plan Template

Use this template when producing the plan in the **Implementation Plan** stage.

---

## Feature / Bug

> One line description of what is being implemented or fixed.

---

## Requirement Summary

> 2–3 sentences. What is being built, why, and for whom.

---

## Impact Summary

| Layer | Files Affected | Change Type |
|-------|---------------|-------------|
| View | `path/to/Screen.swift` | modify |
| ViewModel | `path/to/ViewModel.swift` | modify |
| Domain | `path/to/UseCase.swift` | new |
| Data | `path/to/DTO.swift`, `path/to/Mapper.swift` | modify |
| Navigation | `path/to/ContentView.swift` | extend |
| Tests | `path/to/ViewModelTests.swift` | modify |

---

## API Changes

- **Classification**: backward compatible / backward compatible but risky / breaking / none
- **Force update required**: yes / no / unknown
- **Fields added**: `fieldName: Type`
- **Fields removed**: `fieldName`
- **Fields changed**: `fieldName: OldType → NewType`
- **OpenAPI Status**: <Already defined in sharedContracts/openapi.yaml / Requires update: list changes>

---

## Rule Applicability Implementation

Copy the approved Rule Applicability matrix from the requirement artifact. Keep all
nine rows; do not replace a `Not applicable` or approved exception with silence.

| Rule ID | Approved decision | Planned work or retained rationale | Verification evidence |
|---|---|---|---|
| ARCH | <decision> | <files/boundary decision or rationale> | <evidence> |
| IMPL | <decision> | <files/real behavior or rationale> | <evidence> |
| TEST | <decision> | <test layer or rationale> | <evidence> |
| SUI | <decision> | <UI work or rationale> | <evidence> |
| L10N | <decision> | <catalog/accessibility work or rationale> | <evidence> |
| NAV | <decision> | <route/back-stack work or rationale> | <evidence> |
| API | <decision> | <OpenAPI/DTO work or rationale> | <evidence> |
| OBS | <decision> | <logger/error-boundary work or rationale> | <evidence> |
| ANL | <decision> | <event work or `analytics: none` rationale> | <evidence> |

---

## Files to Create

| File | Purpose |
|------|---------|
| `path/to/NewFile.swift` | reason |

---

## Files to Modify

| File | What Changes |
|------|-------------|
| `path/to/ExistingFile.swift` | description of change |

---

## Files to Delete

| File | Reason |
|------|--------|
| `path/to/OldFile.swift` | reason |

---

## UIState Design

```swift
struct ExampleUIState {
    var isLoading: Bool = false
    var content: ExampleUIModel? = nil
    var error: String? = nil
}
```

```swift
@Observable
class ExampleViewModel {
    var uiState = ExampleUIState()
    // ...
}
```

States covered:
- [ ] Loading
- [ ] Success / Content
- [ ] Empty
- [ ] Error
- [ ] Retry
- [ ] Permission / Auth (if applicable)

---

## Test Plan

> Produce a separate test plan document using **[`harness/templates/test-plan-template.md`](test-plan-template.md)** and link it here once created.

---

## Explicit Assumptions

1. <assumption>

---

## Risks

1. Risk: <what could go wrong> — Mitigation: <how to reduce it>

---

## Migration / Compatibility Notes

> Any SwiftData migration, backward compatibility handling, or phased rollout considerations.

---

## Out of Scope

> List anything explicitly NOT being changed in this task to prevent scope creep.
