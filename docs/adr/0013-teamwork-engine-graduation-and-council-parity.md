# ADR-0013: Standardize Multi-Agent Tool Invocations to teamwork

## Status
Accepted

## Date
2026-10-29

## Context
The Antigravity runtime updated the tool and slash command for its multi-agent feature from `teamwork_preview` to `teamwork`:
1. The slash command is standardized as `/teamwork`.
2. The subagent engine is invoked via `invoke_subagent(TypeName: "teamwork", ...)`.
3. Calls using the older `teamwork_preview` name risk deprecation warnings or runtime errors.

Prior ADRs ([ADR-0008](./0008-tri-pillar-council-review-architecture.md) and [ADR-0010](./0010-domain-specific-academic-council.md)) established review panels relying on this engine. The invocation references across skills, runbooks, and documentation required updating to match the current runtime naming.

## Decision
1. **Update Subagent Invocation to `teamwork`**:
   - Update `config/skills/council-review/SKILL.md` to dispatch `TypeName: "teamwork"`.
   - Update `config/skills/academic-council/SKILL.md` to dispatch `TypeName: "teamwork"`.
   - Update `audit-dev-workflow/SKILL.md` to cite `teamwork` for large review panels.
2. **Standardize Role and Verification References**:
   - Align verification references in `council-review` with the `teamwork` runtime.
3. **Update Documentation**:
   - Update workflow documentation in `README.md` to reference `/teamwork`.
4. **Preserve Historical Decision Context**:
   - Retain earlier ADRs (ADR-0007, ADR-0008, ADR-0010) as historical records, using ADR-0013 to document the name update.
5. **Update Deployment Configurations**:
   - Run `restore.ps1` to deploy updated skill configurations into `~/.gemini/config/`.

## Alternatives Considered & Rejected
- **Maintaining compatibility aliases**: Rejected because runtime tools are defined by the host environment; updating invocations directly prevents deprecated tool call failures.

## Consequences
- **Positive**: Maintains compatibility with current Antigravity runtime tool names.
- **Positive**: Prevents deprecation warnings and failed subagent invocations.
- **Trade-off**: Multi-agent sessions consume significant tokens and remain gated behind explicit user confirmation.
