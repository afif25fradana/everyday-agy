# everyday-agy

Personal, battle-tested Google Antigravity configuration, custom agents, skills, and guardrails.

---

## Architecture Overview

```text
everyday-agy/
├── GEMINI.md            # Global rules, verified tooling, and safety guardrails
├── TOOLKIT.md           # Standalone catalog: verified CLI tools, MCP snippets & skills
├── config/
│   ├── agents/          # 9 specialized subagents (model: inherit)
│   ├── skills/          # Custom workflow skills (spec-kit, gh-workflow, ponytail, etc.)
│   └── plugins/         # Bundled custom plugins (antislop)
├── docs/
│   └── adr/             # Architectural Decision Records (ADR-0001 through ADR-0006)
├── sync.ps1             # Pull active configs from ~/.gemini/ into this repo
└── restore.ps1          # Deploy this configuration to ~/.gemini/ on a fresh machine
```

> [!TIP]
> For a standalone catalog with one-line copy-paste install commands, official GitHub links, and MCP configuration snippets, see [TOOLKIT.md](./TOOLKIT.md).

---

## Components

### 1. Global Rules (`GEMINI.md`)
- **Verified Tooling**: Strict toolbelt definitions (`rtk`, `git`, `gh`, `ast-grep`, `pwsh`, etc.).
- **Guardrails**: Investigate first, explicit user confirmation before mutations, checkpointing, and lean chat output.
- **YAGNI & Anti-Slop**: Code minimalism, shortest working diffs, zero generic AI comments or gradients.
- **Architecture Invariants**: Documented baseline preventing regression on MCP, skills, and subagent tiering.

### 2. Custom Subagents (`config/agents/`)
- `system-architect`: Contract-first API design, Socratic planning, ADR authoring (`model: inherit`).
- `code-auditor`: Non-mutating whole-repo health, security, and test integrity auditor (`model: inherit`).
- `database-reviewer`: PostgreSQL, schema migrations, N+1 detection, zero-downtime expand/contract (`model: inherit`).
- `silent-failure-hunter`: Uncovers swallowed errors and missing error propagation (`model: inherit`).
- `build-error-resolver`: Emergency compilation, typecheck, and build fixes with shortest working diff.
- `tdd-guide`: Red-Green-Refactor test-driven development workflow.
- `docs-architect`: Modern documentation and Nygard ADR authoring.
- `maintenance-bot`: Dependabot triage, CVE mitigation, and CI failure diagnostics.
- `ui-crafter`: Modern web primitives, WCAG AA accessibility, Generative UI widgets.

### 3. Custom Skills (`config/skills/`)
- `spec-kit`: Spec-Driven Development (`/speckit.specify`, `/speckit.plan`, `/speckit.tasks`).
- `gh-workflow`: Automated PR lifecycle and non-interactive CI monitoring via authenticated `gh`.
- `ponytail` (suite of 6): Lazy senior developer mode, one-shot repo audits, debt ledger, and PR reviews.
- `audit-dev-workflow`: Defensive caller tracing, safety checkpoints, and verification.
- `audit-context-building`: Codebase invariant mapping before auditing (adapted from Trail of Bits for Antigravity).
- `design-taste-frontend`: Anti-slop frontend art direction and visual craft.
- `differential-review`: Security-focused differential review for commits and PRs (adapted from Trail of Bits for Antigravity).
- `documentation-and-adrs`: Standardized Architectural Decision Records.
- `sync-task-state`: Lightweight active context maintenance for Twin-Repo setups.

### 4. Architectural Decision Records (`docs/adr/`)
- [ADR-0001](./docs/adr/0001-context7-streamable-http-token-headers.md): Context7 Streamable HTTP Header Authentication.
- [ADR-0002](./docs/adr/0002-domain-partitioned-skills-vs-greedy-references.md): Domain-Partitioned Skills vs Greedy References.
- [ADR-0003](./docs/adr/0003-ponytail-5-suite-architecture.md): Preservation of Ponytail 5 Discrete Modal Architecture.
- [ADR-0004](./docs/adr/0004-subagent-model-tiering-inherit.md): Subagent Cognitive Model Tiering (`model: inherit`).
- [ADR-0005](./docs/adr/0005-spec-kit-and-ast-grep-tooling.md): Spec-Kit, GitHub Workflow & AST-Grep Integration.
- [ADR-0006](./docs/adr/0006-marketplace-plugin-decoupling-and-security-adaptation.md): Marketplace Plugin Decoupling & Security Skill Adaptation.

---

## Recommended MCP Integrations

Configured locally in `~/.gemini/config/mcp_config.json`:

| Service | Transport | URL / Command | Purpose | Documentation |
|---|---|---|---|---|
| **Context7** | `Streamable HTTP` | `https://mcp.context7.com/mcp` | Up-to-date documentation & API contracts for external libraries | [context7.com](https://context7.com) |

> [!NOTE]
> In Antigravity, Streamable HTTP headers do not evaluate environment variables. Put your Bearer token directly into your machine's local `~/.gemini/config/mcp_config.json`:
> ```json
> {
>   "mcpServers": {
>     "context7": {
>       "url": "https://mcp.context7.com/mcp",
>       "headers": {
>         "Authorization": "Bearer <YOUR_CONTEXT7_API_KEY>"
>       }
>     }
>   }
> }
> ```

---

## Usage

### Prerequisites & Customization
- **Shell**: Built and optimized for PowerShell 7+ (`pwsh`) on Windows.
- **Tooling & Aliases**: By default, `GEMINI.md` configures external tool execution (`git`, `npm`, `ripgrep`) prefixed with `rtk` if installed. If you do not use `rtk`, remove the prefix line in `GEMINI.md`.
- **GitHub CLI**: Update `gh (authed)` in `GEMINI.md` to match your own GitHub handle if desired.
- **Safe Restore**: `restore.ps1` automatically detects existing configurations in `~/.gemini/` and creates a timestamped backup before deploying.

### Sync Active Changes to Repository
Run this whenever you tweak agents, rules, or skills in your local Antigravity environment:
```powershell
.\sync.ps1
```
*Note: Includes automated credential regex checking to prevent accidental secret commits.*

### Restore / Deploy to New Machine
On a new machine with Antigravity installed:
```powershell
# 1. Clone repository
git clone https://github.com/afif25fradana/everyday-agy.git
cd everyday-agy

# 2. Run restore script (creates backup if existing config is detected)
.\restore.ps1

# 3. Add MCP token locally (if using Context7)
# Edit ~/.gemini/config/mcp_config.json
```

---

## License

MIT License. See [LICENSE](./LICENSE) for details.
