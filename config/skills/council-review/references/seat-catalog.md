# Council Seat Catalog & Agent Mapping (`seat-catalog.md`)

This catalog maps evaluation domains to specialized Antigravity custom subagents (`config/agents/`). Each seat functions as an independent reviewer during Pillar 3 council deliberation.

---

## 1. Primary Council Seats

### Seat 1: Architecture & Topology
- **Mapped Custom Agent**: [`system-architect`](../../../agents/system-architect/agent.md)
- **Domain Focus**: Contract-first API design, dependency graphs (DAG acyclicity), modular isolation, zero-downtime refactoring, and Nygard ADR documentation.
- **Evaluation Mandate**: Detects architectural erosion, cyclic imports, leaky abstractions, and protocol mismatches.

### Seat 2: Security & Code Health
- **Mapped Custom Agent**: [`code-auditor`](../../../agents/code-auditor/agent.md)
- **Domain Focus**: Whole-repo health, security attack surface, injection/deserialization vulnerabilities, secret scanner hygiene, and anti-slop code hygiene.
- **Evaluation Mandate**: Audits unbracketed credentials, unvalidated inputs, and generic AI comments.

### Seat 3: Reliability & Silent Failures
- **Mapped Custom Agent**: [`silent-failure-hunter`](../../../agents/silent-failure-hunter/agent.md)
- **Domain Focus**: Swallowed exceptions (bare `catch {}`), masking defaults (`.catch(() => [])`), silent `null` returns on critical paths, and resource leaks (unclosed streams, orphaned subprocesses, unreleased locks).
- **Evaluation Mandate**: Traces unhandled edge cases, timeout drops, and error propagation failures.

### Seat 4: Test Integrity & TDD
- **Mapped Custom Agent**: [`tdd-guide`](../../../agents/tdd-guide/agent.md)
- **Domain Focus**: Test-Driven Development (Red-Green-Refactor), mock-cheating detection, assertion veracity, boundary condition testing, and mutation testing.
- **Evaluation Mandate**: Validates that unit tests verify real state mutations rather than superficial `mock.called` assertions.

### Seat 5: Persistence & Schema
- **Mapped Custom Agent**: [`database-reviewer`](../../../agents/database-reviewer/agent.md)
- **Domain Focus**: SQL schema migrations, indexing strategies, N+1 query traps, zero-downtime expand/contract patterns, and foreign key integrity.
- **Evaluation Mandate**: Identifies unindexed foreign keys, table lock hazards, and data migration bottlenecks.

### Seat 6: Frontend UX & Platform Primitives
- **Mapped Custom Agent**: [`ui-crafter`](../../../agents/ui-crafter/agent.md)
- **Domain Focus**: Web platform primitives, WCAG 2.2 AA accessibility, layout shifts, dark mode, keyboard navigation, and anti-slop UI design.
- **Evaluation Mandate**: Audits ARIA roles, focus states, tap targets, and layout overflow.

---

## 2. Specialized Operational Seats

### Seat 7: Documentation & ADR Architecture
- **Mapped Custom Agent**: [`docs-architect`](../../../agents/docs-architect/agent.md)
- **Domain Focus**: Architecture Decision Record (ADR) authoring, progressive disclosure documentation, anti-slop technical copywriting, and AI context synchronization.
- **Evaluation Mandate**: Detects documentation drift, redundant checklists, and bloated rule files.

### Seat 8: Type Safety & Compilation
- **Mapped Custom Agent**: [`build-error-resolver`](../../../agents/build-error-resolver/agent.md)
- **Domain Focus**: TypeScript / compiler error resolution, type soundness, generic constraints, and strict compilation hygiene.
- **Evaluation Mandate**: Ensures zero loose `any` casts, missing type exports, or broken tsconfig paths.

### Seat 9: Dependency & CI Maintenance
- **Mapped Custom Agent**: [`maintenance-bot`](../../../agents/maintenance-bot/agent.md)
- **Domain Focus**: Package dependency hygiene, CVE vulnerability mitigation, Dependabot PR triage, and CI failure diagnosis.
- **Evaluation Mandate**: Spots deprecated runtime targets (EOL Node/Python) and broken CI actions.

---

## 3. Recommended Seat Bundles by Task Type

| Task Type | Recommended Council Composition |
| :--- | :--- |
| **Architectural / Refactoring Audit** | `system-architect` + `code-auditor` + `docs-architect` + `silent-failure-hunter` |
| **Security & Vulnerability Audit** | `code-auditor` + `silent-failure-hunter` + `maintenance-bot` |
| **New Feature / Greenfield PR Review** | `system-architect` + `tdd-guide` + `code-auditor` + `ui-crafter` |
| **Database & Schema Modification** | `database-reviewer` + `system-architect` + `silent-failure-hunter` |
| **Skill & Workflow Tooling Audit** | `system-architect` + `code-auditor` + `docs-architect` + Community Benchmark |
