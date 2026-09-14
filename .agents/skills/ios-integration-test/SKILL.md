---
name: ios-integration-test
description: Write integration tests for API endpoints, repositories, and SwiftData.
---

# Skill — iOS Integration Testing

## Purpose
Write integration tests covering ViewModel + repository + mocked API end-to-end flows.

---

## Load
- `skills/shared-json-scenarios/SKILL.md`
- `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read
- `rules/api-contract-rules.md`

---

## Execute
- **Coverage per API endpoint**: Success (2xx), 4xx client error, 5xx server error, malformed payload, timeout, unknown enum fallback.
- **Shared Scenarios**: Use shared JSON scenarios from `sharedContracts/test-scenarios/` — **never inline mock response data**.
- **Layer assertions**: Assert `expected.ui` when endpoint is consumed by ViewModel; assert `expected.domain` when consumed only by repo/use case.
- **Mocking**: Use `URLProtocol` subclass to mock URLSession network traffic.
- **Persistence**: Use in-memory `ModelConfiguration` for SwiftData integration tests.

---

## Done When
- At least one integration test per changed API endpoint
- All error paths covered (4xx, 5xx, timeout, malformed, unknown enum)
- Shared JSON scenarios used
- Tests pass
