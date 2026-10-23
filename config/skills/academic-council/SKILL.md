---
name: academic-council
description: >
  Orchestrate a deliberative Multi-Agent Academic Council for evaluating thesis proposals,
  research paper drafts, and academic writing. Specialized for accounting, finance, economics,
  and social science research using secondary data (BEI/capital market). Seats include
  Econometrics Methodologist, Theoretical Scholar, BEI Domain Specialist, Real Citation Auditor,
  and Thesis Defense Simulator. Trigger when the user types /academic-council, /thesis-council,
  /skripsi-review, or says "review proposal skripsi", "academic council", "dewan akademik",
  "review riset", or asks for academic/thesis evaluation.
---

# Academic Council — Deliberative Thesis & Research Evaluation (Operational Runbook)

A high-rigor, evidence-backed academic evaluation framework for thesis proposals, research papers,
and scholarly writing. Adapted from the `council-review` architecture for software engineering,
re-engineered for **accounting, finance, economics, and social science research**.

Powered by Antigravity's multi-agent orchestration engine (`teamwork_preview`).

---

## Mandatory Delegation Protocol (DO NOT BYPASS)

> [!CAUTION]
> **NEVER CALL SPECIALIST AGENTS DIRECTLY FROM THE PARENT AGENT.**
> The Parent Agent MUST dispatch EXACTLY ONE call to `teamwork_preview`:
>
> ```json
> invoke_subagent(
>   TypeName: "teamwork_preview",
>   Role: "Academic Council Panel",
>   Prompt: "Requested team: Council review panel (read-only audit & comparison)\n\n..."
> )
> ```
>
> *Engine Visibility Note*: `teamwork_preview` is an internal engine subagent. Even though it
> may be omitted from the visible `Available subagents:` list, it is fully recognized by the
> Antigravity runtime. Invoking `TypeName: "teamwork_preview"` spawns the full autonomous council.

---

## Core Operational Guarantees

1. **Read-Only Invariant**: Council panels are diagnostic only. Zero modifying edits to project files outside the scratch workspace.
2. **Real-World Evidence Grounding**: No council member may offer opinions without first verifying against real journal databases, regulatory documents, or financial data sources via `search_web`.
3. **Anti-Hallucination Citation Gate**: Every referenced journal, author name, publication year, and DOI MUST be verified through web search. Fabricated references are treated as critical failures.
4. **Socratic Operator Alignment**: Council composition, evaluation depth, and acceptance criteria are locked via structured dialog (`ask_question`) before dispatching agent teams.
5. **Anti-Sycophancy Gate**: Scores >= 4.50 require concrete proof. Every seat must surface real weaknesses. No empty praise.

---

## Tri-Pillar Execution Lifecycle

```
[Target: Thesis Proposal / Paper Draft / Research Design]
               │
               ▼
┌──────────────────────────────────────────────┐
│  Pillar 1: Cold Context Grounding            │
│  (Read all proposal files, map variables,    │
│   identify theories, verify formula accuracy) │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│  Pillar 2: Socratic Council Formation        │  <-- ask_question
│  (Select 3-5 academic seats, set criteria)   │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────┐
│  Pillar 3: Autonomous Council Deliberation   │  <-- teamwork_preview
│  - Parallel Specialized Academic Reviewers   │
│  - Adversarial Thesis Defense Simulation     │
│  - Citation Forensic Verification            │
│  - Chairman Synthesis & Scorecard            │
│  - Independent Victory Auditor Certification │
└──────────────────────┬───────────────────────┘
                       │
                       ▼
[Deliverable: Certified Academic Evaluation Report]
```

---

### Pillar 1: Cold Context Grounding

Before convening the Council, establish an objective factual baseline:

1. **Read all target files** (proposals, drafts, variable tables, formula definitions).
2. **Map the research architecture**: Independent variables → Dependent variables → Control/Moderating/Mediating variables → Theoretical framework → Hypotheses → Methodology.
3. **Identify verification targets**: Which formulas need checking? Which theories need alignment validation? Which journal claims need citation forensics?
4. Proceed to Pillar 2 once the factual map is compiled.

---

### Pillar 2: Socratic Council Formation

Engage the operator interactively using `ask_question` (one question at a time):

1. **Council Seat Selection**: Present seats from the [Academic Seat Catalog](./references/seat-catalog.md). Default bundle for thesis proposal review:
   - Econometrics & Methodology Specialist
   - Theoretical Scholar (Accounting/Finance Theory)
   - BEI & Accounting Domain Specialist
   - Real Citation Auditor
   - Thesis Defense Simulator (Devil's Advocate)

2. **Evaluation Scope**: Select which proposals/chapters to evaluate:
   - All proposals (comparative ranking mode)
   - Single proposal (deep-dive mode)
   - Specific chapter/section (focused audit)

3. **Research Domain**: Confirm the academic field to calibrate seat expertise:
   - Akuntansi Keuangan (Financial Accounting)
   - Auditing
   - Perpajakan (Taxation)
   - Akuntansi Manajemen (Management Accounting)
   - Ekonomi / Keuangan Umum (General Finance/Economics)

4. **Output Language**: Indonesian academic prose or English.

5. **Draft Prompt Assembly**: Maintain and display `prompt_draft.md` in the brain artifact directory.

6. **Operator Approval Gate**: Require explicit confirmation before delegating.

---

### Pillar 3: Autonomous Council Deliberation

Upon operator approval, dispatch `teamwork_preview` using this structure:

```json
invoke_subagent(
  TypeName: "teamwork_preview",
  Role: "Academic Council Panel",
  Prompt: <academic_council_prompt_text>
)
```

#### Dispatch Prompt Contract

The `Prompt` text must adhere to this structure:

```markdown
Requested team: Council review panel (read-only audit & comparison)

Conduct a comprehensive, read-only multi-perspective Academic Council evaluation of the
thesis proposal(s) at <target_path> to assess research feasibility, methodological rigor,
theoretical coherence, citation integrity, and defense readiness.

Working directory: <appDataDir>\scratch\<project>
Integrity mode: development

## Context & Domain
- Academic field: [Akuntansi Keuangan / Auditing / Perpajakan / etc.]
- Data source: Secondary data from Bursa Efek Indonesia (BEI / idx.co.id)
- Target files: <absolute_paths_to_proposal_files>

## Requirements

### R1. Econometrics & Research Methodology Audit (Seat: Methodology Specialist)
Evaluate the methodological soundness of each proposal:
- Is the chosen regression model (data panel / logistic / MRA / path analysis) appropriate
  for the variable types and research questions?
- Are the variable proxies (formulas) mathematically correct and commonly accepted in
  peer-reviewed accounting literature?
- Identify purposive sampling criteria gaps, minimum sample size concerns, and potential
  endogeneity or multicollinearity traps.
- Flag assumptions that may fail (e.g., normality for small samples, heteroscedasticity
  in cross-sectional data).
- Use `search_web` to verify each formula/proxy against real published methodology papers.

### R2. Theoretical Framework & Hypothesis Coherence Audit (Seat: Theoretical Scholar)
Evaluate the theoretical foundations of each proposal:
- Does the chosen grand theory (Agency Theory, Signaling Theory, Stakeholder Theory,
  Positive Accounting Theory, Legitimacy Theory, etc.) logically support the proposed
  hypotheses?
- Is the causal chain from theory → variable relationship → hypothesis direction ($H_1$
  positive/negative) internally consistent?
- Identify any logical gaps where a theory is cited but the hypothesis direction
  contradicts the theory's core mechanism.
- Suggest alternative or complementary theories if the current framework is weak.
- Use `search_web` to verify theoretical applications in recent accounting research.

### R3. BEI Regulatory & Accounting Domain Verification (Seat: Domain Specialist)
Verify practical feasibility against real-world BEI/OJK/DSAK-IAI conditions:
- Are the proposed variable data points actually available in BEI annual reports,
  financial statements (Neraca, Laba Rugi, Arus Kas, CALK), or sustainability reports?
- Do the proposed sector/index selections (LQ45, IDX ESG Leaders, SRI-KEHATI,
  Papan Pemantauan Khusus) match the research period (2021-2025)?
- Are there recent regulatory changes (POJK, PSAK revisions, IFRS adoption timelines)
  that affect variable measurement or data availability?
- Verify specific BEI mechanisms mentioned (Full Call Auction, free float rules,
  trading halt procedures) against actual BEI regulations via web search.

### R4. Citation Forensics & Real Journal Verification (Seat: Citation Auditor)
Conduct forensic verification of all academic references and claims:
- For each theoretical claim or "penelitian terdahulu" mentioned, search for the REAL
  journal article using `search_web` targeting Google Scholar, SINTA, Scopus, or
  publisher domains (emerald.com, sciencedirect.com, tandfonline.com, garuda.kemdikbud.go.id).
- Verify: author name(s), publication year, journal name, volume/issue, and DOI.
- Provide 5-8 VERIFIED real journal references per proposal that directly support the
  research variables and hypotheses.
- Flag any claims that cannot be substantiated with real published research.
- Prioritize Indonesian SINTA-accredited journals (S1-S2) and international Scopus-indexed
  journals in accounting/finance.

### R5. Thesis Defense Simulation (Seat: Devil's Advocate / Dosen Penguji)
Simulate a rigorous thesis defense examination (sidang skripsi):
- Generate 5-7 pointed questions per proposal that a tough examiner ("dosen killer")
  would ask, covering:
  * "Apa bedanya penelitian Anda dengan penelitian terdahulu X?"
  * "Kenapa memilih sektor ini dan bukan sektor lain?"
  * "Bagaimana kalau data Anda tidak lolos uji normalitas/asumsi klasik?"
  * "Apa kontribusi praktis penelitian ini bagi dunia usaha/regulator?"
  * "Jelaskan mekanisme teori keagenan yang menghubungkan X1 dengan Y!"
- For each question, provide a suggested strong answer framework.
- Rate each proposal's "defense readiness" on a 1-5 scale.

### R6. Comparative Ranking & Recommendation (Seat: Chairman)
After all seats complete their evaluation:
- Produce a comparative ranking of all proposals across dimensions:
  * Feasibility (data availability & ease of collection)
  * Novelty (kebaruan / research gap strength)
  * Methodological Rigor
  * Theoretical Coherence
  * Defense Readiness
  * Estimated Time to Completion
- Recommend the single best proposal with justification.
- Provide a concrete "quick win" action plan for the recommended proposal.

### R7. Strictly Read-Only Execution
The evaluation must remain strictly read-only. Zero mutating file edits, package
installations, or system changes are permitted outside the scratch workspace.

### R8. Structured Deliverable
Generate a comprehensive evaluation report saved to
`<appDataDir>\scratch\<project>\academic_council_report.md`. The report must include:
1. Executive Summary & Chairman Verdict with final ranking.
2. Numerical Scorecards (scale 1.0 to 5.0) per proposal across all evaluation dimensions.
3. Verified citation list (real journals with author, year, title, journal name, DOI/URL).
4. Defense simulation Q&A per proposal.
5. Prioritized weakness matrix (Critical / High / Medium / Low).
6. Recommended proposal with action plan.

## Acceptance Criteria & Verification
- [ ] Report exists at `<appDataDir>\scratch\<project>\academic_council_report.md`
- [ ] Report contains numerical scorecards (1.0-5.0) for each proposal across all dimensions
- [ ] Every cited journal reference has been verified via web search (author, year, journal, DOI/URL confirmed)
- [ ] Zero fabricated/hallucinated journal references in the final report
- [ ] Each proposal has 5-7 defense simulation questions with answer frameworks
- [ ] Comparative ranking table with clear #1 recommendation and justification
- [ ] All variable formulas/proxies have been cross-checked against published methodology sources
- [ ] Anti-Sycophancy: Scores >= 4.50 require concrete evidence. Every seat must surface at least 2 real weaknesses per proposal
- [ ] Zero mutating file edits outside scratch workspace
```

---

### Pillar 4: Certified Deliverable Packaging

Once `teamwork_preview` returns, the Parent Agent reads `academic_council_report.md` and presents:

1. **Executive Summary & Chairman Verdict**: Ranking (#1 to #5) with composite scores.
2. **Scorecard Matrix**: Per-proposal scores across Feasibility, Novelty, Methodology, Theory, Defense Readiness.
3. **Verified Citation Bank**: Real journal references with confirmed DOI/URLs, ready to paste into daftar pustaka.
4. **Defense Prep Kit**: Simulated examiner questions + suggested answers per proposal.
5. **Weakness Matrix**: Categorized into `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`.
6. **Action Plan**: Concrete next steps for the recommended #1 proposal.

---

## References & Catalogs

- [Academic Seat Catalog & Domain Mapping](./references/seat-catalog.md)
- [Academic Scorecard Rubric & Chairman Template](./references/scorecard-rubric.md)
