# ADR-0007: Defensive Audit-First Development Workflow Harmonization and Anti-Cheating Architecture

## Status
Accepted

## Date
2026-10-22

## Context
Following a read-only Council evaluation (`teamwork_preview`) of `audit-dev-workflow` across 4 independent review seats (Antigravity Spec & Tooling, Developer Ergonomics, Token & Context Efficiency, and GitHub Community Benchmarking), several critical architectural inconsistencies, friction points, and token redundancies were identified:

1. **Tooling Dualism & Engine Discrepancies**:
   - `SKILL.md` instructed direct execution using legacy or subagent tool names (`replace_file_content`, `write_to_file`) for the Parent Agent, whereas Antigravity's native Parent Agent tools are `edit_file` and `write_file`.
   - Automation helper scripts in `scripts/` called raw `git` instead of `rtk git`, violating `<RULE[user_global]>`.
   - Slash command triggers omitted the canonical folder-bound command `/audit-dev-workflow`.
2. **Operational Deadlock on Testless Repositories**:
   - Inflexible requirements for CLI test commands and exit code 0 (`handoff-spec.md` L11, L47) caused execution deadlocks on documentation, configuration, and prototype repositories lacking automated test harnesses.
3. **Ergonomic Friction & Missing Rollback**:
   - Gate 1 relied on chat polling without utilizing Antigravity's native `ArtifactMetadata.RequestFeedback: true` (UI "Proceed" button).
   - Checkpoints could be created via `New-AuditCheckpoint.ps1`, but lacked an automated inverse script for single-command rollback.
4. **Token Inefficiency & Greedy Retrieval Hazards**:
   - Cross-file duplication of the Five-Axis rubric, Tier 0 criteria, and return-loop protocols across `SKILL.md`, `handoff-spec.md`, `prompt-templates.md`, and `pitfalls.md` created context bloat and violated ADR-0002.
5. **Community Verification Gaps**:
   - Absence of SWE-agent style Repro-First failing tests and fault injection protocols to detect mock-cheating in unit tests.

## Decision

1. **Harmonize Parent vs. Subagent Tooling Protocol**:
   - Formally document runtime tool dualism: Parent Agent uses native `read_file`, `edit_file`, and `write_file`; Subagents utilize `view_file`, `replace_file_content`, and `write_to_file`.
   - Update `New-AuditCheckpoint.ps1` and `Export-AuditEvidence.ps1` to execute `rtk git` with automatic fallback to `git`.
   - Add canonical `/audit-dev-workflow` slash command mapping to frontmatter.
2. **Eliminate Testless Repository Deadlocks**:
   - Establish the `[TEST HARNESS: NONE]` protocol, permitting static verification (e.g. `python -m py_compile`, `rtk npx eslint`), build checks, or dry-runs as valid verification evidence.
3. **Implement Automated Rollback & Native UI Gating**:
   - Implement `Restore-AuditCheckpoint.ps1` to enable one-command recovery (`git reset --hard checkpoint-$Task` or `.bak` restore).
   - Integrate `ArtifactMetadata.RequestFeedback: true` into Gate 1 proposal artifacts for native one-click "Proceed" approval.
4. **Adopt Community Anti-Cheating & Repro Patterns**:
   - Require SWE-agent style Repro-First failing tests (RED) in Phase 1 before proposing bug fixes.
   - Enforce Fault Injection in Phase 4 (Axis 5) to verify test suite integrity and eliminate mock-cheating.
5. **Refactor Reference Directory to Single Source of Truth (SSOT)**:
   - Establish `handoff-spec.md` as the normative contract schema.
   - Refactor `prompt-templates.md` into lean execution prompts referencing `handoff-spec.md`.
   - Strip duplicate 5-axis narrative from `pitfalls.md`, reserving it strictly for concrete traps and anti-patterns.

## Consequences
- **Positive**:
  - Eliminates runtime tool-not-found errors during Parent Agent execution.
  - Guarantees `<RULE[user_global]>` compliance across all PowerShell helper scripts.
  - Unblocks agent execution on documentation, DevOps, and infrastructure codebases.
  - Prunes redundant context weight across reference files, reducing token overhead and preventing greedy retrieval hazards.
  - Fortifies test veracity with repro-first verification and fault injection against mock-cheating.
- **Trade-offs / Operational Requirements**:
  - PowerShell scripts require `-ExecutionPolicy Bypass` when invoked in Windows host environments.
