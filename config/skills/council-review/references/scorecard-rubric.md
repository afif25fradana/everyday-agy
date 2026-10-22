# Scorecard Rubric & Chairman Synthesis Template (`scorecard-rubric.md`)

This specification defines the numerical evaluation rubric, mathematical reconciliation standards, and report template required for Council evaluation deliverables.

---

## 1. The Four-Dimensional Rubric (Scale 1.0 – 5.0)

Every Council seat independently evaluates the subject across four standard axes:

### Axis 1: Technical Rigor & Correctness
- **5.0**: Flawless invariant preservation, exhaustive edge-case coverage, zero dropped defensive mechanisms, airtight typing/concurrency.
- **4.0**: Minor edge-case gaps, solid core invariants, sound state management.
- **3.0**: Acceptable standard logic, but vulnerable to specific concurrency, timeout, or boundary anomalies.
- **2.0**: Incomplete error handling, unhandled edge cases, potential data loss under load.
- **1.0**: Broken logic, severe safety violations, unmitigated race conditions.

### Axis 2: Developer Ergonomics & Operational Friction
- **5.0**: Zero ceremony on trivial tasks, clear single-click action paths, intuitive error recovery, zero cognitive fatigue.
- **4.0**: Minimal friction, clear guidelines, rare unnecessary verification prompts.
- **3.0**: Moderate ceremony, rigid gates for simple tasks, manual workarounds needed for edge cases.
- **2.0**: High operational friction, frequent false-positive rejections, workflow deadlocks.
- **1.0**: Impractical for daily engineering, causes developer paralysis or total bypass of safety gates.

### Axis 3: Token & Context Efficiency (Anti-Slop)
- **5.0**: Perfectly modular progressive disclosure, zero redundant text, concise plain-spoken prose, optimal context utilization.
- **4.0**: Good brevity, minor narrative padding (<1 KB), well-partitioned references.
- **3.0**: Noticeable text repetition (1–3 KB duplicate checklists), moderate greedy retrieval risk.
- **2.0**: Severe text duplication (>5 KB), heavy prompt templates, repetitive guidelines burning context.
- **1.0**: Monolithic prompt bloat, high token burn on every turn, severe context window dilution.

### Axis 4: Specification & Community Alignment
- **5.0**: Full harmony with official engine tool signatures, adheres to industry state-of-the-art standards (Anthropic, SWE-agent, Karpathy).
- **4.0**: Minor tool naming or script discrepancies, competitive with leading community practices.
- **3.0**: Functional but relies on legacy naming conventions, missing modern community patterns (e.g. repro-first tests).
- **2.0**: Significant specification drift, script execution failures, outdated tool references.
- **1.0**: Fundamental incompatibility with runtime engine or host platform.

---

## 2. Mathematical Reconciliation & Arithmetic Closure Rules

To prevent arbitrary or hallucinated scoring, the Chairman synthesis must satisfy exact arithmetic closure across all 16 cells:

1. **Seat Composite Score (Row Average)**:
   $$\text{Seat Composite} = \frac{\text{Rigor} + \text{Ergonomics} + \text{Token} + \text{Spec}}{4}$$
2. **Dimensional Column Average**:
   $$\text{Column Average} = \frac{\sum_{i=1}^{N} \text{Score}_{i}}{N}$$
3. **Grand Mean Closure**:
   The Overall Council Composite Average must match both the mean of row composites and the mean of column averages:
   $$\text{Grand Mean} = \frac{\sum \text{All 16 Cells}}{16} = \frac{\sum \text{Seat Composites}}{N_{\text{seats}}} = \frac{\sum \text{Column Averages}}{4}$$
4. **Grading Scale**:
   - `4.50 – 5.00`: **Grade A+ (Exemplary)**
   - `4.00 – 4.49`: **Grade A (High Distinction)**
   - `3.50 – 3.99`: **Grade B+ (Conditional Pass / Approved with Optimizations)**
   - `3.00 – 3.49`: **Grade B (Acceptable / Requires Refactoring)**
   - `< 3.00`: **Grade C or Below (Reject / Fundamental Redesign Needed)**

---

## 3. Prioritized Gap Matrix Standards

Identified deficiencies must be mapped to four discrete urgency tiers:

- **CRITICAL**: Runtime engine breakage, tool call failures, security vulnerabilities, or hard execution deadlocks.
- **HIGH**: Slash command mismatches, heavy operator friction, or missing rollback capabilities.
- **MEDIUM**: Cross-file text duplication, missing repro-first test patterns, or excessive prompt weight.
- **LOW**: Minor stylistic inconsistencies or cross-platform shell convenience enhancements.

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
- **Composite Score**: X.XX / 5.0 (Grade: [A/B+/B/C])
- **Executive Rationale**: <2-3 paragraphs explaining the core strengths and critical deficiencies.>

---

## 2. Numerical Scorecard Matrix

| Council Seat | Rigor | Ergonomics | Token Efficiency | Spec Alignment | Seat Composite |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Seat 1: <Name>** | X.XX | X.XX | X.XX | X.XX | **X.XX** |
| **Seat 2: <Name>** | X.XX | X.XX | X.XX | X.XX | **X.XX** |
| **Seat 3: <Name>** | X.XX | X.XX | X.XX | X.XX | **X.XX** |
| **Seat 4: <Name>** | X.XX | X.XX | X.XX | X.XX | **X.XX** |
| **Column Averages** | **X.XX** | **X.XX** | **X.XX** | **X.XX** | **Grand Mean: X.XX** |

---

## 3. Key Findings with Concrete Line Citations
- `<file.ext#Lxx-Lyy>`: <Verbatim discrepancy or invariant violation observed>

---

## 4. Prioritized Gap Matrix
- **CRITICAL**: <List items>
- **HIGH**: <List items>
- **MEDIUM**: <List items>
- **LOW**: <List items>

---

## 5. Non-Breaking Actionable Roadmap
- **Phase 1: Immediate Gaps**
- **Phase 2: Ergonomics & Friction**
- **Phase 3: Token Hygiene & Progressive Disclosure**
- **Phase 4: Community Upgrades**

---

## 6. Certification
- **Auditor**: Victory Auditor Independent Verification
- **Status**: VICTORY CONFIRMED (Zero file mutations, zero package installs)
```
