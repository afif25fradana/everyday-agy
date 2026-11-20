<#
.SYNOPSIS
    Automated regression and functional test suite for Test-PowerShellCommandSafety.ps1.
.DESCRIPTION
    Validates that prohibited commands (.NET direct deletes, Start-Process, rmdir, git clean,
    recursive deletions, and force pushes) are strictly blocked, while benign developer
    commands pass cleanly without interruption.
#>
$ErrorActionPreference = "Stop"

$repoRoot = if ($PSScriptRoot) {
    Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
} else {
    (Get-Location).Path
}
$configScriptsDir = Join-Path (Join-Path $repoRoot "config") "scripts"
$safetyValidator = Join-Path $configScriptsDir "Test-PowerShellCommandSafety.ps1"

if (-not (Test-Path -LiteralPath $safetyValidator)) {
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
    @{ Expected = "BLOCK"; Cmd = 'git push origin +main'; Reason = "git push force refspec without colon" },
    @{ Expected = "BLOCK"; Cmd = 'git push origin :branch'; Reason = "git push remote branch deletion" },
    @{ Expected = "BLOCK"; Cmd = 'git push ''--force'''; Reason = "git push single-quoted force flag" },
    @{ Expected = "BLOCK"; Cmd = 'git push "--force"'; Reason = "git push double-quoted force flag" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item "-Recurse" "-Force" "C:\*"'; Reason = "quoted recursive root deletion" },
    @{ Expected = "BLOCK"; Cmd = 'start cmd "/c rd /s /q C:\"'; Reason = "start alias launching secondary shell" },
    @{ Expected = "BLOCK"; Cmd = 'sudo git push --force'; Reason = "sudo unwrapping git force push" },
    @{ Expected = "BLOCK"; Cmd = '[scriptblock]::Create(''git push --force'').Invoke()'; Reason = "Dynamic scriptblock reflection invocation" },
    @{ Expected = "BLOCK"; Cmd = 'Get-ChildItem -Recurse | Remove-Item -Force'; Reason = "Pipelined recursive Remove-Item" },
    @{ Expected = "BLOCK"; Cmd = 'git restore .'; Reason = "git restore worktree discard" },

    # Blocked: Double-dash wrappers, global git flags, compound switches, process execution & branch deletion
    @{ Expected = "BLOCK"; Cmd = 'rtk -- git clean -fdx'; Reason = "rtk double-dash wrapper unwrapping" },
    @{ Expected = "BLOCK"; Cmd = 'sudo -- git push --force'; Reason = "sudo double-dash wrapper unwrapping" },
    @{ Expected = "BLOCK"; Cmd = 'git --no-pager clean -fdx'; Reason = "git --no-pager global flag displacement" },
    @{ Expected = "BLOCK"; Cmd = 'git -P push --force'; Reason = "git -P global flag displacement" },
    @{ Expected = "BLOCK"; Cmd = 'git -p clean -fdx'; Reason = "git -p global flag displacement" },
    @{ Expected = "BLOCK"; Cmd = 'rm -rf ./dir'; Reason = "Compound POSIX -rf recursive deletion" },
    @{ Expected = "BLOCK"; Cmd = 'rm -fr ./dir'; Reason = "Compound POSIX -fr recursive deletion" },
    @{ Expected = "BLOCK"; Cmd = '$d.Delete($true)'; Reason = "Variable expression member .Delete() invocation" },
    @{ Expected = "BLOCK"; Cmd = '[System.Diagnostics.Process]::Start("cmd.exe", "/c echo bypass")'; Reason = "Direct .NET Process::Start invocation" },
    @{ Expected = "BLOCK"; Cmd = '[Diagnostics.Process]::Start("calc")'; Reason = "Direct short .NET Process::Start invocation" },
    @{ Expected = "BLOCK"; Cmd = 'git push origin --delete main'; Reason = "git push --delete remote branch" },
    @{ Expected = "BLOCK"; Cmd = 'git push origin -d main'; Reason = "git push -d remote branch" },
    @{ Expected = "BLOCK"; Cmd = 'git branch -D main'; Reason = "git branch -D force delete" },
    @{ Expected = "BLOCK"; Cmd = 'git restore -s HEAD .'; Reason = "git restore -s worktree discard" },
    @{ Expected = "BLOCK"; Cmd = 'git -c clean.requireForce=false clean -dx'; Reason = "git -c clean.requireForce override" },
    @{ Expected = "BLOCK"; Cmd = 'git -c core.editor=calc.exe commit'; Reason = "git -c core.editor override" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item ~/.ssh/id_rsa -Force'; Reason = "Remove-Item sensitive ~/.ssh target" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item $HOME/.aws/credentials -Force'; Reason = "Remove-Item sensitive ~/.aws target" },

    # Blocked: Process instantiation & instance execution (SEC-01)
    @{ Expected = "BLOCK"; Cmd = '[System.Diagnostics.Process]::new().Start()'; Reason = "Direct constructor [Process]::new().Start()" },
    @{ Expected = "BLOCK"; Cmd = '([System.Diagnostics.Process]::new()).Start()'; Reason = "Direct parenthesized [Process]::new().Start()" },
    @{ Expected = "BLOCK"; Cmd = '$p = [System.Diagnostics.Process]::new(); $p.Start()'; Reason = "Variable assigned [Process]::new() .Start()" },
    @{ Expected = "BLOCK"; Cmd = '(New-Object System.Diagnostics.Process).Start()'; Reason = "(New-Object Process).Start()" },
    @{ Expected = "BLOCK"; Cmd = '$p = New-Object System.Diagnostics.Process; $p.Start()'; Reason = "Variable assigned New-Object Process .Start()" },
    @{ Expected = "BLOCK"; Cmd = 'New-Object System.Diagnostics.Process'; Reason = "New-Object System.Diagnostics.Process" },

    # Blocked: Destructive git checkout file/pathspec discard (SEC-02)
    @{ Expected = "BLOCK"; Cmd = 'git checkout file.txt'; Reason = "git checkout file worktree discard" },
    @{ Expected = "BLOCK"; Cmd = 'git checkout -- file.txt'; Reason = "git checkout double-dash file discard" },
    @{ Expected = "BLOCK"; Cmd = 'git checkout src/app.ts'; Reason = "git checkout relative path discard" },
    @{ Expected = "BLOCK"; Cmd = 'git checkout .\file.txt'; Reason = "git checkout local prefix discard" },
    @{ Expected = "BLOCK"; Cmd = 'git checkout HEAD file.txt'; Reason = "git checkout multi-positional file discard" },

    # Blocked: Relative directory naked wildcard wipes (SEC-03)
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item *'; Reason = "Remove-Item naked wildcard wipe" },
    @{ Expected = "BLOCK"; Cmd = 'del *'; Reason = "del naked wildcard wipe" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item .\*'; Reason = "Remove-Item relative naked wildcard wipe" },

    # Blocked: Wrapper flags, backtick escapes, two-statement scriptblock variables, git switch/stash, robocopy /MIR (ADR-0003)
    @{ Expected = "BLOCK"; Cmd = 'rtk -v git push --force'; Reason = "rtk flag before git force push" },
    @{ Expected = "BLOCK"; Cmd = 'sudo -E rm -rf ./dir'; Reason = "sudo -E flag before recursive rm" },
    @{ Expected = "BLOCK"; Cmd = 'sudo -u root Remove-Item -Recurse C:\test'; Reason = "sudo -u user option before Remove-Item" },
    @{ Expected = "BLOCK"; Cmd = 'git push origin main --`force'; Reason = "backtick-escaped git push force flag" },
    @{ Expected = "BLOCK"; Cmd = 'i`ex "Remove-Item C:\test"'; Reason = "backtick-escaped iex command" },
    @{ Expected = "BLOCK"; Cmd = '$s = [scriptblock]::Create(''git push --force''); $s.Invoke()'; Reason = "two-statement scriptblock variable Invoke" },
    @{ Expected = "BLOCK"; Cmd = 'git switch -f main'; Reason = "git switch -f worktree discard" },
    @{ Expected = "BLOCK"; Cmd = 'git switch --discard-changes main'; Reason = "git switch --discard-changes worktree discard" },
    @{ Expected = "BLOCK"; Cmd = 'git stash clear'; Reason = "git stash clear destructive drop" },
    @{ Expected = "BLOCK"; Cmd = 'robocopy C:\empty C:\target /MIR'; Reason = "robocopy /MIR destructive mirror wipe" },

    # Blocked: Colon path parameter syntax, uncheckpointed git branch force, git worktree force, COM/WMI execution
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item -Path:C:\* -Force'; Reason = "Remove-Item -Path: colon parameter root wildcard" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item -LiteralPath:C:\* -Force'; Reason = "Remove-Item -LiteralPath: colon parameter root wildcard" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item -LiteralPath:~/.ssh/id_rsa -Force'; Reason = "Remove-Item -LiteralPath: sensitive ~/.ssh target" },
    @{ Expected = "BLOCK"; Cmd = 'git branch -f main HEAD~1'; Reason = "Uncheckpointed git branch -f overwrite" },
    @{ Expected = "BLOCK"; Cmd = 'git branch --force dev HEAD~2'; Reason = "Uncheckpointed git branch --force overwrite" },
    @{ Expected = "BLOCK"; Cmd = 'git worktree remove --force wt1'; Reason = "git worktree remove --force" },
    @{ Expected = "BLOCK"; Cmd = 'git worktree remove -f wt1'; Reason = "git worktree remove -f" },
    @{ Expected = "BLOCK"; Cmd = 'New-Object -ComObject WScript.Shell'; Reason = "New-Object -ComObject WScript.Shell execution" },
    @{ Expected = "BLOCK"; Cmd = 'New-Object -Com "Shell.Application"'; Reason = "New-Object -Com Shell.Application execution" },
    @{ Expected = "BLOCK"; Cmd = '([wmiclass]"Win32_Process").Create("calc.exe")'; Reason = "([wmiclass]Win32_Process).Create execution" },

    # Blocked: Remote execution and background jobs
    @{ Expected = "BLOCK"; Cmd = 'Invoke-Command -ScriptBlock { Get-Process }'; Reason = "Invoke-Command execution" },
    @{ Expected = "BLOCK"; Cmd = 'icm -ScriptBlock { Get-Process }'; Reason = "icm alias execution" },
    @{ Expected = "BLOCK"; Cmd = 'Start-Job -ScriptBlock { Get-Process }'; Reason = "Start-Job execution" },
    @{ Expected = "BLOCK"; Cmd = 'sajb -ScriptBlock { Get-Process }'; Reason = "sajb alias execution" },
    @{ Expected = "BLOCK"; Cmd = 'Start-ThreadJob -ScriptBlock { Get-Process }'; Reason = "Start-ThreadJob execution" },

    # Blocked: Compound and flag-order git branch force deletions
    @{ Expected = "BLOCK"; Cmd = 'git branch -df main'; Reason = "git branch -df compound force delete" },
    @{ Expected = "BLOCK"; Cmd = 'git branch -fd main'; Reason = "git branch -fd compound force delete" },
    @{ Expected = "BLOCK"; Cmd = 'git branch -f --delete main'; Reason = "git branch -f --delete force delete" },
    @{ Expected = "BLOCK"; Cmd = 'git branch --delete -f main'; Reason = "git branch --delete -f force delete" },

    # Blocked: COM/CLSID type reflection
    @{ Expected = "BLOCK"; Cmd = '[type]::GetTypeFromProgID("Scripting.FileSystemObject")'; Reason = "[type]::GetTypeFromProgID COM activation" },
    @{ Expected = "BLOCK"; Cmd = '[System.Type]::GetTypeFromCLSID("{00000000-0000-0000-0000-000000000000}")'; Reason = "[System.Type]::GetTypeFromCLSID COM activation" },

    # Blocked: Destructive checkout and branch overwrite with -m flag
    @{ Expected = "BLOCK"; Cmd = 'git checkout -m -f'; Reason = "git checkout -m -f destructive discard with merge flag" },
    @{ Expected = "BLOCK"; Cmd = 'git checkout -m --force'; Reason = "git checkout -m --force destructive discard with merge flag" },
    @{ Expected = "BLOCK"; Cmd = 'git branch -m -f dev main'; Reason = "git branch -m -f destructive branch overwrite" },
    @{ Expected = "BLOCK"; Cmd = 'git branch -M dev main'; Reason = "git branch -M uppercase force branch move" },
    @{ Expected = "BLOCK"; Cmd = 'git branch -m --force dev main'; Reason = "git branch -m --force branch overwrite" },

    # Blocked: Git config execution hijacking
    @{ Expected = "BLOCK"; Cmd = 'git config core.sshCommand calc.exe'; Reason = "git config core.sshCommand execution hijacking" },
    @{ Expected = "BLOCK"; Cmd = 'git config core.hooksPath /tmp'; Reason = "git config core.hooksPath hook hijacking" },
    @{ Expected = "BLOCK"; Cmd = 'git config core.editor calc.exe'; Reason = "git config core.editor editor hijacking" },
    @{ Expected = "BLOCK"; Cmd = 'git config alias.ci "!rm -rf /"'; Reason = "git config alias.ci command injection" },
    @{ Expected = "BLOCK"; Cmd = 'git config --global core.sshCommand calc.exe'; Reason = "git config --global core.sshCommand hijacking" },

    # Blocked: Relative sensitive directory deletion (.ssh, .aws, .gnupg)
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item .ssh\id_rsa'; Reason = "Remove-Item relative .ssh target with backslash" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item .aws\credentials'; Reason = "Remove-Item relative .aws target with backslash" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item .ssh/id_rsa'; Reason = "Remove-Item relative .ssh target with forward slash" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item .gnupg\secring.gpg'; Reason = "Remove-Item relative .gnupg target" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item -Force .ssh\id_rsa'; Reason = "Remove-Item -Force relative .ssh target" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item -LiteralPath .ssh\id_rsa -Force'; Reason = "Remove-Item -LiteralPath relative .ssh target" },
    @{ Expected = "BLOCK"; Cmd = 'rm .ssh/id_rsa'; Reason = "rm relative .ssh target" },
    @{ Expected = "BLOCK"; Cmd = 'rm .aws/credentials'; Reason = "rm relative .aws target" },

    # Blocked: Robocopy POSIX-style dash flags (-mir, -purge, -mov, -move)
    @{ Expected = "BLOCK"; Cmd = 'robocopy src dst -mir'; Reason = "robocopy -mir POSIX dash mirror flag" },
    @{ Expected = "BLOCK"; Cmd = 'robocopy src dst -purge'; Reason = "robocopy -purge POSIX dash purge flag" },
    @{ Expected = "BLOCK"; Cmd = 'robocopy src dst -MIR'; Reason = "robocopy -MIR uppercase POSIX dash mirror flag" },
    @{ Expected = "BLOCK"; Cmd = 'robocopy src dst -mov'; Reason = "robocopy -mov POSIX dash move files flag" },
    @{ Expected = "BLOCK"; Cmd = 'robocopy src dst -move'; Reason = "robocopy -move POSIX dash move files and dirs flag" },

    # Allowed: Standard developer commands
    @{ Expected = "ALLOW"; Cmd = 'git status'; Reason = "git status" },
    @{ Expected = "ALLOW"; Cmd = 'git push git@github.com:user/repo.git main'; Reason = "git push to SSH remote URL containing colon" },
    @{ Expected = "ALLOW"; Cmd = 'git push origin main'; Reason = "git push origin main" },
    @{ Expected = "ALLOW"; Cmd = 'rtk git log --oneline -n 10'; Reason = "rtk git log" },
    @{ Expected = "ALLOW"; Cmd = 'npm test'; Reason = "npm test" },
    @{ Expected = "ALLOW"; Cmd = 'python -m pytest tests/'; Reason = "python pytest" },
    @{ Expected = "ALLOW"; Cmd = 'pwsh -File .\scripts\build.ps1'; Reason = "pwsh script run" },
    @{ Expected = "ALLOW"; Cmd = 'pwsh -NoProfile -ExecutionPolicy Bypass -File .\scripts\build.ps1'; Reason = "pwsh script run with execution policy bypass" },
    @{ Expected = "ALLOW"; Cmd = 'rtk git restore --staged .'; Reason = "rtk git restore staged un-stage" },
    @{ Expected = "ALLOW"; Cmd = 'git restore --staged .'; Reason = "git restore staged un-stage" },
    @{ Expected = "ALLOW"; Cmd = 'git restore -S .'; Reason = "git restore -S uppercase staged un-stage" },
    @{ Expected = "ALLOW"; Cmd = 'Remove-Item -Path "temp.txt" -for -ErrorAction SilentlyContinue -Filter "*.log"'; Reason = "Benign parameter abbreviation -for and -Filter" },
    @{ Expected = "ALLOW"; Cmd = 'git checkout -b feat/branch .'; Reason = "git checkout -b create branch" },
    @{ Expected = "ALLOW"; Cmd = 'git switch -c feat/branch'; Reason = "git switch -c create branch" },
    @{ Expected = "ALLOW"; Cmd = 'git -c core.autocrlf=input status'; Reason = "benign git -c status" },

    # Allowed: Checkpoint rollback & commit messages containing flag text
    @{ Expected = "ALLOW"; Cmd = 'rtk git reset --hard checkpoint-fix-auth'; Reason = "Valid checkpoint branch reset" },
    @{ Expected = "ALLOW"; Cmd = 'git reset checkpoint-fix-auth --hard'; Reason = "Valid checkpoint branch reset with trailing --hard" },
    @{ Expected = "ALLOW"; Cmd = 'git branch -f checkpoint-test1 HEAD'; Reason = "Valid checkpoint branch creation with git branch -f" },
    @{ Expected = "ALLOW"; Cmd = 'git branch -d checkpoint-test1'; Reason = "Valid unforced branch deletion with git branch -d" },
    @{ Expected = "ALLOW"; Cmd = 'rtk proxy git status'; Reason = "rtk proxy benign command" },
    @{ Expected = "ALLOW"; Cmd = '& { Write-Host "safe scriptblock" }'; Reason = "Safe script block execution" },
    @{ Expected = "ALLOW"; Cmd = 'rtk git commit -m "fix(safety): block git clean -fdx and git push -f"'; Reason = "Commit message containing flag text" },
    @{ Expected = "ALLOW"; Cmd = 'git branch -f checkpoint-diff HEAD'; Reason = "git branch -f checkpoint-diff HEAD" },
    @{ Expected = "ALLOW"; Cmd = 'git branch -f checkpoint-pdf HEAD'; Reason = "git branch -f checkpoint-pdf HEAD" },
    @{ Expected = "ALLOW"; Cmd = '[System.Activator]::CreateInstance([System.Text.StringBuilder])'; Reason = "[System.Activator]::CreateInstance safe type" },
    @{ Expected = "ALLOW"; Cmd = 'git branch -m old-branch new-branch'; Reason = "git branch -m benign branch rename" },
    @{ Expected = "ALLOW"; Cmd = 'git config user.name "John Doe"'; Reason = "git config user.name benign config" },
    @{ Expected = "ALLOW"; Cmd = 'robocopy src dst *.txt'; Reason = "robocopy benign copy without mirror or purge" },

    # Allowed: Benign Process inspection and non-Process .Start() (SEC-01)
    @{ Expected = "ALLOW"; Cmd = '[System.Diagnostics.Process]::GetCurrentProcess().Id'; Reason = "Benign Process::GetCurrentProcess inspection" },
    @{ Expected = "ALLOW"; Cmd = '$sw = New-Object System.Diagnostics.Stopwatch; $sw.Start()'; Reason = "Benign Stopwatch.Start invocation" },

    # Allowed: Benign Git branch checkouts (SEC-02)
    @{ Expected = "ALLOW"; Cmd = 'git checkout main'; Reason = "git checkout branch switch" },
    @{ Expected = "ALLOW"; Cmd = 'git checkout dev'; Reason = "git checkout dev branch switch" },
    @{ Expected = "ALLOW"; Cmd = 'git checkout feat/auth'; Reason = "git checkout slash branch switch" },
    @{ Expected = "ALLOW"; Cmd = 'git checkout -b feat/branch'; Reason = "git checkout -b branch creation" },
    @{ Expected = "ALLOW"; Cmd = 'git checkout --detach HEAD'; Reason = "git checkout --detach" },
    @{ Expected = "ALLOW"; Cmd = 'git checkout --orphan new-branch'; Reason = "git checkout --orphan branch" },

    # Allowed: Filtered wildcard cleanup (SEC-03)
    @{ Expected = "ALLOW"; Cmd = 'Remove-Item *.log'; Reason = "Remove-Item filtered wildcard cleanup" },

    # Blocked: PowerShell AST parameter, pipeline, and reflection bypasses
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item -Recurse:1 C:\test'; Reason = "Remove-Item -Recurse:1 numeric truthy" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item -Recurse:($true) C:\test'; Reason = "Remove-Item -Recurse:(`$true) parenthesized" },
    @{ Expected = "BLOCK"; Cmd = "Remove-Item $([char]0x2013)Recurse C:\test"; Reason = "Remove-Item Unicode en-dash U+2013 Recurse" },
    @{ Expected = "BLOCK"; Cmd = "Remove-Item $([char]0x2014)Recurse C:\test"; Reason = "Remove-Item Unicode em-dash U+2014 Recurse" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item -pa:C:\*'; Reason = "Remove-Item abbreviated -pa: colon root wildcard" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item ${HOME}\*'; Reason = "Remove-Item `${HOME}\* braced home wildcard" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item ${env:USERPROFILE}\*'; Reason = "Remove-Item `${env:USERPROFILE}\* braced wildcard" },
    @{ Expected = "BLOCK"; Cmd = 'Remove-Item ${env:SystemDrive}\*'; Reason = "Remove-Item `${env:SystemDrive}\* braced wildcard" },
    @{ Expected = "BLOCK"; Cmd = 'Get-ChildItem -Recurse C:\test | ForEach-Object { Remove-Item $_.FullName -Force }'; Reason = "Nested PipelineAst upstream -Recurse into ForEach-Object" },
    @{ Expected = "BLOCK"; Cmd = 'Get-ChildItem C:\test -Depth 3 | ForEach-Object { Remove-Item $_.FullName }'; Reason = "Nested PipelineAst upstream -Depth into ForEach-Object" },
    @{ Expected = "BLOCK"; Cmd = 'Get-ChildItem C:\test | ForEach-Object Delete'; Reason = "ForEach-Object Delete member invocation" },
    @{ Expected = "BLOCK"; Cmd = 'Get-ChildItem C:\test | % Delete'; Reason = "Percent alias Delete member invocation" },
    @{ Expected = "BLOCK"; Cmd = '(Get-Item C:\test).("Delete")()'; Reason = "Parenthesized quoted member Delete invocation" },
    @{ Expected = "BLOCK"; Cmd = '([type]"System.Diagnostics.Process")::Start("calc")'; Reason = "Cast type expression Process::Start" },
    @{ Expected = "BLOCK"; Cmd = '[PowerShell]::Create().AddScript("whoami").BeginInvoke()'; Reason = "PowerShell BeginInvoke dynamic execution" },
    @{ Expected = "BLOCK"; Cmd = '$ExecutionContext.InvokeCommand.ExpandString("$(whoami)")'; Reason = "InvokeCommand.ExpandString dynamic execution" },

    # Blocked: Git AST clustered flag, config-env, and branch target bypasses
    @{ Expected = "BLOCK"; Cmd = 'git push -uf origin main'; Reason = "git push clustered -uf force flag" },
    @{ Expected = "BLOCK"; Cmd = 'git push -ud origin main'; Reason = "git push clustered -ud delete flag" },
    @{ Expected = "BLOCK"; Cmd = 'git push origin :feat+1'; Reason = "git push remote deletion with + in branch name" },
    @{ Expected = "BLOCK"; Cmd = 'git --config-env=core.hooksPath=EVIL status'; Reason = "git --config-env= inline security override" },
    @{ Expected = "BLOCK"; Cmd = 'git --config-env core.editor=EVIL commit -m "hi"'; Reason = "git --config-env split security override" },
    @{ Expected = "BLOCK"; Cmd = 'git commit -nm "bypass"'; Reason = "git commit clustered -nm no-verify flag" },
    @{ Expected = "BLOCK"; Cmd = 'git restore -qW .'; Reason = "git restore clustered -qW worktree discard" },
    @{ Expected = "BLOCK"; Cmd = 'git checkout -mf'; Reason = "git checkout clustered -mf force discard" },
    @{ Expected = "BLOCK"; Cmd = 'git switch -qf main'; Reason = "git switch clustered -qf force discard" },
    @{ Expected = "BLOCK"; Cmd = 'git switch -C main'; Reason = "git switch -C force create overwrite" },
    @{ Expected = "BLOCK"; Cmd = 'git branch -M old-branch main'; Reason = "git branch -M overwriting destination main" },
    @{ Expected = "BLOCK"; Cmd = 'git branch -c -f new-dest main'; Reason = "git branch -c -f overwriting destination main" },
    @{ Expected = "BLOCK"; Cmd = 'git branch -f main checkpoint-ok'; Reason = "git branch -f overwriting first arg main" },

    # Allowed: Explicit non-recursive opt-outs and benign git flags
    @{ Expected = "ALLOW"; Cmd = 'Remove-Item -Recurse:($false) temp.txt'; Reason = "Remove-Item -Recurse:(`$false) explicit opt-out" },
    @{ Expected = "ALLOW"; Cmd = 'Remove-Item -Recurse:$false temp.txt'; Reason = "Remove-Item -Recurse:`$false explicit opt-out" },
    @{ Expected = "ALLOW"; Cmd = 'Remove-Item -Recurse:0 temp.txt'; Reason = "Remove-Item -Recurse:0 explicit opt-out" },
    @{ Expected = "ALLOW"; Cmd = 'git restore -h'; Reason = "git restore -h lone help flag" },
    @{ Expected = "ALLOW"; Cmd = 'git restore --help'; Reason = "git restore --help lone help flag" },
    @{ Expected = "ALLOW"; Cmd = 'git --no-optional-locks status'; Reason = "git --no-optional-locks global boolean" },
    @{ Expected = "ALLOW"; Cmd = 'git commit -am "fix -n flag docs"'; Reason = "git commit -am message containing -n" },
    @{ Expected = "ALLOW"; Cmd = 'git push -n origin main'; Reason = "git push -n dry-run" },
    @{ Expected = "ALLOW"; Cmd = 'git branch -M old-branch checkpoint-dest'; Reason = "git branch -M to checkpoint-* destination" },
    @{ Expected = "ALLOW"; Cmd = 'git -h'; Reason = "git -h global help" },

    # Dynamic Member Invocations & MemberName bindings
    @{ Expected = "BLOCK"; Cmd = '[System.IO.Directory]::("Del"+"ete")("C:\test")'; Reason = "Dynamic ParenExpressionAst member invocation" },
    @{ Expected = "BLOCK"; Cmd = '$m = "Delete"; [System.IO.File]::$m("C:\test.txt")'; Reason = "Dynamic VariableExpressionAst member invocation" },
    @{ Expected = "BLOCK"; Cmd = '$t = [System.IO.Directory]; $t::("Del"+"ete")("C:\test")'; Reason = "Variable type dynamic member invocation" },
    @{ Expected = "BLOCK"; Cmd = '(Get-Item C:\test).("Del"+"ete")()'; Reason = "Pipeline object dynamic member invocation" },
    @{ Expected = "BLOCK"; Cmd = 'Get-ChildItem | ForEach-Object ("Del"+"ete")'; Reason = "Dynamic ForEach-Object positional member" },
    @{ Expected = "BLOCK"; Cmd = '$m = "Delete"; Get-ChildItem | % -MemberName $m'; Reason = "Dynamic ForEach-Object -MemberName variable" },
    @{ Expected = "BLOCK"; Cmd = 'Get-ChildItem | ForEach-Object -MemberName Delete'; Reason = "ForEach-Object -MemberName Delete" },
    @{ Expected = "BLOCK"; Cmd = 'Get-ChildItem | % Delete'; Reason = "ForEach-Object positional Delete member" },
    @{ Expected = "ALLOW"; Cmd = '[System.String]::Concat("a", "b")'; Reason = "Constant non-prohibited static method" },
    @{ Expected = "ALLOW"; Cmd = 'Get-ChildItem | % FullName'; Reason = "ForEach-Object benign positional member" },
    @{ Expected = "ALLOW"; Cmd = 'Get-ChildItem | ForEach-Object -MemberName FullName'; Reason = "ForEach-Object benign -MemberName" },

    # Cmdlet Aliasing
    @{ Expected = "BLOCK"; Cmd = 'Set-Alias -Name mydel -Value Remove-Item'; Reason = "Set-Alias definition" },
    @{ Expected = "BLOCK"; Cmd = 'New-Alias -Name wipe -Value Remove-Item'; Reason = "New-Alias definition" },
    @{ Expected = "BLOCK"; Cmd = 'sal wipe Clear-Disk'; Reason = "sal alias shorthand" },
    @{ Expected = "BLOCK"; Cmd = 'nal wipe Remove-Item'; Reason = "nal alias shorthand" },

    # Git Subcommands & Flags (--mirror, --prune, -B checkpoint restriction)
    @{ Expected = "BLOCK"; Cmd = 'git push --mirror origin'; Reason = "git push --mirror destructive ref wipe" },
    @{ Expected = "BLOCK"; Cmd = 'git push --prune origin'; Reason = "git push --prune remote branch deletion" },
    @{ Expected = "BLOCK"; Cmd = 'git push origin --mirror'; Reason = "git push origin --mirror" },
    @{ Expected = "BLOCK"; Cmd = 'git push origin --prune'; Reason = "git push origin --prune" },
    @{ Expected = "BLOCK"; Cmd = 'git checkout -B main'; Reason = "git checkout -B non-checkpoint branch force-reset" },
    @{ Expected = "BLOCK"; Cmd = 'git checkout -B feature/foo'; Reason = "git checkout -B non-checkpoint branch feature/foo" },
    @{ Expected = "ALLOW"; Cmd = 'git checkout -B checkpoint-task1'; Reason = "git checkout -B checkpoint branch reset" },
    @{ Expected = "ALLOW"; Cmd = 'git checkout -b feature/foo'; Reason = "git checkout -b non-force new branch" },

    # Git -c and config security overrides
    @{ Expected = "BLOCK"; Cmd = 'git -c core.pager=calc.exe log'; Reason = "git -c core.pager external process execution" },
    @{ Expected = "BLOCK"; Cmd = 'git -c pager.log=calc.exe log'; Reason = "git -c pager.<cmd> external process execution" },
    @{ Expected = "BLOCK"; Cmd = 'git -c credential.helper=calc.exe fetch'; Reason = "git -c credential.helper external execution" },
    @{ Expected = "BLOCK"; Cmd = 'git -c diff.external=calc.exe diff'; Reason = "git -c diff.external external execution" },
    @{ Expected = "BLOCK"; Cmd = 'git -c merge.tool=calc.exe mergetool'; Reason = "git -c merge.tool external execution" },
    @{ Expected = "BLOCK"; Cmd = 'git -c filter.clean.clean=calc.exe status'; Reason = "git -c filter clean execution sink" },
    @{ Expected = "BLOCK"; Cmd = 'git config core.pager calc.exe'; Reason = "git config core.pager external process execution" },
    @{ Expected = "BLOCK"; Cmd = 'git config credential.helper calc.exe'; Reason = "git config credential.helper external execution" }
)

$passed = 0
$failed = 0

Write-Host ">>> Running Test-PowerShellCommandSafety Test Suite..." -ForegroundColor Cyan

foreach ($tc in $testCases) {
    $global:LASTEXITCODE = 0
    $wasBlocked = $false
    $errMsg = ""
    $result = $null

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
        if ($wasBlocked -and ($errMsg -match 'Safety Violation:')) {
            Write-Host "  [PASS] Blocked: $($tc.Reason)" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  [FAIL] Expected BLOCK with 'Safety Violation:', but got wasBlocked=$wasBlocked, errMsg=$errMsg ($($tc.Cmd))" -ForegroundColor Red
            $failed++
        }
    } elseif ($tc.Expected -eq "ALLOW") {
        if (-not $wasBlocked -and ($result | Select-Object -Last 1) -eq $true) {
            Write-Host "  [PASS] Allowed: $($tc.Reason)" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  [FAIL] Expected ALLOW with `$true result, but command failed: $($tc.Cmd) (wasBlocked=$wasBlocked, result=$result, err=$errMsg)" -ForegroundColor Red
            $failed++
        }
    }
}

# Stdin non-blocking -File, [AllowEmptyString()], and multi-item pipeline regression tests
$safetyPsExe = if ($PSVersionTable.PSEdition -eq "Core") { (Get-Process -Id $PID).Path } else { Join-Path $PSHOME "powershell.exe" }
$stdinPsi = New-Object System.Diagnostics.ProcessStartInfo
$stdinPsi.FileName = $safetyPsExe
$stdinPsi.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$safetyValidator`" -CommandLine `"git status`""
$stdinPsi.UseShellExecute = $false
$stdinPsi.RedirectStandardInput = $true
$stdinPsi.RedirectStandardOutput = $true
$stdinPsi.RedirectStandardError = $true
$stdinProc = [System.Diagnostics.Process]::Start($stdinPsi)
$stdinOutTask = $stdinProc.StandardOutput.ReadToEndAsync()
$stdinErrTask = $stdinProc.StandardError.ReadToEndAsync()
$stdinExited = $stdinProc.WaitForExit(2000)
if (-not $stdinExited) {
    try { $stdinProc.Kill() } catch {}
    try { $null = $stdinProc.WaitForExit(1000) } catch {}
} else {
    try { $stdinProc.StandardInput.Close() } catch {}
}
$stdinOutText = if ($stdinExited) { $stdinOutTask.Result.Trim() } else { "<TIMED_OUT>" }
if ($stdinExited -and $stdinProc.ExitCode -eq 0 -and $stdinOutText -eq "True") {
    Write-Host "  [PASS] Safety validator exits immediately without draining open stdin" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  [FAIL] Safety validator hung or failed with open stdin (exited=$stdinExited, code=$(if ($stdinExited) { $stdinProc.ExitCode } else { 'N/A' }), out=$stdinOutText)" -ForegroundColor Red
    $failed++
}

$global:LASTEXITCODE = 0
$emptyFailed = $false
$emptyRes = $null
try {
    $emptyRes = & $safetyValidator -CommandLine "" 2>&1
    if ($LASTEXITCODE -ne 0) { $emptyFailed = $true }
} catch {
    $emptyFailed = $true
}
if (-not $emptyFailed -and ($emptyRes | Select-Object -Last 1) -eq $true) {
    Write-Host "  [PASS] Safety validator accepts empty string via [AllowEmptyString()]" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  [FAIL] Safety validator rejected empty CommandLine string (failed=$emptyFailed, res=$emptyRes)" -ForegroundColor Red
    $failed++
}

$global:LASTEXITCODE = 0
$pipeBlocked = $false
$pipeMsg = ""
try {
    $pipeRes = @("", "Remove-Item -Recurse C:\*") | & $safetyValidator 2>&1
    if ($LASTEXITCODE -ne 0) {
        $pipeBlocked = $true
        $pipeMsg = "$pipeRes"
    }
} catch {
    $pipeBlocked = $true
    $pipeMsg = $_.Exception.Message
}
if ($pipeBlocked -and $pipeMsg -match 'Safety Violation:') {
    Write-Host "  [PASS] Multi-item pipeline (@('', destructive)) blocks element 2 with exit 1" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  [FAIL] Multi-item pipeline (@('', destructive)) failed to block element 2 (blocked=$pipeBlocked, msg=$pipeMsg)" -ForegroundColor Red
    $failed++
}

$global:LASTEXITCODE = 0
$pipeFirstBlocked = $false
$pipeFirstMsg = ""
try {
    $pipeFirstRes = @("Remove-Item -Recurse C:\*", "git status") | & $safetyValidator 2>&1
    if ($LASTEXITCODE -ne 0) {
        $pipeFirstBlocked = $true
        $pipeFirstMsg = "$pipeFirstRes"
    }
} catch {
    $pipeFirstBlocked = $true
    $pipeFirstMsg = $_.Exception.Message
}
if ($pipeFirstBlocked -and $pipeFirstMsg -match 'Safety Violation:') {
    Write-Host "  [PASS] Multi-item pipeline (@(destructive, safe)) blocks element 1 with exit 1" -ForegroundColor Green
    $passed++
} else {
    Write-Host "  [FAIL] Multi-item pipeline (@(destructive, safe)) failed to block element 1 (blocked=$pipeFirstBlocked, msg=$pipeFirstMsg)" -ForegroundColor Red
    $failed++
}

Write-Host "`n>>> Running Deployment & Sync Sandbox Test Suite..." -ForegroundColor Cyan

function Assert-HookCondition {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$Details = ""
    )
    if ($Condition) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:passed++
    } else {
        Write-Host "  [FAIL] $Name $(if ($Details) { "- $Details" })" -ForegroundColor Red
        $script:failed++
    }
}

$hookTestId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
$hookTempDir = Join-Path ([System.IO.Path]::GetTempPath()) "agy_sandbox_test_$hookTestId"
$isolatedHome = Join-Path $hookTempDir "home"
New-Item -ItemType Directory -Path $isolatedHome -Force | Out-Null

try {
    # Sandbox tests for repo-scoped restore.ps1 and sync.ps1
    $syncRepo = Join-Path $hookTempDir "sync_repo"
    $syncHome = Join-Path $hookTempDir "sync_home"
    New-Item -ItemType Directory -Path `
        (Join-Path $syncRepo "config/scripts"),
        (Join-Path $syncRepo "config/agents/tdd-guide"),
        (Join-Path $syncRepo "config/skills/orchestrator"),
        (Join-Path $syncRepo "docs/adr"),
        (Join-Path $syncHome ".gemini/docs/adr"),
        (Join-Path $syncHome ".gemini/config/docs/adr"),
        (Join-Path $syncHome ".gemini/config/scripts/stale_sub"),
        (Join-Path $syncHome ".gemini/config/skills/custom-external-skill"),
        (Join-Path $syncHome ".gemini/config/skills/audit-dev-workflow"),
        (Join-Path $syncHome ".gemini/config/skills/orchestrator/scripts"),
        (Join-Path $syncHome ".gemini/config/agents/database-reviewer"),
        (Join-Path $syncHome ".gemini/config/plugins/my-marketplace-plugin") -Force | Out-Null

    $rootSync = Join-Path $repoRoot "sync.ps1"
    $rootRestore = Join-Path $repoRoot "restore.ps1"
    Copy-Item -LiteralPath $rootSync -Destination (Join-Path $syncRepo "sync.ps1") -Force
    Copy-Item -LiteralPath $rootRestore -Destination (Join-Path $syncRepo "restore.ps1") -Force
    Set-Content -LiteralPath (Join-Path $syncRepo "config/GEMINI.md") -Value "# Repo GEMINI" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/hooks.json") -Value "{}" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/scripts/Invoke-AntigravityHook.ps1") -Value "# Hook script" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/scripts/Test-PowerShellCommandSafety.ps1") -Value "# Safety script" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/scripts/New-AuditCheckpoint.ps1") -Value "# New checkpoint script" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/scripts/Restore-AuditCheckpoint.ps1") -Value "# Restore checkpoint script" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/scripts/Update-Gate2Diff.ps1") -Value "# Gate2 diff script" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/scripts/invoke-antigravity-hook.mjs") -Value "// Hook script" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/agents/tdd-guide/agent.md") -Value "name: tdd-guide" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/skills/orchestrator/SKILL.md") -Value "name: orchestrator" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "docs/adr/README.md") -Value "# ADR" -Encoding utf8

    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/docs/adr/0001-old.md") -Value "# Old ADR" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/docs/adr/0001-old.md") -Value "# Legacy Old ADR" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/hooks.json") -Value '{"old":true}' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/orphan-script.ps1") -Value "# Orphan script" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/stale_sub/retired.ps1") -Value "# Nested orphan script" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/skills/custom-external-skill/SKILL.md") -Value "external" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/skills/audit-dev-workflow/SKILL.md") -Value "retired" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/skills/orchestrator/orphan.txt") -Value "stale" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/skills/orchestrator/scripts/Test-PowerShellCommandSafety.ps1") -Value "# Stale skill safety script" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/skills/orchestrator/scripts/Update-Gate2Diff.ps1") -Value "# Legacy skill gate2 diff script" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/agents/database-reviewer/agent.md") -Value "retired" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/plugins/my-marketplace-plugin/plugin.json") -Value "{}" -Encoding utf8

    $psExe = if ($PSVersionTable.PSEdition -eq "Core") { (Get-Process -Id $PID).Path } else { Join-Path $PSHOME "powershell.exe" }
    function Invoke-SandboxScript {
        param([string]$ScriptPath, [switch]$Detailed)
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $psExe
        $psi.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$ScriptPath`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.EnvironmentVariables["USERPROFILE"] = $syncHome
        $psi.EnvironmentVariables["HOME"] = $syncHome
        $proc = [System.Diagnostics.Process]::Start($psi)
        $outTask = $proc.StandardOutput.ReadToEndAsync()
        $errTask = $proc.StandardError.ReadToEndAsync()
        $proc.WaitForExit()
        $outText = $outTask.Result
        $errText = $errTask.Result
        if ($Detailed) {
            return [PSCustomObject]@{
                ExitCode = $proc.ExitCode
                StdOut   = $outText
                StdErr   = $errText
            }
        }
        return $proc.ExitCode
    }

    $restoreRes = Invoke-SandboxScript -ScriptPath (Join-Path $syncRepo "restore.ps1") -Detailed
    $restoreExit = $restoreRes.ExitCode

    $externalPreserved = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/skills/custom-external-skill/SKILL.md")
    $pluginPreserved = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/plugins/my-marketplace-plugin/plugin.json")
    $retiredAgentGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/agents/database-reviewer"))
    $retiredSkillGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/skills/audit-dev-workflow"))
    $orphanFileGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/skills/orchestrator/orphan.txt"))
    $staleSkillSafetyGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/skills/orchestrator/scripts/Test-PowerShellCommandSafety.ps1"))
    $staleSkillGate2Gone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/skills/orchestrator/scripts/Update-Gate2Diff.ps1"))
    $staleSkillScriptsDirGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/skills/orchestrator/scripts"))
    $hooksDeployed = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/hooks.json")
    $scriptDeployed = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/Invoke-AntigravityHook.ps1")
    $safetyScriptDeployed = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/Test-PowerShellCommandSafety.ps1")
    $newCheckpointDeployed = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/New-AuditCheckpoint.ps1")
    $restoreCheckpointDeployed = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/Restore-AuditCheckpoint.ps1")
    $gate2DiffDeployed = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/Update-Gate2Diff.ps1")
    $nodeHookDeployed = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/invoke-antigravity-hook.mjs")
    $orphanScriptGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/orphan-script.ps1"))
    $orphanScriptSubGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/stale_sub"))
    $reportedSixScripts = $restoreRes.StdOut -match 'Restored 6 Config Scripts'
    $hooksBackedUp = @(Get-ChildItem -Path (Join-Path $syncHome ".gemini") -Filter "backup_*" -Directory | ForEach-Object { Join-Path $_.FullName "hooks.json" } | Where-Object { Test-Path $_ }).Count -gt 0
    $docsAdrGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/docs/adr"))
    $docsParentGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/docs"))
    $legacyDocsAdrGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/docs/adr"))
    $legacyDocsParentGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/docs"))

    Assert-HookCondition -Name "restore.ps1 preserves unrecognized skills & plugins while pruning retired repo names, skill orphans, and legacy orchestrator/scripts/" -Condition ($restoreExit -eq 0 -and $externalPreserved -and $pluginPreserved -and $retiredAgentGone -and $retiredSkillGone -and $orphanFileGone -and $staleSkillSafetyGone -and $staleSkillGate2Gone -and $staleSkillScriptsDirGone) -Details "ext=$externalPreserved plug=$pluginPreserved retA=$retiredAgentGone retS=$retiredSkillGone orph=$orphanFileGone staleSafetyGone=$staleSkillSafetyGone staleGate2Gone=$staleSkillGate2Gone staleDirGone=$staleSkillScriptsDirGone"
    Assert-HookCondition -Name "restore.ps1 backs up and deploys 6 Config Scripts while pruning orphan scripts/" -Condition ($hooksDeployed -and $scriptDeployed -and $safetyScriptDeployed -and $newCheckpointDeployed -and $restoreCheckpointDeployed -and $gate2DiffDeployed -and $nodeHookDeployed -and $orphanScriptGone -and $orphanScriptSubGone -and $reportedSixScripts -and $hooksBackedUp) -Details "hook=$scriptDeployed safety=$safetyScriptDeployed newCkpt=$newCheckpointDeployed resCkpt=$restoreCheckpointDeployed gate2=$gate2DiffDeployed nodeHook=$nodeHookDeployed orphScr=$orphanScriptGone orphSub=$orphanScriptSubGone msg6=$reportedSixScripts bak=$hooksBackedUp"
    Assert-HookCondition -Name "restore.ps1 prunes ~/.gemini/docs/adr, ~/.gemini/config/docs/adr, and empty parent docs/ directories" -Condition ($restoreExit -eq 0 -and $docsAdrGone -and $docsParentGone -and $legacyDocsAdrGone -and $legacyDocsParentGone) -Details "docsAdrGone=$docsAdrGone docsParentGone=$docsParentGone legacyAdrGone=$legacyDocsAdrGone legacyParentGone=$legacyDocsParentGone"

    # Verify sync.ps1 pulls back only tracked items and guards against empty source deletion
    New-Item -ItemType Directory -Path (Join-Path $syncHome ".gemini/config/agents/untracked-user-agent") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/agents/untracked-user-agent/agent.md") -Value "user-owned" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/hooks.json") -Value '{"updatedByUser":true}' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/Test-PowerShellCommandSafety.ps1") -Value "# Updated safety script" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/untracked-script.ps1") -Value "# Untracked user script" -Encoding utf8
    Remove-Item -LiteralPath (Join-Path $syncHome ".gemini/config/skills/orchestrator/SKILL.md") -Force
    Remove-Item -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/Update-Gate2Diff.ps1") -Force

    $repoAdrReadme = Join-Path $syncRepo "docs/adr/README.md"
    $adrSentinelUtc = [datetime]::SpecifyKind([datetime]"2020-01-01T00:00:00", [System.DateTimeKind]::Utc)
    [System.IO.File]::SetLastWriteTimeUtc($repoAdrReadme, $adrSentinelUtc)
    $adrAbsentBeforeSync = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/docs/adr"))

    $syncExit = Invoke-SandboxScript -ScriptPath (Join-Path $syncRepo "sync.ps1")

    $syncedHooks = (Get-Content -LiteralPath (Join-Path $syncRepo "config/hooks.json") -Raw).Trim() -eq '{"updatedByUser":true}'
    $syncedSafetyScript = (Get-Content -LiteralPath (Join-Path $syncRepo "config/scripts/Test-PowerShellCommandSafety.ps1") -Raw).Trim() -eq "# Updated safety script"
    $ignoredUntrackedScript = -not (Test-Path -LiteralPath (Join-Path $syncRepo "config/scripts/untracked-script.ps1"))
    $ignoredUntrackedAgent = -not (Test-Path -LiteralPath (Join-Path $syncRepo "config/agents/untracked-user-agent"))
    $ignoredExternalSkill = -not (Test-Path -LiteralPath (Join-Path $syncRepo "config/skills/custom-external-skill"))
    $emptySourcePreserved = (Test-Path -LiteralPath (Join-Path $syncRepo "config/skills/orchestrator/SKILL.md")) -and (Test-Path -LiteralPath (Join-Path $syncRepo "config/scripts/Update-Gate2Diff.ps1"))
    $adrReadmeUntouched = (Test-Path -LiteralPath $repoAdrReadme) -and ([System.IO.File]::GetLastWriteTimeUtc($repoAdrReadme) -eq $adrSentinelUtc) -and ((Get-Content -LiteralPath $repoAdrReadme -Raw).Trim() -eq "# ADR")

    Assert-HookCondition -Name "sync.ps1 pulls back tracked hooks.json and scripts, ignores unrecognized items, and guards against empty source deletion" -Condition ($syncExit -eq 0 -and $syncedHooks -and $syncedSafetyScript -and $ignoredUntrackedScript -and $ignoredUntrackedAgent -and $ignoredExternalSkill -and $emptySourcePreserved) -Details "hooks=$syncedHooks safety=$syncedSafetyScript ignScr=$ignoredUntrackedScript ignA=$ignoredUntrackedAgent ignS=$ignoredExternalSkill emptyGuard=$emptySourcePreserved"
    Assert-HookCondition -Name "sync.ps1 neither creates nor touches repo docs/adr/README.md when ~/.gemini/docs/adr is absent" -Condition ($syncExit -eq 0 -and $adrAbsentBeforeSync -and $adrReadmeUntouched) -Details "adrAbsentBeforeSync=$adrAbsentBeforeSync adrReadmeUntouched=$adrReadmeUntouched"

    # Verify restore.ps1 preserves non-empty sibling files in docs/ and sync.ps1 ignores stale ~/.gemini/docs/adr
    New-Item -ItemType Directory -Path (Join-Path $syncHome ".gemini/docs/adr"), (Join-Path $syncHome ".gemini/config/docs/adr") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/docs/notes.txt") -Value "keep-docs" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/docs/adr/0002-stale.md") -Value "# Stale" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/docs/adr/README.md") -Value "# Overwrite" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/docs/notes.txt") -Value "keep-legacy-docs" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/docs/adr/0002-stale.md") -Value "# Legacy Stale" -Encoding utf8

    Remove-Item -LiteralPath $repoAdrReadme -Force
    $syncStaleExit = Invoke-SandboxScript -ScriptPath (Join-Path $syncRepo "sync.ps1")
    $staleAdrNotSynced = (-not (Test-Path -LiteralPath $repoAdrReadme)) -and (-not (Test-Path -LiteralPath (Join-Path $syncRepo "docs/adr/0002-stale.md")))
    Assert-HookCondition -Name "sync.ps1 never syncs or creates repo docs/adr files even when ~/.gemini/docs/adr exists" -Condition ($syncStaleExit -eq 0 -and $staleAdrNotSynced) -Details "staleAdrNotSynced=$staleAdrNotSynced"

    $restoreSiblingExit = Invoke-SandboxScript -ScriptPath (Join-Path $syncRepo "restore.ps1")
    $docsSiblingPreserved = (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/docs/notes.txt")) -and (-not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/docs/adr")))
    $legacySiblingPreserved = (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/docs/notes.txt")) -and (-not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/docs/adr")))
    Assert-HookCondition -Name "restore.ps1 preserves non-empty sibling files in ~/.gemini/docs and ~/.gemini/config/docs while pruning adr/" -Condition ($restoreSiblingExit -eq 0 -and $docsSiblingPreserved -and $legacySiblingPreserved) -Details "docsSibling=$docsSiblingPreserved legacySibling=$legacySiblingPreserved"
} finally {
    if (Test-Path -LiteralPath $hookTempDir) {
        Remove-Item -LiteralPath $hookTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$statusColor = if ($failed -eq 0) { "Green" } else { "Red" }
Write-Host ">>> Results: $passed Passed, $failed Failed." -ForegroundColor $statusColor

if ($failed -gt 0) {
    exit 1
}

exit 0
