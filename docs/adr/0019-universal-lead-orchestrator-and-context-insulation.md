# ADR-0019: Universal Lead Orchestrator Protocol, Parent Context Insulation, and Adaptive Subagent Fleet Governance

## Status
Accepted (Partially Superseded by ADR-0020 and ADR-0021)
## Date
2026-11-03

## Context
In multi-turn software engineering, deep codebase audits, and cross-cutting refactoring workflows, unconstrained Parent Agents suffer from a recurring systemic failure mode: **Greedy Inline Reading**.

When the Parent Agent directly inspects implementation files across complex codebases:
1. **Context Window Exhaustion & Attention Drift**: Ingesting raw application code inflates Parent context by 20,000–80,000 tokens per session. This triggers LLM "attention fatigue" and middle-loss phenomena, causing the model to skip AST command safety verification, overlook 2-attempt stop rules, hallucinate test passes, and miss subtle caller regressions.
2. **Cognitive Split-Brain**: The Parent Agent attempts to simultaneously serve as high-level system architect, project manager, line-by-line syntax editor, and verification auditor. This dual identity leads to unverified completion claims, dropped edge cases, and premature commits.
3. **Turn-1 Triage Loophole & Subagent Inheritance Ambiguity**: Because `SKILL.md` bodies use progressive disclosure (ADR-0017), generic rules in `GEMINI.md` instructing agents to "read target files before editing" cause the Parent to read source files in Turn 1 before loading `/orchestrator`. Conversely, because subagents inherit global rules, naively forbidding "the agent" from reading code would paralyze subagents from performing their duties.
4. **Subagent Fleet Underutilization**: While `everyday-agy` maintains an 11-agent specialized fleet (ADR-0018) and Antigravity multi-agent teamwork capabilities, existing runbooks (`audit-dev-workflow/SKILL.md#step-0-blast-radius-size-tiered-pipeline-routing`) treat subagents as merely "optional on-demand," lacking an authoritative routing protocol.

## Decision

1. **Establish Standalone Universal Lead Orchestrator Skill (`/orchestrator`)**:
   - Create `config/skills/orchestrator/SKILL.md` with an ADR-0018 compliant frontmatter description ($\le 128$ characters, exactly 115 characters / 115 bytes):
     ```yaml
     ---
     name: orchestrator
     description: Meta-orchestrator protocol for Parent Agent: task decomposition, context insulation, and subagent fleet governance.
     ---
     ```
   - Position `/orchestrator` as an overarching protocol governing Parent Agent behavior across all domain workflows (`audit-dev-workflow`, `spec-kit`, `council-review`, and release audits).

2. **Enforce Parent Context Insulation Invariant via Tool Dualism**:
   - For all Tier 2 (`standard`) and Tier 3 (`large`) tasks, the **Parent Agent** (distinguished in runtime by possessing `invoke_subagent` and `read_file`) is strictly prohibited from calling `read_file` or `view_file` on application source code (`src/**`, `core/**`, `web/**`, `lib/**`, business logic implementations).
   - Parent Agent is restricted to reading ONLY:
     a) High-level coordination state (`task_state.md`, ADR files, top-level manifests like `package.json`/`pyproject.toml` without implementation code).
     b) Intermediate subagent deliverables in scratch (`~/.gemini/antigravity/scratch/` or `<appDataDir>\brain\<conversation-id>\scratch\`).
     c) Git tracking receipts (`rtk git status --short`, `rtk git diff --stat`).
     d) Terminal execution exit codes and CLI test runner summaries.
   - All deep code reads, syntax analysis, implementation edits, and test authoring are delegated to **Subagents** (distinguished by possessing `view_file`, `replace_file_content`, and `write_to_file`).

3. **Codify the Zero-Read Triage Gate (Step 0)**:
   - Before reading any source file, the Parent Agent classifies task blast radius using zero-read metadata commands only:
     - `rtk git status --short`: modified and untracked file counts.
     - `rtk rg --files` or `rtk rg -l "<symbol>"`: candidate file lists without reading contents.
     - `rtk rg -c "<symbol>"`: caller counts per candidate file.
     - User prompt, issue description, or `task_state.md`.
   - Sizing thresholds:
     - Tier 0 (`trivial`: $\le 2$ files, $\le 3$ exec / $\le 5$ doc lines): Autonomous single-turn Parent execution post-checkpoint. Subagents bypassed.
     - Tier 1 (`small`: 1 module bugfix/enhancement): Autonomous Parent TDD post-checkpoint. Subagents optional on-demand.
     - Tier 2 (`standard`: 2–5 files, internal boundaries): Lead Parent Orchestrator + Direct Specialist Subagents. Parent code reading strictly banned.
     - Tier 3 (`large`: >5 files, cross-cutting schema/architecture): Lead Parent Orchestrator + Single `teamwork` Council Review dispatch.

4. **Codify Adaptive Dual Dispatch with Effort Scaling**:
   - The Parent Agent routes delegated work via two distinct pathways based on blast radius:
     - **Pathway A: Deliberative Multi-Seat Council (Tier 3 / High Stakes)**: Dispatched via `teamwork` with `Role: "Council Review Panel"` to spawn the autonomous multi-agent council (Sentinel, Explorers, Challengers, Victory Auditor) per `council-review/SKILL.md`. Direct specialist agent calls from Parent are prohibited for Tier 3 evaluations.
     - **Pathway B: Focused Domain Specialists (Tier 1 / Tier 2 Execution)**: Dispatched directly via `invoke_subagent` to targeted custom agents from the 11-agent fleet (`system-architect`, `code-auditor`, `tdd-guide`, `silent-failure-hunter`, `spec-verifier`, `build-error-resolver`, `docs-architect`, `l10n-humanizer`, `maintenance-bot`, `database-reviewer`, `ui-crafter`). Invoking `teamwork` for Tier 2 tasks is prohibited.

5. **Standardize the 4-Slot Delegation Contract & Bounded Receipts**:
   - Every subagent dispatch prompt MUST follow the 4-slot structure: `<ROLE_AND_OBJECTIVE>`, `<SCOPE_AND_BOUNDARIES>`, `<TOOLS_AND_ABSOLUTE_SKILL_PATHS>`, and `<RETURN_CONTRACT>`, prefixed with `ROLE_TYPE: SUBAGENT (EXECUTION SPECIALIST)`.
   - Subagents write extensive forensic dossiers to `scratch/` but return a compact $\le 15$-line receipt to chat (`Status`, `Exact Coordinates`, `Caller Blast Radius`, `CLI Test Command`, `Exit Code`, `Assertions`).

6. **Enforce Single-Writer Mutual Exclusion Invariant**:
   - Parallel subagent dispatch is restricted strictly to read-only discovery.
   - Mutating subagents (any agent possessing `replace_file_content` or `write_to_file` targeting workspace files) MUST be dispatched strictly sequentially. Exactly ONE mutating subagent may be active at any given moment to prevent Windows file-locking conflicts (`IOException`) and ensure git rollback atomicity.

7. **Mandate Abnormal Subagent Termination Rollback Guarantee**:
   - On any abnormal subagent termination (timeout, tool error, crash, context truncation, or missing handoff), the Parent Orchestrator must inspect `rtk git status --porcelain -uno`.
   - If tracked modifications exist, Parent immediately executes `Restore-AuditCheckpoint.ps1 -Task "<task>"` before attempting any remediation dispatch, fallback action, or user escalation.

8. **Centralize Monotonic Stop-Rule Accounting ($\le 2$) & Reject Escape Hatches**:
   - The Parent maintains a centralized monotonic `global_attempt_counter` initialized to 0.
   - Any failed fix attempt across ANY delegated subagent or Parent action increments this counter.
   - When `global_attempt_counter == 2`, all automated remediation halts. Parent executes `Restore-AuditCheckpoint.ps1`, documents failure receipts, and pauses asking the human operator for direction.
   - Per `documentation-and-adrs/SKILL.md#zero-nuance-clauses-invariant` (Zero Nuance Clauses), no "emergency escape hatch" reading is permitted.

9. **Codify Parent VCS Receipt Verification & Anti-Mock Cheating Protocol**:
   - The Parent Agent must NEVER accept a subagent's text completion claim at face value.
   - Before accepting delegated work or presenting Gate 2 handoffs, Parent independently verifies:
     1. `rtk git status --short` (verifying modified files match authorized scope).
     2. `rtk git diff --stat` (verifying line insertion/deletion blast radius).
     3. Direct CLI test runner execution: Parent directly executes the verification CLI test command via `run_command`, verifying exit code 0 AND positive assertion count (> 0 passed, 0 failed per ADR-0015).
   - Anti-Mock Cheating: For bug fixes in Tier 2/3, Parent verifies a Repro-First failing test receipt (RED state) authored by `tdd-guide` prior to delegating implementation. Prior to Gate 2, Parent delegates line-by-line diff review to `code-auditor` or `silent-failure-hunter` to audit for mock-cheating, weakened assertions, or deleted tests.
   - Subagent Commit Ban: Subagents are strictly barred from executing `git commit`, `git tag`, or `git push`. Commit authority belongs exclusively to the Parent Agent post-Gate 2.

10. **Testless Repository Operational Fallback (`[TEST HARNESS: NONE]`)**:
    - When automated test runners are absent (e.g. documentation, DevOps configs, prototypes), the verification receipt must record `[TEST HARNESS: NONE]`.
    - Verification is satisfied by static syntax compilation (`python -m py_compile`, `node --check`), static linter execution (`rtk npx eslint`, `cargo check`), or build execution exiting cleanly with code 0.

## Consequences

- **Positive**:
  - Net token reduction of $>50,000$ tokens per complex multi-turn session by insulating Parent context from raw application code.
  - Eliminates context-window attention degradation, ensuring safety rules, stop rules, and checkpoint invariants remain sharp throughout long sessions.
  - Prevents subagent paralysis by explicitly scoping Context Insulation to the Parent Agent via Tool Dualism (`read_file` vs `view_file`).
  - Single-Writer Mutual Exclusion eliminates Windows file-locking conflicts and guarantees atomic git rollback.
  - Completely preserves Tier 0 / Tier 1 autonomous agility without introducing ceremonial friction for small fixes.
- **Negative / Operational Trade-offs**:
  - Sequential dispatch of mutating subagents in Tier 2 introduces higher wall-clock latency compared to raw inline editing, but dramatically improves reliability.
  - Requires subagents to report structured compact receipts rather than conversational prose.

## Alternatives Considered & Rejected

1. **Inlining Orchestration Rules into `audit-dev-workflow/SKILL.md`**:
   - *Rejection Rationale*: Orchestration is a universal capability required across greenfield features (`spec-kit`), council reviews (`council-review`), and release management. Inlining it into `audit-dev-workflow` causes monolithic file bloat and leaves non-audit workflows unanchored.
2. **Emergency Escape Hatch for Localized Code Reading**:
   - *Rejection Rationale*: Allowing Parent to read $\le 30$ lines of code after subagent failure creates a loophole clause that violates the 2-Attempt Stop Rule and `documentation-and-adrs` Zero Nuance Clauses rule. Clean fail-closed escalation is strictly superior.
3. **Hardcoding Orchestration into Tracked Global Prompt (`config/GEMINI.md`)**:
   - *Rejection Rationale*: Injecting multi-agent orchestration instructions into every turn for every workspace burns ~800 tokens globally, directly violating ADR-0018 token optimization goals. Scoped progressive disclosure via `/orchestrator` is strictly superior.
