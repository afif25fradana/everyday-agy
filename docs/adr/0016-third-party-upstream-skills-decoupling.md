# ADR-0016: Third-Party Upstream Skills Decoupling and Documentation Linking

## Status
Accepted

## Date
2026-10-31

## Context
Following the successful precedent of ADR-0006 (decoupling official Marketplace plugins) and ADR-0011 (decoupling `antislop`), `everyday-agy` continued to bundle two large third-party community skill suites directly inside `config/skills/`:
1. `design-taste-frontend` (Leonxlnx's taste-skill v2): 46 files, ~37,000 lines, including large curated JSON databases (`sites.json`, `photos.json`, `sections.json`) and `.mjs` scripts.
2. `ponytail` (Dietrich Gebert's ponytail suite): 6 distinct skill folders (`ponytail`, `ponytail-audit`, `ponytail-debt`, `ponytail-gain`, `ponytail-help`, `ponytail-review`).

An external audit (via Qwen in agent mode) noted that these bundled upstream suites accounted for ~38,000 lines (roughly 88% of the repository's total line volume), distorting GitHub language metrics (labeling a PowerShell/Markdown dotfiles repository as "JavaScript") and duplicating upstream repositories that maintain their own dedicated Antigravity installers (`npx taste-skill`, `npx ponytail-ai`).

## Decision
1. **Decouple Upstream Community Suites from Git Tracking**:
   - Remove `design-taste-frontend` and all 6 `ponytail*` directories from `config/skills/` in git tracking.
   - Retain strictly the 13 bespoke and engine-adapted workflow skills in `config/skills/`.
2. **Exclude from Synchronization Scripts (`sync.ps1`)**:
   - Define an explicit `$externalSkills` list in `sync.ps1` to prevent local installations of `design-taste-frontend` and `ponytail*` in `~/.gemini/config/skills/` from being re-ingested into Git tracking.
3. **Hyperlink to Official Upstream Documentation (`restore.ps1`, `README.md`, `TOOLKIT.md`)**:
   - Rather than hardcoding ephemeral shell installation commands in scripts, provide direct hyperlinks to the upstream project repositories where official Antigravity installation instructions are maintained:
     - [Taste-Skill (`design-taste-frontend`)](https://github.com/Leonxlnx/taste-skill)
     - [Ponytail Suite](https://github.com/DietrichGebert/ponytail)
     - [Antislop Plugin](https://github.com/antislop-ai/antislop)
4. **Calibrate CI Integrity Thresholds**:
   - Update `.github/workflows/ci.yml` skill count threshold to `>= 10` (reflecting the 13 tracked bespoke skills).
   - Remove redundant `.gitattributes` linguist overrides.
5. **Eliminate Community Ceremony Overhead (`clean-docs`)**:
   - Remove boilerplate `.github/CODE_OF_CONDUCT.md`, `.github/CONTRIBUTING.md`, and `.github/SECURITY.md`.
   - Preserve lean, actionable contributing guidelines directly in `README.md` (shortest working diffs, anti-slop hygiene, and local AST safety verification).

## Consequences
- **Positive**:
  - Eliminates ~38,000 lines of vendor bloat from the active working tree; the repository footprint drops to ~5,400 lines of genuine personal dotfiles.
  - Strips away corporate open-source ceremony from a personal dotfiles repository.
  - GitHub naturally classifies the repository as **PowerShell & Markdown** without artificial linguist attributes.
  - Zero risk of bundling stale upstream curated datasets or violating upstream release cadence.
  - Cleaner provenance across all agent manifests.
- **Negative / Neutral**:
  - Developers setting up a clean machine must install external community skills directly from upstream repositories rather than having them copied automatically by `restore.ps1`.
