# ADR-0030: Lean Subagent Brief, Per-Agent Return Receipts, and Security-Only Hooks

## Status
Accepted (Partially supersedes ADR-0018 for deploying and syncing `docs/adr/` to `~/.gemini/`, ADR-0027 for the 4-slot `<RETURN_CONTRACT>`, ADR-0028 for `config/skills/orchestrator/references/subagent-patterns.md`, and ADR-0029 for `PreToolUse` `invoke_subagent` prompt validation)

## Date
2026-11-10

## Context
In my daily `Gemini 3.8 Flash (High)` sessions, the subagent setup from ADR-0027, ADR-0028, and ADR-0029 ran into five problems:

1. **Duplicate reference file and broken `Model: "inherit"` fallback**:
   `config/skills/orchestrator/references/subagent-patterns.md` repeated the 10-agent table from `TOOLKIT.md`, the rules from `config/skills/orchestrator/SKILL.md`, and copy-paste 4-slot prompt templates. Worse, `config/skills/orchestrator/SKILL.md#L127` told a `flash` parent session to pass `Model: "pro"` or `Model: "inherit"` when upgrading `spec-verifier`. Because `Model: "inherit"` resolves to the parent's own `flash` model, passing `inherit` did nothing.

2. **Four-slot dispatch boilerplate on every subagent call**:
   `config/GEMINI.md`, `config/skills/orchestrator/SKILL.md`, `config/skills/documentation-and-adrs/SKILL.md`, and all 10 `config/agents/*/agent.md` files forced every `invoke_subagent` prompt to carry a heavy 4-slot wrapper (`ROLE_TYPE: SUBAGENT (EXECUTION SPECIALIST)`, `<ROLE_AND_OBJECTIVE>`, `<SCOPE_AND_BOUNDARIES>`, `<TOOLS_AND_ABSOLUTE_SKILL_PATHS>`, `<RETURN_CONTRACT>`). That wrapper repeated agent identity, credential deny-paths already enforced by `config/GEMINI.md` and `Invoke-AntigravityHook.ps1`, `<skills>` paths already injected by Antigravity, and long fenced receipt blocks at the bottom of every `agent.md`. Also, `Settled Findings:` in `orchestrator/SKILL.md` and `audit-dev/SKILL.md` did not warn against passing unreviewed assumptions as settled.

3. **Over-broad `PreToolUse` hook blocking `teamwork` and built-in subagents**:
   Under ADR-0029, `config/hooks.json` ran Guard 3 on `invoke_subagent` and rejected any prompt missing all four XML tags or using unaccepted `Model` values. That broke `teamwork` council calls (`council-review/SKILL.md`, `academic-council/SKILL.md`) that start with `"Requested team: ..."`, blocked plain prompts to built-in `research` and `self` subagents, and blocked leaner prompts to my custom agents.

4. **Missing `read_url_content` tool on `spec-verifier`**:
   `config/agents/spec-verifier/agent.md`, `config/skills/deep-web-research/SKILL.md`, and `TOOLKIT.md#L124` listed `read_url_content` (`Read URL`), which does not exist in Antigravity's subagent tool runtime.

5. **Unnecessary ADR copying in `restore.ps1` and `sync.ps1`**:
   Per ADR-0018, `restore.ps1` copied `docs/adr/` into `~/.gemini/docs/adr` and backed it up on every deploy, while `sync.ps1` copied `~/.gemini/docs/adr` back into the repository. ADRs record design choices for this repository and belong in Git. Copying them to `~/.gemini/` only risked letting stale local copies overwrite repository files during sync.

## Decision

I trimmed the dispatch prompt, replaced the fenced receipt blocks in each `agent.md` with a short `## Output` section, narrowed runtime hooks to security and diff checks, removed the unmapped URL tool, and stopped copying `docs/adr/` in `restore.ps1` and `sync.ps1`:

### 1. Drop `subagent-patterns.md` and fix model overrides
- I deleted `config/skills/orchestrator/references/subagent-patterns.md` and removed its link from `config/skills/orchestrator/SKILL.md#L127`. `.github/tests/YamlValidation.Tests.ps1#L339-340` checks that this file stays gone.
- I updated `config/skills/orchestrator/SKILL.md#L127` to list the 8 `inherit` / 2 `flash` fleet defaults directly (`build-error-resolver` and `maintenance-bot` default to `model: flash`; the other 8 default to `model: inherit`). When the parent runs on `flash`, it must pass `Model: "pro"` explicitly to upgrade `spec-verifier`, `system-architect`, or `docs-architect`. I also moved the `Workspace: inherit` rule there so subagents write intermediate reports to `<appDataDir>\brain\<conversation-id>\scratch\<task>\` without duplicating `node_modules` or hitting Windows file locks.

### 2. Switch to the 3-slot XML brief and tighten `Settled Findings`
- I replaced the 4-slot wrapper in `config/GEMINI.md#L42,47`, `config/skills/orchestrator/SKILL.md#L20,55,137,191-210`, and `config/skills/documentation-and-adrs/SKILL.md#L89` with three uppercase XML tags:
  - `<OBJECTIVE>`: task goal, verification bar, and active mode when needed.
  - `<SCOPE>`: `Targets:`, `Allowed Mutation Paths:`, and `Settled Findings:`.
  - `<DELIVERABLE>`: `Scratch Report:` path (omitted for `build-error-resolver`) and a short reminder to follow `## Output` in the agent's `agent.md` (with an inline fallback field list at `orchestrator/SKILL.md#L208` for built-in `research` and `self` subagents).
- I kept uppercase XML delimiters (`<OBJECTIVE>`, `<SCOPE>`, `<DELIVERABLE>`) per `config/skills/documentation-and-adrs/SKILL.md#L89` so `Gemini 3.8 Flash` does not merge or drop required fields.
- I kept `## Mandatory Skill Activation Gate` in all 10 `config/agents/*/agent.md` files because Antigravity injects skill names and OS paths in the `<skills>` header rather than preloading full `SKILL.md` bodies.
- I removed stale `ROLE_TYPE: SUBAGENT` labels from `config/GEMINI.md#L47`, `config/skills/orchestrator/SKILL.md#L20`, `config/skills/sync-task-state/SKILL.md#L30,94`, and `config/skills/gh-workflow/SKILL.md#L15`.
- I updated `config/skills/orchestrator/SKILL.md#L55,203` and `config/skills/audit-dev/SKILL.md#L92-93` so `Settled Findings:` accepts only items contested with evidence or accepted by the operator, never unreviewed assumptions.

### 3. Replace agent receipt blocks with a 2-line `## Output` section
I replaced the fenced receipt templates at the bottom of all 10 `config/agents/*/agent.md` files with a plain 2-line `## Output` section. Each manifest states where detailed output goes (`<appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md`, or in-place `replace_file_content` only for `build-error-resolver`) and which role-specific fields belong in the `<= 15`-line chat summary:
- `build-error-resolver` keeps `write_to_file` disabled (checked by `.github/tests/YamlValidation.Tests.ps1#L191-195`) and reports `Deliverable Path: N/A (in-place replace_file_content only)`.
- `tdd-guide` reports coordinates, caller blast radius, fast syntax check, witnessed RED failure, GREEN pass, and scratch path.
- `code-auditor`, `silent-failure-hunter`, and `spec-verifier` report coordinates, blast radius or grounding sources, their severity or verification counts (`P0–P3` / `B1–B4`, `H1–H4`, `V1–V4`), CLI commands run, and scratch path.
- `system-architect` reports mode (`Read-Only Explorer` or `Spec Author (spec-kit)`), caller blast radius and Scope Level (`1–4`), grounding checks, and scratch or `specs/` path.
- `docs-architect` reports `Mode A` or `Mode B`, parity or hygiene checks, `sync-task-state` byte/line/SHA/edge-case metrics when used (`config/skills/sync-task-state/SKILL.md#L94-96`), and deliverable or scratch path.
- `l10n-humanizer`, `ui-crafter`, and `maintenance-bot` report their active scope or mode, verification checks (including pinned Head SHA and PR count for `maintenance-bot`), and deliverable or scratch path.

### 4. Keep hooks focused on security and diffs, and drop `read_url_content`
- I removed the `invoke_subagent` matcher from `config/hooks.json` and removed the `"invoke_subagent"` branch from `config/scripts/Invoke-AntigravityHook.ps1`. Non-hooked tools fall through to `default` (`allow`), unblocking `teamwork`, `research`, `self`, and the 3-slot brief.
- I kept the 3 security and diff hooks: `PreToolUse` `run_command` AST safety (`Test-PowerShellCommandSafety.ps1`), `PreToolUse` file-tool credential deny-paths (`Test-DenyPath`), and `PostToolUse` automatic diff injection into `gate2_handoff.md` (`Update-Gate2Diff.ps1`).
- I updated `TOOLKIT.md` Section 6 to drop the `invoke_subagent` row and cite `(ADR-0029, ADR-0030)`. I updated `.github/tests/YamlValidation.Tests.ps1#L311-325` to require exact 2 `PreToolUse` matchers excluding `invoke_subagent`, and updated `.github/tests/Test-PowerShellCommandSafety.Tests.ps1#L467-534` to test `invoke_subagent` pass-through for `teamwork`, 3-slot XML briefs, untagged `research`/`self` prompts, and `Subagents` arrays.
- I removed `- read_url_content` from `config/agents/spec-verifier/agent.md`, updated `spec-verifier/agent.md#L37` and `config/skills/deep-web-research/SKILL.md#L34` to fall back from `search_web` to CLI fetch via `run_command` (`curl.exe` or `Invoke-RestMethod` per `deep-web-research/SKILL.md` Section 2.C), and removed `Read URL, ` from `TOOLKIT.md#L124`.

### 5. Stop copying `docs/adr/` in `restore.ps1` and `sync.ps1`
- I updated `restore.ps1#L74,201-212` so it stops backing up or copying `docs/adr/` into `~/.gemini/`. Step 5 now deletes stale `~/.gemini/docs/adr` and `~/.gemini/config/docs/adr` directories if present, then removes the parent `docs/` directory only when empty so sibling files stay untouched.
- I removed `$dstAdr`, `$srcAdrsDir`, the ADR credential-scan target, and Step 5 from `sync.ps1` so syncing never creates or overwrites repository `docs/adr/` files.
- I added regression tests for both behaviors in `.github/tests/Test-PowerShellCommandSafety.Tests.ps1#L628-746`.

## Alternatives Considered & Rejected
- **Plain prose labels (`Objective:`, `Scope:`, `Deliverable:`) instead of XML tags**: Rejected. Without closing tags, multi-line scopes and `Settled Findings:` lines blur together under `Gemini 3.8 Flash` (`documentation-and-adrs/SKILL.md#L89`).
- **Keep Guard 3 in `Invoke-AntigravityHook.ps1` for custom agents only**: Rejected. Maintaining a PowerShell allowlist for `teamwork`, `research`, and `self` across single-object and `Subagents` array payloads adds parser fragility for zero security gain.
- **Delete `## Mandatory Skill Activation Gate` from `agent.md` files**: Rejected. Antigravity passes skill metadata and file paths under `<skills>` rather than full `SKILL.md` contents, so subagents still need that explicit `view_file` gate.
- **Keep syncing `docs/adr/` behind an opt-in flag**: Rejected. ADRs belong strictly in Git; pruning stale `~/.gemini/docs/adr` and `~/.gemini/config/docs/adr` folders on restore avoids stale local copies without adding extra script flags.

## Consequences
- **Positive**:
  - Subagent prompts drop duplicate boilerplate while keeping clear `<OBJECTIVE>`, `<SCOPE>`, and `<DELIVERABLE>` boundaries.
  - Passing `Model: "pro"` from a `flash` parent session works properly, and `Settled Findings:` no longer accepts unreviewed guesses.
  - `teamwork` council calls and built-in `research` and `self` subagents pass through hooks normally, while command safety, deny-path checks, and Gate 2 diff injection still run.
  - `spec-verifier`, `deep-web-research`, and `TOOLKIT.md` match the real Antigravity tool list.
  - `restore.ps1` and `sync.ps1` leave `docs/adr/` in Git alone and clean up stale `~/.gemini/docs/adr` and `~/.gemini/config/docs/adr` directories safely.
- **Negative / Operational Requirements**:
  - Prompt formatting and chat summary length now rely on `orchestrator/SKILL.md` and each `agent.md` rather than a `PreToolUse` hook.
  - Built-in `research` and `self` subagents have no custom `agent.md`, so they rely on the fallback field list in `orchestrator/SKILL.md#L208`.
