# Gate & Milestone Handoff Specification (`handoff-spec.md`)
**Local Implementer (Antigravity) <-> Reviewer (Human Operator or External AI Auditor)**

This specification defines the communication contracts, trigger headers, quantitative thresholds, and evidence payloads required across the development lifecycle.

---

## 1. Environment Asymmetry & Anti-Hallucination Boundaries

- **Sandboxed / Remote Review Environment**: Reviewers rely 100% on the verbatim evidence packaged in the handoff payload.
- **Missing Evidence Rule**: Omitting test/verification logs, exit codes, function signatures, caller context, or diffstats immediately halts review with `QUESTIONS FOR IMPLEMENTER`. For testless codebases, substitute automated tests with static syntax/build verification.
- **Zero Diff Starvation**: Never cite a branch or patch on disk instead of including the actual unified diff (`+`/`-`).
- **Evidence Citation**: All claims must be anchored to exact code coordinates (`file.ext#Lxx-Lyy`), unified diff lines, or verbatim CLI command output.
- **Mandatory UserFacing Artifact Packaging**: Formal review payloads (Gate 1 proposals, Gate 2 handoffs, unified diffs exceeding 5 lines, and deep audit reports) are packaged into Antigravity UserFacing Artifacts (`<appDataDir>\brain\<conversation-id>/<name>.md`). Chat responses must remain 1–3 lines linking to the artifact for clean reviewer copy-pasting (compact $\le 5$-line Tier 0 `[TRIVIAL REVIEW]` diffs may be presented inline in chat per `config/GEMINI.md#L36`).

---

## 2. Gate & Tier Trigger Specifications

### 2.1 Tier 0 (Trivial Fast-Path)
- **Trigger Header**: `[TRIVIAL REVIEW]`
- **Quantitative Limits**: Modifies `<= 2` files AND `<= 3` lines of executable code (or `<= 5` lines of non-executable docs/comments).
- **Qualitative Limits**: ZERO changes to business logic, conditionals, loops, state transitions, error handlers, public API signatures, schemas, or security boundaries.
- **Required Payload**: Diffstat and full inline unified diff (`+`/`-`) in chat (if $\le 5$ diff lines) or UserFacing Artifact.
- **Bypass Rule**: Qualifying Tier 0 changes bypass formal Gate 1 ceremony, executing autonomously immediately following verified checkpoint creation (`New-AuditCheckpoint.ps1`), and submitting `[TRIVIAL REVIEW]` before commit per ADR-0015.

### 2.2 Gate 1 (Pre-Execution Proposal Review)
- **Trigger Header**: `# Review Request: Gate 1 (Pre-Execution Proposal)`
- **Packaging Protocol**: Gate 1 proposals MUST be written exclusively as an Antigravity UserFacing Artifact (`<appDataDir>\brain\<conversation-id>/gate1_proposal.md`) with `ArtifactMetadata` (`UserFacing: true`, `RequestFeedback: true` to provide the native one-click "Proceed" approval button).
- **Chat Response Standard**: Chat responses must strictly be 1–3 lines linking directly to `gate1_proposal.md`, never dumping the raw proposal or diffs directly into chat.
- **Lifecycle Timing**: Generated AFTER Phase 1 (Read-Only Diagnostic Audit & Blast Radius Analysis), strictly BEFORE Phase 2 Checkpoint creation (`New-AuditCheckpoint.ps1`), RED test file creation, and production file modifications (mandatory for Tier 2/3 and package installations; skipped for Tier 0 and Tier 1 per ADR-0015).
- **Required Payload**:
  1. Task & Context summary.
  2. Root cause validation with exact target coordinates (`file.ext#Lxx-Lyy`).
  3. Target function signatures.
  4. Upstream caller context & consumer blast radius (verified via `rtk rg`).
  5. Minimal implementation plan adhering to `ponytail` (shortest working diff).
  6. Repro test plan (for bug fixes; executed immediately after Gate 1 approval and Phase 2 checkpoint).
  7. Zero-Decision Check: All data structures, error codes, and signatures pre-determined; zero architectural choices delegated to implementer (Tier 2/3).

### 2.3 Gate 2 (Post-Execution Handoff & Diff Review)
- **Trigger Header**: `# Review Request: Gate 2 (Post-Execution Handoff & Diff)`
- **Packaging Protocol**: Gate 2 handoff payloads MUST be written exclusively as an Antigravity UserFacing Artifact (`<appDataDir>\brain\<conversation-id>/gate2_handoff.md`) with `ArtifactMetadata` (`UserFacing: true`, `RequestFeedback: false`).
- **Programmatic Diff Injection (Anti-Hallucination Invariant)**: Unified diffs and diffstats must NEVER be typed or reconstructed from memory by the LLM inside `write_file`. Instead, the implementer writes `gate2_handoff.md` containing `{{VERBATIM_GIT_DIFFSTAT}}` and `{{VERBATIM_GIT_DIFF}}` placeholders, and executes `Update-Gate2Diff.ps1` (`powershell -ExecutionPolicy Bypass -File "$HOME\.gemini\config\skills\audit-dev-workflow\scripts\Update-Gate2Diff.ps1" -ArtifactPath "<artifact_path>"`). The script automatically includes untracked files (`git add -N`), scrubs secrets to `<TEST_HASH_SANITIZED>`, injects byte-exact diffs and diffstats, and un-stages untracked files to maintain index idempotency.
- **Chat Response Standard**: Chat responses must strictly be 1–3 lines linking directly to `gate2_handoff.md`, never dumping full diffs directly into chat.
- **Lifecycle Timing**: Generated AFTER Phase 3 (RED Test & GREEN Patch Execution) and Phase 4 (Local Verification), strictly BEFORE `git commit` or `git push`.
- **Required Payload**:
  1. High-level summary of outcome and root cause resolution.
  2. High-level diffstat (untruncated paths via `git diff --stat=140,80 HEAD`) and full unified diff (`+`/`-`).
  3. Five-Axis Pre-Flight self-audit confirmation per [`SKILL.md`](../SKILL.md#phase-4-local-verification--review).
  4. Mandatory Real Test Evidence (or Static Verification):
     - Repos with test harnesses: (a) Exact CLI command, (b) Terminal exit code `0`, (c) Verbatim snippet of `stdout`/`stderr` showing passed assertions.
     - Testless repos: Annotated as `[TEST HARNESS: NONE]` with static/build/linter evidence.

---

## 3. Normative Payload Schemas

The required structure for each gate payload is:

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

## Minimal Implementation & Repro Test Proposal (Ponytail)
- Target Files: `<files>`
- Repro Test Plan (RED): `<test file and assertion to verify failure post-checkpoint>`
- Proposed Diff Strategy (GREEN): <Shortest working diff plan>
- Zero-Decision Check: <Confirmed: schemas, APIs, and boundary choices pre-determined (Tier 2/3)>
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
### Diffstat
{{VERBATIM_GIT_DIFFSTAT}}

### Full Unified Diff
```diff
{{VERBATIM_GIT_DIFF}}
```

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
- **Test Output Token Scrubbing**: If real test output displays generated session IDs, JWTs, or test hashes, scrub them to `<TEST_HASH_SANITIZED>` or `<MOCK_TOKEN>` before copying into the Gate 2 payload or scratch files to avoid triggering false-positive secret scanner rejections.

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
| `APPROVE` | Proceed to Phase 2 checkpoint & implementation (Gate 1) or repository commit discipline (Gate 2). |
| `APPROVE (Trivial: <rationale>)` | Proceed to repository commit discipline for Tier 0 fast-path. |
| `REJECT` | Stop immediately. Review feedback findings. Return to Phase 1 investigation or Phase 3 implementation. Do not commit or push. |
| `QUESTIONS FOR IMPLEMENTER` | Run `rtk rg "<symbol>"` locally to verify the symbol, caller, or invariant. Return the response using the Dispute Resolution Format below. |

### 6.2 The 4-Bucket Resolution Taxonomy
When responding to review feedback or `QUESTIONS FOR IMPLEMENTER`, classify each finding into exactly one bucket:
- **`CONTEST`**: The critique is factually inaccurate or based on a misunderstanding of code. Must cite checkable code coordinates (`file.ext#Lxx-Lyy`) verified via `rtk rg`. ("This was intentional" is not evidence).
- **`ESCALATE`**: The critique is inaccurate, but the evidence relies on out-of-band context (oral team decision, unwritten convention) not present in repository files. State this directly; do not add code or documentation bloat solely to satisfy an external reviewer.
- **`PROPOSE FIX`**: The critique is valid. Define precise textual replacements or code fixes adhering to Ponytail.
- **`DECLINE`**: The finding is a cosmetic Nit with no security or functional risk. Record it as an accepted trade-off; do not modify code.

**Anti-Rationalization Prohibitions**:
- Do not contest a comprehension gap: if a fresh reader could not follow the document or code intent, it is missing context.
- You authored the plan/code under review; a wish to contest is not evidence that the reviewer is wrong.

### 6.3 Review Accounting & State Tracking
- **Failed Reviewer Accounting (`not run` vs 0 Findings)**: Any reviewer or subagent that times out, encounters an unhandled tool exception, or fails to deliver a complete report must be recorded with `Status: not run`. It is strictly forbidden to treat a failed reviewer as having "0 findings". A required reviewer with `not run` status invalidates approval.
- **Settled vs Fixed Finding States**:
  - `Settled`: Finding was contested with verified code coordinates or accepted as a documented trade-off by the human operator. Immune to re-litigation by subsequent subagents.
  - `Fixed`: Finding was addressed via code/doc mutation. Must be re-verified by subsequent verification passes.

### 6.4 Factual Code Dispute Format (Responding to `QUESTIONS FOR IMPLEMENTER`)

```markdown
# Implementer Response: Factual Code Resolution
- **Bucket**: <CONTEST | ESCALATE | PROPOSE FIX | DECLINE>
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

Never commit mock bug reports, flawed sample diffs, or toy test fixtures to the repository working tree. All review artifacts belong in session memory, chat, or session scratch (`<appDataDir>\brain\<conversation-id>\scratch\<task>\`).
