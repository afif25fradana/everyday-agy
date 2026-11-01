<#
.SYNOPSIS
    Pre-execution AST safety validator for shell commands in Antigravity.
.DESCRIPTION
    Inspects command lines using native .NET PowerShell AST parsing without execution.
    Halts on forbidden destructive cmdlets, recursive root deletions, git force pushes, and --no-verify flags.
    Adheres to ADR-0009 & ADR-0011.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [string]$CommandLine
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($CommandLine)) {
    if ($input) {
        $CommandLine = ($input | Out-String)
    }
}
if ([string]::IsNullOrWhiteSpace($CommandLine)) {
    Write-Output $true
    exit 0
}

$parseErrors = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseInput($CommandLine, [ref]$tokens, [ref]$parseErrors)

if ($parseErrors -and $parseErrors.Count -gt 0) {
    Write-Error "Syntax error in command line: $($parseErrors[0].Message)"
    exit 1
}

# 1. Deny forbidden destructive cmdlets and execution wrappers
$forbiddenCommands = @(
    'Format-Volume', 'Format-Disk', 'Clear-Disk', 'Initialize-Disk',
    'Stop-Computer', 'Restart-Computer',
    'Start-Process', 'saps', 'start'
)

# 2. Inspect command elements
$commandElements = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)

foreach ($cmdAst in $commandElements) {
    $rawCmdName = $cmdAst.GetCommandName()

    # Block indirect dynamic expression invocations (e.g. & (Get-Command Remove-Item), & $($cmd), & "...", & @()[0])
    if (-not $rawCmdName) {
        if ($cmdAst.InvocationOperator -in @('Ampersand', 'Dot')) {
            $firstEl = $cmdAst.CommandElements[0]
            if ($firstEl -isnot [System.Management.Automation.Language.ScriptBlockExpressionAst]) {
                Write-Error "Safety Violation: Prohibited dynamic command invocation '$($cmdAst.Extent.Text)' detected."
                exit 1
            }
        }
        continue
    }

    # Normalize module-qualified names (Microsoft.PowerShell.Management\Remove-Item) and .exe suffixes
    $cmdName = (($rawCmdName -split '[\\/]')[-1]) -replace '\.(exe|cmd|bat)$', ''

    # Handle rtk, sudo, and gsudo command unwrapping to subject underlying command to full AST safety inspection
    $targetElements = @($cmdAst.CommandElements)
    if ($cmdName -in @('rtk', 'sudo', 'gsudo')) {
        $idx = 1
        while ($idx -lt $targetElements.Count -and ($targetElements[$idx].Extent.Text -replace '^[''"]|[''"]$', '') -in @('proxy', 'exec')) {
            $idx++
        }
        if ($idx -lt $targetElements.Count) {
            $rawCmdName = $targetElements[$idx].Extent.Text -replace '^[''"]|[''"]$', ''
            $cmdName = (($rawCmdName -split '[\\/]')[-1]) -replace '\.(exe|cmd|bat)$', ''
            $targetElements = @($targetElements[$idx..($targetElements.Count - 1)])
        }
    }

    # Block secondary shell inline command execution while preserving pwsh/powershell -File script runs
    if ($cmdName -in @('cmd', 'wsl', 'bash', 'sh')) {
        Write-Error "Safety Violation: Prohibited secondary shell interpreter '$rawCmdName' detected."
        exit 1
    }
    if ($cmdName -in @('powershell', 'pwsh')) {
        $skipNextArg = $false
        for ($i = 1; $i -lt $targetElements.Count; $i++) {
            $t = $targetElements[$i].Extent.Text -replace '^[''"]|[''"]$', ''
            if ($skipNextArg) {
                $skipNextArg = $false
                continue
            }
            # Legitimate script file execution (-File or -f)
            if ($t -match '^-(f|file)\b') {
                break
            }
            # Explicit inline script / command flags
            if ($t -match '^-(c|co|com|comm|comma|comman|command|e|en|enc|enco|encod|encode|encoded|encodedc|encodedco|encodedcom|encodedcomm|encodedcomma|encodedcomman|encodedcommand)\b') {
                Write-Error "Safety Violation: Prohibited inline subshell evaluation '$($cmdAst.Extent.Text)' detected."
                exit 1
            }
            # Parameters expecting a companion value token
            if ($t -match '^-(executionpolicy|ep|ex|windowstyle|w|configurationname|config|custompipename|outputformat|of|inputformat|if|workingdirectory|wd|settingsfile)\b') {
                if ($t -notmatch '[:=]') {
                    $skipNextArg = $true
                }
                continue
            }
            # Known switch flags
            if ($t -match '^-') {
                continue
            }
            # Positional inline command without -File
            Write-Error "Safety Violation: Prohibited inline subshell evaluation '$($cmdAst.Extent.Text)' detected."
            exit 1
        }
    }

    # Forbidden cmdlets
    if ($forbiddenCommands -contains $cmdName) {
        Write-Error "Safety Violation: Prohibited destructive cmdlet '$cmdName' detected."
        exit 1
    }

    # Remove-Item destructive combinations (including PowerShell parameter prefix abbreviations & colon booleans)
    if ($cmdName -in @('Remove-Item', 'rm', 'del', 'erase', 'rd', 'ri', 'rmdir')) {
        $elements = $targetElements
        $hasRecurse = $false
        $hasForce = $false
        $targetRoot = $false

        foreach ($el in $elements) {
            $text = $el.Extent.Text -replace '^[''"]|[''"]$', ''
            if ($el -is [System.Management.Automation.Language.VariableExpressionAst] -and $el.Splatted) {
                Write-Error "Safety Violation: Prohibited parameter splatting '$text' on '$cmdName'."
                exit 1
            }
            if ($text -match '^-(r|re|rec|recu|recur|recurs|recurse)(:\$?true)?$' -or $text -match '^/s$') { $hasRecurse = $true }
            if ($text -match '^-(f|fo|for|forc|force)(:\$?true)?$' -or $text -match '^/q$') { $hasForce = $true }
            # Check root targets, drive roots, root wildcards, home, and environment path variables (ADR-0011 & ADR-0015)
            if ($text -match '^[/\\]+(\*.*)?$' -or
                $text -match '^[a-zA-Z]:[/\\]*(\*.*)?$' -or
                $text -match '^~[/\\]*(\*.*)?$' -or
                $text -match '^\$(HOME|env:(USERPROFILE|SystemDrive))([/\\]+(\*.*)?)?$' -or
                $text -in @('$env:SystemDrive', '$HOME', '$env:USERPROFILE')) {
                $targetRoot = $true
            }
        }

        # Check if downstream in pipeline where upstream command requested recursion (e.g. gci -r | rm)
        $isPiped = $cmdAst.Parent -is [System.Management.Automation.Language.PipelineAst] -and $cmdAst.Parent.PipelineElements[0] -ne $cmdAst
        if ($isPiped) {
            $parentPipeline = $cmdAst.Parent.Extent.Text
            if ($parentPipeline -match '(?i)(^|\s)-(r|re|rec|recu|recur|recurs|recurse)\b') {
                $hasRecurse = $true
            }
        }

        # Block recursive deletions OR root deletions regardless of -Force (ADR-0011#L29)
        if ($hasRecurse -or $targetRoot) {
            Write-Error "Safety Violation: Prohibited recursive or root deletion '$($cmdAst.Extent.Text)' detected."
            exit 1
        }
    }

    # Git destructive commands & bypass flags (token-aware to avoid false positives inside commit messages)
    if ($cmdName -eq 'git') {
        $argTokens = @()
        $skipNext = $false
        for ($i = 1; $i -lt $targetElements.Count; $i++) {
            if ($targetElements[$i] -is [System.Management.Automation.Language.VariableExpressionAst] -and $targetElements[$i].Splatted) {
                Write-Error "Safety Violation: Prohibited parameter splatting '$($targetElements[$i].Extent.Text)' on git command."
                exit 1
            }
            $t = $targetElements[$i].Extent.Text -replace '^[''"]|[''"]$', ''
            if ($skipNext) {
                $skipNext = $false
                continue
            }
            # Skip commit/tag message payload tokens and global git directory/worktree flags before subcommand
            if ($t -in @('-m', '--message', '--git-dir', '--work-tree', '--namespace') -or $t -ceq '-C') {
                $skipNext = $true
                continue
            }
            # Intercept dangerous git -c configuration overrides (core.hooksPath, core.fsmonitor, alias.*)
            if ($t -ceq '-c') {
                if ($i + 1 -lt $targetElements.Count) {
                    $cfgPayload = $targetElements[$i + 1].Extent.Text -replace '^[''"]|[''"]$', ''
                    if ($cfgPayload -match '(?i)^(core\.(hookspath|fsmonitor|sshcommand|askpass)|alias\.)') {
                        Write-Error "Safety Violation: Prohibited git -c security override '$cfgPayload' detected."
                        exit 1
                    }
                }
                $skipNext = $true
                continue
            }
            if ($t -cmatch '^-c(?<cfg>.+)$') {
                $cfgPayload = ($Matches['cfg'] -replace '^=', '') -replace '^[''"]|[''"]$', ''
                if ($cfgPayload -match '(?i)^(core\.(hookspath|fsmonitor|sshcommand|askpass)|alias\.)') {
                    Write-Error "Safety Violation: Prohibited git -c security override '$cfgPayload' detected."
                    exit 1
                }
                continue
            }
            if ($t -match '^(-m|--message=|--git-dir=|--work-tree=|--namespace=)' -or $t -cmatch '^-C') {
                continue
            }
            $argTokens += $t
        }

        if ($argTokens.Count -gt 0) {
            $subCmd = $argTokens[0]
            $subArgs = ($argTokens -join ' ')

            if ($subCmd -eq 'push') {
                $hasForceFlag = $subArgs -match '(^|\s)(-f\b|--force\b|--force-with-lease\b|--force-if-includes\b)'
                $hasForceRefspec = $subArgs -match '(^|\s)\+[A-Za-z0-9_./-]+'
                $hasRemoteDeletion = $subArgs -match '(^|\s):[A-Za-z0-9_./-]+($|\s)'
                if ($hasForceFlag -or $hasForceRefspec -or $hasRemoteDeletion) {
                    Write-Error "Safety Violation: Prohibited git push force or remote deletion detected."
                    exit 1
                }
            }
            if ($subCmd -eq 'clean' -and $subArgs -match '(^|\s)(-[a-zA-Z]*f|--force\b)') {
                Write-Error "Safety Violation: Prohibited git clean force flag detected."
                exit 1
            }
            if ($subCmd -eq 'commit' -and $subArgs -match '(^|\s)(-n\b|--no-verify\b)') {
                Write-Error "Safety Violation: Prohibited git commit --no-verify bypass flag detected."
                exit 1
            }
            if ($subCmd -eq 'restore') {
                # Permit un-staging index changes (git restore --staged .), block destructive worktree discards
                $hasStagedOnly = ($subArgs -match '(?i)(^|\s)(--staged|-S\b)') -and ($subArgs -notmatch '(?i)(^|\s)(--worktree|-W\b)')
                if (-not $hasStagedOnly) {
                    Write-Error "Safety Violation: Prohibited destructive git 'restore' discard detected. Use Restore-AuditCheckpoint.ps1 instead."
                    exit 1
                }
            }
            if ($subCmd -eq 'checkout') {
                # Permit branch checkouts (git checkout -b <branch> .), block destructive force/discard
                if ($subArgs -match '(^|\s)(-f\b|--force\b)' -or ($subArgs -match '(\s|^)(--\s+)?(\.|\*)(?=\s|$)' -and $subArgs -notmatch '(?i)(^|\s)-b\b')) {
                    Write-Error "Safety Violation: Prohibited destructive git 'checkout' discard detected. Use Restore-AuditCheckpoint.ps1 instead."
                    exit 1
                }
            }
            # Intercept uncheckpointed destructive git resets (allow only exact checkpoint-<task> target ref regardless of flag position)
            if ($subCmd -eq 'reset' -and $subArgs -match '(^|\s)--hard\b') {
                $nonFlagArgs = @()
                if ($argTokens.Count -gt 1) {
                    $nonFlagArgs = @($argTokens[1..($argTokens.Count - 1)] | Where-Object { $_ -notmatch '^-' })
                }
                if ($nonFlagArgs.Count -ne 1) {
                    Write-Error "Safety Violation: Prohibited uncheckpointed 'git reset --hard' detected."
                    exit 1
                }
                $targetRef = ($nonFlagArgs[0] -replace '^[''"]|[''"]$', '')
                if ($targetRef -notmatch '^(refs/heads/)?checkpoint-[A-Za-z0-9_-]+$') {
                    Write-Error "Safety Violation: Prohibited uncheckpointed 'git reset --hard' detected."
                    exit 1
                }
            }
        }
    }

    # Dynamic code execution
    if ($cmdName -in @('Invoke-Expression', 'iex')) {
        Write-Error "Safety Violation: Prohibited dynamic code execution ($cmdName) detected."
        exit 1
    }
}

# 3. Direct .NET destructive method invocations & dynamic reflection execution
$memberExpressions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.InvokeMemberExpressionAst] }, $true)
foreach ($mem in $memberExpressions) {
    $exprText = $mem.Expression.Extent.Text
    $memberVal = $mem.Member.Extent.Text -replace '^[''"]|[''"]$', ''
    if ($memberVal -eq 'Delete' -and ($exprText -match '(?i)(^|\[)(System\.)?IO\.(Directory|File|Path|DirectoryInfo|FileInfo)' -or $exprText -match '(?i)\b(Get-Item|Get-ChildItem|gi|gci|dir|ls|DirectoryInfo|FileInfo)\b')) {
        Write-Error "Safety Violation: Prohibited direct .NET file deletion '$($mem.Extent.Text)' detected."
        exit 1
    }
    if ($memberVal -in @('Invoke', 'InvokeReturnAsIs', 'InvokeScript') -and $exprText -match '(?i)(scriptblock|InvokeCommand|PowerShell)') {
        Write-Error "Safety Violation: Prohibited dynamic script reflection execution '$($mem.Extent.Text)' detected."
        exit 1
    }
}

Write-Output $true
exit 0
