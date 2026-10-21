---
name: audit-dev-workflow
description: >
  Defensive audit-first development workflow with caller tracing, checkpoints, explicit approvals, and rigorous verification.
  Trigger when the user types /audit-first, /audit-workflow, or says "audit workflow",
  "audit first", "investigate first", "audit this change", "cek dulu sebelum ubah", or when
  preparing a complex refactoring, multi-file edit, or architectural modification.
---

# Audit-First Development Workflow (Operational Runbook)

A defensive, evidence-backed operational runbook ensuring safe, well-investigated changes. Governed by the minimalist principles of [`GEMINI.md`](../../../GEMINI.md).

---

## Step-by-Step Procedure

### Phase 1: Investigation & Blast Radius Analysis
1. **Trace Callers & Invariants**: Inspect callers, dependencies, and state first using `rtk rg` before proposing any edits. Understand the root cause and map affected boundaries.
2. **External API & Library Verification (Context7 MCP)**: When inspecting or altering third-party libraries, APIs, or framework contracts, use Context7 MCP (`resolve-library-id` -> `query-docs`) to verify official APIs and versions instead of relying on pre-training memory.
3. **Optional Delegation for Large Discovery**: For massive codebase exploration or log-heavy caller tracing, Parent may deploy a read-only `research` subagent (`Model: inherit`) to keep context clean. For standard investigations, Parent inspects files directly.
4. **Hazard Assessment**:
   - Test harness mocks (`unittest.mock.patch`, Jest spies, dynamic method patching).
   - Concurrency & threading locks, event loops, and daemon states.
   - Import directions (ensure DAG remains acyclic).
5. **Proposal**: Present findings, root cause, and proposed diff clearly. For non-trivial changes, summarize the plan and blast radius. For minor fixes (typos, 1-line tweaks), propose directly in chat.
6. **Architectural Decision Gate (ADR)**: If the proposed change introduces a new dependency, alters system protocols/topology, modifies data schemas, or establishes security boundaries, explicitly propose an ADR (`<Project>-AI-Context/docs/adr/000x-...md` in Twin-Repo mode, or `docs/adr/000x-...md` in Single-Repo mode per `documentation-and-adrs`).

### Phase 2: Checkpoint & Safety Gate
Establish a rollback point before modifying files:
- **Git Repositories**: Ensure working directory is clean (`rtk git status --short`) or commit a checkpoint commit via `rtk git` when needed:
  ```powershell
  rtk git status --short
  ```
- **Files Outside Git**: Create a backup in session scratch or global scratch:
  ```powershell
  # Preferred: Session scratch (<appDataDir>\brain\<conversation-id>\scratch\<task>\)
  # Fallback:  $HOME\.gemini\antigravity\scratch\<task>\<file>.bak
  Copy-Item <file> "$HOME\.gemini\antigravity\scratch\<task>\<file>.bak"
  ```
- **Explicit User Approval**: Wait for explicit user confirmation in chat before touching files, installing packages, or executing mutating commands.

### Phase 3: Pragmatic Implementation
1. **Direct Execution**: Parent applies approved changes directly using `replace_file_content` or `write_to_file`. Shortest working diff wins.
2. **Optional Subagent Delegation**: For isolated worktree testing or tasks with heavy build/test iterations, Parent may optionally invoke a subagent executor (`Workspace: branch`).
3. **Clean Code Discipline**: Zero unneeded abstractions, zero generic AI comments, and strict preservation of existing unrelated code.

### Phase 4: Local Verification & Review
1. **Unified Diff Inspection**: Review the diffstat and unified diff against the plan. Ensure no accidental changes or debug artifacts were left behind.
2. **Test Suite Verification**: Execute relevant unit/integration tests directly to ensure clean exit code (0). Stop immediately on unexpected test failures.
3. **Five-Axis Sanity Check**: Evaluate diff against Correctness, Security, Performance, Maintainability, and Test Coverage.

### Phase 5: Handoff, Commit & Non-Interactive CI
1. **Handoff Report**: Report a concise summary in chat:
   - Summary of outcome & root cause fix
   - Diffstat and files modified
   - Test verification results
   - ADR link (if an architectural decision was recorded)
   - Next steps / user action items
   *(For major milestones or complex architectural refactors, generate a standalone Antigravity Artifact if structured persistence is needed).*
2. **Repository Commit Discipline**:
   - **Code Repository**: Commit code changes using clean Conventional Commits (`fix(scope): ...`, `feat(scope): ...`) with zero AI buzzwords or process tags.
   - **Context Tracking (Twin-Repo or Single-Repo)**:
     - **Twin-Repo Mode**: Update `task_state.md` (and new ADRs in `docs/adr/`) in the sibling context repo per `sync-task-state`, then commit:
       ```powershell
       rtk git -C "<AiContextPath>" add task_state.md docs/adr/
       rtk git -C "<AiContextPath>" commit -m "chore(context): update active task state and record ADR-xxxx"
       ```
     - **Single-Repo Mode**: If no companion context repo exists, maintain local `docs/adr/` and `task_state.md` (if used) within the primary repo and commit them in clean, atomic steps.
3. **Push & Non-Interactive CI**:
   - Prompt user in chat for explicit push approval.
   - After approval, push and monitor CI non-interactively:
     ```powershell
     $run = gh run list --limit 1 --json databaseId,status,conclusion,url | ConvertFrom-Json
     gh run watch $run.databaseId --exit-status --compact
     ```
   - On CI failure: stop, inspect `gh run view <id> --log-failed`, and propose a fix with new approval.

---

## References & Templates (On-Demand)

- [Prompt Templates](./references/prompt-templates.md): Ready-to-paste atomic prompts for Antigravity native execution.
- [Engineering Pitfalls](./references/pitfalls.md): Agentic traps and Five-Axis logic pitfalls to double-check.
- [Handoff Specification & Guidelines](./references/handoff-spec.md): Practical guidelines for milestone handoffs and change summaries.
- [Subagent Execution Patterns](./references/subagent-patterns.md): Optional patterns for deploying read-only researcher or isolated executor subagents.
- [Clean Docs Standard](./references/clean-docs.md): Plain-spoken repo prose, zero process leaks, and natural commit messages.
- [Public Repo Checklist](./references/public-repo-checklist.md): Standards for public claims, CI gates, and repo hygiene.
