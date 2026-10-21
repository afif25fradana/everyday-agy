---
name: gh-workflow
description: >
  GitHub CLI automation for PR creation, non-interactive CI monitoring, and PR review comments using authenticated gh.
  Use when the user asks to create a PR, check GitHub Actions status, review a pull request, or mentions /gh-workflow.
---

# GitHub Workflow (`gh-workflow`)

Operational playbook for managing Pull Requests and GitHub Actions CI pipelines via authenticated `gh` CLI.

---

## 1. Safety & Execution Rules

- **Execution Policy**: Do NOT prefix `gh` with `rtk` (run `gh` directly). Prefix `git` with `rtk` (e.g. `rtk git status`).
- **Explicit Approval**: Always prompt the user before pushing branches or creating/merging PRs.

---

## 2. Pull Request Lifecycle

### Step 1: Pre-flight Check
Ensure working directory is clean and branch is current:
```powershell
rtk git status --short
rtk git branch --show-current
```

### Step 2: Push Branch & Create PR
After user confirms push:
```powershell
rtk git push -u origin (rtk git branch --show-current)
```

Create PR with conventional title and lean markdown body:
```powershell
gh pr create --title "type(scope): concise summary" --body "## Summary`n- Brief bullet points of changes`n`n## Verification`n- Tests executed and pass rate"
```
*(Or use `gh pr create --fill` if commit history is already cleanly formatted).*

---

## 3. Non-Interactive CI Monitoring

Antigravity executes in non-interactive subshells. Never run blocking interactive commands without flags:

### Watch Latest Run
```powershell
$run = (gh run list --limit 1 --json databaseId,status,conclusion,url | ConvertFrom-Json)
gh run watch $run.databaseId --exit-status --compact
```

### Triage CI Failures
If CI exits non-zero, inspect failed step logs directly:
```powershell
gh run view $run.databaseId --log-failed
```

---

## 4. PR Review & Comment Inspection

### Inspect Checks and Diff
```powershell
gh pr checks
gh pr diff
```

### Read Unresolved Comments
```powershell
gh pr view --comments
```
