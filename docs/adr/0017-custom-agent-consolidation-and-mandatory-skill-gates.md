# ADR-0017: Custom Agent Fleet Consolidation and Mandatory Skill Activation Architecture

## Status
Accepted

## Date
2026-11-01

## Context
A forensic audit across `everyday-agy` (commit `ca8f0fb`) identified structural and runtime gaps:
1. **Agent Redundancy & Council Drift**: `docs-architect` and `public-docs-craftsman` overlapped by ~80% across tools, skills, and `README.md` responsibilities. Furthermore, `seat-catalog.md` in `council-review` defined only 10 seats, leaving `public-docs-craftsman` unmapped and forcing split-brain delegations on combined doc/ADR updates.
2. **Progressive Disclosure Token Isolation**: In the Antigravity runtime, declaring `skills:` in YAML frontmatter only provides progressive disclosure headers (names and descriptions). The full content of `SKILL.md` is never loaded into subagent context unless explicitly read. None of the custom agent prompts mandated reading their bound skills, causing subagents to operate without their normative rule sets. Additionally, parent-only orchestration skills (`audit-dev-workflow`) polluted subagent frontmatters.
3. **AST Safety Interception Gaps**: `Test-PowerShellCommandSafety.ps1` was vulnerable to 4 concrete bypasses: `rtk proxy` command wrapping, indirect dynamic invocations (`& $()`, `& "..."`, `& @()[0]`), false positives on `git reset <checkpoint> --hard`, and PowerShell alias `.Delete()` calls.
4. **Zombie File Resurrection**: Additive-only copying in `sync.ps1` and `restore.ps1` left deleted agents or skills lingering in destination folders, resurrecting them on subsequent synchronization runs.

## Decision

1. **Consolidate Documentation Agents (Fleet of 10 Orthogonal Agents)**:
   - Merge `public-docs-craftsman` into `docs-architect` using a Mutually Exclusive Mode Selector:
     - **Mode A (Internal Architecture, Nygard ADRs & AI-Context Sync)**: Governs `docs/adr/**`, `architecture.md`, and `task_state.md`.
     - **Mode B (Public Repo Docs, Sub-Docs & GitHub Community Health)**: Governs `README.md`, `TOOLKIT.md`, `technical.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `LICENSE`, and `.github/**`.
   - Maintain `model: flash` on `docs-architect` for token efficiency, with dynamic elevation to `pro` / `inherit` when invoked by parent agents for complex architectural audits.
   - Restrict path boundaries strictly to documentation files; forbid inline source code modifications.
   - Delete `config/agents/public-docs-craftsman`, restoring exact 1-to-1 parity between the 10 custom agents and the 10 seats in `council-review/references/seat-catalog.md`.

2. **Establish Mandatory Skill Activation Gates Across All Agents**:
   - Introduce an explicit `## Mandatory Skill Activation Gate` section in every `agent.md` body. Subagents must invoke `view_file` on authoritative `SKILL.md` paths before executing analytical phases.
   - Prune parent-only orchestration runbooks (`audit-dev-workflow`) from subagent frontmatters.
   - Prune unneeded security skills (`audit-context-building`, `differential-review`) from non-security agents (`spec-verifier`, `database-reviewer`, `system-architect`).

3. **Harden PowerShell AST Validator & Test Suite**:
   - Unwrap `rtk proxy <cmd>` at the top of the command inspection loop, promoting the wrapped executable to `$cmdName` and subjecting it to all security filters (secondary shells, cmdlets, root wipes, and git safety).
   - Block all dynamic command invocations under `&` and `.` when `-not $rawCmdName` unless the first element is `[ScriptBlockExpressionAst]`.
   - Validate `git reset --hard` position-independently: filter non-flag arguments, require count == 1, and verify target ref matches `checkpoint-[A-Za-z0-9_-]+`.
   - Broaden `.Delete()` method inspection to cover aliases `gi`, `gci`, `dir`, and `ls`.
   - Expand `Test-PowerShellCommandSafety.Tests.ps1` to cover all regression vectors (72 test assertions, 100% PASS).

4. **Eliminate Zombie File Resurrection & Script Bloat**:
   - Implement destination pruning in `restore.ps1` and `sync.ps1` to safely delete stale agents and skills (while preserving decoupled upstream skills in `$externalSkills`).
   - Clean up dangling untracked directories in `Restore-AuditCheckpoint.ps1`.
   - Remove orphaned script `Export-AuditEvidence.ps1` per Ponytail YAGNI.
   - Expand CI secret scanner to monitor `sync.ps1`, `restore.ps1`, and `.github/`.

5. **Harmonize Database Migration & Contract Standards**:
   - Establish `database-migrations/SKILL.md` (5-phase Expand/Contract: Expand, Backfill, Dual-Write, Contract, Prune) as the single source of truth across `system-architect` and `database-reviewer`.
   - Explicitly note PostgreSQL non-transactional requirements for `CREATE INDEX CONCURRENTLY`.

## Consequences

- **Positive**:
  - Exactly 10 orthogonal custom agents aligned 1-to-1 with council review seats.
  - Subagents reliably load full skill rule sets into working context via explicit read gates.
  - Zero AST safety validator bypasses via proxy wrappers, dynamic invocations, or alias methods.
  - Clean, idempotent synchronization between local dotfiles (`~/.gemini/`) and Git tracking.
  - De-hyped documentation adhering strictly to `clean-docs` (no mutable vanity metrics or absolute assertions).
- **Negative / Operational Requirements**:
  - Subagents consume extra read tokens to load `SKILL.md` files during Phase 1 of their respective workflows (mitigated by progressive disclosure token savings).
