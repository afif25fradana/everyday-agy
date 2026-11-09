# ADR-0011: Intercept .NET Deletions and Mirror Secret Scans in Restore

## Status
Partially Superseded by ADR-0024 (for comprehensive AST validation rules) and ADR-0026 (for AST git config interception and rollback hardening)

## Date
2026-10-24

## Context
During execution testing of PowerShell commands and deployment scripts, several bypasses and configuration gaps were identified:
1. **PowerShell AST Validator Bypasses**:
   `Test-PowerShellCommandSafety.ps1` previously only inspected `CommandAst` nodes. Destructive operations invoking direct .NET member calls (e.g. `[System.IO.Directory]::Delete("C:\", $true)`), process launchers (`Start-Process cmd -Args "/c rd /s /q ..."`), unhandled aliases (`rmdir`), destructive worktree cleans (`git clean -fdx`), and dynamic parenthesized commands (`& (Get-Command Remove-Item) ...`) passed through unblocked.
2. **Deployment Verification Asymmetry**:
   `sync.ps1` implemented a pre-flight credential audit before copying dotfiles to git, whereas `restore.ps1` copied files directly from the repository into `~/.gemini/` without pre-flight validation and omitted backing up existing custom plugins.
3. **Write Agent Path Boundaries**:
   Subagents executing on `model: flash` with broad mutation tools (`docs-architect`, `tdd-guide`, `ui-crafter`) lacked explicit path boundaries in their agent definitions.
4. **Evaluating External Tool Ingestion**:
   Several proposed external packages were evaluated and found redundant or obsolete against built-in tools (such as complex graph navigation emulators that add maintenance overhead compared to standard `rtk rg` caller searches).

## Decision
1. **Harden Pre-Execution AST Safety Validator**:
   - Intercept direct .NET file and directory deletion calls (`InvokeMemberExpressionAst` on `System.IO.Directory`, `File`, or `Path` calling `Delete`).
   - Intercept process execution wrappers (`Start-Process`, `saps`) and dynamic parenthesized invocations (`& (...)`).
   - Add `rmdir` to destructive cmdlet aliases and block `git clean -f*`.
   - Prevent recursive deletions and root deletions regardless of `-Force`.
   - Add an automated regression test suite `Test-PowerShellCommandSafety.Tests.ps1` wired into CI.
2. **Mirror Secret Scans in Deployment Scripts**:
   - Mirror `sync.ps1` pre-flight credential scanning into `restore.ps1` to prevent deploying sensitive dotfiles.
   - Include `$configHome\plugins` in the automatic backup routine before restoration.
   - Verify source content in `sync.ps1` before writing ADR files.
3. **Define Explicit Tool and Path Boundaries on Write Agents**:
   - Limit `docs-architect` strictly to documentation files (`docs/**`, `*.md`) and AI-context files.
   - Limit `tdd-guide` strictly to test files and tested application units.
   - Limit `ui-crafter` to frontend assets in Codebase mode and artifact directories in Generative UI mode.
4. **Rely on Standard Tooling Over Complex External Wrappers**:
   - Prefer standard `rtk rg` caller tracing over complex external dependency graphs.
   - Avoid shadowing native slash commands with third-party wrappers.
   - Wire automated credential regex scanning into CI and deployment scripts.

## Alternatives Considered & Rejected
- **Permitting `Start-Process` in agent sessions**: Rejected because launching external shell processes bypasses script command validation.
- **Skipping pre-flight scans on restore**: Rejected because configuration deployments should be validated symmetrically with repository synchronization.

## Consequences
- **Positive**: Intercepts direct .NET deletions and process-based command bypasses before execution.
- **Positive**: Regression test suite automatically validates AST rules in continuous integration.
- **Positive**: Both synchronization (`sync.ps1`) and deployment (`restore.ps1`) are protected by pre-flight secret scans.
- **Trade-off**: Workflows that require `Start-Process` or `git clean -f` must be run manually by the developer outside the agent session.
