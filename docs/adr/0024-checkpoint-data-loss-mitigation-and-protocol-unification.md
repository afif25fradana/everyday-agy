# ADR-0024: Checkpoint Data-Loss Mitigation, AST Hardening, and Protocol Unification

## Status
Accepted

## Date
2026-11-08

## Context
A review of the everyday-agy development harness identified seven gaps across rollback reliability, command safety checks, runbook coordination, and repository consistency:
1. **Checkpoint Data-Loss and Staging Collisions**: Checkpoint restoration (`Restore-AuditCheckpoint.ps1`) previously ran `git reset --hard $branchName` directly. If untracked files had been staged or mixed with modified files during work, the hard reset deleted uncommitted files. Checkpoint scripts also invoked git through `rtk git`, adding unnecessary output filtering and proxy dependencies to critical rollback commands.
2. **AST Command Interception Gaps**: `Test-PowerShellCommandSafety.ps1` checked raw token text rather than resolved string values for file deletion paths, allowing variable expansions or complex path expressions to bypass directory boundary checks. Additionally, `git branch -f` allowed force-updating arbitrary branches outside designated checkpoint branches (`checkpoint-*`). Destructive commands such as `git worktree remove -f`, `git stash clear`, `robocopy /MIR`, COM object creation (`New-Object -ComObject`), and WMI process creation (`Win32_Process.Create`) were also unblocked.
3. **Missing Runbook Loading in Orchestration**: Core coordination standards (the zero-decision rule, 4-bucket resolution taxonomy, settled finding immunity, and failed reviewer accounting from ADR-0023) were documented in `orchestrator/SKILL.md` and `handoff-spec.md`, but complex tasks often began without explicitly reading these files, leading to missed review requirements.
4. **Premature Workspace Files in Spec-Kit**: `spec-kit` originally directed creating specification files (`specs/<feature_name>/*.md`) directly in the workspace during planning (`/speckit.specify`, `/speckit.plan`, `/speckit.tasks`) before establishing a rollback checkpoint. This left untracked files in the working tree prior to review approval.
5. **Duplicate Review Documentation in Spec-Kit**: When starting greenfield features with `spec-kit`, contributors had to write both the spec-kit files (`spec.md`, `plan.md`, `tasks.md`) and a separate `gate1_proposal.md`, creating duplicate review paperwork.
6. **Review Context Boundaries in Differential Reviews**: Guidance in `differential-review/methodology.md` loosely suggested reading diffs directly without distinguishing between small changes and multi-file refactors, risking context overload on large changes where line-by-line inspection should be delegated to specialized review passes.
7. **YAML Parsing Ambiguity and Relative Link Inconsistencies**: Unquoted YAML frontmatter descriptions containing colon-space sequences (`: `) broke strict YAML parsers. In addition, relative Markdown links to ADRs differed inconsistently between skill root folders (3 levels: `../../../docs/adr/`) and nested reference directories (4 levels: `../../../../docs/adr/`), and `sync.ps1` did not delete obsolete ADR files when mirroring from `~/.gemini/docs/adr/`.

## Decision

1. **Raw Git Calls in Checkpoint Scripts**:
   - Changed `Invoke-GitCmd` in `New-AuditCheckpoint.ps1` and `Restore-AuditCheckpoint.ps1` from `rtk git` to direct `git @Arguments`. Rollback scripts are internal safety utilities that require direct execution without output filtering or wrapper overhead.

2. **Two-Stage Rollback with Mixed Reset Pre-Step**:
   - In `Restore-AuditCheckpoint.ps1`, run a mixed reset (`git reset $branchName`) immediately before `git reset --hard $branchName`.
   - This unstages all staged files against the target checkpoint commit first. Untracked files that were staged during an incomplete run are demoted back to untracked status before the hard reset runs, preventing unintended file deletion.

3. **AST Command Safety Hardening (`Test-PowerShellCommandSafety.ps1`)**:
   - Resolve path variables to string values before evaluating filesystem root boundaries.
   - Restrict `git branch (-f|--force)` to allow force-updating branch pointers only when the branch name matches `^checkpoint-[A-Za-z0-9_-]+$`.
   - Block `git worktree remove (-f|--force)`, `git stash clear`, `robocopy /MIR`, and COM object creation (`New-Object -ComObject`).
   - Block WMI process creation patterns (`Win32_Process.Create` and `wmiclass.Create`).
   - Block dangerous .NET file and directory deletion calls (`[System.IO.Directory]::Delete`, `[System.IO.File]::Delete`).

4. **Mandatory Runbook Loading for Multi-File Changes**:
   - In `config/skills/audit-dev-workflow/SKILL.md`, add a mandatory step requiring the orchestrator to load `config/skills/orchestrator/SKILL.md` and `config/skills/audit-dev-workflow/references/handoff-spec.md` before starting Tier 2 (standard) and Tier 3 (large) tasks.
   - Ensure the review requirements from ADR-0023 (the zero-decision rule, alternatives considered, 4-bucket resolution taxonomy, settled finding immunity, and accounting for unrun checks) are applied before review proposals are finalized.

5. **External Spec-Kit Drafting and Gate 1 Equivalence**:
   - Direct `spec-kit` planning phases (`/speckit.specify`, `/speckit.plan`, `/speckit.tasks`) to draft review documents in session artifact storage rather than the working tree. No workspace files are written before proposal approval and checkpoint creation.
   - Establish Gate 1 equivalence: an approved spec-kit document set (`spec.md`, `plan.md`, `tasks.md`) satisfies Gate 1 review requirements without writing a separate `gate1_proposal.md`.
   - Move repository file creation of `specs/<feature_name>/*.md` to post-checkpoint implementation alongside the first test cases.

6. **Differential Review Scope Alignment**:
   - Update `config/skills/differential-review/methodology.md` to clarify that direct file reading applies to small (Tier 0/1) changes, while multi-file reviews should delegate line-by-line inspection to review subagents.

7. **Frontmatter YAML Quoting, Relative Link Parity, and Sync Pruning**:
   - Require quote wrapping for any YAML frontmatter description that contains colon-space sequences (`: `).
   - Standardize relative ADR links to 3 levels (`../../../docs/adr/`) from skill roots and 4 levels (`../../../../docs/adr/`) from nested references.
   - Update `sync.ps1` to mirror `~/.gemini/docs/adr/` into `docs/adr/` and remove obsolete ADR files.

8. **Programmatic Diff Injection**:
   - Unified diff blocks in handoff documents should not be manually typed, avoiding transcription errors and truncated context.
   - Templates use `{{VERBATIM_GIT_DIFFSTAT}}` and `{{VERBATIM_GIT_DIFF}}` placeholders, mark untracked files with `git add -N`, and replace placeholders directly on disk using Git diff output (further formalized in ADR-0025).

## Alternatives Considered & Rejected
- *Retaining `rtk git` in Checkpoint Scripts*: Rejected because `rtk` is designed for console output compression. Wrapping automated safety scripts introduced unnecessary dependencies and brittle parsing in automated environments.
- *Manual Diff Authoring in Handoffs*: Rejected because manually typing diffs causes transcription mistakes, drops context lines, and wastes output limits.
- *Writing Spec-Kit drafts into temporary repository folders*: Rejected because temporary files dirty the Git working tree before a checkpoint exists. Drafting in external session artifacts keeps the repository clean until review approval.
- *Requiring a Separate Gate 1 Proposal with Spec-Kit*: Rejected because it created duplicate paperwork. The spec-kit documents already provide the requirements, architecture decisions, and task plan needed for review.

## Consequences
- **Positive**: Prevents uncommitted file loss during `Restore-AuditCheckpoint.ps1` rollbacks.
- **Positive**: Hardens command validation against WMI/COM process execution, arbitrary branch force-moves, and dangerous file deletions.
- **Positive**: Unifies Spec-Kit planning with Gate 1 reviews without dirtying the working tree.
- **Positive**: Prevents YAML syntax errors in CI and fixes relative ADR links across directory depths.
- **Neutral / Operational Requirements**: When using Spec-Kit, an approved specification set satisfies Gate 1 and moves directly to checkpointing without a duplicate proposal document.
