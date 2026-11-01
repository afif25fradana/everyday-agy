# ADR-0017: Custom Agent Fleet Consolidation, AST Security Hardening, and Mandatory Skill Activation Architecture

## Status
Accepted

## Date
2026-11-01

## Context
A forensic audit and subsequent multi-agent council review across `everyday-agy` identified structural, operational, and runtime security gaps:
1. **Agent Redundancy & Council Parity Drift**: `docs-architect` and `public-docs-craftsman` overlapped by ~80% across tools, skills, and documentation responsibilities. Furthermore, `seat-catalog.md` in `council-review` defined only 10 seats, leaving `public-docs-craftsman` unmapped and forcing split-brain delegations on combined doc/ADR updates.
2. **Progressive Disclosure Token Isolation & Tilde Crash**: In the Antigravity runtime, declaring `skills:` in YAML frontmatter only provides progressive disclosure headers (names and descriptions). The full content of `SKILL.md` is never loaded into subagent context unless explicitly read. None of the custom agent prompts mandated reading their bound skills, causing subagents to operate without normative rule sets. Additionally, passing raw `~` paths to `view_file` on Windows caused runtime tool validation failures (`invalid_args: path is not absolute`), while blanket Turn-1 skill reading dumped 6K–9K tokens unnecessarily.
3. **AST Safety Interception Gaps**: `Test-PowerShellCommandSafety.ps1` had concrete bypass vectors: wrapping parameters in quotes (e.g. `git push "--force"`), command prefixes (`sudo`, `gsudo`, `rtk proxy`), secondary shell alias `start`, pipelined `Remove-Item -Recurse`, reflection methods (`.Invoke()`) on dynamic scriptblocks, and unanchored `git push` force refspecs and remote deletions.
4. **Rollback & Cross-Platform Incompatibilities**:
   - `Restore-AuditCheckpoint.ps1` failed to resolve single-file backups when targets were deleted because `Test-Path` returned false, preventing proper SHA1 matching.
   - Missing untracked baselines risked deleting user files indiscriminately during rollback.
   - Hardcoded `$env:USERPROFILE` paths failed in Linux CI (`ubuntu-latest`), where the variable is null.
5. **Secret Scanner Blind Spots**: Pre-flight scanners did not recognize modern key formats (Anthropic, OpenAI project keys, GitHub tokens, AWS STS) and risked false positives on unquoted words in Markdown documentation.

## Decision

1. **Consolidate Documentation Agents (Fleet of 10 Orthogonal Agents)**:
   - Merge `public-docs-craftsman` into `docs-architect` using a Mutually Exclusive Mode Selector:
     - **Mode A (Internal Architecture, Nygard ADRs & AI-Context Sync)**: Governs `docs/adr/**`, `architecture.md`, and `task_state.md`.
     - **Mode B (Public Repo Docs, Sub-Docs & GitHub Community Health)**: Governs `README.md`, `TOOLKIT.md`, `technical.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `LICENSE`, and `.github/**`.
   - Maintain `model: flash` on `docs-architect` for token efficiency, with dynamic elevation to `pro` / `inherit` when invoked by parent agents for complex architectural audits.
   - Restrict path boundaries strictly to documentation files; forbid inline source code modifications.
   - Delete `config/agents/public-docs-craftsman`, restoring exact 1-to-1 parity between the 10 custom agents and the 10 seats in `council-review/references/seat-catalog.md`.

2. **Establish Task-Conditional Mandatory Skill Gates & Agent Parity**:
   - Introduce an explicit `## Mandatory Skill Activation Gate` section in every `agent.md` body. Subagents must invoke `view_file` using absolute paths resolved from their `<skills>` prompt context (never literal `~` prefixes).
   - Enforce task-conditional / on-demand skill reading per active phase rather than dumping all skills in Turn 1, eliminating token bloat.
   - Establish Universal Sibling AI-Context Auto-Discovery across all agents.
   - Add `database-migrations` to `system-architect` and `read_url_content` to `spec-verifier`.
   - Enforce the 2-Attempt Stop Rule in `tdd-guide` and `build-error-resolver`.

3. **Harden PowerShell AST Validator & Test Automation**:
   - Strip argument token quotes (`-replace '^[''"]|[''"]$', ''`) across all inspection loops in `Test-PowerShellCommandSafety.ps1`.
   - Unwrap `sudo`, `gsudo`, and `rtk proxy` commands, promoting wrapped targets to `$cmdName`.
   - Add `start` alias to `$forbiddenCommands`.
   - Block dynamic scriptblock reflection invocations (`.Invoke()`, `.InvokeReturnAsIs()`, `.InvokeScript()`).
   - Block pipelined recursion (`$cmdAst.Parent -is [PipelineAst]` with upstream `-Recurse`).
   - Anchor `git push` force refspecs (`(^|\s)\+[A-Za-z0-9_./-]+`) and remote deletions (`(^|\s):[A-Za-z0-9_./-]+($|\s)`) without colliding with SSH remote URLs.
   - Add fallback reading from `$input` for stdin pipelines under Windows PowerShell 5.1 CLI.
   - Maintain standalone automated regression test suites covering all safety bypass vectors.

4. **Robust Rollback, Cross-Platform Compatibility & Synchronization**:
   - In `Restore-AuditCheckpoint.ps1`, resolve target paths using `$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($FilePath)` so deleted files resolve to proper absolute paths and match scratch backups.
   - Enforce fail-closed untracked file handling during git rollback: skip untracked cleanup with a warning if `untracked_baseline.txt` is missing.
   - Adopt `$userHome` cross-platform fallback (`if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }`) and `Join-Path` across checkpoint scripts and tests for Linux CI (`ubuntu-latest`) compatibility.
   - Register `AuditCheckpoint.Tests.ps1` in `.github/workflows/ci.yml`.
   - Guard against accidental file pruning in `sync.ps1` and `restore.ps1` when source directories are empty.

5. **Modernize Secret Scanner & YAML Boundary**:
   - Expand `$secretPatterns` across `sync.ps1`, `restore.ps1`, and `.github/workflows/ci.yml` to detect modern Anthropic (`sk-ant-`), OpenAI Project (`sk-proj-`), GitHub (`gho_`, `ghu_`, `ghs_`, `ghr_`), and AWS STS (`ASIA`) keys.
   - Anchor unquoted YAML assignments strictly to line starts (`(?m)^\s*...`) on specific credential keys (`api_key`, `access_token`, `secret_key`), excluding bare `token` words to eliminate false-positive failures in Markdown documentation.

## Alternatives Considered & Rejected

1. **Forced Migration to Pester 5 DSL**:
   - *Proposal*: Migrate `Test-PowerShellCommandSafety.Tests.ps1` to Pester 5 DSL (`Describe`, `It -ForEach`, `Should -Throw`).
   - *Rejection Rationale*: Windows PowerShell 5.1 natively bundles Pester 3.4.0. Pester 5 syntax fails out-of-the-box on clean Windows installations without external PSGallery downloads. Everyday-AGY enforces a zero-unneeded-dependencies standard; standalone test runners provide sub-second dual-engine compatibility (PS 5.1 and pwsh) without external package installations.

2. **Removal of `ask_question` from Custom Agents**:
   - *Proposal*: Remove `ask_question` from agent YAML frontmatters due to reported runtime discrepancies in subagent execution.
   - *Rejection Rationale*: `ask_question` is a core interactive alignment tool. Stripping it breaks clarification capabilities when agents are executed with tool support. Instead, retained `ask_question` with an explicit fallback directive: if running in a runtime that does not expose the tool, agents emit questions directly in plain text.

3. **Purging Multi-Repo Context References**:
   - *Proposal*: Delete references to `architecture.md`, `task_state.md`, and `docs/maintenance-howto.md` from agents like `docs-architect` and `maintenance-bot`.
   - *Rejection Rationale*: Custom agents govern the user's broader project ecosystem (`D:\Github\<Group>\<Project>`), not just `everyday-agy`. Stripping these references breaks cross-repo utility. These references were qualified with "if present in target repo" rather than deleted.

4. **Granting `write_to_file` to `build-error-resolver`**:
   - *Proposal*: Add `write_to_file` to `build-error-resolver` to allow creating missing declaration or export files.
   - *Rejection Rationale*: Constraining `build-error-resolver` strictly to `replace_file_content` is an intentional anti-cheating invariant. Allowing file creation permits Flash models to create dummy `.d.ts` stubs or empty modules to silence compiler errors instead of fixing actual type mismatches at root cause.

## Consequences

- **Positive**:
  - Fleet of 10 orthogonal custom agents with exact 1-to-1 council review seat parity.
  - Subagents reliably load authoritative rules on-demand using absolute context paths without Windows tilde path failures or token bloat.
  - Comprehensive AST safety coverage against quoted flags, reflection invocations, pipelined recursion, and secondary shell launches.
  - Deterministic single-file and git rollback with fail-closed safety and cross-platform compatibility across Windows and Linux CI.
  - Zero false positives on Markdown documentation in modernized secret scanning.
  - Clear documentation of architectural trade-offs and rejected alternatives.
- **Negative / Operational Requirements**:
  - Subagents invoke `view_file` on-demand for relevant task phases, requiring path resolution from prompt headers.
  - Checkpoint test suite execution requires a clean temporary git workspace during CI runs.
