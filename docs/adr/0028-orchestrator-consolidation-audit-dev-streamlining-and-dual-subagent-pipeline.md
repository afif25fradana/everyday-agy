# ADR-0028: Orchestrator Script Consolidation, Audit-Dev Streamlining, and Dual-Subagent Pipeline

## Status
Accepted

## Date
2026-11-09

## Context
As the `everyday-agy` framework evolved across ADR-0007, ADR-0015, ADR-0019, and ADR-0027, redundant definitions and unclear boundaries emerged between the two development workflow skills:

1. **Rule Duplication & Cognitive Overhead (~40–60% Overlap)**:
   `config/skills/orchestrator/SKILL.md` and `config/skills/audit-dev-workflow/SKILL.md` maintained redundant definitions for Step 0 Zero-Read Triage, rollback checkpoint CLI operations (`New-AuditCheckpoint.ps1`, `Restore-AuditCheckpoint.ps1`), Single-Pass TDD verification, monotonic stop-rule counters ($\le 2$), syntax interception gates, and reviewer accounting (`Status: not run`). The Parent Agent loaded two overlapping runbooks (~30KB), consuming prompt tokens and creating duplicate maintenance.
2. **Inverted Architectural Responsibilities**:
   `audit-dev-workflow` was originally conceived as an audit-centric development workflow, but became overloaded with Parent execution mechanics (checkpointing, branch deletion, commit conventions, push automation). Meanwhile, the Five-Axis Review Rubric was coupled to an execution runbook instead of serving as an independent evaluation rubric.
3. **Auditor Agent Disconnect**:
   Because `audit-dev-workflow` contained mutating execution logic, binding it to the read-only `code-auditor` subagent was problematic. Consequently, `config/agents/code-auditor/agent.md` lacked direct binding to the Five-Axis Skeptical Audit Rubric, 4-bucket dispute resolution rules, and the 20 engineering pitfalls.
4. **Misplaced Fleet Infrastructure**:
   `references/subagent-patterns.md` (the 10-agent fleet catalog, model selection invariants, and 4-slot prompt templates) and `references/handoff-spec.md` were hosted under `audit-dev-workflow/references/` rather than under `orchestrator/`.
5. **Cross-Checking External APIs in Planning**:
   While code auditing (`code-auditor`) was routine, cross-checking proposed external APIs against official documentation (`spec-verifier`) during Phase 1 planning was informal.

## Decision

We separate execution mechanics from code quality rubrics across three components:

### 1. Consolidate End-to-End Execution Lifecycle into `orchestrator`
- **Primary Runbook**: `config/skills/orchestrator/SKILL.md` governs the execution lifecycle across all tiers:
  - **Step 0**: Blast Radius Sizing & Zero-Read Triage (Tier 0–3, mid-execution escalation, package installs).
  - **Phase 1**: Investigation, Read-Only Diagnostic Exploration, and Gate 1 Proposal Artifact (`gate1_proposal.md`).
  - **Phase 2**: Verified Rollback Checkpoint Establishment (`New-AuditCheckpoint.ps1`).
  - **Phase 3**: Execution via Single-Pass TDD (`tdd-guide`: RED -> GREEN -> Fast Syntax Check) or serialized Domain Specialists.
  - **Phase 4**: Local Verification, Direct Parent CLI Test Runner, Diff Audit (`code-auditor`), and Conditional Spec Verification (`spec-verifier`).
  - **Phase 5**: Gate 2 Programmatic Diff Injection (`Update-Gate2Diff.ps1`), Commit Discipline (`clean-docs`), and Non-Interactive CI.
- **Relocate Scripts & References**:
  - Move `config/skills/audit-dev-workflow/scripts/*` (7 files: `New-AuditCheckpoint.ps1`, `Restore-AuditCheckpoint.ps1`, `Update-Gate2Diff.ps1`, `Test-PowerShellCommandSafety.ps1`, `AuditCheckpoint.Tests.ps1`, `Test-PowerShellCommandSafety.Tests.ps1`, `YamlValidation.Tests.ps1`) to `config/skills/orchestrator/scripts/`.
  - Move `subagent-patterns.md` and `handoff-spec.md` to `config/skills/orchestrator/references/`.
  - Calibrate all relative link depths: 3 levels from `SKILL.md` (`../../../docs/adr/`) and 4 levels from `references/` (`../../../../docs/adr/`).

### 2. Codify the Mandatory Two-Stage Planning Verification Pipeline in Phase 1
- **Phase 1 Pre-Gate 1 Verification Pipeline**:
  - Whenever `code-auditor` (or `system-architect`) completes a diagnostic audit or discovery pass in `scratch/` proposing fixes, migrations, or dependencies (**Stage 1a**), the Parent Agent MUST automatically dispatch **`spec-verifier` (Stage 1b)** before synthesizing `gate1_proposal.md` or presenting findings to the operator.
  - `spec-verifier` cross-checks all proposed API signatures, configuration schemas, CLI flags, and runtime constraints against Context7 MCP (`resolve-library-id` $\rightarrow$ `query-docs`) and version-locked web documentation (`deep-web-research`).
  - Invalid API calls, deprecated options, and version incompatibilities are caught and remediated in `scratch/` prior to Gate 1 proposal drafting.
- **Phase 4 Conditional Verification**: In Phase 4 (Pre-Gate 2), `code-auditor` audits the unified diff against the Five-Axis rubric; `spec-verifier` is invoked conditionally only if Phase 3 introduced unverified external APIs not already certified at Gate 1.

### 3. Streamline `audit-dev-workflow` into `audit-dev`
- **Rename & Invariant Preservation**:
  - Rename `config/skills/audit-dev-workflow/` to `config/skills/audit-dev/`.
  - Frontmatter declares `name: audit-dev` with description `"Defensive developer audit standard (/audit-dev): caller tracing, pre-flight hazard analysis, and Five-Axis verification."` (121 chars $\le 128$).
  - Preserves the repository skill invariant of exactly 15 bespoke skills under `config/skills/`.
- **Standalone Quality Rubric**:
  - Strip execution mechanics, checkpoint CLI snippets, commit discipline, and subagent boilerplate.
  - Focus `config/skills/audit-dev/SKILL.md` directly on:
    1. **Two-Stage Spec-First Review Process**: Stage 1 Spec Compliance $\rightarrow$ Stage 2 Code Quality ("Skip Style" Directive).
    2. **The Five-Axis Skeptical Audit Rubric**:
       - *Axis 1*: Correctness & Invariants (boundary values, state transitions, caller blast radius, async ordering, modern LTS floors).
       - *Axis 2*: Security & Attack Surface (tainted input tracing, Anti-False-Positive Exploitability Invariant, secret scanner hygiene).
       - *Axis 3*: Over-Engineering / Ponytail YAGNI & Anti-Slop (shortest working diff, stdlib reuse, stripping generic AI comments).
       - *Axis 4*: Edge Cases, Silent Failures & Resource Leaks (no swallowed exceptions, no masking fallback defaults, guaranteed cleanup).
       - *Axis 5*: Test Integrity, Anti-Mock Cheating & Fault Injection (no mocking code under test, positive assertion counts, condition flipping).
    3. **Skeptical Dispute & Verification Rules**: Planning Anti-False-Positive Rule, compact 4-Bucket Resolution Taxonomy (`CONTEST | ESCALATE | PROPOSE FIX | DECLINE`) and Factual Dispute Format referencing `orchestrator/references/handoff-spec.md` as SSOT, Failed Reviewer Accounting (`Status: not run`), and Settled Findings Immunity.
    4. **Engineering Pitfalls Reference**: Retain `references/pitfalls.md` (20 empirical agentic, logic, and shell traps).

### 4. Bind `audit-dev` to `code-auditor` Manifest
- In `config/agents/code-auditor/agent.md`:
  - Add `- audit-dev` to `skills:` frontmatter.
  - Add Step 2 to `Mandatory Skill Activation Gate`: Mandate loading `audit-dev/SKILL.md` for diff audits and skeptical verification.

### 5. Cross-Repository Path Parity
- Update all script and workflow paths across the repository:
  - `config/GEMINI.md`: Update rule 1 workflow guidance and rule 64 AST safety validator path.
  - `.github/workflows/ci.yml` & `.github/pull_request_template.md`: Update test suite execution paths to `config/skills/orchestrator/scripts/*.Tests.ps1`.
  - `config/skills/contract-first/SKILL.md`, `config/skills/database-migrations/SKILL.md`, `config/skills/spec-kit/SKILL.md`: Update links to `audit-dev` and `orchestrator`.
  - `README.md`, `TOOLKIT.md`, `LICENSE`: Update skill lists, license text, and tool commands.

## Alternatives Considered & Rejected

- **Alternative A: Merge everything into `orchestrator` and delete `audit-dev-workflow` entirely**:
  - *Rejected*: Violates the Single Responsibility Principle. Forces `orchestrator` to hold 400+ lines of code quality rubrics, 20 pitfalls, and anti-mock cheating heuristics. Leaves `code-auditor` without a modular skill to bind to. Reduces bespoke skill count to 14.
- **Alternative B: Place scripts under `config/scripts/` at repository root**:
  - *Rejected*: Violates Antigravity canonical skill directory anatomy (`skills/<skill>/{scripts,references}`) defined in `agy-customizations`. Decreases modularity and portability when skills are distributed or installed across environments.

## Consequences

- **Positive**:
  - **Eliminates Redundancy**: Cuts ~40% duplicate rule text across workflow skills; Parent Agent only loads `orchestrator/SKILL.md`.
  - **Clean Responsibility Separation**: `orchestrator` owns execution lifecycle; `audit-dev` owns quality criteria and skeptical auditing.
  - **Auditor Alignment**: `code-auditor` directly carries its authoritative Five-Axis evaluation rubric.
  - **Early API Verification**: Pre-Gate 1 `spec-verifier` checks catch invalid library calls before plans are approved or executed.
  - **Standard Directory Anatomy**: Standardized on canonical `SKILL.md`, `scripts/`, `references/` directory layout.
  - **Preserved Skill Count**: Maintains exactly 15 bespoke skills in the repository.
- **Negative / Trade-offs**:
  - Required updating paths across CI workflows, PR templates, and cross-skill links (mitigated by automated test suites).
