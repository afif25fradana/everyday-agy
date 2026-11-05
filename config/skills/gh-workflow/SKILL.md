---
name: gh-workflow
description: GitHub CLI automation (/gh-workflow) for PR creation, non-interactive CI monitoring, and PR reviews via authenticated gh.
---

# GitHub Workflow (`gh-workflow`)

Operational playbook for managing Pull Requests and GitHub Actions CI pipelines via authenticated `gh` CLI.

---

## 1. Safety & Execution Rules

- **Execution Policy**: Do NOT prefix `gh` with `rtk` (run `gh` directly). Prefix `git` with `rtk` (e.g. `rtk git status`).
- **Explicit Approval & Subagent Ban**: Always prompt the user before pushing branches or creating/merging PRs. Subagents (`ROLE_TYPE: SUBAGENT`) are strictly barred from running `git push`, `gh pr create`, or `gh pr merge` autonomously.
- **Untrusted Event Injection Prevention**: In `.github/workflows/*.yml`, never interpolate untrusted GitHub event contexts (`${{ github.event.issue.body }}`, `${{ github.event.pull_request.title }}`, `${{ github.head_ref }}`, etc.) directly inside inline `run:` shell blocks. Always pass untrusted inputs through intermediate environment variables under `env:` (e.g. `TITLE: ${{ github.event.pull_request.title }}`) and reference `$env:TITLE` or `"$TITLE"` in scripts to prevent command injection.

---

## 2. Pull Request Lifecycle

### Step 1: Pre-flight Check
Ensure working directory is clean and branch is current:
```powershell
rtk git status --short
rtk git branch --show-current
```

### Step 2: Push Branch & Create PR (Post-Approval Only)
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

## 3. Non-Interactive CI Monitoring & Failure Recovery

Antigravity executes in non-interactive subshells. Never run blocking interactive commands without flags:

### Watch Latest Run (Matched to Current `HEAD` SHA)
Wait briefly if triggered immediately after `git push` so GitHub Actions registers the new workflow run, and verify `headSha` before watching:
```powershell
$headSha = (rtk git rev-parse HEAD).Trim()
$run = (gh run list --commit $headSha --limit 1 --json databaseId,headSha,status,conclusion,url | ConvertFrom-Json)
if (-not $run) {
    Start-Sleep -Seconds 3
    $run = (gh run list --commit $headSha --limit 1 --json databaseId,headSha,status,conclusion,url | ConvertFrom-Json)
}
if ($run) {
    gh run watch $run[0].databaseId --exit-status --compact
} else {
    Write-Warning "No CI run found yet for commit $headSha."
}
```

### Triage CI Failures & Stop-Rule
If CI exits non-zero, inspect failed step logs directly:
```powershell
gh run view $run[0].databaseId --log-failed
```
- **Stop-Rule**: Never re-trigger failed CI runs in a loop or push speculative fixes without user approval. If `gh` encounters authentication or rate-limit errors, report `Not Verified (gh auth/rate-limit)` and pause for operator direction.

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
