# Prompt Templates for Antigravity (Gemini 3.8 Flash Native)

All templates are designed to be pasted directly into Antigravity sessions. Powered by Gemini 3.8 Flash (High), these prompts leverage native high reasoning, thinking tokens, and direct tool calling while upholding strict defensive guardrails (investigate first, checkpoints, explicit approval, and zero slop).

---

## 1. Phase 1: Diagnostic Audit (Read-Only Investigation)

Use when investigating a bug, auditing a module/config, or checking blast radius before proposing changes.

```markdown
# Phase
Phase 1: Diagnostic Audit (Read-Only - zero file edits)

# Scope
[exact files, directories, or config files]

# Context / Symptom
[concise technical description of the bug, behavior, or audit target]

# Questions to Answer in Findings (Answer Q1-Q3 sequentially)
1. **Q1 (Root Cause & Invariant Analysis)**: Inspect `[file/function]`. Trace the logic flow, identify the root cause, and cite relevant code coordinates `[file.ext#L10-L20]`.
2. **Q2 (Caller & Blast Radius Sweep)**: Trace callers across the repo using `rtk rg` and map affected boundaries, tests, and consumers.
3. **Q3 (Edge Cases & Minimal Fix Direction)**: Compare against `[working path / invariant]`, evaluate trade-offs, and outline the minimal fix per `ponytail` (shortest working diff, reuse existing helpers).

# Stop Condition
Stop after presenting findings and proposed direction. Do not modify any repository files.
```

---

## 2. Phase 2: Implementation Proposal & Diff Preview

Use when the root cause is confirmed and you want the agent to prepare the exact plan and diff preview before execution.

```markdown
# Phase
Phase 2: Implementation Proposal (Read-Only - awaiting approval)

# Approved Direction
Implement Option `[X]`: `[1-2 sentence summary of the chosen minimal approach]`.

# Scope Lock
Allowed files:
- `[file 1]`
- `[file 2]`

# Requirements
1. **Minimalist Diff (`ponytail`)**: Reuse existing helpers/types; no unrequested abstractions or out-of-scope cleanups.
2. **Code Hygiene (`antislop-code`)**: Zero narrative comments; preserve non-obvious *why* explanations and known gotchas.
3. **Proposed Diff Preview**: Present the exact unified diff for review.

# Stop Condition
Stop after presenting the proposed diff. Await explicit user approval before modifying files.
```

---

## 3. Phase 3–5: Approve, Execute & Verify

Use when approving a verified proposal to execute changes, run tests, and complete verification.

```markdown
# Phase
Phase 3-5: Execution, Verification & Local Review

# Explicit Approval
Approved to execute the following items within the allowed scope:
1. `[Specific change #1 in exact file]`
2. `[Specific change #2 in exact file]`

# Allowed Scope
- `[exact file path(s)]`

# Execution & Verification Focus
1. Ensure git working tree is clean (`rtk git status --short`) or create a checkpoint commit via `rtk git`.
2. Apply changes directly using shortest working diff.
3. Execute relevant unit/integration test suites to confirm clean exit code (0).
4. Run Five-Axis sanity check (Correctness, Security, Performance, Maintainability, Tests).
5. Report concise outcome: diffstat, test results, and next steps.

# Stop Condition
Stop immediately on any unexpected test failure or build error.
```

---

## 4. Global Config or Skill Patch (`GEMINI.md`, `.gemini\`, Skills)

Use when updating Antigravity's own rules, global config, or installed skills. Never dictate line numbers, block names, or exact wording from memory—have the agent inspect its live file first.

```markdown
# Phase
Phase 1-2: Config / Skill Inspection & Minimal Patch Proposal (Read-Only)

# Goal & Context
Refine `[target file/skill, e.g., GEMINI.md or skill X]` to address `[concrete problem or behavior observed]`.

# Questions to Answer Before Editing
1. **Q1 (Live File Inspection)**: Read the current `[target file]` via `view_file`. Which existing section or rule already covers or overlaps with this concept?
2. **Q2 (Collision & Redundancy Check)**: Verify that adding or adjusting this rule does not contradict `GEMINI.md` or duplicate an existing instruction.
3. **Q3 (Minimal Patch Proposal)**: Propose the smallest possible patch (updating existing lines in place rather than rewriting the file) and show the proposed unified diff.

# Stop Condition
Stop after presenting findings and proposed diff. Await explicit user approval before applying changes.
```

---

## 5. Bootstrap & Context Sync (`architecture.md` / `sync-task-state`)

Use when opening a new chat on an existing codebase or rotating stale `*-AI-Context` files.

```markdown
# Phase
Phase 1: Codebase Context Bootstrap / State Sync

# Task
Scan the codebase and synchronize the project context files in `[*-AI-Context path]`:

1. **`architecture.md`**: Document high-level component topology, module boundaries, established conventions, and link to ADRs (`documentation-and-adrs`). Keep index file lean (target <= 3-5 KB).
2. **`task_state.md` (`sync-task-state`)**:
   - Ensure `task_state.md` is strictly `<= 8 KB` and `<= 100 lines` (active scope, immediate next steps, current Git HEAD, and pointers to ADRs).
   - Prune older completed milestones, relying on `rtk git log` for historical commit records. Zero graveyard files (`phase_history.md` retired).

# Stop Condition
Stop and report context synchronization status once files are verified.
```
