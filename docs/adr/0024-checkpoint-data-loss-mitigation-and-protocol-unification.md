# ADR-0024: Checkpoint Data-Loss Mitigation, AST Hardening, and Protocol Unification

## Status
Accepted

## Date
2026-11-08

## Context
Across complex multi-turn developer workflows and subagent execution waves, an audit of the everyday-agy core harness revealed seven distinct architectural and operational gaps spanning data loss risks during rollback, AST command interception bypasses, protocol divergence, and CI linting hazards:
1. **Checkpoint Data-Loss & Staging Collisions**: Checkpoint restoration (`Restore-AuditCheckpoint.ps1`) executed `git reset --hard $branchName` directly. If a developer or subagent pre-staged pre-existing untracked files or mixed staged modifications with untracked baseline assets, the hard reset combined with untracked file pruning risked dropping uncommitted developer work. Furthermore, checkpoint scripts invoked git through `rtk git`, creating unnecessary output-compression overhead and proxy dependencies in critical rollback plumbing.
2. **AST Command Interception Gaps**: `Test-PowerShellCommandSafety.ps1` previously analyzed raw token text `$text` for file path deletions rather than normalized string values, allowing variable expansions or complex path expressions to evade directory root boundary checks. Additionally, `git branch -f` permitted arbitrary force-pointing of repository branches beyond designated checkpoint branches (`checkpoint-*`), and commands such as `git worktree remove -f`, `git stash clear`, `robocopy /MIR`, COM object instantiation (`New-Object -ComObject`), and WMI process creation (`Win32_Process.Create`) lacked proactive AST blocking.
3. **Implicit Parent Protocol Loading**: While `orchestrator/SKILL.md` and `audit-dev-workflow/references/handoff-spec.md` established rigorous standards (The Zero-Decision Rule, 4-Bucket Resolution Taxonomy, Settled Finding Immunity, and Failed Reviewer Accounting per ADR-0023), Parent Agents frequently initiated Phase 1 investigations without explicitly loading these runbooks, leading to forgotten Gate 1 requirements and reviewer disputes.
4. **Premature Workspace Pollution in Spec-Kit**: `spec-kit` originally directed the creation of `specs/<feature_name>/*.md` directly within the repository workspace during Phases 1–3 (`/speckit.specify`, `/speckit.plan`, `/speckit.tasks`) before an audit checkpoint was established, leaving untracked speculative specification files in the tree prior to Gate 1 human approval.
5. **Spec-Kit & Gate 1 Workflow Duplication**: When greenfield features used `spec-kit`, teams were forced to draft both the Spec-Kit trilogy (`spec.md`, `plan.md`, `tasks.md`) and a redundant `gate1_proposal.md`, creating ceremonial fatigue and divergent review surfaces.
6. **Context Insulation Drift in Differential Reviews**: Guidance in `differential-review/methodology.md` loosely suggested using `read_file` without reiterating ADR-0019 Parent Context Insulation invariants, risking Parent Agents reading source diffs directly on Tier 2/3 refactors.
7. **YAML Parsing Ambiguity & Relative Link Asymmetries**: Unquoted YAML frontmatter descriptions containing colon-space sequences (`: `) violated strict YAML parsers. Furthermore, relative markdown links to ADRs suffered from depth confusion between top-level skills (3 levels: `../../../docs/adr/`) and nested references (4 levels: `../../../../docs/adr/`), and `sync.ps1` lacked automated pruning of obsolete ADRs when syncing from `~/.gemini/docs/adr/`.

## Decision

1. **Raw Git Plumbing in Checkpoint Scripts**:
   - Revert `Invoke-GitCmd` in `New-AuditCheckpoint.ps1` and `Restore-AuditCheckpoint.ps1` from `rtk git` to raw `git @Arguments`. Checkpoint scripts represent internal safety harnesses requiring direct, uncompressed OS-level execution without external proxy overhead.

2. **Two-Stage Rollback with Mixed Reset Pre-Step**:
   - In `Restore-AuditCheckpoint.ps1`, precede `git reset --hard $branchName` with a mixed reset `Invoke-GitCmd @("reset", $branchName) | Out-Null`.
   - This unstages all staged files against the target checkpoint commit prior to the hard reset, ensuring that pre-existing untracked files staged during a failed attempt are demoted back to untracked status before the hard reset executes, preserving baseline developer work from accidental deletion.

3. **AST Security Engine Hardening (`Test-PowerShellCommandSafety.ps1`)**:
   - Normalize path variables to `$pathVal` before verifying filesystem roots, preventing variable-based evasion.
   - Constrain `git branch (-f|--force)`: strictly allow force-updating branch pointers only when the target branch matches `^checkpoint-[A-Za-z0-9_-]+$`.
   - Intercept and block: `git worktree remove (-f|--force)`, `git stash clear`, `robocopy /MIR`, and dynamic execution via COM objects (`New-Object -ComObject`).
   - Intercept and block WMI process execution patterns (`Win32_Process.Create` and `wmiclass.Create`).
   - Harden member expression blocking for `.NET` file/directory deletion invocations (`[System.IO.Directory]::Delete`, `[System.IO.File]::Delete`).

4. **Mandatory Parent Reference Activation Gate**:
   - In `config/skills/audit-dev-workflow/SKILL.md`, codify an explicit pre-Phase 1 gate requiring the Parent Agent to read `config/skills/orchestrator/SKILL.md` and `config/skills/audit-dev-workflow/references/handoff-spec.md` via `read_file` on all Tier 2 (`standard`) and Tier 3 (`large`) tasks.
   - Enforce compliance with ADR-0023 invariants (The Zero-Decision Rule, Alternatives Considered, 4-Bucket Resolution Taxonomy, Settled Finding Immunity, and `Status: not run` accounting) prior to Gate 1 proposal packaging.

5. **Ephemeral Spec-Kit Artifacts & Gate 1 Fusion**:
   - Mandate that `spec-kit` Phases 1–3 draft exclusively to Antigravity UserFacing Artifacts (`<appDataDir>\brain\<conversation-id>/`). Zero workspace files are written before Gate 1 approval and checkpoint creation (`New-AuditCheckpoint.ps1`).
   - Formalize Gate 1 Equivalence: an approved spec-kit artifact trilogy (`spec.md` + `plan.md` + `tasks.md`) formally satisfies Gate 1 of `audit-dev-workflow`, eliminating the redundant drafting of `gate1_proposal.md`.
   - Defer physical workspace creation of `specs/<feature_name>/*.md` to post-checkpoint in Phase 3 alongside or immediately preceding the RED repro test.

6. **Differential Review Context Insulation Alignment**:
   - Update `config/skills/differential-review/methodology.md` to explicitly state that Parent `read_file` is restricted strictly to Tier 0/1 changes, and Tier 2/3 reviews must delegate line-by-line diff inspection exclusively to `code-auditor` (`view_file`).

7. **Frontmatter YAML Quoting, Relative Link Parity & Sync Pruning**:
   - Enforce YAML syntax safety in `.github/workflows/ci.yml`: any frontmatter description containing `: ` must be wrapped in quotes.
   - Standardize relative ADR links to 3 levels (`../../../docs/adr/`) from skill roots and 4 levels (`../../../../docs/adr/`) from nested references.
   - Update `sync.ps1` to mirror `~/.gemini/docs/adr/` into `docs/adr/` with active pruning of stale ADR markdown files.

8. **Programmatic Diff Injection (Eliminating LLM Diff Typing)**:
   - To eliminate LLM autoregressive paraphrasing and context hallucination inside `write_file`, unified diff blocks in `gate2_handoff.md` must never be typed manually by the model.
   - The workflow mandates that implementers author `gate2_handoff.md` with `{{VERBATIM_GIT_DIFFSTAT}}` and `{{VERBATIM_GIT_DIFF}}` placeholders, mark untracked files via `git add -N .`, and programmatically replace placeholders with raw `git --no-pager diff --stat=140,80 HEAD` and `git --no-pager diff HEAD` directly on disk.

## Alternatives Considered & Rejected
- *Retaining `rtk git` in Checkpoint Scripts*: Rejected because `rtk` is designed for human/model conversational compression; wrapping automated safety scripts introduced brittle output parsing and failure modes in headless environments.
- *Manual Unified Diff Authoring in Gate 2*: Rejected because manual LLM diff re-typing causes autoregressive drift, hallucinates surrounding context lines, and wastes output token budgets.
- *Writing Spec-Kit drafts into `.git/scratch` or temporary repository folders*: Rejected because temporary git-tracked files dirty the working tree and invalidate the zero-diff pre-checkpoint invariant. Drafting inside Antigravity session artifacts provides pure ephemerality with complete user visibility.
- *Separate Gate 1 Proposal Alongside Spec-Kit Trilogy*: Rejected due to process bloat and documentation fatigue. The spec-kit trilogy already contains comprehensive requirements, data contracts, and task plans that strictly supersede the standard `gate1_proposal.md`.

## Consequences
- **Positive**: Eliminates risk of uncommitted file loss during `Restore-AuditCheckpoint.ps1` rollbacks.
- **Positive**: AST engine blocks advanced privilege escalation, process spawning via WMI/COM, and destructive branch/worktree manipulation.
- **Positive**: Streamlines greenfield feature development by unifying Spec-Kit and Gate 1 into a single review pass without workspace pollution.
- **Positive**: Prevents YAML syntax errors in CI and guarantees relative ADR link resolution across all directory levels and deployment paths.
- **Neutral / Operational Requirements**: Parent agents must remember that approving a Spec-Kit trilogy unlocks immediate Phase 2 checkpointing without requiring a duplicate proposal artifact.
