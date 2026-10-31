# ADR-0015: Checkpoint-Gated Autonomous Execution, AST Safety Fortification, and Dynamic Subagent Elevation

## Status
Accepted

## Date
2026-10-31

## Context
Under the previous workflow regime governed by `GEMINI.md#L42` and `audit-dev-workflow` (ADR-0007, ADR-0009), all repository file mutations strictly required prior explicit human operator approval in chat ("Gate 1"), even for trivial documentation fixes or contained single-module enhancements. This policy originated from rational fears of generative model hallucination, boundary violations, and context-window attention degradation ("fatigue") on long-running multi-turn sessions.

However, forensic multi-perspective Council deliberation (5 Specialist Seats) and adversarial peer review identified that this "pre-mutation speculative text approval" created severe review friction (requiring the operator to review a text promise rather than an actual code diff) while leaving critical security gaps open:
1. **Porous AST Shell Sandbox**: `Test-PowerShellCommandSafety.ps1` exhibited 13 distinct bypass vectors (module-qualified cmdlet invocations, `.exe` suffixes, parameter splatting `@var`, secondary subshells `cmd /c` and `powershell -Command`, and displaced git global path flags).
2. **Ghost Artifact Trap & Rollback Catch-22**: `New-AuditCheckpoint.ps1` suppressed git errors via `2>$null | Out-Null`, while `Restore-AuditCheckpoint.ps1` ran `git reset --hard` which left task-created untracked files behind. Because `Test-PowerShellCommandSafety.ps1` strictly blocked `git clean -f`, the agent was trapped in an unresolvable dirty-tree deadlock.
3. **Subagent Cognitive Downgrade Hazard**: Proposing to hardcode `model: pro` in subagent manifests (`spec-verifier`, `database-reviewer`) violated ADR-0004 and ADR-0012, forcing subagents to downgrade to Gemini 3.1 Pro whenever the parent session ran on top-tier frontier models such as Claude Sonnet 4.6 (Thinking) or Gemini 4 Argon.
4. **False Green Exit Code 0 Fallacy**: Automated test runners could exit with status code 0 when test filters matched zero tests, falsely certifying broken implementations.
5. **Write Boundary Self-Lockout**: Naive restrictions on writing outside the workspace root threatened to break Antigravity UserFacing Artifacts (`~/.gemini/antigravity/brain/...`), session scratch backups, and Twin-Repo `<Project>-AI-Context` synchronization.

## Decision

1. **Adopt Checkpoint-Gated Autonomous Execution (Tier 0 & Tier 1)**:
   - For Tier 0 (`trivial`: $\le 2$ files, $\le 3$ exec or $\le 5$ doc lines, zero logic mutation): Autonomous execution immediately following verified checkpoint creation $\rightarrow$ static verification $\rightarrow$ pause at `[TRIVIAL REVIEW]` before commit. Subagent spawning is bypassed.
   - For Tier 1 (`small`: single-module bugfix/feature): Autonomous execution post-checkpoint $\rightarrow$ Failure-First TDD (RED $\rightarrow$ GREEN) $\rightarrow$ 5-Axis verification $\rightarrow$ pause at Gate 2 (`gate2_handoff.md`) before commit.
   - For Tier 2/3 (`standard`/`large`) & Package Installations: Retain mandatory pre-execution human Gate 1 approval (`gate1_proposal.md`).

2. **Fortify PowerShell AST Command Safety Sandbox (`Test-PowerShellCommandSafety.ps1`)**:
   - Normalize command names by stripping module paths (`Microsoft.PowerShell.Management\Remove-Item` $\rightarrow$ `Remove-Item`) and `.exe` suffixes (`git.exe` $\rightarrow$ `git`).
   - Intercept parameter splatting (`@var`) on destructive cmdlets and git commands.
   - Block secondary command interpreters (`cmd`, `wsl`, `bash`, `sh`) and inline subshell evaluation (`powershell`/`pwsh` with `-Command`/`-c`/`-EncodedCommand`), while explicitly permitting legitimate script execution (`pwsh -File`).
   - Filter git global configuration and path flags (`-C`, `-c`, `--work-tree`, `--git-dir`, `--namespace`) before evaluating subcommands.
   - Block destructive working tree discards (`git checkout -f`, `git restore .`, and force push refspecs `+ref:ref`).
   - Preserve the ADR-0012 exemption for read-only commands, test runners, and routine `rtk git status/diff/add/commit`.

3. **Eliminate Ghost Artifacts & Fail-Closed Checkpoints**:
   - `New-AuditCheckpoint.ps1`: Validate that the tracked working tree is clean (`git status --porcelain -uno`), eliminate `2>$null`, verify `$LASTEXITCODE == 0`, and snapshot untracked files into scratch (`untracked_baseline.txt`).
   - `Restore-AuditCheckpoint.ps1`: Verify `$LASTEXITCODE == 0` upon `git reset --hard`, compare against `untracked_baseline.txt`, and selectively remove only task-created untracked artifacts (`Remove-Item -LiteralPath $cleanRel -Recurse -Force`) without invoking blind `git clean -f`.

4. **Codify Dynamic Flash-to-Pro Elevation over Hardcoding**:
   - Preserve `model: inherit` across all agent manifests (`spec-verifier`, `database-reviewer`, `system-architect`, `code-auditor`, `silent-failure-hunter`) per ADR-0004 & ADR-0012 to inherit Claude Sonnet 4.6 (Thinking) or Gemini 4 Argon parent sessions without downgrade.
   - Enforce **Dynamic Flash-to-Pro Elevation** in `subagent-patterns.md`: when the parent session runs on `Gemini 3.8 Flash`, pass `Model: "pro"` dynamically at invocation time for `spec-verifier` (bound to mandatory Context7 MCP live documentation retrieval) and `database-reviewer`.

5. **Enforce Semantic Test Integrity & Write Boundaries**:
   - Redefine Definition of Done: test verification requires exit code 0 AND positive assertion count ($>0$ passed, $0$ failed/skipped). Mutating or weakening test assertions during the GREEN phase is prohibited.
   - Codify explicit Write Path Boundaries in `GEMINI.md`: allow mutations exclusively within the active repository root, sibling `<Project>-AI-Context` repository, and Antigravity `brain`/`scratch` directories, acknowledging both Parent (`edit_file`/`write_file`) and Subagent (`replace_file_content`/`write_to_file`) tool dualism.

6. **Deployment & Clean Synchronization**:
   - Add `.agents/` internal teamwork scratch directories to `.gitignore`.
   - Maintain full deployment parity via `restore.ps1`.

## Consequences

- **Positive**:
  - Dramatically reduces developer review fatigue: routine Tier 0 and Tier 1 tasks are verified on actual code diffs and test evidence at Gate 2, eliminating the speculative pre-execution Gate 1 approval.
  - Hardens the execution perimeter against 13 known shell bypass vectors while preserving necessary build and script executions.
  - Prevents untracked ghost files from poisoning test suites after rollback.
  - Avoids artificial model downgrades when operating under frontier partner models.
  - Protects Antigravity UserFacing Artifact generation and Twin-Repo context tracking.
- **Negative / Neutral**:
  - Checkpoint creation strictly fails if the tracked working tree is dirty; developers must commit or stash prior uncommitted work before initiating autonomous tasks.
  - Requires developers to maintain test suites that output positive assertion counts.
