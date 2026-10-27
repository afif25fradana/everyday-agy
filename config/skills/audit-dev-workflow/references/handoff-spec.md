# Gate & Milestone Handoff Specification (`handoff-spec.md`)
**Local Implementer (Antigravity) <-> Reviewer (Human Operator or External AI Auditor)**

This specification defines the communication contracts, trigger headers, quantitative thresholds, and evidence payloads required across the development lifecycle. Ready-to-paste prompts are maintained in [`prompt-templates.md`](./prompt-templates.md).

---

## 1. Environment Asymmetry & Anti-Hallucination Boundaries

- **Sandboxed / Remote Review Environment**: Reviewers rely 100% on the verbatim evidence packaged in the handoff payload.
- **Missing Evidence Rule**: Omitting test/verification logs, exit codes, function signatures, caller context, or diffstats immediately halts review with `QUESTIONS FOR IMPLEMENTER`. For testless codebases, substitute automated tests with static syntax/build verification.
- **Zero Diff Starvation**: Never cite a branch or patch on disk instead of including the actual unified diff (`+`/`-`).
- **Evidence Citation**: All claims must be anchored to exact code coordinates (`file.ext#Lxx-Lyy`), unified diff lines, or verbatim CLI command output.

---

## 2. Gate & Tier Trigger Specifications

### 2.1 Tier 0 (Trivial Fast-Path)
- **Trigger Header**: `[TRIVIAL REVIEW]`
- **Quantitative Limits**: Modifies `<= 2` files AND `<= 3` lines of executable code (or `<= 5` lines of non-executable docs/comments).
- **Qualitative Limits**: ZERO changes to business logic, conditionals, loops, state transitions, error handlers, public API signatures, schemas, or security boundaries.
- **Required Payload**: Diffstat and full inline unified diff (`+`/`-`).
- **Bypass Rule**: Qualifying Tier 0 changes bypass formal Gate 1 ceremony upon simple chat approval, proceeding from Phase 2 checkpoint to Phase 3 execution and submitting `[TRIVIAL REVIEW]` before commit.

### 2.2 Gate 1 (Pre-Execution Proposal Review)
- **Trigger Header**: `# Review Request: Gate 1 (Pre-Execution Proposal)`
- **Lifecycle Timing**: Generated AFTER Phase 1 (Diagnostic Audit) and Phase 2 (Checkpoint), strictly BEFORE modifying files.
- **Required Payload**:
  1. Task & Context summary.
  2. Root cause validation with exact target coordinates (`file.ext#Lxx-Lyy`).
  3. Target function signatures.
  4. Upstream caller context & consumer blast radius (verified via `rtk rg`).
  5. Minimal implementation plan adhering to `ponytail` (shortest working diff).
  6. Repro test confirmation (for bug fixes).

### 2.3 Gate 2 (Post-Execution Handoff & Diff Review)
- **Trigger Header**: `# Review Request: Gate 2 (Post-Execution Handoff & Diff)`
- **Lifecycle Timing**: Generated AFTER Phase 3 (Patch Execution) and Phase 4 (Local Verification), strictly BEFORE `git commit` or `git push`.
- **Required Payload**:
  1. High-level summary of outcome and root cause resolution.
  2. High-level diffstat and full unified diff (`+`/`-`).
  3. Five-Axis Pre-Flight self-audit confirmation per [`SKILL.md`](../SKILL.md#3-five-axis-pre-flight-rubric).
  4. Mandatory Real Test Evidence (or Static Verification):
     - Repos with test harnesses: (a) Exact CLI command, (b) Terminal exit code `0`, (c) Verbatim snippet of `stdout`/`stderr` showing passed assertions.
     - Testless repos: Annotated as `[TEST HARNESS: NONE]` with static/build/linter evidence.

---

## 3. Normative Payload Schemas

Ready-to-paste execution prompts are in [`prompt-templates.md`](./prompt-templates.md). The required structure for each gate payload is:

### 3.1 Tier 0 Schema (`[TRIVIAL REVIEW]`)
```markdown
[TRIVIAL REVIEW]
- **Task**: <Concise description>
- **Scope**: <= 2 files, <= 3 executable lines (or <= 5 doc lines)
- **Rationale**: <Explain cosmetic/non-logic nature>

### Diffstat & Full Unified Diff
<inline diffstat and unified diff>
```

### 3.2 Gate 1 Schema (`# Review Request: Gate 1`)
```markdown
# Review Request: Gate 1 (Pre-Execution Proposal)
- **Task**: <Task Title>
- **Date**: <YYYY-MM-DD>
- **Git HEAD SHA**: `<sha>`
- **Target Coordinates**: `<file.ext#Lxx-Lyy>`
- **Function Signature(s)**: `<exact signature(s)>`

## Root Cause & Invariant Analysis
<Investigation findings citing exact lines and invariants>

## Caller Context & Blast Radius (`rtk rg`)
- Callers identified: `<list of caller coordinates>`
- Affected modules / boundaries: `<list>`

## Minimal Implementation Proposal (Ponytail)
- Target Files: `<files>`
- Proposed Diff Strategy: <Shortest working diff plan>
```

### 3.3 Gate 2 Schema (`# Review Request: Gate 2`)
```markdown
# Review Request: Gate 2 (Post-Execution Handoff & Diff)
- **Task**: <Task Title>
- **Date**: <YYYY-MM-DD>
- **Git HEAD SHA**: `<sha>`

## Summary of Outcome & Root Cause Fix
<2-3 lines stating concrete fix and verified behavior>

## Diff & Impact
### Diffstat & Full Unified Diff
<diffstat and diff>

## Mandatory Real Test Evidence
- **CLI Test Command**: `<command>`
- **Exit Code**: `0`
- **Verbatim Output**: `<stdout/stderr snippet>` (or `[TEST HARNESS: NONE]` with static evidence)

## Five-Axis Pre-Flight Self-Audit
- All 5 axes verified per SKILL.md (Correctness, Security, Ponytail, Edge Cases, Test Integrity).
```

---

## 4. The `> 800` Line Module-Chunking Protocol

If a change exceeds 800 lines of unified diff, it must NOT be truncated blindly:
1. **Chunk 1 (Core Domain Logic)**:
   - Header: `# Review Request: Gate 2 (Post-Execution Handoff & Diff) - Chunk 1 of N`
   - Payload: Full diffstat for the entire change, full unified diff of core business logic / state transitions, and full real test evidence.
   - Note: State clearly: *"Chunk 1 contains the high-level diffstat, core domain changes, and test execution evidence. Subsequent chunks will cover adapters, integration layers, and test suites upon approval."*
2. **Chunk 2 (Adapters & Integrations)**:
   - Header: `# Review Request: Gate 2 (Post-Execution Handoff & Diff) - Chunk 2 of N`
   - Payload: Secondary modules, API routes, and integration glue.
3. **Chunk 3 (Tests, Fixtures & Docs)**:
   - Header: `# Review Request: Gate 2 (Post-Execution Handoff & Diff) - Chunk 3 of N`
   - Payload: Test files, test fixtures, documentation, and configuration changes.

---

## 5. Secret Scanner Hygiene & Test Log Token Scrubbing

- **Placeholder Tokens**: All tokens, credentials, or keys in code, diffs, and examples must strictly use bracketed `<...>` placeholders (e.g., `Bearer <AUTH_TOKEN>`, `api_key = "<STRIPE_KEY>"`).
- **Entropy Limit**: Never use raw mock strings exceeding 12-16 characters that resemble production keys (e.g., avoid `abc123456789xyz000`).
- **Test Output Token Scrubbing**: If real test output displays generated session IDs, JWTs, or test hashes, scrub them to `<TEST_HASH_SANITIZED>` or `<MOCK_TOKEN>` before copying into the Gate 2 payload to avoid triggering false-positive secret scanner rejections.

---

## 6. Dual-Mode Return Loop & Dispute Resolution Protocol

The local implementer supports two feedback ingestion modes:

### 6.1 Review Feedback Ingestion Modes
- **Mode A (Direct Human Operator Chat)**:
  - Explicit confirmation in chat (e.g., `"approve"`, `"acc"`, `"lanjut"`, `"gas"`, `"LGTM"`) or clicking the UI "Proceed" button immediately satisfies Gate 1 or Gate 2.
  - Conversational questions or critiques from the user are addressed directly as revision items.
- **Mode B (Structured or Pasted External AI Review)**:
  - Ingests structured feedback blocks starting with `# Review Feedback` or `# Technical Review` (compatible with Claude, Gemini Web, or pasted external critiques):

| Reviewer Verdict | Local Action |
| :--- | :--- |
| `APPROVE` | Proceed to implementation (Gate 1) or repository commit discipline (Gate 2). |
| `APPROVE (Trivial: <rationale>)` | Proceed to repository commit discipline for Tier 0 fast-path. |
| `REJECT` | Stop immediately. Review feedback findings. Return to Phase 1 investigation or Phase 3 implementation. Do not commit or push. |
| `QUESTIONS FOR IMPLEMENTER` | Run `rtk rg "<symbol>"` locally to verify the symbol, caller, or invariant. Return the response using the Dispute Resolution Format below. |

### 6.2 Factual Code Dispute Format (Responding to `QUESTIONS FOR IMPLEMENTER`)

```markdown
# Implementer Response: Factual Code Resolution
- **Target Question / Symbol**: `<symbol or invariant in question>`
- **Command Executed**: `rtk rg "<symbol>"`

### Verified Code Coordinates
`path/to/file.ext#Lxx-Lyy`

```<lang>
// Verbatim code snippet showing definition or caller context
```

### Clarification
<1-2 concise lines resolving the question directly from the verified code evidence.>
```

---

## 7. Zero Synthetic Bloat

Never commit mock bug reports, flawed sample diffs, or toy test fixtures to the repository working tree. All review artifacts belong in session memory, chat, or session scratch.
