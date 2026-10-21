# Subagent Execution Patterns for Audit-First Workflow

The multi-tiered architecture allows the **Parent Agent** to optionally leverage specialized **Subagents (Researcher & Isolated Executor)**. This keeps context clean, eliminates token bloat during deep audits, and enables safe isolated prototyping.

---

## 1. Division of Responsibilities

| Role | Agent / Type | Model | Workspace | Key Responsibilities |
| :--- | :--- | :--- | :--- | :--- |
| **Lead Auditor & Implementer** | Parent Agent | Primary / Inherit | Host CWD | Directs investigation, creates checkpoints, implements fixes directly (shortest path wins), runs verification tests, and requests user approval. Subagent delegation is optional on-demand. |
| **Codebase Researcher** | Subagent (`research`) | `inherit` | `inherit` | Rapid read-only discovery, tracing callers with `rtk rg`, dependency tree analysis, and mapping invariant hazards without polluting parent context. |
| **Isolated Executor** | Subagent (`self`) | `inherit` | `branch` (or `inherit`) | Optional executor for high-risk changes requiring isolated Git worktree testing before merging to main workspace. |

---

## 2. Subagent Invocation & Communication Protocol

### 2.1 Workspace Isolation Modes (`Workspace`)
- `branch`: Creates an isolated Git worktree branched from the parent. The main repository stays completely clean until changes and test suites pass verification. Use for non-trivial edits, refactors, and risky multi-file changes.
- `inherit`: Operates directly in the current workspace. Use for simple in-place edits, fast configuration tweaks, or read-only research.
- `share`: Shared directory sharing the parent's repository storage for multi-subagent coordination.

### 2.2 Model Selection Invariant (`Model`)
- **Default (`inherit`)**: Always use `inherit` to inherit the parent agent's model configuration. Antigravity system rules mandate never switching model tiers autonomously based on task complexity.
- **Explicit User Request Only**: Use alternative tiers (`flash` / `flash_lite` for lightweight read-only sweeps or `pro` for heavy architectural refactoring) ONLY if the user explicitly requests it in chat.

### 2.3 Core Execution & Verification Invariants
1. **Focused Scope & Concise Contracts**:
   - Parent invokes Subagent via `invoke_subagent` with clear, actionable scope.
   - Subagent reports back only structured receipts and findings—never raw terminal dumps in chat.
2. **Sequential Execution for State & Core Modules**:
   - When modifying tightly coupled components or monolithic state files, avoid concurrent subagents to prevent file locks and race conditions.
3. **Zero Process Leak in Git Commits**:
   - Any commit prepared for or by a subagent must strictly follow humanized Conventional Commits with zero internal AI tags or phase markers.

### 2.4 Standard Prompt Skeletons (Copy-Paste Templates)

#### Template 1: Research Subagent Prompt Skeleton
- **TypeName**: `research`
- **Role**: `Codebase Researcher`
- **Model**: `inherit`
- **Workspace**: `inherit`

```markdown
You are the Codebase Researcher exploring <feature/bug>.
Your objective is read-only discovery to keep the parent context clean.

Tasks:
1. Trace all callers of `<symbol>` using `rtk rg`.
2. Inspect `<path/to/relevant/files>` to identify invariants and edge cases.
3. Check for existing tests covering this area.

Constraints:
- Read-only: Do NOT modify any files or execute state-changing commands.
- Report findings concisely in chat:
  1. High-level summary and affected caller counts
  2. Invariants / hazards identified
```

#### Template 2: Isolated Executor Subagent Prompt Skeleton
- **TypeName**: `self`
- **Role**: `Isolated Executor`
- **Model**: `inherit`
- **Workspace**: `branch`

```markdown
You are the Isolated Executor implementing <task_name> in a branched workspace.

Target scope:
- Files to modify: <files>
- Task details: <details>

Instructions:
1. Apply the approved changes to the target files.
2. Run test suites: `<test command>`.
3. If tests fail, diagnose and fix within scope.

Return Contract (report back ONLY):
- Files changed: <list>
- Test run results & exit codes
- Unified diff summary
```
