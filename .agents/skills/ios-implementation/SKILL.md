---
name: ios-implementation
description: Implements a user story or feature across data, domain, and UI layers sequentially.
---

# Skill — iOS Implementation (Data + Domain + UI)

## Purpose
Implement the full change across all three layers — Data, Domain, and UI — in a single pass.
Work in small, vertically-sliced increments: implement one layer, verify the build, then proceed to the next.

> This is the **compact implementation stage** used by `feature-delivery` and `bug-fixing` workflows.
> For granular layer-by-layer control, use the individual stages `ios-data-layer/SKILL.md`, `ios-domain-layer/SKILL.md`, and `ios-ui-layer/SKILL.md`.

---

## Load

**Always load:**
- `docs/product/design_system.md` — mandatory visual tokens and reusable component contracts for UI-affecting work
- `rules/ios-architecture.md`
- `rules/api-contract-rules.md`
- `rules/swiftui-rules.md`
- `rules/navigation-rules.md`
- `rules/analytics-rules.md`
- `rules/localization-rules.md`
- `rules/observability.md`
- `rules/implementation-rules.md`

**Adhoc workflows** (`feature-delivery`, `bug-fixing`):
- `docs/current/implementation_plan_v<N>.md` — implementation plan approved by user
- `docs/current/spec_v<N>.md` — requirement summary, impact analysis, UIState & navigation design
- `docs/current/design.md` — screen purpose, layout, visual/interaction states, copy, components inventory (if UI changes involved)
- `docs/current/design/` — user-provided screenshots or AI-generated `mockup_*.png` images (view these for visual layout reference before implementing UI)

**Harness workflow** (`harness-generator`):
- `$FEATURE_DIR/design.md` — screen purpose, layout, visual/interaction states, copy, components inventory, accessibility
- `$FEATURE_DIR/design/` — user-provided screenshots or AI-generated `mockup_*.png` images (view these images to understand the intended visual layout before implementing UI)
- `$FEATURE_DIR/spec.md` — screen specifications, functional requirements, edge cases, persistence schema
- `$FEATURE_DIR/sprint-contract.md` — acceptance criteria, scope boundaries, verification plan
- `$FEATURE_DIR/summary_{feature_id}.md` — single source of truth for the active feature (key decisions, files changed, stage progress)

---

## Execute

### Layer 1 — Data Layer

#### 1.1 API / DTO changes
If the API contract changed:
1. Update `sharedContracts/openapi.yaml` to reflect the new contract — **do this first**
2. Create or modify DTO structs in `Data/<feature>/Remote/DTOs/`
3. Mark properties as optional (`T?`) for optional fields
4. Handle unknown enum values with a fallback variant:
   ```swift
   enum NoteStatus: String, Codable {
       case active, archived, unknown
       init(from decoder: Decoder) throws {
           let container = try decoder.singleValueContainer()
           let raw = try container.decode(String.self)
           self = NoteStatus(rawValue: raw) ?? .unknown
       }
   }
   ```

#### 1.2 SwiftData / local data changes
If local storage is affected:
1. Create or modify `@Model` class in `Data/<feature>/Local/`
2. Mark properties with default values for optional migration
3. **Increment the SwiftData schema version** — use `VersionedSchema` for migration
4. Map DTO → Domain model inside the repository — **never pass DTOs to upper layers**
5. Translate API errors to domain errors before they leave this layer
6. Map every field explicitly — no reflection or structural bridging
7. Handle nil defensively: `dto.field ?? defaultValue`

---

### Layer 2 — Domain Layer

#### 2.1 Domain model changes
1. Add or remove properties in domain model structs
2. Import **no SwiftUI or UIKit framework classes**
3. If an enum is added, include an `unknown` / fallback variant

#### 2.2 Repository protocol changes
1. Add or update method signatures in the repository protocol (defined in domain layer)
2. Keep protocols stable and framework-independent
3. Use `async throws` or `AsyncSequence` based on existing conventions in the codebase
4. Confirm the protocol change matches the Data Layer implementation above

#### 2.3 Use case changes
1. Create or update use cases — one use case does one thing
2. Use cases may coordinate multiple repository methods but must not call data sources directly
3. Implement business validation, filtering, and decision logic here — not in the ViewModel

**Business logic that belongs in use cases (not ViewModel or View):**
- Access permission checks
- Filter / sort logic driven by business rules
- Validation before mutations
- Data combination from multiple repositories

---

### Layer 3 — UI Layer

#### 3.1 ViewModel
1. Expose screen state as `@Observable` — one ViewModel per screen
2. Handle all states: loading, success, empty, error, retry, permission
3. Emit one-off events (navigation, toast, alert) via closures — not as persistent state
4. Call use cases only — **never call repositories or data sources directly**
5. Do not import URLSession or data-layer classes
6. Add structured logs at state transitions and error boundaries — follow `rules/observability.md`

#### 3.2 UI model and mapper
1. Create or update UI model structs if the domain model needs formatting for display
2. Create or update the Domain → UI mapper in the ViewModel layer
3. Do not pass domain models directly to SwiftUI Views when UI formatting is needed

#### 3.3 SwiftUI View
1. Split every screen into stateless `Content` + stateful `Screen` wrapper (see `rules/swiftui-rules.md`)
2. The stateless `Content` View receives UI state and closures — it does not call the ViewModel
3. **View the mockup images** in the active design directory before writing UI code — use both `design.md` text and visual mockup images as visual context for component layout, spacing, and visual hierarchy
4. Use `LocalizedStringKey` / `String(localized:)` for all user-visible text — **no hardcoded strings**
5. Add `.accessibilityIdentifier("stable_name")` to all interactive elements and key content areas
6. Map every visual choice to `docs/product/design_system.md` semantic tokens/shared components or to an explicit approved exception in the active `design.md`
7. **Visual-verification owner**: if this slice owns `requires_visual_verification: true` in `feature_list.json`, implement its visual capture per the sprint contract's visual-verification gate

#### 3.4 Navigation, Analytics & String resources
1. Update navigation destinations if new routes are added — use enum-based route types
2. Fire analytics events from the ViewModel — not from SwiftUI Views
3. Add all new user-visible text to `Localizable.xcstrings`

---

## Output

Update `summary_{feature_id}.md` (or `summary_v<N>.md` depending on the active workflow): mark the Implementation (Data + Domain + UI) stage complete.

---

## Done When

**This stage is complete when all of the following are true — all must be mechanically verifiable:**
- [ ] `sharedContracts/openapi.yaml` updated (if API changed)
- [ ] No DTOs referenced outside the data layer
- [ ] All new enum fields have an `unknown` / fallback variant
- [ ] SwiftData schema version incremented and migration added (if schema changed)
- [ ] Repository methods return domain models, not DTOs
- [ ] No UIKit/SwiftUI framework classes imported in domain layer
- [ ] Use cases are single-responsibility
- [ ] ViewModel does not import URLSession or data-layer classes
- [ ] SwiftUI Views do not contain business logic
- [ ] All user-visible text uses `LocalizedStringKey` — no hardcoded strings
- [ ] All interactive elements have `.accessibilityIdentifier(...)` with a stable name
- [ ] UI conforms to `docs/product/design_system.md` plus explicit approved feature exceptions
- [ ] UIState covers loading, content, empty, and error states
- [ ] Log statements use `os.Logger`, correct level, and no PII (see `rules/observability.md`)
- [ ] No dummy code in production sources — no `fatalError("TODO")`, `#warning("stub")`, stub return values, no-op handlers, or dummy comments (see `rules/implementation-rules.md`)
- [ ] Build passes: `xcodebuild -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' build`

**APPROVED →** Return to the active workflow file.