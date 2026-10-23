# Contributing to Everyday-AGY

Thank you for your interest in contributing. `everyday-agy` is a personal configuration and workflow suite for Google Antigravity, but improvements, bug fixes, and well-grounded suggestions are always welcome.

---

## Guiding Principles

1. **Shortest Working Diff Wins**: Avoid speculative abstractions, single-implementation interfaces, and unneeded dependencies. Solve the concrete problem with the simplest robust approach.
2. **Anti-Slop Hygiene**: Keep code and documentation free of generic AI commentary, filler paragraphs, and corporate marketing puffery.
3. **Architecture Decision Records (ADRs)**: If you propose a non-trivial architectural change, directory reorganization, or new workflow concept, document the context, decision, and trade-offs in a new Nygard ADR under `docs/adr/`.
4. **Environment Realism**: Ground all documentation and tools in actual commands. Do not assume tools that are not verified in `GEMINI.md`.

---

## Local Development & Verification

Before submitting a pull request, run these local verification checks to ensure CI will pass cleanly.

### 1. PowerShell Script Syntax Check
Ensure all PowerShell scripts parse without syntax errors:
```powershell
Get-ChildItem -Path . -Filter "*.ps1" -Recurse | ForEach-Object {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$errors) | Out-Null
    if ($errors) {
        Write-Error "Syntax error in $($_.FullName): $errors"
    }
}
```

### 2. Run AST Command Security Tests
Verify that all 22 security interceptor test cases pass:
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File "config/skills/audit-dev-workflow/scripts/Test-PowerShellCommandSafety.Tests.ps1"
```

### 3. Verify Local Sync Script
Verify that `sync.ps1` runs its credential scan and copies cleanly without detecting unmasked secrets:
```powershell
powershell -ExecutionPolicy Bypass -File .\sync.ps1
```

---

## Submitting Pull Requests

1. **Branching**: Create a focused topic branch from `main` (e.g. `fix/ast-bypass` or `skill/my-workflow`).
2. **Atomic Commits**: Keep commits concise and descriptive. Avoid bundling unrelated formatting changes with logic updates.
3. **No Process Leaks**: Ensure no scratch files, debug notes, or temporary API keys are included in the commit.
4. **Pull Request Checklist**: Complete the PR template checklist when opening your pull request.
