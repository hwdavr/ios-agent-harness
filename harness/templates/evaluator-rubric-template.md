# Evaluator Rubric

Use this rubric after implementation and before final acceptance.

| Category | Question | Score (0-5) | Notes |
| --- | --- | --- | --- |
| Correctness | Does the implemented behavior match the requested feature? |  |  |
| Verification | Did the required checks actually run, with evidence? |  |  |
| Scope discipline | Did the session stay inside the chosen feature scope? |  |  |
| Reliability | Does the result survive restart or rerun without repair? |  |  |
| Maintainability | Is the code and documentation clear enough for the next session? |  |  |
| Handoff readiness | Can a fresh session continue work from repo artifacts only? |  |  |
| Code & Test Review | Do the code quality checks (SwiftLint, custom rules) and comprehensive test reviews pass? |  |  |
| Rule Applicability | Does every approved rule decision have diff-trigger reconciliation and evidence in both review reports? |  |  |

### Overall: 5.0 / 5

### Visual Verification Hard Gate *(when `requires_visual_verification == true`)*

- Dedicated visual verification test exists and captures screenshots via `XCUIScreen.main.screenshot()`: Yes / No / N/A
- `ui_verification.json` present: Yes / No / N/A
- `reference-anchor-verification.md` references visual test methods: Yes / No / N/A
- `check-visual-evidence-contract.sh` exits 0: Yes / No / N/A

If any required answer is `No`, the evaluator MUST score `Verification` below `5.0 / 5` and use `Revise`.

### Rule Applicability Hard Gate

- Complete approved matrix exists in the feature specification: Yes / No
- Code review includes all nine reconciliation rows: Yes / No
- Test review includes all nine reconciliation rows: Yes / No
- Every `Not applicable` / exception decision is supported by the diff and cited approval: Yes / No

If any required answer is `No`, the evaluator MUST use `Revise`.

### Harness File Assessment

| File | Present | Quality | Notes |
|------|---------|---------|-------|
| feature_list.json | Yes | Complete | All features, all pass with evidence |
| progress.md | Yes | Complete | Session log with results |
| session-handoff.md | Yes | Complete | Full handoff with decisions and files modified |
| clean-state-checklist.md | Yes | Complete | Check items across categories |
| evaluator-rubric.md | Yes | Complete | This file |

## Verdict

- Accept
- Revise
- Block

## Required Follow-Up

- Missing evidence:
- Required fixes:
- Next review trigger:
