# ADR-0019: Lead Orchestrator Protocol: Insulate Parent Context via Subagents

## Status
Partially Superseded by ADR-0020, ADR-0021, ADR-0027, and ADR-0028 (for orchestrator script consolidation, end-to-end lifecycle runbook, and dual-subagent verification pipeline)

## Date
2026-11-03

## Context
When orchestrating multi-file refactors or complex audits, parent agents that directly read large source files experience context window inflation (adding tens of thousands of tokens of implementation code into the main conversation). This dilutes attention on high-level orchestration, causes skipped safety checks, and increases the likelihood of missing regression errors.

Furthermore, running all tasks through the parent agent mixes project coordination, line-by-line code editing, and verification into a single context. While `everyday-agy` maintained specialized custom agents, operational runbooks lacked an authoritative routing protocol to keep parent session context clean while delegating deep work.

## Decision
1. **Establish the Lead Orchestrator Protocol (`/orchestrator`)**:
   - Create `config/skills/orchestrator/SKILL.md` to govern parent session behavior across multi-file refactors, reviews, and audits.
2. **Insulate Parent Context from Application Source Code**:
   - On multi-file changes (Tier 2 and Tier 3), the parent agent avoids calling `read_file` or `view_file` directly on implementation code (`src/**`, `lib/**`, business logic).
   - The parent agent reads only high-level coordination files (`task_state.md`, ADR files, top-level dependency manifests), git status and diff summaries (`rtk git status --short`, `rtk git diff --stat`), test runner exit codes, and subagent summary receipts.
   - Deep source file inspection, edits, and test writing are delegated to specialized subagents possessing `view_file`, `replace_file_content`, and `write_to_file`.
3. **Classify Tasks by Blast Radius Before Reading Files**:
   - Size tasks using lightweight metadata (`rtk git status --short`, `rtk rg --files`, `rtk rg -c` caller counts):
     - `Tier 0` (trivial, <= 2 files, <= 5 doc lines): Direct parent execution post-checkpoint without subagents.
     - `Tier 1` (small, 1 module): Direct parent TDD post-checkpoint; subagents optional.
     - `Tier 2` (standard, 2-5 files): Parent orchestrates and delegates deep reading and editing to subagents.
     - `Tier 3` (large, > 5 files, architectural): Parent convenes a multi-seat review panel via `teamwork`.
4. **Standardize Subagent Delegation Prompts and Compact Receipts**:
   - Structure subagent prompts using four clear sections: `<ROLE_AND_OBJECTIVE>`, `<SCOPE_AND_BOUNDARIES>`, `<TOOLS_AND_ABSOLUTE_SKILL_PATHS>`, and `<RETURN_CONTRACT>`.
   - Subagents write full scratch reports to `scratch/` and return a compact summary receipt (<= 15 lines) to chat.
5. **Enforce Sequential Execution for Mutating Subagents**:
   - Read-only discovery subagents may run in parallel.
   - Subagents that edit or create files must run sequentially (one at a time) to prevent file-locking conflicts on Windows and ensure clean git checkpoints.
6. **Centralize the 2-Attempt Stop Rule**:
   - The parent tracks a single counter for failed repair attempts across all actions on a task.
   - After two failed attempts, automated editing stops, the checkpoint is restored, and the agent pauses to consult the human operator.
7. **Independently Verify Subagent Deliverables**:
   - The parent independently confirms subagent work using `rtk git status`, `rtk git diff --stat`, and running verification test commands directly. Subagents are barred from committing code.

## Alternatives Considered & Rejected
- **Allowing Parent agents to read code inline on all tasks**: Rejected because loading large codebases into parent context leads to context exhaustion and dropped review requirements.
- **Running modifying subagents in parallel**: Rejected because concurrent writes risk Windows file access collisions (`IOException`) and complicate rollback points.

## Consequences
- **Positive**: Keeps parent conversation context lean by delegating file reading and editing to subagents.
- **Positive**: Sequential mutation prevents file-locking conflicts and ensures atomic rollback.
- **Positive**: Independent test verification by the parent prevents accepting unverified completion claims.
- **Trade-off**: Delegating to subagents sequentially introduces slight latency compared to editing inline, but improves reliability.
