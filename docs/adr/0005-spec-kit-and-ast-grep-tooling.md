# ADR-0005: Spec-Kit, GitHub Workflow & AST-Grep Integration

## Status
Accepted

## Date
2026-10-22

## Context
The existing Antigravity environment was well-equipped for defensive auditing, bug fixing, and refactoring (`audit-dev-workflow`, `audit-context-building`, `differential-review`), but lacked:
1. A structured generative playbook for building new features from scratch without premature implementation bias.
2. Direct GitHub CLI (`gh`) lifecycle automation despite authenticated `gh` being active.
3. Syntax-aware structural code search for complex multiline refactoring beyond standard regex (`ripgrep`).

## Decision
1. **Adopt Spec-Driven Development (`spec-kit`)**:
   Implement a three-phase workflow for greenfield development:
   - `/speckit.specify` $\rightarrow$ User scenarios & verifiable acceptance criteria in `specs/<feature>/spec.md`.
   - `/speckit.plan` $\rightarrow$ Technical contracts, schemas, and ADR triggers in `specs/<feature>/plan.md`.
   - `/speckit.tasks` $\rightarrow$ Atomic checklist before any code is generated in `specs/<feature>/tasks.md`.
   Wire `spec-kit` to `system-architect`.
2. **Implement `gh-workflow`**:
   Package an operational playbook leveraging authenticated `gh` CLI for non-interactive CI monitoring (`gh run watch --compact`), PR creation with conventional titles, and PR review comments.
   Wire `gh-workflow` to `maintenance-bot`.
3. **Verify and Register `ast-grep` (`sg`)**:
   Install `ast-grep` (v0.51.0) and register it in `GEMINI.md` under verified tools for syntax-tree-accurate multiline AST search/replace.

## Consequences
- **Positive**: Complete feature-authoring lifecycle from spec to PR, backed by AST-level refactoring precision.
