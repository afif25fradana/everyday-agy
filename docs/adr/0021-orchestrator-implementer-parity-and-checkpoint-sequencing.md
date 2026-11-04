# ADR-0021: Orchestrator Implementer Parity, Checkpoint Sequencing, and Agent Skill Pruning

## Status
Accepted

## Date
2026-11-04

## Context
Following an external audit cross-check and authoritative verification by `spec-verifier` (grounded in Context7 and official documentation standards), three architectural discrepancies and maintenance issues were identified across the orchestration runbooks and agent fleet manifests:

1. **Tier 2 Implementer Inflexibility (`GAP-ORCH-02`)**: In `orchestrator/SKILL.md#L68-L70`, Sequential Mutator `S3` was hardcoded to `build-error-resolver` as the sole "Green Implementation" specialist. However, `build-error-resolver` lacks `write_to_file` and contains strict prompt directives forbidding modifications to business logic or runtime behavior. This created an implementer vacuum for Tier 2 tasks requiring new files or functional logic fixes, contradicting Pathway B operational guidance.
2. **Missing Checkpoint Step in Tier 2 Topology (`GAP-ORCH-03`)**: The Tier 2 Mermaid flowchart transitioned directly from `Gate 1` human approval into `S2` test mutations without depicting the mandatory Git Checkpoint (`New-AuditCheckpoint.ps1`) step required by `audit-dev-workflow` Phase 2 and `GEMINI.md`.
3. **Anti-Rationalization Contradiction with Tier 1 (`GAP-ORCH-04`)**: `orchestrator/SKILL.md#L135` stated that touching `>2 files or logic/state` was Tier 2 by definition. This contradicted Tier 1 definitions (`GEMINI.md#L44` and `audit-dev-workflow/SKILL.md#L17`), which explicitly govern single-module bugfixes (inherently mutating logic/state).
4. **Agent Skill Manifest Hygiene (`GAP-FLEET-02`)**: `l10n-humanizer/agent.md` bound `coding-standards`, which was redundant for UI translation and UX copywriting. Meanwhile, `ui-crafter/agent.md` bindings for optional plugins (`Chrome-DevTools`, `Modern-Web-Guidance`) were affirmed as intentional dormant bindings that activate dynamically when the user toggles on the respective Antigravity plugins.
5. **Gate 1 Lifecycle Sequencing (`GAP-DOCS-02`)**: `handoff-spec.md#L31` incorrectly stated that Gate 1 was generated after Phase 2 Checkpoint creation, rather than strictly before checkpointing and file modification.

## Decision

1. **Modularize Tier 2 Implementer in Orchestrator Topology**:
   - Update the Mermaid diagram in `orchestrator/SKILL.md` to define node `S3` as `Sequential Mutator 2: Implementer (tdd-guide / ui-crafter / build-error-resolver)`.
   - Ensure all node labels follow Mermaid syntax standards by enclosing labels containing HTML linebreaks or punctuation in double quotes (`["..."]`).

2. **Codify Checkpoint Node Prior to Mutator Execution**:
   - Explicitly insert node `Ckpt["Parent Verified Checkpoint (New-AuditCheckpoint.ps1)"]` immediately following Gate 1 approval and preceding Sequential Mutator `S2` in the Tier 2 flowchart.

3. **Harmonize Tier 1 Single-Module Boundary Invariant**:
   - Update row 3 of the Anti-Rationalization Table in `orchestrator/SKILL.md` to define Tier 2 by module boundary crossings (`>1 module or >2 non-test files`) or architectural redesign, preserving autonomous Tier 1 execution for single-module logic fixes.

4. **Prune Unused Skills from L10n Agent Manifest & Preserve Optional UI Plugins**:
   - Remove `coding-standards` from `l10n-humanizer/agent.md`, refocusing its activation gate on resource formatting and encoding integrity.
   - Retain optional plugin skill declarations in `ui-crafter/agent.md` as valid dormant bindings connected to user-toggled Antigravity plugins.

5. **Harmonize Lifecycle Timing in Handoff Specification**:
   - Update `handoff-spec.md#L31` to state that Gate 1 is generated after Phase 1 diagnostic audit, strictly before Phase 2 checkpoint creation and file modifications.

## Consequences

- **Positive**: Eliminates flowchart contradictions and ensures Tier 2 tasks have appropriate execution specialists (`tdd-guide` for logic, `ui-crafter` for UI, `build-error-resolver` for compile errors).
- **Positive**: Visualizes the Git Checkpoint step in orchestration topology, reinforcing rollback safety.
- **Positive**: Resolves definition overlap between Tier 1 and Tier 2.
- **Positive**: Streamlines `l10n-humanizer` prompt overhead while preserving seamless plugin toggle re-activation for `ui-crafter`.
- **Positive**: Preserves CI integrity assertions (11 custom agents, 14 bespoke skills, $\ge 20$ indexed ADRs).
