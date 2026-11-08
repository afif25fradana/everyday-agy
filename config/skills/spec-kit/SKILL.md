---
name: spec-kit
description: "Spec-Driven Development (/speckit.specify, .plan, .tasks) for greenfield features: requirements, tech plan, and task checklist."
---

# Spec-Kit (Spec-Driven Development)

A structured specification framework for designing and delivering new features. Complements `audit-dev-workflow` and `orchestrator` by providing a deliberate, test-first specification phase before any application code is generated.

Governed by the minimalist principles of `config/GEMINI.md` (`~/.gemini/GEMINI.md`) and Ponytail (anti-slop, YAGNI, shortest working diff).

---

## The Three-Phase Workflow

```
Phase 1: Specify        Phase 2: Plan           Phase 3: Tasks
(/speckit.specify)  ->  (/speckit.plan)     ->  (/speckit.tasks)    -> Implementation
Requirements & ACs       Technical Contracts     Atomic Checklist        Red-Green Code
```

- **Antigravity UserFacing Artifacts Exclusively**: Phases 1–3 (`/speckit.specify`, `/speckit.plan`, `/speckit.tasks`) draft outputs exclusively as Antigravity UserFacing Artifacts in the conversation artifact directory (`<appDataDir>\brain\<conversation-id>/`). Zero workspace files are written before the Phase 2 audit checkpoint (`New-AuditCheckpoint.ps1`).
- **Gate 1 Satisfaction**: An approved spec-kit artifact trilogy (`spec.md` + `plan.md` + `tasks.md`) formally satisfies Gate 1 of `audit-dev-workflow` (no redundant `gate1_proposal.md` is drafted).
- **Post-Checkpoint Workspace Persistence**: Workspace file creation (`specs/<feature_name>/*.md`) occurs post-checkpoint in Phase 3 alongside or immediately preceding the RED repro test.

---

## Phase 1: `/speckit.specify`

Focus on **WHAT** is needed and **WHY**, without prescribing internal implementation details or prematurely picking libraries.
- **Socratic 1-Question Discipline**: Clarifying turns must end with exactly one focused question to prevent user fatigue.
- **Scope & Constraint Discovery**: Surface implied constraints and cheaper alternative paths in 1–3 lines (strictly zero prompt restating per `GEMINI.md#L35`).
- **Design Gate**: Hard boundary prohibiting application code writing or project scaffolding until the user explicitly approves `spec.md`.

Draft artifact `<appDataDir>\brain\<conversation-id>/spec.md`:
```markdown
# Specification: [Feature Name]

## 1. Problem Statement & User Value
- [1-2 sentences on what problem this solves and for whom]

## 2. User Scenarios
- **Scenario 1**: Given [context], When [action], Then [outcome].
- **Scenario 2**: Given [edge case], When [action], Then [graceful fallback].

## 3. Core Requirements
- **R1**: [Primary functional requirement - what must happen]
- **R2**: [Secondary requirement or behavioral invariant]
- **R3**: [Constraint - latency, security boundary, or data isolation]

## 4. Acceptance Criteria (Objectively Verifiable)
- [ ] Criterion 1 (e.g. CLI exits with code 0 on valid input)
- [ ] Criterion 2 (e.g. Returns 400 Bad Request on missing fields)
- [ ] Criterion 3 (e.g. Unit tests cover happy and error paths)
```

---

## Phase 2: `/speckit.plan`

Map the specification to the concrete architecture, data contracts, and verification harnesses.

Draft artifact `<appDataDir>\brain\<conversation-id>/plan.md`:
```markdown
# Technical Plan: [Feature Name]

## 1. Architecture & Component Boundaries
- **Modified Components**: [Files or modules being touched]
- **New Modules**: [Only if strictly necessary; prefer stdlib/existing helpers]

## 2. Contracts & Data Models
- **API / CLI Contract**: [Input parameters, payload types, exit codes]
- **Database / Schema Changes**: [Migrations, foreign keys, indexes - zero downtime]

## 3. ADR Gate
- [If this introduces a new external dependency or alters system protocols, trigger an ADR in docs/adr/]

## 4. Verification Harness
- **Test Strategy**: [Unit tests, integration tests, or mock-free CLI invocations]
- **Verification Command**: [Exact command to test, e.g. `rtk npm test` or `rtk python -m pytest`]

## 5. Architectural Invariants & Alternatives
- **The Zero-Decision Rule (Tier 2/3 Scoped)**: The plan must leave zero design or architectural choices to the implementer. All API routes, data structures, dependencies, error codes, and boundary edge cases must be pre-determined. If the implementer must invent designs on the fly, the plan fails review (Tier 0 trivial and Tier 1 small bugfix changes are exempt per blast-radius tiering).
- **Alternatives Considered**: Mandatory evaluation of alternative designs with documented trade-offs explaining why each alternative was rejected.

## 6. Review Focus (Top 5 Implied Edge Cases & Failure Modes)
- [Identify top 5 implied edge cases, race hazards, or boundary limits; each must map to an atomic test task in tasks.md]
```

---

## Phase 3: `/speckit.tasks`

Break down the plan into a sequential, atomic checklist where each task represents an incremental, testable step.

Draft artifact `<appDataDir>\brain\<conversation-id>/tasks.md`:
```markdown
# Tasks: [Feature Name]

## Milestone 1: Contracts & Scaffolding
- [ ] Task 1.1: Establish git checkpoint (`New-AuditCheckpoint.ps1`) and persist `specs/<feature_name>/*.md` to workspace
- [ ] Task 1.2: Add schema/types for [Contract] and add failing unit tests covering R1 and R2 (Red)

## Milestone 2: Implementation & Verification
- [ ] Task 2.1: Implement minimal business logic to pass tests (Green)
- [ ] Task 2.2: Refactor for lean code, remove temporary stubs (Refactor)

## Milestone 3: Review & Handoff
- [ ] Task 3.1: Execute full test suite and verify exit code 0 with > 0 passed assertions
- [ ] Task 3.2: Present Gate 2 (`gate2_handoff.md`) and create PR using `gh-workflow`
```

---

## Execution Guardrails & Stop Condition

1. **Zero Workspace Writes Before Checkpoint**: Phases 1–3 draft outputs exclusively as session artifacts (`<appDataDir>\brain\<conversation-id>/`). Never write workspace files (`specs/<feature_name>/*.md`) or application code prior to Gate 1 approval and `New-AuditCheckpoint.ps1`.
2. **Gate 1 Equivalence**: An approved spec-kit artifact trilogy (`spec.md` + `plan.md` + `tasks.md`) formally satisfies Gate 1 of `audit-dev-workflow`; no redundant `gate1_proposal.md` is drafted.
3. **Post-Checkpoint Persistence**: Workspace file creation (`specs/<feature_name>/*.md`) occurs post-checkpoint in Phase 3 alongside or immediately preceding the RED repro test.
4. **Minimalist Requirements**: Only specify what the user actually cares about. Avoid over-constraining the agent with unnecessary abstractions.
5. **Trace Back to Acceptance Criteria**: Every task in `tasks.md` must link back to at least one acceptance criterion in `spec.md`.
6. **Stop Condition**: Pause after presenting each phase artifact (`spec.md` $\rightarrow$ `plan.md` $\rightarrow$ `tasks.md`) and await user confirmation before advancing to implementation via `orchestrator` / `audit-dev-workflow`.
