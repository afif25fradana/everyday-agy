# Everyday-AGY Toolkit: Tools, MCP & Skills Catalog

A comprehensive standalone catalog of all CLI tools, Model Context Protocol (MCP) servers, custom skills, and recommended official plugins configured in this environment. Contains verified official repository links, one-liner installation commands, and ready-to-use configuration snippets.

---

## 1. Verified CLI Tools

Core development tools registered in `GEMINI.md` and verified across workflows.

| Tool | Category | Official Repository / Docs | Quick Install Command (Windows) |
|---|---|---|---|
| **rtk** | LLM Token Proxy & Filter | [rtk-ai/rtk](https://github.com/rtk-ai/rtk) • [rtk-ai.app](https://rtk-ai.app) | `winget install rtk-ai.rtk` |
| **ast-grep** (`sg`) | AST Code Search & Rewrite | [ast-grep/ast-grep](https://github.com/ast-grep/ast-grep) | `npm install -g @ast-grep/cli` *(or `winget install ast-grep`)* |
| **gh** | GitHub CLI | [cli/cli](https://github.com/cli/cli) | `winget install GitHub.cli` |
| **ripgrep** (`rg`) | Ultra-Fast Regex Search | [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) | `winget install BurntSushi.ripgrep.MSVC` |
| **fzf** | Fuzzy Finder | [junegunn/fzf](https://github.com/junegunn/fzf) | `winget install junegunn.fzf` |
| **pwsh** | PowerShell 7+ | [PowerShell/PowerShell](https://github.com/PowerShell/PowerShell) | `winget install Microsoft.PowerShell` |
| **ffmpeg** | Media Processing | [FFmpeg](https://ffmpeg.org/) • [GyanD/codexffmpeg](https://github.com/GyanD/codexffmpeg) | `winget install Gyan.FFmpeg` |
| **adb** | Android Debug Bridge | [Android Platform Tools](https://developer.android.com/tools/releases/platform-tools) | `winget install Google.PlatformTools` |
| **betterleaks** | Secret Scanner (Gitleaks Successor) | [betterleaks/betterleaks](https://github.com/betterleaks/betterleaks) | `go install github.com/betterleaks/betterleaks@latest` |
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

19 modular skills shipped directly within this repository (`config/skills/`), plus 10 recommended external/marketplace skills documented in Section 4.

### A. Spec-Driven & Development Workflows
| Skill Name | Trigger / Command | Description | Upstream / Origin |
|---|---|---|---|
| **council-review** | `/council`<br>`/council-review` | Deliberative multi-agent council review panel: fact grounding, socratic alignment, and adversarial peer review. | **Original Work (@afif25fradana)** /<br>Inspired by Anthropic & Karpathy |
| **academic-council** | `/academic-council`<br>`/thesis-council` | Multi-agent council for empirical capital market, accounting, and BEI thesis proposal defense. | **Original Work (@afif25fradana)** |
| **spec-kit** | `/speckit.specify`<br>`/speckit.plan`<br>`/speckit.tasks` | Spec-Driven Development (SDD) framework to specify, architect, and generate task lists before coding. | [github/spec-kit](https://github.com/github/spec-kit) |
| **gh-workflow** | `/gh-workflow` | GitHub CLI automation for PR creation, non-interactive CI monitoring, and PR review comments. | Antigravity Native / [cli/cli](https://github.com/cli/cli) |
| **audit-dev-workflow** | `/audit-dev-workflow`<br>`/audit-first` | Defensive audit-first workflow: caller tracing, checkpoints, explicit approvals, and verification. | **Original Work (@afif25fradana)** /<br>Heuristics adapted from [obra/superpowers](https://github.com/obra/superpowers) |
| **sync-task-state** | `/sync-task-state` | Lightweight active AI context management (`task_state.md`) in Twin-Repo workflows. | **Original Work (@afif25fradana)** |

### B. Ponytail 5 Suite (YAGNI & Anti-Overengineering)
| Skill Name | Trigger / Command | Description | Upstream / Origin |
|---|---|---|---|
| **ponytail** | `/ponytail [lite\|full\|ultra]` | Lazy senior dev mode: shortest working diff, eliminates speculative abstractions and bloat. | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) |
| **ponytail-audit** | `/ponytail-audit` | Quality audit of an entire repo: bugs, security risks, load bottlenecks, and dead code cleanup. | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) |
| **ponytail-review** | `/ponytail-review` | Deep quality review for git diffs and PRs (correctness, safety, real load, and testing). | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) |
| **ponytail-debt** | `/ponytail-debt` | Scans `shortcut:` and `ponytail:` comments as an actionable technical debt ledger. | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) |
| **ponytail-gain** | `/ponytail-gain` | Displays measured token and performance benchmark savings (39-task suite). | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) |
| **ponytail-help** | `/ponytail-help` | Quick reference cheatsheet for Ponytail levels, rules, and commands. | [DietrichGebert/ponytail](https://github.com/DietrichGebert/ponytail) |

### C. Security, Standards & Architecture
| Skill Name | Trigger / Command | Description | Upstream / Origin |
|---|---|---|---|
| **audit-context-building** | `/audit-context-building` | Builds codebase comprehension before security audits: maps invariants, assumptions (`nothing found`), and contracts. | **Trail of Bits**<br>[trailofbits/skills](https://github.com/trailofbits/skills)<br>*(Adapted for Google Antigravity)* |
| **differential-review** | *Auto-triggers on security review of diffs/PRs* | Security-focused differential review evaluating blast radius, test gaps, regressions, and attacker models. | **Trail of Bits**<br>[trailofbits/skills](https://github.com/trailofbits/skills)<br>*(Adapted for Google Antigravity)* |
| **contract-first** | `/contract-first` | Schema-first API collaboration (OpenAPI, Protobuf, JSON Schema) preventing consumer/provider field drift. | Domain Best Practices / ECC Port |
| **database-migrations** | `/database-migrations` | Zero-downtime expand-contract schema changes, reversible migrations, and concurrent indexes. | Database Reliability Engineering |
| **coding-standards** | `/coding-standards` | Baseline naming, immutability, type safety, and defensive error-handling conventions. | Universal Engineering Standards |
| **clean-docs** | `/clean-docs` | Enforces plain-spoken repo prose, humanized conventional commits, and zero AI process leaks. | **Original Work (@afif25fradana)** |
| **documentation-and-adrs** | `/documentation-and-adrs` | Documents architectural decisions, trade-offs, and context using Michael Nygard's ADR format. | Michael Nygard Standard /<br>[joelparkerhenderson/architecture-decision-record](https://github.com/joelparkerhenderson/architecture-decision-record) |

### D. Frontend & Visual Craft
| Skill Name | Trigger / Command | Description | Upstream / Origin |
|---|---|---|---|
| **design-taste-frontend** | *Auto-triggers on frontend UI design* | Tasteskill v2: art direction distilled from 247 curated Awwwards & OnePageLove websites. | [Leonxlnx/taste-skill](https://github.com/Leonxlnx/taste-skill) |

---

## 4. Recommended External & Marketplace Plugins

These plugins are maintained officially or via upstream package managers. Install them directly rather than tracking vendor clones in Git (per ADR-0006 & ADR-0011):

| Plugin Name | Included Skills | Description | Official Upstream & Install |
|---|---|---|---|
| **Anti-Slop Suite** (`antislop`) | `antislop`<br>`antislop-ui`<br>`antislop-copywriting`<br>`antislop-code`<br>`antislop-human`<br>`antislop-layoutmobile` | Master filter for AI coding agents: stops generic AI purple gradients, filler copy, and sloppy comments. | [miqdadbadjuber/anti-slop](https://github.com/miqdadbadjuber/anti-slop)<br>`npx antislop-ai` |
| **Chrome DevTools** (`chrome-devtools-plugin`) | `chrome-devtools`<br>`a11y-debugging`<br>`cookie-debugging`<br>`debug-optimize-lcp`<br>`memory-leak-debugging`<br>`troubleshooting` | Browser automation, accessibility auditing, cookie debugging, Core Web Vitals (LCP) optimization, and heap snapshots. | [ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp)<br>*(Antigravity Marketplace)* |
| **Modern Web Guidance** (`modern-web-guidance-plugin`) | `modern-web-guidance`<br>`chrome-extensions` | Best practices for modern web platform APIs (popovers, container queries, view transitions) and Chrome Extensions Manifest V3. | [GoogleChrome/modern-web-guidance](https://github.com/GoogleChrome/modern-web-guidance)<br>*(Antigravity Marketplace)* |
| **Android CLI** (`android-cli-plugin`) | `android-cli` | Project scaffolding, emulator control, layout tree inspection, and visual validation for Android development. | [developer.android.com/tools/agents/android-cli](https://developer.android.com/tools/agents/android-cli)<br>*(Antigravity Marketplace)* |

---

## 5. Custom Subagents

Eleven specialized agents available for delegation in Antigravity:

| Agent Name | Model Tier | Tools Boundary | Core Responsibility |
|---|:---:|---|---|
| **system-architect** | `model: inherit` | Read, Write, Run, Ask | Contract-first API design, Socratic planning, and Nygard ADR documentation. |
| **code-auditor** | `model: inherit` | Read, Artifact Write, Run *(Read-Only)* | Repository health audits, security vulnerability analysis, and test integrity. |
| **database-reviewer** | `model: inherit` | Read, Artifact Write, Run *(Read-Only)* | SQL schema design, zero-downtime migrations, and N+1 query optimization. |
| **silent-failure-hunter** | `model: inherit` | Read, Artifact Write, Run *(Read-Only)* | Hunts silent failures, swallowed exceptions, and empty error handling blocks. |
| **spec-verifier** | `model: inherit` | Read, Artifact Write, Search, Run *(Read-Only)* | Cross-checks proposed fixes and API contracts against Context7 MCP and official vendor docs. |
| **public-docs-craftsman** | `model: inherit` | Read, Write, Replace, Run, Ask | Public repository documentation, companion sub-docs, and GitHub Community Standards. |
| **build-error-resolver** | `model: flash` | Read, Replace, Run *(No write)* | Resolves compiler, typecheck, and build errors with shortest working diffs. |
| **tdd-guide** | `model: flash` | Read, Write, Replace, Run | Guides Test-Driven Development workflows (Red-Green-Refactor cycles; Iron Law adapted from [obra/superpowers](https://github.com/obra/superpowers)). |
| **docs-architect** | `model: flash` | Read, Write, Replace, Run, Ask | Modernizes technical documentation and synchronizes AI-Context repositories. |
| **maintenance-bot** | `model: flash` | Read, Write, Replace, Run, Ask | Dependabot PR triage, CI failure diagnosis, and CVE remediation. |
| **ui-crafter** | `model: flash` | Read, Write, Replace, Run, Ask | Modern web UI widget creation, WCAG AA accessibility, and Generative UI design. |
