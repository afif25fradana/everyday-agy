# ADR-0023: Adopt Zero-Decision Planning, 4-Bucket Dispute Actions, and Unrun Checks

## Status
Accepted

## Date
2026-11-08

## Context
When evaluating external review and specification guidelines from Google's Elephant-Goldfish Model (EGM), direct installation of the plugin was unsuitable due to several structural limitations:
1. **Agent and Skill Schema Mismatches**:
   The external plugin defined 10 persona markdown files without required `model` or `tools` frontmatter fields, and several skill descriptions exceeded continuous integration character limits.
2. **Conversation Context Overhead**:
   The workflow instructed the primary conversation session to accumulate all drafting turns, multiple rounds of critique, and inline code editing, which caused large prompt token buildup and attention drift.
3. **Subagent Nesting Incompatibility**:
   The review pipeline routed through an intermediate delegator agent attempting to invoke subagents recursively. Antigravity's subagent harness is single-tiered and does not support nested subagent calls.
4. **Lack of Automated Test Verification and Rollbacks**:
   The plugin focused strictly on prose review without automated test-runner verification or git rollback checkpoints. Its automated acceptance mode modified workspace files without version control integration.
5. **Static File Sprawl**:
   The bootstrapping script created static `README.md` files in every subdirectory, adding unnecessary maintenance overhead.

However, the methodology contained practical heuristics: resolving architectural decisions in planning before writing code, classifying review disputes into four clear actions, tracking unrun checks honestly, auditing implementation against specifications across four drift vectors, and verifying documentation clarity. Rather than installing the plugin, these heuristics were adopted into existing skills.

## Decision
1. **Require Zero Design Decisions Left to Implementers in Planning (`spec-kit`, `handoff-spec.md`)**:
   - In `spec-kit` planning (`/speckit.plan`), mandate that technical plans determine schemas, API endpoints, dependencies, error codes, and edge-case behaviors before implementation starts.
   - In `handoff-spec.md` (Gate 1 payload), include a verification check confirming all architectural choices are settled.
   - Sizing exemption: this requirement applies to Tier 2 (`standard`) and Tier 3 (`large`) tasks. Tier 0 (`trivial`) and Tier 1 (`small bugfix`) changes are exempt to prevent over-specification on routine fixes.
   - Require documenting evaluated design alternatives and trade-offs.
2. **Classify Review Feedback into Four Action Buckets (`handoff-spec.md`)**:
   - In `handoff-spec.md` (Section 6.2), categorize review responses into four unambiguous actions:
     - `CONTEST`: The critique is factually incorrect or based on a misunderstanding of code; requires verifying checkable coordinates (`file.ext#Lxx-Lyy`) via `rtk rg`.
     - `ESCALATE`: The critique is incorrect, but evidence relies on unwritten conventions or external agreements; state the context plainly without adding unnecessary code or documentation bloat.
     - `PROPOSE FIX`: The critique is valid; provide the exact text replacement or code diff adhering to minimal change principles.
     - `DECLINE`: The finding is a cosmetic preference with no functional or security risk; record as an accepted trade-off without code changes.
3. **Record Failed Review Checks as Unrun (`handoff-spec.md`, `council-review`)**:
   - Any review check or subagent that times out or encounters a tool exception must be recorded as `Status: not run`. Treating a failed check as having zero findings is prohibited, and unrun checks prevent clean review sign-off.
   - Distinguish between `Settled` findings (contested with verified evidence or accepted as trade-offs) and `Fixed` findings (addressed via code edits, which require verification).
4. **Audit Implementation Against Specifications Across Four Drift Vectors (`code-auditor`)**:
   - When reviewing code against specifications or ADRs, check four specific vectors: (a) *Missing Features*, (b) *Incomplete Models/Schemas*, (c) *Logic Shortcuts or Bypasses*, and (d) *Architectural Divergence*.
   - In planning reviews, treat proposed functions and files as planned additions rather than flagging them as missing code.
5. **Enforce Documentation Clarity and Caveat Calibration (`clean-docs`)**:
   - Ban performative praise and filler phrases in review discussions.
   - Apply the Naive Reader Paraphrase Test: ensure a fresh reader can plainly articulate in two paragraphs what the document proposes and how the existing system works.
   - Calibrate operational caveats (`DROP`, `CALIBRATE`, `RELOCATE`, `KEEP`) to remove speculative hedging while preserving real system limits.

## Alternatives Considered & Rejected
- **Installing the raw plugin**: Rejected due to agent frontmatter schema mismatches, recursive subagent nesting failures, and lack of rollback checkpoints.
- **Applying zero-decision rules to trivial bug fixes**: Rejected because requiring full architectural plans for single-line or single-module fixes introduces unnecessary friction.

## Consequences
- **Positive**: Resolves design choices before writing implementation code on multi-file tasks.
- **Positive**: Replaces circular review debates with four concrete action categories and verified evidence.
- **Positive**: Prevents false-pass assumptions by recording failed review checks as `not run`.
- **Positive**: Adds clear evaluation criteria for comparing implementation code to specifications.
- **Neutral / Operational Requirements**: Planning documents for Tier 2 and Tier 3 tasks must specify data schemas, error handling, and rejected alternatives before implementation begins.
