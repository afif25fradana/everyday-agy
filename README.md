# everyday-agy

Everyday configuration, custom subagents, workflow skills, and safety guardrails for Google Antigravity. It equips local pair-programming sessions with automated caller tracing, multi-agent council reviews, spec-driven development, and git checkpoints.

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
   *The script detects existing files in `~/.gemini/` and creates a timestamped backup before copying.*
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
   *The script runs a credential scanner before copying to prevent accidental token leaks.*

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
├── GEMINI.md            # Active operational rules and execution guardrails (28 lines)
├── TOOLKIT.md           # Catalog of CLI tools, MCP snippets, and skill upstream links
├── config/
│   ├── agents/          # 9 specialized subagents configured with model: inherit
│   ├── skills/          # 21 custom workflow skills (council-review, spec-kit, ponytail, etc.)
│   └── plugins/         # Bespoke plugins (antislop design and code filters)
├── docs/
│   └── adr/             # Architectural Decision Records (ADR-0001 through ADR-0008)
├── sync.ps1             # Pulls live configs from ~/.gemini/ into this repo
└── restore.ps1          # Deploys this repo into ~/.gemini/ with automatic backup
```

### Operational Guardrails (`GEMINI.md`)
The global rules file stays compact (28 lines) by defining only active behavioral boundaries:
- Investigate first: trace callers with `rtk rg` before editing code.
- Explicit approval: obtain human confirmation before running mutating commands or modifying files.
- Checkpoints: verify git status or take backups before editing.
- Lean chat: report concise summaries (1 to 2 lines with diffs or action items).

### Custom Subagents (`config/agents/`)
Nine specialized agents handle task delegation. Analytical roles run on `model: inherit` (ADR-0004) to retain the full reasoning capacity of the primary model:
- `system-architect`: Contract-first API design, dependency topology, and ADR drafting.
- `code-auditor`: Read-only security attack surface reviews and repository hygiene audits.
- `database-reviewer`: PostgreSQL schemas, indexing strategies, and zero-downtime expand/contract migrations.
- `silent-failure-hunter`: Catches swallowed exceptions, empty catch blocks, and resource leaks.
- `tdd-guide`: Red-Green-Refactor test cycles and mock-cheating detection.
- `build-error-resolver`: Scoped TypeScript compiler and build fixes with shortest working diffs.
- `ui-crafter`: Modern web primitives, WCAG 2.2 AA accessibility, and Generative UI widgets.
- `docs-architect`: Technical documentation maintenance and AI context synchronization.
- `maintenance-bot`: Dependabot PR triage, CI failure diagnosis, and CVE remediation.

### Custom Skills (`config/skills/`)
Twenty-one modular skills load on-demand through Antigravity's progressive disclosure engine:
- `council-review`: Multi-agent deliberative review panel synthesizing context grounding, socratic scoping, and teamwork peer reviews.
- `audit-dev-workflow`: Defensive development runbook with caller tracing, checkpoints, testless fallbacks, and automated rollback scripts.
- `spec-kit`: Spec-Driven Development framework (`/speckit.specify`, `/speckit.plan`, `/speckit.tasks`).
- `gh-workflow`: Non-interactive CI monitoring and PR lifecycle automation via authenticated `gh`.
- `ponytail` (suite of 6): Minimal diff enforcement, repo quality audits, technical debt ledgers, and PR reviews.
- `audit-context-building`: Invariant mapping and assumption tracing before code audits.
- `differential-review`: Security differential analysis for commits and pull requests.
- `design-taste-frontend`: Anti-slop frontend art direction distilled from curated design galleries.
- `documentation-and-adrs`: Standardized Nygard ADR authoring.
- `sync-task-state`: Lightweight context synchronization (`task_state.md`) for Twin-Repo workflows.

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

## Contributing

1. Keep modifications minimal: shortest working diff wins (see `ponytail`).
2. Avoid generic commentary: remove empty AI narrative comments from code.
3. Propose structural changes through ADRs before modifying directory layouts or core guardrails.
4. Verify all tests and CI checks pass locally using `.\sync.ps1` before opening a pull request.

## License

MIT License. See [LICENSE](./LICENSE) for details.
