---
name: clean-docs
description: Clean documentation, commit hygiene, and anti-slop standard. Enforces plain-spoken repo prose, zero AI process leaks, humanized conventional commits, and public repo hygiene. Trigger when writing or reviewing commit messages, PR descriptions, READMEs, CHANGELOGs, docstrings, code comments, or preparing public repo releases.
---

# Clean Docs & Repository Hygiene Standard

Plain-spoken engineering prose, humanized conventional commits, zero internal process leaks, and grounded documentation. Governed by the minimalist principles of `GEMINI.md` and `ponytail`.

---

## 1. Zero Process Artifacts & Leak Prevention

Never let internal AI orchestration or audit machinery leak into repository files, git history, or pull requests:

- **Banned in repo files, commits & PR titles/bodies**:
  - `"investigation summary"`, `"checkpoint commit"`, `"audit finding #..."`, `"Gate 1"`, `"Gate 2"`, `"batch/stage tags"`, `"handoff_artifact"`, `"subagent execution"`, `"Parent verification"`, `"Phase 2 complete"`, `"prompt instructions"`, `"per prompt directives"`.
- **Where Process Belongs**:
  - Internal AI commentary, audit gates, and execution stages belong **exclusively** in chat dialog, session scratch files (`$HOME/.gemini/antigravity/scratch/<task>/` or `<appDataDir>/brain/<conversation-id>/scratch/`), or Antigravity session artifacts.
- **Humanized Conventional Commits**:
  - Commit messages must use clean standard prefixes (`fix(scope): ...`, `refactor(scope): ...`, `feat(scope): ...`, `test(scope): ...`, `docs(scope): ...`).
  - Describe **what** changed in the software and **why**, exactly as a pragmatist human software engineer would write it.
  - Zero AI buzzwords, zero process tags, and zero robotic self-congratulations.

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

---

## 5. The 4-Question Sanitization Pass

Before finalizing any commit message, PR description, README, or doc change, run this quick filter:

1. **Utility vs Theater**: Does this sentence explain something useful to an engineer or user, or does it merely signal AI rigor?
2. **Simplicity**: Can this be phrased more simply and directly without losing technical precision?
3. **Human Naturalness**: Would this look completely natural in a pragmatic human engineer's personal GitHub repo?
4. **Zero Leaks**: Are there any leftover AI session tags, checkpoint references, artifact markers, or internal stage labels?
