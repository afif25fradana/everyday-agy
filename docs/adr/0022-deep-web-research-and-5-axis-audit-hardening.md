# ADR-0022: Register Deep Web Research, Fix RED Test Sequencing, Unify Scratch Paths

## Status
Accepted (Supersedes ADR-0007 in part, ADR-0014 in part, ADR-0020 in part, and ADR-0021 in part)

## Date
2026-11-05

## Context
A review of the repository configuration, agent manifests, PowerShell safety scripts, and continuous integration checks identified several issues:
1. **Command Safety and Pre-Flight Scanner Bypasses**:
   `Test-PowerShellCommandSafety.ps1` did not unwrap flags passed to command wrappers (`rtk -v git push --force`, `sudo -u root ...`), allowing wrapped subcommands to escape validation. PowerShell backtick escapes (``git push --`force``), internal flag quoting (`--"force"`), two-statement scriptblock variables (`$s.Invoke()`), `git switch -f`, `git stash drop/clear`, and `robocopy /MIR` were unblocked. Furthermore, secret scanners in `sync.ps1` and `restore.ps1` checked only a fixed extension list (`.md`, `.json`, `.yml`), leaving files like `.env`, `.key`, and `.toml` unscanned.
2. **Checkpoint and Failing Test Ordering Deadlock**:
   In `audit-dev-workflow`, creating the reproducer test (RED) was placed in Phase 1 before Gate 1 approval and Phase 2 checkpoint creation. This meant writing the test dirtied the working tree, which caused `New-AuditCheckpoint.ps1` to abort.
3. **Inconsistent Scratch Path Conventions**:
   Different skills used conflicting path conventions for session scratch storage (`$HOME/.gemini/antigravity/scratch/<task>/`, `<appDataDir>\brain\<conversation-id>\scratch\<task>\`, and unexpanded `$HOME` paths).
4. **Subagent File Creation Rules and Duplicated Prompts**:
   `build-error-resolver` is intentionally barred from creating new files (`write_to_file`) to prevent empty stub declarations, but its subagent mode section instructed it to create scratch dossiers. In addition, prompt receipt blocks were repeated across all 11 agent definitions, adding unnecessary token overhead.
5. **Skill Catalog Expansion**:
   `deep-web-research` was added as a bespoke skill for primary-source web research, bringing the total tracked skill count to 15. Continuous integration assertions needed updating to reflect this count.

## Decision
1. **Harden PowerShell AST Validator and Secret Scanners**:
   - Add token normalization in `Test-PowerShellCommandSafety.ps1` to strip backticks and internal quotes before matching commands and flags.
   - Unwrap wrapper commands (`rtk`, `sudo`, `gsudo`) past arbitrary flags until the underlying command token is reached.
   - Block `[scriptblock]::Create(...)`, `.Invoke()` on variable expressions, `git switch -f`, `git stash drop/clear`, `robocopy /MIR`, and WMI/CIM process execution methods.
   - Expand pre-flight secret scans in `sync.ps1`, `restore.ps1`, and CI to inspect all non-binary files rather than a fixed extension list.
   - Ensure checkpoint scripts restore previous directory locations with `Push-Location` and `Pop-Location`.
2. **Move Failing Test Creation to Phase 3 (Post-Checkpoint)**:
   - On Tier 2/3 tasks, keep Phase 1 strictly read-only. The proposal document (Gate 1) specifies the intended reproducer test plan.
   - Authoring the failing test occurs in Phase 3 after Gate 1 approval and after `New-AuditCheckpoint.ps1` establishes the git rollback point, preventing dirty working trees during checkpointing.
3. **Standardize Session Scratch Paths**:
   - Standardize scratch storage on `<appDataDir>\brain\<conversation-id>\scratch\<task>\` across review and audit workflows, replacing literal unexpanded `$HOME` paths with absolute paths.
   - Restrict git commit execution in `sync-task-state` to parent sessions, and use read-only `rtk git show` in review workflows.
4. **Clarify Agent Boundaries and Condense Prompts**:
   - Exempt `build-error-resolver` from creating scratch files, keeping its tool set focused strictly on `replace_file_content`.
   - Reaffirm `model: flash` for tactical agents while allowing dynamic elevation for complex tasks.
   - Condense duplicated delegation text across agent definitions and trim redundant sections from `documentation-and-adrs`, saving prompt tokens.
5. **Register `deep-web-research` in Continuous Integration**:
   - Register `deep-web-research` as the 15th tracked skill with Windows PowerShell 5.1 compatibility (`curl.exe`) and query limits.
   - Update `.github/workflows/ci.yml` to assert exactly 15 skills (`$skills.Count -ne 15`) and 11 custom agents (`$agents.Count -ne 11`).

## Alternatives Considered & Rejected
- **Merging `deep-web-research` into `spec-verifier`**: Rejected because web research provides distinct, reusable search guardrails across multiple review roles without coupling it to spec validation.
- **Permitting file creation in `build-error-resolver`**: Rejected because restricting compiler repair agents to in-place edits prevents creating empty type stubs to silence compiler errors.

## Consequences
- **Positive**: Resolves the timing deadlock between writing reproducer tests and establishing git checkpoints.
- **Positive**: Intercepts command bypasses using backticks, quotes, wrapper flags, and WMI invocations.
- **Positive**: Unifies session scratch storage under the Antigravity conversation directory.
- **Positive**: Continuous integration enforces exact counts (15 skills, 11 agents) and frontmatter character limits.
