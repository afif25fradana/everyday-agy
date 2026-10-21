---
name: sync-task-state
description: >
  Maintains lightweight active AI context (task_state.md) in Twin-Repo workflows (*-AI-Context).
  Enforces size limits (<= 8 KB, <= 100 lines), tracks code HEAD, prunes completed milestones,
  links gotchas to ADRs, and commits atomically. Use when task_state.md exceeds 8 KB or 100 lines,
  or when prompted with /sync-task-state, "sync task state", or "update task state".
---

# Sync Task State (Twin-Repo Context Hygiene)

Maintains lightweight active AI context in `task_state.md` within companion private context repositories (`<Project>-AI-Context/`).
Enforces strict size limits (target: **<= 8,192 bytes** and **<= 100 lines**) while keeping the prompt context clean, current, and tightly reconciled with the code repository.

---

## 1. Twin-Repo Governance & Boundaries

- **Location**: `task_state.md` lives in the root of the companion context repo (`<Project>-AI-Context\task_state.md` in Twin-Repo mode), or in `.context\task_state.md` / `./task_state.md` (in Single-Repo mode).
- **Size Thresholds**: `task_state.md` must strictly remain `<= 8,192 bytes` (8 KB) and `<= 100 lines`.
- **Git as the Single Source of Truth for History**:
  - Do not maintain a separate `phase_history.md` dumping ground. Past commits and completed task records are already 100% preserved in Git history (`rtk git log`).
  - Major historical research, native GUI deep-dives, or retired planning specs belong in `docs/archive/`.
- **Gotchas vs. ADR Boundary**:
  - **Tactical Gotchas**: Immediate pitfalls, OS quirks, or concurrency locks belong in `## Known Edge Cases` in `task_state.md` (or inline code comments per `antislop-code`).
  - **Architectural Decisions**: Decisions that choose dependencies, protocols, security policies, or data models must be documented in `docs/adr/000x-...md` per `documentation-and-adrs`. Edge cases that inspired an ADR should simply include a link: `[ADR-0004: Thread-safe PDFium](docs/adr/0004-thread-safe-pdfium-rasterization-and-pipeline-guards.md)`.
- **Atomic Git Tracking**: Always stage and commit files explicitly with `rtk git add task_state.md` in the target context repository (or code repo in Single-Repo mode). Never accidentally leak confidential planning notes into public releases.

---

## 2. Step-by-Step Execution Procedure

### Step 1: Pre-Sync Status Check
1. Resolve context repository and check git status:
   ```pwsh
   # Resolves <AiContextPath> if provided, otherwise checks sibling context or current repo:
   $ctx = if ($AiContextPath -and (Test-Path $AiContextPath)) { $AiContextPath } elseif (Test-Path "..\*-AI-Context") { (Resolve-Path "..\*-AI-Context").Path } else { "." }
   rtk git -C $ctx status --porcelain
   ```
   If uncommitted modifications exist outside `task_state.md`, review them before proceeding.
2. Verify code repository HEAD:
   ```pwsh
   $codeRepo = if ($CodeRepoPath -and (Test-Path $CodeRepoPath)) { $CodeRepoPath } else { "." }
   $codeHead = (rtk git -C $codeRepo rev-parse --short HEAD).Trim()
   ```

### Step 2: Code Repo Reconciliation
1. Inspect the commit hash recorded in `## Current Task` of `task_state.md`.
2. Compare it with `$codeHead`. If `task_state.md` points to an older commit or a milestone that has already shipped in code, update `task_state.md` to reference `$codeHead`.

### Step 3: Prune & Condense `task_state.md`
Follow the standardized section layout:

1. **`# Task State`**: Top-level title.
2. **`## Current Task`**:
   - 1–2 sentences summarizing the active task, current objectives, and target commit `$codeHead`.
3. **`## Completed Steps`**:
   - Retain only the most recent **1–2 immediate milestones** relevant to current work.
   - **Pruning rule**: Remove older, finished stages. They are already permanently preserved in the code repo's `rtk git log` and releases.
4. **`## Deferred / Next Milestone`**:
   - Bulleted list of immediate backlog items or future version tasks.
5. **`## Known Edge Cases`**:
   - 1–2 line summaries of active edge cases, gotchas, or platform quirks.
   - If an edge case is backed by an ADR, add a relative link to `docs/adr/000x-....md`.
   - Remove resolved edge cases that are covered by regression tests.

### Step 4: Verification Gate (Size & Line Limits)
Verify that `task_state.md` meets the constraints directly in pwsh:
```pwsh
$taskFile = if (Test-Path "$ctx\task_state.md") { "$ctx\task_state.md" } else { ".\task_state.md" }
$item = Get-Item $taskFile
$lines = (Get-Content $taskFile).Count
if ($item.Length -gt 8192 -or $lines -gt 100) {
    Write-Error "task_state.md exceeds limits: $($item.Length) bytes (max 8192), $lines lines (max 100)."
} else {
    Write-Host "PASS: task_state.md is $($item.Length) bytes and $lines lines." -ForegroundColor Green
}
```

### Step 5: Atomic Git Commit
Commit the pruned state in the target repository:
```pwsh
rtk git -C $ctx add $taskFile
rtk git -C $ctx commit -m "chore(context): update active task state"
```

---

## 3. Subagent Execution Report Contract

When invoked as a subagent for task state synchronization, return only:
- Pre-sync vs Post-sync byte size and line count of `task_state.md`.
- Code repo HEAD SHA referenced.
- Number of active edge cases retained.
- Commit hash created in the AI-Context repository.
