# ADR-0007: Development Workflow Tooling and Reproducer-First Tests

## Status
Superseded by ADR-0014, ADR-0015, ADR-0022, and ADR-0028

## Date
2026-10-22

## Context
During initial workflow reviews of `audit-dev-workflow`, several tool and execution inconsistencies were identified:
1. **Tool Differences Between Parent and Subagents**:
   The workflow documentation referenced tool names across different agent contexts (`replace_file_content` and `write_to_file` for subagents, versus `edit_file` and `write_file` for parent sessions). Automation helper scripts called raw `git` instead of `rtk git`, and folder slash commands were not cleanly mapped.
2. **Handling Repositories Without Test Harnesses**:
   Strict requirements for automated test commands and exit code 0 caused deadlocks on documentation, configuration, and prototype repositories that lacked automated test suites.
3. **Rollback Script Availability**:
   Git checkpoints were created via `New-AuditCheckpoint.ps1`, but lacked an automated companion script for single-command restoration.
4. **Redundant Reference Documentation**:
   Duplication of evaluation rubrics and task tier criteria across multiple reference files increased token usage and led to version drift.
5. **Verifying Bug Fixes with Reproducer Tests**:
   Bug fixes were sometimes written before confirming that a test could reliably reproduce the reported defect.

## Decision
1. **Document Tool Conventions for Parent and Subagent Execution**:
   - Document tool conventions: parent sessions use `read_file`, `edit_file`, and `write_file`, while subagents use `view_file`, `replace_file_content`, and `write_to_file`.
   - Update `New-AuditCheckpoint.ps1` and helper scripts to prefer `rtk git` with fallback to `git`.
   - Add canonical `/audit-dev-workflow` command mapping to frontmatter.
2. **Allow Static Verification on Repositories Without Test Suites**:
   - Establish the `[TEST HARNESS: NONE]` protocol, allowing static checks (e.g. `python -m py_compile`, `node --check`, linters) or build runs as acceptable verification when no test runner exists.
3. **Add Rollback Script and UI Approval Gating**:
   - Add `Restore-AuditCheckpoint.ps1` for clean one-command recovery (`git reset --hard checkpoint-<task>`).
   - Use `ArtifactMetadata.RequestFeedback: true` in proposal artifacts to support interactive confirmation.
4. **Require Reproducer Tests Before Fixing Bugs**:
   - Require writing a failing test (RED) that reproduces the issue before making bug fixes.
5. **Consolidate Reference Documentation**:
   - Establish `handoff-spec.md` as the single reference schema and trim duplicated text from other reference guides.

## Alternatives Considered & Rejected
- **Requiring test runners on all repositories**: Rejected because documentation, infrastructure, and prototype repositories often do not have unit test frameworks installed.
- **Manual rollback instructions in chat**: Rejected because manual git commands during recovery are error-prone; an automated script ensures consistent restoration.

## Consequences
- **Positive**: Resolves runtime tool mismatches between parent and subagent executions.
- **Positive**: Unblocks automated verification on projects without unit test suites.
- **Positive**: Reduces redundant prompt context across reference files.
- **Trade-off**: PowerShell helper scripts require `-ExecutionPolicy Bypass` when invoked in Windows environments.
