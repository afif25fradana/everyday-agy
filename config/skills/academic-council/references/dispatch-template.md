# Academic Council Dispatch Prompt Contract (`dispatch-template.md`)

Read on-demand during Stage 2/3 to assemble the `Prompt` argument for the single `invoke_subagent(TypeName: "teamwork", Role: "Academic Council Panel", ...)` call.

Populate **only** the `N` approved seats (`3-5` for full proposals; `2-5` for Focused Chapter/Section Audits) as `R1..R<N>` and bind `<evaluation_mode>`, `<research_period>`, `<academic_field>`, `<output_language>`, and `<target_paths>` from Stage 2. Never inject unapproved seats or hardcoded proposal counts.

```markdown
Requested team: Council review panel (read-only audit & comparison)

Conduct a strictly read-only multi-perspective Academic Council evaluation of the target research
material at <target_paths> to assess feasibility, methodological rigor, theoretical coherence,
regulatory currency, citation integrity, and defense readiness.

Working directory: <appDataDir>\brain\<conversation-id>\scratch\<task>
Integrity mode: development

## Context & Scope
- Evaluation mode: <Comparative Ranking (M proposals) | Single Proposal Deep-Dive | Focused Chapter Audit (Bab X)>
- Academic field: <Akuntansi Keuangan | Auditing | Perpajakan | Akuntansi Manajemen | Keuangan/Ekonomi>
- Research period: <research_period> (e.g., 2022-2025 or 2023-2026)
- Data source: <Secondary data from Bursa Efek Indonesia (BEI / idx.co.id) or specified source>
- Output language: <Indonesian academic prose | English>
- Target files: <target_paths>

## Requirements

### R1..R<N>. Dynamic Academic Seat Audits (Instantiate Exactly N Blocks for Approved Seats)
<!-- Select and instantiate ONLY the N approved seats (3-5 full; 2-5 focused) from references/seat-catalog.md: -->

<!-- Template — Methodology Specialist (Seat 1) -->
### R<k>. Econometrics & Research Methodology Audit (Seat: Methodology Specialist)
Evaluate methodological soundness for each target proposal/chapter:
- Verify regression model suitability (panel FE/RE/CEM with Chow/Hausman/LM tests, logistic, MRA, path/SEM) against variable types and research questions.
- Cross-check all variable proxy formulas (Altman Z-Score, Modified Jones, Tobin's Q, Cash ETR, CAR/NPL, etc.) via `search_web` against published methodology sources.
- Audit purposive sampling criteria, sample size sufficiency, outlier/winsorization strategy, endogeneity, multicollinearity, and classical assumption contingencies.

<!-- Template — Theoretical Scholar (Seat 2) -->
### R<k>. Theoretical Framework & Hypothesis Coherence Audit (Seat: Theoretical Scholar)
Evaluate theoretical foundations:
- Verify whether the grand theory (Agency, Signaling, Stakeholder, Positive Accounting, Legitimacy, Pecking Order, Trade-Off, etc.) logically entails each stated hypothesis direction.
- Flag theory name-dropping, internal contradictions across multiple theories, or broken causal chains from theory -> variable proxy -> hypothesis.
- Verify seminal and recent theoretical applications via `search_web`.

<!-- Template — BEI & Accounting Domain Specialist (Seat 3) -->
### R<k>. BEI Regulatory & Accounting Domain Verification (Seat: Domain Specialist)
Verify practical feasibility and regulatory currency across `<research_period>` via `search_web` targeting `idx.co.id`, `ojk.go.id`, and `iaiglobal.or.id` (tagged `[VERIFIED: <url>]` / `[UNVERIFIED: <reason>]` / `[VETOED: <reason>]` per `deep-web-research`):
- Confirm variable data availability in public BEI annual reports, financial statements (Neraca, Laba Rugi, Arus Kas, CALK), or sustainability reports without assuming paid terminals (Bloomberg/Refinitiv).
- Verify active effective dates of all cited PSAK/ISAK standards (checking the 1 Jan 2024 IAI SAK Indonesia 3-digit renumbering: PSAK 72 -> PSAK 115, PSAK 71 -> PSAK 109, PSAK 73 -> PSAK 116, PSAK 1 -> PSAK 201; shariah standards shifted to `4xx`), POJK/SEOJK rules, IDX-IC sector codes, and BEI index/board rules (e.g., Papan Pemantauan Khusus Peraturan I-X / II-X revisions, FCA mechanics) specifically for `<research_period>`.
- Flag any structural breaks or transitional rule changes falling inside `<research_period>`.

<!-- Template — Real Citation Auditor (Seat 4) -->
### R<k>. Citation Forensics & Real Journal Verification (Seat: Citation Auditor)
Conduct forensic verification of cited "penelitian terdahulu" and supply supporting references via `search_web` (Google Scholar, SINTA, Garuda, Crossref/`doi.org`, Scopus, ScienceDirect, Emerald, Taylor & Francis), capped at 3 queries per unresolved reference:
- Verify author(s), publication year, exact title, journal name, volume/issue, SINTA/Scopus rank, and DOI/URL.
- **Paywall & Offline Guardrail**: If a publisher paywall (ScienceDirect, Emerald, Scopus) or offline/rate-limited indexer blocks full bibliographic metadata, cross-check DOI/Crossref within the 3-query cap; if fields remain unconfirmed, explicitly tag `[UNVERIFIED - PAYWALL/OFFLINE: <missing_fields>]`. NEVER extrapolate missing volume/issue, DOI, or quartile from search snippets.
- Place ONLY `[VERIFIED: <DOI/URL>]` and `[UNVERIFIED - PAYWALL/OFFLINE: <missing_fields>]` rows in the Verified Reference Bank. Quarantine every `[FABRICATED/VETOED]` draft citation into the segregated `### Quarantined / Rejected Draft Citations` sub-table beneath it so skimming readers cannot copy fabricated rows into daftar pustaka.
- Provide 5-8 `[VERIFIED: <DOI/URL>]` supporting references per proposal (or chapter scope), prioritizing Indonesian SINTA 1-2 and Scopus-indexed accounting/finance journals.

<!-- Template — Thesis Defense Simulator (Seat 5) -->
### R<k>. Thesis Defense Simulation (Seat: Devil's Advocate / Dosen Penguji)
Simulate a rigorous thesis defense (sidang skripsi / ujian proposal):
- Generate 5-7 pointed examiner questions per target covering novelty/gap, methodology choice, sector/period justification, theory mechanism, failed-assumption contingencies, variable proxy choice, and practical impact.
- Provide a structured answer framework per question and assign a Defense Readiness score (1.0-5.0).

<!-- Optional Extension Seats (instantiate ONLY if approved in Stage 2): Seat 6 Quantitative Data Pipeline Reviewer; Seat 7 Academic Writing & APA/Chicago Style Reviewer. -->

### R<N+1>. Chairman Synthesis & Mode-Adaptive Scoring (Seat: Chairman)
Compile scores per `references/scorecard-rubric.md`:
- **Comparative Mode (`M >= 2` proposals)**: Build a dynamic `M`-column comparative scorecard (Template 4A), rank `#1..#M`, recommend the strongest proposal with justification, and provide an action plan.
- **Single Proposal Deep-Dive**: Score all active dimensions in a single-target table (Template 4B) with readiness verdict (`READY FOR SEMINAR` / `CONDITIONAL REVISION` / `MAJOR RESTRUCTURING`) and phased revision plan (no comparative ranking table).
- **Focused Chapter/Section Audit**: Score only dimensions covered by active seats (Template 4B), mark unseated dimensions `N/A (not seated)`, proportionally renormalize active weights to sum to `100%`, and output a chapter readiness verdict + targeted revision plan.

### R<N+2>. Strictly Read-Only Execution
Maintain strict read-only operation. Zero edits to thesis files, code, or repository files, and zero package installations outside the scratch workspace.

### R<N+3>. Structured Deliverable
Save the complete evaluation report to `<appDataDir>\brain\<conversation-id>\scratch\<task>\academic_council_report.md` following the matching mode template in `references/scorecard-rubric.md`.

## Acceptance Criteria & Verification
- [ ] Report exists at `<appDataDir>\brain\<conversation-id>\scratch\<task>\academic_council_report.md`
- [ ] Scorecard matches `<evaluation_mode>` (no dummy proposal columns) with exact arithmetic closure (active weights sum to `100%`, composite equals weighted sum, ranking matches composites in comparative mode)
- [ ] Regulatory effective dates (IAI 2024 SAK renumbering, POJK/SEOJK, Peraturan BEI I-X/II-X) verified for `<research_period>` via `search_web` with status tags
- [ ] Verified Reference Bank holds ONLY `[VERIFIED: <DOI/URL>]` and `[UNVERIFIED - PAYWALL/OFFLINE: <missing_fields>]` rows; all `[FABRICATED/VETOED]` draft citations are isolated in `### Quarantined / Rejected Draft Citations`; zero snippet-extrapolated metadata
- [ ] Variable formulas/proxies cross-checked against published methodology sources (when Seat 1 is seated)
- [ ] 5-7 defense questions with answer frameworks per target (when Seat 5 is seated)
- [ ] Anti-Sycophancy Gate: Scores >= 4.50 backed by concrete proof; every seat reports verified gaps OR documents checked invariants/formulas with `no critical/high gaps verified` (zero forced weakness quotas)
- [ ] Honest Subagent Accounting: Any failed or timed-out seat is recorded as `Status: not run` (never "0 findings") and invalidates certification
- [ ] Forensic Audit: Zero mutating file edits or package installations outside scratch workspace
```
