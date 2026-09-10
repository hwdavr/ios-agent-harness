---
name: ios-data-layer
description: Implement SwiftData persistence, URLSession networking, DTOs, and repositories.
---

# Skill — iOS Data Layer

## Purpose
Implement the Data Layer portion of a feature: DTOs, local persistence, remote data sources, and repository implementations.

---

## Load
- `rules/ios-architecture.md`
- `rules/api-contract-rules.md`

---

## Execute

### 1. API / DTO changes
1. Update `sharedContracts/openapi.yaml` first if contract changed
2. Create/modify Codable DTO structs in `Data/<feature>/Remote/`
3. Optional fields → `T?`, required fields → non-optional
4. Unknown enum values → always use `unknown` fallback in custom decoder

### 2. SwiftData / local persistence
1. Create/modify `@Model` classes in `Data/<feature>/Local/`
2. Use `@Attribute` for constraints, `@Relationship` for relations
3. Use `VersionedSchema` for migration — never `ModelConfiguration(isStoredInMemoryOnly:)` for production

### 3. Repository implementation
1. Implement repository protocol from domain layer
2. Map DTO → Domain model inside repository — never expose DTOs
3. Translate API errors to domain errors before leaving data layer
4. Map every field explicitly

---

## Done When
- `openapi.yaml` is current
- No DTO leaks outside data layer
- Repository returns domain models
- Build passes
