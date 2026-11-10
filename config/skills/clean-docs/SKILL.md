---
name: clean-docs
description: Plain-spoken documentation (/clean-docs), commit hygiene, anti-slop standard, zero process leaks, and conventional commits.
---

# Clean Docs & Repository Hygiene Standard

Plain-spoken engineering prose, humanized conventional commits, zero internal process leaks, and grounded documentation. Governed by the minimalist principles of `GEMINI.md` and `ponytail`.

---

## 1. Zero Process Artifacts & Leak Prevention

Never let internal AI orchestration or audit machinery leak into repository files, git history, or pull requests:

- **Banned in Client Application Repositories (repo files, commits & PR titles/bodies)**:
  - `"investigation summary"`, `"checkpoint commit"`, `"audit finding #..."`, `"Gate 1"`, `"Gate 2"`, `"batch/stage tags"`, `"handoff_artifact"`, `"subagent execution"`, `"Parent verification"`, `"Phase 2 complete"`, `"prompt instructions"`, `"per prompt directives"`.
  - *Scope Qualification / Framework Exemption*: In meta-framework, developer tooling, or orchestration repositories (such as `everyday-agy`) where gates, checkpoints, and subagent schemas are the primary domain subject matter under design, test, or documentation, architectural references like "Gate 1", "Gate 2", and "checkpoint commit" are recognized technical domain concepts and are permitted within framework specifications, runbooks, ADRs, and test suites.
- **Where Process Belongs**:
  - Internal AI commentary, audit gates, and execution stages belong **exclusively** in chat dialog, session scratch files (`<appDataDir>\brain\<conversation-id>\scratch\<task>\` or `$HOME/.gemini/antigravity/scratch/<task>/`), or Antigravity session artifacts.
- **Humanized Conventional Commits**:
  - Commit messages must use clean standard prefixes (`fix(scope): ...`, `refactor(scope): ...`, `feat(scope): ...`, `test(scope): ...`, `docs(scope): ...`).
  - Describe **what** changed in the software and **why**, exactly as a pragmatist human software engineer would write it.
  - Zero AI buzzwords, zero process tags, and zero robotic self-congratulations.
- **Review Anti-Sycophancy**:
  - Strictly ban performative praise in code review dialogs (`"You're absolutely right!"`, `"Great point!"`, `"Thanks for catching that!"`, `"Excellent feedback!"`, `"Brilliant!"`, `"Perfect!"`) and polite apologies (`"I apologize"`, `"I am sorry"`). Evaluate feedback purely on caller verification, YAGNI, and technical merits.

---

## 2. Zero Sophistication Theater (Plain Register)

Never inflate simple code or architecture with academic, corporate, or audit-report buzzwords. A null check is not a *"Fail-Fast Invariant Enforcement Barrier"*. Describe what the software actually does in plain terms.

### Transformation Guide:

| Hyperbolic / AI-Slop (Banned) | Pragmatic Plain English (Required) |
| :--- | :--- |
| *"Implemented a multi-tenant invariant enforcement barrier across the data ingestion pipeline."* | *"Added validation to reject invalid OCR responses before parsing."* |
| *"Architected an extensible polyglot styling paradigm."* | *"Consolidated shared button and typography CSS classes."* |
| *"Executed phase 3 subagent refactoring pass per differential audit findings."* | *"Split the parser into two modules."* |
| *"Employed defensive state synchronization heuristics to eliminate race hazards."* | *"Added a mutex lock to prevent concurrent write collisions."* |
| *"Seamless, cutting-edge, battle-tested solution empowering frictionless developer experiences."* | Plainly explain what the feature does, how to run it, and its known limits. |

---

## 3. Code Comment Hygiene (`antislop-code`)

- **Zero Obvious AI Commentary**:
  - Never add obvious comments describing syntax or trivial actions (`// Update state`, `// Loop through items`, `// Check if user is null`, `// Return result`).
- **Code Explains What & How**:
  - Clean, well-named functions and variables explain *what* and *how*.
- **Comments Strictly for Non-Obvious "Why"**:
  - Retain or write comments only when documenting non-obvious *why* rationale, OS/browser workarounds, upstream API quirks, concurrency edge cases, or intentional performance trade-offs.

---

## 4. Public Repo & Release Hygiene

When preparing or reviewing public-facing files (`README.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, release notes):

1. **CI-Claim Gate**:
   - Any claim that tests pass or a platform is supported must be backed by a green CI run at current `Git HEAD`. Never claim passes that are not verified.
2. **Stranger-Verifiable Claims**:
   - Ground claims in checkable evidence (reproducible commands, CI badges, real benchmarks). If something is based on personal setup, state it honestly as personal experience rather than an enterprise benchmark.
3. **No Mutable Vanity Metrics**:
   - Never hardcode volatile metrics (test counts, LOC, subagent counts, coverage %) in `README.md` or `CHANGELOG.md`; they become stale instantly.
4. **Accurate & Grounded Claims**:
   - Every claim in docs must match actual code in the repository.
5. **Clean Rebrand / Rename**:
   - After renaming a project, grep tracked files (`rtk rg`) and build configurations to verify all references are updated.
6. **Stranger Test (30-Second Impression)**:
   - First line of `README.md` must state plainly what the tool is and what problem it solves. No promotional fluff or hyperbolic claims.
7. **Naive Reader Paraphrase Test**:
   - Before approving or publishing, ensure a fresh reader can plainly articulate in two paragraphs: (1) what the document/architecture proposes, and (2) how the existing system works. If either cannot be plainly paraphrased, report a blocker for unstated assumptions.

---

## 5. The 5-Point Sanitization & Caveat Pass

Before finalizing any commit message, PR description, README, or doc change, run this quick filter:

1. **Utility vs Theater**: Does this sentence explain something useful to an engineer or user, or does it merely signal AI rigor?
2. **Simplicity**: Can this be phrased more simply and directly without losing technical precision?
3. **Human Naturalness**: Would this look completely natural in a pragmatic human engineer's personal GitHub repo?
4. **Zero Leaks**: Are there any leftover AI session tags, checkpoint references, artifact markers, or internal stage labels?
5. **Defensive Caveat Calibration (`DROP | CALIBRATE | RELOCATE | KEEP`)**:
   - `DROP`: Strip speculative hedging with no reachable user/operator decision.
   - `CALIBRATE`: Narrow the claim to match exact verified evidence.
   - `RELOCATE`: Move operational caveats to the specific step where the user makes a choice.
   - `KEEP`: Retain caveats directly backed by documented system limits.

---

## 6. The Tri-Guard Editorial Guardrails (SSOT)

To guarantee authentic engineering tone across documentation surfaces, enforce three non-negotiable editorial guardrails:

### Guardrail A: Anti-Casual & Anti-Indie-Hacker Marketing Slop
- **Voice**: Maintain an honest developer-to-developer notebook tone. Never emulate breathless tech marketing, Twitter threads, or startup pitch decks.
- **Banned Promotional Hooks**: Strictly purge ProductHunt/indie-hacker slogans (`"Meet your new superpower"`, `"Supercharge your workflow"`, `"The ultimate toolkit"`, `"Game-changing"`, `"Frictionless developer experience"`).
- **No Fictional Roleplay Dialogue**: Ban invented conversational dialogues (`"Alice: How do I do X? Bob: Easy, just use Y!"`) or Q&A personas unless explicitly mandated by project specifications.
- **Ban Punctuation Variants of False Contrast ("Not X, but Y")**: Purge all stylistic permutations staged to inflate the second clause:
  - Semicolon variant: *"Not a simple linter; it is an architectural enforcement engine."*
  - Em-dash variant: *"Not just a database helper—a complete transactional rethink."*
  - Colon variant: *"Not standard caching: it's proactive memory invalidation."*
  - Staccato fragment variant: *"Not an ordinary script. A paradigm shift."*
  - Direct rewrite: Plainly state what the component actually does without negative staging.
- **Anti-Corporate Cosplay Rule**: For personal/single-developer repositories, dotfiles, or experimental side projects, strictly avoid generating or recommending enterprise bureaucracy templates (`CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/*`) unless explicitly requested by the user.

### Guardrail B: Upfront Sandbox & Scaffolding Honesty
- **Opening Disclosure**: Clearly disclose prototype, mockup, or scaffolding limits in the opening paragraphs of `README.md` or component documentation.
- **No Footnote Hiding**: Never bury incomplete features, simulated endpoints, or stubbed adapters in bottom footnotes or deep caveats. If a capability runs in sandbox mode or uses mocked data, state it plainly alongside the feature overview.

### Guardrail C: Cross-Session Continuity via `task_state.md`
- **Pre-Documentation Inspection**: Before editing or rewriting public documentation (`README.md`, `TOOLKIT.md`, sub-docs), inspect `task_state.md` in the current repository or its sibling `<Project>-AI-Context` repository.
- **Continuity Lock**: Carry over settled findings, documented gotchas, rejected alternatives, and project-specific banned terminology across AI sessions to prevent re-introducing discarded patterns or conflicting architectural claims.
