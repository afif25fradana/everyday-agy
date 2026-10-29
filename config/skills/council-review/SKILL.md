---
name: council-review
description: >
  Orchestrate a deliberative Multi-Agent Council Review panel for high-stakes architectural evaluations,
  deep code audits, or pre-release verification. Synthesizes audit-context-building (fact grounding),
  grill-me (socratic scoping), and teamwork (adversarial peer-review & Victory Auditor certification)
  powered by specialized custom subagents. Trigger when the user types /council, /council-review, or says
  "council review", "dewan pakar", "multi-agent audit", "deliberative review", or asks for a council-based evaluation.
---

# Deliberative Council Review Orchestration (Operational Runbook)

A high-rigor, evidence-backed evaluation framework combining Anthropic's **Evaluator-Optimizer** separation, Karpathy's **Council Double-Blind Synthesis**, and Addy Osmani's **SDLC Phased Gating**. Powered natively by Antigravity's hidden multi-agent orchestration engine (`teamwork`).

---

## Mandatory Delegation Protocol (DO NOT BYPASS)

> [!CAUTION]
> **NEVER CALL SPECIALIST AGENTS DIRECTLY FROM THE PARENT AGENT.**
> Calling `invoke_subagent(TypeName: "code-auditor")`, `invoke_subagent(TypeName: "system-architect")`, or any other individual specialist agent directly from the parent session completely bypasses the multi-tier council architecture. Direct calls execute flat, unverified, sycophantic runs that finish in 60 seconds with zero critical defects found.
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
> *Engine Visibility Note*: `teamwork` is an internal engine subagent. Even though it is omitted from the visible `Available subagents:` list in your system prompt, it is fully recognized by the Antigravity runtime. Invoking `TypeName: "teamwork"` spawns the full autonomous council (Sentinel -> Project Orchestrator -> Parallel Explorers -> Adversarial Challengers -> Victory Auditor).

---

## Core Operational Guarantees

1. **Strictly Read-Only Invariant**: Council panels are diagnostic only. Zero modifying edits to project files, zero package installations, and zero destructive shell commands are permitted during evaluation.
2. **Cold Fact Grounding First**: No council member may offer opinions, ratings, or critiques without first grounding observations in verified codebase guarantees and caller topologies per [`audit-context-building`](../audit-context-building/SKILL.md).
3. **Socratic Operator Alignment**: Council composition, evaluation depth, and acceptance criteria are locked via structured dialog (`ask_question`) before dispatching agent teams.
4. **Anti-Sycophancy Gate**: Explorers and reviewers are barred from giving unearned praise. Scores >= 4.50 require concrete proof or automated fault injection. Every seat must surface real gaps.
5. **Adversarial Verification Gate**: Preliminary findings must be challenged by independent reviewers (stress-testing line citations, logic consistency, and 16-cell arithmetic closure) before final handoff.

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
│  Pillar 3: Autonomous Council Deliberation   │  <-- teamwork (Sentinel)
│  - Dedicated Project Orchestrator            │
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
3. For large codebases, deploy a read-only specialist subagent (`code-auditor` or `system-architect`) to compile the context dossier under `$HOME/.gemini/antigravity/scratch/<task>/audit-context/`.
4. Proceed to Pillar 2 once factual boundaries are verified.

---

### Pillar 2: Socratic Council Formation (`grill-me`)

Engage the operator interactively using `ask_question` (one question at a time) to eliminate ambiguity:

1. **Council Seat Selection**: Present 3-5 specialized seats tailored to the problem from the [Seat Catalog](./references/seat-catalog.md):
   - Architecture & Contracts (`system-architect`)
   - Security & Hygiene (`code-auditor`)
   - Reliability & Silent Failures (`silent-failure-hunter`)
   - Test Integrity & TDD (`tdd-guide`)
   - Persistence & Database (`database-reviewer`)
   - Frontend UX & Accessibility (`ui-crafter`)
   - Documentation & ADRs (`docs-architect`)
   - Compiler & Typing (`build-error-resolver`)
   - Infrastructure & CI (`maintenance-bot`)
   - Official Spec & Remediation Verifier (`spec-verifier`)
2. **Evaluation Depth & Focus**: Select primary dimensions:
   - Antigravity Spec Alignment
   - Developer Ergonomics & Operational Friction
   - Token & Context Window Efficiency
   - GitHub Community Benchmarking
3. **Forcing Function & Output Format**: Confirm deliverable format (Scorecard Rubric 1-5 + Prioritized Gap Matrix + Chairman Roadmap).
4. **Draft Prompt Assembly**: Maintain and display `prompt_draft.md` in the brain artifact directory per `teamwork` rules.
5. **Operator Approval Gate**: Require explicit operator confirmation ("approve", "proceed", "continue", or UI "Proceed") before delegating.

---

### Pillar 3: Autonomous Council Deliberation (`teamwork`)

Upon operator approval, dispatch `teamwork` using this exact structure:

```json
invoke_subagent(
  TypeName: "teamwork",
  Role: "Council Review Panel",
  Prompt: <council_prompt_text>
)
```

#### Dispatch Prompt Contract

The `Prompt` text must adhere strictly to these structural rules:

```markdown
Requested team: Council review panel (read-only audit & comparison)

Conduct a comprehensive, read-only multi-perspective Council evaluation of <target_name> to determine whether it is optimal, ergonomically sound, spec-compliant, and competitive against top GitHub community standards.

Working directory: <appDataDir>\scratch\<project>
Integrity mode: development

## References
- Target files: <absolute_paths_to_targets>
- Relevant standards and benchmark files

## Requirements

### R1. <Domain 1 Audit> (Council Seat 1 - e.g. system-architect)
Audit the target against architectural invariants, DAG acyclicity, modular isolation, and API contract fidelity.

### R2. <Domain 2 Audit> (Council Seat 2 - e.g. code-auditor)
Audit security attack surface, sanitization, credential hygiene, and anti-slop code hygiene.

### R3. <Domain 3 Audit> (Council Seat 3 - e.g. silent-failure-hunter)
Hunt swallowed exceptions, silent defaults, masking catches, and resource leaks.

### R4. <Domain 4 Audit> (Council Seat 4 - e.g. Community Benchmarking)
Benchmark against top GitHub repositories and state-of-the-art patterns.

### R5. Official Spec & Remediation Verification (Council Seat: spec-verifier)
Cross-check all proposed remediation plans, code snippets, and third-party library recommendations against live authoritative documentation. Use Context7 MCP (`resolve-library-id` -> `query-docs`) as primary verification; fallback to `search_web` targeting official documentation domains if Context7 lacks coverage. Veto deprecated APIs, unverified syntax, or speculative abstractions.

### R6. Strictly Read-Only Execution & Infrastructure
The evaluation must remain strictly read-only. Zero mutating file edits, package installations, or system changes are permitted outside the scratch workspace.

### R7. Structured Deliverable & Chairman Synthesis
Generate a comprehensive evaluation report saved to `<appDataDir>\scratch\<project>\council_evaluation_report.md`. The report must include:
1. Executive Summary & Final Verdict from the Chairman.
2. Numerical Scorecards (scale 1.0 to 5.0 for Rigor, Ergonomics, Token Efficiency, and Spec Alignment across all active seats).
3. Prioritized Gap Matrix (Critical / High / Medium / Low).
4. Non-breaking actionable optimization roadmap grounded in verified documentation.

## Acceptance Criteria & Adversarial Verification
- [ ] Evaluation report exists at `<appDataDir>\scratch\<project>\council_evaluation_report.md`
- [ ] Report contains numerical scorecards (1.0 to 5.0) across all seats with normalized 16-cell arithmetic closure
- [ ] Report lists concrete line-number citations for every identified discrepancy (`file.ext#Lxx-Lyy`)
- [ ] Anti-Sycophancy Mandate: Scores >= 4.50 are prohibited unless backed by automated fault injection or rigorous proof. Every seat must surface at least 2 critical/high gap observations
- [ ] Remediation Verification: Every action item in the optimization roadmap is cross-checked against Context7 or official documentation
- [ ] Adversarial Challengers independently verify all line references against codebase HEAD
- [ ] Zero mutating file edits or package installations were performed during the run
```

#### What Happens Under the Hood
1. **Sentinel Dispatch**: The Sentinel initializes the task scratch workspace and launches a dedicated Project Orchestrator.
2. **Phase 0 (Parallel Seat Exploration)**: Orchestrator spawns concurrent Explorer subagents for the selected seats. Each Explorer performs a deep read-only inspection, citing concrete file and line coordinates (`file.ext#Lxx-Lyy`).
3. **Phase 1 (Chairman Synthesis & Evidence-Normalized Deduplication Barrier)**:
   - A synthesis worker aggregates candidate findings across seats.
   - **Deduplication Barrier (ADR-0009)**: Normalizes code snippet keys (`${file}::${normalize(evidence)}`), stripping transient whitespace and comments. Overlapping findings on identical code coordinates are collapsed into a single canonical gap claim, elevating severity to $\max(\text{Severities})$ and annotating all discovering seats. This cuts downstream review noise and token expenditure by >50%.
   - Compiles the initial consolidated draft report (`council_evaluation_report.md`).
4. **Phase 2 (Targeted Adversarial Quality & Forensic Gate)**:
   - **Reviewers**: Verify domain claims and community benchmark fidelity against unique findings.
   - **Challengers (Fail-Closed Semantics)**: Stress-test line citations and logic consistency on unique `CRITICAL` and `HIGH` findings. A finding is refuted only upon $\ge 0.8$ confidence with empirical proof; otherwise, it fails closed and remains blocking. Stress-test scorecard arithmetic closure (verifying row/column grand mean arithmetic).
   - **Forensic Auditor**: Verifies zero file mutations outside scratch and zero package installs.
5. **Phase 3 (Mandatory Victory Audit)**: Sentinel invokes an independent Victory Auditor (`teamwork_victory_auditor`). Deliberation completes only when `VICTORY CONFIRMED` is achieved.

---

### Pillar 4: Certified Deliverable Packaging

Once `teamwork` returns, the Parent Agent reads `<appDataDir>\scratch\<project>\council_evaluation_report.md` and presents the certified deliverable meeting [`scorecard-rubric.md`](./references/scorecard-rubric.md):
1. **Executive Summary & Chairman Verdict**: Clear grade (A, B+, B, C) and composite score (out of 5.0).
2. **16-Cell Scorecard Matrix**: Normalized arithmetic closure across Rigor, Ergonomics, Token Efficiency, and Spec Alignment.
3. **Concrete Discrepancies**: Citations anchored strictly to line coordinates (`file.ext#Lxx-Lyy`).
4. **Prioritized Gap Matrix**: Categorized into `CRITICAL`, `HIGH`, `MEDIUM`, and `LOW`.
5. **Non-Breaking Actionable Roadmap**: Phased implementation plan ready for operator execution.

---

## References & Catalogs

- [Seat Catalog & Agent Mapping](./references/seat-catalog.md): Directory of custom subagent specialties and domain assignments.
- [Scorecard Rubric & Chairman Template](./references/scorecard-rubric.md): Scoring criteria, mathematical reconciliation rules, and handoff template.
