# Differential Review Methodology

Detailed phase-by-phase workflow for security-focused code review.

## Pre-Analysis: Baseline Context Building

**FIRST ACTION - Build complete baseline understanding:**

If `audit-context-building` skill is available:

```pwsh
# Checkout baseline commit
rtk git checkout <baseline_commit>
```

Deploy a read-only research subagent (`invoke_subagent` with `TypeName: "research"`, `Role: "Codebase Context Auditor"`) following `audit-context-building` using `rtk rg` and `view_file`, saving baseline context in `$HOME/.gemini/antigravity/scratch/<task>/baseline-context/`.
- **Scope**: entire relevant project (e.g., `packages/contracts/contracts/` for Solidity, `src/` for Rust, or repository root).
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

**Store baseline context for reference during differential analysis.**

After baseline analysis, checkout back to head commit to analyze changes.

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
rg --files -g "*.sol" -g "*.rs" -g "*.go" -g "*.ts" . | Measure-Object -Line
```

**Classify complexity:**
- **SMALL**: <20 files → Deep analysis (read all deps)
- **MEDIUM**: 20-200 files → Focused analysis (1-hop deps)
- **LARGE**: 200+ files → Surgical (critical paths only)

**Risk score each file:**
- **HIGH**: Auth, crypto, external calls, value transfer, validation removal
- **MEDIUM**: Business logic, state changes, new public APIs
- **LOW**: Comments, tests, UI, logging

---

## Phase 1: Changed Code Analysis

For each changed file:

1. **Read both versions** (baseline and changed)

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
   git blame <baseline> -- file.sol | rg "pattern"
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
git diff <range> --name-only | rg -v "test"

# Test changes
git diff <range> --name-only | rg "test"

# For each changed function, search for tests
rtk rg "test.*functionName" test -g "*.sol" -g "*.js"
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
rg "functionName\(" -g "*.sol" . | Measure-Object -Line
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

**If `audit-context-building` skill is available**, deploy a read-only research subagent (`invoke_subagent` with `TypeName: "research"`, `Role: "Codebase Context Auditor"`) following `audit-context-building` using `rtk rg` and `view_file`, saving context in `$HOME/.gemini/antigravity/scratch/<task>/audit-context/`, to help answer all the questions below for each HIGH RISK changed function:

**The audit-context-building skill will help you answer:**

1. **Map complete function flow:**
   - Entry conditions (preconditions, requires, modifiers)
   - State reads (which variables accessed)
   - State writes (which variables modified)
   - External calls (to contracts, APIs, system)
   - Return values and side effects

2. **Trace internal calls:**
   - List all functions called
   - Recursively map their flows
   - Build complete call graph

3. **Trace external calls:**
   - Identify trust boundaries crossed
   - List assumptions about external behavior
   - Check for reentrancy risks

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

**If `audit-context-building` skill is NOT available**, manually perform the line-by-line analysis above using view_file, rtk rg, and code tracing.

**Cross-cutting pattern detection:**
```pwsh
# Find repeated validation patterns
rtk rg "require.*amount > 0" -g "*.sol" .
rtk rg "onlyOwner" -g "*.sol" .

# Check if any removed in diff
git diff <range> | rg "^-.*require.*amount > 0"
```

**Flag if removal breaks defense-in-depth.**

---

**Next steps:**
- For HIGH RISK changes, proceed to [adversarial.md](adversarial.md)
- For report generation, see [reporting.md](reporting.md)
