---
name: api-contract-update
description: Deliver a backend API contract change through data, domain, UI, and verification.
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
| **Full** (contract + repo + UI + tests) | All stages (1 → 2 → 3 → 4 → 5 → 6) |
| **Data & Domain only** (no UI changes) | 1 → 2 → 3 → 4 → 5 (lightweight). Skip UI in stage 3, skip 6. |

---

## Load
- `rules/ios-architecture.md` (skip if already loaded this session — L1 is session-scoped)
- `rules/implementation-rules.md` (skip if already loaded this session)
- `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read
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

### Stage 3 — Implementation (Data + Domain + UI) ✅ Always
**INVOKE** the `ios-implementation` skill via the Skill tool (name: `ios-implementation`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Implement affected layers sequentially:
1. Update `sharedContracts/openapi.yaml` first if contract changed.
2. Implement DTOs and Data Layer.
3. Implement Domain models, repository protocol, and use cases.
4. Implement UI layer (ViewModel, View) only if contract change surfaces in UI.

---

### Stage 4 — Testing ✅ Always
**INVOKE** the `ios-testing` skill via the Skill tool (name: `ios-testing`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Mandatory: at least one integration test per changed API endpoint using shared JSON scenarios. See `testing-strategy.md`.

---

### Stage 5 — Code Quality Fix ⚠️ Lightweight if Data & Domain only
**INVOKE** the `code-quality-fix` skill via the Skill tool (name: `code-quality-fix`). Reading the SKILL.md manually is not a substitute — the Skill tool is the required mechanism.

Scope guidance:
- Always run SwiftLint and applicable harness rule checks.
- Skip UI-related scripts or rules if UI was not modified.

---

### Stage 6 — Knowledge Capture ⏭️ Skip unless change is non-obvious
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
