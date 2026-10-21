# Milestone Handoff Specification (`handoff_artifact.md`)

A structured, readable guideline for generating milestone handoff reports when completing complex tasks or significant work phases.

---

## 1. When to Generate an Artifact

- **Major Milestones & Multi-File Refactors**: Generate an Antigravity UserFacing Artifact (via `write_to_file` with `ArtifactMetadata: { Summary, UserFacing: true, RequestFeedback: false }` in the session artifact directory `<appDataDir>\brain\<conversation-id>`) when completing a discrete phase or complex refactoring to provide a permanent audit record. Milestone handoff artifacts must **never** be written into the git repository working tree.
- **Fast-Path (Default)**: For everyday fixes, single-module features, or config updates, report directly in chat (1–3 lines with diff/action items). Do not generate ceremonial artifacts for simple tasks.

---

## 2. Recommended Handoff Template

When an artifact is appropriate, use the following clean structure:

```markdown
# Handoff: <Task Title>

- **Task**: <Concise Task Description>
- **Date**: <YYYY-MM-DD>
- **Git HEAD SHA**: `<sha>`
- **Phase Status**: `audit` | `proposal` | `executed`

---

## Summary
<2-3 lines stating the concrete outcome and root cause resolution.>

---

## Changes & Rationale
- `<file>`: <what was changed and why>
- `<file>`: <what was changed and why>

---

## Diff & Impact
### Diffstat
```text
 <file> | <N> +++---
```

<Include inline unified diff if under ~60 lines, or cite the branch/patch.>

---

## Verification & Testing
- `<test command>`: <exit code 0, test pass count, execution summary>

---

## Next Steps / User Decisions
- <Any pending user decisions or logical next steps; or "None (milestone complete)">
```

---

## 3. Core Principles

1. **Say Plainly What Code Does**: Use natural, direct technical descriptions. Never inject internal AI tags, phase tokens, or corporate buzzwords into repo files or commit messages.
2. **Honest Verification**: Only report tests that were actually executed. If a test fails, state the exact error and stop immediately.
3. **Concise Chat**: Chat output should remain lean (1–2 lines) pointing the user to the artifact or summarizing the next action item.
