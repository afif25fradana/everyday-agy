# ADR-0017: Consolidate Documentation Agents and Enforce Absolute Paths for Skills

## Status
Partially Superseded by ADR-0018 (for 11th agent addition) and ADR-0024 (for AST command validation and rollback safety)

## Date
2026-11-01

## Context
A review of custom agents and execution scripts identified several structural and runtime gaps:
1. **Redundant Documentation Roles**:
   `docs-architect` and `public-docs-craftsman` had overlapping tools and responsibilities, creating confusion when delegating tasks that touched both internal architecture decisions and public documentation.
2. **Skill File Loading and Path Resolution**:
   Declaring skills in agent frontmatter provides only names and descriptions in the base prompt. To apply detailed skill rules, subagents must read the underlying `SKILL.md` file. However, subagents frequently passed unexpanded tilde (`~`) paths to `view_file` on Windows, causing file-not-found errors.
3. **Command Safety Interception Gaps**:
   `Test-PowerShellCommandSafety.ps1` had bypass vectors: quoted parameter values (e.g. `git push "--force"`), command wrappers (`sudo`, `gsudo`, `rtk proxy`), secondary shell alias `start`, pipelined deletions, scriptblock reflection methods (`.Invoke()`), and unanchored `git push` force refspecs.
4. **Rollback Target Resolution**:
   `Restore-AuditCheckpoint.ps1` failed to resolve single-file backups when target files were deleted before rollback, and missing baseline files risked removing untracked developer files. Hardcoded `$env:USERPROFILE` paths also failed in Linux environments where the variable is unset.
5. **Secret Scanner Detection**:
   Pre-flight scanners did not recognize newer key formats (Anthropic, OpenAI project keys, GitHub tokens, AWS STS) and produced false alarms on unquoted words in Markdown documentation.

## Decision
1. **Consolidate Documentation Agents**:
   - Merge `public-docs-craftsman` into `docs-architect`, structuring responsibilities into two clear operational modes:
     - **Mode A (Internal Architecture and AI Context)**: Governs `docs/adr/**`, `architecture.md`, and `task_state.md`.
     - **Mode B (Public Documentation and Repository Health)**: Governs `README.md`, `TOOLKIT.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `LICENSE`, and `.github/**`.
   - Maintain `model: flash` on `docs-architect` for routine documentation updates, allowing dynamic elevation to `pro` or `inherit` for complex architectural synthesis.
   - Delete `config/agents/public-docs-craftsman` to keep a clean 10-agent fleet aligned with review seats in `council-review`.
2. **Require Absolute Paths for Skill Loading**:
   - Add a mandatory skill activation section to agent definitions directing subagents to read bound skill files using exact absolute paths resolved from their prompt headers rather than literal `~` prefixes.
   - Load skills conditionally based on the active task phase rather than loading all bound skills simultaneously, reducing token consumption.
   - Restrict `build-error-resolver` to in-place edits (`replace_file_content`) to prevent silencing compiler errors with stub declarations.
3. **Harden PowerShell AST Validator**:
   - Strip quotes from argument tokens in inspection loops in `Test-PowerShellCommandSafety.ps1`.
   - Unwrap `sudo`, `gsudo`, and `rtk proxy` prefixes to inspect the underlying command.
   - Add `start` alias to blocked commands.
   - Intercept dynamic scriptblock reflection calls (`.Invoke()`, `.InvokeReturnAsIs()`, `.InvokeScript()`).
   - Intercept pipelined recursive deletions and unanchored `git push` force refspecs.
4. **Improve Rollback Path Resolution and Cross-Platform Compatibility**:
   - In `Restore-AuditCheckpoint.ps1`, resolve target paths using `$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($FilePath)` so deleted files resolve to proper paths and match scratch backups.
   - If `untracked_baseline.txt` is missing, skip untracked file cleanup with a warning rather than deleting files blindly.
   - Use `$userHome` fallbacks (`if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }`) and `Join-Path` for cross-platform compatibility across Windows and Linux CI.
5. **Update Secret Scanner Patterns**:
   - Expand regex patterns across `sync.ps1`, `restore.ps1`, and CI to detect Anthropic (`sk-ant-`), OpenAI Project (`sk-proj-`), GitHub (`gho_`, `ghu_`), and AWS STS (`ASIA`) keys.
   - Anchor unquoted YAML assignments to line beginnings to eliminate false positives on plain text in Markdown documentation.

## Alternatives Considered & Rejected
- **Adopting external test frameworks for PowerShell validation**: Rejected because Windows PowerShell 5.1 bundles Pester 3.4.0 natively, while newer Pester 5 syntax requires external package downloads. Lightweight standalone scripts run reliably across both Windows PowerShell 5.1 and pwsh without extra dependencies.
- **Granting `write_to_file` to `build-error-resolver`**: Rejected because restricting the agent to modifying existing files ensures it fixes underlying type issues rather than adding empty stub declarations.

## Consequences
- **Positive**: Eliminates agent role duplication by consolidating documentation responsibilities into `docs-architect`.
- **Positive**: Resolves Windows tilde path errors by requiring absolute paths when reading skill files.
- **Positive**: Catches command bypasses involving quoted parameters, scriptblock reflection, and wrapper commands.
- **Positive**: Improves rollback reliability when restoring deleted files.
- **Trade-off**: Subagents must resolve absolute paths from their prompt context when loading skill instructions.
