# ADR-0023: Elephant-Goldfish Model Heuristics Distillation and Platform Adaptation

## Status
Accepted

## Date
2026-11-08

## Context
Following an exhaustive Council Review of Google's Elephant-Goldfish Model (EGM v0.1.1) across six constitutional seats (`system-architect`, `silent-failure-hunter`, `spec-verifier`, `tdd-guide`, `docs-architect`, `code-auditor`), direct monolithic installation was strictly vetoed (Grade C, 2.71/5.00 composite score; SHA-256: `61058575418317FA852C3CA1A63EC1DCB4AEE264DEC9B5B7B246F81EE15EFE77`).

Forensic inspection established five critical operational and architectural barriers to raw EGM ingestion:
1. **Continuous Integration Breakage (`.github/workflows/ci.yml`)**: EGM's monolithic plugin imports 10 flat markdown personas in `agents/*.md` (breaking the 11-agent fleet count assertion: $11 \rightarrow 21$) that lack required `model:` and `tools:` frontmatter schemas, while 6 of its 7 skills exceed the $\le 128$-character description limit (up to 367 chars).
2. **Root Context Inversion (Violation of ADR-0019)**: EGM assigns the root conversation session ("The Elephant") to accumulate drafting turns, multi-round critiques, and inline code editing, resulting in massive context bloat ($>80\text{k}$ tokens), middle-loss, and cognitive split-brain. This contradicts everyday-agy's Parent Context Insulation Invariant.
3. **Subagent Nesting Runtime Breakdown**: EGM's review pipeline routes through `egm-synthesizer` acting as an intermediate delegator that attempts to spawn child subagents. Antigravity's `invoke_subagent` harness is strictly single-tiered and disallows recursive subagent invocation, collapsing EGM's synthesis hierarchy.
4. **Complete Absence of Execution Safety & Rollback**: EGM is strictly a prose-auditing tool (`resources/execution_instructions.md#L3-L6`). It provides zero automated test-runner verification, zero assertion count checks, and zero rollback protection (`Restore-AuditCheckpoint.ps1`). Its "Auto accept" mode batch-applies regex edits directly to repository files while forbidding version control tracking.
5. **Documentation Sprawl & Bit-Rot**: EGM's `egm-bootstrap` traverses directories and forces static `README.md` files into every leaf folder ("Peanuts and Hay"), creating immediate maintenance debt and bit-rot that violates clean-docs and twin-repo invariants.

However, EGM introduces high-leverage qualitative specification heuristics that dramatically curb LLM hallucination, unapproved architectural improvisations, and defensive review disputes. Following the distillation precedence established in Michael Nygard ADR-0014 (*Superpowers Heuristics Distillation and Platform Adaptation*), everyday-agy surgically harvests these mechanisms into existing skills and agents with zero plugin bloat and 100% CI compliance.

## Decision

1. **Embed The Zero-Decision Rule (`spec-kit`, `handoff-spec.md`)**:
   - In `config/skills/spec-kit/SKILL.md` (Phase 2: `/speckit.plan`), mandate that technical plans leave zero design or architectural choices to the implementer (schemas, API routes, dependencies, error codes, and boundary edge cases must be pre-determined).
   - In `config/skills/audit-dev-workflow/references/handoff-spec.md` (Gate 1 payload and schema), codify a mandatory Zero-Decision verification check.
   - **Blast-Radius Exemption**: Dogmatic zero-decision enforcement is strictly scoped to Tier 2 (`standard`) and Tier 3 (`large`) tasks; Tier 0 (`trivial`) and Tier 1 (`small bugfix`) changes are explicitly exempt per existing blast-radius tiering to prevent analysis paralysis.
   - Require explicit evaluation of alternative designs with documented trade-offs explaining why each alternative was rejected.

2. **Codify The 4-Bucket Resolution Taxonomy (`handoff-spec.md`)**:
   - In `config/skills/audit-dev-workflow/references/handoff-spec.md` (Section 6.2), replace ambiguous dispute handling with the 4-bucket epistemic classification:
     - `CONTEST`: Critique is factually inaccurate or based on a misunderstanding of code; requires checkable codebase coordinates (`file.ext#Lxx-Lyy`) verified via `rtk rg`. ("This was intentional" is banned as evidence).
     - `ESCALATE`: Critique is inaccurate, but evidence relies on out-of-band context (oral decision, unwritten convention); state plainly without adding code/doc bloat solely to satisfy an external reviewer.
     - `PROPOSE FIX`: Critique is valid; provide precise textual replacement or code diff adhering to Ponytail.
     - `DECLINE`: Finding is a cosmetic Nit with no security or functional risk; record as accepted trade-off without code changes.
   - Prohibit contesting comprehension gaps (if a fresh reader could not follow intent, context is missing) and authorial defensiveness.

3. **Harden Review Accounting & State Tracking (`handoff-spec.md`, `council-review`)**:
   - In `handoff-spec.md` (Section 6.3) and `config/skills/council-review/SKILL.md` (Acceptance Criteria), codify **Failed Reviewer Accounting (`not run` vs 0 Findings)**: any reviewer/subagent that times out or encounters an unhandled tool exception must be recorded as `Status: not run`. Treating a failed reviewer as having "0 findings" is strictly prohibited, and `not run` status invalidates clean-round convergence.
   - Codify **`Settled` vs `Fixed` Finding State Tracking**: `Settled` findings (contested with verified evidence or accepted as documented trade-offs) are immune to re-litigation by subsequent subagents; `Fixed` findings (addressed via code/doc mutation) must be re-verified by subsequent verification passes.

4. **Adopt The 4-Vector Spec Drift Audit Rubric (`code-auditor`)**:
   - In `config/agents/code-auditor/agent.md` (Audit Protocol Step 4), formalize the 4 drift vectors when comparing implementation code to specifications or ADRs: (a) *Missing Features*, (b) *Incomplete Models/Schemas*, (c) *Logic Shortcuts/Bypasses*, and (d) *Architectural Divergence*.
   - In `code-auditor/agent.md` (Execution Policy), codify the **Planning Anti-False-Positive Rule**: when reviewing Gate 1 plans, proposed new files/functions are intentions, not defects; do not flag candidate references as "Non-Existent Code" unless the plan falsely claims they already exist at HEAD.

5. **Consolidate Review Anti-Sycophancy & Documentation Craft (`clean-docs`)**:
   - In `config/skills/clean-docs/SKILL.md` (Section 1), strengthen Review Anti-Sycophancy to explicitly ban performative praise (`"Brilliant!"`, `"Perfect!"`) and polite apologies (`"I apologize"`, `"I am sorry"`).
   - In `clean-docs/SKILL.md` (Section 4), codify **The Naive Reader Paraphrase Test**: ensuring a fresh reader can plainly articulate in two paragraphs what the document proposes and how the existing system works before approving/publishing.
   - In `clean-docs/SKILL.md` (Section 5), codify **Defensive Caveat Calibration (`DROP | CALIBRATE | RELOCATE | KEEP`)** to strip speculative hedging while preserving evidence-backed constraints.
   - Rely on `clean-docs` as the single source of truth (SSOT) bound by custom agents, avoiding redundant prompt duplication across manifests or global rules (`ADR-0022`).

6. **Strict Monolithic Rejection**:
   - Completely reject raw EGM plugins, flat agent personas, nested synthesizers, and Peanuts & Hay README generation.

## Consequences

- **Positive**:
  - Eliminates premature implementation ambiguity, schema hallucination, and unapproved dependency additions via The Zero-Decision Rule.
  - Eliminates circular review debates and sycophantic concessions via the 4-Bucket Resolution Taxonomy and checkability requirements.
  - Prevents false-pass illusions in multi-agent evaluations by distinguishing `not run` from zero findings.
  - Adds surgical precision to differential reviews via the 4-Vector Spec Drift rubric.
  - Zero token inflation: keeps global rules and manifests lean by housing heuristics in specialized on-demand skills.
  - Preserves 100% CI pass rate: agent count remains 11, skills count remains 15, and all skill descriptions remain $\le 128$ characters.
- **Negative / Mitigations**:
  - Risk of over-specification on simple fixes is mitigated by explicitly exempting Tier 0 and Tier 1 tasks from The Zero-Decision Rule.
  - Authoring cognitive load is mitigated by keeping reviews grounded in existing Ponytail and clean-docs standards.
