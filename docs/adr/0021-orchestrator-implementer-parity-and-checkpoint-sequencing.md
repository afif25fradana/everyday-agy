# ADR-0021: Enable Mutator Implementers in Tier 2 and Clarify Checkpoint Timing

## Status
Partially Superseded by ADR-0022 (for checkpoint and test authoring order)

## Date
2026-11-04

## Context
During audits of the orchestration runbooks and agent definitions, several workflow and timing inconsistencies were identified:
1. **Implementer Selection on Multi-File Changes**:
   In `orchestrator/SKILL.md`, implementation on Tier 2 tasks was hardcoded to `build-error-resolver`. However, `build-error-resolver` lacks file creation tools (`write_to_file`) and has strict prompt instructions against modifying business logic. This left tasks requiring new files or functional logic changes without an authorized implementer.
2. **Missing Checkpoint Step in Tier 2 Diagram**:
   The Tier 2 flowchart transitioned directly from Gate 1 approval into file mutation without depicting the mandatory git checkpoint step (`New-AuditCheckpoint.ps1`).
3. **Task Tier Sizing Definitions**:
   `orchestrator/SKILL.md` stated that touching any logic or state was Tier 2 by definition, conflicting with Tier 1 rules which explicitly govern single-module bug fixes (inherently modifying logic/state).
4. **Agent Skill Declarations**:
   `l10n-humanizer` bound `coding-standards`, which was unnecessary for UI translation and text formatting.
5. **Proposal and Checkpoint Timing**:
   Documentation in `handoff-spec.md` incorrectly stated that proposal generation occurred after creating the git checkpoint, rather than before checkpointing and file modification.

## Decision
1. **Allow Appropriate Implementers in Tier 2 Orchestration**:
   - Update the Tier 2 workflow in `orchestrator/SKILL.md` so implementation can be delegated to `tdd-guide`, `ui-crafter`, or `build-error-resolver` based on task requirements.
   - Ensure all Mermaid flowchart node labels follow standard syntax formatting.
2. **Include Git Checkpoint in Tier 2 Flowchart**:
   - Insert an explicit checkpoint node (`New-AuditCheckpoint.ps1`) immediately following Gate 1 proposal approval and preceding file mutation in the flowchart.
3. **Clarify Task Tier Boundaries**:
   - Update tier definition tables to define Tier 2 by module boundary crossings (more than 1 module or more than 2 non-test files) or architectural changes, preserving autonomous Tier 1 execution for single-module logic fixes.
4. **Prune Unneeded Skills from Localization Agent**:
   - Remove `coding-standards` from `l10n-humanizer/agent.md`, focusing its instructions on resource encoding and format validation.
   - Retain optional plugin skill references in `ui-crafter/agent.md` as dormant bindings that activate when users enable those plugins.
5. **Clarify Review Lifecycle Timing**:
   - Update `handoff-spec.md` to state that proposal documents (Gate 1) are generated after initial diagnostic inspection, strictly before creating the git checkpoint and modifying files.

## Alternatives Considered & Rejected
- **Granting file creation tools to `build-error-resolver`**: Rejected because restricting compiler repair agents to in-place modifications prevents adding empty stub files to bypass type errors.
- **Treating all logic changes as Tier 2**: Rejected because single-module bug fixes run safely and autonomously under Tier 1 with TDD and checkpoint rollback protection.

## Consequences
- **Positive**: Enables delegating Tier 2 implementation to agents that can author new files and update functional logic (`tdd-guide`, `ui-crafter`).
- **Positive**: Correctly visualizes git checkpoint creation before file mutation in orchestration diagrams.
- **Positive**: Resolves definition overlap between single-module fixes (Tier 1) and multi-module refactors (Tier 2).
- **Positive**: Streamlines `l10n-humanizer` instructions by removing unnecessary skill bindings.
