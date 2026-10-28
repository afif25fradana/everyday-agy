# ADR-0013: Teamwork Multi-Agent Engine Graduation and Council Parity

## Status
Accepted

## Date
2026-10-29

## Context
Antigravity's multi-agent runtime engine graduated from its experimental preview status (`teamwork_preview` / `/teamwork-preview`) into official General Availability (`teamwork` / `/teamwork`).

In the updated Antigravity runtime:
1. The slash command is standardized as `/teamwork`.
2. The internal multi-agent subagent engine is invoked via `invoke_subagent(TypeName: "teamwork", ...)`.
3. Invocations targeting legacy `teamwork_preview` risk failure, deprecation warnings, or engine fallback.

Prior ADRs ([ADR-0008](./0008-tri-pillar-council-review-architecture.md) and [ADR-0010](./0010-domain-specific-academic-council.md)) established the Tri-Pillar Council Review and Academic Council frameworks relying on this engine. While the core deliberative lifecycle (Cold Context Grounding $\rightarrow$ Socratic Scoping $\rightarrow$ Autonomous Council Deliberation $\rightarrow$ Victory Certification) remains unchanged, the execution bindings across skills, runbooks, and documentation required synchronization to maintain operational parity.

## Decision
1. **Standardize Subagent Invocation to `teamwork`**:
   - Update `config/skills/council-review/SKILL.md` to dispatch `TypeName: "teamwork"`.
   - Update `config/skills/academic-council/SKILL.md` to dispatch `TypeName: "teamwork"`.
   - Update `audit-dev-workflow/SKILL.md` (Tier 3 routing) to cite `teamwork`.
2. **Harmonize Victory Auditor References**:
   - Update Sentinel victory verification reference in `council-review` to `teamwork_victory_auditor`.
3. **Synchronize Repository Documentation**:
   - Update token consumption warnings and core workflow catalogs in `README.md` to reference `teamwork`.
4. **Preserve Historical Decision Integrity**:
   - Retain original context in historical ADRs (ADR-0007, ADR-0008, ADR-0010) as immutable records of earlier development phases, using ADR-0013 as the authoritative superseding binding.
5. **Enforce Deployment Parity**:
   - Execute `restore.ps1` to propagate all skill and ADR modifications directly into `~/.gemini/config/`.

## Consequences
- **Positive**:
  - Full compatibility with the latest Antigravity runtime releases.
  - Zero disruption to existing Council workflows (`/council`, `/council-review`, `/academic-council`).
  - Clear architectural audit trail documenting engine graduation from preview to GA.
- **Negative / Neutral**:
  - No changes to underlying token economics; multi-agent deliberation still requires significant tokens and should remain gated behind Socratic confirmation.
