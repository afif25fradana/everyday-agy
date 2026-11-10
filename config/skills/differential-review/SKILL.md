---
name: differential-review
description: "Security-focused differential review (/differential-review) of diffs/PRs: caller blast radius, git blame, and test coverage."
---

# Differential Security Review

Security-focused code review for PRs, commits, and diffs.

## Core Principles

1. **Risk-First**: Focus on auth, crypto, command/query execution, external calls, and validation changes
2. **Evidence-Based**: Every finding backed by git history, line numbers, and concrete attack scenarios
3. **Adaptive**: Scale to codebase size (`SMALL` / `MEDIUM` / `LARGE`)
4. **Honest**: Explicitly state coverage limits and confidence level
5. **Output-Driven**: Always generate a structured markdown report artifact (`<appDataDir>\brain\<conversation-id>\...`)

---

## Rationalizations (Do Not Skip)

| Rationalization | Why It's Wrong | Required Action |
|-----------------|----------------|-----------------|
| "Small PR, quick review" | Heartbleed was 2 lines | Classify by RISK, not size |
| "I know this codebase" | Familiarity breeds blind spots | Build explicit baseline context |
| "Git history takes too long" | History reveals regressions | Never skip Phase 1 |
| "Blast radius is obvious" | You'll miss transitive callers | Calculate quantitatively |
| "No tests = not my problem" | Missing tests = elevated risk rating | Flag in report, elevate severity |
| "Just a refactor, no security impact" | Refactors break invariants | Analyze as HIGH until proven LOW |
| "I'll explain verbally" | No artifact = findings lost | Always write report |

---

## Quick Reference

### Codebase Size Strategy

| Codebase Size | Strategy | Approach |
|---------------|----------|----------|
| SMALL (<20 files) | DEEP | Read all deps, full git blame |
| MEDIUM (20-200) | FOCUSED | 1-hop deps, priority files |
| LARGE (200+) | SURGICAL | Critical paths only |

### Risk Level Triggers

| Risk Level | Triggers |
|------------|----------|
| HIGH | Auth, crypto, external calls, command/SQL execution, validation removal |
| MEDIUM | Business logic, state changes, new public APIs |
| LOW | Comments, tests, UI, logging |

---

## Workflow Overview

```
Pre-Analysis → Phase 0: Triage → Phase 1: Code Analysis → Phase 2: Test Coverage
    ↓              ↓                    ↓                        ↓
Phase 3: Blast Radius → Phase 4: Deep Context → Phase 5: Adversarial → Phase 6: Report
```

---

## Decision Tree

**Starting a review?**

```
├─ Need detailed phase-by-phase methodology?
│  └─ Read: references/methodology.md
│     (Pre-Analysis + Phases 0-4: triage, code analysis, test coverage, blast radius)
│
├─ Analyzing HIGH RISK change?
│  ├─ Read: references/adversarial.md
│  │  (Phase 5: Attacker modeling, exploit scenarios, exploitability rating)
│  └─ Or delegate to: invoke_subagent (`TypeName: "code-auditor"`, `Role: "Adversarial Security Modeler"`) applying references/adversarial.md
│     (Autonomous attacker modeling with concrete exploit scenarios)
│
├─ Writing the final report?
│  └─ Read: references/reporting.md
│     (Phase 6: Report structure, templates, formatting guidelines)
│
├─ Looking for specific vulnerability patterns?
│  └─ Read: references/patterns.md
│     (Regressions, reentrancy, access control, overflow, etc.)
│
└─ Quick triage only?
   └─ Use Quick Reference above, skip detailed docs
```

---

## Agents

**Adversarial Security Modeler** - Models attacker perspectives and builds exploit
scenarios for HIGH RISK code changes. Follows the 5-step adversarial methodology in
`references/adversarial.md` (attacker model, attack vectors, exploitability rating, exploit
scenario, baseline cross-reference) and produces structured vulnerability reports.
Delegate to this agent using `invoke_subagent` (`TypeName: "code-auditor"`, `Role: "Adversarial Security Modeler"`),
instructing it to apply `references/adversarial.md`.

---

## Quality Checklist

Before delivering:

- [ ] All changed files analyzed (strictly read-only via `rtk git diff` / `rtk git show`)
- [ ] Git blame on removed security code
- [ ] Blast radius calculated for HIGH risk
- [ ] Attack scenarios are concrete (not generic)
- [ ] Findings reference specific line numbers + commits
- [ ] Report file generated in `<appDataDir>\brain\<conversation-id>\...`
- [ ] User notified with concise 1–3 line summary

---

## Integration

**audit-context-building skill:**
- Pre-Analysis: Build baseline context
- Phase 4: Deep context on HIGH RISK changes

---

## When NOT to Use This Skill

- **Greenfield code** (no baseline to compare)
- **Documentation-only changes** (no security impact)
- **Formatting/linting** (cosmetic changes)
- **User explicitly requests quick summary only** (they accept risk)

For these cases, use standard code review instead.

---

## Red Flags (Stop and Investigate)

**Immediate escalation triggers:**
- Removed code from "security", "CVE", or "fix" commits
- Access control modifiers or guards removed
- Validation removed without replacement
- External or shell calls added without sanitization
- High blast radius (50+ callers) + HIGH risk change

These patterns require adversarial analysis even in quick triage.

---

## Tips for Best Results

**Do:**
- Start with git blame for removed code
- Calculate blast radius early to prioritize
- Generate concrete attack scenarios
- Reference specific line numbers and commits
- Be honest about coverage limitations
- Always generate the output file

**Don't:**
- Skip git history analysis
- Make generic findings without evidence
- Claim full analysis when time-limited
- Forget to check test coverage
- Miss high blast radius changes
- Output report only to chat (output report as a standalone UserFacing Artifact following `handoff-spec.md`, and save raw evidence to `<appDataDir>\brain\<conversation-id>\scratch\<task>\`)

---

## Supporting Documentation

- **[methodology.md](references/methodology.md)** - Detailed phase-by-phase workflow (Phases 0-4)
- **[adversarial.md](references/adversarial.md)** - Attacker modeling and exploit scenarios (Phase 5)
- **[reporting.md](references/reporting.md)** - Report structure and formatting (Phase 6)
- **[patterns.md](references/patterns.md)** - Common vulnerability patterns reference

---

## License & Attribution

Adapted from [trailofbits/skills](https://github.com/trailofbits/skills) by Trail of Bits, Inc.  
Licensed under the [Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](./LICENSE).  
Modifications made for Google Antigravity runtime by everyday-agy contributors.
