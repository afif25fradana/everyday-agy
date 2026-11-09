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

    # Blocked: Wrapper flags, backtick escapes, two-statement scriptblock variables, git switch/stash, robocopy /MIR (ADR-0022)
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
    @{ Expected = "ALLOW"; Cmd = 'git checkout -B feat/branch'; Reason = "git checkout -B branch creation" },
    @{ Expected = "ALLOW"; Cmd = 'git checkout --detach HEAD'; Reason = "git checkout --detach" },
    @{ Expected = "ALLOW"; Cmd = 'git checkout --orphan new-branch'; Reason = "git checkout --orphan branch" },

    # Allowed: Filtered wildcard cleanup (SEC-03)
    @{ Expected = "ALLOW"; Cmd = 'Remove-Item *.log'; Reason = "Remove-Item filtered wildcard cleanup" }
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
        if ($wasBlocked -and ($errMsg -match 'Safety Violation:')) {
            Write-Host "  [PASS] Blocked: $($tc.Reason)" -ForegroundColor Green
            $passed++
        } else {
            Write-Host "  [FAIL] Expected BLOCK with 'Safety Violation:', but got wasBlocked=$wasBlocked, errMsg=$errMsg ($($tc.Cmd))" -ForegroundColor Red
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
