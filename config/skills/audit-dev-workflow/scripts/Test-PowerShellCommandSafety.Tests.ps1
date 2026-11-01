<#
.SYNOPSIS
    Automated regression and functional test suite for Test-PowerShellCommandSafety.ps1.
.DESCRIPTION
    Validates that prohibited commands (.NET direct deletes, Start-Process, rmdir, git clean,
    recursive deletions, and force pushes) are strictly blocked, while benign developer
    commands pass cleanly without interruption.
#>
$ErrorActionPreference = "Stop"

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = (Get-Location).Path }
$safetyValidator = Join-Path $scriptRoot "Test-PowerShellCommandSafety.ps1"

if (-not (Test-Path $safetyValidator)) {
    Write-Error "Test-PowerShellCommandSafety.ps1 not found at $safetyValidator!"
    exit 1
}

$testCases = @(
    # Blocked: Direct .NET File/Directory deletion
    @{ Expected = "BLOCK"; Cmd = '[System.IO.Directory]::Delete("C:\test", $true)'; Reason = ".NET Directory Delete" },
    @{ Expected = "BLOCK"; Cmd = '[System.IO.File]::Delete("C:\test\secret.key")'; Reason = ".NET File Delete" },
    @{ Expected = "BLOCK"; Cmd = '[IO.Directory]::Delete("C:\test", $true)'; Reason = "Short .NET Directory Delete" },
    @{ Expected = "BLOCK"; Cmd = '[IO.File]::Delete("C:\test\secret.key")'; Reason = "Short .NET File Delete" },
    @{ Expected = "BLOCK"; Cmd = '(Get-Item C:\test).Delete($true)'; Reason = "Instance method (Get-Item).Delete" },
    @{ Expected = "BLOCK"; Cmd = '(gi C:\test).Delete()'; Reason = "Instance method (gi).Delete alias" },
    @{ Expected = "BLOCK"; Cmd = '(gci C:\test).Delete()'; Reason = "Instance method (gci).Delete alias" },
    @{ Expected = "BLOCK"; Cmd = '(dir C:\test).Delete()'; Reason = "Instance method (dir).Delete alias" },
    @{ Expected = "BLOCK"; Cmd = '(ls C:\test).Delete()'; Reason = "Instance method (ls).Delete alias" },
    @{ Expected = "BLOCK"; Cmd = '[IO.DirectoryInfo]::new("C:\test").Delete($true)'; Reason = "Instance method [IO.DirectoryInfo]::new().Delete" },

    # Blocked: Process spawning of shell interpreters
    @{ Expected = "BLOCK"; Cmd = 'Start-Process cmd -ArgumentList "/c rd /s /q C:\test"'; Reason = "Start-Process cmd" },
    @{ Expected = "BLOCK"; Cmd = 'saps powershell -Args "-Command Remove-Item -Recurse C:\test"'; Reason = "saps alias" },

    # Blocked: Remove-Item aliases & recursive/root wipes
    @{ Expected = "BLOCK"; Cmd = 'rmdir -Recurse -Force C:\test'; Reason = "rmdir alias" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item C:\test -Recurse'; Reason = "Remove-Item without force" },
    @{ Expected = "BLOCK"; Cmd = 'rm -r C:\test'; Reason = "rm short alias" },
    @{ Expected = "BLOCK"; Cmd = 'del -Force C:\'; Reason = "Root target deletion" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item C:\*'; Reason = "Remove-Item root wildcard" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item -Force C:\*'; Reason = "Remove-Item -Force root wildcard" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item $HOME\*'; Reason = "Remove-Item env home wildcard" },

    # Blocked: Git destructive operations & bypasses
    @{ Expected = "BLOCK"; Cmd = 'git push origin main --force'; Reason = "git push force" },
    @{ Expected = "BLOCK"; Cmd = 'git push origin main --force-with-lease'; Reason = "git push force-with-lease" },
    @{ Expected = "BLOCK"; Cmd = 'git clean -fdx'; Reason = "git clean force" },
    @{ Expected = "BLOCK"; Cmd = 'git commit -m "fix" --no-verify'; Reason = "git commit no-verify" },
    @{ Expected = "BLOCK"; Cmd = 'git -c core.hooksPath=/dev/null commit -m "msg"'; Reason = "git -c core.hooksPath override" },
    @{ Expected = "BLOCK"; Cmd = 'git -c alias.ci="!rm -rf /" commit'; Reason = "git -c alias override" },
    @{ Expected = "BLOCK"; Cmd = 'git restore . --quiet'; Reason = "git restore . with trailing quiet flag" },
    @{ Expected = "BLOCK"; Cmd = 'git restore *'; Reason = "git restore wildcard worktree discard" },
    @{ Expected = "BLOCK"; Cmd = 'git checkout .'; Reason = "git checkout dot worktree discard" },

    # Blocked: Dynamic expression invocation & eval
    @{ Expected = "BLOCK"; Cmd = '& (Get-Command Remove-Item) -Recurse C:\test'; Reason = "Dynamic command invocation" },
    @{ Expected = "BLOCK"; Cmd = '. (Get-Command Remove-Item) -Recurse -Force C:\test'; Reason = "Dot-sourcing dynamic invocation" },
    @{ Expected = "BLOCK"; Cmd = '& $($cmd) -Recurse C:\test'; Reason = "SubExpressionAst invocation" },
    @{ Expected = "BLOCK"; Cmd = '. $($cmd) -Recurse C:\test'; Reason = "Dot-sourced SubExpressionAst" },
    @{ Expected = "BLOCK"; Cmd = '& "Remove-$x" -Recurse C:\test'; Reason = "ExpandableStringExpressionAst invocation" },
    @{ Expected = "BLOCK"; Cmd = '& @("Remove-Item")[0] -Recurse C:\test'; Reason = "IndexExpressionAst invocation" },
    @{ Expected = "BLOCK"; Cmd = 'Invoke-Expression "Remove-Item C:\test"'; Reason = "Invoke-Expression" },
    @{ Expected = "BLOCK"; Cmd = 'iex "destructive"'; Reason = "iex alias" },

    # Blocked: Disk destruction
    @{ Expected = "BLOCK"; Cmd = 'Format-Volume -DriveLetter C'; Reason = "Format-Volume" },
    @{ Expected = "BLOCK"; Cmd = 'Clear-Disk -Number 0'; Reason = "Clear-Disk" },

    # Blocked: PowerShell parameter prefix abbreviations, colon booleans & uncheckpointed git reset --hard
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item C:\test -rec'; Reason = "Remove-Item -rec abbreviation" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item C:\test -Recurse:$true'; Reason = "Remove-Item -Recurse:`$true colon syntax" },
    @{ Expected = "BLOCK"; Cmd = 'git commit -m "msg" -n'; Reason = "git commit -n short bypass flag" },
    @{ Expected = "BLOCK"; Cmd = 'git reset --hard HEAD~1'; Reason = "Uncheckpointed git reset --hard HEAD~1" },
    @{ Expected = "BLOCK"; Cmd = 'git reset --hard'; Reason = "git reset --hard without target checkpoint" },
    @{ Expected = "BLOCK"; Cmd = 'git reset --hard HEAD~1 checkpoint-fix-auth'; Reason = "git reset multiple non-flag arguments" },

    # Blocked: rtk proxy unwrapping bypasses
    @{ Expected = "BLOCK"; Cmd = 'rtk proxy git push --force'; Reason = "rtk proxy git push force" },
    @{ Expected = "BLOCK"; Cmd = 'rtk proxy git clean -fdx'; Reason = "rtk proxy git clean force" },
    @{ Expected = "BLOCK"; Cmd = 'rtk proxy cmd /c "del /f /s /q C:\test"'; Reason = "rtk proxy secondary shell cmd" },
    @{ Expected = "BLOCK"; Cmd = 'rtk proxy pwsh -Command "Remove-Item C:\test -Recurse"'; Reason = "rtk proxy pwsh inline eval" },

    # Blocked: Module-qualified cmdlets, splatting, secondary shells, and global git flags
    @{ Expected = "BLOCK"; Cmd = 'Microsoft.PowerShell.Management\Remove-Item C:\test -Recurse'; Reason = "Module-qualified Remove-Item" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item @splatParams'; Reason = "Splatted Remove-Item" },
    @{ Expected = "BLOCK"; Cmd = 'cmd.exe /c "rd /s /q C:\test"'; Reason = "cmd.exe subshell" },
    @{ Expected = "BLOCK"; Cmd = 'pwsh -Command "Remove-Item C:\test -Recurse"'; Reason = "pwsh -Command inline eval" },
    @{ Expected = "BLOCK"; Cmd = 'pwsh -NoProfile "Remove-Item C:\test -Recurse -Force"'; Reason = "pwsh positional inline eval" },
    @{ Expected = "BLOCK"; Cmd = 'powershell "Remove-Item C:\test -Recurse -Force"'; Reason = "powershell positional inline eval" },
    @{ Expected = "BLOCK"; Cmd = 'git.exe --work-tree=. clean -fdx'; Reason = "git.exe with global --work-tree flag" },
    @{ Expected = "BLOCK"; Cmd = 'git push origin +main:main'; Reason = "git push force refspec" },
    @{ Expected = "BLOCK"; Cmd = 'git restore .'; Reason = "git restore worktree discard" },

    # Allowed: Standard developer commands
    @{ Expected = "ALLOW"; Cmd = 'git status'; Reason = "git status" },
    @{ Expected = "ALLOW"; Cmd = 'rtk git log --oneline -n 10'; Reason = "rtk git log" },
    @{ Expected = "ALLOW"; Cmd = 'npm test'; Reason = "npm test" },
    @{ Expected = "ALLOW"; Cmd = 'python -m pytest tests/'; Reason = "python pytest" },
    @{ Expected = "ALLOW"; Cmd = 'pwsh -File .\scripts\build.ps1'; Reason = "pwsh script run" },
    @{ Expected = "ALLOW"; Cmd = 'pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1'; Reason = "pwsh script run with execution policy bypass" },
    @{ Expected = "ALLOW"; Cmd = 'rtk git restore --staged .'; Reason = "rtk git restore staged un-stage" },
    @{ Expected = "ALLOW"; Cmd = 'git restore --staged .'; Reason = "git restore staged un-stage" },
    @{ Expected = "ALLOW"; Cmd = 'git checkout -b feat/branch .'; Reason = "git checkout -b create branch" },
    @{ Expected = "ALLOW"; Cmd = 'git -c core.autocrlf=input status'; Reason = "benign git -c status" },

    # Allowed: Checkpoint rollback & commit messages containing flag text
    @{ Expected = "ALLOW"; Cmd = 'rtk git reset --hard checkpoint-fix-auth'; Reason = "Valid checkpoint branch reset" },
    @{ Expected = "ALLOW"; Cmd = 'git reset checkpoint-fix-auth --hard'; Reason = "Valid checkpoint branch reset with trailing --hard" },
    @{ Expected = "ALLOW"; Cmd = 'rtk proxy git status'; Reason = "rtk proxy benign command" },
    @{ Expected = "ALLOW"; Cmd = '& { Write-Host "safe scriptblock" }'; Reason = "Safe script block execution" },
    @{ Expected = "ALLOW"; Cmd = 'rtk git commit -m "fix(safety): block git clean -fdx and git push -f"'; Reason = "Commit message containing flag text" }
)

$passed = 0
$failed = 0

Write-Host ">>> Running Test-PowerShellCommandSafety Test Suite..." -ForegroundColor Cyan

foreach ($tc in $testCases) {
    $wasBlocked = $false
    $errMsg = ""

    try {
        $result = & $safetyValidator -CommandLine $tc.Cmd 2>&1
        if ($LASTEXITCODE -ne 0) {
            $wasBlocked = $true
            $errMsg = "$result"
        }
    } catch {
        $wasBlocked = $true
        $errMsg = $_.Exception.Message
    }

    if ($tc.Expected -eq "BLOCK") {
        if ($wasBlocked) {
            Write-Host "  [PASS] Blocked: $($tc.Reason)" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  [FAIL] Expected BLOCK, but command was ALLOWED: $($tc.Cmd)" -ForegroundColor Red
            $failed++
        }
    } elseif ($tc.Expected -eq "ALLOW") {
        if (-not $wasBlocked) {
            Write-Host "  [PASS] Allowed: $($tc.Reason)" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  [FAIL] Expected ALLOW, but command was BLOCKED: $($tc.Cmd) ($errMsg)" -ForegroundColor Red
            $failed++
        }
    }
}

$statusColor = if ($failed -eq 0) { "Green" } else { "Red" }
Write-Host ">>> Results: $passed Passed, $failed Failed." -ForegroundColor $statusColor

if ($failed -gt 0) {
    exit 1
}

exit 0
