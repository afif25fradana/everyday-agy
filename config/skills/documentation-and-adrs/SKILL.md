---
name: documentation-and-adrs
description: Author Michael Nygard Architecture Decision Records (docs/adr/) and process runbooks when making significant design decisions.
---

# Architecture Decision Records (ADRs) & Process Documentation

## Overview

Document decisions, not obvious code. The highest-value engineering documentation captures the *why* — the context, technical constraints, and trade-offs that led to an architectural choice. For public README/changelog prose and inline comment hygiene, defer to [`clean-docs`](../clean-docs/SKILL.md) and [`coding-standards`](../coding-standards/SKILL.md).

## When to Activate

- Choosing or replacing a framework, library, runtime, or major dependency
- Designing a data model, database schema, or persistence topology
- Selecting an authentication, cryptography, or security boundary strategy
- Deciding on an API or multi-agent orchestration protocol
- Authoring or refactoring operational runbooks, agent definitions, or skill specifications

**When NOT to Use**: Routine bug fixes, localized single-module edits, or obvious code comments.

---

## 1. Architecture Decision Records (ADRs)

### Convention Discovery (Twin-Repo vs. Single-Repo)

Before creating an ADR, inspect the project layout (`rtk rg` or `read_file` / `view_file`) and follow the established convention:

1. **Twin-Repo Architecture (`<Project>-AI-Context/`)**:
   - Store ADRs in `<Project>-AI-Context/docs/adr/NNNN-<slug>.md` and index them in `<Project>-AI-Context/architecture.md` or `docs/adr/README.md`.
2. **Single-Repo Architecture**:
   - Store ADRs in `docs/adr/NNNN-<slug>.md` (or `docs/decisions/`) and update `docs/adr/README.md` (and `README.md` if indexed there) to preserve two-way CI index validation.

If available evidence conflicts, surface the discrepancy in chat rather than introducing a parallel numbering scheme.

### ADR Template (Michael Nygard Standard)

```markdown
# ADR-0001: Decoupled Local Inference via OpenAI-Compatible HTTP Backend

## Status
Accepted

## Date
2026-10-18

## Context
<Explain the problem, technical constraints, operating systems, dependency sizes, and why a decision is necessary.>

## Decision
<State the chosen architecture, component responsibilities, and protocols adopted.>

## Alternatives Considered & Rejected
- **<Option A>**: <Reason for rejection, e.g. dependency bloat, fragile compilation, or licensing>
- **<Option B>**: <Reason for rejection, e.g. lack of concurrency support or security risks>

## Consequences
- **Positive**: <Concrete benefits: performance, decoupling, token savings, safety>
- **Negative / Operational Requirements**: <Trade-offs, maintenance constraints, or runtime requirements>
```

> [!TIP]
> When evaluating external libraries or third-party APIs during ADR drafting, use Context7 MCP (`resolve-library-id` -> `query-docs`) or [`deep-web-research`](../deep-web-research/SKILL.md) to verify official constraints and licensing rather than relying on pre-training memory.

### ADR Lifecycle & Relationship with `task_state.md`

```
PROPOSED -> ACCEPTED -> (SUPERSEDED or PARTIALLY SUPERSEDED by ADR-NNNN)
```

- **Immutability of Historical ADRs**: Never delete old ADRs. When a decision evolves, write a new ADR that supersedes the prior one and update the prior ADR's `## Status` and `docs/adr/README.md`.
- **ADR vs. `task_state.md`**:
  - **ADR (`docs/adr/`)**: Permanent engineering rationale (*"Why was this designed this way?"*).
  - **Task State (`task_state.md`)**: Ephemeral active task progress (*"What are we building right now?"*, $\le 8$ KB / 100 lines per [`sync-task-state`](../sync-task-state/SKILL.md)).
  - When a tactical gotcha in `task_state.md` triggers an architectural decision, promote it to an ADR and link to it from `task_state.md`.

---

## 2. Process Documentation: Match Form to Failure

When authoring operational runbooks, custom subagents (`config/agents/*/agent.md`), or skills (`config/skills/*/SKILL.md`):

1. **Output Shaping Failures** (verbose narrative or unstructured responses):
   - Provide a **positive structural recipe** defining what the output *is* (order, headings, slots). Never rely on prohibition lists (*"don't restate"*), which invite prompt negotiation.
2. **Discipline & Rule Violations Under Pressure** (skipping steps or cutting corners):
   - Use **explicit prohibitions + anti-rationalization tables + red flags**. Avoid soft guidance (*"prefer"*, *"consider"*) that collapses under pressure.
3. **Omission of Required Elements**:
   - Use **explicit uppercase schema slots** (e.g. `<OBJECTIVE>`, `<SCOPE>`, `<DELIVERABLE>`) instead of prose reminders.
4. **Zero Nuance Clauses**:
   - Never append escape clauses (*"Don't X unless Y"*). Nuance clauses reopen behavioral bargaining.

---

## 3. Verification Checklist & Stop Condition

Before finalizing an ADR or runbook update:

- [ ] Sequential ADR number (`NNNN-<slug>.md`) matches the next available index in `docs/adr/`
- [ ] Two-way index parity verified in `docs/adr/README.md` (and root `README.md` if cataloged)
- [ ] All superseded ADRs have updated `## Status` headers
- [ ] External API/tool claims verified via Context7 MCP, official docs, or repository code
- [ ] Sanitized via [`clean-docs`](../clean-docs/SKILL.md) (zero generic AI buzzwords, zero unmasked credentials)

**Stop Condition**: Present the drafted ADR or documentation update in a UserFacing Artifact (or scratch dossier when running as a subagent) and await explicit operator approval before committing.
