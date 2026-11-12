# everyday-agy

My personal configuration for Google Antigravity, built around how I actually code and pair with AI day to day.

It holds my specialized agent roles, workflow skills, PowerShell AST security guardrails, and architectural decision records (ADRs). It also includes sync scripts to mirror configurations between my local environment (`~/.gemini/`) and Git, backed by pre-flight credential scanning and automated regression tests.

I tweak this setup constantly as I try new patterns and hit edge cases. Some parts are adapted from community tools (Ponytail, Trail of Bits, Spec-Kit, Superpowers); the rest solves specific quirks in my own stack. This is a personal setup built for one developer—LLMs are inherently non-deterministic, so always review what they generate.

> [!CAUTION]
> **Heads up before you clone or run anything:** Do not blindly run `restore.ps1` on your machine. Even though it saves a timestamped backup first, it overwrites your global `~/.gemini/GEMINI.md` and `~/.gemini/config/` with my personal environment configurations:
> - **Personal paths:** Deploys hardcoded paths (`D:\Github`) and user-specific working directory assumptions across operational rules.
> - **WSL2 Arch Linux environment:** Assumes an active Arch Linux distribution under WSL2 (`wsl -d archlinux`) for Linux tool execution and fallback shells.
> - **AST command hooks:** Installs strict runtime hook routing (`config/hooks.json`) and PowerShell AST safety filters (`config/scripts/Test-PowerShellCommandSafety.ps1`) that intercept shell executions, reject destructive primitives, and restrict sensitive file paths.
>
> If you just want the core ideas, point your own AI coding agent at this repository and ask it to distill or adapt the specific rules, hooks, or skills that fit your setup.

> [!NOTE]
> **Btw, feel free to ignore `academic-council` (or don't, if you're also fighting an empirical thesis):**  
> Tucked inside the skills catalog is an odd one out: `academic-council`. Full disclosure: I built it on a whim specifically to survive my own undergraduate accounting & finance thesis: validating Indonesia Stock Exchange (IDX/BEI) secondary data, double-checking panel econometrics (Chow/Hausman tests, Cash ETR boundaries), and simulating ruthless oral defense interrogations from thesis committees. If you're here strictly for software engineering dotfiles, feel free to skip it entirely. But if you happen to be a senior student drowning in econometric specs and hallucinated AI citations, go ahead and use the academic council prompts.

> [!WARNING]
> **Token Consumption Warning: `council-review` & `teamwork`**
> Running the `council-review` skill triggers Antigravity's `teamwork` engine. A council run selects specialized reviewer seats from the 10-agent fleet based on evaluation signals across review phases (Sentinel, Orchestrator, Parallel Domain Explorers, Adversarial Challengers, and Victory Auditor).
>
> This multi-agent deliberation consumes significant tokens. Save `council-review` for major architectural decisions, security reviews, and pre-release gates rather than routine edits.

## Architecture

Rules, agents, skills, and decision records are kept strictly separated so they only load when needed, keeping context windows lean.

```text
everyday-agy/
├── .github/
│   ├── tests/           # Regression test suites (*.Tests.ps1), isolated from ~/.gemini/ deployment
│   └── workflows/       # GitHub Actions CI validation matrix (Ubuntu + Windows)
├── TOOLKIT.md           # Catalog of CLI tools, MCP snippets, and skill upstream links
├── config/
│   ├── GEMINI.md        # Tracked global operational rules deployed to ~/.gemini/GEMINI.md
│   ├── hooks.json       # Native Antigravity PreToolUse/PostToolUse hook definitions
│   ├── scripts/         # Native hook router, AST command safety, checkpoints & diffs (5 scripts)
│   ├── agents/          # 10 specialized subagents with hybrid model tiering (ADR-0002)
│   └── skills/          # 15 bespoke and engine-adapted workflow skills
├── docs/
│   └── adr/             # Living Domain Architectural Decision Records (Nygard format)
├── sync.ps1             # Pulls repo-tracked configs from ~/.gemini/ into this repo
└── restore.ps1          # Deploys repo-tracked configs into ~/.gemini/ with automatic backup
```

### Operational Guardrails (`config/GEMINI.md` → `~/.gemini/GEMINI.md`)
The global rules file stays intentionally lean—focusing on active boundaries rather than prompt bloat:
- Investigate first: trace callers with `rtk rg` before proposing or editing code.
- Checkpoint-gated execution: autonomous execution and verification for small fixes (Tier 0/1); explicit approval before multi-file or architectural changes (Tier 2/3, ADR-0001).
- Rollback safety: maintain a clean git checkpoint before modifying files.
- Lean chat: concise status responses (1 to 3 lines) pointing to structured artifacts for review payloads.
- Security boundaries: deny paths (`.env`, `~/.ssh`, token MCP configs), native hook router enforcement (`config/hooks.json`, `config/scripts/Invoke-AntigravityHook.ps1`), regression and command interception tests (`.github/tests/*.Tests.ps1`), and quarantine for external inputs.

### Specialized Agent Roles (`config/agents/`)

I run 10 custom subagents with an 8 `model: inherit` / 2 `model: flash` split (ADR-0002) backed by native `hooks.json` enforcement. Google Antigravity's official docs barely explain how subagent routing or thinking budgets actually work under the hood, and subagent frontmatter doesn't let you pick specific model variants or thinking effort levels.

I use `Gemini 3.8 Flash (High)` as my daily driver on a free/Jio trial tier instead of burning tokens on `Gemini 4 Argon`. Flash works well, but as a parent orchestrator it occasionally drops multi-step constraints. Native `hooks.json` guards catch those slips at runtime, while `model: inherit` keeps the 8 reasoning and craft specialists on `High` thinking from the main session rather than dropping them into a weaker default Flash worker:

- **Analytical, Craft & Architecture Roles** (`model: inherit`): Inherit the primary session model for planning, audits, test design, documentation, localization, and UI craft (`system-architect`, `code-auditor`, `silent-failure-hunter`, `spec-verifier`, `tdd-guide`, `docs-architect`, `l10n-humanizer`, `ui-crafter`).
- **Build Fix & Maintenance Roles** (`model: flash`): Run on Flash for fast single-file compiler fixes and dependency maintenance (`build-error-resolver`, `maintenance-bot`).

For the full agent directory, tool boundaries, and delegation parameters, see **[Custom Subagents Fleet in TOOLKIT.md](./TOOLKIT.md#5-custom-subagents)**.

### Workflow Skills (`config/skills/`)

I maintain 15 workflow skills directly in `config/skills/`. Third-party suites (`ponytail`, `taste-skill`, and Chrome DevTools) are kept outside git tracking per ADR-0002 and installed straight from their upstream repos:

| Category | Count | Included Skills | Origin / Licensing |
|---|:---:|---|---|
| **Bespoke Architectures** | 7 | `orchestrator`, `council-review`, `academic-council`, `audit-dev`, `sync-task-state`, `clean-docs`, `deep-web-research` | Original works authored for Antigravity (MIT) |
| **Engine-Adapted Ports** | 8 | `spec-kit`, `gh-workflow`, `audit-context-building`, `differential-review`, `contract-first`, `database-migrations`, `coding-standards`, `documentation-and-adrs` | Adapted from community tools, ECC, and Trail of Bits (MIT & CC BY-SA 4.0) |

For trigger commands, detailed skill descriptions, and upstream installation links, see:
- [**Tracked Skills Catalog**](./TOOLKIT.md#3-custom-skills-catalog)
- [**Recommended Upstream Skills & Plugins**](./TOOLKIT.md#4-recommended-upstream-skills-plugins-decoupled-per-adr-0002)

### Architectural Decision Records (`docs/adr/`)
I track key architectural decisions and operational trade-offs using Michael Nygard's ADR format under `docs/adr/`.

These live documents cover orchestrator delegation, fleet model tiering, runtime safety hooks, review councils, and documentation sync boundaries. They are maintained in place and indexed in the **[ADR Catalog](./docs/adr/README.md)**, leaving past versions to Git history.

## Quick Start

> [!IMPORTANT]
> Only run `restore.ps1` verbatim if you intentionally want this exact Windows and WSL2 Arch setup copied into `~/.gemini/`. Otherwise, point your own AI coding agent at this repo to extract and adapt the rules, hooks, and skills that fit your setup.

1. Clone the repository:
   ```powershell
   git clone https://github.com/afif25fradana/everyday-agy.git
   cd everyday-agy
   ```
2. Deploy configuration to local Antigravity home:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\restore.ps1
   ```
   *Runs a pre-flight credential scan and creates a timestamped backup in `~/.gemini/` before deploying repo-tracked files. External skills and third-party plugins in `~/.gemini/` are preserved.*
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
   *Runs a pre-flight credential scan before copying repo-tracked files back into the repository. Untracked local configurations and third-party plugins remain untouched.*

## Tooling & Command Execution

External CLI tools (`git`, `npm`, `npx`, `pip`, `ripgrep`) run through [`rtk`](https://github.com/rtk-ai/rtk) when installed to strip terminal noise and cut token usage before output reaches the model.

For the complete catalog of verified CLI tools, official repositories, and an automated Windows administrator installer script, see **[Verified CLI Tools in TOOLKIT.md](./TOOLKIT.md#1-verified-cli-tools)**.

## License

Dual-licensed under MIT and CC BY-SA 4.0:
- Repository scripts, custom subagents, and bespoke skills (`orchestrator`, `council-review`, `academic-council`, `audit-dev`, `sync-task-state`, `clean-docs`, `deep-web-research`) are licensed under the [MIT License](./LICENSE).
- Adapted Trail of Bits security skills (`audit-context-building`, `differential-review`) are licensed under [Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](./config/skills/audit-context-building/LICENSE).
- Decoupled upstream community skills (`ponytail`, `taste-skill`) are referenced under their respective upstream MIT licenses.
