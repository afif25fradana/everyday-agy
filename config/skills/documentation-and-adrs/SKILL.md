---
name: documentation-and-adrs
description: Author Michael Nygard Architecture Decision Records (docs/adr/) and process runbooks when making significant design decisions.
---

# Architecture Decision Records (ADRs) & Process Documentation

## Overview

Document decisions, not obvious code. The highest-value engineering documentation captures the *why*: the context, technical constraints, and trade-offs that led to an architectural choice. For public README/changelog prose and inline comment hygiene, defer to [`clean-docs`](../clean-docs/SKILL.md) and [`coding-standards`](../coding-standards/SKILL.md).

## When to Activate

- Choosing or replacing a framework, library, runtime, or major dependency
- Designing a data model, database schema, or persistence topology
- Selecting an authentication, cryptography, or security boundary strategy
- Deciding on an API or multi-agent orchestration protocol
- Authoring or refactoring operational runbooks, agent definitions, or skill specifications

**When NOT to Use**: Routine bug fixes, localized single-module edits, or obvious code comments.

---

## 1. Architecture Decision Records (ADRs)

### Convention Discovery (Layout & Lifecycle Model)

Before creating or updating an ADR, inspect `docs/adr/`, `docs/adr/README.md`, and CI checks (such as `.github/workflows/ci.yml`) via `rtk rg` or `read_file` / `view_file` to match both the layout and lifecycle convention:

1. **Storage Layout**:
   - **Twin-Repo Architecture (`<Project>-AI-Context/`)**: Store ADRs in `<Project>-AI-Context/docs/adr/NNNN-<slug>.md` and index them in `<Project>-AI-Context/architecture.md` or `docs/adr/README.md`.
   - **Single-Repo Architecture**: Store ADRs in `docs/adr/NNNN-<slug>.md` (or `docs/decisions/`) and update `docs/adr/README.md` (and `README.md` if cataloged there) to preserve two-way CI index validation.
2. **Lifecycle Model**:
   - **Living Domain ADRs (primary in `everyday-agy`, bounded to `5-8` domain files)**: Maintain one `Accepted` ADR per architectural domain. Update the matching domain ADR in place when decisions evolve, refresh `## Date`, update `docs/adr/README.md` if titles or dates change, and rely on `rtk git log` as the historical ledger. Create a new `NNNN-<slug>.md` only for a distinct domain within the repository's bound.
   - **Append-Only ADRs (Twin-Repo or immutable ledgers)**: Keep historical ADR files intact, write a new sequential `NNNN-<slug>.md` when decisions change, and mark prior records `Superseded by ADR-NNNN` in `## Status`.

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

- **Living Domain Lifecycle** (primary in `everyday-agy`):
  ```
  PROPOSED -> ACCEPTED -> UPDATED IN PLACE (refresh ## Date; Git log holds superseded revisions)
  ```
  Keep domain files bounded (`5-8` files here). Edit the active domain file in place and refresh `## Date` when architecture evolves; retire or fold a file only when its domain is removed or merged. Use `rtk git log` to inspect historical superseded diffs.
- **Append-Only Lifecycle** (Twin-Repo / traditional immutable ledgers):
  ```
  PROPOSED -> ACCEPTED -> (SUPERSEDED or PARTIALLY SUPERSEDED by ADR-NNNN)
  ```
  Preserve historical ADR files when the target repository uses append-only records; write a new sequential ADR and update the prior ADR's `## Status` and `docs/adr/README.md`.
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

- [ ] Active repo convention followed: Living Domain updates refresh `## Date` in place within repo bounds (`5-8` files in `everyday-agy`), OR Append-Only additions use the next sequential `NNNN-<slug>.md` and update `## Status` on superseded ADRs
- [ ] Two-way index parity verified in `docs/adr/README.md` (unique `[ADR-NNNN](./NNNN-<slug>.md)` links matching disk files 1:1, plus root `README.md` if cataloged)
- [ ] External API/tool claims verified via Context7 MCP, official docs, or repository code
- [ ] Sanitized via [`clean-docs`](../clean-docs/SKILL.md) (zero generic AI buzzwords, zero unmasked credentials)

**Stop Condition**: Present the drafted ADR or documentation update in a UserFacing Artifact (or scratch dossier when running as a subagent) and await explicit operator approval before committing.
