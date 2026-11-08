# ADR-0015: Checkpoint-Gated Autonomous Execution for Tiers 0 and 1

## Status
Partially Superseded by ADR-0019 (for orchestration flow) and ADR-0024 (for rollback and command safety)

## Date
2026-10-31

## Context
Under the earlier workflow rules in `audit-dev-workflow` (ADR-0007, ADR-0009), all repository file modifications required explicit human operator approval in chat ("Gate 1") before editing, even for small documentation fixes or contained single-module enhancements. This created review friction, requiring developers to approve a speculative text proposal before seeing the actual diff.

At the same time, several security and execution gaps required attention:
1. **Command Safety Interception Gaps**:
   `Test-PowerShellCommandSafety.ps1` needed checks for module-qualified cmdlets (e.g. `Microsoft.PowerShell.Management\Remove-Item`), `.exe` suffixes, parameter splatting (`@var`), secondary shell launches (`cmd /c`), and global git path flags.
2. **Untracked Files Remaining After Rollback**:
   `New-AuditCheckpoint.ps1` suppressed errors with `2>$null`, while `Restore-AuditCheckpoint.ps1` ran `git reset --hard`, leaving newly created untracked files in the workspace. Because `git clean -f` was strictly blocked, cleaning up after a failed task was difficult.
3. **Subagent Model Configuration**:
   Hardcoding specific model tiers in agent definitions prevented subagents from scaling naturally with higher-capability parent sessions.
4. **Empty Test Suite False Passes**:
   Test runners could exit with code 0 if filters matched zero tests, creating a false impression of success.
5. **Write Boundaries and Artifact Storage**:
   Path limits needed to allow writing to session artifacts (`brain/<conversation-id>`), scratch folders, and sibling `<Project>-AI-Context` repositories.

## Decision
1. **Allow Autonomous Execution for Small Tasks (Tiers 0 and 1)**:
   - For Tier 0 (`trivial`: <= 2 files, <= 3 code lines or <= 5 doc lines): execute autonomously after establishing a verified checkpoint, verify statically, and present the final diff for review before commit.
   - For Tier 1 (`small`: single-module bugfix or enhancement): execute autonomously after establishing a checkpoint, follow TDD (RED -> GREEN), verify, and present the diff at Gate 2 before commit.
   - For Tier 2/3 (`standard`/`large`) and package installations: retain mandatory human proposal approval (Gate 1) before modifying files.
2. **Harden PowerShell AST Command Safety Sandbox (`Test-PowerShellCommandSafety.ps1`)**:
   - Normalize command names by stripping module paths (`Microsoft.PowerShell.Management\Remove-Item` -> `Remove-Item`) and `.exe` suffixes.
   - Intercept parameter splatting (`@var`) on destructive cmdlets and git commands.
   - Block secondary command interpreters (`cmd`, `bash`, `sh`) and inline evaluation (`pwsh -Command`), while permitting script file execution (`pwsh -File`).
   - Filter git global configuration flags (`-C`, `-c`, `--work-tree`) before evaluating subcommands.
   - Block destructive working tree discards (`git checkout -f`, `git restore .`).
   - Retain exemptions for read-only commands, test runners, and routine `rtk git` commands.
3. **Track and Clean Untracked Files on Rollback**:
   - In `New-AuditCheckpoint.ps1`, verify that the working tree is clean and record an untracked file snapshot (`untracked_baseline.txt`).
   - In `Restore-AuditCheckpoint.ps1`, run `git reset --hard`, compare against the snapshot, and delete only the new untracked files created during the task rather than calling `git clean -f`.
4. **Dynamic Model Elevation for Complex Subagents**:
   - Keep `model: inherit` on analytical agents (`spec-verifier`, `database-reviewer`, `system-architect`, `code-auditor`, `silent-failure-hunter`) so they inherit the parent session model.
   - Allow dynamically elevating subagents to `model: pro` when invoked from `flash` sessions for complex documentation checks or schema reviews.
5. **Enforce Assertion Counts and Explicit Write Boundaries**:
   - Require test runs to exit with code 0 AND verify positive passed assertion counts (> 0 passed, 0 failed). Weakening test assertions to force passes is prohibited.
   - Allow file writes exclusively within the repository, sibling `<Project>-AI-Context` repositories, and Antigravity `brain`/`scratch` directories.

## Alternatives Considered & Rejected
- **Requiring Gate 1 on all changes**: Rejected because reviewing actual code diffs on small, contained changes is faster and more reliable than reviewing speculative text proposals.
- **Using `git clean -fdx` during rollback**: Rejected because blind directory cleaning risks deleting untracked developer files unrelated to the active task.

## Consequences
- **Positive**: Reduces review friction for small bug fixes and documentation updates while keeping checkpoints for safety.
- **Positive**: Prevents untracked task files from lingering in the workspace after rollback.
- **Positive**: Catches shell bypasses using parameter splatting, secondary shells, and module prefixes.
- **Trade-off**: Checkpoint creation requires a clean tracked working tree before starting autonomous tasks.
