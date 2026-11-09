# ADR-0026: Council Evaluation Remediation, AST Hardening, and Schema Grounding

## Status
Accepted

## Date
2026-11-09

## Context
During testing of the orchestration harness and safety scripts (documented in `tier3_council_evaluation_report.md` and `subagent_crosscheck_report.md`), several command safety, rollback integrity, and manifest schema issues were identified across repository components:

1. **PowerShell Command Safety Parser Bypasses**:
   - In `Test-PowerShellCommandSafety.ps1`, git flag `-m` unconditionally consumed the next token as a payload across all git subcommands. For subcommands where `-m` does not accept a payload (such as `git checkout -m` or `git branch -m`), subsequent destructive flags (such as `-f` or `--force`) were skipped during inspection, allowing destructive discard and branch overwrites to pass undetected.
   - Destructive robocopy flags prefixed with POSIX hyphens (`robocopy -mir`, `robocopy -purge`, `robocopy -mov`) bypassed regexes that only inspected forward-slash switches (`/mir`, `/purge`).
   - Sensitive credential path checks required leading home roots (`~` or `$HOME`), permitting relative deletion targets (e.g., `Remove-Item .ssh\id_rsa`) to bypass interception.
   - The command safety validator lacked a dedicated check for `git config`, allowing sensitive configuration overrides (`core.sshCommand`, `core.hooksPath`, `core.editor`, `clean.requireForce`, `alias.*`) to run without interception.

2. **Rollback Integrity and Exit Code Omissions**:
   - In `Restore-AuditCheckpoint.ps1`, file-mode restore executed `Copy-Item` directly from scratch without verifying the backup against the SHA-256 hashes recorded in `hashes.txt`, risking silent restoration of corrupted or tampered backups.
   - During git rollback in `Restore-AuditCheckpoint.ps1` and checkpoint creation in `New-AuditCheckpoint.ps1`, native git commands (`git status --porcelain -uno` and `git ls-files --others --exclude-standard`) did not verify `$LASTEXITCODE`, silently continuing when git operations failed.
   - In git rollback, directory removal (`Remove-Item -LiteralPath $cleanDir -Recurse -Force`) threw unhandled terminating exceptions when directories were temporarily locked by external Windows processes.

3. **Diff Sanitizer Multiline Key Redaction**:
   - `Update-Gate2Diff.ps1` sanitized only the single-line header `-----BEGIN <KEY_TYPE> PRIVATE KEY-----`, leaving the entire multiline base64 cryptographic body unredacted in review handoffs (`gate2_handoff.md`). Furthermore, truncated diff hunks with unclosed headers required a resilient fallback.

4. **Subagent Manifest Schema Drifts & Runtime Hang Risks**:
   - Five subagent manifests (`docs-architect`, `l10n-humanizer`, `maintenance-bot`, `system-architect`, `ui-crafter`) declared the interactive prompt tool `ask_question`, risking non-interactive execution hangs during autonomous background delegation.
   - Subagents invoking Context7 MCP or DevTools lacked `call_mcp_tool` in their tools allowlist.
   - Subagent manifests omitted the canonical `subagent: true` schema marker required for Antigravity subagent declarations.

5. **Pruning Deficiencies in Deployment Scripts**:
   - `sync.ps1` and `restore.ps1` guarded pruning loops behind `$count -gt 0` conditions. If all source custom agents or custom skills were deleted, the pruning loops were skipped, leaving stale files in target directories.

6. **Orchestration DAG Gaps and Meta-Framework Scope Clarity**:
   - The Mermaid workflow diagram in `config/skills/orchestrator/SKILL.md` dead-ended at `T3Exec`, omitted Gate 2 rejection/abort loops, and forced declarative documentation tasks through redundant test authoring steps.
   - `clean-docs/SKILL.md` banned gate and checkpoint terminology without exempting meta-framework repositories where such terms are primary domain concepts.

## Decision

1. **AST Command Safety Hardening**:
   - Enhanced `Test-PowerShellCommandSafety.ps1` to track the active git subcommand dynamically. Flag `-m`/`--message` only consumes the next token if the subcommand is `commit`, `tag`, or `merge`.
   - Updated robocopy flag regex to match both forward slashes and POSIX hyphens (`(?i)^[/-](mir|purge|mov|move)$`).
   - Hardened credential path detection to match relative targets (`(?i)(^|[/\\])(\.ssh|\.aws|\.gnupg)($|[/\\])`).
   - Added a dedicated validation block for `git config` that blocks modifications to sensitive keys (`core.sshCommand`, `core.hooksPath`, `core.editor`, `core.fsmonitor`, `clean.requireForce`, `alias.*`).

2. **Rollback Integrity and Robustness**:
   - Implemented SHA-256 integrity verification in `Restore-AuditCheckpoint.ps1` against `hashes.txt` before overwriting target files, rejecting corrupted backups.
   - Added explicit `$LASTEXITCODE -ne 0` checks after `git status` in `New-AuditCheckpoint.ps1` and `git ls-files` in `Restore-AuditCheckpoint.ps1`.
   - Wrapped untracked file and directory cleanup in `try/catch` blocks with `-ErrorAction Stop` to handle Windows file locks gracefully with warnings instead of fatal crashes.

3. **Two-Stage Private Key Redaction**:
   - Upgraded `Update-Gate2Diff.ps1` to perform two-stage private key sanitization: full multiline block replacement (`(?ms)-----BEGIN...-----END...`) with `[SANITIZED PRIVATE KEY BLOCK]`, followed by single-line header replacement for truncated diff hunks.

4. **Subagent Manifest Hygiene & Schema Grounding**:
   - Removed `ask_question` from all subagents.
   - Added `call_mcp_tool` to the tools allowlist for agents utilizing Context7 MCP or DevTools (`build-error-resolver`, `code-auditor`, `database-reviewer`, `spec-verifier`, `system-architect`, `ui-crafter`).
   - Declared `subagent: true` across all 11 subagent manifests and enforced this schema invariant in `YamlValidation.Tests.ps1`.

5. **Deterministic Pruning in Sync and Restore**:
   - Removed the `$count -gt 0` guards in `sync.ps1` and `restore.ps1` across agents and skills, ensuring that deleting all source items cleanly prunes the destination while preserving whitelisted external skills (`$externalSkills`).

6. **Orchestration DAG and Documentation Hygiene**:
   - Updated the Mermaid diagram in `orchestrator/SKILL.md` to eliminate the `T3Exec` dead end, add Gate 2 feedback/abort loops, and support declarative task bypass past `tdd-guide`.
   - Added a scope qualification to `clean-docs/SKILL.md` clarifying that process artifact bans apply to client application repositories while permitting framework domain terms in `everyday-agy`.
   - Synchronized historical ADR statuses and back-links across `docs/adr/`.

## Alternatives Considered & Rejected

- **Single-Stage Multiline Regex for Private Keys**: Rejected because truncated diff hunks containing only `-----BEGIN <KEY_TYPE> PRIVATE KEY-----` without the closing delimiter would fail to match, leaking key material.
- **Strict Error Termination on Locked Directories**: Rejected because temporary Windows file locks on ephemeral build artifacts would abort the entire rollback, leaving tracked files in an inconsistent state.
- **Custom Native Tool Wrappers for MCP**: Rejected in favor of the standard Antigravity `call_mcp_tool` declaration.

## Consequences

- **Positive**: Strengthened AST protection against git option parsing bypasses, relative credential deletion, and git config overrides.
- **Positive**: Rollback operations are verified via SHA-256 checksums and protected against silent git query failures.
- **Positive**: Diff handoffs sanitize full multiline cryptographic private keys and unclosed key headers without leaking payloads.
- **Positive**: Background subagents operate without interactive hang risks, with properly declared MCP tool access and validated YAML schemas.
- **Positive**: Synchronized bidirectional ADR traceability and complete workflow orchestration state transitions.
- **Neutral / Operational Requirements**: Subagent manifests must include `subagent: true` and pass automated YAML schema validation in CI.
