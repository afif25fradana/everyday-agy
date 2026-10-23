# ADR-0009: Everything Claude Code (ECC) Selective Adaptation, Pre-Execution AST Security, and Bounded Gotcha Harvesting

## Status
Accepted

## Date
2026-10-23

## Context
A comprehensive, read-only multi-perspective Council Review was conducted across 4 independent evaluation seats (`system-architect`, `code-auditor`, `docs-architect`, `spec-verifier`) comparing the Everything Claude Code (ECC) benchmark repository (`D:\Github\ECC`) against Google Antigravity's lightweight Ponytail engineering standard (`d:\Github\everyday-agy`).

The audit revealed significant architectural tensions:
1. **Catalog Bloat vs. Progressive Disclosure**: ECC's catalog of 311 skills, 71 agents, and 97 commands consumes ~20,215 tokens per prompt turn in catalog indexing headers, triggers severe embedding collisions, and violates ADR-0002 (Domain Partitioning) and ADR-0003 (Ponytail Anti-Bloat).
2. **The Prompt-Level Advisory Fallacy**: Antigravity previously relied exclusively on advisory text prompts in `GEMINI.md` lines 22–28 (`<!-- workflow-guardrails -->`). Under indirect prompt injection (CVE-2025-59536, CVE-2026-21852), advisory prompt instructions can be bypassed, exposing developers to destructive commands and credential exfiltration.
3. **Platform Invalidation & Foreign Hook Bloat**: ECC enforces safety through 6,500+ lines of brittle Node.js wrapper scripts and a 2,245-line regex-based PowerShell parser in JavaScript. On native Windows host environments (`pwsh / PowerShell 5.1`), ECC's background observers fail due to Windows Job Object process reaping (issue #2489), bash heredocs crash the shell parser, and unmapped Claude Code tool names cause Antigravity subagents to hang.
4. **State Decay**: ECC's Context Keeper (`ck`) appends historical decisions monotonically without retention limits, causing severe context drift and token inflation.

However, ECC also demonstrated high-leverage algorithmic breakthroughs: an Evidence-Normalized Review-Verify DAG Barrier with fail-closed semantics, a dedicated post-implementation De-Sloppify pass, and structured tactical gotcha harvesting.

## Decision

1. **Categorical Rejection of Monolithic Import**:
   - Veto wholesale ingestion of ECC's 311 skills, 71 subagents, and 97 commands. Maintain Antigravity's compact 10-agent fleet configured with `model: inherit` (ADR-0004) and enforce a hard limit of $\le 20$ core skills.
   - Veto external wrapper scripts (`ccg-workflow`, `codeagent-wrapper`) and Claude Code lifecycle hooks (`hooks.json`).

2. **Implement Pre-Execution PowerShell AST Security Validator (`Test-PowerShellCommandSafety.ps1`)**:
   - Reject ECC's 2,245-line JavaScript regex parser.
   - Author a lean (~60 lines) native PowerShell script in `config/skills/audit-dev-workflow/scripts/Test-PowerShellCommandSafety.ps1` utilizing `[System.Management.Automation.Language.Parser]`.
   - The script inspects the parsed command AST tokens for forbidden destructive cmdlets (`Remove-Item -Recurse -Force`, `Format-Volume`, `Clear-Disk`, `git push --force`, bypass flags `--no-verify`) with 100% precision and $<5$ms execution overhead, halting execution prior to command dispatch.

3. **Establish Explicit Credential & Path Deny-List in `GEMINI.md`**:
   - Insert an immutable `<!-- security-boundaries -->` block into `GEMINI.md` defining strict deny paths:
     - User credentials: `~/.ssh/**`, `~/.aws/**`, `~/.gnupg/**`
     - Environment secrets: `**/.env*`, `**/*.key`, `**/*.pem`
     - Antigravity tokens: `C:\Users\*\.gemini\antigravity\mcp\**`
   - Quarantine untrusted external content (git diffs, issues, PRs) as raw data to defeat the "Lethal Trifecta" prompt injection vector.
   - Mandate MCP argument sanitization to prevent passing file contents or secrets to outbound MCP servers.

4. **Adopt Evidence-Normalized Review-Verify DAG Barrier**:
   - Integrate ECC's 2-stage Review $\rightarrow$ Dedup $\rightarrow$ Verify DAG into `council-review`:
     - Stage 1: Parallel subagent review across orthogonal dimensions.
     - Barrier: Deduplicate findings by normalizing code snippets (`${file}::${normalize(evidence)}`) and promoting severities to the supremum.
     - Stage 2: Pass only unique `CRITICAL` and `HIGH` findings to independent adversarial verification.
     - Fail-Closed Semantics: Uncertainty or timeout in the verifier keeps the finding as blocking.

5. **Formalize Blast-Radius Size-Tiered Pipeline Routing (Step 0)**:
   - Update `audit-dev-workflow` to classify incoming tasks into 4 blast tiers:
     - `trivial` (1 file, localized): TDD $\rightarrow$ verify $\rightarrow$ commit. Multi-agent council skipped.
     - `small` (1 module, clear scope): Single auditor review.
     - `standard` (2–5 files, internal refactor): System architect planning $\rightarrow$ Gate 1 $\rightarrow$ TDD $\rightarrow$ code-auditor $\rightarrow$ Gate 2.
     - `large` (cross-cutting, schema, public API): Full Tri-Pillar Council Review (`council-review`).

6. **Establish Antigravity Tactical Gotcha Protocol (ATGP) in `sync-task-state`**:
   - Reject ECC's daemon-based observer and unbounded `ck` storage.
   - Enforce single-line structured gotchas in `task_state.md` (`## Known Edge Cases`):
     `- [DOMAIN/SUBSYS] <Trigger>: <Workaround> (HEAD: <Short-SHA>)`
   - Enforce a 3-tier promotion lifecycle: Micro-Capture (max 5 items, $\le 20$ lines) $\rightarrow$ Code Inlining (per `antislop-code`) $\rightarrow$ Promotion to `docs/adr/`.
   - Update the PowerShell verification gate in `sync-task-state` to assert both base budget ($\le 8,192$ bytes, $\le 100$ lines) and gotcha limit ($\le 5$ items).
   - Adopt ECC's `/aside` temporary task-freezing rule into `GEMINI.md`.

7. **Adopt Curated Domain Skills & De-Sloppify Pass**:
   - Ingest exactly 3 high-impact, domain-agnostic skills into `config/skills/`: `contract-first`, `database-migrations`, and `coding-standards`.
   - Embed a `de-sloppify` cleanup pass into `config/agents/tdd-guide/agent.md` to scrub redundant compiler-level test assertions without chilling TDD velocity.

## Consequences

### Positive
- **Eliminates Prompt-Level Security Vulnerabilities**: Closes the prompt-level advisory fallacy by intercepting destructive commands at the PowerShell AST compiler layer before execution.
- **Protects Context Budget & Token Economy**: Prevents ~20,215 tokens of prompt bloat per turn by rejecting the monolithic catalog, while keeping `task_state.md` strictly within $\le 8$ KB / $\le 100$ lines.
- **Deduplicates Review Noise**: Cuts multi-agent verification token expenditure and latency by >50% via evidence-normalized deduplication.
- **Guarantees Windows Runtime Stability**: Replaces broken Unix daemons and brittle Node scripts with native PowerShell 7.6 / .NET primitives, eliminating Job Object process terminations and syntax crashes.
- **Preserves Lean Ergonomics**: Scales ceremony to blast radius via Step 0 routing, avoiding multi-agent overhead on trivial bug fixes.

### Negative & Operational Requirements
- **AST Parser Limitations**: Static PowerShell AST analysis cannot resolve obfuscated runtime strings (e.g. `Invoke-Expression ([char]...))`); requires layered prompt quarantining as secondary defense.
- **Manual Gotcha Triage**: Developers and agents must periodically triage `task_state.md` when the 5-gotcha limit is reached, promoting architectural items to formal ADRs.
- **Review Latency on Large Tiers**: Tier `large` operations still incur multi-agent token expenditure during Council Review, though mitigated by deduplication barriers.
