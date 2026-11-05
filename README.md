# everyday-agy

My personal configuration for Google Antigravity, built around the coding workflows and pair-programming habits I use in everyday development.

This repository collects my specialized agent roles, reusable workflow skills, PowerShell AST security guardrails, and architectural decision records (ADRs). It also includes utility scripts to synchronize configurations between my local environment (`~/.gemini/`) and Git, backed by pre-flight credential scanning and automated regression tests.

The setup evolves continuously as I test new patterns, encounter edge cases, and refine workflows. Some components are adapted from community tools (Ponytail, Trail of Bits, Spec-Kit, Superpowers), while others were built for my own project needs. This is a personal configuration, not an enterprise framework or an absolute guarantee against model mistakes.

> [!NOTE]
> **Btw, feel free to ignore `academic-council` (or don't, if you're also fighting an empirical thesis):**  
> Tucked inside the skills catalog is an odd one out: `academic-council`. Full disclosure: I built it on a whim specifically to survive my own undergraduate accounting & finance thesis—validating Indonesia Stock Exchange (IDX/BEI) secondary data, double-checking panel econometrics (Chow/Hausman tests, Cash ETR boundaries), and simulating ruthless oral defense interrogations from thesis committees. If you're here strictly for software engineering dotfiles, feel free to skip it entirely. But if you happen to be a senior student drowning in econometric specs and hallucinated AI citations, *well... feel free to borrow the council!*

> [!WARNING]
> **Token Consumption Warning: `council-review` & `teamwork`**
> Running the deliberative `council-review` skill triggers Antigravity's `teamwork` engine. A full council run spawns 15 to 20+ autonomous subagents in discrete phases (Sentinel, Orchestrator, Parallel Domain Explorers, Adversarial Challengers, and Victory Auditor).
>
> This multi-agent deliberation consumes significant tokens. Reserve `council-review` for high-stakes architectural evaluations, comprehensive security audits, and critical pre-release reviews rather than routine, minor code edits.

## Quick Start

1. Clone the repository:
   ```powershell
   git clone https://github.com/afif25fradana/everyday-agy.git
   cd everyday-agy
   ```
2. Deploy configuration to local Antigravity home:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\restore.ps1
   ```
   *The script runs a pre-flight credential audit, detects existing files in `~/.gemini/`, and creates a timestamped backup (including custom plugins) before deployment.*
3. Configure Model Context Protocol (MCP) authentication:
   Add your Context7 token to `~/.gemini/config/mcp_config.json`:
   ```json
   {
     "mcpServers": {
       "context7": {
         "url": "https://mcp.context7.com/mcp",
         "headers": {
           "Authorization": "Bearer <YOUR_CONTEXT7_API_KEY>"
         }
       }
     }
   }
   ```
4. Sync local modifications back to the repository:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\sync.ps1
   ```
   *The script runs a pattern-based pre-flight audit for known credential and token formats before copying.*

## Tooling & Command Execution

External CLI commands (`git`, `npm`, `ripgrep`, `ast-grep`) execute through [`rtk`](https://github.com/rtk-ai/rtk) when available to compress command output and eliminate token waste before reaching the model.

For the complete catalog of verified CLI tools, official repositories, and an automated Windows administrator installer script, see **[TOOLKIT.md#1-verified-cli-tools](./TOOLKIT.md#1-verified-cli-tools)**.

## Architecture

The repository partitions rules, agents, skills, and decision records to prevent context window dilution.

```text
everyday-agy/
├── TOOLKIT.md           # Catalog of CLI tools, MCP snippets, and skill upstream links
├── config/
│   ├── GEMINI.md        # Tracked global operational rules deployed to ~/.gemini/GEMINI.md
│   ├── agents/          # 11 specialized subagents with hybrid model tiering (ADR-0004, ADR-0017, ADR-0018)
│   └── skills/          # 15 bespoke and engine-adapted workflow skills
├── docs/
│   └── adr/             # Architectural Decision Records (ADR-0001 through ADR-0022)
├── sync.ps1             # Pulls live configs from ~/.gemini/ into this repo
└── restore.ps1          # Deploys this repo into ~/.gemini/ with automatic backup
```

### Operational Guardrails (`config/GEMINI.md` $\rightarrow$ `~/.gemini/GEMINI.md`)
The global rules file stays compact by defining only active behavioral boundaries:
- Investigate first: trace callers with `rtk rg` before proposing or editing code.
- Checkpoint-gated execution: autonomous execution and verification for small fixes (Tier 0/1); explicit approval before multi-file or architectural changes (Tier 2/3, ADR-0015).
- Rollback safety: maintain a clean git checkpoint before modifying files.
- Lean chat: concise status responses (1 to 3 lines) pointing to structured artifacts for review payloads.
- Security boundaries: deny paths (`.env`, `~/.ssh`, token MCP configs), AST command interception (`Test-PowerShellCommandSafety.ps1` regression test suite), and quarantine for external inputs.

### Specialized Agent Roles (`config/agents/`)

Eleven custom subagents handle delegated tasks under a two-tier cognitive model architecture:
- **Analytical & Architecture Roles** (`model: inherit`): Run with full primary model reasoning capacity and read-only/spec boundaries (`system-architect`, `code-auditor`, `database-reviewer`, `silent-failure-hunter`, `spec-verifier`).
- **Focused Execution Roles** (`model: flash`): Optimized for fast, cost-effective diffs and tight scoping (`tdd-guide`, `build-error-resolver`, `ui-crafter`, `docs-architect`, `maintenance-bot`, `l10n-humanizer`).

For the full agent directory, tool boundaries, and delegation parameters, see **[TOOLKIT.md#5-custom-subagents](./TOOLKIT.md#5-custom-subagents)**.

### Workflow Skills and Provenance (`config/skills/`)

Fifteen modular skills are maintained directly within `config/skills/`. Third-party upstream suites (`ponytail`, `taste-skill`, and `antislop`) are decoupled from git tracking per ADR-0006, ADR-0011, and ADR-0016, and installed directly from their respective project repositories:

| Category | Count | Included Skills | Origin / Licensing |
|---|:---:|---|---|
| **Bespoke Architectures** | 7 | `orchestrator`, `council-review`, `academic-council`, `audit-dev-workflow`, `sync-task-state`, `clean-docs`, `deep-web-research` | Original works authored for Antigravity (MIT) |
| **Engine-Adapted Ports** | 8 | `spec-kit`, `gh-workflow`, `audit-context-building`, `differential-review`, `contract-first`, `database-migrations`, `coding-standards`, `documentation-and-adrs` | Adapted from community tools, ECC, and Trail of Bits (MIT & CC BY-SA 4.0) |

Third-party upstream suites (`ponytail`, `taste-skill`, `anti-slop`, and Chrome DevTools) are decoupled from Git tracking per ADR-0016 to prevent vendor bloat.

For trigger commands, detailed skill descriptions, and upstream installation links, see:
- **[Tracked Skills Catalog (`TOOLKIT.md#3-custom-skills-catalog`)](./TOOLKIT.md#3-custom-skills-catalog)**
- **[Decoupled Upstream Skills & Plugins (`TOOLKIT.md#4-recommended-upstream-skills--plugins-decoupled-per-adr-0016`)](./TOOLKIT.md#4-recommended-upstream-skills--plugins-decoupled-per-adr-0016)**

### Architectural Decision Records (`docs/adr/`)
Significant technical decisions, architectural constraints, and operational trade-offs are permanently recorded following the Michael Nygard format.

All 22 active and historical decision records—covering cognitive model tiering, checkpoint gating, lead orchestrator context insulation, and AST safety hardening—are indexed with their status and context in the **[ADR Catalog (`docs/adr/README.md`)](./docs/adr/README.md)**.

## Contributing

1. Keep modifications minimal: shortest working diff wins (see `ponytail`).
2. Avoid generic commentary: remove empty AI narrative comments from code.
3. Propose structural changes through ADRs before modifying directory layouts or core guardrails.
4. Verify PowerShell syntax and run AST safety tests (`Test-PowerShellCommandSafety.Tests.ps1`) locally before committing.

## License

Dual-licensed under MIT and CC BY-SA 4.0:
- Repository scripts, custom subagents, and bespoke skills (`orchestrator`, `council-review`, `academic-council`, `audit-dev-workflow`, `sync-task-state`, `clean-docs`, `deep-web-research`) are licensed under the [MIT License](./LICENSE).
- Adapted Trail of Bits security skills (`audit-context-building`, `differential-review`) are licensed under [Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](./config/skills/audit-context-building/LICENSE).
- Decoupled upstream community skills (`ponytail`, `taste-skill`, `anti-slop`) are referenced under their respective upstream MIT licenses.
