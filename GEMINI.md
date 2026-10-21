<!-- dev-tooling -->
# Environment & Tooling
- Verified tools: rtk, git, gh (authed), node, npm, python, pip, java (JBR 25), code, opencode, rg, ast-grep, fzf, ffmpeg, adb.
- Shells: Windows PowerShell 5.1 & PowerShell 7.6 (pwsh). Prefer pwsh.
- Missing: pnpm, yarn, bun, uv, go, cargo, docker, kubectl, terraform, aws, az, gcloud, jq, make. Do not assume or install without asking.
- Execution: Prefix external tools (git, npm, npx, pip, rg) with `rtk` if available. Do not prefix `gh` or PowerShell cmdlets. Fallback: run raw or `rtk proxy <cmd>` if output is truncated or if `rtk` is not installed.
<!-- dev-tooling -->

<!-- context7 -->
# Documentation
- Use Context7 MCP (`resolve-library-id` -> `query-docs`) for external libraries and APIs before relying on training data.
<!-- context7 -->

<!-- ponytail -->
# Code Standard (YAGNI & Anti-Slop)
- Shortest working diff wins. Never write speculative abstractions, single-impl interfaces, or unneeded dependencies.
- Reuse existing helpers and stdlib first. Grep all callers before editing; fix root causes, not symptoms.
- Never simplify away security, input validation, data integrity, or accessibility.
- Anti-Slop: Zero obvious/generic AI commentary in code. Keep UI crafted, clean, and accessible (no purple AI gradients).
<!-- ponytail -->

<!-- workflow-guardrails -->
# Workflow & Safety Guardrails
1. Investigate First: Trace callers and state before proposing edits. For large/complex codebases, consult the `audit-dev-workflow` skill.
2. Explicit Approval: Wait for explicit user confirmation in chat before modifying files, installing packages, or running mutating commands.
3. Checkpoint & Safety: Ensure git repo is clean or commit a checkpoint before modifying files. Stop immediately on unexpected test/build failures.
4. Lean Output: Keep chat concise (1–2 lines with diff / action items). Say plainly what code does without corporate or AI buzzwords.
<!-- workflow-guardrails -->

<!-- architecture-invariants -->
# Architecture Invariants & Decisions (ADR)
- Context7 MCP: Keep token directly in `mcp_config.json`. Streamable HTTP headers do not support env var interpolation; moving to env vars breaks authentication (see ADR-0001).
- Modular Skills: Keep domain skills partitioned (e.g. `antislop-*`, Ponytail 5 suite). Do not merge into monolithic skills with reference folders to prevent greedy LLM retrieval (see ADR-0002, ADR-0003).
- Subagent Tiering: Analytical agents (`system-architect`, `database-reviewer`, `code-auditor`, `silent-failure-hunter`) use `model: inherit` (see ADR-0004).
- Plugin Decoupling: Do not bundle official marketplace plugins in Git. Maintain only bespoke configurations in config/plugins/ and install official tooling via Antigravity Marketplace (see ADR-0006).
<!-- architecture-invariants -->
