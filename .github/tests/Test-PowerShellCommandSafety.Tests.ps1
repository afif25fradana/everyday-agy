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
$orchestratorScriptsDir = Join-Path (Join-Path (Join-Path (Join-Path $repoRoot "config") "skills") "orchestrator") "scripts"
$safetyValidator = Join-Path $orchestratorScriptsDir "Test-PowerShellCommandSafety.ps1"

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

Write-Host "`n>>> Running Invoke-AntigravityHook Router & Guard Test Suite..." -ForegroundColor Cyan

$hookScript = Join-Path (Join-Path (Join-Path $repoRoot "config") "scripts") "Invoke-AntigravityHook.ps1"

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

function Invoke-HookCli {
    param(
        [string]$EventName,
        [string]$JsonInput = "",
        [byte[]]$RawBytes = $null,
        [string]$WorkDir = "",
        [string]$HomeOverride = ""
    )
    if (-not (Test-Path -LiteralPath $hookScript)) {
        return [PSCustomObject]@{
            MissingScript = $true
            ExitCode      = -1
            StdOut        = ""
            StdErr        = "Missing script: $hookScript"
            Parsed        = $null
        }
    }
    $psExe = if ($PSVersionTable.PSEdition -eq "Core") {
        (Get-Process -Id $PID).Path
    } else {
        Join-Path $PSHOME "powershell.exe"
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$hookScript`" -Event $EventName"
    $psi.WorkingDirectory = if ($WorkDir) { $WorkDir } else { Split-Path -Parent (Split-Path -Parent $hookScript) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    if ($HomeOverride) {
        $psi.EnvironmentVariables["USERPROFILE"] = $HomeOverride
        $psi.EnvironmentVariables["HOME"] = $HomeOverride
    }

    $proc = [System.Diagnostics.Process]::Start($psi)
    $bytesToWrite = if ($null -ne $RawBytes) {
        $RawBytes
    } elseif (-not [string]::IsNullOrEmpty($JsonInput)) {
        [System.Text.UTF8Encoding]::new($false).GetBytes($JsonInput)
    } else {
        $null
    }
    if ($null -ne $bytesToWrite -and $bytesToWrite.Length -gt 0) {
        $proc.StandardInput.BaseStream.Write($bytesToWrite, 0, $bytesToWrite.Length)
    }
    $proc.StandardInput.Close()
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit()

    $stdoutStr = $outTask.Result
    $parsedObj = $null
    $trimmedOut = $stdoutStr.Trim()
    $lines = @($trimmedOut -split "`r?`n" | Where-Object { $_ -ne "" })
    if ($lines.Count -eq 1) {
        try { $parsedObj = $trimmedOut | ConvertFrom-Json } catch { $parsedObj = $null }
    }

    return [PSCustomObject]@{
        MissingScript = $false
        ExitCode      = $proc.ExitCode
        StdOut        = $stdoutStr
        StdErr        = $errTask.Result
        SingleJson    = ($lines.Count -eq 1 -and $null -ne $parsedObj)
        Parsed        = $parsedObj
    }
}

$hookTestId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
$hookTempDir = Join-Path ([System.IO.Path]::GetTempPath()) "agy_hook_test_$hookTestId"
$isolatedHome = Join-Path $hookTempDir "home"
New-Item -ItemType Directory -Path $isolatedHome -Force | Out-Null

try {
    # Guard 1: run_command
    $g1Allow = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput '{"toolCall":{"name":"run_command","args":{"CommandLine":"git status"}}}'
    Assert-HookCondition -Name "Guard 1 allows safe run_command (git status)" -Condition ($g1Allow.ExitCode -eq 0 -and $g1Allow.SingleJson -and $g1Allow.Parsed.decision -eq "allow") -Details "out=$($g1Allow.StdOut) err=$($g1Allow.StdErr)"

    $g1DenyForce = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput '{"toolCall":{"name":"run_command","args":{"CommandLine":"git push origin main --force"}}}'
    Assert-HookCondition -Name "Guard 1 denies git push --force" -Condition ($g1DenyForce.ExitCode -eq 0 -and $g1DenyForce.SingleJson -and $g1DenyForce.Parsed.decision -eq "deny" -and $g1DenyForce.Parsed.reason -match 'Safety Violation') -Details "out=$($g1DenyForce.StdOut)"

    $g1DenyRm = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput '{"toolCall":{"name":"run_command","args":{"CommandLine":"Remove-Item -Recurse C:\\temp\\foo"}}}'
    Assert-HookCondition -Name "Guard 1 denies recursive Remove-Item" -Condition ($g1DenyRm.ExitCode -eq 0 -and $g1DenyRm.SingleJson -and $g1DenyRm.Parsed.decision -eq "deny") -Details "out=$($g1DenyRm.StdOut)"

    $g1EmptyCmd = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput '{"toolCall":{"name":"run_command","args":{"CommandLine":""}}}'
    Assert-HookCondition -Name "Guard 1 degrades empty CommandLine to ask" -Condition ($g1EmptyCmd.ExitCode -eq 0 -and $g1EmptyCmd.SingleJson -and $g1EmptyCmd.Parsed.decision -eq "ask") -Details "out=$($g1EmptyCmd.StdOut)"

    $g1SpaceCmd = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput '{"toolCall":{"name":"run_command","args":{"CommandLine":"   "}}}'
    Assert-HookCondition -Name "Guard 1 degrades whitespace CommandLine to ask" -Condition ($g1SpaceCmd.ExitCode -eq 0 -and $g1SpaceCmd.SingleJson -and $g1SpaceCmd.Parsed.decision -eq "ask") -Details "out=$($g1SpaceCmd.StdOut)"

    $g1MultilinePayload = @{
        toolCall = @{
            name = "run_command"
            args = @{
                CommandLine = "pwsh -Command `"Write-Host 1`nWrite-Host 2`""
            }
        }
    } | ConvertTo-Json -Depth 5 -Compress
    $g1Multiline = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput $g1MultilinePayload
    Assert-HookCondition -Name "Guard 1 preserves wrapped multiline AST safety output" -Condition ($g1Multiline.ExitCode -eq 0 -and $g1Multiline.SingleJson -and $g1Multiline.Parsed.decision -eq "deny" -and $g1Multiline.Parsed.reason -match 'Safety Violation:' -and $g1Multiline.Parsed.reason -match 'Write-Host 2' -and $g1Multiline.Parsed.reason -match 'detected\.') -Details "out=$($g1Multiline.StdOut)"

    # Guard 2: Security Deny-Path Gate
    $guard2Cases = @(
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "C:\\repo\\.env"; Expected = "deny"; Label = ".env via AbsolutePath" },
        @{ Tool = "write_to_file"; Key = "TargetFile"; Path = "/app/api/.env.local"; Expected = "deny"; Label = ".env.local via TargetFile" },
        @{ Tool = "replace_file_content"; Key = "TargetFile"; Path = "C:\\repo\\sub\\..\\.env.production"; Expected = "deny"; Label = "Normalized path traversal to .env.production" },
        @{ Tool = "multi_replace_file_content"; Key = "Path"; Path = "C:\\repo\\.env.dev"; Expected = "deny"; Label = ".env.dev via Path" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "C:\\repo\\.env.example"; Expected = "allow"; Label = ".env.example exception" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "C:\\repo\\.env.sample"; Expected = "allow"; Label = ".env.sample exception" },
        @{ Tool = "write_to_file"; Key = "TargetFile"; Path = "/app/.env.template"; Expected = "allow"; Label = ".env.template exception" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "~/.ssh/id_rsa"; Expected = "deny"; Label = "~/.ssh/id_rsa" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "C:\\Users\\Test\\.aws\\credentials"; Expected = "deny"; Label = "~/.aws/credentials" },
        @{ Tool = "write_to_file"; Key = "TargetFile"; Path = "/home/user/.gnupg/secring.gpg"; Expected = "deny"; Label = "~/.gnupg secret" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "C:\\certs\\private.key"; Expected = "deny"; Label = "*.key file" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "certs/server.pem"; Expected = "deny"; Label = "*.pem file" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "C:\\Users\\Alice\\.gemini\\antigravity\\mcp\\context7\\token.json"; Expected = "deny"; Label = "Antigravity mcp/** token config" },
        @{ Tool = "write_to_file"; Key = "TargetFile"; Path = "~/.gemini/antigravity/mcp/oauth.json"; Expected = "deny"; Label = "~/antigravity/mcp/** token config" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "D:\\repo\\src\\mcp\\server.ts"; Expected = "allow"; Label = "Normal repo src/mcp/ file allowed" },
        @{ Tool = "write_to_file"; Key = "TargetFile"; Path = "D:\\repo\\src\\index.ts"; Expected = "allow"; Label = "Normal source write allowed regardless of role" }
    )

    foreach ($g2 in $guard2Cases) {
        $payloadObj = @{
            toolCall = @{
                name = $g2.Tool
                args = @{
                    $g2.Key = $g2.Path
                }
            }
        }
        $jsonPayload = $payloadObj | ConvertTo-Json -Depth 5 -Compress
        $res = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput $jsonPayload
        Assert-HookCondition -Name "Guard 2 ($($g2.Tool)): $($g2.Label) -> $($g2.Expected)" -Condition ($res.ExitCode -eq 0 -and $res.SingleJson -and $res.Parsed.decision -eq $g2.Expected) -Details "out=$($res.StdOut)"
    }

    # Guard 3 removed: invoke_subagent passes through without 4-slot tag or model blocking
    $threeSlotPrompt = "<OBJECTIVE>Inspect parser edge cases</OBJECTIVE>`n<SCOPE>config/scripts/** (read-only)</SCOPE>`n<DELIVERABLE>Compact receipt</DELIVERABLE>"

    $subagentTeamwork = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput (@{
        toolCall = @{
            name = "invoke_subagent"
            args = @{
                Subagents = @{
                    TypeName = "teamwork"
                    Model    = "inherit"
                    Prompt   = "Requested team: council`nEvaluate auth boundaries."
                }
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    Assert-HookCondition -Name "invoke_subagent pass-through allows TypeName=teamwork with Requested team prompt" -Condition ($subagentTeamwork.ExitCode -eq 0 -and $subagentTeamwork.SingleJson -and $subagentTeamwork.Parsed.decision -eq "allow" -and $subagentTeamwork.StdOut.Trim() -eq '{"decision":"allow"}') -Details "out=$($subagentTeamwork.StdOut)"

    $subagentThreeSlot = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput (@{
        toolCall = @{
            name = "invoke_subagent"
            args = @{
                Subagents = @{
                    TypeName = "code-auditor"
                    Model    = "inherit"
                    Prompt   = $threeSlotPrompt
                }
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    Assert-HookCondition -Name "invoke_subagent pass-through allows 3-slot XML prompt (<OBJECTIVE>/<SCOPE>/<DELIVERABLE>)" -Condition ($subagentThreeSlot.ExitCode -eq 0 -and $subagentThreeSlot.SingleJson -and $subagentThreeSlot.Parsed.decision -eq "allow" -and $subagentThreeSlot.StdOut.Trim() -eq '{"decision":"allow"}') -Details "out=$($subagentThreeSlot.StdOut)"

    $subagentResearch = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput (@{
        toolCall = @{
            name = "invoke_subagent"
            args = @{
                TypeName = "research"
                Prompt   = "Search repo for hook matcher usages and return file paths."
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    Assert-HookCondition -Name "invoke_subagent pass-through allows untagged built-in research prompt" -Condition ($subagentResearch.ExitCode -eq 0 -and $subagentResearch.SingleJson -and $subagentResearch.Parsed.decision -eq "allow" -and $subagentResearch.StdOut.Trim() -eq '{"decision":"allow"}') -Details "out=$($subagentResearch.StdOut)"

    $subagentSelf = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput (@{
        toolCall = @{
            name = "invoke_subagent"
            args = @{
                TypeName = "self"
                prompt   = "Summarize test suite results without delegation tags."
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    Assert-HookCondition -Name "invoke_subagent pass-through allows untagged built-in self prompt" -Condition ($subagentSelf.ExitCode -eq 0 -and $subagentSelf.SingleJson -and $subagentSelf.Parsed.decision -eq "allow" -and $subagentSelf.StdOut.Trim() -eq '{"decision":"allow"}') -Details "out=$($subagentSelf.StdOut)"

    $subagentArray = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput (@{
        toolCall = @{
            name = "invoke_subagent"
            args = @{
                Subagents = @(
                    @{ TypeName = "teamwork"; Model = "inherit"; Prompt = "Requested team: quick-review`nCheck diff." },
                    @{ TypeName = "tdd-guide"; Model = "flash"; Prompt = $threeSlotPrompt },
                    @{ TypeName = "research"; Prompt = "Locate all callers of Test-DenyPath." },
                    @{ TypeName = "tdd-guide"; Model = "sonnet"; Prompt = "Plain prompt without model restriction." }
                )
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    Assert-HookCondition -Name "invoke_subagent pass-through allows Subagents array payloads" -Condition ($subagentArray.ExitCode -eq 0 -and $subagentArray.SingleJson -and $subagentArray.Parsed.decision -eq "allow" -and $subagentArray.StdOut.Trim() -eq '{"decision":"allow"}') -Details "out=$($subagentArray.StdOut)"

    # Guard 4: PostToolUse gate2_handoff.md diff injection & stdout isolation
    $postRepo = Join-Path $hookTempDir "post_repo"
    $postArtifactDir = Join-Path $hookTempDir "brain"
    New-Item -ItemType Directory -Path $postRepo, $postArtifactDir -Force | Out-Null
    $origLoc = Get-Location
    try {
        Set-Location -LiteralPath $postRepo
        git init --quiet
        git config user.name "HookTester"
        git config user.email "hooktester@example.com"
        $tracked = Join-Path $postRepo "sample.txt"
        [System.IO.File]::WriteAllText($tracked, "line1`n", [System.Text.UTF8Encoding]::new($false))
        git add sample.txt
        git commit -m "init" --quiet
        [System.IO.File]::WriteAllText($tracked, "line1`nline2_hook_test`n", [System.Text.UTF8Encoding]::new($false))
    } finally {
        Set-Location -LiteralPath $origLoc
    }

    $gate2File = Join-Path $postArtifactDir "gate2_handoff.md"
    $gate2Template = @('# Gate 2', '{{VERBATIM_GIT_DIFFSTAT}}', '```diff', '{{VERBATIM_GIT_DIFF}}', '```') -join "`n"
    [System.IO.File]::WriteAllText($gate2File, $gate2Template, [System.Text.UTF8Encoding]::new($false))
    $g4Res = Invoke-HookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -WorkDir $postRepo -JsonInput (@{
        workspacePaths = @($postRepo)
        toolCall = @{
            name = "write_to_file"
            args = @{
                TargetFile = $gate2File
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    $g4Text = [System.IO.File]::ReadAllText($gate2File, [System.Text.Encoding]::UTF8)
    Assert-HookCondition -Name "Guard 4 injects git diff into gate2_handoff.md and emits strictly {}" -Condition ($g4Res.ExitCode -eq 0 -and $g4Res.StdOut.Trim() -eq "{}" -and $g4Text.Contains("line2_hook_test") -and (-not $g4Text.Contains("{{VERBATIM_GIT_DIFF}}"))) -Details "out=$($g4Res.StdOut)"

    $gate2ErrFile = Join-Path $postArtifactDir "err_dir/gate2_handoff.md"
    New-Item -ItemType Directory -Path (Split-Path -Parent $gate2ErrFile) -Force | Out-Null
    [System.IO.File]::WriteAllText($gate2ErrFile, "{{VERBATIM_GIT_DIFF}}", [System.Text.UTF8Encoding]::new($false))
    $g4ErrRes = Invoke-HookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -WorkDir $postRepo -JsonInput (@{
        workspacePaths = @($postRepo)
        error = "write failed"
        toolCall = @{
            name = "replace_file_content"
            args = @{
                TargetFile = $gate2ErrFile
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    $g4ErrText = [System.IO.File]::ReadAllText($gate2ErrFile, [System.Text.Encoding]::UTF8)
    Assert-HookCondition -Name "Guard 4 skips diff injection when PostToolUse error is non-empty" -Condition ($g4ErrRes.ExitCode -eq 0 -and $g4ErrRes.StdOut.Trim() -eq "{}" -and $g4ErrText.Contains("{{VERBATIM_GIT_DIFF}}")) -Details "out=$($g4ErrRes.StdOut)"

    $nonGate2File = Join-Path $postArtifactDir "foo_gate2_handoff.md"
    [System.IO.File]::WriteAllText($nonGate2File, "{{VERBATIM_GIT_DIFF}}", [System.Text.UTF8Encoding]::new($false))
    $g4SuffixRes = Invoke-HookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -WorkDir $postRepo -JsonInput (@{
        workspacePaths = @($postRepo)
        toolCall = @{
            name = "write_to_file"
            args = @{
                TargetFile = $nonGate2File
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    $g4SuffixText = [System.IO.File]::ReadAllText($nonGate2File, [System.Text.Encoding]::UTF8)
    Assert-HookCondition -Name "Guard 4 does not inject diff into foo_gate2_handoff.md" -Condition ($g4SuffixRes.ExitCode -eq 0 -and $g4SuffixRes.StdOut.Trim() -eq "{}" -and $g4SuffixText.Contains("{{VERBATIM_GIT_DIFF}}") -and (-not $g4SuffixText.Contains("line2_hook_test"))) -Details "out=$($g4SuffixRes.StdOut) text=$g4SuffixText"

    # UTF-8 BOM stripping & malformed JSON fallback & 5MB log cap
    $bomPayload = '{"toolCall":{"name":"run_command","args":{"CommandLine":"git status"}}}'
    $bomBytes = [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.UTF8Encoding]::new($false).GetBytes($bomPayload)
    $bomRes = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -RawBytes $bomBytes
    Assert-HookCondition -Name "Hook strips UTF-8 BOM from stdin JSON" -Condition ($bomRes.ExitCode -eq 0 -and $bomRes.SingleJson -and $bomRes.Parsed.decision -eq "allow") -Details "out=$($bomRes.StdOut)"

    $badJsonRes = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput "{malformed json"
    $logFile = Join-Path $isolatedHome ".gemini/antigravity/scratch/hooks.log"
    Assert-HookCondition -Name "Malformed JSON degrades gracefully to decision=ask and logs error" -Condition ($badJsonRes.ExitCode -eq 0 -and $badJsonRes.SingleJson -and $badJsonRes.Parsed.decision -eq "ask" -and -not [string]::IsNullOrWhiteSpace($badJsonRes.Parsed.reason) -and (Test-Path -LiteralPath $logFile)) -Details "out=$($badJsonRes.StdOut) logExists=$(Test-Path -LiteralPath $logFile)"

    $badPostRes = Invoke-HookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -JsonInput "{malformed json"
    Assert-HookCondition -Name "Malformed JSON in PostToolUse emits strictly {}" -Condition ($badPostRes.ExitCode -eq 0 -and $badPostRes.StdOut.Trim() -eq "{}") -Details "out=$($badPostRes.StdOut)"

    # 5 MB bounded log check
    if (Test-Path -LiteralPath (Split-Path -Parent $logFile)) {
        $oversizeChunk = ("x" * 1023) + "`n"
        $sw = [System.IO.StreamWriter]::new($logFile, $false, [System.Text.UTF8Encoding]::new($false))
        try {
            for ($k = 0; $k -lt 5300; $k++) { $sw.Write($oversizeChunk) }
        } finally {
            $sw.Dispose()
        }
        $null = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput "{still malformed"
        $finalLogLen = (Get-Item -LiteralPath $logFile).Length
        Assert-HookCondition -Name "hooks.log stays bounded <= 5 MB after rotation/truncation" -Condition ($finalLogLen -le (5 * 1024 * 1024) -and $finalLogLen -gt 0) -Details "len=$finalLogLen"
    } else {
        Assert-HookCondition -Name "hooks.log stays bounded <= 5 MB after rotation/truncation" -Condition $false -Details "Scratch log dir missing"
    }

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
        (Join-Path $syncHome ".gemini/config/skills/custom-external-skill"),
        (Join-Path $syncHome ".gemini/config/skills/audit-dev-workflow"),
        (Join-Path $syncHome ".gemini/config/skills/orchestrator"),
        (Join-Path $syncHome ".gemini/config/agents/database-reviewer"),
        (Join-Path $syncHome ".gemini/config/plugins/my-marketplace-plugin") -Force | Out-Null

    $rootSync = Join-Path $repoRoot "sync.ps1"
    $rootRestore = Join-Path $repoRoot "restore.ps1"
    Copy-Item -LiteralPath $rootSync -Destination (Join-Path $syncRepo "sync.ps1") -Force
    Copy-Item -LiteralPath $rootRestore -Destination (Join-Path $syncRepo "restore.ps1") -Force
    Set-Content -LiteralPath (Join-Path $syncRepo "config/GEMINI.md") -Value "# Repo GEMINI" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/hooks.json") -Value "{}" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/scripts/Invoke-AntigravityHook.ps1") -Value "# Hook script" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/agents/tdd-guide/agent.md") -Value "name: tdd-guide" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "config/skills/orchestrator/SKILL.md") -Value "name: orchestrator" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncRepo "docs/adr/README.md") -Value "# ADR" -Encoding utf8

    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/docs/adr/0001-old.md") -Value "# Old ADR" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/docs/adr/0001-old.md") -Value "# Legacy Old ADR" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/hooks.json") -Value '{"old":true}' -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/skills/custom-external-skill/SKILL.md") -Value "external" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/skills/audit-dev-workflow/SKILL.md") -Value "retired" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/skills/orchestrator/orphan.txt") -Value "stale" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/agents/database-reviewer/agent.md") -Value "retired" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/plugins/my-marketplace-plugin/plugin.json") -Value "{}" -Encoding utf8

    $psExe = if ($PSVersionTable.PSEdition -eq "Core") { (Get-Process -Id $PID).Path } else { Join-Path $PSHOME "powershell.exe" }
    function Invoke-SandboxScript {
        param([string]$ScriptPath)
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
        $null = $outTask.Result
        $null = $errTask.Result
        return $proc.ExitCode
    }

    $restoreExit = Invoke-SandboxScript -ScriptPath (Join-Path $syncRepo "restore.ps1")

    $externalPreserved = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/skills/custom-external-skill/SKILL.md")
    $pluginPreserved = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/plugins/my-marketplace-plugin/plugin.json")
    $retiredAgentGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/agents/database-reviewer"))
    $retiredSkillGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/skills/audit-dev-workflow"))
    $orphanFileGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/skills/orchestrator/orphan.txt"))
    $hooksDeployed = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/hooks.json")
    $scriptDeployed = Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/scripts/Invoke-AntigravityHook.ps1")
    $hooksBackedUp = @(Get-ChildItem -Path (Join-Path $syncHome ".gemini") -Filter "backup_*" -Directory | ForEach-Object { Join-Path $_.FullName "hooks.json" } | Where-Object { Test-Path $_ }).Count -gt 0
    $docsAdrGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/docs/adr"))
    $docsParentGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/docs"))
    $legacyDocsAdrGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/docs/adr"))
    $legacyDocsParentGone = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/config/docs"))

    Assert-HookCondition -Name "restore.ps1 preserves unrecognized skills & plugins while pruning only retired repo names and skill orphans" -Condition ($restoreExit -eq 0 -and $externalPreserved -and $pluginPreserved -and $retiredAgentGone -and $retiredSkillGone -and $orphanFileGone) -Details "ext=$externalPreserved plug=$pluginPreserved retA=$retiredAgentGone retS=$retiredSkillGone orph=$orphanFileGone"
    Assert-HookCondition -Name "restore.ps1 backs up and deploys hooks.json and scripts/" -Condition ($hooksDeployed -and $scriptDeployed -and $hooksBackedUp)
    Assert-HookCondition -Name "restore.ps1 prunes ~/.gemini/docs/adr, ~/.gemini/config/docs/adr, and empty parent docs/ directories" -Condition ($restoreExit -eq 0 -and $docsAdrGone -and $docsParentGone -and $legacyDocsAdrGone -and $legacyDocsParentGone) -Details "docsAdrGone=$docsAdrGone docsParentGone=$docsParentGone legacyAdrGone=$legacyDocsAdrGone legacyParentGone=$legacyDocsParentGone"

    # Verify sync.ps1 pulls back only tracked items and guards against empty source deletion
    New-Item -ItemType Directory -Path (Join-Path $syncHome ".gemini/config/agents/untracked-user-agent") -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/agents/untracked-user-agent/agent.md") -Value "user-owned" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $syncHome ".gemini/config/hooks.json") -Value '{"updatedByUser":true}' -Encoding utf8
    Remove-Item -LiteralPath (Join-Path $syncHome ".gemini/config/skills/orchestrator/SKILL.md") -Force

    $repoAdrReadme = Join-Path $syncRepo "docs/adr/README.md"
    $adrSentinelUtc = [datetime]::SpecifyKind([datetime]"2020-01-01T00:00:00", [System.DateTimeKind]::Utc)
    [System.IO.File]::SetLastWriteTimeUtc($repoAdrReadme, $adrSentinelUtc)
    $adrAbsentBeforeSync = -not (Test-Path -LiteralPath (Join-Path $syncHome ".gemini/docs/adr"))

    $syncExit = Invoke-SandboxScript -ScriptPath (Join-Path $syncRepo "sync.ps1")

    $syncedHooks = (Get-Content -LiteralPath (Join-Path $syncRepo "config/hooks.json") -Raw).Trim() -eq '{"updatedByUser":true}'
    $ignoredUntrackedAgent = -not (Test-Path -LiteralPath (Join-Path $syncRepo "config/agents/untracked-user-agent"))
    $ignoredExternalSkill = -not (Test-Path -LiteralPath (Join-Path $syncRepo "config/skills/custom-external-skill"))
    $emptySourcePreserved = Test-Path -LiteralPath (Join-Path $syncRepo "config/skills/orchestrator/SKILL.md")
    $adrReadmeUntouched = (Test-Path -LiteralPath $repoAdrReadme) -and ([System.IO.File]::GetLastWriteTimeUtc($repoAdrReadme) -eq $adrSentinelUtc) -and ((Get-Content -LiteralPath $repoAdrReadme -Raw).Trim() -eq "# ADR")

    Assert-HookCondition -Name "sync.ps1 pulls back tracked hooks.json, ignores unrecognized agents/skills, and guards against empty source deletion" -Condition ($syncExit -eq 0 -and $syncedHooks -and $ignoredUntrackedAgent -and $ignoredExternalSkill -and $emptySourcePreserved) -Details "hooks=$syncedHooks ignA=$ignoredUntrackedAgent ignS=$ignoredExternalSkill emptyGuard=$emptySourcePreserved"
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
