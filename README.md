# everyday-agy

My personal configuration for Google Antigravity, built around the coding workflows and pair-programming habits I use in everyday development.

This repository collects my specialized agent roles, reusable workflow skills, PowerShell AST security guardrails, and architectural decision records (ADRs). It also includes utility scripts to synchronize configurations between my local environment (`~/.gemini/`) and Git, backed by pre-flight credential scanning and automated regression tests.

The setup evolves continuously as I test new patterns, encounter edge cases, and refine workflows. Some components are adapted from community tools (Ponytail, Trail of Bits, Spec-Kit), while others were built for my own project needs. This is a personal configuration, not an enterprise framework or an absolute guarantee against model mistakes.

> [!NOTE]
> **Btw, feel free to ignore `academic-council` (or don't, if you're also fighting an empirical thesis):**  
> Tucked inside the skills catalog is an odd one out: `academic-council`. Full disclosure: I built it on a whim specifically to survive my own undergraduate accounting & finance thesis—validating Indonesia Stock Exchange (IDX/BEI) secondary data, double-checking panel econometrics (Chow/Hausman tests, Cash ETR boundaries), and simulating ruthless oral defense interrogations from thesis committees. If you're here strictly for software engineering dotfiles, feel free to skip it entirely. But if you happen to be a senior student drowning in econometric specs and hallucinated AI citations, *well... feel free to borrow the council!*

> [!WARNING]
> **Token Consumption Warning: `council-review` & `teamwork_preview`**
> Running the deliberative `council-review` skill triggers Antigravity's experimental `teamwork_preview` engine. A full council run spawns 15 to 20+ autonomous subagents in discrete phases (Sentinel, Orchestrator, Parallel Domain Explorers, Adversarial Challengers, and Victory Auditor).
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

## Verified Tools and Commands

The environment registers verified command-line tools in `GEMINI.md`. External commands (`git`, `npm`, `ripgrep`) execute through `rtk` when available to reduce token consumption:

| Command / Tool | Category | Role in Environment |
|---|---|---|
| `rtk` | Token Proxy | Compresses CLI outputs and filters token waste before sending to the model |
| `ast-grep` (`sg`) | Structural Search | Performs multiline, syntax-tree-accurate code search and refactoring |
| `gh` | GitHub CLI | Automates PR creation, non-interactive CI monitoring, and PR review comments |
| `ripgrep` (`rg`) | Text Search | Traces upstream callers, symbols, and references across files |
| `pwsh` | Shell | Preferred execution shell (PowerShell 7+) on Windows hosts |
| `fzf` | Interactive Filter | Fuzzy directory and file navigation helper |
| `ffmpeg` | Media Utility | Media inspection and asset optimization |
| `adb` | Device Bridge | Android debugging bridge for mobile testing workflows |

## Architecture

The repository partitions rules, agents, skills, and decision records to prevent context window dilution.

```text
everyday-agy/
├── GEMINI.md            # Active operational rules, workflow guardrails, and security boundaries
├── TOOLKIT.md           # Catalog of CLI tools, MCP snippets, and skill upstream links
├── config/
│   ├── agents/          # 11 specialized subagents configured with hybrid model tiering (ADR-0004)
│   └── skills/          # 20 curated, adapted, and bespoke workflow skills
├── docs/
│   └── adr/             # Architectural Decision Records (ADR-0001 through ADR-0012)
├── sync.ps1             # Pulls live configs from ~/.gemini/ into this repo
└── restore.ps1          # Deploys this repo into ~/.gemini/ with automatic backup
```

### Operational Guardrails (`GEMINI.md`)
The global rules file stays compact by defining only active behavioral boundaries:
- Investigate first: trace callers with `rtk rg` before editing code.
- Explicit approval: obtain human confirmation before running mutating commands or modifying files.
- Checkpoints & safety: verify git status or take backups before editing.
- Lean chat: report concise summaries (1 to 2 lines with diffs or action items).
- Security boundaries: deny paths (`.env`, `~/.ssh`, token MCP), AST command interception (`Test-PowerShellCommandSafety.ps1` backed by continuous CI regression tests), and quarantine for external inputs.

### Specialized Agent Roles (`config/agents/`)
Eleven specialized agent configurations handle task delegation. Analytical roles run on `model: inherit` (ADR-0004) to retain the full reasoning capacity of the primary model:
- `system-architect`: Contract-first API design, dependency topology, and ADR drafting.
- `code-auditor`: Read-only security attack surface reviews and repository hygiene audits.
- `database-reviewer`: PostgreSQL schemas, indexing strategies, and zero-downtime expand/contract migrations.
- `silent-failure-hunter`: Catches swallowed exceptions, empty catch blocks, and resource leaks.
- `tdd-guide`: Red-Green-Refactor test cycles, mock-cheating detection, and de-sloppify test hygiene.
- `build-error-resolver`: Scoped TypeScript compiler and build fixes with shortest working diffs.
- `ui-crafter`: Modern web primitives, WCAG 2.2 AA accessibility, and Generative UI widgets.
- `docs-architect`: Technical documentation maintenance and AI context synchronization.
- `public-docs-craftsman`: Public repository documentation, companion sub-docs (TOOLKIT.md, technical.md), and GitHub Community Standards health files.
- `maintenance-bot`: Dependabot PR triage, CI failure diagnosis, and CVE remediation.
- `spec-verifier`: Cross-checks proposed fixes and API signatures against Context7 MCP and official vendor docs (anti-hallucination, read-only).

### Workflow Skills and Provenance (`config/skills/`)

Twenty modular skills load on-demand through Antigravity's progressive disclosure engine. They are partitioned transparently by origin and licensing:

| Category | Count | Included Skills | Origin / Licensing |
|---|:---:|---|---|
| **Bespoke Architectures** | 5 | `council-review`, `academic-council`, `audit-dev-workflow`, `sync-task-state`, `clean-docs` | Original works authored for Antigravity (MIT) |
| **Engine-Adapted Ports** | 7 | `spec-kit`, `gh-workflow`, `audit-context-building`, `differential-review`, `contract-first`, `database-migrations`, `coding-standards` | Adapted from community tools, ECC, and Trail of Bits (MIT & CC BY-SA 4.0) |
| **Curated Community Suites** | 8 | `ponytail` suite (6), `design-taste-frontend`, `documentation-and-adrs` | Bundled from DietrichGebert, Leonxlnx, and standards (MIT) |

*(Note: Third-party suites like `antislop` are decoupled from git tracking per ADR-0006 and installed via `npx antislop-ai` or Antigravity Marketplace).*

#### Core Workflows
- `council-review`: Multi-agent deliberative review panel synthesizing context grounding, socratic scoping, and teamwork peer reviews (high token consumption; spawns 15 to 20+ subagents via `teamwork_preview`).
- `academic-council`: Deliberative research evaluation panel for empirical finance, accounting, and BEI thesis proposals (featuring citation forensics and defense simulation).
- `audit-dev-workflow`: Defensive development runbook with caller tracing, checkpoints, testless fallbacks, and automated rollback scripts.
- `spec-kit`: Spec-Driven Development framework (`/speckit.specify`, `/speckit.plan`, `/speckit.tasks`).
- `gh-workflow`: Non-interactive CI monitoring and PR lifecycle automation via authenticated `gh`.
- `ponytail` (suite of 6): Minimal diff enforcement, repo quality audits, technical debt ledgers, and PR reviews (DietrichGebert, MIT).
- `contract-first`: Schema-first API design collaboration without drift.
- `database-migrations`: Safe, reversible, zero-downtime database schema changes.
- `coding-standards`: Baseline naming, immutability, and error handling conventions.
- `audit-context-building`: Invariant mapping and assumption tracing before code audits (Trail of Bits, CC BY-SA 4.0).
- `differential-review`: Security differential analysis for commits and pull requests (Trail of Bits, CC BY-SA 4.0).
- `design-taste-frontend`: Anti-slop frontend art direction distilled from curated design galleries (Leonxlnx, MIT).
- `documentation-and-adrs`: Standardized Nygard ADR authoring.
- `sync-task-state`: Lightweight context synchronization (`task_state.md`) for Twin-Repo workflows with Antigravity Tactical Gotcha Protocol (ATGP).

### Architectural Decision Records (`docs/adr/`)
Technical decisions, constraints, and trade-offs are recorded as permanent Nygard ADRs:
- [ADR-0001](./docs/adr/0001-context7-streamable-http-token-headers.md): Context7 Streamable HTTP Header Authentication.
- [ADR-0002](./docs/adr/0002-domain-partitioned-skills-vs-greedy-references.md): Domain-Partitioned Skills vs Greedy References.
- [ADR-0003](./docs/adr/0003-ponytail-5-suite-architecture.md): Preservation of Ponytail 5 Discrete Modal Architecture.
- [ADR-0004](./docs/adr/0004-subagent-model-tiering-inherit.md): Subagent Cognitive Model Tiering (`model: inherit`).
- [ADR-0005](./docs/adr/0005-spec-kit-and-ast-grep-tooling.md): Spec-Kit, GitHub Workflow and AST-Grep Integration.
- [ADR-0006](./docs/adr/0006-marketplace-plugin-decoupling-and-security-adaptation.md): Marketplace Plugin Decoupling and Security Skill Adaptation.
- [ADR-0007](./docs/adr/0007-audit-dev-workflow-harmonization-and-anti-cheating.md): Audit-Dev-Workflow Harmonization and Anti-Cheating Architecture.
- [ADR-0008](./docs/adr/0008-tri-pillar-council-review-architecture.md): Tri-Pillar Deliberative Multi-Agent Council Architecture.
- [ADR-0009](./docs/adr/0009-ecc-harness-adaptation-and-security.md): ECC Selective Adaptation, Pre-Execution AST Security, and Bounded Gotchas.
- [ADR-0010](./docs/adr/0010-domain-specific-academic-council.md): Academic Council for Capital Market & Secondary Data Thesis Evaluation.
- [ADR-0011](./docs/adr/0011-ast-security-hardening-and-deployment-parity.md): Pre-Execution AST Security Hardening, Deployment Parity, and Anti-Slop Upstream Filtration.
- [ADR-0012](./docs/adr/0012-flash-high-optimization-ast-hardening-and-model-tiering-invariants.md): Flash High Optimization, AST Hardening, and Cognitive Tiering Invariants.

## Contributing

1. Keep modifications minimal: shortest working diff wins (see `ponytail`).
2. Avoid generic commentary: remove empty AI narrative comments from code.
3. Propose structural changes through ADRs before modifying directory layouts or core guardrails.
4. Verify all tests and CI checks pass locally using `.\sync.ps1` before opening a pull request.

## License

Dual-licensed under MIT and CC BY-SA 4.0:
- Repository scripts, custom subagents, and bespoke skills (`council-review`, `audit-dev-workflow`, `sync-task-state`) are licensed under the [MIT License](./LICENSE).
- Adapted Trail of Bits security skills (`audit-context-building`, `differential-review`) are licensed under [Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](./config/skills/audit-context-building/LICENSE).
- Bundled third-party community skills (`ponytail`, `design-taste-frontend`, `antislop`) retain their respective upstream MIT licenses (see subfolder `LICENSE` files).
