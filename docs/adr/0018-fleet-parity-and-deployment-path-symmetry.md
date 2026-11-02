# ADR-0018: 11-Agent Fleet Parity, Deployment Path Symmetry, and Global Rule Token Optimization

## Status
Accepted

## Date
2026-11-02

## Context
A forensic audit and deliberative council evaluation of `everyday-agy` identified several operational and architectural inconsistencies across agent manifests, file deployments, and cognitive token consumption:
1. **Fleet Parity Drift (`GAP-HIGH-05`)**: The 11th specialized custom agent (`l10n-humanizer`) existed in the live user runtime (`~/.gemini/config/agents/l10n-humanizer/`) but was omitted from repository tracking (`config/agents/`). Consequently, executing `restore.ps1` threatened to prune the agent during directory synchronization. Furthermore, `l10n-humanizer` lacked frontmatter `skills:` bindings (`clean-docs`, `coding-standards`), the ADR-0017 Mandatory Skill Activation Gate, and explicit path boundary definitions.
2. **ADR Deployment Path Split-Brain (`GAP-ARCH-01`)**: `restore.ps1` deployed Architectural Decision Records to `~/.gemini/config/docs/adr/`, while the Git repository housed them at `docs/adr/`. This path asymmetry broke relative links (`../../../docs/adr/`) in installed skills, prompt templates, and AI-context files.
3. **Double `GEMINI.md` Rule Injection (`GAP-TOK-01`)**: When `everyday-agy` was opened as the active workspace, Antigravity injected both `~/.gemini/GEMINI.md` (`RULE[user_global]`) and repository root `everyday-agy/GEMINI.md` (`RULE[workspace]`). Because the repository root file was an identical copy of the global configuration, the identical ~65 lines (~1,840 tokens) were double-injected on every single turn, inflating token overhead and diluting context reasoning.
4. **Orphan Skill Files & Non-Mirroring Sync (`GAP-MED-03`)**: Previous skill restoration used naive `Copy-Item -Recurse`, which copied new files but never pruned deleted or obsolete scripts (e.g. `Export-AuditEvidence.ps1`) from `~/.gemini/config/skills/`, causing ghost scripts to persist indefinitely.
5. **Checkpoint Branch Accumulation (`GAP-MED-05`)**: Checkpoint Git branches (`checkpoint-<task>`) accumulated without standard post-commit deletion instructions in operational runbooks, leading to stale branch sprawl.
6. **Token Bloat in Skill Frontmatter & Agent Manifests (`GAP-MED-06`)**: Verbose frontmatter descriptions across 11 `SKILL.md` files burned ~550 tokens per turn in the `<skills>` prompt block, while `system-architect` duplicated the 5-phase Expand/Contract database migration protocol verbatim instead of delegating to `database-migrations/SKILL.md`.

## Decision

1. **Formalize 11-Agent Fleet Parity**:
   - Track `l10n-humanizer` in repository `config/agents/l10n-humanizer/agent.md` with `model: flash`, frontmatter bindings for `clean-docs` and `coding-standards`, `ask_question`, and `run_command` restricted to read-only JSON/XML validation.
   - Enforce the ADR-0017 `## Mandatory Skill Activation Gate` and restrict file mutations strictly to localization resource paths (`locales/**`, `Strings/**`, `*.resw`, `*.json`, `*.resx`, `*.po`, `*.xaml`, `*.yaml`).
   - Map Seat 11 permanently in `council-review/references/seat-catalog.md`.

2. **Standardize ADR Deployment Path Symmetry (`GAP-ARCH-01`)**:
   - Align ADR storage strictly to `~/.gemini/docs/adr/` in 1-to-1 directory parity with repository root `docs/adr/`.
   - Update `restore.ps1` to deploy ADRs to `~/.gemini/docs/adr/` and automatically purge legacy `~/.gemini/config/docs/adr/` directories.
   - Update `sync.ps1` to pull ADRs from `~/.gemini/docs/adr/` with seamless migration fallback.

3. **Relocate Tracked Global Prompt to `config/GEMINI.md` (`GAP-TOK-01`)**:
   - Move the canonical tracked global prompt from repository root `GEMINI.md` to `config/GEMINI.md`, preserving its complete rule set.
   - Update `sync.ps1` and `restore.ps1` to synchronize `config/GEMINI.md` $\leftrightarrow$ `~/.gemini/GEMINI.md`.
   - Update CI (`.github/workflows/ci.yml`), `README.md`, and relative links in `config/skills/` (`../../GEMINI.md`).
   - Eliminate workspace double-injection when `everyday-agy` is open, immediately freeing ~1,840 tokens per turn.

4. **Clean Skill Directory Mirroring & Orphan Cleanup (`GAP-MED-03`)**:
   - Enhance `restore.ps1` to mirror tracked skill subdirectories, pruning obsolete files (such as `Export-AuditEvidence.ps1`) from `~/.gemini/config/skills/` while preserving decoupled upstream skills (`ADR-0016`).
   - Remove orphan `Export-AuditEvidence.ps1` from the codebase.

5. **Operational Checkpoint Branch Deletion (`GAP-MED-05`)**:
   - Add Step 5 to Phase 5 of `audit-dev-workflow/SKILL.md` mandating clean deletion of local `checkpoint-<task>` branches via `rtk git branch -d` post-commit.

6. **Agent & Skill Frontmatter Token Trimming (`GAP-MED-06`)**:
   - Trim frontmatter descriptions across all 11 repository skills to $\le 128$ characters, saving ~550 tokens per turn.
   - Replace inlined Expand/Contract migration steps in `system-architect` with a concise cross-reference to `database-migrations/SKILL.md`.

## Consequences
- **Positive**: Total elimination of double rule injection in workspace context (~1,840 tokens saved per turn). Skill description trimming frees an additional ~550 tokens per turn across all sessions.
- **Positive**: Complete 1-to-1 fleet parity across repo, runtime, and council seats without risk of agent pruning.
- **Positive**: Symmetrical ADR paths ensure all relative markdown references resolve consistently in both Git checkouts and installed `~/.gemini/` environments.
- **Neutral**: Any script relying on root `everyday-agy/GEMINI.md` must now reference `config/GEMINI.md` in repository checkouts.

## Alternatives Considered & Rejected
- *Gutting root `GEMINI.md` into delta rules without moving tracked file*: Rejected because `restore.ps1` would overwrite and destroy global `~/.gemini/GEMINI.md` during subsequent deployments.
- *Symlinking `~/.gemini/config/docs/adr` to `~/.gemini/docs/adr`*: Rejected due to Windows unprivileged symlink permission restrictions (`Developer Mode` required). Symmetrical physical directories in `restore.ps1` provide robust zero-dependency parity.
