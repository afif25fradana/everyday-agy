---
name: audit-dev-workflow
description: >
  Defensive audit-first development workflow with caller tracing, checkpoints, explicit approvals, and rigorous verification.
  Trigger when the user types /audit-dev-workflow, /audit-first, /audit-workflow, or says "audit workflow",
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
3. **Optional Delegation for Large Discovery**: For massive codebase exploration or log-heavy caller tracing, Parent may deploy a read-only `research` subagent (`Model: inherit`) to keep context clean. For standard investigations, Parent inspects files directly using `read_file`.
4. **Repro-First Failing Test (SWE-Agent Pattern)**: For bug fixes or logic defects, create a minimal reproducible test script or failing test case first (RED) before writing any solution code. Confirm that the test reliably captures the failure mode before moving to execution.
5. **Hazard Assessment**:
   - Test harness mocks (`unittest.mock.patch`, Jest spies, dynamic method patching).
   - Concurrency & threading locks, event loops, and daemon states.
   - Import directions (ensure DAG remains acyclic).
6. **Proposal & Gate 1 Packaging**: Present findings, root cause, exact target coordinates (`file.ext#Lxx-Lyy`), target function signatures, upstream caller context / consumer blast radius (via `rtk rg`), and the minimal implementation plan. For non-trivial changes, package the proposal under `# Review Request: Gate 1 (Pre-Execution Proposal)`. When generating proposals in a UserFacing Artifact, set `ArtifactMetadata.RequestFeedback: true` to provide the native one-click "Proceed" approval button in the UI. Qualifying Tier 0 changes (typos, docs, metadata; <= 2 files, <= 3 lines executable or <= 5 lines non-executable, zero logic mutation) bypass Gate 1 ceremony and proceed directly upon simple chat approval.
7. **Architectural Decision Gate (ADR)**: If the proposed change introduces a new dependency, alters system protocols/topology, modifies data schemas, or establishes security boundaries, explicitly propose an ADR (`<Project>-AI-Context/docs/adr/000x-...md` in Twin-Repo mode, or `docs/adr/000x-...md` in Single-Repo mode per `documentation-and-adrs`).

### Phase 2: Checkpoint & Safety Gate
Establish a rollback point before modifying files:
- **Git Repositories**: Ensure working directory is clean (`rtk git status --short`) or create a checkpoint via helper script:
  ```powershell
  powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.gemini\config\skills\audit-dev-workflow\scripts\New-AuditCheckpoint.ps1" -Task "<task_name>"
  ```
- **Files Outside Git**: Create a backup in session scratch or global scratch:
  ```powershell
  # Preferred: Session scratch (<appDataDir>\brain\<conversation-id>\scratch\<task>\)
  # Fallback helper:
  powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.gemini\config\skills\audit-dev-workflow\scripts\New-AuditCheckpoint.ps1" -Task "<task_name>" -FilePath "<target_file>"
  ```
- **Automated Rollback**: If unexpected failures occur during Phase 4, restore cleanly with:
  ```powershell
  powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.gemini\config\skills\audit-dev-workflow\scripts\Restore-AuditCheckpoint.ps1" -Task "<task_name>" [-FilePath "<target_file>"]
  ```
- **Explicit Approval & Gate 1 Return Loop**:
  - Always obtain explicit review confirmation before touching files, installing packages, or executing mutating commands.
  - Supports two review input modes:
    - **Mode A (Direct Human Operator Chat)**: Explicit conversational confirmation from the user in chat (e.g., `"approve"`, `"acc"`, `"lanjut"`, `"gas"`, `"LGTM"`) or clicking the UI "Proceed" button immediately satisfies Gate 1 (`APPROVE`). Conversational questions or critiques are addressed directly without ceremonial overhead.
    - **Mode B (Structured or Pasted External AI Review)**: Ingest structured review blocks matching `# Review Feedback...` or `# Technical Review...` (from Claude, Gemini Web, or pasted external auditors):
      - On `APPROVE`: Proceed directly to Phase 3 implementation.
      - On `QUESTIONS FOR IMPLEMENTER`: Run `rtk rg "<symbol>"` and return exact file coordinates (`file.ext#Lxx-Lyy`) and verbatim definitions; await reviewer resolution.
      - On `REJECT`: Stop immediately, evaluate reviewer feedback, and return to Phase 1 investigation or revise proposal.
  - Qualifying Tier 0 changes bypass Gate 1 review ceremony and proceed directly to execution upon user approval.

### Phase 3: Pragmatic Implementation
1. **Direct Execution**: Parent applies approved changes directly using `edit_file` or `write_file` (or `replace_file_content` / `write_to_file` when delegated to Subagents). Shortest working diff wins.
2. **Optional Subagent Delegation**: For isolated worktree testing or tasks with heavy build/test iterations, Parent may optionally invoke a subagent executor (`Workspace: branch`) or delegate test writing to `tdd-guide`.
3. **Clean Code Discipline**: Zero unneeded abstractions, zero generic AI comments, strict preservation of existing defensive logic (timeouts, retries, null checks, calibrated thresholds), and bracketed `<...>` placeholders for secret scanner hygiene.

### Phase 4: Local Verification & Review
1. **Unified Diff Inspection**: Review the diffstat and unified diff against the plan. Ensure no accidental changes or debug artifacts were left behind.
2. **Test Suite Verification**:
   - **Repos with Test Harnesses**: Execute relevant unit/integration tests directly to capture: (a) exact CLI test command executed, (b) terminal exit code (0), and (c) verbatim assertion stdout/stderr snippet showing passed checks (turning the Phase 1 RED test into GREEN). Stop immediately on unexpected test failures.
   - **Testless Repositories**: For repositories lacking automated test suites (documentation, infra/devops configs, initial prototypes), substitute with static verification: syntax checking (e.g. `python -m py_compile`, `rtk npx eslint`), build checks, or dry-run execution. Explicitly annotate Gate 2 with `[TEST HARNESS: NONE — STATIC/BUILD EVIDENCE PROVIDED]`.
3. **Five-Axis Pre-Flight Rubric**:
   - **Axis 1 (Correctness & Invariants)**: Boundary checks, state transitions, loop invariants, type safety, caller regressions, async/await/lock ordering, and zero dropped defensive logic (never silently strip timeouts, retries, null checks, or calibrated thresholds).
   - **Axis 2 (Security & Attack Surface)**: Input sanitization, auth boundaries, injection/deserialization safety, cross-module blast radius, and Secret Scanner Hygiene (bracketed `<TOKEN>`, `<API_KEY>` placeholders; zero raw sample credentials exceeding 12-16 chars).
   - **Axis 3 (Over-Engineering / Ponytail & Anti-Slop)**: Shortest working diff wins. Reject speculative abstractions, generic wrappers, and single-impl interfaces. Comment hygiene: strip generic AI narrative comments (`// Update state`); keep comments strictly for non-obvious *why* rationale, OS workarounds, or protocol quirks. Zero corporate/academic fluff in docstrings.
   - **Axis 4 (Edge Cases & Silent Failures)**: No swallowed exceptions (bare `catch {}`), no masking defaults (`.catch(() => [])`), no silent `null` returns on critical paths, no resource leaks (unclosed streams, orphaned subprocesses, lingering event listeners, unreleased locks), and explicit boundary and timeout checks (`0`, `null`, `undefined`, empty collections, negative numbers, timeouts).
   - **Axis 5 (Test Integrity & Fault Injection)**: No mock-cheating (no mocks replacing the unit under test; no asserting only `mock.called == True` without verifying state/data/return values). Both happy paths and negative paths must be verified. When in doubt, perform a temporary fault injection (flip a conditional or invalidate an input) to verify that the test fails before finalizing.

### Phase 5: Gate 2 Review, Commit & Non-Interactive CI
1. **Gate Packaging & Reviewer Payloads**:
   - **Tier 0 (Trivial Fast-Path)**: Header `[TRIVIAL REVIEW]`. Allowed ONLY if modifying <= 2 files AND <= 3 lines of executable code (or <= 5 lines of non-executable documentation/comments), with ZERO changes to business logic, conditionals, loops, state transitions, error handlers, public API signatures, schemas, or security boundaries. Must include diffstat and full inline unified diff (`+`/`-`) to verify compliance.
   - **Gate 2 (Post-Execution Handoff & Diff)**: Header `# Review Request: Gate 2 (Post-Execution Handoff & Diff)`.
     - High-level diffstat & full unified diff (`+`/`-`). If > 800 lines, chunk by module starting with diffstat + core domain logic first.
     - Mandatory Real Test Evidence: (1) exact CLI command, (2) terminal exit code (0), and (3) verbatim snippet of stdout/stderr showing passed assertions (with mock tokens scrubbed to `<TEST_HASH_SANITIZED>` or `<MOCK_TOKEN>`). If repo is testless, supply static/build evidence under `[TEST HARNESS: NONE]`.
2. **Reviewer Return Loop Handling (Gate 2)**:
   - Before `git commit` or `git push`, evaluate the review verdict via two modes:
     - **Mode A (Direct Human Operator Chat)**: Explicit conversational confirmation in chat (e.g., `"approve"`, `"acc"`, `"lanjut"`, `"gas"`, `"LGTM"`) immediately satisfies Gate 2 (`APPROVE`). Natural-language critiques or questions are resolved directly before commit.
     - **Mode B (Structured or Pasted External AI Review)**: Ingest `# Review Feedback...` or `# Technical Review...` (from Claude, Gemini Web, or pasted external audit):
       - On `APPROVE` or `APPROVE (Trivial: <rationale>)`: Proceed to repository commit discipline.
       - On `QUESTIONS FOR IMPLEMENTER`: Run `rtk rg "<symbol>"` and return exact file coordinates (`file.ext#Lxx-Lyy`) and verbatim definitions.
       - On `REJECT`: Stop, evaluate reviewer feedback, and return to Phase 1 investigation or Phase 3 implementation.
3. **Repository Commit Discipline**:
   - Report a concise summary in chat (1-2 lines with diffstat / action items). For major milestones, an Antigravity UserFacing Artifact can be generated for structured persistence.
   - **Code Repository**: Commit code changes using clean Conventional Commits (`fix(scope): ...`, `feat(scope): ...`) with zero AI buzzwords or process tags.
   - **Context Tracking (Twin-Repo or Single-Repo)**:
     - **Twin-Repo Mode**: Update `task_state.md` (and new ADRs in `docs/adr/`) in the sibling context repo per `sync-task-state`, then commit:
       ```powershell
       rtk git -C "<AiContextPath>" add task_state.md docs/adr/
       rtk git -C "<AiContextPath>" commit -m "chore(context): update active task state and record ADR-xxxx"
       ```
     - **Single-Repo Mode**: If no companion context repo exists, maintain local `docs/adr/` and `task_state.md` (if used) within the primary repo and commit them in clean, atomic steps.
4. **Push & Non-Interactive CI**:
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
