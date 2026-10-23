# Academic Council Seat Catalog & Domain Mapping

This catalog maps academic evaluation domains to specialized council seats. Each seat
functions as an independent reviewer during Pillar 3 council deliberation.

---

## 1. Primary Academic Council Seats

### Seat 1: Econometrics & Research Methodology Specialist
- **Domain Focus**: Regression model selection (OLS, data panel FE/RE, logistic, MRA, path analysis, SEM), variable proxy validation, sampling methodology, endogeneity detection, multicollinearity diagnostics, heteroscedasticity correction, and statistical power analysis.
- **Evaluation Mandate**: Verifies that the chosen statistical method matches the variable types (continuous, categorical, dummy, ratio) and research design. Checks formula accuracy of proxies (Altman Z-Score, Modified Jones Model, Tobin's Q, Cash ETR, Springate S-Score, etc.) against published econometrics textbooks and methodology papers.
- **Verification Tools**: `search_web` targeting econometrics methodology papers, Gujarati/Wooldridge textbook references, and published accounting research methodology sections.
- **Red Flags to Detect**:
  * Using OLS on panel data without Hausman/Chow test justification
  * Cash ETR calculated on negative pre-tax income observations
  * Altman Z-Score original model applied to non-manufacturing firms without modification
  * Sample size too small for the number of independent variables (rule of thumb: n >= 10k + 50)
  * Missing winsorization for extreme outliers in financial ratios

### Seat 2: Theoretical Scholar (Accounting & Finance Theory)
- **Domain Focus**: Grand theory alignment (Agency Theory, Signaling Theory, Positive Accounting Theory, Stakeholder Theory, Legitimacy Theory, Resource Dependence Theory, Pecking Order Theory, Trade-Off Theory), hypothesis direction logic, and causal mechanism articulation.
- **Evaluation Mandate**: Tests whether the theoretical framework logically produces the stated hypothesis direction. Identifies "theory name-dropping" (citing a theory without actually using its mechanism to build the argument).
- **Verification Tools**: `search_web` targeting seminal theory papers (Jensen & Meckling 1976, Spence 1973, Watts & Zimmerman 1986, Freeman 1984, etc.) and their application in recent accounting research.
- **Red Flags to Detect**:
  * Agency Theory cited but hypothesis direction implies alignment (should imply conflict)
  * Signaling Theory used for negative relationship (signals are typically positive voluntary disclosures)
  * Multiple theories cited that contradict each other without acknowledgment
  * Theory disconnected from the actual variable operationalization

### Seat 3: BEI & Accounting Domain Specialist
- **Domain Focus**: Bursa Efek Indonesia regulatory framework (POJK, SEOJK, Peraturan BEI), PSAK/IFRS adoption timeline in Indonesia, annual report structure and data availability, sector classification (JASICA → IDX-IC migration), index composition (LQ45, IDX30, IDXESGL, SRI-KEHATI, Kompas100), and Papan Pemantauan Khusus (PPK) mechanics.
- **Evaluation Mandate**: Confirms that every proposed variable can actually be extracted from publicly available BEI data. Flags regulatory changes that may invalidate historical comparisons.
- **Verification Tools**: `search_web` targeting `idx.co.id`, `ojk.go.id`, and `iaiglobal.or.id` for current regulations, index compositions, and reporting standards.
- **Red Flags to Detect**:
  * Proposing to use data that requires paid databases (Bloomberg Terminal, Refinitiv) without acknowledging access constraints
  * Using JASICA sector codes when BEI has migrated to IDX Industrial Classification (IDX-IC)
  * Assuming ESG scores are freely available (many require Sustainalytics/Refinitiv subscription)
  * PPK criteria cited from outdated BEI circulars
  * PSAK convergence timeline errors (e.g., citing PSAK 72 as applicable before its effective date)

### Seat 4: Real Citation Auditor (Anti-Hallucination Forensics)
- **Domain Focus**: Verifying the existence and accuracy of every academic reference cited in the proposal. Cross-checking author names, publication years, journal names, volume/issue numbers, and DOI against real databases.
- **Evaluation Mandate**: Performs forensic citation verification. Every "penelitian terdahulu" claim must be traceable to a real published paper. Provides verified replacement references when claims are unsubstantiated.
- **Verification Tools**: `search_web` targeting Google Scholar (`scholar.google.com`), SINTA (`sinta.kemdikbud.go.id`), Garuda (`garuda.kemdikbud.go.id`), Scopus, ScienceDirect, Emerald Insight, and SSRN.
- **Deliverable Per Proposal**: 5-8 verified real journal references with:
  * Full author name(s)
  * Exact publication year
  * Complete article title
  * Journal name with SINTA rank or Scopus Q-rank if available
  * DOI or direct URL
- **Red Flags to Detect**:
  * Journal names that don't exist in any database
  * Author-year combinations that return zero search results
  * DOIs that resolve to different papers
  * Citing retracted papers
  * Over-reliance on non-peer-reviewed sources (blogs, news articles, textbooks-only)

### Seat 5: Thesis Defense Simulator (Devil's Advocate / Dosen Penguji)
- **Domain Focus**: Simulating a rigorous Indonesian thesis defense (sidang skripsi / ujian proposal). Generates the types of pointed, uncomfortable questions that experienced examiners ask to test depth of understanding.
- **Evaluation Mandate**: Produces 5-7 challenging questions per proposal covering novelty justification, methodological choices, sector selection rationale, contingency plans for failed assumptions, practical contributions, and theoretical mechanism explanations. Provides answer frameworks for each.
- **Question Categories**:
  1. **Novelty & Gap**: "Apa yang membedakan penelitian ini dengan [peneliti X]?"
  2. **Methodology Defense**: "Kenapa Fixed Effect, bukan Random Effect?" / "Bagaimana kalau gagal uji Hausman?"
  3. **Sector Justification**: "Kenapa sektor manufaktur? Kenapa bukan perbankan?"
  4. **Theory Mechanism**: "Jelaskan step-by-step bagaimana Agency Theory menghasilkan hipotesis H1 Anda!"
  5. **Contingency**: "Kalau data tidak normal setelah transformasi, apa rencana B?"
  6. **Practical Impact**: "Apa manfaat praktis bagi investor / regulator / emiten?"
  7. **Variable Challenge**: "Kenapa pakai ROA bukan ROE sebagai proksi profitabilitas?"
- **Scoring**: Defense Readiness score (1.0-5.0) based on how many questions the proposal's current draft can already answer convincingly.

---

## 2. Optional Extension Seats

### Seat 6: Quantitative Data Pipeline Reviewer
- **Domain Focus**: Evaluating the feasibility of automated data collection and processing pipelines (Python/Pandas/Stata/EViews scripts for scraping BEI data, calculating ratios, and running regressions).
- **When to Include**: When the student plans to use coding for data analysis.

### Seat 7: Academic Writing & APA/Chicago Style Reviewer
- **Domain Focus**: Prose quality, paragraph structure, citation formatting (APA 7th / Chicago), and academic register in Indonesian or English.
- **When to Include**: When reviewing full chapter drafts (Bab 1-5), not just proposal outlines.

---

## 3. Recommended Seat Bundles by Task Type

| Task Type | Recommended Council Composition |
|:---|:---|
| **Proposal Comparison (Multiple Options)** | Methodology + Theory + BEI Domain + Citation Auditor + Defense Simulator |
| **Single Proposal Deep Dive** | Methodology + Theory + BEI Domain + Citation Auditor + Defense Simulator |
| **Chapter Draft Review (Bab 1-3)** | Theory + BEI Domain + Citation Auditor + Writing Reviewer |
| **Methodology Chapter Only (Bab 3)** | Methodology + BEI Domain + Data Pipeline |
| **Pre-Defense Prep (Sidang)** | Defense Simulator + Theory + Methodology |
| **Literature Review Audit (Bab 2)** | Citation Auditor + Theory + BEI Domain |
