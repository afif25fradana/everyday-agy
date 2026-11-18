---
name: academic-council
description: "Read-only multi-agent council (/academic-council): BEI/IDX thesis & chapter audits, econometrics, citation forensics, defense."
---

# Academic Council — Deliberative Thesis & Research Evaluation (Operational Runbook)

A high-rigor, strictly read-only multi-perspective evaluation framework for accounting, finance, economics, and BEI/IDX empirical research (thesis proposals, single-proposal deep dives, chapter drafts, citation forensics, and defense prep).

Powered by Antigravity's native multi-agent orchestration engine (`teamwork`).

---

## When to Use & Non-Goals (Routing Boundary)

- **Use `/academic-council` ONLY for**: Read-only multi-seat academic evaluations—comparing multiple thesis proposals, auditing a single proposal or specific chapter (Bab 1–5), validating econometric models/proxies, checking BEI/OJK/PSAK data feasibility, verifying real journal citations, or simulating Indonesian thesis defenses (sidang skripsi / ujian proposal).
- **Do NOT use (redirect immediately)**:
  - **Mutating thesis edits or code/script fixes** (e.g., editing `.docx`/`.tex`/`.md` drafts or fixing Python/Stata/R data-cleaning scripts): Council is strictly read-only. Route code edits to [`orchestrator`](../orchestrator/SKILL.md) / [`audit-dev`](../audit-dev/SKILL.md).
  - **Software architecture, codebase audits, or PR reviews**: Route to [`council-review`](../council-review/SKILL.md) or [`differential-review`](../differential-review/SKILL.md).
  - **Standalone documentation writing or non-academic library research**: Route to [`clean-docs`](../clean-docs/SKILL.md) or [`deep-web-research`](../deep-web-research/SKILL.md).

---

## Mandatory Delegation Protocol (DO NOT BYPASS)

> [!CAUTION]
> **FOR ACADEMIC COUNCIL EVALUATIONS, DISPATCH EXCLUSIVELY VIA `teamwork`.**
> Calling specialist subagents directly from the Parent session bypasses parallel seat deliberation, citation verification, arithmetic reconciliation, and victory auditing.
>
> **The Parent Agent MUST dispatch EXACTLY ONE call to `teamwork`:**
>
> ```json
> invoke_subagent(
>   TypeName: "teamwork",
>   Role: "Academic Council Panel",
>   Prompt: "Requested team: Council review panel (read-only audit & comparison)\n\n..."
> )
> ```
>
> *Engine Visibility Note*: `teamwork` is an internal runtime subagent omitted from the visible `Available subagents:` list, yet natively recognized by Antigravity. Invoking `TypeName: "teamwork"` spawns the full autonomous council.

---

## Core Operational Guarantees

1. **Strictly Read-Only Invariant**: Diagnostic only. Zero edits to thesis files, scripts, or repository files outside the scratch workspace.
2. **Real-World Evidence Grounding & Regulatory Currency**: All econometric proxies, BEI/OJK/DSAK-IAI regulations (including the 1 Jan 2024 SAK Indonesia renumbering and active Peraturan BEI I-X/II-X effective dates for `<research_period>`), and prior-study claims must be verified via `search_web` governed by [`deep-web-research`](../deep-web-research/SKILL.md) (capped at 3 queries per unresolved item).
3. **Anti-Hallucination & Paywall Citation Gate**: Every cited journal reference requires verified author(s), year, title, journal, and DOI/URL. When paywalls (ScienceDirect, Emerald, Scopus) or offline/rate-limited indexers hide fields, tag `[UNVERIFIED - PAYWALL/OFFLINE: <missing_fields>]`—never extrapolate missing volume/issue, DOI, or quartile from snippets. Fabricated references are tagged `[FABRICATED/VETOED]` as critical failures and isolated in a quarantined sub-table.
4. **Plain-Text Single-Turn Alignment (No `ask_question` Dependency)**: Only the Parent Agent aligns with the operator, using concise plain text in a single turn. Skip parameters already supplied by the operator. Never invoke `ask_question` inside subagents or non-interactive runs.
5. **Anti-Sycophancy Gate (No Forced Quotas)**: Scores `>= 4.50` require concrete empirical or documentary proof. Every seat reports verified weaknesses with concrete evidence—or explicitly documents the formulas, rules, or citations checked with `no critical/high gaps verified` (zero fabricated weakness quotas, zero empty praise).
6. **Honest Subagent Accounting (`Status: not run`)**: Any seat that crashes, times out, or fails to execute records `Status: not run` (never "0 findings") and invalidates certification.

---

## 4-Stage Execution Lifecycle

### Stage 1: Cold Context Grounding

Before convening the Council, establish an objective factual baseline:
1. Read all target files (proposals, chapter drafts, variable tables, formula definitions).
2. Map the research architecture: Independent -> Dependent -> Moderating/Mediating/Control variables, grand theories, hypotheses, sample scope, and `<research_period>`.
3. List concrete verification targets: proxy formulas, BEI/OJK/PSAK regulations active during `<research_period>`, and "penelitian terdahulu" citations requiring forensic verification.

### Stage 2: Operator Council Formation (Plain-Text Confirmation)

Align missing parameters in **one concise plain-text response** (omit anything already specified in the user prompt, and avoid naming internal skill/reference filenames in operator-facing text):

1. **Evaluation Mode**: Confirm one of:
   - **Comparative Ranking** (`M >= 2` proposals ranked head-to-head)
   - **Single Proposal Deep-Dive** (readiness verdict on 1 proposal, no ranking table)
   - **Focused Chapter/Section Audit** (e.g., Bab 2 Literature Review or Bab 3 Methodology; active dimension weights renormalized to 100%)
2. **Council Seat Selection (`3-5` seats for full proposals; `2-5` seats for Focused Chapter/Section Audits)**: Recommend a tailored bundle from [`references/seat-catalog.md`](./references/seat-catalog.md) mapped 1-to-1 to dynamic requirement blocks (`R1..R<N>`).
3. **Domain, `<research_period>` & Language**: Confirm academic field (`Akuntansi Keuangan`, `Auditing`, `Perpajakan`, `Akuntansi Manajemen`, `Keuangan/Ekonomi`), exact `<research_period>` (e.g., `2022-2025` or `2023-2026`), and output language (Indonesian academic prose or English).
4. **Draft Prompt Assembly**: Read [`references/dispatch-template.md`](./references/dispatch-template.md) via `read_file`/`view_file` **before** assembling `<appDataDir>\brain\<conversation-id>\prompt_draft.md` so the draft locks dynamic `R1..R<N>` seats, `<research_period>`, paywall citation tags, mode-adaptive scoring, and `Status: not run` accounting.
5. **Operator Approval Gate**: Stop and wait for explicit operator confirmation (`approve`, `proceed`, `continue`) before dispatching `teamwork`.

### Stage 3: Autonomous Council Deliberation (`teamwork`)

After operator approval, verify `<appDataDir>\brain\<conversation-id>\prompt_draft.md` strictly matches [`references/dispatch-template.md`](./references/dispatch-template.md) (read via `read_file`/`view_file` if not already loaded in this session), then dispatch **one** `invoke_subagent(TypeName: "teamwork", Role: "Academic Council Panel", Prompt: ...)` call populated strictly with the approved seats (`3-5` full / `2-5` focused), evaluation mode, target paths, and `<research_period>`.

Internal `teamwork` execution pipeline:
1. **Sentinel Dispatch**: Initializes `<appDataDir>\brain\<conversation-id>\scratch\<task>\` and launches the Project Orchestrator.
2. **Phase 0 (Parallel Academic Seat Reviews)**: Runs concurrent read-only Explorers for the `N` approved seats using `search_web` per `deep-web-research`.
3. **Phase 1 (Chairman Synthesis & Arithmetic Reconciliation)**: Compiles `academic_council_report.md` using the mode-adaptive template in [`references/scorecard-rubric.md`](./references/scorecard-rubric.md), verifying weight closure (`100%`) and composite math.
4. **Phase 2 (Adversarial & Citation Forensic Verification)**: Cross-checks formula proofs, regulatory effective dates, citation status tags (`[VERIFIED]` / `[UNVERIFIED - PAYWALL/OFFLINE]` / quarantined `[FABRICATED/VETOED]`), and `Status: not run` disclosures.
5. **Phase 3 (Mandatory Victory Audit)**: Confirms zero workspace mutations and certifies completion (`VICTORY CONFIRMED`).

### Stage 4: Certified Deliverable Packaging

Once `teamwork` returns, read `<appDataDir>\brain\<conversation-id>\scratch\<task>\academic_council_report.md` and present per [`references/scorecard-rubric.md`](./references/scorecard-rubric.md):

1. **Executive Summary & Chairman Verdict**: Mode-appropriate verdict (`#1..#M` ranking for comparative mode, or readiness verdict for single-proposal / chapter mode) with composite score(s).
2. **Mode-Adaptive Scorecard Matrix**: Dynamic `M`-proposal matrix or single-target weighted table (with unseated dimensions marked `N/A (not seated)` and active weights renormalized to `100%`).
3. **Verified Citation Bank** *(when Citation Auditor is seated)*: Real journal references carrying `[VERIFIED: <DOI/URL>]` or `[UNVERIFIED - PAYWALL/OFFLINE: <missing_fields>]` tags, with any `[FABRICATED/VETOED]` draft citations segregated into a separate `Quarantined / Rejected Draft Citations` sub-table.
4. **Defense Prep Kit** *(when Defense Simulator is seated)*: 5–7 pointed examiner questions with structured answer frameworks.
5. **Prioritized Weakness Matrix**: Categorized into `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` (plus any `Status: not run` disclosures).
6. **Concrete Action Plan**: Phased next steps tailored to the recommended proposal or audited chapter.

---

## References (Read On-Demand)

- [`references/seat-catalog.md`](./references/seat-catalog.md): 5 primary academic seats, 2 optional extension seats, IAI/BEI regulatory guardrails, paywall citation rules, and task bundles.
- [`references/dispatch-template.md`](./references/dispatch-template.md): Parameterized `teamwork` prompt contract (`R1..R<N>`), `<research_period>` binding, and acceptance checklist.
- [`references/scorecard-rubric.md`](./references/scorecard-rubric.md): Weighted 6-dimension rubric, focused-audit renormalization, anti-sycophancy rules, and mode-adaptive Chairman templates.
