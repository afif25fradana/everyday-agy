---
name: audit-dev-workflow
description: Defensive audit-first dev workflow (/audit-dev-workflow): caller tracing, checkpoints, approval gates, and verification.
---

# Audit-First Development Workflow (Operational Runbook)

A defensive, evidence-backed operational runbook ensuring safe, well-investigated changes. Governed by `config/GEMINI.md` (`~/.gemini/GEMINI.md`) and [`orchestrator`](../orchestrator/SKILL.md).

> [!TIP]
> **Workflow Routing**: `audit-dev-workflow` is the operational runbook for all changes (Tier 0–3). For Tier 2/3 multi-file changes, Parent Agent activates `orchestrator` for context insulation and subagent fleet governance.

---

## Step-by-Step Procedure

### Step 0: Blast-Radius Size-Tiered Pipeline Routing (ADR-0009, ADR-0015, ADR-0019)
Classify the incoming task using the **Zero-Read Triage Gate** in [`orchestrator/SKILL.md#12-zero-read-triage-gate-step-0-blast-radius-sizing--ssot`](../orchestrator/SKILL.md):
- **`trivial` (Tier 0)**: $\le 2$ files, $\le 3$ exec or $\le 5$ doc/comment lines, zero logic/state/schema mutation. Checkpoint $\rightarrow$ patch $\rightarrow$ verify $\rightarrow$ pause at `[TRIVIAL REVIEW]` before commit.
- **`small` (Tier 1)**: Contained single-module bugfix/enhancement. Investigation $\rightarrow$ Checkpoint (`New-AuditCheckpoint.ps1`) $\rightarrow$ Failure-First TDD (RED $\rightarrow$ GREEN) $\rightarrow$ 5-Axis verification $\rightarrow$ pause at Gate 2 (`gate2_handoff.md`) before commit.
- **`standard` (Tier 2)**: Multi-file refactor or multi-component change (2–5 files). Enforce [`orchestrator`](../orchestrator/SKILL.md) Parent Context Insulation: read-only explorer (`system-architect` / `code-auditor`) $\rightarrow$ Gate 1 approval (`gate1_proposal.md`) $\rightarrow$ Checkpoint (`New-AuditCheckpoint.ps1`) $\rightarrow$ `tdd-guide` RED test $\rightarrow$ implementer GREEN fix $\rightarrow$ `code-auditor` diff review $\rightarrow$ Gate 2 (`gate2_handoff.md`).
- **`large` (Tier 3)**: Cross-cutting architecture/schema overhaul ($>5$ files). Convene [`council-review`](../council-review/SKILL.md) via single `teamwork` dispatch $\rightarrow$ Gate 1 approval $\rightarrow$ sequential Tier 2 work packages.
- **Mid-Execution Escalation**: If scope exceeds initial tier boundaries, immediately halt mutations, retain active checkpoint, author `gate1_proposal.md`, and obtain explicit approval before resuming edits per [`orchestrator`](../orchestrator/SKILL.md#12-zero-read-triage-gate-step-0-blast-radius-sizing--ssot).

### Phase 1: Investigation & Blast Radius Analysis (Strictly Read-Only on Tier 2/3)
1. **Trace Callers & Invariants (Parallel Fan-Out)**: Batch read-only caller searches (`rtk rg`) in parallel within a single turn before proposing edits. For Tier 0/1, inspect target files directly (`read_file`). For Tier 2/3, delegate target file reading to read-only specialist subagents (`system-architect` or `code-auditor` via `view_file`) per [`orchestrator`](../orchestrator/SKILL.md).
2. **External API & Library Verification (Context7 MCP)**: Verify third-party libraries, APIs, or framework contracts via Context7 MCP (`resolve-library-id` $\rightarrow$ `query-docs`) or [`deep-web-research`](../deep-web-research/SKILL.md) instead of training memory.
3. **Hazard Assessment**:
   - Test harness mocks (`unittest.mock.patch`, Jest spies, dynamic method patching).
   - Concurrency & threading locks, event loops, and daemon states.
   - Import directions (ensure DAG remains acyclic).
4. **Proposal & Gate 1 Packaging (Tier 2/3 & Package Installations)**:
   - Present findings, root cause, exact target coordinates (`file.ext#Lxx-Lyy`), target function signatures, upstream caller blast radius (`rtk rg`), repro test plan, and minimal implementation plan under `# Review Request: Gate 1 (Pre-Execution Proposal)` **exclusively inside an Antigravity UserFacing Artifact** (`write_file` to `<appDataDir>\brain\<conversation-id>/gate1_proposal.md` with `ArtifactMetadata.RequestFeedback: true`).
   - Keep the working tree 100% clean prior to Gate 1 approval so Phase 2 `New-AuditCheckpoint.ps1` succeeds cleanly. Chat response must remain 1–3 lines linking to `gate1_proposal.md`.
   - Qualifying Tier 0 and Tier 1 tasks bypass Gate 1 ceremony and proceed directly to Phase 2 Checkpoint.
5. **Architectural Decision Gate (ADR)**: If the proposed change introduces a new dependency, alters system protocols/topology, modifies data schemas, or establishes security boundaries, propose an ADR (`<Project>-AI-Context/docs/adr/000x-...md` in Twin-Repo mode, or `docs/adr/000x-...md` in Single-Repo mode per [`documentation-and-adrs`](../documentation-and-adrs/SKILL.md)).

### Phase 2: Gate 1 Approval (Tier 2/3) & Verified Rollback Checkpoint
1. **Explicit Approval & Gate 1 Return Loop (Tier 2/3 & Package Installs)**:
   - Obtain Gate 1 confirmation before modifying any files:
     - **Mode A (Direct Human Operator Chat)**: Explicit confirmation (`"approve"`, `"acc"`, `"lanjut"`, `"gas"`, `"LGTM"`, or clicking the UI "Proceed" button) satisfies Gate 1 (`APPROVE`).
     - **Mode B (Structured External Review)**: Ingest `# Review Feedback...` or `# Technical Review...` per [`handoff-spec.md`](./references/handoff-spec.md). Strictly ban performative praise (`"You're absolutely right!"`); verify review suggestions against caller grep results and Ponytail YAGNI.
2. **Establish Verified Rollback Point (All Tiers — Strictly Before Modifying Files)**:
   - **Git Repositories**: Ensure tracked working tree is clean (`rtk git status --short`) and create a checkpoint:
     ```powershell
     powershell -ExecutionPolicy Bypass -File "$HOME\.gemini\config\skills\audit-dev-workflow\scripts\New-AuditCheckpoint.ps1" -Task "<task_name>"
     ```
   - **Files Outside Git**: Back up the target file to scratch via `-FilePath "<target_file>"`:
     ```powershell
     powershell -ExecutionPolicy Bypass -File "$HOME\.gemini\config\skills\audit-dev-workflow\scripts\New-AuditCheckpoint.ps1" -Task "<task_name>" -FilePath "<target_file>"
     ```
   - **Automated Rollback**: On unexpected Phase 3/4 failures (after 2 failed fix attempts), restore cleanly via:
     ```powershell
     powershell -ExecutionPolicy Bypass -File "$HOME\.gemini\config\skills\audit-dev-workflow\scripts\Restore-AuditCheckpoint.ps1" -Task "<task_name>" [-FilePath "<target_file>"]
     ```

### Phase 3: Repro-First RED Test & Pragmatic Implementation (Post-Checkpoint)
1. **Repro-First Failing Test (Failure-First Verification / RED)**:
   - Immediately after establishing `checkpoint-<task>`, author or update a minimal reproducible failing test (RED) before writing production fix code.
   - On Tier 1, Parent authors and verifies the failing test directly. On Tier 2/3, Parent delegates RED test authoring to `tdd-guide` (Sequential Mutator 1) and verifies the failing CLI test receipt (`run_command`, exit code $\ne 0$ for the expected assertion failure, not a syntax/import error).
2. **Minimal Implementation (GREEN)**:
   - **Tier 0 & Tier 1**: Parent applies changes directly (`edit_file` / `write_file`). Shortest working diff wins.
   - **Tier 2 & Tier 3**: Parent delegates implementation to serialized specialists (`tdd-guide`, `ui-crafter`, `build-error-resolver`, `docs-architect`, `l10n-humanizer`, or `maintenance-bot`) via the 4-Slot Delegation Contract in [`orchestrator`](../orchestrator/SKILL.md).
3. **Clean Code & Fast Syntax Gate**:
   - Zero unneeded abstractions, zero generic AI comments, strict preservation of existing defensive logic (timeouts, retries, null checks, calibrated thresholds), and bracketed `<...>` placeholders for secret scanner hygiene.
   - Run the **Pre-Mutation Syntax Interception Gate** (`orchestrator/SKILL.md#17-pre-mutation-syntax-interception-swe-agent-fast-syntax-gate--ssot`) before running full test suites so syntax typos are fixed in-turn without burning `global_attempt_counter` ($\le 2$).

### Phase 4: Local Verification & Review
1. **Test Suite Verification & Parent VCS Receipt Check**:
   - **Parent VCS Receipt Invariant**: On delegated work, Parent independently inspects `rtk git status --short` and `rtk git diff --stat` and executes test runners directly via `run_command`.
   - **Repos with Test Harnesses**: Capture (a) exact CLI test command executed, (b) terminal exit code (`0`), and (c) verbatim assertion output confirming `> 0` passed assertions and `0` failed, plus full project test suite verification (`rtk npm test`, `rtk python -m pytest`). After two failed fix attempts, execute `Restore-AuditCheckpoint.ps1` and escalate.
   - **Testless Repositories**: Substitute with static syntax/build/linter verification and annotate Gate 2 with `[TEST HARNESS: NONE — STATIC/BUILD EVIDENCE PROVIDED]`.
2. **Unified Diff & Spec Verification (Two-Stage Five-Axis Rubric)**:
   - Review `rtk git diff --stat=140,80 HEAD` and full unified diff against the approved plan.
   - **Stage 1 (Spec & Acceptance Compliance)**: Verify line-by-line against requirements; reject unapproved scope creep.
   - **Stage 2 (Code Quality & Five-Axis Rubric — "Skip Style")**: Report only correctness defects, security gaps, and spec violations:
     - **Axis 1 (Correctness & Invariants)**: Boundary checks, state transitions, loop invariants, type safety, caller regressions, async/lock ordering, non-EOL runtimes (Python 3.12+, Node 20+), and zero dropped defensive logic.
     - **Axis 2 (Security & Attack Surface)**: Input sanitization, auth boundaries, injection safety, cross-module blast radius, and Secret Scanner Hygiene (bracketed `<TOKEN>` placeholders; scrub test log tokens to `<TEST_HASH_SANITIZED>` or `<MOCK_TOKEN>`).
     - **Axis 3 (Over-Engineering / Ponytail & Anti-Slop)**: Shortest working diff wins. Reject speculative abstractions and single-impl interfaces. Strip obvious comments; keep only non-obvious *why* rationale per [`clean-docs`](../clean-docs/SKILL.md).
     - **Axis 4 (Edge Cases & Silent Failures)**: No swallowed exceptions (`catch {}`), no masking defaults (`.catch(() => [])`), no resource leaks (streams, subprocesses, listeners, locks), and explicit boundary/timeout checks.
     - **Axis 5 (Test Integrity & Fault Injection)**: No mock-cheating (never mock out the unit under test or assert only `mock.called`). Verify both happy and negative paths; perform fault injection (flip a condition) when in doubt to prove tests fail.

### Phase 5: Gate 2 Review, Commit & Non-Interactive CI
1. **Gate Packaging & Reviewer Payloads**:
   - **Tier 0 (`[TRIVIAL REVIEW]`)**: Inline in chat (for diffs $\le 5$ lines per `config/GEMINI.md#L36`) or artifact, containing diffstat and full unified diff (`+`/`-`).
   - **Gate 2 (`# Review Request: Gate 2 (Post-Execution Handoff & Diff)`)**: Written exclusively as an Antigravity UserFacing Artifact (`<appDataDir>\brain\<conversation-id>/gate2_handoff.md` with `UserFacing: true`) per [`handoff-spec.md`](./references/handoff-spec.md). Chat response must remain 1–3 lines linking to the artifact.
2. **Reviewer Return Loop Handling (Gate 2)**:
   - Evaluate operator chat confirmation (Mode A) or structured review verdict (Mode B):
     - On `APPROVE`: Proceed to commit discipline.
     - On `QUESTIONS FOR IMPLEMENTER`: Run `rtk rg "<symbol>"` and return exact coordinates (`file.ext#Lxx-Lyy`) and verbatim snippet.
     - On `REJECT`:
       - *Implementation Fix (Iterative Phase 3)*: Keep active `checkpoint-<task>` branch as baseline (do NOT run `Restore-AuditCheckpoint.ps1` or overwrite the checkpoint), apply requested fixes, re-verify, and update `gate2_handoff.md`.
       - *Architectural Abort (Return to Phase 1)*: Run `Restore-AuditCheckpoint.ps1` to revert working tree cleanly, confirm rollback, and draft a new Gate 1 proposal.
3. **Repository Commit Discipline (Parent Agent Only)**:
   - Commit code changes using humanized Conventional Commits (`fix(scope): ...`, `feat(scope): ...`) with zero AI process tags per [`clean-docs`](../clean-docs/SKILL.md).
   - **Context Tracking**: In Twin-Repo mode, synchronize `task_state.md` and `docs/adr/` in `<Project>-AI-Context` per [`sync-task-state`](../sync-task-state/SKILL.md) and commit atomically; in Single-Repo mode, commit local `docs/adr/` and `task_state.md` in clean atomic steps.
4. **Push & Non-Interactive CI**:
   - Prompt user in chat for explicit push approval, then push and monitor CI via [`gh-workflow`](../gh-workflow/SKILL.md).
5. **Post-Commit Checkpoint Branch Cleanup (GAP-MED-05)**:
   - Once changes are committed and verified, delete the local checkpoint branch (`rtk git branch -d "checkpoint-<task>"`; never use `-D`).

---

## References (On-Demand)

- [Clean Docs Standard](../clean-docs/SKILL.md): Plain-spoken repo prose, zero process leaks, public repo hygiene, and humanized commit messages.
- [Engineering Pitfalls](./references/pitfalls.md): Agentic traps and Five-Axis logic pitfalls to double-check.
- [Handoff Specification & Guidelines](./references/handoff-spec.md): Normative schemas for Gate 1, Gate 2, and dispute resolution.
- [Subagent Execution Patterns](./references/subagent-patterns.md): 11-agent fleet responsibilities, dynamic model elevation, and 4-slot templates.
