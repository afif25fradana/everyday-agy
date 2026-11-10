---
name: audit-dev
description: "Defensive developer audit standard (/audit-dev): caller tracing, pre-flight hazard analysis, and Five-Axis verification."
---

# Defensive Developer Audit Standard (Skeptical Review Rubric)

An evidence-anchored, skeptical code quality and review rubric for developers, auditors, and review subagents. Governed by `config/GEMINI.md` (`~/.gemini/GEMINI.md`), [`orchestrator`](../orchestrator/SKILL.md), and [`ADR-0028`](../../../docs/adr/0028-orchestrator-consolidation-audit-dev-streamlining-and-dual-subagent-pipeline.md).

> [!TIP]
> **Workflow vs. Audit Separation**: `orchestrator` is the operational runbook governing the execution lifecycle (triage, checkpoints, subagents, and gate packaging). `audit-dev` provides the authoritative quality criteria, skeptical inquiry doctrine, and Five-Axis Review Rubric applied during diagnostic audits and pre-flight diff reviews.

---

## 1. Two-Stage Spec-First Review Process

All diff audits (conducted by `code-auditor`, `silent-failure-hunter`, or human reviewers) MUST execute in two distinct stages:

### Stage 1: Specification & Acceptance Compliance
- Verify line-by-line that the proposed or implemented diff matches approved requirements (`gate1_proposal.md`, task description, or issue).
- Immediately flag and reject unapproved scope creep, speculative helper methods, or unintended architectural drift.

### Stage 2: Code Quality & The Five-Axis Rubric ("Skip Style" Directive)
- Reviewers are explicitly instructed to **skip cosmetic formatting, whitespace, or subjective stylistic preferences** (unless violating anti-slop rules).
- Focus 100% of review energy on substantive defects: correctness, security vulnerabilities, over-engineering bloat, silent failures, and test cheats.

---

## 2. The Five-Axis Skeptical Audit Rubric

Every code modification or architectural proposal is evaluated against these five exhaustive axes:

### Axis 1: Correctness & Invariants
- **Boundary Conditions**: Are edge values ($\le 0$, off-by-one, integer overflow, empty collections) handled safely?
- **State Transition Completeness**: Do finite-state machines, lifecycle hooks, or async flows account for cancelled, aborted, or re-entered states?
- **Caller Blast Radius**: Trace all upstream callers (`rtk rg "<symbol>"`) to ensure signature or semantic changes do not break downstream consumers.
- **Async & Concurrency Ordering**: Ensure absence of race conditions, deadlocks, or un-awaited promises.
- **Modern Runtime LTS Floors**: Reject deprecated APIs; enforce non-EOL runtimes (Python 3.12+, Node 20+, Go 1.22+).
- **Preservation of Defensive Logic**: Never remove existing timeouts, retry budgets, null guards, or calibrated thresholds without explicit justification.

### Axis 2: Security & Attack Surface (Concrete Exploitability Proof)
- **Tainted Input Tracing**: Follow untrusted external input (HTTP parameters, CLI arguments, environment variables, webhooks) from source to sink.
- **Anti-False-Positive Exploitability Invariant**: Every security finding MUST document a concrete exploit path or reproducible failure trace. Hypothetical or speculative vulnerabilities with no reachable execution path are rejected.
- **Auth & Access Boundaries**: Ensure authorization checks are performed before state mutation or data access, never after.
- **Secret Scanner Hygiene**: All credentials, API keys, or tokens in code, diffs, and examples must strictly use bracketed `<...>` placeholders (e.g. `<AUTH_TOKEN>`, `<STRIPE_KEY>`). Scrub test log tokens to `<TEST_HASH_SANITIZED>` or `<MOCK_TOKEN>`.

### Axis 3: Over-Engineering / Ponytail YAGNI & Anti-Slop
- **Shortest Working Diff Wins**: Reject speculative abstractions, premature generalizations, configurable factories with a single implementation, and unused interfaces.
- **Standard Library & Existing Helper Reuse**: Grep for existing utility functions before authoring new helpers.
- **Anti-Slop Comment Hygiene**: Strip obvious, generic AI comments (e.g. `// calculate sum`, `// return result`). Retain only non-obvious *why* rationale, hardware quirks, or algorithmic edge cases per [`clean-docs`](../clean-docs/SKILL.md).

### Axis 4: Edge Cases, Silent Failures & Resource Leaks
- **Zero Swallowed Exceptions**: Strictly ban empty catch blocks (`catch {}`), unlogged errors, and catch-all handlers that mask fatal bugs.
- **No Masking Fallback Defaults**: Ban patterns that return empty arrays or fallback objects on unexpected network/database errors (e.g. `.catch(() => [])`), masking operational failures as empty states.
- **Resource Lifecycle Guarantees**: Ensure all opened file handles, sockets, database transactions, listeners, and child processes are deterministically closed across both happy and early-return/error paths (`try...finally`, `using`, `defer`).
- **Fail-Loud Errors**: Unrecoverable invariants must crash or throw immediately with descriptive context.

### Axis 5: Test Integrity, Anti-Mock Cheating & Fault Injection
- **Anti-Mock Cheating**:
  - Never mock the unit under test.
  - Ban tests that assert only `mock.called` or `mock.toHaveBeenCalled()` without asserting state mutations, return values, or side effects.
  - Reject tests with tautological assertions (e.g. `assert x == x`).
- **Dual Path Coverage**: Every feature or bug fix must verify both the happy path and negative/error paths.
- **Condition-Flipping Fault Injection**: When evaluating test rigor, mentally or temporarily flip an implementation condition (e.g. `>` to `<` or `true` to `false`); if tests continue to pass, the test suite is cheating or incomplete.

---

## 3. Skeptical Dispute & Verification Rules

### 3.1 Planning Anti-False-Positive Rule
During diagnostic audits and Gate 1 planning:
- Auditors and planners are strictly prohibited from asserting that code is broken without checkable evidence.
- Every claimed defect must cite exact code coordinates (`file.ext#Lxx-Lyy`), reproduction commands, or caller blast radius numbers verified via `rtk rg`.

### 3.2 The 4-Bucket Resolution Taxonomy
When reviewing findings or responding to review inquiries, classify every finding into exactly one bucket:
- **`CONTEST`**: Finding is factually incorrect; must cite verified code coordinates (`file.ext#Lxx-Lyy`).
- **`ESCALATE`**: Finding relies on unwritten conventions or out-of-band context not present in the codebase.
- **`PROPOSE FIX`**: Finding is valid; provide the minimal Ponytail textual fix.
- **`DECLINE`**: Finding is a cosmetic Nit with zero functional or security risk; record as an accepted trade-off.

*Full specification and response templates are governed by [`orchestrator/references/handoff-spec.md#62-the-4-bucket-resolution-taxonomy`](../orchestrator/references/handoff-spec.md#62-the-4-bucket-resolution-taxonomy).*

### 3.3 Factual Code Dispute Format
Any factual dispute must cite exact lines and reproduction commands using the canonical schema in [`orchestrator/references/handoff-spec.md#64-factual-code-dispute-format-responding-to-questions-for-implementer`](../orchestrator/references/handoff-spec.md#64-factual-code-dispute-format-responding-to-questions-for-implementer).

### 3.4 Failed Reviewer Accounting Invariant
- Any delegated reviewer or subagent that times out, encounters an unhandled tool exception, or fails to complete execution MUST be accounted as `Status: not run`.
- It is strictly prohibited to treat a failed or aborted reviewer run as "0 findings" or an implicit pass. Any required reviewer with `not run` status invalidates approval.

### 3.5 Settled Findings Immunity
- Review findings that have been formally settled (contested with verified code coordinates or accepted as documented operator trade-offs) are immune to re-litigation by subsequent review passes or subagent dispatches.
- Settled findings must be passed under `Settled Findings:` in `<SCOPE>` (strictly restricted to previously contested-with-evidence or operator-accepted items, never unreviewed assumptions) to prevent endless review churn.

---

## 4. Engineering Pitfalls & Companion References

- **Engineering Pitfalls Checklist**: Consult [`references/pitfalls.md`](./references/pitfalls.md) for 20 empirical traps across Agentic Engineering (1–7), Logic & Implementation (8–16), and Platform & Shell (17–20).
- **Execution Runbook**: Consult [`orchestrator/SKILL.md`](../orchestrator/SKILL.md) for the end-to-end development lifecycle, zero-read triage, checkpoints, and Gate 1/2 handoffs.
- **Documentation Standards**: Consult [`clean-docs/SKILL.md`](../clean-docs/SKILL.md) for plain-spoken documentation and commit message hygiene.
