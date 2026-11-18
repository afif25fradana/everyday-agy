# Academic Council Scorecard Rubric & Chairman Template (`scorecard-rubric.md`)

Scoring criteria, mode-adaptive templates, and arithmetic reconciliation rules for Academic Council deliverables.

---

## 1. Scoring Dimensions & Weight Renormalization

Each evaluated target is scored on a `1.0` to `5.0` scale across six baseline dimensions:

| Dimension | Baseline Weight | Primary Seat(s) | What It Measures |
|:---|:---:|:---|:---|
| **Feasibility** | 25% | BEI Domain + Methodology | Public BEI/CALK data extractability, regulatory currency across `<research_period>`, realistic collection effort. |
| **Novelty (Kebaruan)** | 20% | Theory + Defense Simulator | Genuine research gap, distinction from prior studies, current empirical phenomenon. |
| **Methodological Rigor** | 20% | Methodology (+ Data Pipeline) | Statistical model fit, verified proxy formulas, defensible sampling, assumption diagnostics. |
| **Theoretical Coherence** | 15% | Theory | Deductive link from grand theory -> proxy -> hypothesis direction (no name-dropping). |
| **Defense Readiness** | 10% | Defense Simulator | Ability of the current draft to withstand tough examiner interrogation. |
| **Citation Integrity** | 10% | Citation Auditor | Real, verifiable scholarly references with explicit status tags and zero fabrications. |

- **Full-Panel Composite Score** (`all 6 dimensions active`): Weighted sum across all 6 dimensions (weights sum to `100%`).
- **Focused Chapter/Section Audit Renormalization**: When a focused audit omits seats covering specific dimensions (e.g., Bab 3 Methodology Only omitting Citation Auditor and Defense Simulator), mark unseated dimensions `N/A (not seated)` and renormalize the remaining active baseline weights proportionally so active weights sum to exactly `100%`:
  $$w_i^{\text{norm}} = \frac{w_i^{\text{base}}}{\sum_{j \in \text{Active}} w_j^{\text{base}}} \times 100\%$$
  Report both baseline and renormalized weights in the scorecard table.

---

## 2. Score Anchors

| Score | Label | Meaning |
|:---:|:---|:---|
| **5.0** | Exceptional | Publication-ready rigor (SINTA 1 / Scopus Q2 caliber with minor revisions). Requires concrete documentary proof. |
| **4.0** | Strong | Minor fixable gaps. Ready for seminar proposal / chapter submission with confidence. |
| **3.0** | Adequate | Meets minimum academic threshold but has notable gaps requiring 1–2 revision rounds. |
| **2.0** | Weak | Fundamental flaws in methodology, theory, regulatory alignment, or data feasibility. Needs major restructuring. |
| **1.0** | Critical | Not viable in current form; core construct, data availability, or citation integrity is broken. |

---

## 3. Anti-Sycophancy & Honest Accounting Rules

> [!CAUTION]
> - **Proof Gate (`>= 4.50`)**: Scores `>= 4.50` on any dimension are **prohibited** unless anchored in concrete proof (verified published methodology reference, confirmed BEI/CALK data item, or verified regulatory text).
> - **Zero Forced Weakness Quotas**: Do NOT invent nitpicks to hit an artificial count. Every active seat reports verified weaknesses with concrete evidence—or, if a section is genuinely sound, explicitly enumerates the formulas, regulatory rules, or citations audited and records `no critical/high gaps verified`.
> - **Adversarial Defense Integrity**: When seated, the Defense Simulator must ask genuine, substantive examiner questions—never softball prompts.
> - **Honest Subagent Accounting (`Status: not run`)**: Any seat that crashes, times out, or fails to produce output MUST be recorded as `Status: not run` (never counted as "0 findings") and invalidates final certification.

---

## 4. Mode-Adaptive Chairman Report Templates

Select **Template 4A** for Comparative Ranking (`M >= 2` proposals) or **Template 4B** for Single Proposal Deep-Dive / Focused Chapter Audit. Never render dummy unused proposal columns.

### Template 4A: Comparative Ranking Mode (`M >= 2` Proposals)

```markdown
# Academic Council Evaluation Report (Comparative Mode)

## Executive Summary
- **Date**: <YYYY-MM-DD>
- **Evaluator**: Academic Council (<N>-seat panel)
- **Target**: <M> thesis proposals | Field: <academic_field> | Period: <research_period>
- **Chairman Verdict**: Proposal #<X> — "<Title>" is recommended as the strongest candidate (Composite: X.XX / 5.0).

## Comparative Scorecard (<M> Proposals)

<!-- Instantiate strictly M proposal columns (Proposal 1 .. Proposal M). -->
| Dimension (Weight) | Proposal 1 | Proposal 2 | ... | Proposal M |
|:---|:---:|:---:|:---:|:---:|
| Feasibility (25%) | X.X | X.X | ... | X.X |
| Novelty (20%) | X.X | X.X | ... | X.X |
| Methodological Rigor (20%) | X.X | X.X | ... | X.X |
| Theoretical Coherence (15%) | X.X | X.X | ... | X.X |
| Defense Readiness (10%) | X.X | X.X | ... | X.X |
| Citation Integrity (10%) | X.X | X.X | ... | X.X |
| **Composite** | **X.XX** | **X.XX** | ... | **X.XX** |

## Final Ranking
1. **#1**: Proposal <X> — <Title> (Composite: X.XX)
2. **#2**: Proposal <Y> — <Title> (Composite: X.XX)
...
```

### Template 4B: Single Proposal Deep-Dive / Focused Chapter Audit Mode

```markdown
# Academic Council Evaluation Report (<Single Proposal Deep-Dive | Focused Audit: Bab X>)

## Executive Summary
- **Date**: <YYYY-MM-DD>
- **Evaluator**: Academic Council (<N>-seat panel: <list active seats>)
- **Target**: "<Title / Chapter>" | Field: <academic_field> | Period: <research_period>
- **Chairman Verdict**: [READY FOR SEMINAR | CONDITIONAL REVISION | MAJOR RESTRUCTURING] (Composite: X.XX / 5.0)

## Evaluation Scorecard

<!-- For Focused Audits, mark unseated dimensions `N/A (not seated)` and renormalize active weights to 100%. -->
| Dimension | Baseline Weight | Active Weight | Score (1.0–5.0) | Evidence / Basis |
|:---|:---:|:---:|:---:|:---|
| Feasibility | 25% | XX.X% | X.X | [concrete BEI/regulatory basis] |
| Novelty (Kebaruan) | 20% | XX.X% or N/A | X.X or N/A | [basis or N/A (not seated)] |
| Methodological Rigor | 20% | XX.X% | X.X | [concrete formula/model basis] |
| Theoretical Coherence | 15% | XX.X% or N/A | X.X or N/A | [basis or N/A (not seated)] |
| Defense Readiness | 10% | XX.X% or N/A | X.X or N/A | [basis or N/A (not seated)] |
| Citation Integrity | 10% | XX.X% or N/A | X.X or N/A | [basis or N/A (not seated)] |
| **Composite** | **100%** | **100.0%** | **X.XX** | **Weighted sum across active dimensions** |
```

### Shared Body Sections (Append to Template 4A or 4B)

```markdown
---

## Seat Findings (Include Only Active Seats; Record `Status: not run` for Any Failed Seat)

### Seat <k>: <Seat Name>
- **Status**: Completed | `Status: not run`
- **Score**: X.X / 5.0
- **Verified Checks / Strengths**: [specific formulas, rules, or invariants audited]
- **Verified Weaknesses**: [concrete issues with evidence — OR `no critical/high gaps verified` after listing audited checks]
- **Domain Verification Log**: [proxy formula checks or `[VERIFIED: <url>]` / `[UNVERIFIED: <reason>]` regulatory citations]

---

## Citation Forensics — Verified Reference Bank *(Include when Citation Auditor is seated)*

*(Include ONLY `[VERIFIED: <DOI/URL>]` and `[UNVERIFIED - PAYWALL/OFFLINE: <missing_fields>]` rows here. Never mix `[FABRICATED/VETOED]` entries into this table.)*

| # | Authors | Year | Title | Journal & Rank | Status | DOI / URL |
|---|---------|------|-------|----------------|--------|-----------|
| 1 | [name] | [YYYY] | [title] | [journal / rank] | `[VERIFIED: <DOI/URL>]` / `[UNVERIFIED - PAYWALL/OFFLINE: <missing_fields>]` | [link or N/A] |

### Quarantined / Rejected Draft Citations

*(Segregated non-citable quarantine for all `[FABRICATED/VETOED]` draft citations—do NOT copy into daftar pustaka. Record `None detected` if zero draft citations failed verification.)*

| # | Draft Citation As Written | Failure Reason | Status | Verified Replacement (if any) |
|---|---------------------------|----------------|--------|-------------------------------|
| 1 | [raw draft citation] | [non-existent journal / mismatched DOI / unverified author-year] | `[FABRICATED/VETOED]` | [Row # in Verified Reference Bank or None] |

---

## Thesis Defense Simulation *(Include when Defense Simulator is seated)*

**Defense Readiness Score**: X.X / 5.0

| # | Examiner Question | Suggested Answer Framework |
|---|-------------------|---------------------------|
| 1 | [pointed question] | [structured answer strategy] |

---

## Prioritized Weakness Matrix

| Severity | Target | Finding | Seat |
|:---|:---|:---|:---|
| CRITICAL | [Proposal/Bab] | [description — or `None verified`] | [seat] |
| HIGH | [Proposal/Bab] | [description — or `None verified`] | [seat] |
| MEDIUM | [Proposal/Bab] | [description — or `None verified`] | [seat] |
| LOW | [Proposal/Bab] | [description — or `None verified`] | [seat] |

*(Disclose any `Status: not run` seats explicitly here; any `not run` seat blocks certification.)*

---

## Concrete Action Plan

### Immediate Fixes (Week 1–2)
1. [concrete action tied to CRITICAL/HIGH findings]

### Before Seminar / Submission (Week 3–4)
1. [concrete action]

### Data & Verification Phase
1. [concrete action with realistic BEI data extraction timeline]

## Certification
- **Status**: VICTORY CONFIRMED (Zero workspace mutations, zero `not run` seats) | CERTIFICATION BLOCKED (`Status: not run` or critical audit failure)
```

---

## 5. Arithmetic Reconciliation

Before certification, the Chairman must verify:
- All scored dimensions fall within `[1.0, 5.0]`.
- Active dimension weights sum to exactly `100%` (after proportional renormalization in focused audits).
- Each target's `Composite` equals $\sum (\text{score}_i \times \text{active\_weight}_i)$ rounded consistently to 2 decimal places.
- In Comparative Mode, the Final Ranking order strictly matches Composite scores (no contradictions).
- Zero seated reviewers have `Status: not run`.
