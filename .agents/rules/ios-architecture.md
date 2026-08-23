# iOS Architecture Rules

## Purpose
These rules define the mandatory layer boundaries and patterns for this project.
All contributors (human and AI) must follow these rules. Any change that violates these rules must be rejected unless this file is updated with explicit justification in the same change.

> **Enforcement Matrix** — each rule below is tagged as Scripted 🤖 / Evaluator 🧠 / Human 👁️
> in [`architecture-rules-enforcement-matrix.md`](../../harness/rules-matrix/architecture-rules-enforcement-matrix.md).

---

## Layer Model

```
View (SwiftUI) → ViewModel (@Observable) → Domain ← Data
```

Dependencies flow inward only. No upward or cross-layer dependencies.

---

## Layer Responsibilities

### View Layer
Files: SwiftUI Views, components
Responsibilities:
- Render from `@Observable` ViewModel state
- Send user actions/events to ViewModel
- Handle UI-only concerns (focus, local animation, navigation callbacks)

Must NOT:
- Call repositories directly
- Contain business rules
- Parse API responses
- Perform DTO → domain mapping
- Access remote or local data sources directly
- Import data layer classes

---

### ViewModel Layer
Files: `@Observable` classes, UI model structs
Responsibilities:
- Expose screen state as `@Observable` properties
- Coordinate use cases (domain services)
- Transform domain models into UI models
- Manage loading / success / error state transitions
- Emit one-off events (navigation, toast, alert)

Must NOT:
- Call URLSession or SwiftData directly
- Contain persistent storage logic
- Contain heavy business logic that belongs to domain
- Import data-layer implementation classes

---

### Domain Layer
Files: Use case structs/classes, domain models, repository protocols
Responsibilities:
- Define business behavior
- Define repository contracts (protocols only)
- Contain business validation and decision logic
- Remain platform-independent

Must NOT:
- Depend on SwiftUI or UIKit framework classes
- Depend on View layer classes
- Depend on URLSession or SwiftData implementation details

Scoped exception — domain boundaries:
- Features with complex processing (e.g. AI summarizer, rich text parser) may define domain contracts, keeping framework dependencies encapsulated in data layer implementations.
- The feature must document the boundary and keep all heavy processing off the main actor.

---

### Data Layer
Files: Repository implementations, remote data sources, local data sources, DTOs, mappers
Responsibilities:
- Fetch and store data
- Map external data models (DTOs) to domain models
- Implement repository protocols from domain

Must NOT:
- Expose DTOs to ViewModel or View layers
- Contain UI state logic
- Make navigation decisions

---

## Dependency Rules

Allowed:
- View → ViewModel
- ViewModel → Domain
- Data → Domain (implements protocols)
- App entry point wires dependencies together

Not allowed:
- View → Data (direct)
- Domain → View
- ViewModel → data source implementations (only domain protocols)
- View imports DTOs from data layer

---

## Dependency Injection

- Use protocol-based dependency injection:
  - **App-scoped**: Long-lived services (repositories, network clients) injected via `@Environment` or a lightweight service locator at the app root.
  - **Screen-scoped**: ViewModels scoped to a single screen via `@State` or `@EnvironmentObject`.
- Do not pass `ModelContext` or `URLSession` into domain layer

---

## State Management

- Each screen renders from a single primary ViewModel
- ViewModels use `@Observable` (Swift 6 Observation framework)
- Prefer a single `enum` or `struct` with optional content fields for UI state
- One `@Observable` class per screen — no scattered `@State` variables for business state
- One-off events (toast, navigation) must use a separate pattern (closures, async streams) — not persistent state fields

---

## Mapping Rules

Allowed:
- DTO → Domain in Data layer
- Domain → UI model in ViewModel layer

Not allowed:
- DTO → UI directly in View layer
- Domain → DTO in View layer
- API response objects passed to SwiftUI directly

---

## Forbidden Patterns

These are never allowed without explicit architectural justification:

- SwiftUI View calling repository directly
- ViewModel calling URLSession directly
- DTO used outside data layer
- Business rules inside SwiftUI View
- Domain layer importing UIKit or SwiftUI framework classes
- Adding feature logic without tests
- AI-generated code merged without review

---

## Package Structure

Mandatory feature folder layout:

```
Views/<Feature>/
  Screen.swift          # SwiftUI screen
  Components/           # Feature-specific SwiftUI components
  ViewModel.swift       # @Observable ViewModel + UIState

  Model.swift           # UI model structs
  Mapper.swift          # Domain → UI mapper

Domain/<Feature>/
  UseCase.swift         # Use case structs/classes
  Model.swift           # Domain model structs
  RepositoryProtocol.swift  # Repository protocols

Data/<Feature>/
  Remote/               # URLSession services, DTOs
  Local/                # SwiftData models, repositories
  Repository.swift      # Repository implementations
  Mapper.swift          # DTO → Domain mappers
```

### Coverage Boundary

The `Views/<Feature>/Screen.swift` and `Views/<Feature>/Components/` directories are **excluded from code coverage** because SwiftUI Views cannot be meaningfully measured by `xccov`.
The `ViewModel.swift` and `Mapper.swift` files in the ViewModel layer are **included in coverage** and must meet the 90% line coverage target.

Rule: **Never place a ViewModel class inside `Views/`**, and **never place a SwiftUI View inside a ViewModel file**.
This boundary is what makes the `xccov` target exclusion reliable.