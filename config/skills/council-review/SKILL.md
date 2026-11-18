---
name: council-review
description: "Read-only multi-agent teamwork council (/council, /council-review): scored Tier 3 software architecture audits & release gates."
---

# Deliberative Council Review Orchestration (Operational Runbook)

High-rigor, read-only multi-perspective evaluation framework for Tier 3 software engineering reviews. Powered by Antigravity's native multi-agent orchestration engine (`teamwork`).

---

## When to Use & Non-Goals (Tier Routing Boundary)

- **Use `/council` or `/council-review` ONLY for**: Read-only Tier 3 evaluations (`> 5` files, architectural overhauls, cross-cutting security/reliability audits, or pre-release gates) that justify multi-seat adversarial deliberation.
- **Do NOT use (downgrade or redirect immediately)**:
  - **Mutating tasks (edits, fixes, commits)**: Council is strictly read-only. Route to [`orchestrator`](../orchestrator/SKILL.md) (Tier 0/1/2).
  - **Tier 0/1 single-module fixes or Tier 2 scoped changes (`2-5` files)**: Use direct Parent TDD or targeted specialists with [`audit-dev`](../audit-dev/SKILL.md).
  - **PR or git diff reviews**: Route to [`differential-review`](../differential-review/SKILL.md).
  - **Pre-audit invariant mapping only**: Route to [`audit-context-building`](../audit-context-building/SKILL.md).
  - **Academic, finance, or BEI/IDX thesis reviews**: Route to [`academic-council`](../academic-council/SKILL.md).

---

## Mandatory Delegation Protocol (DO NOT BYPASS)

> [!CAUTION]
> **FOR TIER 3 COUNCIL EVALUATIONS, DISPATCH EXCLUSIVELY VIA `teamwork`.**
> Calling individual specialist subagents directly from the Parent session for a Tier 3 Council evaluation bypasses peer deliberation, deduplication, fail-closed adversarial challenge, and victory auditing.
>
> **The Parent Agent MUST dispatch EXACTLY ONE call to `teamwork`:**
>
> ```json
> invoke_subagent(
>   TypeName: "teamwork",
>   Role: "Council Review Panel",
>   Prompt: "Requested team: Council review panel (read-only audit & comparison)\n\n..."
> )
> ```
>
> *Engine Visibility Note*: `teamwork` is an internal runtime subagent omitted from the visible `Available subagents:` list, yet natively recognized by Antigravity. Invoking `TypeName: "teamwork"` spawns Sentinel -> Project Orchestrator -> Parallel Explorers -> Adversarial Challengers -> Victory Auditor.

---

## Core Operational Guarantees

1. **Strictly Read-Only Invariant**: Diagnostic only. Zero edits to repository files, zero package installations, and zero destructive shell commands.
2. **Cold Fact Grounding First**: Anchor observations in verified invariants, unenforced assumptions (`nothing found` if absent), and caller graphs per [`audit-context-building`](../audit-context-building/SKILL.md).
3. **Plain-Text Single-Turn Alignment (No `ask_question` Dependency)**: Only the Parent Agent aligns with the operator, using concise plain text in a single turn. Skip parameters the operator already supplied. Never invoke `ask_question` inside subagents or non-interactive runs, and never use multi-turn `ask_question` ceremony for confirmations.
4. **Anti-Sycophancy & Exploitability Gate**: Scores `>= 4.50` require empirical proof or automated fault injection. Every seat must report verified gaps with concrete `file.ext#Lxx-Lyy` citations—or explicitly document the invariants inspected with `no critical/high gaps verified` (zero fabricated quotas, zero performative praise).
5. **Fail-Closed Verification & Honest Accounting**: Adversarial Challengers verify line citations and dynamic `4 x N_seats` arithmetic closure. Any seat that fails or times out records `Status: not run` (never "0 findings") and blocks certification.

---

## 4-Stage Execution Lifecycle

### Stage 1: Cold Context Grounding (`audit-context-building`)

1. Establish factual boundaries before convening seats: target modules, entrypoints, dependencies, and risk surface.
2. Parent performs zero-read baseline scoping (`rtk git status`, `rtk rg -l`, `rtk rg -c`) without reading application source code inline.
3. Deep read-only invariant mapping runs concurrently inside `teamwork` Phase 0 Explorers, writing dossiers under `<appDataDir>\brain\<conversation-id>\scratch\<task>\audit-context\`.

### Stage 2: Operator Council Formation (Plain-Text Confirmation)

Align missing parameters in **one concise plain-text response** (omit anything already specified in the user prompt, and avoid naming internal skill/reference filenames in operator-facing text):

1. **Seat Selection (`3-5` seats)**: Recommend a tailored bundle from [`references/seat-catalog.md`](./references/seat-catalog.md). Every active seat maps 1-to-1 to a dynamic requirement block (`R1..R<N>`).
2. **Evaluation Scope & Focus**: Confirm target paths and primary audit priorities (e.g., architecture invariants, security/data safety, reliability, UX/a11y, spec verification).
3. **Deliverable & Draft Prompt**: Read [`references/dispatch-template.md`](./references/dispatch-template.md) via `read_file`/`view_file` **before** assembling the dispatch prompt so the draft locks the dynamic `R1..R<N>` contract, the Deduplication Barrier, `Status: not run` accounting, and acceptance criteria. Confirm output format per [`references/scorecard-rubric.md`](./references/scorecard-rubric.md) (`4 x N_seats` scorecard: 12 cells for 3 seats, 16 for 4, 20 for 5), and save the assembled prompt to `<appDataDir>\brain\<conversation-id>\prompt_draft.md`.
4. **Approval Gate**: Stop and wait for explicit operator confirmation (`approve`, `proceed`, `continue`) before dispatching `teamwork`.

### Stage 3: Autonomous Council Deliberation (`teamwork`)

After operator approval, verify `<appDataDir>\brain\<conversation-id>\prompt_draft.md` strictly matches [`references/dispatch-template.md`](./references/dispatch-template.md) (read via `read_file`/`view_file` if not already loaded in this session), then dispatch **one** `invoke_subagent(TypeName: "teamwork", Role: "Council Review Panel", Prompt: ...)` call populated strictly with the approved `N` seats (`3-5`) and target paths.

Internal `teamwork` execution pipeline:
1. **Sentinel Dispatch**: Initializes `<appDataDir>\brain\<conversation-id>\scratch\<task>\` and launches the Project Orchestrator.
2. **Phase 0 (Parallel Seat Exploration)**: Runs concurrent read-only Explorers for the `N` approved seats, citing `file.ext#Lxx-Lyy`.
3. **Phase 1 (Chairman Synthesis & Deduplication Barrier)**: Normalizes snippet keys (`${file}::${normalize(evidence)}`), collapses duplicate findings at `max(Severities)` annotating all discovering seats, and compiles `council_evaluation_report.md`.
4. **Phase 2 (Fail-Closed Adversarial & Forensic Gate)**: Reviewers check domain fidelity; Challengers stress-test `CRITICAL`/`HIGH` citations (refuted only at `>= 0.8` confidence with empirical proof; otherwise fails closed) and `4 x N_seats` arithmetic closure; Forensic Auditor confirms zero repo mutations or installs.
5. **Phase 3 (Mandatory Victory Audit)**: `teamwork_victory_auditor` certifies completion (`VICTORY CONFIRMED`).

### Stage 4: Certified Deliverable Packaging

Once `teamwork` finishes, Parent reads `<appDataDir>\brain\<conversation-id>\scratch\<task>\council_evaluation_report.md` and delivers the certified summary per [`references/scorecard-rubric.md`](./references/scorecard-rubric.md):

1. **Executive Summary & Chairman Verdict**: Verdict, composite score (`X.XX / 5.0`), and Grade (`A+`, `A`, `B+`, `B`, or `C`).
2. **Dynamic `4 x N_seats` Scorecard Matrix**: Exact row, column, and grand-mean arithmetic closure across all `N` active seats (`3-5`) and four rubric axes (12, 16, or 20 scored cells).
3. **Verified Discrepancies**: Anchored to exact line coordinates (`file.ext#Lxx-Lyy`).
4. **Prioritized Gap Matrix**: Categorized into `CRITICAL`, `HIGH`, `MEDIUM`, and `LOW` (plus any `Status: not run` disclosures).
5. **Non-Breaking Actionable Roadmap**: Phased remediation plan verified against Context7 or official docs when `spec-verifier` is seated (or flagged `[UNVERIFIED]` if offline).

---

## References (Read On-Demand)

- [`references/seat-catalog.md`](./references/seat-catalog.md): 11 custom specialist seats, model tiers, and recommended bundles.
- [`references/dispatch-template.md`](./references/dispatch-template.md): Parameterized `teamwork` prompt contract (`R1..R<N>`) and acceptance checklist.
- [`references/scorecard-rubric.md`](./references/scorecard-rubric.md): 4-axis rubric, `4 x N_seats` arithmetic closure rules, grading scale, and Chairman report template.
