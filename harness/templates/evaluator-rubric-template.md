# Evaluator Rubric Template

Use this template when producing `evaluator-rubric.md` in the **Harness Evaluation** workflow.

---

## Category Scores

| Category | Evaluation Criteria | Score (0–5) | Notes |
|----------|-------------------|-------------|-------|
| Functional completeness | Are all FRs and acceptance criteria from the spec satisfied? |  |  |
| Verification | Are automated tests passing and evidence attached to every feature? |  |  |
| Architecture adherence | Are layer boundaries, data flow, and state ownership clean? |  |  |
| Reliability | Does the result survive restart or rerun without repair? |  |  |
| Maintainability | Is the code and documentation clear enough for the next session? |  |  |
| Handoff readiness | Can a fresh session continue work from repo artifacts only? |  |  |
| Code & Test Review | Do SwiftLint, the full-source rules bundle, and comprehensive test reviews pass? |  |  |
| Rule Applicability | Does every approved rule decision have diff-trigger reconciliation and evidence in both review reports? |  |  |

### Overall: <arithmetic mean of the eight category scores, rounded to one decimal> / 5

The eight category scores are the machine-checkable source of the overall score. Use
their arithmetic mean, rounded to one decimal place; do not choose an independent
overall score. A perfect 5.0 / 5 requires an Accept verdict and routes the tracker
to To be human reviewed. Any lower score requires Revise or Block and routes the
tracker to To be fixed.

### Platform Hard Gate

- Platform capability matrix present and linked from `feature_list.json`: Yes / No
- Minimum, target, and important API boundaries explicitly tested: Yes / No
- Unsupported environment policy is `fail_loudly`: Yes / No
- Real instrumented platform-boundary test passed: Yes / No / N/A
- Fake-only or unit-only evidence used as the sole platform proof: Yes / No

If any required answer is `No`, the evaluator MUST score the feature below `5.0 / 5` and use `Revise` or `Block`. Missing runtimes, devices, models, locales, permissions, or platform services are failed/blocked evidence, never passing skips.

### Rule Applicability Hard Gate

- All ten rule-applicability rows reconciled against the diff in both review reports: Yes / No
- Every `Required` rule has supporting code/check/test evidence: Yes / No
- No unapproved exception or unhandled diff trigger present: Yes / No
- Analytics/observability evidence matches the approved decision: Yes / No

If any required answer is `No`, the evaluator MUST use `Revise`.

### Visual Verification Hard Gate *(when `requires_visual_verification == true`)*

- Dedicated visual verification test exists and captures screenshots in-test via `XCUIScreen.main.screenshot()`: Yes / No / N/A
- No post-test CLI screencaps (`simctl io booted screenshot` after test exits) in `feature_list.json` verification or evidence commands: Yes / No / N/A
- `ui_verification.json` present and passes `check-ui-verification-artifact.sh`: Yes / No / N/A
- `reference-anchor-verification.md` references visual test methods in Runtime proof column: Yes / No / N/A
- `check-visual-evidence-contract.sh` exits 0: Yes / No / N/A
- Rich-text/inline-formatting appearance claims have source-fed visual evidence and an explicit checked pixel comparison in the named method: Yes / No / N/A

If any required answer is `No`, the evaluator MUST score `Verification` below `5.0 / 5` and use `Revise`. Screenshots from post-test CLI screencaps are invalid evidence because the test process/window may be destroyed before the capture runs.

### Harness File Assessment

| File | Present | Quality | Notes |
|------|---------|---------|-------|
| feature_list.json | Yes | Complete | All features, all pass with evidence |
| progress.md | Yes | Complete | Session log with results |
| session-handoff.md | Yes | Complete | Full handoff with decisions and files modified |
| clean-state-checklist.md | Yes | Complete | 30 check items across 7 categories |
| evaluator-rubric.md | Yes | Complete | This file |

### Evidence Contract

The evaluator's static-quality evidence must include
`bash harness/scripts/check-full-source-rules.sh` (or the Windows `.cmd` launcher),
not only a changed-file checker invocation.

Before changing the tracker status, run:

```bash
bash harness/scripts/check-evaluation-fix-contract.sh "$FEATURE_DIR" --evaluation
```

This hard gate verifies arithmetic score routing, successful non-contradictory
evidence, acceptance-test traceability, and the required review artifacts.

## Verdict

- Accept
- Revise
- Block

### Follow-Up Notes
- Root cause:
- Missing evidence:
- Required fixes:
- Next review trigger:
