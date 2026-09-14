---
name: ios-unit-test
description: Write Swift Testing unit tests for ViewModels, use cases, and mappers.
---

# Skill — iOS Unit Testing

## Purpose
Write unit tests for ViewModels, use cases, and mapper logic using Swift Testing framework.

---

## Load
- `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read

---

## Execute
- **Scope**: ViewModel state transitions, domain use case logic, mappers (DTO → Domain, Domain → UI), formatting/fallback.
- **Framework**: Swift Testing (`@Test func`, `#expect(...)`, `#require(...)`).
- **Naming**: File ends with `Tests`, test functions use descriptive Given/When/Then names.
- **Conventions**: Follow AAA pattern, test public API, one main scenario per test. Prefer real model instances over mocks.

---

## Done When
- All ViewModel state transitions tested
- All use cases tested
- All mappers tested
- Tests pass: `xcodebuild test`
- New classes ≥ 90% coverage
