# ADR-0011: Pre-Execution AST Security Hardening, Deployment Parity, and Anti-Slop Upstream Filtration

## Status
Accepted

## Date
2026-10-24

## Context
Following a dual-agent audit (Claude Opus 4.6 and Gemini 3.8 Flash) combined with empirical PowerShell execution testing and authoritative upstream verification via `spec-verifier`, several critical vulnerabilities and architectural trade-offs were identified:

1. **AST Safety Validator Bypass Vectors**:
   `Test-PowerShellCommandSafety.ps1` previously only inspected `CommandAst` nodes. Destructive operations invoking direct .NET member calls (e.g. `[System.IO.Directory]::Delete("C:\", $true)`), process launchers (`Start-Process cmd -Args "/c rd /s /q ..."`), unhandled aliases (`rmdir`), destructive worktree cleans (`git clean -fdx`), and dynamic parenthesized commands (`& (Get-Command Remove-Item) ...`) passed through unblocked.
2. **Deployment Asymmetry**:
   `sync.ps1` implemented a robust 50-line pre-flight credential audit before copying dotfiles to git, whereas `restore.ps1` copied files directly from the repository into `~/.gemini/` without pre-flight validation and failed to back up existing custom plugins.
3. **Over-Broad Write-Agent Boundaries**:
   Subagents executing on `model: flash` with broad mutation tools (`docs-architect`, `tdd-guide`, `ui-crafter`) lacked explicit path and target boundaries, relying solely on global prompt text.
4. **Upstream Slop & Cargo-Cult Pitfalls**:
   Initial external research proposed importing community artifacts that proved invalid upon spec verification:
   - `coderabbitai/ast-grep-essentials`: Archived and read-only since September 8, 2026.
   - `mmaaz-git/agentic-pbt`: Academic workshop prototype (~37 commits), not an authoritative production library.
   - Matt Pocock `/grill-me`: Redundant port of a TTY Claude Code skill that shadows Antigravity's native `/grill-me` slash command and degrades the native interactive `ask_question` modal UI.
   - Aider PageRank Repo Map: Over-engineered 2023 artifact designed for 8k token windows, unnecessary and fragile in 2026 1M+ token environments.

## Decision

1. **Harden Pre-Execution AST Safety Validator**:
   - Intercept direct .NET file deletion calls (`InvokeMemberExpressionAst` on `System.IO.Directory|File|Path` calling `Delete`).
   - Intercept process execution wrappers (`Start-Process`, `saps`) and dynamic parenthesized invocations (`& (...)`).
   - Add `rmdir` to destructive cmdlet aliases and prohibit `git clean -f*`.
   - Prevent recursive deletions and root deletions regardless of the presence of `-Force`.
   - Add an automated regression test suite `Test-PowerShellCommandSafety.Tests.ps1` wired into CI.

2. **Enforce Full Restore & Deployment Parity**:
   - Mirror `sync.ps1`'s pre-flight credential scanner into `restore.ps1` to prevent deploying poisoned dotfiles.
   - Include `$configHome\plugins` in the automatic backup routine before restoration.
   - Protect repository ADRs from accidental overwrite in `sync.ps1` by verifying source content.

3. **Define Hard Tool & Path Boundaries on Write Agents**:
   - Bound `docs-architect` strictly to documentation files (`docs/**`, `*.md`) and AI-context files.
   - Bound `tdd-guide` strictly to test files and tested application units.
   - Bound `ui-crafter` to frontend assets in Codebase mode and artifact directories in Generative UI mode.
   - Inject an Anti-False-Positive Exploitability Invariant into `code-auditor`.
   - Inject Invariant Property Testing guidance (`fast-check` and `Hypothesis`) into `tdd-guide`.

4. **Reject Upstream Slop & Reaffirm YAGNI**:
   - Veto archived third-party rule sets in favor of official upstream `ast-grep` catalog documentation.
   - Veto shadow skills for native Antigravity slash commands (`/grill-me`).
   - Veto complex PowerShell PageRank graph emulators in favor of standard `rtk rg` caller tracing.
   - Adopt `Betterleaks` as the modern, active drop-in successor to `Gitleaks`.

## Consequences

### Positive
- **Eliminates High-Risk AST Bypass Vectors**: Direct .NET deletions and process-based bypasses are intercepted before execution with zero overhead.
- **Continuous Safety Regression Prevention**: CI automatically executes 22 functional test cases on the AST validator on every push.
- **Symmetric Credential Defense**: Both inbound (`sync.ps1`) and outbound (`restore.ps1`) configurations are guarded by pre-flight secret scans.
- **Zero Catalog Bloat**: Rejected 4 redundant or obsolete upstream tools, preserving context window economics per ADR-0002 and ADR-0003.

### Negative & Operational Requirements
- **Strict Shell Constraints**: Legitimate developer workflows that require `Start-Process` or `git clean -f` must be executed manually by the human outside the agent subshell.
