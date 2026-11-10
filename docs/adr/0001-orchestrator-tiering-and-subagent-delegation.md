# ADR-0001: Orchestrator Tiering and Subagent Delegation

## Status
Accepted

## Date
2026-11-11

## Context
In my daily `Gemini 3.8 Flash (High)` sessions, letting the main conversation load application files directly for multi-file changes burns through the context window quickly. Once tens of thousands of tokens of implementation code sit in the main thread, attention drifts, safety checks get skipped, and verification claims get sloppy.

Four Antigravity runtime constraints shape how delegation works here:
1. **No nested subagents**: Antigravity's subagent harness is single-tiered, so a subagent cannot spawn worker subagents beneath it. Delegation has to come directly from the Parent session (or through one `teamwork` engine call on Tier 3).
2. **Windows file locks and workspace duplication**: Running concurrent file edits or creating separate git worktrees on Windows hits file-locking `IOException` errors and duplicates heavy folders like `node_modules`.
3. **Tool and model differences**: Parent sessions hold `read_file`, `edit_file`, `write_file`, and `invoke_subagent`, while custom subagents hold `view_file`, `replace_file_content`, and `write_to_file` (except `build-error-resolver`, which omits `write_to_file`). When the Parent runs on `flash`, passing `Model: "inherit"` in `invoke_subagent` keeps the subagent on `flash` instead of upgrading it.
4. **Runbook and dispatch overhead**: Earlier versions split execution rules between `orchestrator` and `audit-dev-workflow` (~40-60% duplicate text), shipped a redundant `subagent-patterns.md` table, wrapped every subagent prompt in a heavy 4-slot template (`ROLE_TYPE: SUBAGENT`, `<ROLE_AND_OBJECTIVE>`, `<SCOPE_AND_BOUNDARIES>`, `<TOOLS_AND_ABSOLUTE_SKILL_PATHS>`, `<RETURN_CONTRACT>`), and burned 40k-60k extra tokens spawning two serial `tdd-guide` sessions for RED then GREEN.

## Decision

I consolidated the execution lifecycle into `config/skills/orchestrator/SKILL.md` paired with `config/GEMINI.md` and `config/skills/orchestrator/references/handoff-spec.md`.

### 1. Zero-Read Triage and Blast Radius Tiering
On the first discovery turn, the Parent reads the coordination files (`task_state.md`, `docs/AGENTS.md` or `architecture.md`, and `docs/adr/README.md`) in parallel. Before reading application files, the Parent classifies task blast radius using zero-read metadata commands (`rtk git status --short`, `rtk rg --files` or `rtk rg -l`, `rtk rg -c`, and `task_state.md`):
- **Tier 0 (`trivial`)**: `<= 2` files, `<= 3` executable lines or `<= 5` doc/comment lines, and zero changes to logic, state, schemas, or security boundaries. Runs autonomously on the Parent fast-path post-checkpoint and pauses at `[TRIVIAL REVIEW]` before commit.
- **Tier 1 (`small`)**: Single-module bugfix or contained enhancement. Runs autonomous Parent TDD post-checkpoint (`New-AuditCheckpoint.ps1` -> RED -> GREEN -> Five-Axis check -> `gate2_handoff.md`); subagents are optional.
- **Tier 2 (`standard`)**: `2-5` non-test files or crossing `> 1` module boundary. Requires read-only exploration, Gate 1 proposal approval before checkpointing, and serialized specialist subagents.
- **Tier 3 (`large`)**: `> 5` files, architectural overhaul, or schema rewrite. Requires one `teamwork` Council Review dispatch (`TypeName: "teamwork"`, `Role: "Council Review Panel"`), Gate 1 approval, and decomposition into sequential Tier 2 work packages.
- **Package Installations & Scope Escalation**: Adding, removing, or upgrading dependencies requires Gate 1 approval regardless of file count. If a Tier 0/1 task turns out to cross module boundaries (`> 1` module or `> 2` non-test files), stop edits, keep the existing `checkpoint-<task>` branch intact, write `gate1_proposal.md`, and wait for approval.

### 2. Context Insulation and Single-Writer Serialization
- **Parent Insulation (Tier 2/3)**: The Parent (`invoke_subagent` present) must not call `read_file` or `view_file` on application source code and must not call mutating tools on workspace files. Parent writes on Tier 2/3 stay strictly inside `<appDataDir>\brain\<conversation-id>\*.md` artifacts and scratch files.
- **Read-Only vs Mutating Subagents**: Read-only explorers (`code-auditor`, `silent-failure-hunter`, `spec-verifier`, `system-architect`) can run in parallel and write only to `scratch/` dossiers. Mutating specialists (`tdd-guide`, `ui-crafter`, `docs-architect`, `l10n-humanizer`, `maintenance-bot`, `build-error-resolver`) run one at a time inside `Workspace: inherit` without duplicating `node_modules`, and they write intermediate reports to `<appDataDir>\brain\<conversation-id>\scratch\<task>\`.

### 3. Five-Phase Execution Lifecycle and Gate Flow
- **Phase 1 (Exploration, Stage 1b Grounding & Gate 1)**: Whenever `code-auditor` or `system-architect` proposes fixes, migrations, or dependencies in `scratch/` (Stage 1a), Parent dispatches `spec-verifier` (Stage 1b, Context7 MCP plus `deep-web-research`) before authoring `gate1_proposal.md`. Tier 2/3 plans follow the **Zero-Decision Rule**: schemas, routes, dependencies, error codes, and edge cases are settled upfront rather than left to the implementer (Tier 0/1 exempt). For greenfield features, `spec-kit` (`/speckit.specify` -> `/speckit.plan` -> `/speckit.tasks`) writes `spec.md`, `plan.md`, and `tasks.md` only as UserFacing Artifacts, which satisfies Gate 1 without a separate `gate1_proposal.md`. Writing those files into `specs/<feature>/*.md` waits until Phase 3, after the checkpoint exists. Gate 1 proposals use `ArtifactMetadata` (`UserFacing: true`, `RequestFeedback: true`) with a 1-3 line chat link.
- **Phase 2 (Checkpoint)**: Establish `checkpoint-<task>` via `New-AuditCheckpoint.ps1` only after Gate 1 approval (or immediately after Step 0 for Tier 0/1) so planning docs and RED tests never dirty the tree pre-checkpoint.
- **Phase 3 (Execution & Single-Pass TDD)**:
  - *Single-Pass TDD (`tdd-guide`)*: For Tier 2/3 features and bugfixes, a single post-checkpoint `tdd-guide` dispatch writes the failing RED test on unmodified production code, runs the test suite to observe the expected failure, writes the minimal GREEN patch, runs the Fast Syntax Gate, verifies `exit code 0` with `> 0` passed assertions (`0` failed), refactors under `ponytail` and `antislop-code`, and returns dual RED/GREEN traces. Separate S2 -> S3 dispatches remain only when test authoring and implementation need distinct specialists (such as `tdd-guide` plus `ui-crafter`). Repositories without automated test runners use `[TEST HARNESS: NONE]` with static compilation, syntax, or build checks.
  - *Specialized Mutators & Documentation*: UI, compiler, and CI tasks go sequentially to `ui-crafter`, `build-error-resolver`, or `maintenance-bot`. Tier 2/3 public docs run `docs-architect` (Mode B) -> `l10n-humanizer` (Scope B) sequentially; routine Mode A updates (`docs/adr/**`, `task_state.md`, topology maps) stay single-pass on `docs-architect`, with optional Scope B prose polish on major ADR rewrites.
  - *Pre-Mutation Fast Syntax Gate*: Quick syntax checks (`node --check` or `rtk npx tsc --noEmit`, `python -m py_compile`, PowerShell `Parser::ParseFile`) catch typos in-turn without consuming the 2-attempt stop-rule counter.
- **Phase 4 & Phase 5 (Verification, 2-Attempt Stop Rule, Gate 2 & Commit Authority)**:
  - `code-auditor` audits the diff against `audit-dev`; `spec-verifier` runs conditionally in Stage 4b only if Phase 3 added unverified external APIs.
  - The Parent runs the CLI verification command directly via `run_command` and confirms `exit code 0` plus `> 0` passed assertions.
  - A centralized `global_attempt_counter <= 2` tracks semantic and test repair failures across the task. At 2 failures, automation stops, Parent executes `Restore-AuditCheckpoint.ps1`, reports verbatim logs, and waits for operator direction (resetting to 0 only upon explicit redirection).
  - Subagents are prohibited from running `git commit`, `git tag`, `git push`, `gh pr create`, `gh pr merge`, or `gh release create`. Parent packages `gate2_handoff.md` with `Update-Gate2Diff.ps1` (see [ADR-0003](./0003-runtime-hooks-command-safety-and-checkpoints.md)), links to it in 1-3 chat lines, commits with Conventional Commits post-approval, and deletes temporary checkpoint branches with `rtk git branch -d`.

### 4. Lean 3-Slot XML Brief, Explicit `Model: "pro"` Override & `## Output`
- Every `invoke_subagent` prompt uses three uppercase XML tags: `<OBJECTIVE>`, `<SCOPE>` (`Targets:`, `Allowed Mutation Paths:`, and `Settled Findings:` restricted strictly to evidence-contested or operator-accepted items), and `<DELIVERABLE>`. Built-in `research` and `self` subagents use the inline fallback list in `orchestrator/SKILL.md`.
- When the Parent runs on `flash`, pass `Model: "pro"` explicitly in `invoke_subagent` to elevate `spec-verifier`, `system-architect`, or `docs-architect` on high-stakes checks.
- I deleted `subagent-patterns.md` (asserted absent by `.github/tests/YamlValidation.Tests.ps1`). Each custom `agent.md` retains `## Mandatory Skill Activation Gate` and ends with a compact 2-line `## Output` section (`<= 15`-line chat summary plus scratch path).

## Alternatives Considered & Rejected
- **Allowing Parent agents to read code inline on Tier 2/3**: Rejected because loading full implementation files into the main session causes context exhaustion and skipped checks.
- **Parallel mutating subagents or git worktrees on Windows**: Rejected due to file-locking collisions (`IOException`) and duplicated `node_modules` installs.
- **Recursive nested subagent pipelines**: Rejected because Antigravity's subagent harness is single-tiered and fails on nested `invoke_subagent` calls.
- **Retaining 4-slot prompt wrappers, `subagent-patterns.md`, and mandatory serial S2 -> S3 TDD turns**: Rejected because they duplicated `agent.md`/`TOOLKIT.md` content and burned 40k-60k redundant tokens per TDD cycle.
- **Requiring Gate 1 on Tier 0/1 or counting syntax typos against the 2-attempt limit**: Rejected because small fixes verify faster against real diffs and minor typos do not warrant full rollback cycles.
- **Writing `spec-kit` drafts into `specs/` pre-checkpoint or requiring a duplicate `gate1_proposal.md`**: Rejected because untracked planning files dirty the working tree before checkpointing and duplicate review paperwork.

## Consequences
- **Positive**: Keeps Parent context focused on coordination, enforces serialized edits and atomic checkpoints, requires verified positive test assertions, and keeps subagent briefs to 3 slots.
- **Negative / Operational Requirements**:
  - Sequential mutation adds slight latency compared to inline edits.
  - Parent sessions running on `flash` must pass `Model: "pro"` explicitly when elevating subagents, and must run verification commands directly rather than trusting subagent prose summaries.
