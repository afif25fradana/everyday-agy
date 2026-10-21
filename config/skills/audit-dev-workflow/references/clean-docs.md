# Clean Docs & Anti-Slop Standard: Plain-Spoken, Zero Process Leaks

Apply whenever reviewing or approving READMEs, CHANGELOGs, docstrings, code comments, commit messages, PR descriptions, or release notes from Antigravity.

## 1. Zero Process Artifacts
Never let internal AI/audit machinery leak into repository files, commits, or PRs:

- **Banned in repo files & commits**: `"investigation summary"`, `"checkpoint commit"`, `"audit finding #2"`, `"batch/stage tags"`, `"handoff_artifact"`, `"subagent execution"`, `"Parent verification"`, `"Phase 2 complete"`, `"prompt instructions"`.
- These terms belong exclusively in chat dialog, session scratch files (`$HOME/.gemini/antigravity/scratch/<task>/` or `<appDataDir>/brain/<conversation-id>/scratch/`), or Antigravity session artifacts.
- **Humanized Conventional Commits**: Commit messages must use clean standard prefixes (`fix(scope): ...`, `refactor(scope): ...`, `feat(scope): ...`) describing what changed in the software and why.

## 2. Zero Sophistication Theater (`antislop-copywriting` & `GEMINI.md` Plain Register)
Never inflate simple logic with academic, corporate, or audit-report buzzwords. A null check is not a *"Fail-Fast Invariant"*. Describe what the software actually does.

### Before & After Transformation Examples:

- **Bad:** *"Implemented a multi-tenant invariant enforcement barrier across the data ingestion pipeline."*
  **Better:** *"Added validation to reject invalid OCR responses before parsing."*
- **Bad:** *"Architected an extensible polyglot styling paradigm."*
  **Better:** *"Consolidated shared button and typography CSS classes."*
- **Bad:** *"Executed phase 3 subagent refactoring pass per differential audit findings."*
  **Better:** *"Split the parser into two modules."*

## 3. Code Comments (`antislop-code`)

- Zero obvious AI commentary (`// Update state`, `// Loop through items`).
- Code should explain *what* and *how* by itself; keep comments strictly for non-obvious *why* rationale, browser/OS workarounds, or external protocol quirks.

## 4. The 4-Question Sanitization Pass
Before approving prose or commit messages for the repository, verify:

1. Does this sentence explain something useful to an engineer or end user, or just signal AI rigor?
2. Can it be stated more simply without losing technical accuracy?
3. Would this look completely natural in a pragmatic human engineer's personal GitHub repo?
4. Are there any leftover AI session tags, checkpoint references, artifact markers, or batch labels?
