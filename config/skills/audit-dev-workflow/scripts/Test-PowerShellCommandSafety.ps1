<#
.SYNOPSIS
    Pre-execution AST safety validator for shell commands in Antigravity.
.DESCRIPTION
    Inspects command lines using native .NET PowerShell AST parsing without execution.
    Halts on forbidden destructive cmdlets, recursive root deletions, git force pushes, and --no-verify flags.
    Adheres to ADR-0009, ADR-0011, ADR-0015, ADR-0017 & ADR-0022.
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

function Get-NormalizedTokenText {
    param([string]$RawText)
    if ([string]::IsNullOrEmpty($RawText)) { return '' }
    $trimmed = $RawText -replace '^[''"]|[''"]$', ''
    # Strip PowerShell backtick escapes (`f -> f), internal quote obfuscation (--'force' -> --force), and ANSI control characters
    return ((($trimmed -replace '`', '') -replace '[''"]', '') -replace '[\x00-\x1F\x7F]', '')
}

# 1. Deny forbidden destructive cmdlets and execution wrappers
$forbiddenCommands = @(
    'Format-Volume', 'Format-Disk', 'Clear-Disk', 'Initialize-Disk',
    'Stop-Computer', 'Restart-Computer',
    'Start-Process', 'saps', 'start',
    'Invoke-CimMethod', 'icim', 'Invoke-WmiMethod', 'iwmi'
)

# 2. Inspect command elements
$commandElements = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)

foreach ($cmdAst in $commandElements) {
    $rawCmdName = $cmdAst.GetCommandName()
    $firstElem = $cmdAst.CommandElements[0]
    if ($firstElem -is [System.Management.Automation.Language.StringConstantExpressionAst] -and $firstElem.Extent.Text -match '`') {
        $rawCmdName = $firstElem.Extent.Text
    }

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

    # Normalize backtick escapes, module-qualified names (Microsoft.PowerShell.Management\Remove-Item), and .exe suffixes
    $normalizedRawCmd = Get-NormalizedTokenText $rawCmdName
    $cmdName = (($normalizedRawCmd -split '[\\/]')[-1]) -replace '\.(exe|cmd|bat)$', ''

    # Handle rtk, sudo, and gsudo command unwrapping (including wrapper flags like -v, -E, -u <user>)
    $targetElements = @($cmdAst.CommandElements)
    while ($cmdName -in @('rtk', 'sudo', 'gsudo')) {
        $idx = 1
        while ($idx -lt $targetElements.Count) {
            $tok = Get-NormalizedTokenText $targetElements[$idx].Extent.Text
            if ($tok -in @('proxy', 'exec', '--')) {
                $idx++
                continue
            }
            if ($tok -match '^-(u|-user|g|-group|C|D|h|-host|p|-prompt|r|-role|t|-type|T|-command-timeout|i|-integrity)$') {
                $idx += 2
                continue
            }
            if ($tok -match '^-') {
                $idx++
                continue
            }
            break
        }
        if ($idx -lt $targetElements.Count) {
            $rawCmdName = Get-NormalizedTokenText $targetElements[$idx].Extent.Text
            $cmdName = (($rawCmdName -split '[\\/]')[-1]) -replace '\.(exe|cmd|bat)$', ''
            $targetElements = @($targetElements[$idx..($targetElements.Count - 1)])
        } else {
            break
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
            $t = Get-NormalizedTokenText $targetElements[$i].Extent.Text
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

    # Destructive robocopy mirror/purge modes
    if ($cmdName -eq 'robocopy') {
        foreach ($el in $targetElements) {
            $t = Get-NormalizedTokenText $el.Extent.Text
            if ($t -match '(?i)^/(mir|purge|mov|move)$') {
                Write-Error "Safety Violation: Prohibited destructive robocopy flag '$t' detected."
                exit 1
            }
        }
    }

    # Remove-Item destructive combinations (including PowerShell parameter prefix abbreviations & colon booleans)
    if ($cmdName -in @('Remove-Item', 'rm', 'del', 'erase', 'rd', 'ri', 'rmdir')) {
        $elements = $targetElements
        $hasRecurse = $false
        $hasForce = $false
        $targetRoot = $false

        foreach ($el in $elements) {
            $text = Get-NormalizedTokenText $el.Extent.Text
            if ($el -is [System.Management.Automation.Language.VariableExpressionAst] -and $el.Splatted) {
                Write-Error "Safety Violation: Prohibited parameter splatting '$text' on '$cmdName'."
                exit 1
            }
            # Constrain POSIX compound short switch check to 2-4 clustered POSIX single-letter flags (r, f, i, v, d)
            # preventing collision with PowerShell parameter prefix abbreviations (-for, -forc, -ver, -verb, -cred, -str)
            $isPosixCluster = $text -match '^-(?i)[rfivd]{2,4}$'
            if ($text -match '^-(r|re|rec|recu|recur|recurs|recurse)(:\$?true)?$' -or $text -match '^/s$' -or ($isPosixCluster -and $text -match '(?i)r')) { $hasRecurse = $true }
            if ($text -match '^-(f|fo|for|forc|force)(:\$?true)?$' -or $text -match '^/q$' -or ($isPosixCluster -and $text -match '(?i)f')) { $hasForce = $true }
            
            # Check sensitive credential directory deletions (~/.ssh, ~/.aws, ~/.gnupg)
            if ($text -match '(?i)^(~|\$HOME|\$env:USERPROFILE)[/\\]+(\.ssh|\.aws|\.gnupg)($|[/\\])' -or $text -match '(?i)[/\\](\.ssh|\.aws|\.gnupg)($|[/\\])') {
                Write-Error "Safety Violation: Prohibited deletion of credential or sensitive directory '$text' detected."
                exit 1
            }

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
            $t = Get-NormalizedTokenText $targetElements[$i].Extent.Text
            if ($skipNext) {
                $skipNext = $false
                continue
            }
            # Filter Git global boolean flags (do not take arguments) including -P (pager disable)
            $gitGlobalBools = @('--no-pager', '-p', '-P', '--paginate', '--bare', '--no-replace-objects', '--literal-pathspecs')
            if ($t -in $gitGlobalBools) {
                continue
            }
            # Skip commit/tag message payload tokens and global git directory/worktree flags before subcommand
            if ($t -in @('-m', '--message', '--git-dir', '--work-tree', '--namespace') -or $t -ceq '-C') {
                $skipNext = $true
                continue
            }
            # Intercept dangerous git -c configuration overrides (core.hooksPath, core.editor, clean.requireForce, alias.*)
            if ($t -ceq '-c') {
                if ($i + 1 -lt $targetElements.Count) {
                    $cfgPayload = Get-NormalizedTokenText $targetElements[$i + 1].Extent.Text
                    if ($cfgPayload -match '(?i)^(core\.(hookspath|fsmonitor|sshcommand|askpass|editor)|clean\.requireforce|sequence\.editor|safe\.directory|alias\.)') {
                        Write-Error "Safety Violation: Prohibited git -c security override '$cfgPayload' detected."
                        exit 1
                    }
                }
                $skipNext = $true
                continue
            }
            if ($t -cmatch '^-c(?<cfg>.+)$') {
                $cfgPayload = Get-NormalizedTokenText ($Matches['cfg'] -replace '^=', '')
                if ($cfgPayload -match '(?i)^(core\.(hookspath|fsmonitor|sshcommand|askpass|editor)|clean\.requireforce|sequence\.editor|safe\.directory|alias\.)') {
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
            # Robust subcommand resolution: locate the first non-flag argument token as $subCmd
            $subCmd = $null
            for ($j = 0; $j -lt $argTokens.Count; $j++) {
                if ($argTokens[$j] -notmatch '^-') {
                    $subCmd = $argTokens[$j]
                    break
                }
            }
            $subArgs = ($argTokens -join ' ')

            if ($subCmd -eq 'push') {
                $hasForceFlag = $subArgs -match '(^|\s)(-f\b|--force\b|--force-with-lease\b|--force-if-includes\b)'
                $hasForceRefspec = $subArgs -match '(^|\s)\+[A-Za-z0-9_./-]+'
                $hasRemoteDeletion = $subArgs -match '(^|\s)(:[A-Za-z0-9_./-]+|--delete\b|-d\b)($|\s)'
                if ($hasForceFlag -or $hasForceRefspec -or $hasRemoteDeletion) {
                    Write-Error "Safety Violation: Prohibited git push force or remote deletion detected."
                    exit 1
                }
            }
            if ($subCmd -eq 'branch' -and $subArgs -match '(^|\s)(-D\b|--delete\s+-f\b|--delete\s+--force\b)') {
                Write-Error "Safety Violation: Prohibited destructive git branch force deletion detected."
                exit 1
            }
            if ($subCmd -eq 'clean' -and $subArgs -match '(^|\s)(-[a-zA-Z]*f|--force\b)') {
                Write-Error "Safety Violation: Prohibited git clean force flag detected."
                exit 1
            }
            if ($subCmd -eq 'commit' -and $subArgs -match '(^|\s)(-n\b|--no-veri(f|fy)?\b)') {
                Write-Error "Safety Violation: Prohibited git commit --no-verify bypass flag detected."
                exit 1
            }
            if ($subCmd -eq 'restore') {
                # Permit un-staging index changes (git restore --staged .), block destructive worktree discards
                # Must be strictly case-sensitive (-S vs -s) and reject -s/--source
                $hasStagedOnly = ($subArgs -cmatch '(^|\s)(--staged|-S\b)') -and ($subArgs -notmatch '(?i)(^|\s)(--worktree|-W\b)') -and ($subArgs -cnotmatch '(^|\s)(-s\b|--source\b)')
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
            if ($subCmd -eq 'switch') {
                # Block destructive worktree discard or force branch overwrite on git switch
                if ($subArgs -match '(^|\s)(-f\b|--force\b|--discard-changes\b)' -or $subArgs -cmatch '(^|\s)(-C\b|--force-create\b)') {
                    Write-Error "Safety Violation: Prohibited destructive git 'switch' discard/force detected. Use Restore-AuditCheckpoint.ps1 instead."
                    exit 1
                }
            }
            if ($subCmd -eq 'stash' -and $subArgs -match '(^|\s)(drop|clear)\b') {
                Write-Error "Safety Violation: Prohibited destructive git 'stash' drop/clear detected."
                exit 1
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
                $targetRef = Get-NormalizedTokenText $nonFlagArgs[0]
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

# 3. Direct .NET destructive method invocations, process execution & dynamic reflection execution
$memberExpressions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.InvokeMemberExpressionAst] }, $true)
foreach ($mem in $memberExpressions) {
    $exprText = $mem.Expression.Extent.Text
    $memberVal = Get-NormalizedTokenText $mem.Member.Extent.Text

    # Intercept direct process execution via .NET Process::Start (GAP-CRIT-04)
    if ($memberVal -eq 'Start' -and $exprText -match '(?i)(^|\[\s*)(System\.)?Diagnostics\.Process(\s*\]|:|$)') {
        Write-Error "Safety Violation: Prohibited direct .NET process execution '$($mem.Extent.Text)' detected."
        exit 1
    }

    # Intercept destructive .NET deletions on files, directories, and IO object variables
    if ($memberVal -eq 'Delete' -and (
        $exprText -match '(?i)(^|\[\s*)(System\.)?IO\.(Directory|File|Path|DirectoryInfo|FileInfo)' -or
        $exprText -match '(?i)\b(Get-Item|Get-ChildItem|gi|gci|dir|ls|DirectoryInfo|FileInfo)\b' -or
        $mem.Expression -is [System.Management.Automation.Language.VariableExpressionAst])) {
        Write-Error "Safety Violation: Prohibited direct .NET file/directory deletion '$($mem.Extent.Text)' detected."
        exit 1
    }
    if (($memberVal -eq 'Create' -and $exprText -match '(?i)(^|\[\s*)(System\.Management\.Automation\.)?ScriptBlock(\s*\]|:|$)') -or
        ($memberVal -in @('Invoke', 'InvokeReturnAsIs', 'InvokeScript') -and (
            $exprText -match '(?i)(scriptblock|InvokeCommand|PowerShell)' -or
            $mem.Expression -is [System.Management.Automation.Language.VariableExpressionAst]))) {
        Write-Error "Safety Violation: Prohibited dynamic script reflection execution '$($mem.Extent.Text)' detected."
        exit 1
    }
}

Write-Output $true
exit 0
