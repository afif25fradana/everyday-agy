# ADR-0018: Track 11th Agent (l10n-humanizer) and Align ADR Directory Paths

## Status
Partially Superseded by ADR-0021, ADR-0027 (fleet consolidated to 10 agents, database-reviewer retired), and ADR-0030 (docs/adr/ stopped deploying to ~/.gemini/)

## Date
2026-11-02

## Context
During a repository audit and deployment review, several inconsistencies were identified across agent manifests, directory paths, and prompt token usage:
1. **Unversioned Localization Agent**:
   An 11th custom agent (`l10n-humanizer`) existed in the local user directory (`~/.gemini/config/agents/l10n-humanizer/`) but was omitted from git tracking in `config/agents/`. Running `restore.ps1` risked pruning the untracked agent directory during synchronization. The agent also lacked frontmatter skill bindings, a mandatory skill activation gate, and explicit path boundaries.
2. **ADR Directory Path Discrepancy**:
   `restore.ps1` deployed ADR files to `~/.gemini/config/docs/adr/`, whereas the repository housed them at `docs/adr/`. This discrepancy broke relative Markdown links (`../../../docs/adr/`) in installed skills and AI context files.
3. **Duplicate Global Rule Injection in Workspace**:
   When `everyday-agy` was opened as the active workspace, Antigravity injected both the global configuration (`~/.gemini/GEMINI.md`) and the repository root `GEMINI.md`. Because the root file was an identical copy of the global configuration, roughly 65 lines (~1,840 tokens) were injected twice into every turn.
4. **Obsolete Files in Skill Directories**:
   Skill restoration used `Copy-Item -Recurse`, which copied new files but did not remove deleted or renamed scripts from `~/.gemini/config/skills/`, allowing obsolete files to persist indefinitely.
5. **Checkpoint Git Branches**:
   Temporary checkpoint branches (`checkpoint-<task>`) accumulated without guidance for post-commit deletion.
6. **Skill Frontmatter Description Lengths**:
   Verbose frontmatter descriptions across 11 skill files added unnecessary token overhead to the prompt header block on every turn.

## Decision
1. **Track 11th Custom Agent (`l10n-humanizer`)**:
   - Add `l10n-humanizer` to `config/agents/l10n-humanizer/agent.md` with `model: flash`, frontmatter skill bindings, `ask_question`, and validation tools.
   - Restrict the agent's file mutations to localization resource files (`locales/**`, `Strings/**`, `*.resw`, `*.json`, `*.resx`, `*.po`, `*.xaml`, `*.yaml`).
   - Add the agent to `council-review/references/seat-catalog.md`.
2. **Align ADR Deployment Directory Structure**:
   - Standardize installed ADR storage at `~/.gemini/docs/adr/` to match the repository layout.
   - Update `restore.ps1` to deploy ADRs to `~/.gemini/docs/adr/` and remove legacy directories.
   - Update `sync.ps1` to pull ADRs from `~/.gemini/docs/adr/`.
3. **Relocate Tracked Global Prompt to `config/GEMINI.md`**:
   - Move the repository's copy of the global configuration from the root directory to `config/GEMINI.md`.
   - Update `sync.ps1` and `restore.ps1` to synchronize `config/GEMINI.md` with `~/.gemini/GEMINI.md`.
   - Update CI and documentation references.
   - Moving the file stops Antigravity from injecting the duplicate workspace rules, saving ~1,840 tokens per turn when working on this repository.
4. **Prune Obsolete Files During Skill Restoration**:
   - Update `restore.ps1` to mirror tracked skill subdirectories and remove obsolete scripts while preserving decoupled external community skills.
   - Remove obsolete helper scripts from the repository.
5. **Document Checkpoint Branch Cleanup**:
   - Document deleting local `checkpoint-<task>` branches using `rtk git branch -d` following successful commits.
6. **Trim Skill Frontmatter Descriptions**:
   - Shorten frontmatter descriptions across repository skills to 128 characters or fewer, saving prompt tokens.
   - Replace long inlined migration steps in `system-architect` with a reference to `database-migrations/SKILL.md`.

## Alternatives Considered & Rejected
- **Removing root `GEMINI.md` rules without moving the tracked file**: Rejected because `restore.ps1` would overwrite global configurations with empty files on deployment.
- **Using symlinks for ADR directories**: Rejected due to Windows symlink permission restrictions. Standard physical directories deployed by `restore.ps1` provide consistent cross-platform behavior.

## Consequences
- **Positive**: Eliminates duplicate rule injection in the workspace context, saving ~1,840 tokens per turn.
- **Positive**: Full 11-agent fleet tracked in version control and mapped in review catalogs.
- **Positive**: Matching ADR paths ensure relative Markdown links resolve identically in checkouts and installed directories.
- **Neutral / Operational Requirements**: Repository scripts referencing the configuration must point to `config/GEMINI.md`.
