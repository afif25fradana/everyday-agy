# Academic Council Seat Catalog & Domain Mapping (`seat-catalog.md`)

This catalog maps academic evaluation domains to specialized council seats. Each approved seat functions as an independent read-only reviewer during Stage 3 council deliberation.

---

## 1. Primary Academic Council Seats

### Seat 1: Econometrics & Research Methodology Specialist
- **Domain Focus**: Regression model selection (OLS, panel data FE/RE/CEM with Chow/Hausman/LM tests, logistic, MRA, path analysis, SEM), variable proxy validation, sampling methodology, endogeneity detection, multicollinearity diagnostics, heteroscedasticity/autocorrelation correction (robust/clustered SEs), and statistical power analysis.
- **Evaluation Mandate**: Verifies that the chosen statistical method matches variable types (continuous, categorical, dummy, ratio) and research design. Cross-checks proxy formulas (Altman Z-Score, Modified Jones Model, Tobin's Q, Cash ETR, Springate S-Score, CAMEL/RBBR ratios, etc.) against published econometrics textbooks and peer-reviewed methodology papers.
- **Verification Tools**: `search_web` targeting econometrics methodology papers, Gujarati/Wooldridge/Baltagi references, and peer-reviewed accounting methodology sections.
- **Red Flags to Detect**:
  * Using pooled OLS on panel data without Chow/Hausman/Lagrange Multiplier justification
  * Cash ETR calculated on negative pre-tax income observations without exclusion or boundary treatment
  * Original Altman Z-Score (manufacturing) applied to service, banking, or non-manufacturing firms without modification
  * Insufficient sample size relative to predictors or panel cross-sections
  * Missing outlier treatment / winsorization for extreme financial ratios

### Seat 2: Theoretical Scholar (Accounting & Finance Theory)
- **Domain Focus**: Grand theory alignment (Agency Theory, Signaling Theory, Positive Accounting Theory, Stakeholder Theory, Legitimacy Theory, Resource Dependence Theory, Pecking Order Theory, Trade-Off Theory), hypothesis direction logic, and causal mechanism articulation.
- **Evaluation Mandate**: Tests whether the theoretical framework logically entails the stated hypothesis direction. Identifies "theory name-dropping" (citing a theory without articulating its causal mechanism).
- **Verification Tools**: `search_web` targeting seminal theory papers (Jensen & Meckling 1976, Spence 1973, Watts & Zimmerman 1986, Freeman 1984, etc.) and recent peer-reviewed applications.
- **Red Flags to Detect**:
  * Agency Theory cited when the hypothesis mechanism assumes principal-agent alignment rather than agency conflict or monitoring mitigation
  * Signaling Theory applied to involuntary or purely negative events without explaining the costly-signal separating equilibrium
  * Multiple theories cited with conflicting predictions and zero reconciliation
  * Grand theory disconnected from actual variable operationalization

### Seat 3: BEI & Accounting Domain Specialist
- **Domain Focus**: Bursa Efek Indonesia regulatory framework (POJK, SEOJK, Peraturan BEI), DSAK-IAI SAK Indonesia / IFRS convergence & numbering, annual report & CALK data availability, sector classification (JASICA -> IDX-IC migration), index composition (LQ45, IDX30, IDXESGL, SRI-KEHATI, Kompas100), and Papan Pemantauan Khusus (PPK) / Full Call Auction (FCA) mechanics.
- **Evaluation Mandate**: Confirms every proposed variable is extractable from publicly available BEI filings (`idx.co.id`) and verifies active regulatory effective dates specifically for `<research_period>` via `search_web` (governed by `deep-web-research`, tagged `[VERIFIED: <url>]` / `[UNVERIFIED: <reason>]` / `[VETOED: <reason>]`). Never assume static rules across years.
- **Mandatory Regulatory Currency Checks**:
  * **IAI 2024 SAK Indonesia Renumbering (Effective 1 January 2024)**: Verify 3-digit nomenclature (`1xx` = IFRS, `2xx` = IAS, `3xx` = local, `4xx` = shariah): e.g., `PSAK 72` -> `PSAK 115` (IFRS 15, Revenue), `PSAK 71` -> `PSAK 109` (IFRS 9, Financial Instruments; note former shariah PSAK 109 Zakat moved to `PSAK 4xx`), `PSAK 73` -> `PSAK 116` (IFRS 16, Leases), `PSAK 1` -> `PSAK 201` (IAS 1, Financial Statement Presentation). Flag proposals covering `>= 2024` that cite legacy numbers without noting the 2024 renumbering, or proposals spanning pre/post-adoption years without noting transitional cutoffs.
  * **BEI Papan Pemantauan Khusus (Peraturan Bursa I-X & II-X)**: Verify which rule version was active during `<research_period>` via `search_web` on `idx.co.id` (e.g., March 2024 FCA Tahap II implementation vs. 28 September 2026 revision removing liquidity/price `< Rp51` criteria 1, 6, 7, and 10 while retaining fundamental criteria and adding Non-Cancellation Period).
- **Verification Tools**: `search_web` targeting `idx.co.id`, `ojk.go.id`, and `iaiglobal.or.id`.
- **Red Flags to Detect**:
  * Requiring paid terminals (Bloomberg, Refinitiv/LSEG, Sustainalytics) without disclosing access constraints or free BEI proxies
  * Using deprecated JASICA sector codes instead of IDX Industrial Classification (IDX-IC)
  * Citing outdated PPK criteria or stale POJK/SEOJK rules without checking active effective dates for `<research_period>`
  * PSAK numbering or effective-date errors across pre-2024 and post-2024 observation windows

### Seat 4: Real Citation Auditor (Anti-Hallucination & Paywall Forensics)
- **Domain Focus**: Forensic verification of every academic reference cited in the proposal/chapter. Cross-checking author names, publication years, exact titles, journal names, volume/issue numbers, SINTA/Scopus ranks, and DOIs against real databases.
- **Evaluation Mandate**: Every "penelitian terdahulu" claim must trace to a real published work. Provide verified replacement references when claims are unsubstantiated, strictly observing the 3-query cap per unresolved citation (`deep-web-research`).
- **Paywall & Offline Guardrail**:
  * When `search_web` hits paywalled publishers (ScienceDirect, Emerald Insight, Taylor & Francis, Scopus) or rate-limited/offline indexers (Google Scholar, SINTA) and cannot confirm volume/issue, DOI, or quartile, cross-check public DOI metadata (`doi.org` / Crossref) within the 3-query cap.
  * If bibliographic fields remain unconfirmed, **explicitly tag the row `[UNVERIFIED - PAYWALL/OFFLINE: <missing_fields>]`**. NEVER infer or extrapolate missing volume/issue numbers, DOIs, or SINTA/Scopus ranks from partial search snippets.
  * Tag non-existent author-year/journal combinations `[FABRICATED/VETOED]` as critical failures and isolate them in the segregated `Quarantined / Rejected Draft Citations` sub-table (never mixed into the Verified Reference Bank).
- **Verification Tools**: `search_web` targeting Google Scholar (`scholar.google.com`), SINTA (`sinta.kemdikbud.go.id`), Garuda (`garuda.kemdikbud.go.id`), Crossref (`doi.org`), Scopus, ScienceDirect, Emerald Insight, Taylor & Francis, and SSRN.
- **Deliverable Per Target**: 5–8 `[VERIFIED: <DOI/URL>]` supporting journal references (author(s), exact year, full title, journal name + verified SINTA/Scopus rank if confirmed, DOI/URL), plus forensic audit status for all existing draft citations.
- **Red Flags to Detect**:
  * Journal names absent from SINTA, Garuda, Crossref, or Scopus
  * Author-year combinations returning zero verifiable scholarly records
  * DOIs resolving to different articles or mismatched years/authors
  * Extrapolated volume/issue/quartile claims lacking verifiable metadata
  * Retracted papers or over-reliance on non-peer-reviewed blogs/news

### Seat 5: Thesis Defense Simulator (Devil's Advocate / Dosen Penguji)
- **Domain Focus**: Simulating a rigorous Indonesian thesis defense (sidang skripsi / ujian proposal) with pointed, non-softball examiner questions.
- **Evaluation Mandate**: Produces 5–7 challenging questions per target covering novelty/gap, methodology choice, sector/period rationale, theoretical causal chain, failed-assumption contingencies, variable proxy defense, and practical impact—each paired with a concrete answer framework.
- **Question Categories**:
  1. **Novelty & Gap**: "Apa yang membedakan penelitian ini dengan [peneliti X]?"
  2. **Methodology Defense**: "Kenapa Fixed Effect, bukan Random Effect?" / "Bagaimana penanganan jika uji asumsi klasik gagal?"
  3. **Sector & Period Justification**: "Kenapa memilih sektor dan periode `<research_period>` ini, dan bagaimana dampak perubahan regulasi di tengah periode?"
  4. **Theory Mechanism**: "Jelaskan mekanisme kausal dari grand theory Anda sampai menghasilkan arah hipotesis H1!"
  5. **Contingency**: "Jika data outlier ekstrem atau sampel tergerus kriteria purposive sampling, apa rencana B?"
  6. **Practical Impact**: "Apa kontribusi praktis bagi investor, emiten, atau regulator (OJK/BEI)?"
  7. **Variable Challenge**: "Kenapa memilih proksi X dibandingkan alternatif Y?"
- **Scoring**: Defense Readiness score (`1.0-5.0`) grounded in how convincingly the current draft already answers these challenges.

---

## 2. Optional Extension Seats

### Seat 6: Quantitative Data Pipeline Reviewer
- **Domain Focus**: Read-only audit of data-extraction and econometric code reproducibility (Python/Pandas, Stata, EViews, R scripts for IDX financial data cleaning, ratio calculation, winsorization, and panel regression).
- **When to Include**: When the student uses scripted data processing or includes Bab 3/4 empirical code.

### Seat 7: Academic Writing & APA/Chicago Style Reviewer
- **Domain Focus**: Academic register (Indonesian EYD/KBBI or English scholarly prose), argument cohesion, paragraph flow, and APA 7th / Chicago citation formatting consistency.
- **When to Include**: When reviewing full chapter drafts (Bab 1–5) rather than proposal outlines.

---

## 3. Recommended Seat Bundles by Task Type

Seat count bounds: **`3-5` seats** for full proposals (Comparative Ranking & Single Proposal Deep-Dive) and **`2-5` seats** for Focused Chapter/Section Audits.

| Task Type / Evaluation Mode | Recommended Council Composition |
|:---|:---|
| **Comparative Ranking (`M >= 2` Proposals)** | Methodology + Theory + BEI Domain + Citation Auditor + Defense Simulator *(5 seats)* |
| **Single Proposal Deep-Dive** | Methodology + Theory + BEI Domain + Citation Auditor + Defense Simulator *(5 seats)* |
| **Chapter Draft Audit (Bab 1–3)** | Theory + BEI Domain + Citation Auditor + Writing Reviewer *(4 seats)* |
| **Methodology Chapter Only (Bab 3)** | Methodology + BEI Domain *(2-seat Bab 3 core)* + Seat 6 Data Pipeline *(optional, 3rd seat)* |
| **Pre-Defense Prep (Sidang)** | Defense Simulator + Theory + Methodology *(3 seats)* |
| **Literature Review Audit (Bab 2)** | Citation Auditor + Theory + BEI Domain *(3 seats)* |
