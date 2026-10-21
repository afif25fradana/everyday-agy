# ADR-0006: Marketplace Plugin Decoupling and Security Skill Adaptation

## Status
Accepted

## Date
2026-10-22

## Context
As `everyday-agy` matured toward public release, two architectural liabilities emerged:
1. **Redundant Third-Party Plugin Bundling**:
   `config/plugins/` initially tracked official Google/Chromium plugins (`chrome-devtools-plugin`, `modern-web-guidance-plugin`, and `android-cli-plugin`), adding 49 files and ~6,000 lines of code. These plugins are officially maintained in the Antigravity Plugin Marketplace with their own release cycles. Bundling them in Git duplicates upstream repositories, creates maintenance staleness, and introduces file bloat.
2. **Upstream Skill Tooling Divergence**:
   Advanced security and auditing skills imported from Trail of Bits (`audit-context-building` and `differential-review`) were originally authored for Claude Code, utilizing proprietary Claude tool calls (`Workflow`, `allowed-tools`, and internal `.js` workflow scripts) that fail under Google Antigravity runtime contracts.

## Decision
1. **Decouple Official Marketplace Plugins**:
   Remove all bundled files of official marketplace plugins from the repository. Retain only bespoke/custom plugins (`antislop`) in `config/plugins/`.
2. **Automate Sync Exclusion**:
   Update `sync.ps1` to explicitly filter out official marketplace plugins (`chrome-devtools-plugin`, `modern-web-guidance-plugin`, `android-cli-plugin`), preventing local marketplace installations from being re-ingested into Git tracking.
3. **Catalog via Marketplace Recommendations**:
   Document the official plugins in `TOOLKIT.md` and `README.md` as recommended 1-click marketplace installations.
4. **Port Trail of Bits Security Skills to Antigravity Primitives**:
   Adapt `audit-context-building` and `differential-review` to use Antigravity native subagent primitives (`invoke_subagent` with `TypeName: research, Role: Codebase Context Auditor`) and scratch persistence (`$HOME/.gemini/antigravity/scratch/`), preserving 100% of the invariant-mapping and adversarial threat-modeling methodologies without runtime tool call incompatibilities.
5. **Enforce Safe Deployments in `restore.ps1`**:
   Introduce automatic timestamped backups (`~/.gemini/backup_<timestamp>/`) prior to deploying configurations on any machine.

## Alternatives Considered & Rejected
- **Vendoring all plugins via Git submodules**: Rejected due to unnecessary submodule pointer management and merge complexity for end users.
- **Retaining static upstream Claude workflows**: Rejected because invoking Claude-specific `.js` workflows within Antigravity leads to silent execution failures and tool contract errors.

## Consequences
- **Positive**: Shaved 49 files and ~6,000 lines of redundant third-party code. Clean separation between user dotfiles and ecosystem plugins.
- **Positive**: Antigravity agents autonomously execute security audits using native subagents and semantic triggers.
- **Trade-off**: Users requiring Chrome DevTools or Android CLI capabilities must install them via the Antigravity Marketplace UI rather than getting them pre-copied by `restore.ps1`.
