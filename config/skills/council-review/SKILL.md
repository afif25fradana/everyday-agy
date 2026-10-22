---
name: council-review
description: >
  Orchestrate a deliberative Multi-Agent Council Review panel for high-stakes architectural evaluations,
  deep code audits, or pre-release verification. Synthesizes audit-context-building (fact grounding),
  grill-me (socratic scoping), and teamwork-preview (adversarial peer-review & Victory Auditor certification)
  powered by specialized custom subagents. Trigger when the user types /council, /council-review, or says
  "council review", "dewan pakar", "multi-agent audit", "deliberative review", or asks for a council-based evaluation.
---

# Deliberative Council Review Orchestration (Operational Runbook)

A high-rigor, evidence-backed evaluation framework combining Anthropic's **Evaluator-Optimizer** separation, Karpathy's **Council Double-Blind Synthesis**, and Addy Osmani's **SDLC Phased Gating**. Powered natively by Antigravity's specialized custom subagents.

---

## Core Operational Guarantees

1. **Strictly Read-Only Invariant**: Council panels are strictly diagnostic. Zero modifying edits to project files, zero package installations, and zero destructive actions are permitted during evaluation.
2. **Cold Fact Grounding First**: No council member may offer opinions, ratings, or critiques without first grounding observations in verified codebase guarantees and caller topologies per [`audit-context-building`](../audit-context-building/SKILL.md).
3. **Socratic Operator Alignment**: Council composition, evaluation depth, and acceptance criteria are locked via structured dialog (`ask_question`) before dispatching agent teams.
4. **Adversarial Verification Gate**: Preliminary findings must be challenged by independent reviewers (stress-testing line citations, logic consistency, and arithmetic closure) before final handoff.

---

## Tri-Pillar Execution Lifecycle

```
[Target Code/Skill/Architecture]
               │
               ▼
┌──────────────────────────────────────────────┐
│  Pillar 1: Cold Context Grounding            │  <-- audit-context-building
│  (Map guarantees, assumptions, calls)        │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│  Pillar 2: Socratic Council Formation        │  <-- grill-me (ask_question)
│  (Select 3-5 custom agent seats, criteria)   │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│  Pillar 3: Autonomous Council Deliberation   │  <-- teamwork-preview (sentinel)
│  - Parallel Specialized Explorers            │
│  - Adversarial Reviewers & Challengers       │
│  - Chairman Synthesis & Scorecard Arithmetic │
│  - Independent Victory Auditor Certification │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
[Deliverable: Certified Council Evaluation Report]
```

---

### Pillar 1: Cold Context Grounding (`audit-context-building`)

Before convening the Council, establish an objective factual baseline to prevent speculative debate:
1. Identify target modules, boundaries, and dependencies.
2. Map function guarantees (what must always hold), unenforced assumptions (marked `nothing found` if unvalidated), and upstream/downstream callers.
3. For large codebases, deploy a read-only `research` subagent to compile the context dossier under `$HOME/.gemini/antigravity/scratch/<task>/audit-context/`.
4. Proceed to Pillar 2 once factual boundaries are verified.

---

### Pillar 2: Socratic Council Formation (`grill-me`)

Engage the operator interactively using `ask_question` (one question at a time) to eliminate ambiguity:

1. **Council Seat Selection**: Present 3–5 specialized seats tailored to the problem from the [Seat Catalog](./references/seat-catalog.md):
   - Architecture & Contracts (`system-architect`)
   - Security & Hygiene (`code-auditor`)
   - Reliability & Silent Failures (`silent-failure-hunter`)
   - Test Integrity & TDD (`tdd-guide`)
   - Persistence & Database (`database-reviewer`)
   - Frontend UX & Accessibility (`ui-crafter`)
   - Documentation & ADRs (`docs-architect`)
   - Compiler & Typing (`build-error-resolver`)
   - Infrastructure & CI (`maintenance-bot`)
2. **Evaluation Depth & Focus**: Select primary dimensions:
   - Antigravity Spec Alignment
   - Developer Ergonomics & Operational Friction
   - Token & Context Window Efficiency
   - GitHub Community Benchmarking
3. **Forcing Function & Output Format**: Confirm deliverable format (Scorecard Rubric 1–5 + Prioritized Gap Matrix + Chairman Roadmap).
4. **Draft Prompt Assembly**: Maintain and display `prompt_draft.md` in the brain artifact directory per `teamwork_preview` rules.
5. **Operator Approval Gate**: Require explicit operator confirmation (`"gas"`, `"approve"`, `"lanjut"`, or UI "Proceed") before delegating.

---

### Pillar 3: Autonomous Council Deliberation (`teamwork-preview`)

Upon operator approval, delegate execution to `teamwork_preview` with `Requested team: Council review panel`:

1. **Sentinel Dispatch**: The Sentinel launches a dedicated project orchestrator in the task scratch workspace (`<appDataDir>\scratch\<project>`).
2. **Phase 0 (Parallel Seat Exploration)**: Orchestrator spawns concurrent explorer subagents corresponding to the chosen seats. Each explorer audits the target against its domain directives, citing concrete file and line coordinates (`file.ext#Lxx-Lyy`).
3. **Phase 1 (Chairman Synthesis Draft)**: A synthesis worker compiles the initial draft report (`council_evaluation_report.md`) integrating cross-seat observations.
4. **Phase 2 (Adversarial Quality & Forensic Gate)**:
   - **Reviewers**: Verify domain claims and community benchmark fidelity.
   - **Challengers**: Actively stress-test line citations (checking verbatim code matches) and scorecard arithmetic closure (verifying row/column grand mean arithmetic).
   - **Forensic Auditor**: Validates zero file mutations outside scratch and zero package installs.
5. **Phase 3 (Mandatory Victory Audit)**: Sentinel invokes an independent victory auditor (`teamwork_preview_victory_auditor`). Completion is certified only upon `VICTORY CONFIRMED`.

---

### Pillar 4: Certified Deliverable Packaging

Deliver the finalized evaluation report meeting the standards of [`scorecard-rubric.md`](./references/scorecard-rubric.md):
1. **Executive Summary & Chairman Verdict**: Clear grade (A, B+, B, C) and composite score (out of 5.0).
2. **16-Cell Scorecard Matrix**: Normalized arithmetic closure across Rigor, Ergonomics, Token Efficiency, and Spec Alignment.
3. **Concrete Discrepancies**: Citations anchored strictly to line coordinates (`file.ext#Lxx-Lyy`).
4. **Prioritized Gap Matrix**: Categorized into `CRITICAL`, `HIGH`, `MEDIUM`, and `LOW`.
5. **Non-Breaking Actionable Roadmap**: Phased implementation plan ready for operator execution.

---

## References & Catalogs

- [Seat Catalog & Agent Mapping](./references/seat-catalog.md): Directory of custom subagent specialties and domain assignments.
- [Scorecard Rubric & Chairman Template](./references/scorecard-rubric.md): Scoring criteria, mathematical reconciliation rules, and handoff template.
