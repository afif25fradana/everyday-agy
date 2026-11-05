# ADR-0022: Deep Web Research Skill Registration, 5-Axis Ecosystem Audit Hardening, and Token De-duplication

## Status
Accepted

## Date
2026-11-05

## Context
A comprehensive 5-Axis Architecture & Ecosystem Audit across `everyday-agy` (`config/GEMINI.md`, 11 custom subagents, 15 skills, 7 PowerShell scripts/test suites, 21 ADRs, and `.github/workflows/ci.yml`), grounded against official Google Antigravity documentation (`antigravity.google/docs`), Microsoft PowerShell AST documentation (`System.Management.Automation.Language`), PostgreSQL `DO` documentation, and Git CLI specifications, uncovered five categories of defects:

1. **AST Safety & Pre-Flight Scanner Bypass Vectors (Axis 1)**:
   - `Test-PowerShellCommandSafety.ps1` only skipped literal `'proxy'`, `'exec'`, and `'--'` tokens when unwrapping `rtk`, `sudo`, and `gsudo`, allowing wrapper flags (`rtk -v git push --force`, `sudo -E rm -rf ./dir`, `sudo -u root ...`) to bypass subcommand inspection.
   - PowerShell backtick escapes (``git push --`force``, ``i`ex "..."``), internal flag quoting (`--"force"`), two-statement `ScriptBlock` variable invocations (`$s = [scriptblock]::Create(...); $s.Invoke()`), `git switch -f` / `--discard-changes` / `-C`, `git stash drop/clear`, and `robocopy /MIR` were unblocked.
   - `sync.ps1` and `restore.ps1` scanned only a fixed whitelist of file extensions (`-Include "*.md", "*.json", ...`) in Phase 1 while copying all files (`*`) in Phase 2, leaving `.env*`, `.key`, `.pem`, `.txt`, and `.toml` files uninspected prior to copying.
   - `New-AuditCheckpoint.ps1` and `Restore-AuditCheckpoint.ps1` mutated the caller session's working directory on in-process calls (`Set-Location` without `Push-Location`/`Pop-Location`).
2. **Lifecycle Deadlocks & Scratch Path Split-Brain (Axis 4)**:
   - `audit-dev-workflow/SKILL.md` placed Repro-First Failing Test (RED) creation in Phase 1 prior to Gate 1 approval and Phase 2 `New-AuditCheckpoint.ps1`, causing `New-AuditCheckpoint.ps1` to abort on dirty tracked test files and contradicting the Tier 2 flowchart in `orchestrator/SKILL.md`.
   - Three conflicting scratch path conventions (`$HOME/.gemini/antigravity/scratch/<task>/`, `<appDataDir>\brain\<conversation-id>\scratch\<task>\`, and `<appDataDir>\scratch\<project>\`) existed across skills, and `subagent-patterns.md` passed unexpanded `$HOME` strings to `view_file` in its 4-slot templates.
   - `sync-task-state/SKILL.md` instructed subagents to run `git commit`, violating the ADR-0019 Subagent Commit Ban, while `differential-review/methodology.md` instructed `rtk git checkout <baseline_commit>`, violating `code-auditor`'s read-only non-branch-switching invariant.
3. **Subagent Tool Contradictions & Model Tier Drift (Axis 5)**:
   - `build-error-resolver/agent.md` lacked `write_to_file` by design (ADR-0017), yet its `Subagent Mode` section required creating a new scratch file `<appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md`.
   - `subagent-patterns.md` listed `Model: inherit` for `ui-crafter`, `build-error-resolver`, and `maintenance-bot`, contradicting their `model: flash` manifests (`ADR-0004`, `ADR-0012`).
   - `maintenance-bot/agent.md` lacked an `Explicit Tool & Path Boundaries` section, and `TOOLKIT.md` inaccurately listed migration/ADR write access for `database-reviewer` while omitting `Ask` for `l10n-humanizer`.
4. **Context Token Bloat & Broken References (Axis 2 & 3)**:
   - Repeating the 22-line `Dual Execution Mode & 4-Slot Delegation Acceptance` receipt block across all 11 `agent.md` files consumed ~14.7 KB (~3,677 tokens) despite `<RETURN_CONTRACT>` already being injected by `orchestrator/SKILL.md`.
   - `documentation-and-adrs/SKILL.md` contained 180 lines of duplicated comment, OpenAPI, and generic README boilerplate that overlapped with `clean-docs`, `coding-standards`, and `contract-first`.
   - `handoff-spec.md#L48` and `pitfalls.md#L4` contained broken markdown anchors (`#3-five-axis-pre-flight-rubric`), `deep-web-research/SKILL.md` used `curl -sSL` (which collides with the `Invoke-WebRequest` alias in Windows PowerShell 5.1), and `database-migrations/SKILL.md` omitted the PostgreSQL `DO $$ ... COMMIT` outer-transaction restriction.
5. **15-Skill CI & ADR Index Parity**:
   - `deep-web-research` was added as the 15th bespoke skill and enforced in `.github/workflows/ci.yml` (`$skills.Count -ne 15`), superseding the 14-skill assertions recorded in ADR-0020 and ADR-0021, while `README.md` omitted ADR-0021.

## Decision

1. **Fortify PowerShell AST Safety Validator, Pre-Flight Scanners & CI**:
   - Add `Get-NormalizedTokenText` to `Test-PowerShellCommandSafety.ps1` to strip PowerShell backtick escapes (`` ` ``) and internal flag quote obfuscation before AST token matching.
   - Enhance `rtk`/`sudo`/`gsudo` wrapper unwrapping to skip arbitrary wrapper flags (`-v`, `-E`, `-u <user>`) until the underlying command token is reached.
   - Block `[scriptblock]::Create(...)`, `.Invoke()` on `VariableExpressionAst` (`$s.Invoke()`), `git switch -f`/`--discard-changes`/`-C`, `git stash drop/clear`, `robocopy /MIR`/`/PURGE`, and `Invoke-CimMethod`/`Invoke-WmiMethod`, backed by 10 new regression tests in `Test-PowerShellCommandSafety.Tests.ps1`.
   - Expand pre-flight secret scanning in `sync.ps1`, `restore.ps1`, and `.github/workflows/ci.yml` to scan all non-binary files (`Get-ChildItem -Recurse -File -Force`), closing the extension whitelist gap.
   - Wrap `New-AuditCheckpoint.ps1` and `Restore-AuditCheckpoint.ps1` in `Push-Location` / `Pop-Location` and strip UTF-8 BOMs when parsing `untracked_baseline.txt`.
   - Add top-level `permissions: contents: read` and strict agent frontmatter assertions (`model: inherit|flash` and `build-error-resolver` `write_to_file` prohibition) to `.github/workflows/ci.yml`.
2. **Harmonize Gate 1 / Checkpoint / RED Test Sequencing & Unify Scratch Paths**:
   - Align `audit-dev-workflow/SKILL.md` and `handoff-spec.md` with `orchestrator/SKILL.md`: on Tier 2/3, Phase 1 is 100% read-only; `gate1_proposal.md` specifies the repro test plan; after Gate 1 approval and Phase 2 `New-AuditCheckpoint.ps1`, `tdd-guide` authors the failing RED test in Phase 3.
   - Standardize session scratch paths on `<appDataDir>\brain\<conversation-id>\scratch\<task>\` across `council-review`, `academic-council`, `audit-context-building`, and `differential-review`, and replace literal `$HOME` paths in `subagent-patterns.md` `view_file` templates with OS-resolved absolute paths.
   - Restrict `sync-task-state` Step 5 (`git commit`) to the Parent Agent post-approval, and replace `rtk git checkout <baseline_commit>` in `differential-review/methodology.md` with read-only `rtk git show <baseline_commit>:<file>`.
3. **Align Custom Agent Fleet Boundaries, Model Tiers & Token Footprint**:
   - Exempt `build-error-resolver` from creating new scratch files in `Subagent Mode` (`Deliverable Path: N/A (in-place replace_file_content only)`).
   - Restore `model: flash` parity for `ui-crafter`, `build-error-resolver`, and `maintenance-bot` in `subagent-patterns.md`, while codifying optional dynamic elevation (`Model: inherit`) for `docs-architect` and `tdd-guide` on complex Tier 2 tasks.
   - Add `Explicit Tool & Path Boundaries` to `maintenance-bot/agent.md`, clarify Read-Only Explorer vs `spec-kit`/ADR boundaries on `system-architect/agent.md`, and add test token scrubbing (`<TEST_HASH_SANITIZED>`) to `tdd-guide` and `build-error-resolver`.
   - Condense the duplicated 4-slot delegation boilerplate across all 11 `agent.md` files and trim duplicated non-ADR sections from `documentation-and-adrs/SKILL.md`, saving ~18 KB (~4,500 tokens) across the ecosystem.
4. **Formalize 15-Skill Catalog & Trigger Precision**:
   - Formally register `deep-web-research` as the 15th bespoke skill (with `curl.exe` PowerShell 5.1 compatibility and a 3-query stop-rule), wire `spec-kit` into `orchestrator/SKILL.md`, and sharpen YAML `description` triggers across skills while strictly preserving the $\le 128$-character invariant.

## Alternatives Considered & Rejected
- **Merging `deep-web-research` into `spec-verifier` and reducing skill count to 14**: Rejected because `.github/workflows/ci.yml` enforces `$skills.Count -ne 15` and `deep-web-research` provides reusable primary-source search guardrails for `council-review` and `academic-council`.
- **Granting `write_to_file` to `build-error-resolver` for scratch reports**: Rejected per ADR-0017 because granting file creation to a `flash` compiler fixer enables stub `.d.ts` cheating; exempting it from scratch file creation is cleaner and safer.

## Consequences
- **Positive**: Closes 10 concrete PowerShell AST and pre-flight secret scanner bypasses, resolves the Tier 2 Phase 1 RED test vs checkpoint deadlock, eliminates ~4,500 tokens of cross-file duplication, and achieves 100% parity across CI, ADRs, `README.md`, and `TOOLKIT.md`.
- **Negative / Operational Requirements**: All future bespoke skills must maintain the 15-skill CI count (or update `.github/workflows/ci.yml` in lockstep with a new ADR) and keep YAML `description` fields $\le 128$ characters.
