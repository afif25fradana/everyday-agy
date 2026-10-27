# ADR-0012: Flash High Optimization, AST Hardening, and Cognitive Tiering Invariants

## Status
Accepted

## Date
2026-10-28

## Context
Following an external configuration review conducted via Gemini 4 Argon in webchat and audited through Antigravity's `spec-verifier` subagent, several optimization opportunities, latent security bypasses, and architectural questions arose:

1. **Subagent Model Tiering Under Flagship Flash Sessions**:
   The external review proposed migrating all five tactical subagents (`tdd-guide`, `build-error-resolver`, `ui-crafter`, `docs-architect`, `maintenance-bot`) from `model: flash` to `model: inherit`, arguing that running primary sessions on `Gemini 3.8 Flash (High)` meant tactical subagents degraded to base Flash without thinking.
2. **Context Discovery Turn Latency**:
   `GEMINI.md` contained sequential instructions (*"read ... then read ..."*), causing modern models capable of multi-tool execution to make 3–4 sequential roundtrips for initial repository discovery.
3. **AST Safety Validator Vulnerabilities and False Positives**:
   `Test-PowerShellCommandSafety.ps1` exhibited two distinct flaws:
   - Parameter prefix abbreviations (e.g. `Remove-Item -rec`, `Remove-Item -Recurse:$true`) and short commit flags (`git commit -m "msg" -n`) bypassed destructive command interception.
   - Naive text matching on git invocations produced false positives on benign developer commit messages containing flag keywords (e.g. `rtk git commit -m "fix clean -f bug"`).
   - Inadvertent `git reset --hard` commands outside checkpoint branches were not intercepted.
4. **Tool Dualism Drift & Tier 0 Ambiguity**:
   `audit-dev-workflow/SKILL.md` instructed Parent agents to use subagent-only tools (`view_file`, `replace_file_content`), conflicting with ADR-0007. Furthermore, `handoff-spec.md#L24` contained phrasing suggesting file modification preceded human confirmation in Tier 0.
5. **Orphaned Skills & Documentation Parity**:
   Newly introduced domain skills (`contract-first`, `database-migrations`, `coding-standards`, `clean-docs`) lacked YAML frontmatter bindings in custom agents, and repo documentation catalogs reported 19 skills instead of 20.

## Decision

1. **Reaffirm and Enforce ADR-0004 Hybrid Model Tiering Invariants**:
   - Veto blanket `model: inherit` migration for tactical subagents. Retain `model: flash` strictly for `tdd-guide`, `build-error-resolver`, `ui-crafter`, `docs-architect`, and `maintenance-bot`.
   - Reaffirm that Gemini 3.8 Flash is fully capable of bounded, mechanical execution tasks adhering to Ponytail ("shortest working diff wins"). Unbounded reasoning tokens on tactical agents induce speculative over-engineering.
   - Prevent catastrophic quota and latency degradation when primary sessions operate on `Gemini 3.8 Pro`.
2. **Adopt Parallel Context Fan-Out in `GEMINI.md`**:
   - Restructure discovery turn rules to batch read-only inspections (`task_state.md`, `docs/AGENTS.md`, and `docs/adr/README.md`) into a single multi-tool turn.
   - Refine the AST safety trigger wording to exempt read-only commands, test runners, and routine `rtk git` operations.
3. **Harden Pre-Execution AST Safety Validator**:
   - Expand `Remove-Item` parameter detection to catch PowerShell prefix abbreviations (`-r` through `-recurse`, `-f` through `-force`) and boolean syntax (`:$true`).
   - Implement token-aware argument parsing for `git`/`rtk` commands that strips message payloads (`-m`, `--message`), preventing false positives on commit messages.
   - Intercept short bypass flags (`-n` for `--no-verify`).
   - Anchor `git reset --hard` validation to strictly permit designated checkpoint branch targets (`^(refs/heads/)?checkpoint-[A-Za-z0-9_-]+$`) while halting arbitrary uncheckpointed resets.
4. **Harmonize Tool Dualism & Upstream Tier 0 Specifications**:
   - Align `audit-dev-workflow/SKILL.md` with ADR-0007 (`read_file`/`edit_file` for Parent; `view_file`/`replace_file_content` for Subagents).
   - Delete obsolete redirect stub files (`clean-docs.md`, `public-repo-checklist.md`).
   - Clarify `handoff-spec.md#L24` so Tier 0 bypasses formal Gate 1 ceremony upon simple chat approval, strictly preserving prior human confirmation before file mutations.
5. **Decouple Skill Bindings and Synchronize Catalog Documentation**:
   - Bind domain skills to custom agent YAML frontmatters independently of model tiering.
   - Update `README.md` and `TOOLKIT.md` to catalog 20 modular skills, registering `clean-docs` under Bespoke Architectures.

## Alternatives Considered & Rejected

- **Migrating all agents to `model: inherit`**: Rejected. Degrades execution speed on routine tasks and burns Pro quota on trivial dependency or typing fixes.
- **Permitting disk modifications prior to chat approval for Tier 0**: Rejected. Violates core safety guardrails; approval must precede file mutation even on trivial diffs.
- **Adding `betterleaks` to Verified Tools without local binary installation**: Rejected as a tool hallucination.

## Consequences

### Positive
- **Zero False Positives on Git Commits**: Developers and agents can commit messages referencing security flags without validator interruptions.
- **Comprehensive AST Safety Coverage**: Catching parameter abbreviations and uncheckpointed hard resets closes real bypass vectors on Windows environments.
- **Optimized Discovery Latency**: Reduces initial context reading turns by up to 70% under Gemini 3.8 Flash High.
- **Architectural Integrity Preserved**: Subagent roles remain cleanly partitioned between cognitive architects and fast tactical executors.

### Negative & Operational Requirements
- Restorations and deployments must continue passing `restore.ps1` pre-flight credential scans.
- Any manual invocation of `git reset --hard` must target a named `checkpoint-*` branch or bypass via explicit user execution.
