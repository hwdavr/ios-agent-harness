# iOS Agent Harness

> A battle-tested development, execution, and evaluation harness for AI coding agents to build, verify, and maintain production-grade iOS applications safely, deterministically, and with high code quality.

---

## 🎯 Overview

Modern AI coding agents (such as Google Antigravity, Claude Code, OpenAI Codex, Cursor, Windsurf, and Copilot) possess strong code generation capabilities but can easily deviate into architecture violations, bloated context windows, untested edge cases, and hallucinations when unconstrained.

This repository provides an **Agent Harness** designed to:
- **Raise the Quality Floor**: Mandate strict architecture layers (Data, Domain, UI), SwiftUI best practices, unidirectional state flow, and comprehensive test coverage (unit, integration, UI).
- **Lower the Blast Radius**: Enforce incremental vertical slices, strict stage gates, and deterministic quality checks before code lands.
- **Optimize Context Efficiency**: Use a 3-tier layered context loading protocol (L1 / L2 / L3) to keep context windows under 40% fill.
- **Separate Agent Roles**: Distinct execution modes for **Planner**, **Coder / Generator**, and **Evaluator**.

---

## 🚀 Setting Up the Harness in Your iOS Project

### Initialize the complete harness

After cloning the submodule, run this from the iOS project root:

```bash
bash .harness/harness/scripts/init-harness.sh
```

The initializer validates harness lifecycle state and runs the full source-rule checks.

It creates the `.agents` and `harness` root symlinks and copies `AGENTS.md` to the project root if
it is absent (an existing project-specific version is kept). It then checks the project-owned
documentation baseline: `docs/product/product.md` and `docs/product/design_system.md`. If either
is missing, it prints instructions. The design system is not generated automatically; use the
`ux-design` skill to draft it from product requirements and obtain approval before UI work.

On macOS it also creates `~/Library/LaunchAgents/com.ios.<project-name>.harness-generator.plist`
from the template, with a project-specific launchd label and log name. The script prints the
explicit `launchctl load` command; it does not schedule the job automatically.

`docs/product/journey-registry.yaml` is not required for initial setup. It becomes required when a
feature declares a production journey; the generator then registers it and verification runs
`bash harness/scripts/check-journey-registry.sh --run-all`.

### 1. Add as a Git Submodule

From your iOS project root:

```bash
git submodule add -b main git@github.com:hwdavr/ios-agent-harness.git .harness
```

### 2. Create Root Symlinks (handled by the initializer)

The initializer creates `.agents` and `harness` symlinks automatically. It stops with a clear
message if either path already exists as a real file or directory.

### 3. Copy `AGENTS.md` to Project Root (handled by the initializer)

The initializer copies `.harness/AGENTS.md` to the project root on first setup. If the project
already has an `AGENTS.md`, it preserves that project-specific file.

---

## 🧠 Context Management Protocol (L1 / L2 / L3)

To prevent LLM performance degradation and context dilution, context is loaded in strict layers:

| Layer | When to Load | Contents |
|---|---|---|
| **L1 — Always Loaded** | Every session start | `AGENTS.md` + `rules/ios-architecture.md` + `rules/implementation-rules.md` + `rules/testing-strategy.md` |
| **L2 — Phase-Triggered** | Per workflow stage | The active stage skill(s), plus the Rule Applicability template and conditional iOS rules during requirements, planning, and review; load `rules/ios-security.md` for security/AI/WKWebView/network/Info.plist boundaries |
| **L3 — On-Demand** | When specifically needed | `docs/knowledge/`, `sharedContracts/openapi.yaml`, feature evidence, and rule detail newly triggered by the approved applicability matrix |

> **Rule:** Never preload all rules and skills upfront. Only load what the active stage requires.

---

## 🔄 Workflows & Execution Pipelines

### Project-Based Development (Complex Features)
Used for multi-slice, significant features requiring systematic requirement analysis and evaluation:

1. **Planning (`.agents/workflows/harness-planning.md`)**
   - Clarifies ambiguities and generates `spec.md` and `design.md`.
   - Decomposes requirements into vertical slices in `feature_list.json` and schedules a `sprint-contract.md`.
2. **Generation (`.agents/workflows/harness-generator.md`)**
   - Implements each vertical slice incrementally (Data → Domain → UI → Tests → Quality Gates).
   - Validates each slice before advancing to the next.
3. **Evaluation (`.agents/workflows/harness-evaluation.md`)**
   - Conducts independent code, test, visual, and architectural reviews against evaluation rubrics.
4. **Fixing (`.agents/workflows/harness-fix.md`)**
   - Resolves any findings if evaluation score is below 5.0/5.

### Ad-Hoc Development (Simple Tasks & Bug Fixes)
- **`feature-delivery.md`**: Direct end-to-end implementation for simple features.
- **`bug-fixing.md`**: Reproduction test first → surgical fix → regression verification.
- **`create-ui-and-verify.md`**: Focused on pixel-perfect SwiftUI styling against design mockups.
- **`feature-review.md`**: Pre-merge independent review checklist.

---

## 🛠️ Automated Scripts & Rule Checkers

The harness includes validation scripts located in `harness/scripts/`:

| Script | Purpose |
|---|---|
| `check-full-source-rules.sh` | Repository-wide bundle: architecture, SwiftUI, localization, navigation, assertion, and AI security rules |
| `check-architecture-rules.sh` | Validates layer boundaries, file imports, and DTO isolation |
| `check-swiftui-rules.sh` | Checks SwiftUI best practices, `accessibilityIdentifier` presence, and statelessness |
| `check-localization-rules.sh` | Detects hardcoded strings in UI views |
| `check-ai-security-rules.sh` | Evaluates AI prompt/credential logging, WebView boundary policies, and HTML sinks |
| `check-feature-lifecycle.sh` | Validates feature tracking state and artifact integrity |
| `check-visual-evidence-contract.sh` | Enforces visual screenshot verification artifacts |
| `check-evaluation-fix-contract.sh` | Enforces deterministic evaluator scoring, evidence, and fix-stage routing |
| `check-test-assertions-quality.sh` | Ensures tests do not use shallow/envelope-only assertions |
| `check-rules-matrix-contract.sh` | Validates enforcement-matrix rows, summaries, and scripted owners |

Run any check directly from your project root:
```bash
bash harness/scripts/check-full-source-rules.sh
bash harness/scripts/check-architecture-rules.sh
bash harness/scripts/check-swiftui-rules.sh
bash harness/scripts/check-localization-rules.sh
bash harness/scripts/check-rules-matrix-contract.sh
bash harness/scripts/check-evaluation-fix-contract.sh <feature-dir> --evaluation
```

The full-source bundle is the required entry point for generator, evaluator, fix,
and CI quality gates. It forces `--all` scans for the architecture, SwiftUI, and
localization checkers and still runs the remaining checkers after an earlier failure.

The authoritative conditional iOS security baseline is
`.agents/rules/ios-security.md`. It governs trust-boundary handling and
evidence; the full-source bundle provides the mechanical AI/WebView enforcement.

---

## 🤖 Agent Tool Compatibility

| Tool | Integration Method |
|---|---|
| **Google Antigravity IDE** | Reads `AGENTS.md` automatically; executes skills natively via IDE tools. |
| **Codex CLI / Claude Code** | Run `codex-harness-generator.sh` or prompt: `"Load context for the project"` to trigger `context-management`. |
| **Cursor / Windsurf** | Add `AGENTS.md` and `.agents/rules/` to `.cursorrules` / `.windsurfrules` or project context. |
| **GitHub Copilot Chat** | Reference `@workspace AGENTS.md` when initiating a development task. |

---

## 📚 References & Resources

- **Medium Article:** [Harness Engineering: How to Set Up an iOS Agent Harness](https://weidianhuang.medium.com/harness-engineering-how-to-set-up-an-android-agent-harness-b7154d9e3471)
- **Reference Application:** [NotesTakingAppiOS](https://github.com/weidianhuang/NotesTakingAppiOS)
