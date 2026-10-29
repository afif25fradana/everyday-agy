# ADR-0014: Superpowers Heuristics Distillation and Platform Adaptation

## Status
Accepted

## Date
2026-10-30

## Context
Following an exhaustive Council Review deliberation of `obra/superpowers` (v7.0.1) documented in `council_evaluation_report.md`, direct monolithic installation of the external plugin was strictly vetoed. Superpowers relies on POSIX shell scripts (`.sh`), physical git worktrees (prone to `EPERM` file-locking crashes and disk exhaustion on Windows PowerShell hosts), greedy "1% chance" bootstrap directives that bloat context by ~160KB (~40,000 tokens), and unapproved autonomous execution loops that violate mandatory human safety gates (`<RULE[user_global]>` Rule 2).

However, Superpowers incorporates industry-leading behavioral heuristics that substantially reduce LLM rationalization, confirmation bias, and superficial verification shortcuts. Rather than discarding these insights or importing runtime bloat, this decision surgically distills its highest-value heuristics into the user's existing, spec-compliant Antigravity skills.

## Decision
1. **Harden TDD & Test Integrity (`tdd-guide`)**:
   - Embed the Iron Law of TDD ("Delete means delete"): if production code is written before observing a failing test, delete the implementation immediately.
   - Embed a compact 5-point Anti-Rationalization Guardrails matrix to prevent shortcut rationalizations.
   - Add the Mutation Check heuristic under the De-Sloppify pass (mentally or temporarily mutating code to ensure at least one test fails per mutation).
   - Retain `model: flash` strictly to preserve cognitive tiering and token efficiency (ADR-0004, ADR-0012).

2. **Upgrade Audit-Dev-Workflow (`audit-dev-workflow`)**:
   - In Phase 1: Incorporate multi-layer boundary logging, backward call-stack tracing, and Failure-First Verification (RED) ensuring tests fail for the intended assertion, not syntax/import errors.
   - Clean legacy subagent references: Replace `TypeName: "research"`, `TypeName: "self"`, and `Workspace: branch` with custom specialist subagents (`system-architect`, `code-auditor`, `tdd-guide`) and atomic Git Checkpoints (`New-AuditCheckpoint.ps1` -> `checkpoint-<task>`). Reserve `teamwork` strictly for Tier 3 deliberative Council.
   - In Review Return Loop: Codify an Anti-Sycophancy rule banning performative praise (`"You're absolutely right!"`, `"Great point!"`) and requiring technical verification against caller topology and Ponytail YAGNI.
   - In Phase 4: Enforce project-wide test runner execution (`rtk npm test`, `rtk python -m pytest`) to catch regressions, while strictly preserving the static verification fallback (`[TEST HARNESS: NONE — STATIC/BUILD EVIDENCE PROVIDED]`) for testless repositories (ADR-0007).
   - Codify the 2-attempt architectural circuit breaker harmonized with `GEMINI.md#L45`.

3. **Enhance Specification & Planning (`spec-kit`)**:
   - In Phase 1 (`/speckit.specify`): Enforce Socratic 1-question discipline, 1–3 line scope and constraint discovery (strictly zero prompt restating per `GEMINI.md#L35`), and the Design Gate.
   - In Phase 2 (`/speckit.plan`): Add Section 5 "Review Focus" requiring the top 5 implied edge cases to be mapped directly to atomic test tasks.

4. **Refine Standards & Documentation (`clean-docs`, `coding-standards`, `documentation-and-adrs`)**:
   - In `clean-docs`: Ban performative review praise across commit messages and review dialogs.
   - In `coding-standards`: Add the canonical deterministic `waitFor` polling helper to eliminate flaky `setTimeout` / `sleep` in async tests.
   - In `documentation-and-adrs`: Codify the "Match Form to Failure" prompt engineering principle (structural positive recipes for output shaping, prohibitions + rationalization tables for discipline failures, uppercase schema slots for required fields, zero nuance clauses).

5. **Enforce Deployment Parity**:
   - Apply all modifications within `D:\Github\everyday-agy\` repository working tree.
   - Run `restore.ps1` to deploy clean changes into `~/.gemini/config/`.

## Consequences
- **Positive**:
  - Eliminates confirmation bias and LLM shortcuts without increasing system prompt token bloat.
  - 100% native compatibility with Windows PowerShell 5.1 / pwsh 7.6; zero file-locking crashes.
  - Cleans legacy references to `research` and physical worktrees across workflow documentation.
  - Retains human oversight and blast-radius tiering intact.
- **Negative / Neutral**:
  - Slightly more rigorous test requirements for complex changes, requiring full suite runs when automated test harnesses are present.
