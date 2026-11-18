# ADR-0004: Code Review Council, Skeptical Audit Rubric, and Verification Rules

## Status
Accepted

## Date
2026-11-18

## Context
Single-perspective reviews miss cross-cutting defects, rely on memory instead of current documentation, slip into polite agreement (`"Great point!"`), or treat timed-out reviewers as having zero findings. Integrating external review tools also hit practical snags:
1. **Coupled workflow and rubric**: `audit-dev-workflow` mixed parent execution mechanics (git checkpoints, commits) with code quality criteria, so `code-auditor` (read-only) could not bind cleanly to the evaluation rubric.
2. **Third-party skill mismatches**: Trail of Bits security skills (`audit-context-building`, `differential-review`) targeted Claude Code's `Workflow` and `.js` tooling, while Elephant-Goldfish Model (EGM) lacked Antigravity manifest fields, nested subagents recursively, and skipped test verification.
3. **Research outside software engineering**: While working on my undergraduate accounting and finance thesis using Indonesia Stock Exchange (IDX/BEI) secondary data, generic software review roles could not catch panel econometric errors (regression model selection, proxy formulas, endogeneity), BEI data availability gaps, or hallucinated journal citations.

## Decision

### 1. Standalone Skeptical Audit Rubric (`config/skills/audit-dev/`)
I stripped execution mechanics out of `audit-dev-workflow` (moved to `orchestrator`) and refactored `config/skills/audit-dev/` into a dedicated quality standard bound directly to `code-auditor`:
- **Two-Stage Spec-First Review**: Stage 1 checks specification compliance (`gate1_proposal.md` or requirements); Stage 2 evaluates the Five-Axis Rubric under a "Skip Style" directive so reviewers focus on substantive defects rather than formatting preferences.
- **Five-Axis Skeptical Rubric & 20 Pitfalls (`references/pitfalls.md`)**:
  1. *Correctness & Invariants*: Boundary limits, state transitions, `rtk rg` caller blast radius, active LTS floors, and preserving existing timeouts/guards.
  2. *Security & Attack Surface*: Source-to-sink taint tracing paired with the **Anti-False-Positive Exploitability Invariant** (every P0/P1 claim requires a concrete exploit path, never theoretical guesses), plus bracketed `<...>` and `<TEST_HASH_SANITIZED>` secret hygiene.
  3. *Over-Engineering / Ponytail YAGNI & Anti-Slop*: Shortest working diff, existing helper reuse, and non-obvious *why* comments only.
  4. *Edge Cases, Silent Failures & Resource Leaks*: Zero swallowed exceptions, no masking fallback defaults (`.catch(() => [])`), and deterministic handle/lock cleanup.
  5. *Test Integrity, Anti-Mock Cheating & Fault Injection*: Never mock the unit under test, verify happy and error paths, and verify tests catch condition-flipping mutations.

### 2. Cold Grounding and Differential Risk Audits (Trail of Bits Ports)
I adapted Trail of Bits' security skills to Antigravity subagent and scratch primitives (`<appDataDir>\brain\<conversation-id>\scratch\<task>\`):
- **`audit-context-building`**: Compiles function-by-function invariants, callers, and unenforced assumptions (explicitly tagged `nothing found`) before any vulnerability hunting begins.
- **`differential-review`**: Organized under canonical `references/` (`adversarial.md`, `methodology.md`, `patterns.md`, `reporting.md`). It classifies PRs by security risk rather than line count, checks regressions against git history, and separates inline reading (Tier 0/1) from subagent diff delegation (Tier 2/3).

### 3. Deliberative `council-review` via `teamwork`
High-stakes Tier 3 evaluations run through `config/skills/council-review/` using a single read-only call to `invoke_subagent(TypeName: "teamwork", ...)` (updated from the deprecated `teamwork_preview` name):
- **4-Stage Execution Lifecycle**:
  - *Stage 1 (Cold Context Grounding)*: Baseline invariants via `audit-context-building` and zero-read scoping (`rtk git status`, `rtk rg`), with deep read-only invariant mapping running concurrently inside `teamwork` Phase 0 Explorers.
  - *Stage 2 (Operator Council Formation)*: Parent aligns 3-5 seats from the 10-seat `references/seat-catalog.md`, evaluation focus, and deliverable format in one concise plain-text turn without `ask_question`, loading the parameterized `R1..R<N>` dispatch contract on demand from `references/dispatch-template.md` into `prompt_draft.md` and pausing for explicit operator confirmation.
  - *Stage 3 (Autonomous `teamwork` Deliberation)*: Sentinel initializes scratch; Project Orchestrator runs parallel read-only seat explorers using the approved `R1..R<N>` prompt loaded on demand from `references/dispatch-template.md`; Chairman synthesis normalizes and collapses duplicate findings via the **Deduplication Barrier** (`${file}::${normalize(evidence)}`, taking max severity); fail-closed Adversarial Challengers verify line citations (`file.ext#Lxx-Lyy`) and dynamic `4 x N_seats` arithmetic closure; Forensic Auditor confirms zero repository mutations or installs; Victory Auditor certifies completion.
  - *Stage 4 (Certified Deliverable Packaging)*: Parent packages the Chairman verdict, dynamic `4 x N_seats` scorecard matrix (12, 16, or 20 cells with exact row, column, and grand-mean arithmetic closure per `references/scorecard-rubric.md`), line-cited discrepancies, prioritized gap matrix (including any `Status: not run` disclosures), and non-breaking remediation roadmap.
- **Anti-Sycophancy & Exploitability Gate**: Scores `>= 4.50` require empirical proof or fault injection. Every seat reports verified gaps with concrete `file.ext#Lxx-Lyy` citations or explicitly documents the invariants inspected with `no critical/high gaps verified` (no forced finding quotas, no performative praise per `clean-docs`).

### 4. Empirical Finance Research Panel (`academic-council`)
Tucked alongside the software skills in `config/skills/academic-council/` is a specialized read-only research review panel I built for my accounting and finance thesis on IDX/BEI secondary market data. Disclosed upfront in `README.md`, it mirrors the 4-Stage `teamwork` lifecycle of `council-review`: single-turn plain-text operator alignment (no `ask_question` ceremony), on-demand `R1..R<N>` dispatch assembly from `references/dispatch-template.md` (`3-5` seats for full proposals; `2-5` seats for focused chapter audits), mode-adaptive scoring (`references/scorecard-rubric.md`), zero forced weakness quotas (`>= 4.50` proof gate preserved; `no critical/high gaps verified` permitted after listing audited checks), and `Status: not run` certification invalidation. Across its five primary seats (`references/seat-catalog.md`, plus optional Data Pipeline and Academic Writing extensions):
- **Econometrics & Research Methodology**: Audits panel/logistic regression models, variable proxy formulas, sampling criteria, and endogeneity or multicollinearity risks.
- **Theoretical Coherence**: Audits deductive links between grand theories (Agency, Signaling, Stakeholder, Positive Accounting) and hypothesis directions.
- **BEI/IDX Regulatory & Data Feasibility**: Verifies that proposed variables appear in public IDX annual reports, financial statement notes (CALK), or sustainability reports without assuming paid Bloomberg/Refinitiv terminals, and checks active regulatory effective dates for `<research_period>` via `search_web`—including IAI's 1 Jan 2024 3-digit SAK Indonesia renumbering (`PSAK 72 -> 115`, `71 -> 109`, `73 -> 116`, `1 -> 201`; shariah `4xx`) and BEI Papan Pemantauan Khusus revisions (`Peraturan I-X` / `II-X`).
- **Citation Forensics & Paywall Guardrail**: Verifies author names, years, journals, and DOIs via `search_web` (capped at 3 queries per unresolved reference, with Crossref/`doi.org` fallback). Paywall-blocked or offline fields are tagged `[UNVERIFIED - PAYWALL/OFFLINE: <missing_fields>]` without snippet extrapolation, while `[FABRICATED/VETOED]` entries are isolated in a segregated `Quarantined / Rejected Draft Citations` sub-table beneath the Verified Reference Bank.
- **Thesis Defense Simulator**: Generates 5–7 pointed examiner questions and suggested answer frameworks per target.
- **Mode-Adaptive Scorecards (`4A`/`4B`)**: Comparative proposals (`M >= 2`) use dynamic `M`-column Template `4A`; single-proposal deep dives and focused chapter audits use Template `4B`, marking unseated dimensions `N/A (not seated)` and proportionally renormalizing active weights to `100%`.

### 5. Primary-Source Verification (`deep-web-research`) and Dispute Rules (`handoff-spec.md`)
- **Two-Stage Verification Pipeline (`deep-web-research`)**: During Phase 1 Stage 1b (mandatory before Gate 1 when fixes/dependencies are proposed) and conditional Phase 4 Stage 4b, `spec-verifier` checks APIs against Context7 MCP (`resolve-library-id` -> `query-docs`) first, then `search_web` (targeting official domains) plus CLI fetch fallback (`gh release view`, `curl.exe` on PS 5.1, `Invoke-RestMethod`, `rtk npm view`, `rtk pip index`) in place of removed `read_url_content`. Queries are version-locked, capped at 3 per unresolved symbol, and tagged `[VERIFIED]`, `[UNVERIFIED]`, or `[VETOED]`.
- **4-Bucket Dispute Taxonomy & Review Accounting (`handoff-spec.md`, `audit-dev`)**:
  - Responses classify each review item as `CONTEST` (verified `file.ext#Lxx-Lyy` via `rtk rg`), `ESCALATE` (out-of-band context stated plainly without bloat), `PROPOSE FIX` (minimal diff), or `DECLINE` (cosmetic nit).
  - Timed-out or crashed reviewers record `Status: not run` (never "0 findings") and block sign-off.
  - `Settled` items (evidence-contested or operator-accepted) stay immune from re-litigation and are the only items passed under `Settled Findings:`, whereas `Fixed` items require re-verification.
  - `code-auditor` audits specs across 4 drift vectors (Missing Features, Incomplete Schemas, Logic Shortcuts, Architectural Divergence) while respecting the **Planning Anti-False-Positive Rule** (do not flag planned additions in Gate 1 proposals as missing code).
  - Diffs exceeding 800 lines split into Core Domain, Adapters/Integrations, and Tests/Docs chunks; test logs scrub generated tokens to `<TEST_HASH_SANITIZED>`.

## Alternatives Considered & Rejected
- **Keeping `audit-dev-workflow` coupled with execution mechanics**: Rejected because it blocked read-only binding to `code-auditor` and duplicated `orchestrator`.
- **Running raw Claude Code Trail of Bits scripts or EGM bootstrapping**: Rejected due to missing Antigravity tool contracts, nested subagent calls, missing tests, and static `README` sprawl.
- **Granting write permissions or ad-hoc unstructured prompts during reviews**: Rejected to keep diagnostic verification separate from implementation and maintain citation rigor.
- **Using software engineering review seats for BEI/IDX finance theses**: Rejected because software criteria miss econometric errors, CALK data limits, and journal citation hallucinations.

## Consequences
- **Positive**: Audits stay grounded in verified callers, Context7/official vendor docs, deduplicated evidence, and honest `not run` accounting; thesis reviews catch econometric and citation errors before data collection.
- **Negative / Operational Requirements**:
  - `teamwork` council sessions consume high token volume and are reserved for major architectural evaluations, security audits, or thesis reviews.
  - `deep-web-research` and `academic-council` citation verification require network access and fall back explicitly to `[UNVERIFIED]` when offline.
