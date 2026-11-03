# Subagent Execution Patterns for Audit-First Workflow

The multi-tiered architecture allows the **Parent Agent** to optionally leverage specialized **Subagents (Specialist Explorer & TDD Guide)**. This keeps context clean, eliminates token bloat during deep audits, and enables safe disciplined execution.

---

## 1. Division of Responsibilities

| Role | Agent / Type | Model | Workspace | Key Responsibilities |
| :--- | :--- | :--- | :--- | :--- |
| **Lead Auditor & Implementer** | Parent Agent | Primary / Inherit | Host CWD | Directs investigation, creates atomic Git checkpoints, implements fixes directly on Tier 0/1; on Tier 2/3 acts strictly as Lead Orchestrator under [`orchestrator`](../../orchestrator/SKILL.md) (ADR-0019) with Context Insulation, runs verification tests, and requests user approval. |
| **Specialist Explorer** | Subagent (`system-architect` / `code-auditor`) | `inherit` (or `flash` per agent manifest) | `inherit` | Rapid read-only discovery, tracing callers with `rtk rg`, dependency tree analysis, and mapping invariant hazards without polluting parent context. Reserve `teamwork` strictly for Tier 3 deliberative Council. |
| **TDD Specialist** | Subagent (`tdd-guide`) | `flash` | `inherit` | Focused test authoring, Red-Green-Refactor cycles, boundary test coverage, and mutation checks before code implementation. |

---

## 2. Subagent Invocation & Communication Protocol

### 2.1 Workspace & Safety Isolation
- **Atomic Git Checkpoints**: Before mutating files or executing complex tests, establish a rollback branch via `New-AuditCheckpoint.ps1 -Task "<task>"`.
- **Workspace Modes**: Default to `inherit` workspace mode to avoid Windows file-locking or worktree `node_modules` duplication. Use session scratch (`<appDataDir>\brain\<conversation-id>\scratch\<task>\`) for intermediate audit artifacts.

### 2.2 Model Selection Invariant (`Model`)
- **Default (`inherit`)**: Inherits parent agent model unless the subagent manifest defines an explicit specialized tier (e.g. `tdd-guide` uses `model: flash` per ADR-0004 & ADR-0012).
- **Dynamic Flash-to-Pro Elevation (`spec-verifier` & `database-reviewer`)**: Keep `model: inherit` in agent manifests so `Claude Sonnet 4.6 Thinking` or `Gemini 4 Argon` parent sessions never downgrade. When the parent session is running on `Gemini 3.8 Flash`, pass `Model: "pro"` dynamically in `invoke_subagent` when invoking `spec-verifier` (paired with mandatory Context7 MCP live docs) or `database-reviewer`.
- **Explicit User Override**: For all other agents, override model tiers at invocation time ONLY if the user explicitly requests it in chat.

### 2.3 Core Execution & Verification Invariants
1. **4-Slot Delegation Contract & Compact Receipts (ADR-0019)**:
   - Parent invokes Subagent via `invoke_subagent` following the 4-slot structure in [`orchestrator`](../../orchestrator/SKILL.md) (`<ROLE_AND_OBJECTIVE>`, `<SCOPE_AND_BOUNDARIES>`, `<TOOLS_AND_ABSOLUTE_SKILL_PATHS>`, `<RETURN_CONTRACT>`).
   - Subagent writes detailed forensic reports to session scratch, returning ONLY a compact receipt (<= 15 lines) to chat to preserve parent context insulation.
2. **Sequential Execution & Single-Writer Mutual Exclusion**:
   - Mutating subagents MUST execute strictly serialized (at most 1 active mutating agent at any time). Read-only explorers may execute in parallel.
3. **Zero Process Leak in Git Commits**:
   - Any commit prepared for or by a subagent must strictly follow humanized Conventional Commits with zero internal AI tags or phase markers.
4. **Independent VCS Receipt Check (`verification-before-completion`)**:
   - When Parent delegates mutations to a subagent (especially `flash`-tier agents like `tdd-guide`), the Parent must never rely on subagent text claims alone.
   - Parent must independently verify `rtk git status --short` and `rtk git diff --stat`, and execute fresh test runs directly from Parent context before accepting delegated work.
5. **Two-Stage Spec-First Review & "Skip Style" Directive**:
   - When delegating diff or code review to a subagent (`code-auditor` or `silent-failure-hunter`), instruct it to evaluate in two stages: (1) line-by-line compliance against the approved plan and requirements, then (2) correctness, security, and edge cases.
   - Explicitly instruct review subagents to skip purely stylistic formatting preferences, subjective aesthetic nits, or unsolicited rewrites. Focus exclusively on defects, spec gaps, and security risks.

### 2.4 Standard Prompt Skeletons (Copy-Paste Templates)

#### Template 1: Specialist Explorer Subagent Prompt Skeleton
- **TypeName**: `code-auditor` (or `system-architect`)
- **Role**: `Specialist Explorer`
- **Model**: `inherit`
- **Workspace**: `inherit`

```markdown
You are the Specialist Explorer analyzing <feature/bug>.
Your objective is read-only discovery to keep the parent context clean.

Tasks:
1. Trace all callers of `<symbol>` using `rtk rg`.
2. Inspect `<path/to/relevant/files>` to identify invariants, boundaries, and edge cases.
3. Check for existing tests covering this area.

Constraints:
- Strictly Read-only: Do NOT modify any files or execute state-changing commands.
- Report findings concisely in chat:
  1. High-level summary and affected caller counts
  2. Invariants / hazards identified
```

#### Template 2: TDD Guide Subagent Prompt Skeleton
- **TypeName**: `tdd-guide`
- **Role**: `TDD Specialist`
- **Model**: `flash`
- **Workspace**: `inherit`

```markdown
You are the TDD Guide establishing failure-first test coverage for <task_name>.

Target scope:
- Test files to add/modify: <test_files>
- Specification: <expected_behavior_and_edge_cases>

Instructions:
1. Write failing test case (RED) verifying the missing behavior.
2. Verify test fails for the expected reason (not syntax/import error).
3. Follow the Iron Law of TDD ("delete means delete").

Return Contract (report back ONLY):
- Test file modified & test command
- Verbatim failure snippet confirming RED state
- Edge cases and mutation checks verified
```
