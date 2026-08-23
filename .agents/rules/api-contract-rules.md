# API Contract Rules

## Purpose
Rules for reviewing, classifying, and handling API contract changes in this project.

---

## When to Apply
Apply these rules whenever:
- A new API endpoint is introduced
- An existing endpoint changes its request or response
- A field is added, removed, renamed, or changes type
- Error response format changes

---

## OpenAPI Contract

The authoritative API contract is `sharedContracts/openapi.yaml`.

Rules:
- All API endpoints used by the iOS app must be defined in `openapi.yaml`
- If a new endpoint or changed endpoint is not yet in `openapi.yaml`, update it before implementing
- DTOs must match the contract — do not guess field names or types from behavior

---

## Change Classification

Classify every API change before implementing:

| Classification | Examples |
|---|---|
| **Backward compatible** | Adding optional field, adding new endpoint, loosening validation |
| **Backward compatible but risky** | New non-null field with server-side default, new enum value, nullable→optional change |
| **Breaking change** | Removing field, renaming field, changing type, removing enum value, changing auth |

State the classification explicitly before implementation. Breaking changes require escalation.

---

## Field Handling Rules

### New optional field
- Add to DTO as optional: `let newField: String? = nil`
- Map defensively — never crash on nil: `dto.newField ?? defaultValue`

### New required field
- Confirm with backend whether old app versions receive it
- If old versions won't receive it, treat as optional with fallback

### Removed field
- Confirm field is gone from server contract before removing from DTO
- Keep the field if old server versions may still return it (treat as optional)

### Renamed field
- Treat as a new field + removed field
- Confirm rollout sequence with backend

### Changed type
- Classify as breaking change
- Add explicit conversion or fallback in mapper

### New enum value
- Always add an `unknown` / fallback variant in domain model
- Mapper must never crash on unrecognized enum string
```swift
enum NoteStatus: String, Codable {
    case active, archived, unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = NoteStatus(rawValue: rawValue) ?? .unknown
    }
}
```

### Changed error response
- Update error mapping in repository
- Ensure error is translated to a domain error before reaching ViewModel

---

## Force Update Assessment

After classifying the change, explicitly state:
- **Force update required**: Yes / No / Unknown
- Reason: `<why>`

A force update may be required when:
- A required field is removed and old clients will break without it
- Auth/session flow changes in a breaking way
- A critical security vulnerability is patched

---

## Testing Rule

Every API endpoint must have at least one integration test.
Use shared JSON scenarios — do not inline mock data in test cases.