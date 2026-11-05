# Report Generation (Phase 6)

Comprehensive markdown report structure and formatting guidelines.

---

## Report Structure

Generate markdown report with these mandatory sections:

### 1. Executive Summary

- Severity distribution table
- Risk assessment (`CRITICAL` / `HIGH` / `MEDIUM` / `LOW`)
- Final recommendation (`APPROVE` / `REJECT` / `CONDITIONAL`)
- Key metrics (test gaps, blast radius, red flags)

**Template:**
```markdown
# Executive Summary

| Severity | Count |
|----------|-------|
| CRITICAL | X |
| HIGH | Y |
| MEDIUM | Z |
| LOW | W |

**Overall Risk:** CRITICAL/HIGH/MEDIUM/LOW
**Recommendation:** APPROVE/REJECT/CONDITIONAL

**Key Metrics:**
- Files analyzed: X/Y (Z%)
- Test coverage gaps: N functions
- High blast radius changes: M functions
- Security regressions detected: P
```

---

### 2. What Changed

- Commit timeline
- File summary table
- Lines changed stats

**Template:**
```markdown
## What Changed

**Commit Range:** `base..head`
**Commits:** X
**Timeline:** YYYY-MM-DD to YYYY-MM-DD

| File | +Lines | -Lines | Risk | Blast Radius |
|------|--------|--------|------|--------------|
| src/auth.ts | +50 | -20 | HIGH | CRITICAL |
| src/utils.ts | +10 | -5 | MEDIUM | LOW |

**Total:** +N, -M lines across K files
```

---

### 3. Critical Findings

For each HIGH/CRITICAL issue:

```markdown
### [SEVERITY] Title

**File**: path/to/file.ext#Lxx-Lyy
**Commit**: hash
**Blast Radius**: N callers (HIGH/MEDIUM/LOW)
**Test Coverage**: YES/NO/PARTIAL

**Description**: [clear explanation]

**Historical Context**:
- Git blame: Added in commit X (date)
- Message: "[original commit message]"
- [Why this code existed]

**Attack Scenario**:
[Concrete exploitation steps from adversarial.md]

**Proof of Concept**:
```code demonstrating issue```

**Recommendation**:
[Specific fix with code]
```

---

### 4. Test Coverage Analysis

```markdown
## Test Coverage Analysis

**Coverage:** X% of changed code

**Untested Changes:**
| Function | Risk | Impact |
|----------|------|--------|
| functionA() | HIGH | No validation tests |
| functionB() | MEDIUM | Logic untested |

**Risk Assessment:**
N HIGH-risk functions without tests → Recommend blocking merge
```

---

### 5. Blast Radius Analysis

```markdown
## Blast Radius Analysis

**High-Impact Changes:**
| Function | Callers | Risk | Priority |
|----------|---------|------|----------|
| verifyToken() | 89 | HIGH | P0 |
| validateInput() | 45 | MEDIUM | P1 |
```

---

### 6. Historical Context

```markdown
## Historical Context

**Security-Related Removals:**
- Line 45: Validation guard removed (added 2026-03 for CVE-2026-1234)
- Line 78: Path sanitization removed (added 2025-12 "security hardening")

**Regression Risks:**
- Code pattern removed in commit X, re-added in commit Y
```

---

### 7. Recommendations

```markdown
## Recommendations

### Immediate (Blocking)
- [ ] Fix CRITICAL issue in src/auth.ts#L156
- [ ] Add tests for verifyToken() function

### Before Production
- [ ] Security audit of auth changes
- [ ] Verify blast radius callers

### Technical Debt
- [ ] Refactor validation pattern consistency
```

---

### 8. Analysis Methodology

```markdown
## Analysis Methodology

**Strategy:** FOCUSED (80 files, medium codebase)

**Analysis Scope:**
- Files reviewed: 45/80 (56%)
- HIGH RISK: 100% coverage
- MEDIUM RISK: 60% coverage
- LOW RISK: Excluded

**Techniques:**
- Git blame on all removals
- Blast radius calculation
- Test coverage analysis
- Adversarial modeling for HIGH RISK

**Limitations:**
- Did not analyze external dependencies
- Limited to 1-hop caller analysis

**Confidence:** HIGH for analyzed scope, MEDIUM overall
```

---

## File Naming and Location

**Priority order for output:**
1. Standalone Antigravity UserFacing Artifact (`<appDataDir>\brain\<conversation-id>\<PROJECT>_DIFFERENTIAL_REVIEW_<DATE>.md`)
2. Raw execution logs, diffs, and evidence files saved in `<appDataDir>\brain\<conversation-id>\scratch\<task>\` (or `$HOME/.gemini/antigravity/scratch/<task>/` via CLI fallback)

---

## User Notification Standard

After generating the report artifact, emit a concise 1–3 line summary in chat linking to the artifact with finding counts (`CRITICAL`/`HIGH`) and final recommendation (`APPROVE`/`REJECT`/`CONDITIONAL`), adhering to `config/GEMINI.md#L35-L36`.
