# ADR-0012: Retain Flash for Tactical Agents and Strip Commit Message Flags

## Status
Partially Superseded by ADR-0015 (for autonomous execution) and ADR-0024 (for AST command validation)

## Date
2026-10-28

## Context
During configuration audits and testing of the command safety script, several operational points required resolution:
1. **Model Selection for Routine Subagents**:
   A proposal suggested migrating all five tactical subagents (`tdd-guide`, `build-error-resolver`, `ui-crafter`, `docs-architect`, `maintenance-bot`) from `model: flash` to `model: inherit`. However, routine execution tasks (compiler fixes, straightforward test runs, small documentation edits) do not require heavy reasoning models and benefit from fast turnaround.
2. **Context Discovery Latency**:
   Sequential instructions for reading initial context files caused multiple turn roundtrips during repository startup.
3. **AST Safety Validator False Positives and Parameter Flags**:
   `Test-PowerShellCommandSafety.ps1` had two issues:
   - Parameter prefix abbreviations (e.g. `Remove-Item -rec`) bypassed parameter checks.
   - Text matching on git invocations produced false positives on benign commit messages that contained flag keywords (e.g. `rtk git commit -m "fix clean -f bug"`).
   - Uncheckpointed `git reset --hard` commands outside designated checkpoint branches needed interception.
4. **Tool Phrasing and Approval Clarification**:
   Documentation phrasing in `audit-dev-workflow` needed alignment so parent and subagent tools remained distinct, and trivial changes (Tier 0) were clarified to require human confirmation before mutating files.

## Decision
1. **Retain Flash for Tactical Subagents**:
   - Reaffirm ADR-0004: keep `model: flash` for tactical agents (`tdd-guide`, `build-error-resolver`, `ui-crafter`, `docs-architect`, and `maintenance-bot`).
   - Keep routine tasks fast and token-efficient, reserving inherited model sessions for architecture planning and deep audits.
2. **Batch Initial Repository Discovery**:
   - Update repository discovery guidance to batch read-only inspections (`task_state.md`, `docs/AGENTS.md`, and `docs/adr/README.md`) into a single turn.
   - Clarify safety trigger wording so read-only commands, test runners, and routine `rtk git` operations run without unnecessary interception.
3. **Harden AST Parameter Checks and Ignore Commit Messages**:
   - Expand `Remove-Item` parameter detection to catch PowerShell prefix abbreviations (`-r` through `-recurse`, `-f` through `-force`) and boolean syntax (`:$true`).
   - Implement argument-aware parsing for `git`/`rtk` commands that strips message payloads (`-m`, `--message`) before inspection, preventing false alarms on commit messages.
   - Intercept short bypass flags (`-n` for `--no-verify`).
   - Allow `git reset --hard` only when targeting designated checkpoint branches (`^(refs/heads/)?checkpoint-[A-Za-z0-9_-]+$`).
4. **Align Tool Phrasing Across Workflow Documents**:
   - Align tool conventions in `audit-dev-workflow`: `read_file`/`edit_file` for parent sessions and `view_file`/`replace_file_content` for subagents.
   - Remove obsolete redirect documentation files.
   - Clarify that human confirmation must precede file modifications even on trivial changes.

## Alternatives Considered & Rejected
- **Migrating all agents to `model: inherit`**: Rejected because routine tasks run faster on Flash and do not warrant higher token usage.
- **Allowing unapproved file edits on small tasks**: Rejected to ensure changes are always reviewed before touching disk.

## Consequences
- **Positive**: Eliminates false positives when committing messages that reference flags or command names.
- **Positive**: Intercepts abbreviated PowerShell parameters and uncheckpointed hard resets.
- **Positive**: Reduces initial discovery turns by batching read-only inspections.
- **Trade-off**: Invocations of `git reset --hard` must target a named `checkpoint-*` branch or be executed manually outside the agent session.
