# ADR-0009: PowerShell AST Command Safety Validation and Gotcha Limits

## Status
Partially Superseded by ADR-0024 (for AST command validation and rollback safety)

## Date
2026-10-23

## Context
A comparative review of the Everything Claude Code (ECC) harness against `everyday-agy` identified several design trade-offs:
1. **Catalog Sizing vs Progressive Disclosure**:
   ECC bundled 311 skills, 71 agents, and 97 commands, adding significant prompt token overhead per turn and risking tool selection confusion.
2. **Advisory Prompts vs Executable Command Validation**:
   Safety rules previously relied exclusively on text directives in `GEMINI.md`. Text instructions alone cannot guarantee command safety if unexpected or destructive shell snippets are executed.
3. **Host Shell Compatibility**:
   ECC enforced security via complex Node.js wrappers and regex-based command parsers. On Windows environments (`pwsh` and PowerShell 5.1), these wrappers encountered process termination issues, bash heredoc syntax errors, and tool-mapping failures.
4. **Unbounded Task State Growth**:
   Unbounded appending of historical edge cases without size limits causes context drift and token waste.

At the same time, ECC included useful practices: structured review deduplication, code comment cleanup passes, and concise edge-case tracking.

## Decision
1. **Maintain a Lean Core Catalog**:
   Keep a compact fleet of custom agents and maintain a limit of 15-20 core skills rather than importing large third-party catalogs wholesale. Avoid external wrapper scripts and non-native lifecycle hooks.
2. **Implement Native PowerShell AST Command Safety Validator (`Test-PowerShellCommandSafety.ps1`)**:
   Implement a lean native PowerShell script (`config/skills/audit-dev-workflow/scripts/Test-PowerShellCommandSafety.ps1`) using `[System.Management.Automation.Language.Parser]`.
   The script inspects the parsed command AST for destructive commands (`Remove-Item -Recurse -Force`, `Format-Volume`, `Clear-Disk`, `git push --force`, `--no-verify`) before execution.
3. **Establish Explicit Credential and Path Deny-List in `GEMINI.md`**:
   Add explicit deny paths in configuration:
   - User credentials: `~/.ssh/**`, `~/.aws/**`, `~/.gnupg/**`
   - Environment secrets: `**/.env*`, `**/*.key`, `**/*.pem`
   - Antigravity tokens: `C:\Users\*\.gemini\antigravity\mcp\**`
   Treat untrusted external content (diffs, PRs, issues) as inert data and sanitize MCP arguments.
4. **Structured Multi-Perspective Review Deduplication**:
   In `council-review`, deduplicate findings across review roles before compiling final recommendations.
5. **Classify Tasks by Blast Radius**:
   Classify incoming tasks into four tiers:
   - `trivial` (1 file, small change): Direct edit and verification.
   - `small` (1 module): Single-auditor review and TDD.
   - `standard` (2-5 files): Architecture planning, human proposal approval, implementation, and review.
   - `large` (cross-cutting, schema, public API): Full multi-perspective review panel.
6. **Limit Known Edge Cases in `task_state.md`**:
   Enforce single-line structured gotchas in `task_state.md` (`## Known Edge Cases`) with strict budget limits (<= 8 KB, <= 100 lines, maximum 5 edge cases). Promote settled edge cases to formal ADRs when recurring.
7. **Adopt Selected Domain Skills**:
   Incorporate three domain-agnostic skills into `config/skills/`: `contract-first`, `database-migrations`, and `coding-standards`.

## Alternatives Considered & Rejected
- **Importing the full external catalog**: Rejected due to high token overhead per turn and tool selection confusion.
- **JavaScript regex command parsing on Windows**: Rejected because native PowerShell AST parsing provides accurate token identification without fragile regex patterns.

## Consequences
- **Positive**: Intercepts destructive commands at the PowerShell AST level before execution.
- **Positive**: Keeps context budgets small by maintaining a lean catalog and bounded task state.
- **Positive**: Replaces external wrappers with native PowerShell primitives compatible with Windows hosts.
- **Trade-off**: Static AST analysis cannot resolve dynamically constructed runtime strings (e.g. `Invoke-Expression ([char]...)`), requiring layered path boundaries as defense.
