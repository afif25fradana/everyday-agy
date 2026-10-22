# Prompt Templates for Antigravity
**Operational Alignment with Human Operator & External Reviewers (Claude, Gemini Web, etc.)**

Ready-to-paste atomic prompts for Antigravity sessions. Governed by the payload schemas in [`handoff-spec.md`](./handoff-spec.md) and the operational runbook in [`SKILL.md`](../SKILL.md).

---

## 1. Phase 1 & 2: Diagnostic Audit & Gate 1 Proposal Packaging

Use when investigating a bug or planning a feature to produce a compliant `# Review Request: Gate 1 (Pre-Execution Proposal)` before touching any code.

```markdown
# Phase
Phase 1-2: Diagnostic Audit & Gate 1 Proposal Packaging (Read-Only)

# Scope
[exact files, directories, or config files]

# Context / Symptom
[concise technical description of the bug, behavior, or feature target]

# Instructions
1. **Root Cause & Invariants**: Inspect target code via `read_file`. Trace logic flow, identify root cause, and cite exact target coordinates (`file.ext#Lxx-Lyy`) and function signatures.
2. **Blast Radius (rtk rg)**: Trace callers across the repo using `rtk rg` and map affected boundaries, consumers, and tests.
3. **Repro Test**: For bug fixes, create a minimal failing test script (RED) capturing the issue.
4. **Minimal Proposal**: Formulate the shortest working diff, reusing existing helpers with zero speculative abstractions.
5. **Gate 1 Packaging**: Package proposal per schema in [`handoff-spec.md`](./handoff-spec.md):

# Review Request: Gate 1 (Pre-Execution Proposal)
- **Task**: [Task Title]
- **Target Coordinates**: [file.ext#Lxx-Lyy]
- **Function Signature(s)**: [exact signature(s)]
- **Git HEAD SHA**: [sha]

## Root Cause & Invariant Analysis
[analysis]

## Caller Context & Blast Radius (rtk rg)
[callers and modules]

## Minimal Implementation Proposal (Ponytail)
[plan and target files]

# Stop Condition
Stop immediately after presenting Gate 1. Await explicit approval (or UI "Proceed") before modifying files.
```

---

## 2. Tier 0: Trivial Fast-Path Execution (`[TRIVIAL REVIEW]`)

Use ONLY for cosmetic changes, docs, typos, or metadata updates modifying `<= 2` files and `<= 3` executable lines (or `<= 5` comment/doc lines) with ZERO logic mutations per [`handoff-spec.md`](./handoff-spec.md#21-tier-0-trivial-fast-path).

```markdown
# Phase
Tier 0: Trivial Fast-Path (Cosmetic / Non-Logic Change)

# Scope Lock (<= 2 files, <= 3 executable or <= 5 doc lines)
[exact file paths]

# Task
[concise description of typo, comment, or metadata fix]

# Execution Instructions
1. Verify change touches zero logic, conditionals, loops, state transitions, or security checks.
2. Apply edit directly using `edit_file`.
3. Package output strictly as:

[TRIVIAL REVIEW]
- **Task**: [Task Description]
- **Scope**: [files changed]
- **Rationale**: [Explain non-logic nature]

### Diffstat & Unified Diff
[inline diffstat and diff]

# Stop Condition
Stop after presenting [TRIVIAL REVIEW]. Await approval before commit.
```

---

## 3. Phase 3–5: Execution, Local Verification & Gate 2 Handoff Packaging

Use when Gate 1 is approved to execute changes, run tests, capture real evidence, and package the Gate 2 payload per [`handoff-spec.md`](./handoff-spec.md#23-gate-2-post-execution-handoff--diff).

```markdown
# Phase
Phase 3-5: Execution, Local Verification & Gate 2 Handoff Packaging

# Approved Direction
Approved Gate 1 plan: [1-2 sentence summary of approved proposal]

# Allowed Scope
- [exact file paths]

# Execution Instructions
1. Checkpoint: Ensure git working tree is clean or create a checkpoint via `New-AuditCheckpoint.ps1`.
2. Execution: Apply changes using `edit_file`/`write_file`. Shortest working diff wins. Use `<...>` bracketed placeholders for any secret tokens.
3. Verification: Execute test suite `[command]`. Capture exit code 0 and verbatim stdout turning RED test to GREEN (or annotate `[TEST HARNESS: NONE]` with static evidence if repo is testless).
4. Five-Axis Self-Audit: Confirm compliance with the 5 axes defined in [`SKILL.md`](../SKILL.md#3-five-axis-pre-flight-rubric).
5. Packaging: If diff > 800 lines, chunk per [`handoff-spec.md`](./handoff-spec.md#4-the--800-line-module-chunking-protocol). Otherwise package:

# Review Request: Gate 2 (Post-Execution Handoff & Diff)
- **Task**: [Task Title]
- **Git HEAD SHA**: [sha]

## Summary of Outcome & Root Cause Fix
[summary]

## Diff & Impact
### Diffstat & Full Unified Diff
[diffstat and diff]

## Mandatory Verification Evidence
- **CLI Command**: [exact command, e.g., rtk npm test]
- **Exit Code**: 0
- **Verbatim Output**:
[verbatim stdout/stderr snippet showing passed assertions with mock tokens scrubbed to <TEST_HASH_SANITIZED>]

## Five-Axis Pre-Flight Self-Audit
- All 5 axes verified (Correctness, Security, Ponytail/YAGNI, Edge Cases, Test Integrity).

# Stop Condition
Stop immediately after presenting Gate 2. Do not commit or push until review approval is received.
```

---

## 4. Return Loop: Dispute Resolution & Factual Queries

Use when a Reviewer issues `QUESTIONS FOR IMPLEMENTER` or asks to verify a symbol, caller, or invariant per [`handoff-spec.md`](./handoff-spec.md#62-factual-code-dispute-format).

```markdown
# Phase
Return Loop: Factual Code Dispute Resolution

# Reviewer Question / Target Symbol
[paste reviewer question or symbol name]

# Instructions
1. Execute `rtk rg "[symbol]"` across the repository to locate definition and caller sites.
2. Package findings per [`handoff-spec.md`](./handoff-spec.md#62-factual-code-dispute-format):

# Implementer Response: Factual Code Resolution
- **Target Question / Symbol**: [symbol]
- **Command Executed**: `rtk rg "[symbol]"`

### Verified Code Coordinates
[file.ext#Lxx-Lyy]

```[lang]
[verbatim code snippet]
```

### Clarification
[1-2 direct sentences resolving the inquiry from evidence]

# Stop Condition
Stop after providing code evidence. Await reviewer's updated verdict.
```

---

## 5. Global Config or Skill Patch (`GEMINI.md`, `.gemini\`, Skills)

Use when updating Antigravity's own rules, global config, or installed skills. Never dictate line numbers, block names, or exact wording from memory—have the agent inspect its live file first.

```markdown
# Phase
Phase 1-2: Config / Skill Inspection & Minimal Patch Proposal (Read-Only)

# Goal & Context
Refine `[target file/skill, e.g., GEMINI.md or skill X]` to address `[concrete problem or behavior observed]`.

# Questions to Answer Before Editing
1. **Q1 (Live File Inspection)**: Read current `[target file]` via `read_file`. Which existing section or rule already covers or overlaps with this concept?
2. **Q2 (Collision & Redundancy Check)**: Verify that adjusting this rule does not contradict `GEMINI.md` or duplicate an existing instruction.
3. **Q3 (Minimal Patch Proposal)**: Propose the smallest possible patch (updating existing lines in place) and show proposed unified diff.

# Stop Condition
Stop after presenting findings and proposed diff. Await explicit approval before applying changes.
```

---

## 6. Bootstrap & Context Sync (`architecture.md` / `sync-task-state`)

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
