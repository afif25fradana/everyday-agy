# ADR-0006: Decouple Marketplace Plugins from Git Tracking

## Status
Superseded by ADR-0011 and ADR-0016

## Date
2026-10-22

## Context
Two packaging concerns emerged in `everyday-agy`:
1. **Third-Party Plugin Bundling**:
   `config/plugins/` initially tracked official Google/Chromium plugins (`chrome-devtools-plugin`, `modern-web-guidance-plugin`, and `android-cli-plugin`), adding 49 files and ~6,000 lines of code. These plugins are officially maintained in the Antigravity Plugin Marketplace with their own release cadence. Bundling them in Git duplicates upstream repositories, creates maintenance overhead, and introduces file bloat.
2. **Upstream Skill Tooling Divergence**:
   Security and auditing skills imported from external repositories (`audit-context-building` and `differential-review`) were originally authored for Claude Code, utilizing proprietary Claude tool calls (`Workflow`, `allowed-tools`, and internal `.js` scripts) that do not match Google Antigravity runtime contracts.

## Decision
1. **Decouple Official Marketplace Plugins**:
   Remove all bundled files of official marketplace plugins from the repository. Retain only custom plugins (`antislop`) in `config/plugins/`.
2. **Automate Sync Exclusion**:
   Update `sync.ps1` to filter out official marketplace plugins (`chrome-devtools-plugin`, `modern-web-guidance-plugin`, `android-cli-plugin`), preventing local marketplace installations from being re-ingested into Git tracking.
3. **Catalog via Marketplace Recommendations**:
   Document the official plugins in `TOOLKIT.md` and `README.md` as recommended marketplace installations.
4. **Port External Security Skills to Antigravity Primitives**:
   Adapt `audit-context-building` and `differential-review` to use Antigravity subagent primitives and scratch storage (`$HOME/.gemini/antigravity/scratch/`), preserving invariant-mapping and threat-modeling practices without runtime incompatibilities.
5. **Add Deployment Backups in `restore.ps1`**:
   Introduce automatic timestamped backups (`~/.gemini/backup_<timestamp>/`) prior to deploying configurations on any machine.

## Alternatives Considered & Rejected
- **Vendoring all plugins via Git submodules**: Rejected due to unnecessary submodule pointer management and merge complexity for users.
- **Retaining static upstream Claude workflows**: Rejected because invoking Claude-specific `.js` workflows within Antigravity causes runtime contract errors.

## Consequences
- **Positive**: Removed 49 files and ~6,000 lines of third-party code. Clean separation between user dotfiles and ecosystem plugins.
- **Positive**: Security audits execute using native subagents and semantic triggers.
- **Trade-off**: Users requiring Chrome DevTools or Android CLI capabilities install them via the Marketplace UI rather than getting them pre-copied by `restore.ps1`.
