# Subagent Execution Patterns for Audit-First Workflow

The multi-tiered architecture allows the **Parent Agent** to orchestrate specialized **Subagents** across the 11-agent fleet. This keeps parent context clean, eliminates token bloat during deep audits, and enables safe, disciplined execution. Governed by [`orchestrator`](../../orchestrator/SKILL.md) and [`ADR-0018`](../../../../docs/adr/0018-fleet-parity-and-deployment-path-symmetry.md).

---

## 1. Division of Responsibilities (11-Agent Fleet)

| Role / Domain | Agent (`TypeName`) | Model | Workspace | Key Responsibilities |
| :--- | :--- | :--- | :--- | :--- |
| **Lead Orchestrator** | Parent Agent | Primary | Host CWD | Directs zero-read triage, manages checkpoints, implements fixes directly on Tier 0/1; on Tier 2/3 governs fleet under [`orchestrator`](../../orchestrator/SKILL.md) with Context Insulation, runs CLI verification tests, and handles user approval gates. |
| **Architecture & Topology** | `system-architect` | `inherit` | `inherit` | Contract-first API design, module boundaries, acyclic DAG graphs, zero-downtime refactors, and Nygard ADR documentation. Read-only explorer on Tier 2/3. |
| **Security & Code Health** | `code-auditor` | `inherit` | `inherit` | Whole-repo health, security attack surface, injection/auth boundaries, secret scanner hygiene, and anti-slop code hygiene. Read-only explorer or diff verifier. |
| **Reliability & Silent Failures** | `silent-failure-hunter` | `inherit` | `inherit` | Audits swallowed exceptions, masking fallbacks (`.catch(() => [])`), resource leaks, unhandled edge cases, and timeout drops. |
| **Test Integrity & TDD** | `tdd-guide` | `flash` | `inherit` | Test-Driven Development (Red-Green-Refactor), boundary testing, mutation checks, and anti-mock cheating verification. Mutating subagent (sequential execution). |
| **Persistence & Schema** | `database-reviewer` | `inherit` (`pro` on Flash) | `inherit` | SQL schema migrations, indexing strategies, N+1 query traps, zero-downtime expand/contract patterns, and foreign key integrity. |
| **Frontend UX & Primitives** | `ui-crafter` | `inherit` | `inherit` | Web platform primitives, WCAG 2.2 AA accessibility, layout shifts, dark mode, responsive styling, and anti-slop UI design. Mutating subagent (sequential execution). |
| **Documentation & ADRs** | `docs-architect` | `flash` | `inherit` | Architecture Decision Records (ADRs), progressive disclosure sub-docs, anti-slop copywriting, and AI context synchronization (`task_state.md`). Mutating subagent (sequential execution). |
| **Type Safety & Compilation** | `build-error-resolver` | `inherit` | `inherit` | TypeScript/compiler error resolution, type soundness, generic constraints, and strict compilation hygiene. Mutating subagent (sequential execution). |
| **Dependency & CI Maintenance** | `maintenance-bot` | `inherit` | `inherit` | Package dependency hygiene, CVE vulnerability mitigation, Dependabot triage, and CI workflow diagnosis. Mutating subagent (sequential execution). |
| **Official Spec Verifier** | `spec-verifier` | `inherit` (`pro` on Flash) | `inherit` | Authoritative vendor spec verification via Context7 MCP (`resolve-library-id` -> `query-docs`) and official documentation before implementing third-party APIs. |
| **Software Localization** | `l10n-humanizer` | `flash` | `inherit` | Software localization (L10n), UI translation, Microsoft Indonesian style guide consistency, UX microcopy conciseness, and XML/JSON escaping. Mutating subagent (sequential execution). |

---

## 2. Subagent Invocation & Communication Protocol

### 2.1 Workspace & Safety Isolation
- **Atomic Git Checkpoints**: Before mutating files or executing complex tests, establish a rollback branch via `New-AuditCheckpoint.ps1 -Task "<task>"`.
- **Workspace Modes**: Default to `inherit` workspace mode to avoid Windows file-locking or worktree `node_modules` duplication. Use session scratch (`<appDataDir>\brain\<conversation-id>\scratch\<task>\`) for intermediate audit artifacts.

### 2.2 Model Selection Invariant (`Model`)
- **Default (`inherit`)**: Inherits parent agent model unless the subagent manifest defines an explicit specialized tier (e.g. `tdd-guide` and `docs-architect` use `model: flash` per ADR-0004 & ADR-0012).
- **Dynamic Flash-to-Pro Elevation (`spec-verifier` & `database-reviewer`)**: Keep `model: inherit` in agent manifests so `Claude Sonnet 4.6 Thinking` or `Gemini 4 Argon` parent sessions never downgrade. When the parent session is running on `Gemini 3.8 Flash`, pass `Model: "pro"` dynamically in `invoke_subagent` when invoking `spec-verifier` (paired with mandatory Context7 MCP live docs) or `database-reviewer`.
- **Explicit User Override**: For all other agents, override model tiers at invocation time ONLY if the user explicitly requests it in chat.

### 2.3 Core Execution & Verification Invariants
1. **4-Slot Delegation Contract & Compact Receipts (ADR-0019)**:
   - Parent invokes Subagent via `invoke_subagent` following the 4-slot structure in [`orchestrator`](../../orchestrator/SKILL.md) (`<ROLE_AND_OBJECTIVE>`, `<SCOPE_AND_BOUNDARIES>`, `<TOOLS_AND_ABSOLUTE_SKILL_PATHS>`, `<RETURN_CONTRACT>`).
   - Subagent writes detailed forensic reports to session scratch (`<appDataDir>\brain\<conversation-id>\scratch\<task>\`), returning ONLY a compact receipt (<= 15 lines) to chat to preserve parent context insulation.
2. **Sequential Execution & Single-Writer Mutual Exclusion**:
   - Mutating subagents MUST execute strictly serialized (at most 1 active mutating agent at any time). Read-only explorers may execute in parallel.
3. **Pre-Mutation Syntax Interception**:
   - Mutating subagents run fast syntax checks (`node --check`, `python -m py_compile`, PowerShell `Parser::ParseFile`) immediately upon editing files to fix syntax typos in-turn without incrementing the monotonic stop-rule counter.
4. **Zero Process Leak in Git Commits**:
   - Any commit prepared for or by a subagent must strictly follow humanized Conventional Commits with zero internal AI tags or phase markers.
5. **Independent VCS Receipt Check (`verification-before-completion`)**:
   - When Parent delegates mutations to a subagent (especially `flash`-tier agents like `tdd-guide`), the Parent must never rely on subagent text claims alone.
   - Parent must independently verify `rtk git status --short` and `rtk git diff --stat`, and execute fresh test runs directly from Parent context before accepting delegated work.
6. **Two-Stage Spec-First Review & "Skip Style" Directive**:
   - When delegating diff or code review to a subagent (`code-auditor` or `silent-failure-hunter`), instruct it to evaluate in two stages: (1) line-by-line compliance against the approved plan and requirements, then (2) correctness, security, and edge cases.
   - Explicitly instruct review subagents to skip purely stylistic formatting preferences, subjective aesthetic nits, or unsolicited rewrites. Focus exclusively on defects, spec gaps, and security risks.

---

### 2.4 Standard Prompt Skeletons (4-Slot Copy-Paste Templates)

#### Template 1: Specialist Explorer Subagent Prompt Skeleton
- **TypeName**: `code-auditor` (or `system-architect`)
- **Role**: `Specialist Explorer`
- **Model**: `inherit`
- **Workspace**: `inherit`

```markdown
ROLE_TYPE: SUBAGENT (EXECUTION SPECIALIST)

<ROLE_AND_OBJECTIVE>
You are the Specialist Explorer (<code-auditor / system-architect>) analyzing <feature/bug>.
Your objective is read-only discovery, tracing invariants, callers, and dependencies to preserve Parent Context Insulation.
Zero Process Leaks: do not emit AI process tags or commit markers.
</ROLE_AND_OBJECTIVE>

<SCOPE_AND_BOUNDARIES>
Target Coordinates: <file.ext#Lxx-Lyy>
Allowed Mutation Paths: NONE (Read-Only Inspection)
Deny Paths: ~/.ssh/**, ~/.aws/**, ~/.gnupg/**, **/.env*, **/*.key, **/*.pem, mcp/**
</SCOPE_AND_BOUNDARIES>

<TOOLS_AND_ABSOLUTE_SKILL_PATHS>
Tools: Use view_file to inspect code; rtk rg for caller searches; run_command for read-only checks.
Bound Skills (resolve via absolute paths from prompt header):
- $HOME/.gemini/config/skills/audit-context-building/SKILL.md
- $HOME/.gemini/config/skills/clean-docs/SKILL.md
</TOOLS_AND_ABSOLUTE_SKILL_PATHS>

<RETURN_CONTRACT>
Write detailed forensic reports to <appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md.
In your final chat message, return ONLY this compact receipt (<= 15 lines):
- Status: [PASS | FAIL | BLOCKED]
- Target Coordinates: <file.ext#Lxx-Lyy>
- Caller Blast Radius: <N callers across M files>
- CLI Test Command: <command executed or N/A>
- Exit Code: <0 or non-zero>
- Assertions: <N passed, 0 failed or N/A>
- Deliverable Path: <appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md
</RETURN_CONTRACT>
```

#### Template 2: TDD Guide Subagent Prompt Skeleton
- **TypeName**: `tdd-guide`
- **Role**: `TDD Specialist`
- **Model**: `flash`
- **Workspace**: `inherit`

```markdown
ROLE_TYPE: SUBAGENT (EXECUTION SPECIALIST)

<ROLE_AND_OBJECTIVE>
You are the TDD Specialist (tdd-guide) establishing failure-first test coverage for <task_name>.
Your objective is to author a reproducible failing test case (RED) verifying the missing behavior before implementation.
Zero Process Leaks: do not emit AI process tags or commit markers.
</ROLE_AND_OBJECTIVE>

<SCOPE_AND_BOUNDARIES>
Target Coordinates: <test_file.ext>
Allowed Mutation Paths: <test_directory/**>
Deny Paths: ~/.ssh/**, ~/.aws/**, ~/.gnupg/**, **/.env*, **/*.key, **/*.pem, mcp/**
</SCOPE_AND_BOUNDARIES>

<TOOLS_AND_ABSOLUTE_SKILL_PATHS>
Tools: Use view_file to inspect existing tests; use write_to_file or replace_file_content to author tests.
Bound Skills (resolve via absolute paths from prompt header):
- $HOME/.gemini/config/skills/coding-standards/SKILL.md
- $HOME/.gemini/config/skills/clean-docs/SKILL.md
</TOOLS_AND_ABSOLUTE_SKILL_PATHS>

<RETURN_CONTRACT>
Write detailed test logs to <appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md.
In your final chat message, return ONLY this compact receipt (<= 15 lines):
- Status: [PASS | FAIL | BLOCKED]
- Target Coordinates: <test_file.ext#Lxx-Lyy>
- Caller Blast Radius: <N callers across M files>
- CLI Test Command: <test runner command>
- Exit Code: <non-zero confirming RED failure>
- Assertions: <0 passed, 1 failed (expected failure)>
- Deliverable Path: <appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md
</RETURN_CONTRACT>
```

#### Template 3: Mutating Implementation Specialist Prompt Skeleton
- **TypeName**: `build-error-resolver` (or `ui-crafter` / `maintenance-bot`)
- **Role**: `Implementation Specialist`
- **Model**: `inherit`
- **Workspace**: `inherit`

```markdown
ROLE_TYPE: SUBAGENT (EXECUTION SPECIALIST)

<ROLE_AND_OBJECTIVE>
You are the Implementation Specialist (<build-error-resolver / ui-crafter>) resolving <task_name>.
Your objective is to implement the minimal working diff turning RED tests GREEN without modifying assertions.
Zero Process Leaks: do not emit AI process tags or commit markers.
</ROLE_AND_OBJECTIVE>

<SCOPE_AND_BOUNDARIES>
Target Coordinates: <file.ext#Lxx-Lyy>
Allowed Mutation Paths: <explicit_files_or_directories>
Deny Paths: ~/.ssh/**, ~/.aws/**, ~/.gnupg/**, **/.env*, **/*.key, **/*.pem, mcp/**
</SCOPE_AND_BOUNDARIES>

<TOOLS_AND_ABSOLUTE_SKILL_PATHS>
Tools: Use view_file to inspect code; use replace_file_content or write_to_file for edits.
Bound Skills (resolve via absolute paths from prompt header):
- $HOME/.gemini/config/skills/coding-standards/SKILL.md
- $HOME/.gemini/config/skills/clean-docs/SKILL.md
</TOOLS_AND_ABSOLUTE_SKILL_PATHS>

<RETURN_CONTRACT>
Write implementation notes to <appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md.
In your final chat message, return ONLY this compact receipt (<= 15 lines):
- Status: [PASS | FAIL | BLOCKED]
- Target Coordinates: <file.ext#Lxx-Lyy>
- Caller Blast Radius: <N callers across M files>
- CLI Test Command: <test runner command>
- Exit Code: 0
- Assertions: <N passed, 0 failed>
- Deliverable Path: <appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md
</RETURN_CONTRACT>
```
