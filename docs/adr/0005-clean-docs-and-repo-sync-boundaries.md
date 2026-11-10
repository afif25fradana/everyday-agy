# ADR-0005: Clean Documentation Standards, Living ADRs, and Sync Boundaries

## Status
Accepted

## Date
2026-11-11

## Context
Documentation and sync workflows across `everyday-agy` ran into four recurring issues:
1. **AI writing tells and corporate template bloat**: Docs and commit messages accumulated indie-hacker slogans, false-contrast phrasing (`"Not X; it is Y"`), corporate bureaucracy files (`CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/*`) that did not fit a personal dotfiles repo, and internal workflow tags leaking into client application repos.
2. **Duplicate `GEMINI.md` prompt injection**: Keeping the tracked global rules at repository root `GEMINI.md` caused Antigravity to inject both `~/.gemini/GEMINI.md` and workspace `GEMINI.md` whenever working in `everyday-agy`, loading ~65 lines (~1,840 tokens) twice on every turn.
3. **Sync and deployment drift**: `sync.ps1` and `restore.ps1` carried dead `$externalSkills` and `$officialPlugins` lists, omitted `config/hooks.json` and `config/scripts/`, left deleted files behind, and risked copying stale `~/.gemini/docs/adr` files back over Git. Also, an earlier ADR falsely claimed `restore.ps1` backed up `$configHome\plugins`; inspecting `restore.ps1` confirmed it backs up `GEMINI.md`, `hooks.json`, `scripts/`, `agents/`, and `skills/` while leaving `plugins/` untouched on disk.
4. **Append-only ADR sprawl**: Maintaining 30 point-in-time delta ADRs forced readers to trace superseded chains across dozens of files instead of reading current decisions per domain.

## Decision

### 1. Tri-Guard Editorial Standard (`config/skills/clean-docs/SKILL.md`)
I use `clean-docs/SKILL.md` as the single editorial standard for prose, commits, and public docs:
- **Plain register & zero process leaks**: Describe changes in plain developer language; keep internal session tags, stage markers, and checkpoint chatter out of client repos (while permitting framework domain concepts like `Gate 1`, `Gate 2`, and `checkpoint commit` inside meta-framework repos such as `everyday-agy`). Use humanized Conventional Commits and zero sycophantic praise in reviews.
- **Public repo hygiene**: Follow the 4-Part Pragmatic README layout (what it is, why it exists, verified quick start, architecture & scope; personal dotfiles and configuration repositories are allowed to place `Architecture & Scope` ahead of `Quick Start` so readers see layout and overwrite boundaries before running setup commands), gate test/platform claims on green CI at `HEAD`, omit volatile counts in `README.md`/`CHANGELOG.md`, apply the Stranger Test and Naive Reader Paraphrase Test, and pass the 5-Point Sanitization & Caveat Calibration filter (`DROP | CALIBRATE | RELOCATE | KEEP`).
- **Tri-Guard SSOT (Section 6)**:
  - *Guardrail A (Voice & Anti-Corporate Cosplay)*: Honest developer notebook prose; ban ProductHunt hooks, unrequested roleplay dialogues, and all punctuation variants of `"Not X, but Y"`. Never add enterprise community templates to personal/dotfiles repos unless asked; I removed `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/*`, `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`, and `README.md`'s `## Contributing` section here.
  - *Guardrail B (Upfront Sandbox & Scaffolding Honesty)*: State prototype, stub, or mockup limits in opening paragraphs rather than hiding them in footnotes.
  - *Guardrail C (Cross-Session Continuity via `task_state.md`)*: Read `task_state.md` in the target repo or sibling `<Project>-AI-Context` before rewriting public docs so settled trade-offs and terminology carry across sessions.

### 2. Living Domain ADRs vs Twin-Repo Compatibility (`documentation-and-adrs/SKILL.md`)
- **Living Domain ADRs (primary in `everyday-agy`)**: Keep `docs/adr/` bounded to `5-8` domain-scoped `Accepted` ADRs formatted in Michael Nygard sections (`# ADR-000N: ...`, `## Status`, `## Date`, `## Context`, `## Decision`, `## Alternatives Considered & Rejected`, `## Consequences`). When decisions evolve, update the matching domain ADR in place, refresh `## Date`, and rely on `rtk git log` as the historical ledger of superseded states. Two-way parity with `docs/adr/README.md` is enforced in CI via `[System.StringComparer]::Ordinal`.
- **Convention Discovery & Twin-Repo compatibility**: `config/skills/documentation-and-adrs/SKILL.md` detects both repository layout (Twin-Repo `<Project>-AI-Context/` vs Single-Repo `docs/adr/`) and lifecycle convention (Living Domain in-place updates vs traditional Append-Only `SUPERSEDED` chains for external Twin-Repos), enforces `Match Form to Failure` rules for agent/skill authoring, keeps skill `description:` `<= 128` chars, and standardizes relative ADR link depths (`../../../docs/adr/` from `SKILL.md`, `../../../../docs/adr/` from `references/`).
- **Task state boundary (`sync-task-state/SKILL.md`)**: Active `task_state.md` files stay `<= 8,192 bytes`, `<= 100 lines`, and `<= 5` single-line gotchas (`- [DOMAIN/SUBSYS] ...`), retaining only 1-2 recent milestones while Git holds history. Subagents execute Steps 1-4 only and leave commits to the Parent.

### 3. Documentation Ownership and `l10n-humanizer` Dual Scope
- **`docs-architect` (`Mode A` / `Mode B`)**: Sole owner of ADR decisions, architectural structure, `docs/adr/README.md` indexing, `architecture.md`, `task_state.md`, and public repository docs.
- **`l10n-humanizer` (`Scope A` / `Scope B`)**: Handles Indonesian UI localization (`Scope A` following the Microsoft Language Style Guide: capitalized `"Anda"`, modern tech terms kept untranslated, `&amp;` XML escaping, 20-30% layout expansion budget) and second-pass bilingual prose polish (`Scope B`: purging 7 Instant-Edit Tells under a strict Fact & Code Preservation Lock with a 3-Stage scratch reflection ledger). `l10n-humanizer` stays strictly barred from editing `GEMINI.md`; any Scope B polish on `docs/adr/**` is restricted to prose cleanup under Fact Lock without modifying decisions, Nygard headings, `## Status`, `## Date`, coordinates, or `docs/adr/README.md` indexing.

### 4. Global Rules Deduplication and Repo-Only Sync Boundaries (`config/GEMINI.md`, `restore.ps1`, `sync.ps1`)
- **Move global rules to `config/GEMINI.md`**: I moved tracked rules from root `GEMINI.md` into `config/GEMINI.md` (deployed by `restore.ps1` to `~/.gemini/GEMINI.md`). That stops duplicate rule injection and saves ~65 lines (~1,840 tokens) per turn inside `everyday-agy`.
- **Repo-only `docs/adr/` (no symlinks or home sync)**: I rejected Windows symlinks for ADR directories due to Windows permission restrictions, and stopped copying or syncing `docs/adr/` to `~/.gemini/` altogether. `sync.ps1` ignores `docs/adr/`, while `restore.ps1` deletes stale `~/.gemini/docs/adr` and `~/.gemini/config/docs/adr` folders (removing parent `docs/` only when empty so sibling user notes remain intact).
- **Timestamped backups, symmetric scans, and clean pruning**:
  - `restore.ps1` runs a pre-flight non-binary credential scan, backs up existing `~/.gemini/GEMINI.md`, `config/hooks.json`, `config/scripts/`, `config/agents/`, and `config/skills/` to `~/.gemini/backup_<timestamp>/` (leaving `$configHome\plugins` untouched on disk rather than backing up or overwriting it), deploys tracked configs, prunes retired repo items (`database-reviewer`, `audit-dev-workflow`) and orphan files inside tracked directories without `$count -gt 0` guards, and leaves unrecognized external skills and Marketplace plugins intact.
  - `sync.ps1` discovers tracked agents, skills, and scripts directly from the repository (dropping `$externalSkills` and `$officialPlugins`), guards against deleting repo files when a local source folder is empty, prunes deleted repo orphans, and runs the same non-binary pre-flight secret scan before copying anything into Git.

## Alternatives Considered & Rejected
- **Keeping append-only ADR chains on disk in `everyday-agy`**: Rejected because 30+ point-in-time records created stale cross-references and forced readers to piece together current rules across superseded deltas when Git history already tracks every revision.
- **Syncing `docs/adr/` with `~/.gemini/` via copies or Windows symlinks**: Rejected due to Windows symlink privilege issues and stale local copies overwriting repository history.
- **Retaining root `GEMINI.md`, `$externalSkills` lists, or `$count -gt 0` pruning guards**: Rejected due to ~1,840 wasted tokens per turn, stale config drift, and skipped cleanup when directories are emptied.
- **Keeping `PR` / `ISSUE` templates and `CONTRIBUTING.md` on a personal dotfiles repo**: Rejected as unnecessary boilerplate for a single-developer configuration repository.

## Consequences
- **Positive**: Saves ~1,840 tokens per turn in `everyday-agy`, keeps ADRs bounded and verified 1:1 by CI, prevents stale `~/.gemini/` ADRs from overwriting Git, and protects external skills and plugins during restore/sync.
- **Negative / Operational Requirements**:
  - Contributors and AI sessions rely on `rtk git log` when researching historical superseded decisions beyond current Living Domain ADRs.
  - `restore.ps1` permanently removes legacy `~/.gemini/docs/adr` and `~/.gemini/config/docs/adr` directories on deployment.
