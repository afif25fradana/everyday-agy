# Scorecard Rubric & Chairman Synthesis Template (`scorecard-rubric.md`)

This specification defines the numerical evaluation rubric, mathematical reconciliation standards, and report template required for Council evaluation deliverables.

---

## 1. The Four-Dimensional Rubric (Scale 1.0 - 5.0)

Every active Council seat (`N` = 3 to 5) independently evaluates the subject across four standard axes:

### Axis 1: Technical Rigor & Correctness
- **5.0**: Flawless invariant preservation, exhaustive edge-case coverage, zero dropped defensive mechanisms, airtight typing/concurrency.
- **4.0**: Minor edge-case gaps, solid core invariants, sound state management.
- **3.0**: Acceptable standard logic, but vulnerable to specific concurrency, timeout, or boundary anomalies.
- **2.0**: Incomplete error handling, unhandled edge cases, potential data loss under load.
- **1.0**: Broken logic, severe safety violations, unmitigated race conditions.

### Axis 2: Developer Ergonomics & Operational Friction
- **5.0**: Zero unnecessary ceremony, clear operator paths, intuitive error recovery, minimal cognitive load.
- **4.0**: Minimal friction, clear guidelines, rare unnecessary verification prompts.
- **3.0**: Moderate ceremony, rigid gates for simple tasks, manual workarounds needed for edge cases.
- **2.0**: High operational friction, frequent false-positive rejections, workflow deadlocks.
- **1.0**: Impractical for daily engineering, causes developer paralysis or safety-gate bypasses.

### Axis 3: Modularity, Maintainability & Context Efficiency
- **5.0**: Clean progressive disclosure / modular boundaries, zero dead weight or duplication, concise plain-spoken structure.
- **4.0**: Good modularity and brevity, minor padding, cleanly separated responsibilities.
- **3.0**: Noticeable duplication or unnecessary coupling across modules/documents.
- **2.0**: Severe duplication, oversized templates/modules, or heavy cognitive/token bloat.
- **1.0**: Monolithic bloat, severe dilution of invariants, unmaintainable sprawl.

### Axis 4: Specification & Standards Alignment
- **5.0**: Full harmony with authoritative runtime/vendor specs, ADRs, and verified industry practices.
- **4.0**: Minor naming or convention discrepancies, aligned with current standards.
- **3.0**: Functional but relies on legacy conventions or misses modern verification patterns.
- **2.0**: Significant specification drift, outdated tool/API references, or contract violations.
- **1.0**: Fundamental incompatibility with runtime engine, platform contracts, or security baselines.

---

## 2. Mathematical Reconciliation & Arithmetic Closure Rules

To prevent arbitrary or hallucinated scoring, Chairman synthesis must satisfy exact arithmetic closure across all evaluated cells (`4 x N_seats` cells: 12 for 3 seats, 16 for 4 seats, 20 for 5 seats):

1. **Seat Composite Score (Row Average)**:
   $$\text{Seat Composite} = \frac{\text{Rigor} + \text{Ergonomics} + \text{Efficiency} + \text{Spec}}{4}$$
2. **Dimensional Column Average**:
   $$\text{Column Average} = \frac{\sum_{i=1}^{N} \text{Score}_{i}}{N}$$
3. **Grand Mean Closure**:
   The Overall Council Composite Average must match both the mean of row composites and the mean of column averages:
   $$\text{Grand Mean} = \frac{\sum \text{All Cells}}{4 \times N_{\text{seats}}} = \frac{\sum \text{Seat Composites}}{N_{\text{seats}}} = \frac{\sum \text{Column Averages}}{4}$$
4. **Grading Scale**:
   - `4.50 - 5.00`: **Grade A+ (Exemplary)**
   - `4.00 - 4.49`: **Grade A (High Distinction)**
   - `3.50 - 3.99`: **Grade B+ (Conditional Pass / Approved with Optimizations)**
   - `3.00 - 3.49`: **Grade B (Acceptable / Requires Refactoring)**
   - `< 3.00`: **Grade C or Below (Reject / Fundamental Redesign Needed)**

---

## 3. Prioritized Gap Matrix Standards

Identified deficiencies map to four discrete urgency tiers:

- **CRITICAL**: Runtime breakage, tool/API call failures, exploitable security vulnerabilities, or execution deadlocks.
- **HIGH**: Contract/interface mismatches, heavy operator friction, silent error masking, or missing rollback safety.
- **MEDIUM**: Cross-file duplication, missing edge-case test coverage, or excessive module/prompt weight.
- **LOW**: Minor stylistic inconsistencies or cross-platform convenience improvements.

---

## 4. Chairman Evaluation Report Template

```markdown
# Council Evaluation Report: <Subject Title>

**Date**: <YYYY-MM-DD>  
**Auditing Body**: Antigravity Council Review Panel (<N> Specialized Seats)  
**Investigation Mode**: Strictly Read-Only  
**Subject**: `<Target Path>`  

---

## 1. Executive Summary & Chairman Verdict
- **Chairman's Verdict**: [APPROVED | APPROVED WITH OPTIMIZATIONS | REJECTED]
- **Composite Score**: X.XX / 5.0 (Grade: [A+/A/B+/B/C])
- **Executive Rationale**: <2-3 paragraphs explaining core strengths and verified deficiencies.>

---

## 2. Numerical Scorecard Matrix (4 x <N> Cells)

<!-- Include one row per active seat (3 to 5 seats). Mark any failed/timed-out seat as `Status: not run` (invalidates certification). -->

| Council Seat | Rigor | Ergonomics | Efficiency | Spec Alignment | Seat Composite |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Seat 1: <Name>** | X.XX | X.XX | X.XX | X.XX | **X.XX** |
| **Seat 2: <Name>** | X.XX | X.XX | X.XX | X.XX | **X.XX** |
| **Seat 3: <Name>** | X.XX | X.XX | X.XX | X.XX | **X.XX** |
| *(Add Seat 4 / Seat 5 rows if active)* | ... | ... | ... | ... | ... |
| **Column Averages** | **X.XX** | **X.XX** | **X.XX** | **X.XX** | **Grand Mean: X.XX** |

---

## 3. Key Findings with Concrete Line Citations
- `<file.ext#Lxx-Lyy>`: <Verbatim discrepancy or invariant violation observed>

---

## 4. Prioritized Gap Matrix
- **CRITICAL**: <List items or "None verified">
- **HIGH**: <List items or "None verified">
- **MEDIUM**: <List items or "None verified">
- **LOW**: <List items or "None verified">

---

## 5. Non-Breaking Actionable Roadmap
- **Phase 1: Immediate Gaps**
- **Phase 2: Ergonomics & Reliability**
- **Phase 3: Maintainability & Modularity**
- **Phase 4: Standards & Modernization**
*(Note: When `spec-verifier` is seated, every roadmap API/library action must be tagged `[VERIFIED]`, `[UNVERIFIED]`, or `[VETOED]` against Context7 or official documentation.)*

---

## 6. Certification
- **Auditor**: Victory Auditor Independent Verification
- **Status**: VICTORY CONFIRMED (Zero repository mutations, zero package installs)
```
