# ADR-0010: Domain-Specific Academic Council for Capital Market & Secondary Data Thesis Evaluation

## Status
Accepted

## Date
2026-10-23

## Context
Undergraduate and graduate research in accounting, finance, economics, and management relying on secondary capital market data (specifically Bursa Efek Indonesia / IDX) frequently suffers from recurring methodological and structural pitfalls:
1. **Econometrics Specification Traps**: Incorrect regression models (e.g. applying pooled OLS to panel data without Chow/Hausman tests), invalid proxy operationalization (e.g. calculating Cash ETR on negative pre-tax income or misapplying manufacturing Altman Z-Scores to financial institutions), unaddressed endogeneity, and extreme outlier distortions.
2. **Theoretical Disconnect ("Theory Name-Dropping")**: Citing grand theories (Agency Theory, Signaling Theory, Stakeholder Theory, Positive Accounting Theory) in literature reviews without establishing a deductive, causal mechanism that justifies hypothesis direction.
3. **Data Availability Miscalculations**: Proposing variables requiring paid proprietary terminals (Bloomberg, Refinitiv, S&P Capital IQ) under the mistaken belief that the metrics are freely available in public financial statements or Notes to Financial Statements (CALK).
4. **AI Citation Hallucination**: AI assistants commonly fabricate journal names, publication years, author pairings, and DOIs when drafting literature reviews.
5. **Defense Unpreparedness**: Lack of structured adversarial simulation for thesis defense (*sidang skripsi*) and proposal seminars (*sempro*).

While ADR-0008 established the Tri-Pillar Council Review framework (`council-review`) for software engineering audits, Antigravity lacked a tailored deliberative board specialized for empirical social science and capital market research.

## Decision
1. **Establish the Academic Council Skill (`academic-council`)**:
   Implement a specialized deliberative panel powered by Antigravity's multi-agent runtime (`teamwork_preview`), tailored for empirical accounting and finance research:
   - **Seat 1 (Econometrics & Methodology Specialist)**: Audits regression model selection, proxy formulas, purposive sampling criteria, and statistical assumptions.
   - **Seat 2 (Theoretical Scholar)**: Audits grand theory coherence, hypothesis causality, and internal consistency.
   - **Seat 3 (BEI Domain Specialist)**: Verifies empirical feasibility against real IDX annual reports, CALK, IDX-IC sector classifications, and OJK/PSAK regulatory timelines.
   - **Seat 4 (Real Citation Auditor)**: Enforces forensic anti-hallucination verification using targeted web search against Google Scholar, SINTA, Scopus, and official repositories.
   - **Seat 5 (Thesis Defense Simulator)**: Simulates examiner defense questions (Devil's Advocate) to stress-test research design and prepare researchers for oral defense.
2. **Enforce Read-Only & Evidence-Backed Guarantees**:
   - Council deliberation is strictly read-only with respect to project source documents.
   - All citations and regulatory claims must be grounded in live web search verification.
3. **Incorporate into Antigravity Customization Architecture**:
   Install `academic-council` under `config/skills/academic-council/` with seat catalogs and normalized 16-cell scorecard rubrics.

## Consequences

### Positive
- **Guaranteed Citation Integrity**: Completely eliminates fake or hallucinated citations in thesis drafts through forensic web verification.
- **Pre-Collection Methodology Validation**: Catches econometrics errors and proxy formula mistakes before time-consuming data collection begins.
- **Realistic Defense Preparation**: Equips students and researchers with anticipated examiner counterarguments and methodological defenses.
- **Zero Repo Bloat**: Implemented as a modular, on-demand skill without modifying global runtime invariants.

### Negative & Operational Requirements
- **Search Dependency**: Seat 4 and Seat 3 require active internet connectivity and `search_web` invocations to verify journal indexing and regulatory circulars.
- **Multi-Agent Latency**: Full panel deliberation involves multi-agent synthesis via `teamwork_preview`, taking several minutes per evaluation.
