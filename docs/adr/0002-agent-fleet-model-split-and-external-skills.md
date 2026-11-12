# ADR-0002: Agent Fleet Model Split, Skills Catalog, and MCP Tooling

## Status
Accepted

## Date
2026-11-12

## Context
As my `everyday-agy` dotfiles grew, I needed to keep the catalog lean. Importing massive external catalogs (like 300+ skill bundles) or vendoring community suites (`taste-skill`, 6 `ponytail*` skills, and official Marketplace plugins) dumped roughly 44,000 lines of third-party JavaScript and JSON into Git, distorted GitHub language stats, and drifted from upstream releases.

Testing in `Gemini 3.8 Flash (High)` sessions also ran into four Antigravity model and schema constraints:
1. **Model selection drift**: `model: flash` degraded multi-file TDD reasoning, accessibility audits, bilingual localization nuances, and doc writing. Because Antigravity's subagent docs leave exact `model: flash` worker budgets vague, subagents dropped `High` thinking unless configured with `model: inherit`.
2. **Role overlap**: Keeping both `public-docs-craftsman` and `docs-architect`, and splitting ADR ownership between `system-architect` and `docs-architect`, blurred responsibilities. Meanwhile, `database-reviewer` ran in under 5% of local tasks while still requiring dedicated CI assertions and manifest upkeep.
3. **Antigravity manifest traps**: `call_mcp_tool` is not a valid entry under agent `tools:` (reverted in commit `2b390e2` to `inheritMcp: true`), `read_url_content` does not exist in Antigravity's subagent runtime, `ask_question` hangs background subagent runs, omitting `mainAgent: false` clutters the main chat persona selector, and passing literal `~` paths to `view_file` fails on Windows.
4. **Context7 Streamable HTTP authentication**: Antigravity connects to Context7 via Streamable HTTP (`https://mcp.context7.com/mcp`). Testing showed that Streamable HTTP does not interpolate shell environment variables (such as `${CONTEXT7_API_KEY}` or `$env:CONTEXT7_API_KEY`) inside `headers`; env interpolation only works under `stdio`. Variable placeholders send literal strings and crash the client with `401 Unauthorized`.

## Decision

### 1. 10-Agent Fleet and 8 `inherit` / 2 `flash` Model Split
I trimmed the fleet to 10 custom subagents in `config/agents/*/agent.md` (enforced by `.github/workflows/ci.yml`). I merged `public-docs-craftsman` into `docs-architect`, folded `database-reviewer` into `code-auditor` (via task-conditional `database-migrations`), kept `silent-failure-hunter` separate so error-swallowing checks stay isolated, and kept `l10n-humanizer` tracked:
- **8 `model: inherit` specialists**: `system-architect`, `code-auditor`, `silent-failure-hunter`, `spec-verifier`, `tdd-guide`, `docs-architect`, `l10n-humanizer`, and `ui-crafter` inherit the parent session's `High` thinking tier (with explicit `Model: "pro"` overrides when invoked from a `flash` parent).
- **2 `model: flash` tactical specialists**: `build-error-resolver` (single-file compiler and type fixes) and `maintenance-bot` (Dependabot PR triage and CI diagnosis) stay on Flash for fast, low-cost turnaround.

### 2. Subagent Schema, MCP Inheritance, and Tool Boundaries
- **Frontmatter invariants**: Every custom agent declares `model: inherit|flash`, `subagent: true`, `mainAgent: false` (eliminating persona-picker clutter and dead `Primary Interactive Mode` prompt text), `tools:`, and zero `ask_question` or `call_mcp_tool` entries (verified by `.github/tests/YamlValidation.Tests.ps1`).
- **MCP inheritance (`inheritMcp: true`)**: Per commit `2b390e2`, MCP-capable agents (`system-architect`, `code-auditor`, `spec-verifier`, `build-error-resolver`, `ui-crafter`) declare `inheritMcp: true` in YAML frontmatter instead of listing `call_mcp_tool` in `tools:`.
- **Web research tools**: `spec-verifier` uses `search_web` plus CLI raw fetch (`curl.exe` / `Invoke-RestMethod` via `run_command` per `deep-web-research`) without `read_url_content`.
- **Explicit write and path boundaries**:
  - Read-only auditors (`code-auditor`, `silent-failure-hunter`, `spec-verifier`) write only to `<appDataDir>\brain\<conversation-id>\...` scratch dossiers; `system-architect` writes to scratch/proposals in explorer mode and `specs/<feature>/*.md` only when authorized (`docs/adr/` belongs strictly to `docs-architect`).
  - `build-error-resolver` intentionally lacks `write_to_file` (`replace_file_content` only, no scratch files) so it fixes broken types in place instead of creating empty `.d.ts` stubs.
  - `tdd-guide` edits test files and target units; `ui-crafter` spans three scoped workflows — `Codebase Component` site builds with `taste-skill` (`index.html`, `*.html`, `assets/**`, `.taste-skill/**`, `share.jpg`, `favicon.svg`, `names.json`, `credits.json`, `shots/**`, `dist/**`, `out/**`, `src/**`, `components/**`, `pages/**`, `styles/**`, `public/**`), individual existing-app component edits (`coding-standards`, `clean-docs`), and `Generative UI Widget` standalone `<agent-embed>` artifacts using built-in `generative_ui`; `maintenance-bot` edits CI/dependency manifests and `docs/maintenance-howto.md`; `docs-architect` owns `docs/**`, `*.md`, and `task_state.md`; `l10n-humanizer` edits localization resources (Scope A) and prose polish (Scope B).
- **Mandatory Skill Activation Gate**: Every `agent.md` instructs the subagent to read only active-mode `SKILL.md` files via `view_file` using exact OS absolute paths from `<skills>` (never unexpanded `~`).

### 3. 15-Skill Tracked Catalog, Domain Partitioning, and Frontmatter Budget
I maintain exactly 15 skills under `config/skills/` (enforced by `.github/workflows/ci.yml`), partitioned into independent skills rather than greedy `references/` trees that models load wholesale regardless of task:
- **7 bespoke workflows**: `orchestrator`, `council-review`, `academic-council`, `audit-dev`, `sync-task-state`, `clean-docs`, and `deep-web-research`.
- **8 engine-adapted ports**: `spec-kit` (wired to `system-architect`), `gh-workflow` (wired to `maintenance-bot` and `docs-architect`), `audit-context-building` and `differential-review` (ported from Trail of Bits from Claude `.js`/workflow calls to Antigravity subagent and scratch primitives, with `differential-review` structured under `references/`), `contract-first`, `database-migrations`, `coding-standards` (kept inline at 103 lines with Active LTS floors for Node 20+, Python 3.12+, Go 1.22+, and Java 21/25 rather than split across files), and `documentation-and-adrs`.
- **Frontmatter constraints**: Every `SKILL.md` keeps `description:` on a single line `<= 128` characters and wraps values containing `: ` in quotes (enforced by CI and `YamlValidation.Tests.ps1`).

### 4. Decoupled Upstream Suites, Context7 HTTP Auth, and Verified CLI Tools
- **External skills and plugins**: I decoupled `taste-skill` (`afif25fradana/taste-skill`, fork of `Leonxlnx/taste-skill`, installed as an Antigravity plugin), all 6 `ponytail*` skills (`DietrichGebert/ponytail`), and official Marketplace plugins (`chrome-devtools-plugin`, `android-cli-plugin`) from Git tracking, while retiring the `antislop` plugin suite (`miqdadbadjuber/anti-slop`, superseded by repository `clean-docs` Sections 3/6, `coding-standards`, and `taste-skill`). `modern-web-guidance` remains an optional Marketplace plugin and is not installed locally or declared in `ui-crafter`. `README.md`, `TOOLKIT.md`, and `restore.ps1` point to upstream repositories instead of vendoring clones.
- **Context7 Streamable HTTP header auth**: Store the Bearer token literally in machine-local `~/.gemini/config/mcp_config.json`, exclude `mcp_config.json` and `mcp_config*.json` in `.gitignore`, document copy-paste snippets with `<YOUR_CONTEXT7_API_KEY>` in `README.md` and `TOOLKIT.md`, and enforce credential scans in `sync.ps1`, `restore.ps1`, and CI (see [ADR-0003](./0003-runtime-hooks-command-safety-and-checkpoints.md) and [ADR-0005](./0005-clean-docs-and-repo-sync-boundaries.md)).
- **Verified CLI tooling (`config/GEMINI.md`, `TOOLKIT.md`)**: Register `rtk` for output compression (falling back to raw commands or `rtk proxy`), `ripgrep` (`rg` over heavyweight graph wrappers), `ast-grep` (`sg`) for syntax-tree search/rewrite, `gh` (never prefixed with `rtk`), `pwsh` 7.6 / PowerShell 5.1, `node`, `python`, `java` (JBR 25), `fzf`, `ffmpeg`, `adb`, `code`, and `opencode`.

## Alternatives Considered & Rejected
- **All-`flash` or 5 `inherit` / 5 `flash` split**: Rejected because `flash` degraded UI accessibility, bilingual translation, and doc accuracy on multi-file craft tasks.
- **Keeping `database-reviewer` standalone or sharing ADR writes with `system-architect`**: Rejected due to `<5%` utilization overhead and conflicting ADR ownership.
- **Using `call_mcp_tool` in `tools:` or keeping `ask_question`/`read_url_content` in manifests**: Rejected because Antigravity rejects `call_mcp_tool`, hangs on interactive `ask_question`, and lacks `read_url_content`.
- **Vendoring community suites or using Git submodules**: Rejected because ~38k-44k lines of JS/JSON skewed repo metrics and submodule pointers add friction to dotfiles.
- **Using `${CONTEXT7_API_KEY}` or `mcp-remote` stdio bridges for Context7**: Rejected because Streamable HTTP sends uninterpolated variable text (`401 Unauthorized`) and stdio bridges add unnecessary latency.
- **Splitting `coding-standards` into `references/` or importing large external catalogs**: Rejected because foundational rules are shared across 4 agents and benefit from a compact inline floor without extra read roundtrips.

## Consequences
- **Positive**: Keeps the repo lean (10 agents, 15 skills, PowerShell/Markdown language footprint), catches schema and MCP errors in CI, keeps Context7 reliable, and matches each model tier to task complexity.
- **Negative / Operational Requirements**:
  - Setting up a new machine requires creating `~/.gemini/config/mcp_config.json` locally and installing decoupled upstream skills/plugins (`ponytail`, `taste-skill`) and Marketplace plugins separately.
  - Adding or renaming any agent or skill requires updating the exact count assertions in `.github/workflows/ci.yml`.
