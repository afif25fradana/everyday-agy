---
name: skill-creator
description: "Interactive skill authoring: progressive disclosure structure, eval assertions, blind A/B rubrics, and trigger tuning."
---

<!-- Derivative work adapted from Anthropic's skill-creator (Apache-2.0). Modified for Antigravity native subagent architecture and pure-Markdown format by everyday-agy. -->
<!-- Copyright (c) 2026 Anthropic, PBC. Licensed under the Apache License, Version 2.0. -->

# Skill Authoring, Progressive Disclosure & Verification Runbook

## Overview & Architecture

Plain-spoken runbook for authoring, evaluating, and tuning bespoke and ported skills for Google Antigravity. In `everyday-agy`, skills are concise, focused Markdown files (`SKILL.md`) with clean progressive disclosure and zero speculative code bloat.

Governed by `GEMINI.md`, `clean-docs`, `coding-standards`, and ADR-0002. Automated batch evaluations run through native subagent sessions (`system-architect`, `code-auditor`, `spec-verifier`) or headless `agy -p` CLI externally.

---

## 1. Skill Anatomical Standards (Progressive Disclosure)

- **Top-Level `SKILL.md`**: Primary entry point. Frontmatter must contain `name:` matching directory leaf name and single-line `description:` `<= 128` characters. If `description` contains `: `, wrap in quotes. Keep root file focused ($\le 120$–$180$ lines).
- **Sub-Documents (`references/`)**: Partition deep catalogs, checklists, or reference tables into `references/<topic>.md` only when the skill exceeds single-file bounds. Read on-demand, never forced into immediate context.
- **Pure Markdown Core**: Dotfile skills contain zero bundled execution scripts (`scripts/`). Any executable test fixtures or automation scripts belong in `.github/tests/` or external tooling repositories.

---

## 2. The 4-Phase Authoring & Verification Lifecycle

### Phase 1: Intent & Test-Case Formulation

1. **Define Intent & Boundaries**:
   - Capture user need, operational triggers, and explicit non-goals (what the skill must *not* do).
   - Establish negative constraints: prevent model hallucinations, process leaks, and anti-patterns.
2. **Author 3–5 Evaluation Tasks**:
   - Write concrete, reproducible user prompts representing realistic scenarios.
   - Include at least 1 edge case (unusual arguments, partial input, or constrained context).
3. **Formulate 20 Trigger Test Queries**:
   - **10 Positive Queries**: User prompts that must reliably trigger the skill (e.g., explicit trigger commands, domain keywords, and typical task formulations).
   - **10 Negative Near-Miss Queries**: Prompts sharing keywords or thematic overlap that must *not* trigger the skill (should route to standard chat, coding tools, or sibling skills).

### Phase 2: Execution & Duality Grading

1. **Dual-Run Baseline vs. Candidate**:
   - Run evaluation tasks in baseline state (without skill in context).
   - Run evaluation tasks with candidate `SKILL.md` active.
2. **Assertion-Based Grading**:
   - Grade outputs against explicit binary assertions:
     - `ASSERT_PRESENT`: Required sections, schema slots, or file modifications exist.
     - `ASSERT_ABSENT`: Prohibited phrases, generic AI commentary, or secret leaks do not exist.
     - `ASSERT_GROUNDED`: Claims are backed by repository code, tests, or verified CLI outputs.

### Phase 3: Blind A/B Comparator & Analyzer Rubric

1. **Blind Comparative Scoring**:
   - Evaluate baseline (A) vs. candidate (B) across a 1–5 rubric grid without revealing labels:
     - **Content Quality (1–5)**: Technical accuracy, absence of hallucinated flags/options, completeness, and adherence to repository conventions.
     - **Structural Ergonomics (1–5)**: Progressive disclosure, conciseness, visual hierarchy, and actionable checklists.
2. **Analyzer Failure Taxonomy**:
   - **Over-Triggering**: Activates on negative near-misses; narrow keywords and clarify non-goals.
   - **Under-Triggering**: Fails on valid tasks; expand semantic synonyms in description.
   - **Instruction Drift**: Model ignores procedural steps under load; convert soft prose ("prefer", "consider") into rigid numbered stages.
   - **Process Leakage**: Output leaks internal AI stages or audit tags; enforce `clean-docs` Section 1.

### Phase 4: Trigger Description Calibration & Reporting

1. **Frontmatter Optimization**:
   - Calibrate `description:` to maximize trigger precision while respecting the `128`-character limit.
   - Validate formatting: wrap in double quotes if a colon sequence (`: `) is present.
2. **Artifact Delivery**:
   - Output final evaluation results into an Antigravity UserFacing Artifact:
     `<appDataDir>\brain\<conversation-id>\eval_report.md`
   - Include trigger accuracy percentage, A/B rubric scores, assertion matrix, and recommended description tuning.

---

## 3. Headless Verification via `agy` CLI (Optional External)

When automated command-line evaluation is required across multiple test cases, execute via the headless Antigravity CLI in an external workspace:
```powershell
agy -p "Evaluate task 1 with skill candidate" --print-timeout 60s
```
*Note: In-tree dotfile repositories remain pure Markdown. Automation harnesses and test runners reside externally per ADR-0002.*

---

## 4. Anti-Patterns & Quality Gate

- **No Bundled Virtual Envs / Wheels**: Never commit `.venv/`, binary packages, or heavy script trees into `config/skills/`.
- **No Unquoted Colons**: Ensure YAML frontmatter containing `: ` is strictly quoted.
- **No Vanity Metrics**: Ground skill descriptions in concrete actions rather than marketing buzzwords.
- **Validation**: Verify that `.github/tests/YamlValidation.Tests.ps1` passes with zero warnings.
