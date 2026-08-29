---
name: api-contract-update
description: Handles end-to-end delivery of a backend API contract change — from impact analysis through data/domain/UI layers, testing, code quality, and optional knowledge capture.
---

# Skill — API Contract Update

## Purpose
Drive a complete API contract change end-to-end. Covers DTO updates, domain mapping, optional UI changes, integration tests with shared JSON scenarios, and code quality checks.

Use this skill when:
- A backend API changes its request or response contract.

---

## Scope

Determine scope before running any stage:

| Scope | Stages to run |
|-------|--------------|
| **Full** (contract + repo + UI + tests) | All stages (1 → 2 → 3 → 4 → 5 → 6 → 7 → 8) |
| **Data & Domain only** (no UI changes) | 1 → 2 → 3 → 4 → 6 → 7 (lightweight). Skip 5, 8. |

---

## Load
- `rules/ios-architecture.md`
- `rules/implementation-rules.md`
- `rules/testing-strategy.md`
- `rules/api-contract-rules.md`
- `harness/templates/rule-applicability-template.md`
- `docs/current/implementation_plan_v<N>.md` (once generated in Stage 2)

---

## Execute

### Stage 1 — Requirement, Impact & Design Analysis ✅ Always
**INVOKE** the `requirement-analysis` skill via the Skill tool (name: `requirement-analysis`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Adapt the skill output to cover:
- API impact classification (additive, breaking, partial)
- DTO and Domain model changes required
- Identify which layers are affected (data, domain, UI)
- The complete Rule Applicability matrix. API is `Required` for this workflow; every
  other rule still needs an explicit decision and evidence plan.

Run `bash harness/scripts/check-stage-artifacts.sh api-contract-update requirement-analysis` — must exit 0 before proceeding.

---

### Stage 2 — Implementation Plan ⛔ STOP ✅ Always
**INVOKE** the `implementation-plan` skill via the Skill tool (name: `implementation-plan`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Run `bash harness/scripts/check-stage-artifacts.sh api-contract-update implementation-plan` — must exit 0.

**Stop and present the plan. Do not proceed until the user explicitly approves.**

---

### Stage 3 — Data Layer ✅ Always
**INVOKE** the `ios-data-layer` skill via the Skill tool (name: `ios-data-layer`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

---

### Stage 4 — Domain Layer ✅ Always
**INVOKE** the `ios-domain-layer` skill via the Skill tool (name: `ios-domain-layer`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

---

### Stage 5 — UI Layer ⏭️ Skip if no UI changes
**INVOKE** the `ios-ui-layer` skill via the Skill tool (name: `ios-ui-layer`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Only run this stage if the contract change surfaces in the UI (new fields displayed, new screens, changed error states).

---

### Stage 6 — Testing ✅ Always
**INVOKE** the `ios-testing` skill via the Skill tool (name: `ios-testing`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Mandatory: at least one integration test per changed API endpoint using shared JSON scenarios. See `testing-strategy.md`.

---

### Stage 7 — Code Quality Fix ⚠️ Lightweight if Data & Domain only
**INVOKE** the `code-quality-fix` skill via the Skill tool (name: `code-quality-fix`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Scope guidance:
- Always run SwiftLint and applicable harness rule checks.
- Skip UI-related scripts or rules if Stage 5 was skipped.

---

### Stage 8 — Knowledge Capture ⏭️ Skip unless change is non-obvious
**INVOKE** the `knowledge-capture` skill via the Skill tool (name: `knowledge-capture`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Only run if the contract change involves a tricky mapping, a breaking change, a non-standard pattern, or a decision future agents need to understand.

---

## Output

- Updated `sharedContracts/openapi.yaml`
- Updated DTOs, mappers, SwiftData entities/DAOs (if affected)
- Updated domain models and use cases (if affected)
- Updated SwiftUI screens/ViewModels (if UI scope)
- Integration tests for every changed endpoint using shared JSON scenarios
- `docs/current/coding_report_v<N>.md` updated through each stage
- `docs/current/summary_v<N>.md` with all completed stages marked

---

## Done When

**All of the following must be true:**
- [ ] `sharedContracts/openapi.yaml` reflects the new contract
- [ ] No DTOs referenced outside the data layer
- [ ] All changed API endpoints have at least one integration test using shared JSON scenarios
- [ ] SwiftLint and applicable harness checks pass with zero new violations
- [ ] Build passes: `xcodebuild -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' build`
- [ ] Unit + integration tests pass: `xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16'`
- [ ] `summary_v<N>.md` marks all executed stages as complete with artifact references

**APPROVED →** This skill is complete. Return control to the caller or close the task.
