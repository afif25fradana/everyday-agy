# ADR-0020: Restore Gate 1 Human Approval in Tier 2 and Add Pre-Test Syntax Checks

## Status
Partially Superseded by ADR-0021 (for Tier 2 implementer options) and ADR-0022 (for skill count CI parity)

## Date
2026-11-04

## Context
During operational reviews of multi-agent orchestration, several workflow gaps and protocol desynchronizations were identified:
1. **Human Approval Omission in Tier 2 Flowchart**:
   The Tier 2 dispatch diagram introduced in ADR-0019 showed read-only explorers transitioning directly into file modifiers without depicting human proposal approval (Gate 1). This conflicted with core workflow rules that require human approval before modifying files on multi-file tasks (Tier 2/3) or installing packages.
2. **Catalog Documentation in Operational Runbooks**:
   Although ADR-0018 expanded the fleet to 11 custom agents, operational runbooks still used a legacy 3-role table and lacked examples using the standardized 4-slot delegation structure.
3. **Premature Stop-Rule Depletion from Syntax Typos**:
   Under ADR-0019, any failed repair attempt increments the attempt counter (with a limit of two). When agents made minor syntax slips (missing closing braces, indentation errors), running the full project test suite failed, burning a stop-rule attempt. Two small syntax typos could trigger an automatic rollback and user escalation, even though the underlying logic was sound.
4. **Chat Context Pollution from Large Review Payloads**:
   Dumping multi-screen diffs or full proposal documents directly into chat polluted conversation context and made review cumbersome.
5. **Continuous Integration Verification**:
   Continuous integration checks needed strict assertions for agent count (11), skill count (14 at the time), skill description lengths (<= 128 characters), and two-way ADR index consistency.

## Decision
1. **Restore Gate 1 Human Approval in Tier 2 Topology**:
   - Update orchestration diagrams and runbook text to place proposal generation and human approval (Gate 1) immediately following read-only exploration and strictly before file modification.
   - Affirm that package installations require explicit human approval before changing dependency files.
   - For Tier 3 tasks, decompose post-Gate 1 execution into sequential Tier 2 work packages governed by the parent orchestrator.
2. **Add Fast Syntax Checks Before Running Test Suites**:
   - Run lightweight syntax checks before executing full test runners:
     - JavaScript / TypeScript / Node: `node --check <file>` or linter check.
     - Python: `python -m py_compile <file>`.
     - PowerShell: `[System.Management.Automation.Language.Parser]::ParseFile("<file>", [ref]$null, [ref]$err)`.
   - Syntax typos caught by this initial check must be corrected immediately and do not count against the 2-attempt limit, reserving stop-rule counters for actual test or semantic failures.
3. **Update Agent Runbooks with Full Fleet and 4-Slot Prompts**:
   - Update `subagent-patterns.md` to catalog all 11 custom agents in parity with `seat-catalog.md` and ADR-0018.
   - Standardize sample prompts to use the 4-slot structure (`<ROLE_AND_OBJECTIVE>`, `<SCOPE_AND_BOUNDARIES>`, `<TOOLS_AND_ABSOLUTE_SKILL_PATHS>`, `<RETURN_CONTRACT>`) and compact summary receipts.
4. **Package Proposals and Handoffs as Antigravity Artifacts**:
   - Direct proposals and handoffs into Antigravity artifacts:
     - Gate 1: `<appDataDir>\brain\<conversation-id>/gate1_proposal.md` with `ArtifactMetadata.RequestFeedback: true` (providing interactive approval).
     - Gate 2: `<appDataDir>\brain\<conversation-id>/gate2_handoff.md` with `ArtifactMetadata.UserFacing: true`.
   - Keep chat messages concise (1-3 lines) linking to the generated artifact.
5. **Enhance Continuous Integration Checks (`.github/workflows/ci.yml`)**:
   - Assert exact counts: skills (`-ne 14`) and agents (`-ne 11`).
   - Assert ADR count (`-lt 20`) with two-way index validation between `docs/adr/*.md` and `docs/adr/README.md`.
   - Validate skill frontmatter description lengths to ensure each description is 128 characters or fewer.
6. **Symmetric Orphan Pruning in Synchronization**:
   - Port the orphan skill file pruning loop from `restore.ps1` into `sync.ps1` to keep tracked skill directories clean during synchronization.

## Alternatives Considered & Rejected
- **Counting syntax errors against the 2-attempt stop rule**: Rejected because minor typos during active editing are easily resolved before test execution; distinguishing syntax slips from semantic test failures prevents unnecessary rollback cycles.
- **Skipping Gate 1 on multi-file refactors**: Rejected because changes spanning multiple files carry significant blast radius requiring human approval before modifying files.

## Consequences
- **Positive**: Restores required human approval before files are modified in multi-file refactors.
- **Positive**: Prevents premature rollbacks caused by minor syntax typos before running test suites.
- **Positive**: Full 11-agent fleet visibility and standardized 4-slot prompts improve subagent dispatch consistency.
- **Positive**: Packaging Gate 1 and Gate 2 payloads as UserFacing artifacts preserves Parent context insulation and streamlines reviewer interactions.
- **Positive**: CI checks automatically enforce frontmatter token budgets and ADR index parity.
