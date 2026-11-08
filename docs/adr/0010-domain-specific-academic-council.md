# ADR-0010: Academic Review Panel for Empirical Finance Research

## Status
Accepted

## Date
2026-10-23

## Context
Undergraduate and graduate research in accounting, finance, and economics using secondary capital market data (specifically Bursa Efek Indonesia / IDX) frequently encounters recurring methodological issues:
1. **Econometrics and Model Selection**:
   Incorrect regression model selection (e.g. pooling panel data without diagnostic tests), improper proxy formula operationalization, unaddressed endogeneity, or unadjusted outlier distortions.
2. **Theoretical Grounding**:
   Citing theoretical frameworks (Agency Theory, Signaling Theory, Stakeholder Theory) without clearly explaining the deductive mechanism connecting the theory to the hypothesis direction.
3. **Data Availability Constraints**:
   Proposing variables that require paid proprietary terminals (Bloomberg, Refinitiv) under the assumption that the data is available in free public filings.
4. **Citation Verification**:
   Language models can hallucinate publication years, journal names, author lists, or DOIs when drafting literature reviews.
5. **Defense Preparation**:
   Authors benefit from structured rehearsal of defense questions before oral examinations and proposal seminars.

While ADR-0008 established a general multi-perspective review panel (`council-review`) for software engineering, there was no tailored configuration for empirical finance and accounting research.

## Decision
1. **Define Academic Review Seats for Empirical Finance (`academic-council`)**:
   Implement a specialized review configuration tailored for empirical accounting and finance research:
   - **Econometrics and Methodology**: Audits regression model selection, proxy formulas, sampling criteria, and statistical assumptions.
   - **Theoretical Consistency**: Audits theoretical frameworks, hypothesis development, and logical consistency.
   - **Market Domain and Data Feasibility**: Verifies data availability against real IDX annual reports, financial statement notes (CALK), sector classifications, and regulatory reporting rules.
   - **Citation Verification**: Audits citations using targeted web search against academic search engines to prevent hallucinated references.
   - **Defense Examiner Perspective**: Generates challenging defense questions to help researchers prepare for oral examinations.
2. **Enforce Read-Only and Search-Verified Boundaries**:
   - The review is strictly diagnostic and does not modify source manuscripts.
   - Regulatory claims and journal citations must be grounded in verified search results.
3. **Skill Packaging**:
   Install `academic-council` under `config/skills/academic-council/` with seat catalogs and structured review rubrics.

## Alternatives Considered & Rejected
- **Using generic software engineering review roles**: Rejected because software review criteria (performance, type safety) do not address econometric validity or financial statement accounting standards.
- **Unverified citation generation**: Rejected because hallucinated references undermine research credibility.

## Consequences
- **Positive**: Intercepts incorrect regression models and proxy formulas before time-consuming data collection begins.
- **Positive**: Verifies citations against academic sources to eliminate hallucinated references.
- **Positive**: Provides structured rehearsal questions for thesis defenses and proposal seminars.
- **Trade-off**: Requires internet connectivity for web search to verify citations and regulatory circulars.
