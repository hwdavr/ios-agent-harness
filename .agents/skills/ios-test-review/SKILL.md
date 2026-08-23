---
name: ios-test-review
description: Reviews test quality: coverage, assertions, test isolation, and scenario reuse.
---

# Skill — iOS Test Review

## Purpose
Review test quality independently from the code review: coverage targets, assertion quality, test isolation, and scenario reuse.

---

## Load
- `rules/testing-strategy.md`
- `skills/shared-json-scenarios/SKILL.md`

---

## Execute

### Coverage Review
- [ ] Overall project ≥ 80% line coverage (`xccov`)
- [ ] New ViewModel classes ≥ 90%
- [ ] New domain use case classes ≥ 90%
- [ ] SwiftUI Views excluded from coverage (correct)

### Test Quality Review
- [ ] AAA pattern followed
- [ ] One assertion per concept — no bundled assertions
- [ ] No envelope-only assertions (verify semantic content, not `contains("<svg")`)
- [ ] Tests are isolated — no shared state between tests
- [ ] DAMP over DRY — tests tell self-contained stories
- [ ] Real objects preferred over mocks (mock only boundaries)
- [ ] No `sleep()` in tests — proper expectations used

### Integration Test Review
- [ ] At least one integration test per API endpoint
- [ ] Shared JSON scenarios used — no inline mock data
- [ ] All error paths covered (4xx, 5xx, timeout, malformed)
- [ ] Unknown enum values tested

### Bug Fix Review
- [ ] Reproduction test added and fails before fix
- [ ] Reproduction test passes after fix
- [ ] No unrelated file changes

---

## Output
Test review findings with severity.
Coverage report snapshot with actual percentages.