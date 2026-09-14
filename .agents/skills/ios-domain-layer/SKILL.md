---
name: ios-domain-layer
description: Implement domain use cases, domain models, and repository protocols.
---

# Skill — iOS Domain Layer

## Purpose
Implement the Domain Layer: use cases, domain models, and repository protocols.

---

## Load
- `rules/ios-architecture.md` (skip if already loaded this session — L1 is session-scoped)
- `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read

---

## Execute

### 1. Domain models
1. Create/update domain structs — no framework dependencies
2. Add `unknown` fallback for any new enum fields

### 2. Repository protocols
1. Define protocols in `Domain/<feature>/`
2. Use `async throws` or `AsyncStream` — match existing conventions
3. Protocols are framework-independent — no SwiftData, no URLSession imports

### 3. Use cases
1. One use case = one business capability
2. Coordinate repository protocols, not implementations
3. Contain business validation, filtering, and decision logic
4. Never import UI framework classes

---

## Done When
- No framework imports in domain layer
- All enums have `unknown` fallback
- Use cases are single-responsibility
- Build passes
