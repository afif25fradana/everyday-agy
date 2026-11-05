# ADR-0020: Protocol Harmonization, Gate 1 Flow Correction, Fleet Parity, and Pre-Mutation Syntax Interception

## Status
Accepted (Partially Superseded by ADR-0021 and ADR-0022)
## Date
2026-11-04

## Context
A forensic audit and operational review of the multi-agent orchestration architecture across `everyday-agy` identified several protocol desynchronizations, flow regressions, and quality-of-life bottlenecks:

1. **Gate 1 Flow Bypass Regression (`GAP-ORCH-01`)**: The Tier 2 dual dispatch Mermaid topology introduced in ADR-0019 inadvertently depicted Explorer subagents transitioning directly into Sequential Mutators (`S1 -> S2`) without traversing Parent Gate 1 Proposal Artifact & Approval. This conflicted with the binding invariants in `audit-dev-workflow` Phase 2 and ADR-0015, which mandate that Tier 2 (`standard`) tasks, Tier 3 (`large`) tasks, and package installations strictly require explicit Gate 1 human approval before modifying files.
2. **Subagent Fleet Parity Desynchronization (`GAP-FLEET-01`)**: Although ADR-0018 codified an 11-agent specialized fleet in `seat-catalog.md`, operational runbook `subagent-patterns.md` remained frozen on a legacy 3-role table (`Parent`, `code-auditor`/`system-architect`, `tdd-guide`). The remaining 8 custom agents were missing from operational guidance, and sample prompt skeletons used obsolete, unstructured text rather than the mandatory 4-slot delegation contract.
3. **Monotonic Stop-Rule Depletion via Syntax Typos (`GAP-QUAL-01`)**: Under ADR-0019, any failed repair attempt increments the monotonic `global_attempt_counter` ($\le 2$). When subagents or implementers introduced trivial syntax slips (missing closing braces, unescaped quotes, Python indentation errors, PowerShell syntax typos), executing the project test runner failed, burning a stop-rule attempt. Two minor typos could trigger an automated rollback (`Restore-AuditCheckpoint.ps1`) and human escalation, despite zero underlying semantic defects.
4. **Context Pollution via Inlined Review Payloads (`GAP-COMM-01`)**: Dumping multi-screen diffs, extensive test logs, or full Gate 1 proposals directly into chat polluted Parent context and made external review cumbersome. Standardizing Antigravity UserFacing Artifact packaging (`gate1_proposal.md` with `RequestFeedback: true`, `gate2_handoff.md` with `UserFacing: true`) and restricting chat responses to 1–3 lines linking to the artifact was required.
5. **CI Quality Gates & Skill Description Token Drift (`GAP-CI-01`)**: While ADR-0018 trimmed skill frontmatter descriptions to $\le 128$ characters, CI only checked for at least 10 skills and 10 agents, failing to detect description bloat, agent/skill omissions (14 skills, 11 agents), or orphaned/unindexed ADR files.

## Decision

1. **Restore Gate 1 Human Approval in Tier 2 Topology & Codify Tier 3 Decomposition**:
   - Update the `/orchestrator` Mermaid topology and runbook text to place `Gate 1 Proposal Artifact & Approval` immediately following read-only exploration and strictly preceding mutation (`S1 -> Gate1 -> S2`).
   - Explicitly affirm that package installations (any addition, removal, or upgrade of dependencies regardless of file count) strictly require Gate 1 human approval before touching files.
   - Codify post-Gate 1 execution for Tier 3 tasks: once Council review produces Gate 1 approval, execution decomposes into sequential Tier 2 work packages governed by Parent via Pathway B.

2. **Establish Pre-Mutation Syntax Interception (SWE-Agent Fast Syntax Gate)**:
   - Introduce a lightweight pre-mutation syntax interception check before executing full test runners:
     - JavaScript / TypeScript / Node: `node --check <file>` or static lint check.
     - Python: `python -m py_compile <file>`.
     - PowerShell: `[System.Management.Automation.Language.Parser]::ParseFile("<file>", [ref]$null, [ref]$err)`.
   - Syntax typos, missing braces, or parse errors caught by this syntax gate must be corrected immediately in-turn and do NOT increment the monotonic stop-rule counter (`global_attempt_counter`), preserving stop-rule attempts strictly for true semantic, build, or test assertion failures.

3. **Harmonize 11-Agent Fleet in Operational Runbooks & Standardize 4-Slot Prompts**:
   - Modernize `subagent-patterns.md` to catalog all 11 agents in 1-to-1 parity with `seat-catalog.md` and ADR-0018 (`system-architect`, `code-auditor`, `silent-failure-hunter`, `tdd-guide`, `database-reviewer`, `ui-crafter`, `docs-architect`, `build-error-resolver`, `maintenance-bot`, `spec-verifier`, `l10n-humanizer`).
   - Refactor all prompt skeletons to strictly follow the 4-slot structure (`<ROLE_AND_OBJECTIVE>`, `<SCOPE_AND_BOUNDARIES>`, `<TOOLS_AND_ABSOLUTE_SKILL_PATHS>`, `<RETURN_CONTRACT>`), the standardized 6-field receipt schema, and session scratch coordinates (`<appDataDir>\brain\<conversation-id>\scratch\<task>\`).

4. **Codify Antigravity UserFacing Artifact Packaging**:
   - Mandate in `handoff-spec.md` and `audit-dev-workflow/SKILL.md` that Gate 1 proposals and Gate 2 handoffs are packaged exclusively as Antigravity UserFacing Artifacts:
     - Gate 1: `<appDataDir>\brain\<conversation-id>/gate1_proposal.md` with `ArtifactMetadata.RequestFeedback: true` (providing the native one-click "Proceed" approval button).
     - Gate 2: `<appDataDir>\brain\<conversation-id>/gate2_handoff.md` with `ArtifactMetadata.UserFacing: true`.
   - Standardize chat responses to 1–3 lines linking to the generated artifact.

5. **Enhance CI Integrity Automation (`.github/workflows/ci.yml`)**:
   - Assert exact counts: skills `-ne 14` and agents `-ne 11`.
   - Assert ADR count `-lt 20` combined with two-way index validation between `docs/adr/*.md` and `docs/adr/README.md`.
   - Implement automated frontmatter description length validation: loop through all 14 skills and assert `$desc.Length -le 128`, failing CI with the exact character count if breached.

6. **Symmetric Intra-Directory Orphan Pruning in `sync.ps1`**:
   - Port the intra-directory orphan skill file pruning loop from `restore.ps1` into `sync.ps1` to ensure repo-tracked skill subdirectories automatically prune deleted files during pre-flight synchronization.

## Consequences

- **Positive**: Eliminates accidental mutation without approval by restoring Gate 1 to Tier 2 topologies.
- **Positive**: Eliminates premature auto-rollbacks by preventing trivial syntax typos from depleting the monotonic stop-rule counter.
- **Positive**: Full 11-agent fleet visibility and standardized 4-slot prompts improve subagent dispatch consistency.
- **Positive**: Packaging Gate 1 and Gate 2 payloads as UserFacing artifacts preserves Parent context insulation and streamlines reviewer interactions.
- **Positive**: Robust CI checks guarantee frontmatter token efficiency, two-way ADR indexing, and fleet completeness.

## Alternatives Considered & Rejected

- *Incrementing stop-rule counter on syntax errors*: Rejected because syntax errors during initial edits are expected and trivially fixable before runner execution. Distinguishing syntax typos from semantic failures prevents unnecessary rollback cycles.
- *Allowing autonomous Tier 2 mutation without Gate 1*: Rejected because multi-file modifications carry high blast radius requiring human oversight before files are touched.
