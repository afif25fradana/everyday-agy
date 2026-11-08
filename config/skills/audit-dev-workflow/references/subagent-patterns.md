# Subagent Execution Patterns for Audit-First Workflow

The multi-tiered architecture allows the **Parent Agent** to orchestrate specialized **Subagents** across the 11-agent fleet. This keeps parent context clean, eliminates token bloat during deep audits, and enables safe, disciplined execution. Governed by [`orchestrator`](../../orchestrator/SKILL.md) and [`ADR-0018`](../../../../docs/adr/0018-fleet-parity-and-deployment-path-symmetry.md).

---

## 1. Division of Responsibilities (11-Agent Fleet)

| Role / Domain | Agent (`TypeName`) | Default Model | Workspace | Key Responsibilities |
| :--- | :--- | :--- | :--- | :--- |
| **Lead Orchestrator** | Parent Agent | Primary | Host CWD | Directs zero-read triage, manages checkpoints, implements fixes directly on Tier 0/1; on Tier 2/3 governs fleet under [`orchestrator`](../../orchestrator/SKILL.md) with Context Insulation, runs CLI verification tests, and handles user approval gates. |
| **Architecture & Topology** | `system-architect` | `inherit` | `inherit` | Contract-first API design, module boundaries, acyclic DAG graphs, zero-downtime refactors, and Nygard ADR / `spec-kit` specifications. Read-only explorer prior to Gate 1. |
| **Security & Code Health** | `code-auditor` | `inherit` | `inherit` | Whole-repo health, security attack surface, injection/auth boundaries, secret scanner hygiene, and anti-slop code hygiene. Read-only explorer or diff verifier. |
| **Reliability & Silent Failures** | `silent-failure-hunter` | `inherit` | `inherit` | Audits swallowed exceptions, masking fallbacks (`.catch(() => [])`), resource leaks, unhandled edge cases, and timeout drops. Read-only auditor. |
| **Test Integrity & TDD** | `tdd-guide` | `flash` (`inherit` on complex Tier 2 logic) | `inherit` | Test-Driven Development (Red-Green-Refactor), boundary testing, mutation checks, and anti-mock cheating verification. Mutating subagent (sequential execution). |
| **Persistence & Schema** | `database-reviewer` | `inherit` (`pro` on Flash) | `inherit` | SQL schema migrations, indexing strategies, N+1 query traps, zero-downtime expand/contract patterns, and foreign key integrity. Read-only reviewer. |
| **Frontend UX & Primitives** | `ui-crafter` | `flash` | `inherit` | Web platform primitives, WCAG 2.2 AA accessibility, layout shifts, dark mode, responsive styling, and anti-slop UI design. Mutating subagent (sequential execution). |
| **Documentation & ADRs** | `docs-architect` | `flash` (`inherit` on deep ADR synthesis) | `inherit` | Architecture Decision Records (ADRs), progressive disclosure sub-docs, anti-slop copywriting, and AI context synchronization (`task_state.md`). Mutating subagent (sequential execution). |
| **Type Safety & Compilation** | `build-error-resolver` | `flash` | `inherit` | TypeScript/compiler error resolution, type soundness, generic constraints, and strict compilation hygiene via `replace_file_content` (no `write_to_file`). Mutating subagent (sequential execution). |
| **Dependency & CI Maintenance** | `maintenance-bot` | `flash` | `inherit` | Package dependency hygiene, CVE vulnerability mitigation, Dependabot triage, and CI workflow diagnosis. Mutating subagent (sequential execution). |
| **Official Spec Verifier** | `spec-verifier` | `inherit` (`pro` on Flash) | `inherit` | Authoritative vendor spec verification via Context7 MCP (`resolve-library-id` -> `query-docs`) and [`deep-web-research`](../../deep-web-research/SKILL.md) before implementing third-party APIs. Read-only verifier. |
| **Software Localization** | `l10n-humanizer` | `flash` | `inherit` | Software localization (L10n), UI translation, Microsoft Indonesian style guide consistency, UX microcopy conciseness, and XML/JSON escaping. Mutating subagent (sequential execution). |

---

## 2. Subagent Invocation & Communication Protocol

### 2.1 Workspace & Safety Isolation
- **Atomic Git Checkpoints**: Before mutating files or authoring RED tests on Tier 1/2/3, establish a rollback branch via `New-AuditCheckpoint.ps1 -Task "<task>"`.
- **Workspace Modes**: Default to `inherit` workspace mode to avoid Windows file-locking or worktree `node_modules` duplication. Use session scratch (`<appDataDir>\brain\<conversation-id>\scratch\<task>\`) for intermediate audit artifacts.

### 2.2 Model Selection Invariant (`Model`)
- **Manifest Defaults (`inherit` vs `flash`)**: The 5 cognitive/read-only reasoning agents (`system-architect`, `code-auditor`, `silent-failure-hunter`, `database-reviewer`, `spec-verifier`) default to `model: inherit`, while the 6 tactical execution agents (`tdd-guide`, `build-error-resolver`, `ui-crafter`, `docs-architect`, `maintenance-bot`, `l10n-humanizer`) default to `model: flash` per ADR-0004 & ADR-0012.
- **Dynamic Elevation Rules**:
  - When the parent session runs on `Gemini 3.8 Flash`, pass `Model: "pro"` dynamically in `invoke_subagent` when invoking `spec-verifier` or `database-reviewer` (ADR-0015).
  - For high-stakes multi-system ADR synthesis on `docs-architect` or complex multi-file Tier 2 business logic implementation on `tdd-guide`, the Parent Agent may dynamically elevate invocation via `Model: "inherit"` (or `Model: "pro"`).

### 2.3 Core Execution & Verification Invariants
1. **4-Slot Delegation Contract & Compact Receipts**: Follow the normative 4-slot structure in [`orchestrator/SKILL.md#3-the-4-slot-delegation-contract-ssot`](../../orchestrator/SKILL.md). Subagents write detailed forensic reports to `<appDataDir>\brain\<conversation-id>\scratch\<task>\` (except `build-error-resolver`, which performs in-place `replace_file_content` edits only) and return ONLY a compact $\le 15$-line receipt to chat.
2. **Sequential Execution & Single-Writer Mutual Exclusion**: Mutating subagents execute strictly serialized (at most 1 active mutating agent at any time). Read-only explorers may execute in parallel.
3. **Pre-Mutation Syntax Interception**: Mutating subagents run fast syntax checks (`orchestrator/SKILL.md#17-pre-mutation-syntax-interception-swe-agent-fast-syntax-gate--ssot`) immediately upon editing files to fix syntax typos in-turn without incrementing `global_attempt_counter`.
4. **Independent VCS Receipt Check (`verification-before-completion`)**: Parent never relies on subagent text claims alone; Parent independently verifies `rtk git status --short`, `rtk git diff --stat`, and fresh CLI test runs before Gate 2.
5. **Two-Stage Spec-First Review & "Skip Style" Directive**: Review subagents (`code-auditor` or `silent-failure-hunter`) evaluate (1) line-by-line spec compliance, then (2) correctness, security, and edge cases, skipping purely stylistic formatting preferences.

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
Settled Findings: <list of established baseline non-issues / accepted trade-offs immune to re-litigation, or NONE>
Deny Paths: ~/.ssh/**, ~/.aws/**, ~/.gnupg/**, **/.env*, **/*.key, **/*.pem, mcp/**
</SCOPE_AND_BOUNDARIES>

<TOOLS_AND_ABSOLUTE_SKILL_PATHS>
Tools: Use view_file to inspect code; rtk rg for caller searches; run_command for read-only checks.
Bound Skills (resolve exact OS absolute paths from prompt header; never pass literal ~ or $HOME to view_file):
- C:\Users\<User>\.gemini\config\skills\audit-context-building\SKILL.md
- C:\Users\<User>\.gemini\config\skills\clean-docs\SKILL.md
</TOOLS_AND_ABSOLUTE_SKILL_PATHS>

<RETURN_CONTRACT>
Write detailed forensic reports to <appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md.
In your final chat message, return ONLY this compact receipt (<= 15 lines):
- Status: [PASS | FAIL | BLOCKED | NOT RUN]
- Target Coordinates: <file.ext#Lxx-Lyy>
- Caller Blast Radius: <N callers across M files>
- CLI Test Command: <command executed or N/A>
- Exit Code: <0 or non-zero>
- Assertions: <N passed, 0 failed or N/A>
- Deliverable Path: <appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md
</RETURN_CONTRACT>
```

#### Template 2: TDD Guide Subagent Prompt Skeleton (Post-Gate 1 & Post-Checkpoint)
- **TypeName**: `tdd-guide`
- **Role**: `TDD Specialist`
- **Model**: `flash` (or `inherit` for complex multi-file logic)
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
Settled Findings: <list of established baseline non-issues / accepted trade-offs immune to re-litigation, or NONE>
Deny Paths: ~/.ssh/**, ~/.aws/**, ~/.gnupg/**, **/.env*, **/*.key, **/*.pem, mcp/**
</SCOPE_AND_BOUNDARIES>

<TOOLS_AND_ABSOLUTE_SKILL_PATHS>
Tools: Use view_file to inspect existing tests; use write_to_file or replace_file_content to author tests.
Bound Skills (resolve exact OS absolute paths from prompt header; never pass literal ~ or $HOME to view_file):
- C:\Users\<User>\.gemini\config\skills\coding-standards\SKILL.md
</TOOLS_AND_ABSOLUTE_SKILL_PATHS>

<RETURN_CONTRACT>
Write detailed test logs to <appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md.
In your final chat message, return ONLY this compact receipt (<= 15 lines):
- Status: [PASS | FAIL | BLOCKED | NOT RUN]
- Target Coordinates: <test_file.ext#Lxx-Lyy>
- Caller Blast Radius: <N callers across M files>
- CLI Test Command: <test runner command>
- Exit Code: <non-zero confirming RED failure>
- Assertions: <0 passed, 1 failed (expected failure)>
- Deliverable Path: <appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md
</RETURN_CONTRACT>
```

#### Template 3: Mutating Implementation Specialist Prompt Skeleton
- **TypeName**: `tdd-guide` (or `ui-crafter` / `build-error-resolver` / `docs-architect` / `l10n-humanizer` / `maintenance-bot`)
- **Role**: `Implementation Specialist`
- **Model**: `flash` (or `inherit` on complex Tier 2 logic)
- **Workspace**: `inherit`

```markdown
ROLE_TYPE: SUBAGENT (EXECUTION SPECIALIST)

<ROLE_AND_OBJECTIVE>
You are the Implementation Specialist (<tdd-guide / ui-crafter / build-error-resolver / docs-architect / l10n-humanizer / maintenance-bot>) resolving <task_name>.
Your objective is to implement the minimal working diff turning RED tests GREEN without modifying assertions.
Zero Process Leaks: do not emit AI process tags or commit markers.
</ROLE_AND_OBJECTIVE>

<SCOPE_AND_BOUNDARIES>
Target Coordinates: <file.ext#Lxx-Lyy>
Allowed Mutation Paths: <explicit_files_or_directories>
Settled Findings: <list of established baseline non-issues / accepted trade-offs immune to re-litigation, or NONE>
Deny Paths: ~/.ssh/**, ~/.aws/**, ~/.gnupg/**, **/.env*, **/*.key, **/*.pem, mcp/**
</SCOPE_AND_BOUNDARIES>

<TOOLS_AND_ABSOLUTE_SKILL_PATHS>
Tools: Use view_file to inspect code; use replace_file_content (or write_to_file if granted in agent manifest) for edits.
Bound Skills (resolve exact OS absolute paths from prompt header; never pass literal ~ or $HOME to view_file):
- C:\Users\<User>\.gemini\config\skills\coding-standards\SKILL.md
- C:\Users\<User>\.gemini\config\skills\clean-docs\SKILL.md
</TOOLS_AND_ABSOLUTE_SKILL_PATHS>

<RETURN_CONTRACT>
Write implementation notes to <appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md (or omit file creation if running as build-error-resolver).
In your final chat message, return ONLY this compact receipt (<= 15 lines):
- Status: [PASS | FAIL | BLOCKED | NOT RUN]
- Target Coordinates: <file.ext#Lxx-Lyy>
- Caller Blast Radius: <N callers across M files>
- CLI Test Command: <test runner command>
- Exit Code: 0
- Assertions: <N passed, 0 failed>
- Deliverable Path: <appDataDir>\brain\<conversation-id>\scratch\<task>\<file>.md (or N/A for build-error-resolver)
</RETURN_CONTRACT>
```
