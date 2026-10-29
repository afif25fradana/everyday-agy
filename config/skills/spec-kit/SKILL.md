---
name: spec-kit
description: >
  Spec-Driven Development (SDD) framework for greenfield features and system planning.
  Enforces a three-phase workflow: specify requirements, architect the technical plan,
  and generate an atomic task checklist before writing code.
  Trigger on /speckit.specify, /speckit.plan, /speckit.tasks, /spec-kit, or "spec-driven", "buat spek fitur".
---

# Spec-Kit (Spec-Driven Development)

A structured specification framework for designing and delivering new features. Complements `audit-dev-workflow` by providing a deliberate, test-first specification phase before any code is generated.

Governed by the minimalist principles of [`GEMINI.md`](../../../GEMINI.md) and Ponytail (anti-slop, YAGNI, shortest working diff).

---

## The Three-Phase Workflow

```
Phase 1: Specify        Phase 2: Plan           Phase 3: Tasks
(/speckit.specify)  ->  (/speckit.plan)     ->  (/speckit.tasks)    -> Implementation
Requirements & ACs       Technical Contracts     Atomic Checklist        Red-Green Code
```

All artifacts are persisted in `specs/<feature_name>/` within the project root.

---

## Phase 1: `/speckit.specify`

Focus on **WHAT** is needed and **WHY**, without prescribing internal implementation details or prematurely picking libraries.
- **Socratic 1-Question Discipline**: Clarifying turns must end with exactly one focused question to prevent user fatigue.
- **Scope & Constraint Discovery**: Surface implied constraints and cheaper alternative paths in 1–3 lines (strictly zero prompt restating per `GEMINI.md#L35`).
- **Design Gate**: Hard boundary prohibiting code writing or project scaffolding until the user explicitly approves `spec.md`.

Create `specs/<feature_name>/spec.md`:
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

Create `specs/<feature_name>/plan.md`:
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
- **Verification Command**: [Exact command to test, e.g. `npm test` or `python -m pytest`]

## 5. Review Focus (Top 5 Implied Edge Cases & Failure Modes)
- [Identify top 5 implied edge cases, race hazards, or boundary limits; each must map to an atomic test task in tasks.md]
```

---

## Phase 3: `/speckit.tasks`

Break down the plan into a sequential, atomic checklist where each task represents an incremental, testable step.

Create `specs/<feature_name>/tasks.md`:
```markdown
# Tasks: [Feature Name]

## Milestone 1: Contracts & Scaffolding
- [ ] Task 1.1: Add schema/types for [Contract]
- [ ] Task 1.2: Add failing unit tests covering R1 and R2 (Red)

## Milestone 2: Implementation & Verification
- [ ] Task 2.1: Implement minimal business logic to pass tests (Green)
- [ ] Task 2.2: Refactor for lean code, remove temporary stubs (Refactor)

## Milestone 3: Review & Handoff
- [ ] Task 3.1: Execute full test suite and verify 100% exit code 0
- [ ] Task 3.2: Create PR using `gh-workflow`
```

---

## Execution Guardrails

1. **Never Skip to Code**: Wait for explicit user confirmation on `spec.md` before generating code.
2. **Minimalist Requirements**: Only specify what the user actually cares about. Avoid over-constraining the agent with unnecessary abstractions.
3. **Trace Back to Acceptance Criteria**: Every task in `tasks.md` must link back to at least one acceptance criterion in `spec.md`.
