# ADR-0014: Adopt TDD Discipline, Failure-First Checks, and Anti-Sycophancy

## Status
Partially Superseded by ADR-0022 (for test creation order relative to git checkpoints)

## Date
2026-10-30

## Context
When evaluating the external `superpowers` plugin, several platform mismatches made direct installation unsuitable: it relied on POSIX shell scripts (`.sh`), physical git worktrees (which encounter file-locking issues on Windows hosts), large bootstrap instructions that added significant token overhead, and autonomous loops that bypassed human review gates.

However, the plugin contained practical testing rules and review habits: requiring a failing test before writing implementation code, verifying that tests fail for the intended reason, and removing conversational filler from code review discussions. Rather than installing the full plugin, these useful practices were adopted directly into existing skills.

## Decision
1. **Strengthen Test-Driven Development Discipline (`tdd-guide`)**:
   - Require observing a failing test before writing implementation code. If code is authored without a failing test, revert it and establish the test first.
   - Include a concise checklist of rationalizations to avoid when testing.
   - Verify that tests fail specifically due to missing functionality rather than syntax errors, typos, or import mistakes.
   - Retain `model: flash` for `tdd-guide` to keep routine test authoring fast (ADR-0004, ADR-0012).
2. **Update Development Workflow Guidance (`audit-dev-workflow`)**:
   - Trace caller call-stacks and log boundary inputs when investigating bugs.
   - Replace legacy subagent names with current custom specialist roles (`system-architect`, `code-auditor`, `tdd-guide`) and atomic Git Checkpoints (`New-AuditCheckpoint.ps1`).
   - Remove performative praise (`"You're absolutely right!"`, `"Great point!"`) from code reviews; evaluate feedback on technical merits and minimal diff size.
   - Run project-wide test suites (`rtk npm test`, `rtk python -m pytest`) to catch regressions, preserving the static check fallback (`[TEST HARNESS: NONE]`) when no test runner is configured.
   - Apply a 2-attempt limit before pausing to request operator guidance when fixing automated check failures.
3. **Enhance Planning and Specification Guidance (`spec-kit`)**:
   - In `/speckit.specify`, focus scoping questions on concrete requirements and constraints without restating prompts.
   - In `/speckit.plan`, map identified edge cases directly to specific test tasks.
4. **Refine Coding and Documentation Standards (`clean-docs`, `coding-standards`)**:
   - In `clean-docs`, discourage performative praise and conversational filler in review dialogs and commit messages.
   - In `coding-standards`, prefer deterministic polling helpers (`waitFor`) over hardcoded sleep timeouts in asynchronous tests.
   - In `documentation-and-adrs`, format guidelines with clear structural requirements and explicit negative rules.

## Alternatives Considered & Rejected
- **Installing the complete superpowers plugin**: Rejected due to Windows file-locking issues with git worktrees and shell script incompatibilities.
- **Relying on prompt text alone for TDD discipline**: Rejected because explicit rules in the testing subagent definition produce more reliable test coverage.

## Consequences
- **Positive**: Adopts practical testing rules without adding third-party plugin bloat.
- **Positive**: Maintains full compatibility with Windows PowerShell 5.1 and pwsh 7.6 without worktree file locks.
- **Positive**: Removes performative filler from code reviews and commit messages.
- **Trade-off**: Requires running full test suites when automated test harnesses exist in the repository.
