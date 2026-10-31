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

    # Blocked: Process spawning of shell interpreters
    @{ Expected = "BLOCK"; Cmd = 'Start-Process cmd -ArgumentList "/c rd /s /q C:\test"'; Reason = "Start-Process cmd" },
    @{ Expected = "BLOCK"; Cmd = 'saps powershell -Args "-Command Remove-Item -Recurse C:\test"'; Reason = "saps alias" },

    # Blocked: Remove-Item aliases & recursive/root wipes
    @{ Expected = "BLOCK"; Cmd = 'rmdir -Recurse -Force C:\test'; Reason = "rmdir alias" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item C:\test -Recurse'; Reason = "Remove-Item without force" },
    @{ Expected = "BLOCK"; Cmd = 'rm -r C:\test'; Reason = "rm short alias" },
    @{ Expected = "BLOCK"; Cmd = 'del -Force C:\'; Reason = "Root target deletion" },

    # Blocked: Git destructive operations & bypasses
    @{ Expected = "BLOCK"; Cmd = 'git push origin main --force'; Reason = "git push force" },
    @{ Expected = "BLOCK"; Cmd = 'git push origin main --force-with-lease'; Reason = "git push force-with-lease" },
    @{ Expected = "BLOCK"; Cmd = 'git clean -fdx'; Reason = "git clean force" },
    @{ Expected = "BLOCK"; Cmd = 'git commit -m "fix" --no-verify'; Reason = "git commit no-verify" },

    # Blocked: Dynamic expression invocation & eval
    @{ Expected = "BLOCK"; Cmd = '& (Get-Command Remove-Item) -Recurse C:\test'; Reason = "Dynamic command invocation" },
    @{ Expected = "BLOCK"; Cmd = 'Invoke-Expression "Remove-Item C:\test"'; Reason = "Invoke-Expression" },
    @{ Expected = "BLOCK"; Cmd = 'iex "destructive"'; Reason = "iex alias" },

    # Blocked: Disk destruction
    @{ Expected = "BLOCK"; Cmd = 'Format-Volume -DriveLetter C'; Reason = "Format-Volume" },
    @{ Expected = "BLOCK"; Cmd = 'Clear-Disk -Number 0'; Reason = "Clear-Disk" },

    # Blocked: PowerShell parameter prefix abbreviations, colon booleans & uncheckpointed git reset --hard
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item C:\test -rec'; Reason = "Remove-Item -rec abbreviation" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item C:\test -Recurse:$true'; Reason = "Remove-Item -Recurse:`$true colon syntax" },
    @{ Expected = "BLOCK"; Cmd = 'git commit -m "msg" -n'; Reason = "git commit -n short bypass flag" },
    @{ Expected = "BLOCK"; Cmd = 'git reset --hard HEAD~1'; Reason = "Uncheckpointed git reset --hard" },

    # Blocked: Module-qualified cmdlets, splatting, secondary shells, and global git flags
    @{ Expected = "BLOCK"; Cmd = 'Microsoft.PowerShell.Management\Remove-Item C:\test -Recurse'; Reason = "Module-qualified Remove-Item" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item @splatParams'; Reason = "Splatted Remove-Item" },
    @{ Expected = "BLOCK"; Cmd = 'cmd.exe /c "rd /s /q C:\test"'; Reason = "cmd.exe subshell" },
    @{ Expected = "BLOCK"; Cmd = 'pwsh -Command "Remove-Item C:\test -Recurse"'; Reason = "pwsh -Command inline eval" },
    @{ Expected = "BLOCK"; Cmd = 'git.exe --work-tree=. clean -fdx'; Reason = "git.exe with global --work-tree flag" },
    @{ Expected = "BLOCK"; Cmd = 'git push origin +main:main'; Reason = "git push force refspec" },
    @{ Expected = "BLOCK"; Cmd = 'git restore .'; Reason = "git restore worktree discard" },

    # Allowed: Standard developer commands
    @{ Expected = "ALLOW"; Cmd = 'git status'; Reason = "git status" },
    @{ Expected = "ALLOW"; Cmd = 'rtk git log --oneline -n 10'; Reason = "rtk git log" },
    @{ Expected = "ALLOW"; Cmd = 'npm test'; Reason = "npm test" },
    @{ Expected = "ALLOW"; Cmd = 'python -m pytest tests/'; Reason = "python pytest" },
    @{ Expected = "ALLOW"; Cmd = 'pwsh -File .\scripts\build.ps1'; Reason = "pwsh script run" },

    # Allowed: Checkpoint rollback & commit messages containing flag text
    @{ Expected = "ALLOW"; Cmd = 'rtk git reset --hard checkpoint-fix-auth'; Reason = "Valid checkpoint branch reset" },
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
