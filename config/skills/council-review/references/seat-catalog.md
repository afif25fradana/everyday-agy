# Council Seat Catalog & Agent Mapping (`seat-catalog.md`)

This catalog maps evaluation domains to specialized Antigravity custom subagents (`config/agents/`). Each seat functions as an independent reviewer during Pillar 3 council deliberation, adhering to the 8 `inherit` / 2 `flash` fleet split per ADR-0002.

---

## 1. Primary Council Seats

### Seat 1: Architecture & Topology
- **Mapped Custom Agent**: [`system-architect`](../../../agents/system-architect/agent.md)
- **Default Model**: `inherit`
- **Domain Focus**: Contract-first API design, dependency graphs (DAG acyclicity), modular isolation, zero-downtime refactoring, and specification modeling (`spec-kit`).
- **Evaluation Mandate**: Detects architectural erosion, cyclic imports, leaky abstractions, and protocol mismatches.

### Seat 2: Security, Code Health & Database Safety
- **Mapped Custom Agent**: [`code-auditor`](../../../agents/code-auditor/agent.md)
- **Default Model**: `inherit`
- **Domain Focus**: Whole-repo health, security attack surface, injection/deserialization vulnerabilities, SQL schema migrations, foreign key indexing, zero-downtime expand/contract patterns, secret scanner hygiene, and anti-slop code hygiene.
- **Evaluation Mandate**: Audits unbracketed credentials, unvalidated inputs, unindexed foreign keys, table lock hazards, and generic AI comments.

### Seat 3: Reliability & Silent Failures
- **Mapped Custom Agent**: [`silent-failure-hunter`](../../../agents/silent-failure-hunter/agent.md)
- **Default Model**: `inherit`
- **Domain Focus**: Swallowed exceptions (bare `catch {}`), masking defaults (`.catch(() => [])`), silent `null` returns on critical paths, and resource leaks (unclosed streams, orphaned subprocesses, unreleased locks).
- **Evaluation Mandate**: Traces unhandled edge cases, timeout drops, and error propagation failures.

### Seat 4: Test Integrity & TDD
- **Mapped Custom Agent**: [`tdd-guide`](../../../agents/tdd-guide/agent.md)
- **Default Model**: `inherit`
- **Domain Focus**: Test-Driven Development (Red-Green-Refactor), mock-cheating detection, assertion veracity, boundary condition testing, and mutation testing.
- **Evaluation Mandate**: Validates that unit tests verify real state mutations rather than superficial `mock.called` assertions.

### Seat 5: Frontend UX & Platform Primitives
- **Mapped Custom Agent**: [`ui-crafter`](../../../agents/ui-crafter/agent.md)
- **Default Model**: `inherit`
- **Domain Focus**: Web platform primitives, WCAG 2.2 AA accessibility, layout shifts, dark mode, keyboard navigation, and anti-slop UI design.
- **Evaluation Mandate**: Audits ARIA roles, focus states, tap targets, and layout overflow.

---

## 2. Specialized Operational Seats

### Seat 6: Documentation & ADR Architecture
- **Mapped Custom Agent**: [`docs-architect`](../../../agents/docs-architect/agent.md)
- **Default Model**: `inherit`
- **Domain Focus**: Architecture Decision Record (ADR) authoring, progressive disclosure documentation, anti-slop technical copywriting, and AI context synchronization.
- **Evaluation Mandate**: Detects documentation drift, redundant checklists, and bloated rule files.

### Seat 7: Type Safety & Compilation
- **Mapped Custom Agent**: [`build-error-resolver`](../../../agents/build-error-resolver/agent.md)
- **Default Model**: `flash`
- **Domain Focus**: TypeScript / compiler error resolution, type soundness, generic constraints, and strict compilation hygiene.
- **Evaluation Mandate**: Ensures zero loose `any` casts, missing type exports, or broken tsconfig paths.

### Seat 8: Dependency & CI Maintenance
- **Mapped Custom Agent**: [`maintenance-bot`](../../../agents/maintenance-bot/agent.md)
- **Default Model**: `flash`
- **Domain Focus**: Package dependency hygiene, CVE vulnerability mitigation, Dependabot PR triage, and CI failure diagnosis.
- **Evaluation Mandate**: Spots deprecated runtime targets (EOL Node/Python) and broken CI actions.

### Seat 9: Official Spec & Remediation Verifier
- **Mapped Custom Agent**: [`spec-verifier`](../../../agents/spec-verifier/agent.md)
- **Default Model**: `inherit` (`pro` on Flash)
- **Domain Focus**: Cross-checking proposed remediation roadmaps, refactoring patterns, third-party library integrations, and architectural fixes against authoritative vendor documentation.
- **Verification Tooling Hierarchy**:
  1. **Primary Tool**: Context7 MCP (`resolve-library-id` -> `query-docs`) to pull authoritative, up-to-date library API signatures and guidelines.
  2. **Secondary Fallback**: Targeted web search (`search_web` focusing on official documentation domains) when Context7 lacks library coverage.
- **Evaluation Mandate**: Validates every action item in the proposed roadmap. Rejects hallucinated APIs, deprecated signatures, obsolete configuration flags, or unverified workarounds before final Chairman certification.

### Seat 10: Software Localization & Humanizer
- **Mapped Custom Agent**: [`l10n-humanizer`](../../../agents/l10n-humanizer/agent.md)
- **Default Model**: `inherit`
- **Domain Focus**: Software localization (L10n), UI translation, Microsoft Indonesian style guide consistency, UX microcopy conciseness, XML/JSON escaping, and bilingual prose humanization (anti-AI writing rules, fact lock).
- **Evaluation Mandate**: Audits localized resource files (`.resw`, `.json`, `.resx`), keyboard mnemonics (`&amp;`), character expansion budgets, and humanized translation flow.

---

## 3. Recommended Seat Bundles by Task Type

| Task Type | Recommended Council Composition |
| :--- | :--- |
| **Architectural / Refactoring Audit** | `system-architect` + `code-auditor` + `docs-architect` + `silent-failure-hunter` + `spec-verifier` |
| **Security & Vulnerability Audit** | `code-auditor` + `silent-failure-hunter` + `maintenance-bot` |
| **New Feature / Greenfield PR Review** | `system-architect` + `tdd-guide` + `code-auditor` + `ui-crafter` + `spec-verifier` |
| **Software Localization / i18n Release** | `l10n-humanizer` + `ui-crafter` + `docs-architect` |
| **Database & Schema Modification** | `code-auditor` + `system-architect` + `silent-failure-hunter` |
| **Library Upgrade / Modernization** | `maintenance-bot` + `build-error-resolver` + `spec-verifier` |
| **Skill & Workflow Tooling Audit** | `system-architect` + `code-auditor` + `docs-architect` + Community Benchmark |
