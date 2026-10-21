# ADR-0004: Subagent Cognitive Model Tiering (`model: inherit`)

## Status
Accepted

## Date
2026-10-22

## Context
All 9 custom subagents originally hardcoded `model: flash`.
While `flash` is fast and token-efficient for routine tasks, it creates a severe cognitive bottleneck when delegated to deep architectural planning (`system-architect`), cross-system security/integrity auditing (`code-auditor`), multi-table zero-downtime migrations (`database-reviewer`), or hidden error analysis (`silent-failure-hunter`).
When a developer runs a session with high-capability flagship models (such as `Gemini 3.8 Flash High` or `Pro`), delegating to these 4 agents forcibly downgraded the agent's reasoning capacity to basic Flash.

## Decision
Adopt a hybrid model tiering strategy:
1. **Cognitive / Deep Reasoning Agents** use `model: inherit`:
   - `system-architect`
   - `database-reviewer`
   - `code-auditor`
   - `silent-failure-hunter`
   *(They automatically scale up or down with whatever model tier the developer chose for the primary session).*
2. **Execution / Tactic / Routine Agents** retain `model: flash`:
   - `build-error-resolver` (focused on minimal typecheck/compiler fixes)
   - `maintenance-bot` (automated dependency and CI triage)
   - `tdd-guide` (mechanical Red-Green-Refactor test cycle)
   - `docs-architect` (technical documentation copywriting)
   - `ui-crafter` (component and layout craft)

## Alternatives Considered & Rejected
- **Hardcoding all agents to `pro`**: Rejected due to high latency and unnecessary cost on simple tactical tasks.
- **Keeping all agents at `flash`**: Rejected due to reasoning degradation on complex architecture and security audits.

## Consequences
- **Positive**: Architects and auditors gain full flagship reasoning power whenever invoked from high-capability sessions without manual model switching.
- **Cost Efficiency**: Routine workers stay lightweight and blazing fast on Flash.
