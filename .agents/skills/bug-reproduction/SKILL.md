---
name: bug-reproduction
description: Reproduce a bug with a failing test before fixing it.
---

# Skill — Bug Reproduction (TDD)

## Purpose

Prove the root cause is correct by writing a **failing test** that mechanically reproduces the bug.
The test must turn RED before any fix is written.
This is the gate that separates "we believe we found it" from "we have proven it".

Do not implement any fix in this stage.

---

## Load

Load `docs/current/spec_v<N>.md` first. `rules/testing-strategy.md` is auto-loaded as a system rule — do not re-read. After
selecting the lowest sufficient reproduction layer, load only its guidance:

- `skills/ios-unit-test/SKILL.md` for a unit or integration reproduction
- `skills/ios-ui-test/SKILL.md` for a visual, navigation, or runtime reproduction
- `skills/shared-json-scenarios/SKILL.md` only when an API response is part of the root cause

---

## Execute

### 1. Select the reproduction test layer

Pick the **lowest** layer that is sufficient to reproduce the bug (per `testing-strategy.md`, already loaded):

| Bug type | Preferred layer |
|---|---|
| Logic / calculation error | Unit test (`NotesTakingAppiOSTests/`) |
| Data-flow / API mapping / error state | Integration test (`NotesTakingAppiOSTests/`) |
| Visual glitch / unresponsive element | Instrumented UI test (`NotesTakingAppiOSUITests/`) |
| Navigation crash / deep-link issue | Instrumented UI test (`NotesTakingAppiOSUITests/`) |

### 2. Write the reproduction test — RED phase

Write a failing test that reproduces the defect before attempting a fix:

1. **Write the test first**: Do not write the fix first. Do not touch application code.
2. **Name the test descriptively**: Pattern: `"given <precondition>, when <action>, then <expected outcome>"`
3. **Write the minimal test** that targets the root cause statement in `spec_v<N>.md`.
4. **Do not write the fix**. Do not adjust application code to make the test pass.
5. **Use shared JSON scenarios** if an API response is involved — do not inline mock data.
6. **Add `@Test(.disabled("BUG: <short description> — remove when fixed"))`** if the test would block CI before the fix lands; remove the annotation in the Implementation stage.

### 3. Run the test — confirm RED

```bash
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:NotesTakingAppiOSTests/<TestClassName>/<testMethodName>
```

or for UI tests:

```bash
xcodebuild test -project NotesTakingAppiOS.xcodeproj -scheme NotesTakingAppiOS -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:NotesTakingAppiOSUITests/<TestClassName>/<testMethodName>
```

**The test must fail.** A test that passes immediately means one of:
- The bug is already fixed (re-examine the root cause)
- The test is not actually reproducing the bug (fix the test)

Do not advance until you have observed a RED result.

---

## Output

The new (failing) reproduction test file, committed with `@Ignore` if needed.

Append to `docs/current/spec_v<N>.md`:

```
## Reproduction Test

- File: `<relative path to test file>`
- Class: `<TestClassName>`
- Test name: `<test function name>`
- Layer: Unit | Integration | Instrumented UI
- Run result: FAILED ✓ (expected — bug confirmed)
- Failure message: <paste the key assertion failure line>
```

Update `summary_v<N>.md`: mark this stage complete.

---

## Done When

**This stage is complete when all of the following are true — all must be mechanically verifiable:**

- [ ] A reproduction test exists that targets the root cause statement in `spec_v<N>.md`
- [ ] `./gradlew xcodebuild test` (or `xcodebuild test`) exits **non-zero** for the new test, confirming RED
- [ ] The failure message matches the root cause — not a compilation error or unrelated assertion
- [ ] No application source code has been modified in this stage
- [ ] `spec_v<N>.md` is updated with the Reproduction Test section

**APPROVED →** Return to the active workflow file and proceed to the Fix Plan stage.
