# Differential Review Methodology

Detailed phase-by-phase workflow for security-focused code review.

## Pre-Analysis: Baseline Context Building

**FIRST ACTION - Build complete baseline understanding without mutating working tree:**

If `audit-context-building` skill is available:

```pwsh
# Inspect baseline files read-only without switching branches or mutating working tree
rtk git show <baseline_commit>:<path/to/file>
```

Deploy a read-only specialist subagent (`invoke_subagent` with `TypeName: "code-auditor"`, `Role: "Codebase Context Auditor"`) following `audit-context-building` using `rtk rg`, `rtk git show <baseline_commit>:<file>`, and `view_file`, saving baseline context in `<appDataDir>\brain\<conversation-id>\scratch\<task>\baseline-context\` (or `$HOME/.gemini/antigravity/scratch/<task>/baseline-context/` via CLI fallback).
- **Scope**: entire relevant project (`src/`, `core/`, `lib/`, `config/`, or repository root).
- **Focus**: invariants, trust-boundaries, validation-patterns, call-graphs, state-flows.

**Capture from baseline analysis:**
- System-wide invariants (what must ALWAYS be true across all code)
- Trust boundaries and privilege levels (who can do what)
- Validation patterns (what gets checked where - defense-in-depth)
- Complete call graphs for critical functions (who calls what)
- State flow diagrams (how state changes)
- External dependencies and trust assumptions

**Why this matters:**
- Understand what the code was SUPPOSED to do before changes
- Identify implicit security assumptions in baseline
- Detect when changes violate baseline invariants
- Know which patterns are system-wide vs local
- Catch when changes break defense-in-depth

**Store baseline context in scratch for reference during differential analysis (never run `git checkout` during a read-only audit).**

---

## Phase 0: Intake & Triage

**Extract changes:**
```pwsh
# For commit range
rtk git diff <base>..<head> --stat
rtk git log <base>..<head> --oneline

# For PR
gh pr view <number> --json files,additions,deletions

# Get all changed files
rtk git diff <base>..<head> --name-only
```

**Assess codebase size:**
```pwsh
rtk rg --files . | Measure-Object -Line
```

**Classify complexity:**
- **SMALL**: <20 files → Deep analysis (read all deps)
- **MEDIUM**: 20-200 files → Focused analysis (1-hop deps)
- **LARGE**: 200+ files → Surgical (critical paths only)

**Risk score each file:**
- **HIGH**: Auth, crypto, external calls, command execution, validation removal
- **MEDIUM**: Business logic, state changes, new public APIs
- **LOW**: Comments, tests, UI, logging

---

## Phase 1: Changed Code Analysis

For each changed file:

1. **Read both versions** (baseline via `rtk git show <base>:<file>` and current via `view_file` or `read_file`): Note that Parent `read_file` is restricted strictly to Tier 0/1 changes; Tier 2/3 changes delegate code reading exclusively to `code-auditor` (`view_file`) per ADR-0019 Parent Context Insulation.

2. **Analyze each diff region:**
   ```
   BEFORE: [exact code]
   AFTER: [exact code]
   CHANGE: [behavioral impact]
   SECURITY: [implications]
   ```

3. **Git blame removed code:**
   ```pwsh
   # When was it added? Why?
   rtk git log -S "removed_code" --all --oneline
   rtk git blame <baseline> -- <file> | rtk rg "pattern"
   ```

   **Red flags:**
   - Removed code from "fix", "security", "CVE" commits → CRITICAL
   - Recently added (<1 month) then removed → HIGH

4. **Check for regressions (re-added code):**
   ```pwsh
   rtk git log -S "added_code" --all -p
   ```

   Pattern: Code added → removed for security → re-added now = REGRESSION

5. **Micro-adversarial analysis** for each change:
   - What attack did removed code prevent?
   - What new surface does new code expose?
   - Can modified logic be bypassed?
   - Are checks weaker? Edge cases covered?

6. **Generate concrete attack scenarios:**
   ```
   SCENARIO: [attack goal]
   PRECONDITIONS: [required state]
   STEPS:
     1. [specific action]
     2. [expected outcome]
     3. [exploitation]
   WHY IT WORKS: [reference code change]
   IMPACT: [severity + scope]
   ```

---

## Phase 2: Test Coverage Analysis

**Identify coverage gaps:**
```pwsh
# Production code changes (exclude tests)
rtk git diff <range> --name-only | rtk rg -v "test|spec"

# Test changes
rtk git diff <range> --name-only | rtk rg "test|spec"

# For each changed function, search for tests
rtk rg "functionName" tests/
```

**Risk elevation rules:**
- NEW function + NO tests → Elevate risk MEDIUM→HIGH
- MODIFIED validation + UNCHANGED tests → HIGH RISK
- Complex logic (>20 lines) + NO tests → HIGH RISK

---

## Phase 3: Blast Radius Analysis

**Calculate impact:**
```pwsh
# Count callers for each modified function
rtk rg "functionName\(" . | Measure-Object -Line
```

**Classify blast radius:**
- 1-5 calls: LOW
- 6-20 calls: MEDIUM
- 21-50 calls: HIGH
- 50+ calls: CRITICAL

**Priority matrix:**

| Change Risk | Blast Radius | Priority | Analysis Depth |
|-------------|--------------|----------|----------------|
| HIGH | CRITICAL | P0 | Deep + all deps |
| HIGH | HIGH/MEDIUM | P1 | Deep |
| HIGH | LOW | P2 | Standard |
| MEDIUM | CRITICAL/HIGH | P1 | Standard + callers |

---

## Phase 4: Deep Context Analysis

**If `audit-context-building` skill is available**, deploy a read-only specialist subagent (`invoke_subagent` with `TypeName: "code-auditor"`, `Role: "Codebase Context Auditor"`) following `audit-context-building` using `rtk rg` and `view_file`, saving context in `<appDataDir>\brain\<conversation-id>\scratch\<task>\audit-context\`, to answer the questions below for each HIGH RISK changed function:

1. **Map complete function flow:**
   - Entry conditions (preconditions, guards, schema validators)
   - State reads (which variables/tables accessed)
   - State writes (which variables/tables modified)
   - External calls (to subprocesses, APIs, DBs, filesystems)
   - Return values and side effects

2. **Trace internal calls:**
   - List all functions called
   - Recursively map their flows
   - Build complete call graph

3. **Trace external calls:**
   - Identify trust boundaries crossed
   - List assumptions about external behavior
   - Check for injection, race, or TOCTOU risks

4. **Identify invariants:**
   - What must ALWAYS be true?
   - What must NEVER happen?
   - Are invariants maintained after changes?

5. **Five Whys root cause:**
   - WHY was this code changed?
   - WHY did the original code exist?
   - WHY might this break?
   - WHY is this approach chosen?
   - WHY could this fail in production?

**If `audit-context-building` skill is NOT available**, manually perform the line-by-line analysis above using `read_file` (Parent, restricted strictly to Tier 0/1 changes; Tier 2/3 changes delegate code reading exclusively to `code-auditor` via `view_file` per ADR-0019 Parent Context Insulation) / `view_file` (Subagent), `rtk rg`, and code tracing.

**Cross-cutting pattern detection:**
```pwsh
# Check if any validation or security guard was removed in diff
rtk git diff <range> | rtk rg "^-.*(validate|sanitize|assert|Verify|Check)"
```

**Flag if removal breaks defense-in-depth.**

---

**Next steps:**
- For HIGH RISK changes, proceed to [adversarial.md](adversarial.md)
- For report generation, see [reporting.md](reporting.md)
