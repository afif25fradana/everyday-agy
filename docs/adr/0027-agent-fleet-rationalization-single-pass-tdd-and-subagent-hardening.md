# ADR-0027: Agent Fleet Rationalization, Single-Pass TDD, and Subagent Hardening

## Status
Partially Superseded (ADR-0029, ADR-0030)

## Date
2026-11-09

## Context
As the `everyday-agy` configuration and orchestration framework evolved across ADR-0004 through ADR-0026, several operational issues, token redundancies, and specification drift emerged:

1. **Fleet Bloat and Skill Overlap**: The fleet expanded to 11 custom subagents. `database-reviewer` existed as a standalone agent with a narrow scope (database schema and migrations) invoked in `<5%` of local-first development workflows, yet requiring dedicated maintenance, CI assertions, and documentation. Concurrently, database migrations and SQL schema changes are first-class source-controlled code, naturally aligning with repository health and attack surface auditing in `code-auditor`.
2. **ADR Ownership Ambiguity**: Both `system-architect` and `docs-architect` claimed authoring authority over `docs/adr/` in their manifests and bound `documentation-and-adrs` and `sync-task-state`. This dual-ownership blurred the separation between pre-execution architectural planning and long-term documentation persistence.
3. **Model Tiering Drift on `tdd-guide`**: While `config/agents/tdd-guide/agent.md` declared `model: inherit` in its frontmatter, its prompt body, `README.md`, `TOOLKIT.md`, and `subagent-patterns.md` described it as `model: flash`. In practice, Tier 2 Test-Driven Development requires multi-file context retention, invariant verification, and complex mock boundary reasoning that exceeds `flash` capabilities.
4. **Subagent Persona Selector Clutter (`mainAgent: false`)**: Official Google Antigravity specifications (`https://antigravity.google/docs/subagents/`) establish that subagents default to `mainAgent: true` when omitted, causing dedicated execution specialists to appear in top-level chat persona selectors. Furthermore, all 11 subagent manifests carried 12–16 lines of `Primary Interactive Mode (ROLE_TYPE Absent)` prompt instructions that were dead weight (~150 tokens per turn) since subagents are never invoked as interactive primary agents.
5. **Phantom Tool Calls (`ask_question`)**: Five subagent manifests instructed the agent to call `ask_question`, despite not possessing the tool in their frontmatter allowlists.
6. **Context Waste in Serial TDD**: `config/skills/orchestrator/SKILL.md` and `subagent-patterns.md` mandated a serial two-stage subagent workflow for code changes: S2 (`tdd-guide` writing a failing RED test) followed by S3 (a fresh `tdd-guide` or implementer writing the GREEN fix). Spawning two consecutive subagents spent 40k–60k redundant tokens re-reading identical files and doubled turn latency.
7. **L10n & Humanizer Capabilities**: While `l10n-humanizer` was introduced in ADR-0018 for Indonesian UI localization, public repository documentation and developer-facing prose frequently suffered from machine-generated writing tells, inflation, and corporate theater.

## Decision

We consolidate the agent fleet, orchestration runbooks, and subagent schemas:

### 1. Fleet Rationalization (11 -> 10 Agents) & Role Boundaries
- **Retire `database-reviewer`**: Delete `config/agents/database-reviewer/`. Absorb database schema review, foreign key indexing invariants, transactional DDL safety, and zero-downtime expand/contract migration analysis into `code-auditor` via task-conditional binding of `database-migrations/SKILL.md`.
- **Preserve `silent-failure-hunter`**: Retain `silent-failure-hunter` as a dedicated standalone specialist (`model: inherit`) to audit call-graph error-swallowing patterns without cognitive dilution from broader code hygiene audits.
- **Decouple ADR Ownership**:
  - `system-architect` focuses strictly on pre-execution contract-first design, system topology, and specification authoring (`spec-kit`), writing solely to scratch or proposal artifacts (`gate1_proposal.md`). Removed `docs/adr/` write permissions and ADR skills from `system-architect`.
  - `docs-architect` is designated as the sole authorized owner for authoring, serializing, and indexing Architecture Decision Records (`docs/adr/NNNN-*.md`, `docs/adr/README.md`), `architecture.md`, companion context (`task_state.md`), and public repository docs.
- **Formalize `tdd-guide` as `model: inherit` (Balanced 5/5 Fleet Split)**:
  - Harmonize all manifests, runbooks, and documentation to record `tdd-guide` as `model: inherit`.
  - Split the fleet evenly between model tiers:
    - **5 Cognitive / Analytical Specialists (`model: inherit`)**: `system-architect`, `code-auditor`, `silent-failure-hunter`, `spec-verifier`, `tdd-guide`.
    - **5 Tactical Mutating Specialists (`model: flash`)**: `build-error-resolver`, `docs-architect`, `l10n-humanizer`, `maintenance-bot`, `ui-crafter`.

### 2. Upgrade `l10n-humanizer` with Anti-AI Writing Heuristics
- **Dual-Scope Architecture**:
  - **Scope A (UI/UX Localization)**: Localize `.resw`, `.json`, `.resx`, `.xaml`, `.po`, and CLI output into idiomatic Indonesian (ID-ID) following the Microsoft Language Style Guide (capitalized **"Anda"**, universal UI glossary, untranslated modern computing terms, XML accelerator preservation).
  - **Scope B (Second-Pass Bilingual Prose Humanizer)**: Polish release notes, PR descriptions, commit messages, `README.md`, and technical docs by purging AI writing tells and inflation.
  - **Exclusion Boundary**: Scope B is strictly excluded from editing `GEMINI.md` and `docs/adr/**` to preserve normative engineering contracts and immutable architectural records.
- **Distilled 5 Instant-Edit Tells (Purge on Sight)**:
  1. *Not X but Y*: False contrast staged to inflate Y.
  2. *Dramatic Closers*: Unearned philosophical taglines or restatement fragments.
  3. *Faux-Deep Sayings*: Ordinary technical choices dressed as profound aphorisms.
  4. *Staged Run-Ups*: Performative throat-clearing openers.
  5. *Arguing With No One*: Defending against phantom criticisms or discarded strawmen.
- **Rhythm & Inflation Stripping**: Eliminate forced triads, replace corporate press-release verbs with simple copulas (`serves as` -> `is`), and cut dangling `-ing` riders and meta-document narration.
- **Strict Fact & Code Preservation Lock**: Lock raw code blocks, inline backticks, CLI flags, URLs, benchmark numbers, configuration keys, and architectural caveats verbatim. Document all transformations in a 3-Stage Reflection Table in scratch.

### 3. Subagent Schema Hardening & Prompt Pruning
- **`mainAgent: false` Enforcement**: Add `mainAgent: false` to the YAML frontmatter of all 10 custom agent manifests per official Antigravity subagent specifications, hiding them from top-level interactive persona selectors while keeping them fully accessible via `invoke_subagent` and `/teamwork`.
- **Prompt Pruning**: Delete the `Primary Interactive Mode (ROLE_TYPE Absent)` section from all 10 manifests, saving ~150 tokens per invocation.
- **Tool Hygiene**: Purge all `ask_question` references from subagent manifests and remove `Ask` from tools tables in documentation.
- **Boilerplate Scrubbing**: Remove redundant global boilerplate (*Sibling AI-Context Check* and *Strict Secret Redaction*) where it duplicates `GEMINI.md`, while strictly preserving the *Mandatory Skill Activation Gate* and the *4-Slot `<RETURN_CONTRACT>`*.

### 4. Single-Pass TDD Orchestration
- **Single-Pass Protocol**: In Tier 2/3 tasks where `tdd-guide` is the implementer, Parent Agent dispatches `tdd-guide` once post-checkpoint. In a single execution turn, `tdd-guide` authors the minimal failing test (RED), executes the test runner to witness the failure, implements the minimal fix (GREEN), runs the Pre-Mutation Syntax Interception Gate, verifies the test suite passes (`exit code 0`, `> 0 passed, 0 failed`), refactors, and returns a unified receipt with dual RED and GREEN traces.
- **Cross-Specialist Split Handoff**: The separate two-stage dispatch (S2 test authoring -> S3 implementation) is retained exclusively when test authoring and implementation require different specialist capabilities (e.g. `tdd-guide` writes contract tests, `ui-crafter` implements the frontend component).

## Alternatives Considered & Rejected

- **Retaining `database-reviewer` as Standalone Agent**: Rejected. Maintaining a standalone agent invoked in `<5%` of tasks introduced maintenance overhead, CI assertions, and documentation bloat with zero unique capability over `code-auditor`.
- **Downgrading `tdd-guide` to `model: flash`**: Rejected. TDD in Tier 2 requires holding multi-file interfaces, mock boundaries, and edge cases in memory simultaneously. Running on `flash` leads to assertion dilution and syntax slips.
- **Retaining Shared ADR Ownership**: Rejected. Allowing both `system-architect` and `docs-architect` to modify `docs/adr/` caused cognitive ambiguity. Decoupling planning from persistence enforces single responsibility.
- **Retaining Mandatory Serial S2 -> S3 TDD Dispatches**: Rejected. Forcing two separate subagent cold-starts burned 40k–60k redundant tokens re-reading the same files and doubled turn latency with no quality gain over a single disciplined pass.

## Consequences

- **Positive**:
  - Balanced 10-agent fleet (5 cognitive `inherit` / 5 tactical `flash`) without orphaned or low-utility agents.
  - Eliminated 40k–60k redundant tokens per TDD cycle via single-pass dispatch.
  - Clean UI in Antigravity persona selectors by hiding pure subagents via `mainAgent: false`.
  - Saved ~150–200 prompt tokens per subagent invocation through prompt pruning.
  - Clear separation of concerns: `system-architect` designs; `docs-architect` documents.
  - Improved prose quality across repository docs and localization resources via `l10n-humanizer` anti-AI heuristics without modifying application source code or decision records.
- **Negative / Operational Requirements**:
  - `code-auditor` must conditionally activate `database-migrations` on schema tasks.
  - Reviewers must verify dual RED and GREEN test receipts in `tdd-guide` single-pass handoffs.
