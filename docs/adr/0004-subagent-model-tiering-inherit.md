# ADR-0004: Model Inheritance for Planners and Flash for Routine Tasks

## Status
Partially Superseded by ADR-0027 (tdd-guide elevated to model: inherit; database-reviewer retired into code-auditor)

## Date
2026-10-22

## Context
All custom subagents originally hardcoded `model: flash`.

While `flash` is fast and token-efficient for routine tasks, complex tasks like architectural planning (`system-architect`), cross-system security auditing (`code-auditor`), multi-table database migrations (`database-reviewer`), and subtle bug detection (`silent-failure-hunter`) benefit from higher reasoning capacity. When a developer runs a primary session on a higher-capability model tier, delegating to these four agents unnecessarily constrained their reasoning to base Flash.

## Decision
Adopt a hybrid model tiering strategy:
1. **Planning and Deep Review Agents** use `model: inherit`:
   - `system-architect`
   - `database-reviewer`
   - `code-auditor`
   - `silent-failure-hunter`
   They inherit whatever model tier the developer chose for the primary session.
2. **Routine and Tactical Agents** retain `model: flash`:
   - `build-error-resolver` (compiler and typecheck fixes)
   - `maintenance-bot` (dependency and CI triage)
   - `tdd-guide` (Red-Green-Refactor test authoring)
   - `docs-architect` (technical documentation updates)
   - `ui-crafter` (component and layout craft)

## Alternatives Considered & Rejected
- **Hardcoding all agents to `pro`**: Rejected due to higher latency and unnecessary cost on simple tactical tasks.
- **Keeping all agents at `flash`**: Rejected due to degraded reasoning on complex architecture and security reviews.

## Consequences
- **Positive**: Architects and auditors automatically scale with higher-capability sessions without manual model switching.
- **Cost Efficiency**: Routine tasks remain lightweight and fast on Flash.
