# ADR-0008: Multi-Perspective Architecture and Pre-Release Review Board

## Status
Accepted

## Date
2026-10-22

## Context
Single-perspective reviews and audits can miss blind spots, edge cases, and cross-cutting concerns. While external tooling ecosystems often use multi-agent committee patterns, they typically rely on external runtimes or containerized setups.

Antigravity provides specialized custom subagents (`system-architect`, `code-auditor`, `silent-failure-hunter`, `tdd-guide`, `database-reviewer`, `ui-crafter`, `docs-architect`, `build-error-resolver`, `maintenance-bot`) operating with inherited model capabilities (ADR-0004). However, there was no standardized structure to convene these specialists into a coordinated, multi-perspective review panel for high-stakes evaluations.

## Decision
1. **Establish a Structured Multi-Perspective Review Workflow (`council-review`)**:
   - **Phase 1: Codebase Fact-Mapping**: Map codebase invariants, assumptions, and caller topology (`audit-context-building`) before starting review discussions.
   - **Phase 2: Review Scoping**: Select 3 to 5 domain-specific review roles based on the task scope (e.g. security, performance, ergonomics) and set explicit acceptance criteria.
   - **Phase 3: Independent Evaluation and Synthesis**: Run specialized review roles in parallel, verify line citations against current source code, score findings against defined criteria, and synthesize an actionable finding matrix.
2. **Enforce Read-Only Boundary**:
   Review panel sessions are strictly diagnostic. No file edits or package installations take place during the review.
3. **Standardize Output Structure**:
   Require review summaries to include a structured scorecard (Rigor, Ergonomics, Token Efficiency, Spec Alignment), a prioritized Gap Matrix (Critical, High, Medium, Low), and an actionable remediation roadmap.

## Alternatives Considered & Rejected
- **Ad-hoc unstructured reviews**: Rejected because open-ended reviews lack consistency and frequently miss cross-cutting edge cases.
- **Granting write access during reviews**: Rejected to preserve clear separation between diagnostic review and implementation phases.

## Consequences
- **Positive**: Combines diverse perspectives across security, architecture, and ergonomics before merging high-stakes changes.
- **Positive**: Checks line citations against current code to prevent inaccurate review comments.
- **Positive**: Reuses existing specialized agent definitions rather than generic prompts.
- **Trade-off**: Incurs higher token consumption and latency compared to a single-agent review.
