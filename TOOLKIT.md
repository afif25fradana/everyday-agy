# Everyday-AGY Toolkit: Tools, MCP & Skills Catalog

Reference catalog for CLI tools, MCP servers, workflow skills, and custom agents configured in this environment.

---

## 1. Verified CLI Tools

Core development tools registered in `GEMINI.md` and verified across workflows.

| Tool | Category | Official Repository / Docs | Quick Install Command (Windows) |
|---|---|---|---|
| **rtk** | LLM Token Proxy & Filter | [rtk-ai/rtk](https://github.com/rtk-ai/rtk) • [rtk-ai.app](https://rtk-ai.app) | `winget install rtk-ai.rtk` |
| **ast-grep** (`sg`) | AST Code Search & Rewrite | [ast-grep/ast-grep](https://github.com/ast-grep/ast-grep) | `npm install -g @ast-grep/cli` *(or `winget install ast-grep`)* |
| **gh** | GitHub CLI | [cli/cli](https://github.com/cli/cli) | `winget install GitHub.cli` |
| **ripgrep** (`rg`) | Regex Text Search | [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) | `winget install BurntSushi.ripgrep.MSVC` |
| **fzf** | Fuzzy Finder | [junegunn/fzf](https://github.com/junegunn/fzf) | `winget install junegunn.fzf` |
| **pwsh** | PowerShell 7+ | [PowerShell/PowerShell](https://github.com/PowerShell/PowerShell) | `winget install Microsoft.PowerShell` |
| **ffmpeg** | Media Processing | [FFmpeg](https://ffmpeg.org/) • [GyanD/codexffmpeg](https://github.com/GyanD/codexffmpeg) | `winget install Gyan.FFmpeg` |
| **adb** | Android Debug Bridge | [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools) | `winget install Google.PlatformTools` |
| **git** | Version Control | [git-for-windows](https://gitforwindows.org/) | `winget install Git.Git` |
| **java** (JBR 25) | Java Runtime | [JetBrains/JetBrainsRuntime](https://github.com/JetBrains/JetBrainsRuntime) | Bundled with IDE *(or `winget install Microsoft.OpenJDK.21`)* |
| **code** | VS Code Editor | [microsoft/vscode](https://code.visualstudio.com/) | `winget install Microsoft.VisualStudioCode` |
| **opencode** | OpenCode Assistant | [sst/opencode](https://github.com/sst/opencode) | `npm install -g opencode-ai` |
| **Node.js** | JS/TS Runtime | [nodejs/node](https://github.com/nodejs/node) | `winget install OpenJS.NodeJS.LTS` |
| **Python** | Python Runtime | [python/cpython](https://github.com/python/cpython) | `winget install Python.Python.3.12` |

### One-Liner Install Script (PowerShell Administrator):
Copy and run in an elevated PowerShell session on a new machine:
```powershell
winget install --id rtk-ai.rtk -e --silent
winget install --id GitHub.cli -e --silent
winget install --id BurntSushi.ripgrep.MSVC -e --silent
winget install --id junegunn.fzf -e --silent
winget install --id Microsoft.PowerShell -e --silent
winget install --id Gyan.FFmpeg -e --silent
winget install --id Google.PlatformTools -e --silent
winget install --id OpenJS.NodeJS.LTS -e --silent
winget install --id Python.Python.3.12 -e --silent
# Refresh process PATH to pick up newly installed Node and Python binaries:
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
npm install -g @ast-grep/cli
```

---

## 2. Model Context Protocol (MCP) Servers

| Server Name | Transport | Purpose | Upstream / Endpoint |
|---|:---:|---|---|
| **context7** | `Streamable HTTP` | Real-time external library documentation and official API contract queries. | [https://context7.com](https://context7.com)<br>`https://mcp.context7.com/mcp` |

### Copy-Paste Snippet for `~/.gemini/config/mcp_config.json`:
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

---

## 3. Custom Skills Catalog

15 custom and adapted skills tracked in this repository (`config/skills/`); external third-party suites are listed in Section 4.

### A. Spec-Driven & Development Workflows
| Skill Name | Trigger / Command | Description | Upstream / Origin |
|---|---|---|---|
| **orchestrator** | `/orchestrator` | Lead orchestrator protocol: sizes task blast radius, insulates parent context, and coordinates subagent handoffs. | **Original Work (@afif25fradana)** /<br>Inspired by Anthropic Lead Agent & [obra/superpowers](https://github.com/obra/superpowers) |
| **council-review** | `/council`<br>`/council-review` | Deliberative multi-agent council review panel: fact grounding, Socratic alignment, and adversarial peer review. | **Original Work (@afif25fradana)** /<br>Inspired by Anthropic & Karpathy |
| **academic-council** | `/academic-council`<br>`/thesis-council` | Multi-agent council for empirical capital market, accounting, and BEI thesis proposal defense. | **Original Work (@afif25fradana)** |
| **spec-kit** | `/speckit.specify`<br>`/speckit.plan`<br>`/speckit.tasks` | Spec-Driven Development (SDD) framework to specify, architect, and generate task lists before coding. | [github/spec-kit](https://github.com/github/spec-kit) |
| **gh-workflow** | `/gh-workflow` | GitHub CLI automation for PR creation, non-interactive CI monitoring, and PR review comments. | Antigravity Native / [cli/cli](https://github.com/cli/cli) |
| **sync-task-state** | `/sync-task-state` | Lightweight active AI context management (`task_state.md`) in Twin-Repo workflows. | **Original Work (@afif25fradana)** |

### B. Security, Standards & Architecture
| Skill Name | Trigger / Command | Description | Upstream / Origin |
|---|---|---|---|
| **audit-dev** | `/audit-dev` | Standalone code quality and skeptical evaluation rubric: Two-Stage Spec-First review, Five-Axis audit rubric, 4-bucket dispute resolution, and 20 engineering pitfalls (ADR-0004). | **Original Work (@afif25fradana)** /<br>Heuristics adapted from [obra/superpowers](https://github.com/obra/superpowers) |
| **audit-context-building** | `/audit-context-building` | Builds codebase comprehension before security audits: maps invariants, assumptions (`nothing found`), and contracts. | **Trail of Bits**<br>[trailofbits/skills](https://github.com/trailofbits/skills)<br>*(Adapted for Google Antigravity)* |
| **differential-review** | `/differential-review` | Security-focused differential review evaluating blast radius, test gaps, regressions, and attacker models. | **Trail of Bits**<br>[trailofbits/skills](https://github.com/trailofbits/skills)<br>*(Adapted for Google Antigravity)* |
| **contract-first** | `/contract-first` | Schema-first API collaboration (OpenAPI, Protobuf, JSON Schema) to prevent consumer/provider field drift. | Domain Best Practices / ECC Port |
| **database-migrations** | `/database-migrations` | Zero-downtime expand-contract schema changes, reversible migrations, and concurrent indexes. | Database Reliability Engineering |
| **coding-standards** | `/coding-standards` | Baseline naming, immutability, type safety, and defensive error-handling conventions. | Universal Engineering Standards |
| **clean-docs** | `/clean-docs` | Enforces plain-spoken repo prose, humanized conventional commits, and zero AI process leaks. | **Original Work (@afif25fradana)** |
| **documentation-and-adrs** | `/documentation-and-adrs` | Documents architectural decisions, trade-offs, and context using Michael Nygard's ADR format. | Michael Nygard Standard /<br>[joelparkerhenderson/architecture-decision-record](https://github.com/joelparkerhenderson/architecture-decision-record) |
| **deep-web-research** | `/deep-web-research` | Verifiable primary-source research protocol enforcing version-locked queries, domain constraints, and anti-hallucination grounding. | **Original Work (@afif25fradana)** |

> **Antigravity Built-in Runtime Skill**: `generative_ui` (invoked by `ui-crafter`) is provisioned directly by the Antigravity engine (`~/.gemini/antigravity/builtin/skills/generative_ui`) and is not tracked as a repository-level custom skill.

---

## 4. Recommended Upstream Skills & Plugins (Decoupled per ADR-0002)

These skills and plugins live in their own upstream repositories with dedicated installers. Follow their official docs to install them instead of tracking vendor clones in Git:

| Project / Suite | Included Skills | Description | Official Documentation & Antigravity Setup |
|---|---|---|---|
| **Taste-Skill** | `design-taste-frontend` | Anti-slop frontend art direction distilled from 247 curated design galleries. | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) |
| **Ponytail Suite** | `ponytail`<br>`ponytail-audit`<br>`ponytail-review`<br>`ponytail-debt`<br>`ponytail-gain`<br>`ponytail-help` | Lazy senior developer mode: shortest working diffs, YAGNI enforcement, repo audits, and debt ledgers. | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) |
| **Anti-Slop Suite** | `antislop`<br>`antislop-ui`<br>`antislop-copywriting`<br>`antislop-code`<br>`antislop-human`<br>`antislop-layoutmobile` | Master filter for AI coding agents: stops generic AI purple gradients, filler copy, and sloppy comments. | [miqdadbadjuber/anti-slop](https://github.com/miqdadbadjuber/anti-slop) |
| **Chrome DevTools** | `chrome-devtools`<br>`a11y-debugging`<br>`cookie-debugging`<br>`debug-optimize-lcp`<br>`memory-leak-debugging`<br>`troubleshooting` | Browser automation, accessibility auditing, cookie debugging, Core Web Vitals (LCP) optimization, and heap snapshots. | [ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp)<br>*(Antigravity Marketplace)* |
| **Modern Web Guidance** | `modern-web-guidance`<br>`chrome-extensions` | Best practices for modern web platform APIs (popovers, container queries, view transitions) and Chrome Extensions Manifest V3. | [GoogleChrome/modern-web-guidance](https://github.com/GoogleChrome/modern-web-guidance)<br>*(Antigravity Marketplace)* |
| **Android CLI** | `android-cli` | Project scaffolding, emulator control, layout tree inspection, and visual validation for Android development. | [developer.android.com/tools/agents/android-cli](https://developer.android.com/tools/agents/android-cli)<br>*(Antigravity Marketplace)* |

---

## 5. Custom Subagents

Specialized agents available for delegation in Antigravity across an 8 `inherit` / 2 `flash` fleet split (ADR-0002):

| Agent Name | Model Tier | Tools Boundary | Core Responsibility |
|---|:---:|---|---|
| **system-architect** | `model: inherit` | Read, Spec/Artifact Write, Run, MCP (inheritMcp: true) | Contract-first API design, Socratic planning, and specification modeling (`spec-kit`). |
| **code-auditor** | `model: inherit` | Read, Artifact Write, Run, MCP (inheritMcp: true) *(Read-Only)* | Whole-repo health, security attack surface, database schema & migration safety, and test integrity. |
| **silent-failure-hunter** | `model: inherit` | Read, Artifact Write, Run *(Read-Only)* | Hunts silent failures, swallowed exceptions, and empty error handling blocks. |
| **spec-verifier** | `model: inherit` | Read, Artifact Write, Search, Run, MCP (inheritMcp: true) *(Read-Only)* | Cross-checks proposed fixes and API contracts against Context7 MCP and official vendor docs. |
| **tdd-guide** | `model: inherit` | Read, Write, Replace, Run | Guides Single-Pass Test-Driven Development (Red-Green-Refactor cycles; Iron Law adapted from [obra/superpowers](https://github.com/obra/superpowers)). |
| **build-error-resolver** | `model: flash` | Read, Replace, Run, MCP (inheritMcp: true) *(No write)* | Resolves compiler, typecheck, and build errors with shortest working diffs. |
| **docs-architect** | `model: inherit` | Read, Write, Replace, Run | Updates technical documentation, owns Nygard ADRs and public repository docs, and syncs AI-Context repositories (ADR-0002, ADR-0005). |
| **maintenance-bot** | `model: flash` | Read, Write, Replace, Run | Dependabot PR triage, CI failure diagnosis, and CVE remediation. |
| **ui-crafter** | `model: inherit` | Read, Write, Replace, Run, MCP (inheritMcp: true) | Modern web UI widget creation, WCAG AA accessibility, and Generative UI design. |
| **l10n-humanizer** | `model: inherit` | Read, Write, Replace, Run | Dual-Scope UI/UX localization (Microsoft Indonesian style guide) and second-pass bilingual prose humanization (anti-AI rules, fact lock). |

---

## 6. Native Antigravity Runtime Hooks

Native event handlers configured in `config/hooks.json` and routed via `config/scripts/Invoke-AntigravityHook.ps1` (ADR-0003):

| Hook Event | Matcher | Enforcement & Safety Gates |
|---|---|---|
| **PreToolUse** | `run_command` | Parses commands via PowerShell AST (`Test-PowerShellCommandSafety.ps1`) and blocks dangerous shell operations (`rm -rf`, `git push --force`, `git clean -fdx`). |
| **PreToolUse** | `view_file`<br>`read_file`<br>`replace_file_content`<br>`multi_replace_file_content`<br>`edit_file`<br>`write_to_file`<br>`write_file`<br>`create_file` | Enforces credential and secret deny-path rules only (`Test-DenyPath`: `.env*` except `.env.example`/`.env.sample`/`.env.template`, `~/.ssh`, `~/.aws`, `~/.gnupg`, `*.key`, `*.pem`, Antigravity `mcp/**`) across both parent agent tools (`read_file`, `edit_file`, `write_file`, `create_file`) and subagent tools (`view_file`, `replace_file_content`, `multi_replace_file_content`, `write_to_file`); does not restrict workspace or role boundaries. |
| **PostToolUse** | `write_to_file`<br>`write_file`<br>`create_file`<br>`replace_file_content`<br>`multi_replace_file_content`<br>`edit_file` | Injects git diffs automatically via `Update-Gate2Diff.ps1` when `gate2_handoff.md` contains `{{VERBATIM_GIT_DIFF}}` or `{{VERBATIM_GIT_DIFFSTAT}}` across both parent agent (`write_file`, `create_file`, `edit_file`) and subagent (`write_to_file`, `replace_file_content`, `multi_replace_file_content`) file writes. |

---

## 7. Consolidated Infrastructure Scripts (`config/scripts/`)

Five core PowerShell infrastructure scripts consolidated under `config/scripts/` to separate runtime safety, diff injection, and checkpoint rollback mechanisms from markdown skills (ADR-0003):

| Script Name | Invocation Context | Core Responsibility |
|---|---|---|
| **`Invoke-AntigravityHook.ps1`** | Antigravity engine runtime (`PreToolUse` & `PostToolUse` via `config/hooks.json`) | Central hook router: dispatches tool events, forwards `run_command` payloads to `Test-PowerShellCommandSafety.ps1`, checks file operations against `Test-DenyPath`, triggers `Update-Gate2Diff.ps1` on `gate2_handoff.md`, strips UTF-8 BOM, maintains rotating log (`hooks.log`), and returns deterministic JSON stdout. |
| **`Test-PowerShellCommandSafety.ps1`** | Pre-tool execution via `Invoke-AntigravityHook.ps1` (or manual test/validation runs) | PowerShell AST command validator: inspects command lines via `[System.Management.Automation.Language.Parser]::ParseInput` without running them. Blocks destructive cmdlets (`Remove-Item -Recurse`, `Format-*`, `Clear-Disk`), forced git operations (`git push --force`, `git clean -fdx`, uncheckpointed `git reset --hard`), secondary subshells, dynamic invocations (`iex`), and access to sensitive paths (`~/.ssh`, `~/.aws`, `~/.gnupg`). |
| **`New-AuditCheckpoint.ps1`** | Orchestrator workflow before file mutations (Tier 0/1/2/3 checkpoints) | Atomic rollback checkpoint creator: in Git repositories, verifies a clean tracked working tree, force-updates branch `checkpoint-<task>`, and snapshots baseline untracked files (`untracked_baseline.txt`). In non-git directory modes, captures `<sha1>_<leaf>.bak` copies and SHA-256 checksums in `hashes.txt`. |
| **`Restore-AuditCheckpoint.ps1`** | Orchestrator rollback recovery after test/build failures or operator rejection | Working tree restoration: in Git repositories, executes two-stage reset (mixed reset before hard reset) to prevent wiping newly staged files, fails closed if baseline is missing, removes only post-checkpoint untracked files, and safely unlinks NTFS directory junctions. In non-git directory modes, verifies SHA-256 integrity and restores original files. |
| **`Update-Gate2Diff.ps1`** | PostToolUse event via `Invoke-AntigravityHook.ps1` on `gate2_handoff.md` generation | Git diff injector: stages untracked files temporarily (`git add -N`) in a fail-safe `try/finally` block, captures unified diffs and stat tables, replaces `{{VERBATIM_GIT_DIFF}}` and `{{VERBATIM_GIT_DIFFSTAT}}` literals, and sanitizes private keys, JWTs, and API tokens while preserving Git commit SHAs and checksums. |
