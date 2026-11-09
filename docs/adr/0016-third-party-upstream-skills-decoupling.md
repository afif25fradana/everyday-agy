# ADR-0016: Decouple Vendored Community Skills to External Upstream Links

## Status
Accepted (Supersedes ADR-0002, ADR-0003, and ADR-0006)

## Date
2026-10-31

## Context
Following earlier decoupling decisions for marketplace plugins (ADR-0006) and anti-slop rules (ADR-0011), `everyday-agy` still bundled two large third-party community skill suites directly inside `config/skills/`:
1. `design-taste-frontend` (taste-skill v2): 46 files, ~37,000 lines, including large curated datasets (`sites.json`, `photos.json`, `sections.json`) and `.mjs` scripts.
2. `ponytail`: 6 distinct skill folders (`ponytail`, `ponytail-audit`, `ponytail-debt`, `ponytail-gain`, `ponytail-help`, `ponytail-review`).

A repository audit showed that these bundled community suites accounted for ~38,000 lines (roughly 88% of the repository's volume), distorting GitHub language metrics by classifying a PowerShell/Markdown dotfiles repository as JavaScript. Furthermore, duplicating these upstream packages in git created maintenance staleness, especially since upstream projects provide direct installation paths (e.g. `npx skills add <url>`).

## Decision
1. **Decouple Community Skill Suites from Git Tracking**:
   - Remove `design-taste-frontend` and all 6 `ponytail*` directories from `config/skills/` in git tracking.
   - Retain strictly the 13 bespoke and engine-adapted workflow skills in `config/skills/`.
2. **Exclude Community Skills from Synchronization (`sync.ps1`)**:
   - Define an `$externalSkills` list in `sync.ps1` to prevent local installations of `design-taste-frontend` and `ponytail*` in `~/.gemini/config/skills/` from being re-ingested into git tracking.
3. **Link Directly to Upstream Repositories**:
   - In `restore.ps1`, `README.md`, and `TOOLKIT.md`, provide direct links to the official upstream repositories where installation instructions are maintained:
     - [Taste-Skill (`design-taste-frontend`)](https://github.com/Leonxlnx/taste-skill)
     - [Ponytail Suite](https://github.com/DietrichGebert/ponytail)
     - [Anti-Slop Plugin](https://github.com/miqdadbadjuber/anti-slop)
4. **Calibrate Continuous Integration Checks**:
   - Update `.github/workflows/ci.yml` skill count assertions to reflect the tracked bespoke skills (`>= 10`).
   - Remove redundant `.gitattributes` linguist overrides.
5. **Simplify Repository Governance Files**:
   - Remove boilerplate `.github/CODE_OF_CONDUCT.md`, `.github/CONTRIBUTING.md`, and `.github/SECURITY.md`.
   - Keep concise, actionable contributing guidelines directly in `README.md` (minimal diffs, comment hygiene, and command safety verification).

## Alternatives Considered & Rejected
- **Using git submodules for community skills**: Rejected because managing submodule pointers adds unnecessary friction for personal dotfile repositories.
- **Keeping local vendor copies**: Rejected because bundling ~38,000 lines of third-party JavaScript creates maintenance debt and obscures the repository's core PowerShell tooling.

## Consequences
- **Positive**: Eliminates ~38,000 lines of third-party code from git tracking; repository footprint drops to ~5,400 lines of genuine configuration files.
- **Positive**: GitHub language statistics accurately identify the repository as PowerShell and Markdown.
- **Positive**: Avoids bundling stale upstream datasets.
- **Trade-off**: Setting up a new machine requires installing external community skills directly from upstream repositories rather than having them copied automatically by `restore.ps1`.
