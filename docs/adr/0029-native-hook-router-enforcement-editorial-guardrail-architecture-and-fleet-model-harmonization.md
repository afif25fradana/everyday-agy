# ADR-0029: Native Hook Router Enforcement, Editorial Guardrail Architecture, and Fleet Model Harmonization

## Status
Accepted (Partially supersedes ADR-0027 for fleet model harmonization and ADR-0028 specifically for CI test suite placement in `.github/tests/*.Tests.ps1`)

## Date
2026-11-10

## Context
Following the consolidation of workflow governance and audit rubrics in ADR-0028, four structural gaps and operational frictions were identified across runtime enforcement, documentation governance, and subagent capabilities:

1. **Prompt-Only Safety & Delegation Contract Gaps**:
   PowerShell command safety checks (`Test-PowerShellCommandSafety.ps1`), credential deny-path boundaries, and subagent delegation contracts relied entirely on voluntary compliance via LLM prompt instructions. Under complex multi-turn execution, prompt-only safety instructions can be bypassed or skipped. Furthermore, Google Antigravity introduced native hook event handlers (`PreToolUse`, `PostToolUse` via `hooks.json`), yet `everyday-agy` lacked an integrated hook router and omitted hooks from repo-scoped deployment scripts (`sync.ps1`, `restore.ps1`).
2. **Sync & Restore Script Legacy Footprint and Test Leakage**:
   `sync.ps1` and `restore.ps1` retained obsolete pre-ADR-0016 arrays (`externalSkills`, `officialPlugins`) that hardcoded legacy external skill mappings, creating drift and failing to deploy modern hooks (`config/hooks.json`) and scripts (`config/scripts/`). Simultaneously, storing the CI and regression test suites (`AuditCheckpoint.Tests.ps1`, `Test-PowerShellCommandSafety.Tests.ps1`, `YamlValidation.Tests.ps1`) inside `config/skills/orchestrator/scripts/` caused `restore.ps1` to copy repository test suites into `~/.gemini/config/skills/orchestrator/scripts/`.
3. **Role-Scoped Write Ambiguity (Parent vs Subagents)**:
   In `config/GEMINI.md#L42,47` and `config/skills/orchestrator/SKILL.md#L17-21`, write path boundary rules conflated the Parent Lead Orchestrator with specialist subagents. Parent agents on Tier 2/3 occasionally attempted inline repository edits despite context insulation rules, while subagents lacked explicit permission language for modifying granted targets within `<SCOPE_AND_BOUNDARIES>`.
4. **Editorial Standard Fragmentation, Template Bloat & Model Capability Mismatches**:
   - Technical documentation lacked a single source of truth for anti-marketing and authenticity guardrails. Public documentation was vulnerable to indie-hacker slogans ("supercharge your workflow"), unrequested fictional dialogues, and subtle false-contrast rhetorical tells ("Not X; it is Y").
   - The repository carried enterprise-style GitHub templates (`.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/*`) and a `## Contributing` section in `README.md` misaligned with a single-developer personal dotfiles setup.
   - `docs-architect`, `l10n-humanizer`, and `ui-crafter` remained configured with `model: flash` in agent manifests despite handling nuanced multi-file design systems, bilingual translations, and architectural synthesis that require the reasoning depth of `model: inherit`.
   - `coding-standards/SKILL.md` spanned 384 lines with verbose examples that consumed high token context without providing an authoritative Active LTS floor table for `spec-verifier`. Concurrently, `differential-review` scattered 4 supporting files in its root rather than using the canonical `references/` directory anatomy.

## Decision

We establish a unified three-pillar architecture resolving runtime safety, documentation governance, and fleet execution:

### Pillar 1: Native Antigravity Hook Enforcement, Synchronization Parity & Test Isolation
1. **Native Hook Router (`config/hooks.json` & `config/scripts/Invoke-AntigravityHook.ps1`)**:
   - Register 3 `PreToolUse` hooks and 1 `PostToolUse` hook in `config/hooks.json`, executing `Invoke-AntigravityHook.ps1 -Event PreToolUse` or `-Event PostToolUse`:
     - **Guard 1 (`PreToolUse`, matcher `run_command`)**: Validates `CommandLine` via `Test-PowerShellCommandSafety.ps1` AST safety gate, blocking destructive operations (`rm -rf`, `Remove-Item -Recurse -Force`, `git push --force`, `git clean -fdx`).
     - **Guard 2 (`PreToolUse`, matcher `view_file|replace_file_content|multi_replace_file_content|write_to_file`)**: Enforces credential/secret deny-path blocking ONLY (`Test-DenyPath`: `.env*` excluding `.env.example`/`.env.sample`/`.env.template`, `~/.ssh`, `~/.aws`, `~/.gnupg`, `*.key`, `*.pem`, Antigravity `mcp/**`). Explicitly does NOT block normal workspace reads/writes by boundary, role, or tier (role-scoped Tier 2/3 mutation discipline remains governed by `config/GEMINI.md` and `orchestrator/SKILL.md`).
     - **Guard 3 (`PreToolUse`, matcher `invoke_subagent`)**: Enforces all 4 mandatory 4-slot delegation XML tags (`<ROLE_AND_OBJECTIVE>`, `<SCOPE_AND_BOUNDARIES>`, `<TOOLS_AND_ABSOLUTE_SKILL_PATHS>`, `<RETURN_CONTRACT>`) and validates optional `Model`/`model` aliases (`inherit`, `flash`, `pro`).
     - **Guard 4 (`PostToolUse`, matcher `write_to_file|replace_file_content|multi_replace_file_content`)**: Triggers automatic Gate 2 diff injection via `Update-Gate2Diff.ps1` when `error` is empty, basename matches `gate2_handoff.md`, and the file contains `{{VERBATIM_GIT_DIFF}}` or `{{VERBATIM_GIT_DIFFSTAT}}`.
2. **Synchronization Parity (`sync.ps1` & `restore.ps1`)**:
   - Modernize `sync.ps1` and `restore.ps1` to track and deploy `config/hooks.json` and `config/scripts/Invoke-AntigravityHook.ps1`.
   - Purge dead legacy lists (`externalSkills`, `officialPlugins`), restoring clean synchronization symmetry between repository configs and host user runtimes (`~/.gemini/`).
3. **CI & Regression Test Isolation (`.github/tests/*.Tests.ps1`)**:
   - Relocate `AuditCheckpoint.Tests.ps1`, `Test-PowerShellCommandSafety.Tests.ps1`, and `YamlValidation.Tests.ps1` to `.github/tests/*.Tests.ps1` and update `.github/workflows/ci.yml` and `README.md` to reference `.github/tests/*.Tests.ps1`.
   - Isolating CI and regression test suites in `.github/tests/` ensures `restore.ps1` deploys only runtime operational scripts (`New-AuditCheckpoint.ps1`, `Restore-AuditCheckpoint.ps1`, `Update-Gate2Diff.ps1`, `Test-PowerShellCommandSafety.ps1`) and never deploys test suites into `~/.gemini/`.
   - Supersedes ADR-0028 specifically for CI test suite placement (`.github/tests/*.Tests.ps1`).

### Pillar 2: Tri-Guard Editorial SSOT, Mode B Duet & Role-Scoped Disambiguation
1. **The Tri-Guard Editorial SSOT (`config/skills/clean-docs/SKILL.md#6`)**:
   - Define Section 6 in `clean-docs/SKILL.md` as the authoritative editorial standard:
     - **Guardrail A (Anti-Casual, Anti-Indie-Hacker & Anti-Corporate Cosplay)**: Enforce honest developer-to-developer notebook tone; ban ProductHunt promotional hooks, unrequested conversational roleplay dialogues, and punctuation variants of false contrast ("Not X; it is Y", "Not X—it is Y", "Not X: it is Y", "Not X. It's Y."). Under the **Anti-Corporate Cosplay Rule** (enforced in `clean-docs/SKILL.md` Section 6 Guardrail A and `docs-architect/agent.md` Mode B), avoid generating or recommending enterprise bureaucracy templates (`CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/*`) for personal/single-developer repositories, dotfiles, or experimental side projects unless explicitly requested by the user. Under this rule, remove `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/*`, and `README.md`'s `## Contributing` section from this repository.
     - **Guardrail B (Upfront Sandbox & Scaffolding Honesty)**: Disclose prototype, mockup, or stub limitations in opening paragraphs of `README.md`, never hidden in bottom footnotes.
     - **Guardrail C (Cross-Session Continuity via `task_state.md`)**: Mandate inspection of `task_state.md` in repository or sibling `*-AI-Context` before rewriting public docs to lock settled decisions and project-specific terminology.
2. **Conditional Mode B Duet for Public Repository Documentation**:
   - Formalize the serialized two-stage documentation pipeline in `config/skills/orchestrator/SKILL.md` (Mermaid flowchart and Phase 3):
     - **Stage 3a (`docs-architect` - Mode B)**: Formulates the 4-part pragmatic README/doc structure, grounds technical claims in verified code, and enforces clean documentation standards.
     - **Stage 3b (`l10n-humanizer` - Scope B)**: Reviews and refines drafted prose, purging AI writing tells and marketing fluff while locking technical facts, code blocks, and CLI flags verbatim.
     - *Exemption*: Internal Mode A documentation (`docs/adr/**`, `task_state.md`, architecture topology maps) and Tier 0/1 edits remain single-pass on `docs-architect`.
3. **Role-Scoped Write Disambiguation**:
   - Update `config/GEMINI.md#L42,47` and `config/skills/orchestrator/SKILL.md#L17-21`:
     - **Parent Lead Orchestrator (`invoke_subagent` present)**: On Tier 2/3, strictly barred from calling `read_file`/`view_file` on application source code AND barred from calling mutating tools (`edit_file`, `write_file`, `replace_file_content`, `write_to_file`) on workspace files. Parent write tools on Tier 2/3 are restricted strictly to `<appDataDir>\brain\<conversation-id>\*.md` artifacts and scratch files.
     - **Execution Specialist Subagents (`ROLE_TYPE: SUBAGENT` / `invoke_subagent` absent)**: Mutating specialists (`tdd-guide`, `ui-crafter`, `docs-architect`, `l10n-humanizer`, `maintenance-bot`, `build-error-resolver`) are explicitly authorized to edit granted `<SCOPE_AND_BOUNDARIES>` paths. Read-only specialists (`code-auditor`, `silent-failure-hunter`, `spec-verifier`, `system-architect`) write strictly to `scratch/` dossiers.

### Pillar 3: Fleet Model Harmonization & Skill Anatomical Consolidation
1. **8 `inherit` / 2 `flash` Fleet Split**:
   - Elevate `docs-architect`, `l10n-humanizer`, and `ui-crafter` to `model: inherit` in `config/agents/*/agent.md`.
   - Retain `build-error-resolver` and `maintenance-bot` on `model: flash` for fast, targeted single-file compiler fixes and dependency bumps.
   - Harmonize the 8/2 fleet split across `config/skills/orchestrator/references/subagent-patterns.md` and `config/skills/council-review/references/seat-catalog.md`.
2. **High-Density Shared Floor (`config/skills/coding-standards/SKILL.md`)**:
   - Compress `coding-standards/SKILL.md` from 384 lines into 104 lines without a `references/` split.
   - Preserve all existing section headings verbatim to prevent breaking external consuming agents (`spec-verifier`, `silent-failure-hunter`, `tdd-guide`).
   - Add concise Active LTS runtime floors table (Node 20+, Python 3.12+, Go 1.22+, Java 21/25).
3. **Canonical Directory Anatomy (`config/skills/differential-review/`)**:
   - Move supporting files (`adversarial.md`, `methodology.md`, `patterns.md`, `reporting.md`) into `config/skills/differential-review/references/`.
   - Update relative link depths in `SKILL.md` while maintaining relative links between references.

## Alternatives Considered & Rejected

- **Alternative A: Retain `model: flash` for all mutating specialists**:
  - *Rejected*: Complex UI accessibility audits, bilingual localization with Microsoft style nuances, and multi-file documentation architecture frequently suffered from subtle hallucinations and dropped constraints under `flash`. Elevating the 3 craft specialists to `inherit` matches their cognitive demands.
- **Alternative B: Prompt-only enforcement of command safety and delegation contracts**:
  - *Rejected*: Voluntary compliance degrades under multi-agent pressure. Native hooks provide deterministic, machine-enforced safety that intercepts violations before execution.
- **Alternative C: Split `coding-standards` into multiple reference sub-files**:
  - *Rejected*: Cross-cutting standards (naming, immutability, fail-loud errors) are consulted as a foundational floor by 4 distinct agents. Splitting into multiple files imposes token round-trips and fragmented context without meaningful savings.
- **Alternative D: Keep CI test suites inside `config/skills/orchestrator/scripts/*.Tests.ps1` (ADR-0028 layout)**:
  - *Rejected*: `restore.ps1` recursively mirrors `config/skills/` into `~/.gemini/config/skills/`, copying repository-only CI test suites into the user's live Antigravity runtime directory.

## Consequences

- **Positive**:
  - **Deterministic Safety**: Native hooks enforce AST command safety, credential deny-path blocking, subagent delegation contracts, and automatic Gate 2 diff injection before and after tool calls.
  - **Clean Runtime Deployment**: Isolating `.github/tests/*.Tests.ps1` keeps repository regression tests separate from operational skill scripts deployed by `restore.ps1` into `~/.gemini/`.
  - **Clean Orchestration Boundaries**: Role-scoped write boundaries clearly delineate Parent coordination from Subagent execution.
  - **Authentic Engineering Prose & Lean Repo Hygiene**: The Tri-Guard SSOT, Anti-Corporate Cosplay Rule, and Mode B Duet eliminate indie-hacker hype, unsolicited corporate template bloat, and AI stylistic tells across public repositories.
  - **Fleet Quality**: Elevating 3 craft agents to `model: inherit` improves code craft, bilingual precision, and documentation accuracy.
  - **Modular Directory Standards**: `differential-review` conforms to canonical `skills/<skill>/references/` layout.
- **Negative / Operational Requirements**:
  - Requires maintaining `Invoke-AntigravityHook.ps1` and ensuring PowerShell AST safety parsers run cleanly on Windows and WSL environments.
