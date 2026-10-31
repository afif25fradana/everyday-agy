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
    'Start-Process', 'saps'
)

# 2. Inspect command elements
$commandElements = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)

foreach ($cmdAst in $commandElements) {
    $rawCmdName = $cmdAst.GetCommandName()

    # Block indirect dynamic expression invocations (e.g. & (Get-Command Remove-Item))
    if (-not $rawCmdName) {
        if ($cmdAst.InvocationOperator -eq 'Ampersand') {
            $firstEl = $cmdAst.CommandElements[0]
            if ($firstEl -is [System.Management.Automation.Language.ParenExpressionAst] -or
                $firstEl -is [System.Management.Automation.Language.VariableExpressionAst]) {
                Write-Error "Safety Violation: Prohibited dynamic command invocation '$($cmdAst.Extent.Text)' detected."
                exit 1
            }
        }
        continue
    }

    # Normalize module-qualified names (Microsoft.PowerShell.Management\Remove-Item) and .exe suffixes
    $cmdName = (($rawCmdName -split '[\\/]')[-1]) -replace '\.(exe|cmd|bat)$', ''

    # Block secondary shell inline command execution while preserving pwsh/powershell -File script runs
    if ($cmdName -in @('cmd', 'wsl', 'bash', 'sh')) {
        Write-Error "Safety Violation: Prohibited secondary shell interpreter '$rawCmdName' detected."
        exit 1
    }
    if ($cmdName -in @('powershell', 'pwsh')) {
        foreach ($el in $cmdAst.CommandElements[1..($cmdAst.CommandElements.Count - 1)]) {
            if ($el.Extent.Text -match '^-(c|co|com|comm|comma|comman|command|e|en|enc|enco|encod|encode|encoded|encodedc|encodedco|encodedcom|encodedcomm|encodedcomma|encodedcomman|encodedcommand)\b') {
                Write-Error "Safety Violation: Prohibited inline subshell evaluation '$($cmdAst.Extent.Text)' detected."
                exit 1
            }
        }
    }

    # Forbidden cmdlets
    if ($forbiddenCommands -contains $cmdName) {
        Write-Error "Safety Violation: Prohibited destructive cmdlet '$cmdName' detected."
        exit 1
    }

    # Remove-Item destructive combinations (including PowerShell parameter prefix abbreviations & colon booleans)
    if ($cmdName -in @('Remove-Item', 'rm', 'del', 'erase', 'rd', 'ri', 'rmdir')) {
        $elements = $cmdAst.CommandElements
        $hasRecurse = $false
        $hasForce = $false
        $targetRoot = $false

        foreach ($el in $elements) {
            $text = $el.Extent.Text
            if ($el -is [System.Management.Automation.Language.VariableExpressionAst] -and $el.Splatted) {
                Write-Error "Safety Violation: Prohibited parameter splatting '$text' on '$cmdName'."
                exit 1
            }
            if ($text -match '^-(r|re|rec|recu|recur|recurs|recurse)(:\$?true)?$' -or $text -match '^/s$') { $hasRecurse = $true }
            if ($text -match '^-(f|fo|for|forc|force)(:\$?true)?$' -or $text -match '^/q$') { $hasForce = $true }
            if ($text -match '^[/\\]+$|^[a-zA-Z]:[/\\]*$|^~[/\\]*' -or $text -in @('$env:SystemDrive', '$HOME', '$env:USERPROFILE')) { $targetRoot = $true }
        }

        if ($hasRecurse -or ($hasForce -and $targetRoot)) {
            Write-Error "Safety Violation: Prohibited recursive or root deletion '$($cmdAst.Extent.Text)' detected."
            exit 1
        }
    }

    # Git destructive commands & bypass flags (token-aware to avoid false positives inside commit messages)
    if ($cmdName -in @('git', 'rtk')) {
        $argTokens = @()
        $skipNext = $false
        for ($i = 1; $i -lt $cmdAst.CommandElements.Count; $i++) {
            if ($cmdAst.CommandElements[$i] -is [System.Management.Automation.Language.VariableExpressionAst] -and $cmdAst.CommandElements[$i].Splatted) {
                Write-Error "Safety Violation: Prohibited parameter splatting '$($cmdAst.CommandElements[$i].Extent.Text)' on git command."
                exit 1
            }
            $t = $cmdAst.CommandElements[$i].Extent.Text
            if ($skipNext) {
                $skipNext = $false
                continue
            }
            # Skip commit/tag message payload tokens and global git path/config flags before subcommand
            if ($t -in @('-m', '--message', '-C', '-c', '--git-dir', '--work-tree', '--namespace')) {
                $skipNext = $true
                continue
            }
            if ($t -match '^(-m|--message=|--git-dir=|--work-tree=|--namespace=|-C|-c)') {
                continue
            }
            $argTokens += $t
        }

        if ($cmdName -eq 'rtk' -and $argTokens.Count -gt 0 -and $argTokens[0] -eq 'git') {
            $argTokens = if ($argTokens.Count -gt 1) { $argTokens[1..($argTokens.Count - 1)] } else { @() }
        }

        if ($argTokens.Count -gt 0) {
            $subCmd = $argTokens[0]
            $subArgs = ($argTokens -join ' ')

            if ($subCmd -eq 'push' -and ($subArgs -match '(^|\s)(-f\b|--force\b|--force-with-lease\b|--force-if-includes\b)' -or $subArgs -match '(^|\s)\+[A-Za-z0-9_./-]+:[A-Za-z0-9_./-]+')) {
                Write-Error "Safety Violation: Prohibited git push force flag detected."
                exit 1
            }
            if ($subCmd -eq 'clean' -and $subArgs -match '(^|\s)(-[a-zA-Z]*f|--force\b)') {
                Write-Error "Safety Violation: Prohibited git clean force flag detected."
                exit 1
            }
            if ($subCmd -eq 'commit' -and $subArgs -match '(^|\s)(-n\b|--no-verify\b)') {
                Write-Error "Safety Violation: Prohibited git commit --no-verify bypass flag detected."
                exit 1
            }
            if ($subCmd -in @('checkout', 'restore') -and $subArgs -match '(^|\s)(-f\b|--force\b|\.$)') {
                Write-Error "Safety Violation: Prohibited destructive git '$subCmd' discard detected. Use Restore-AuditCheckpoint.ps1 instead."
                exit 1
            }
            # Intercept uncheckpointed destructive git resets (allow only exact checkpoint-<task> target ref)
            if ($subCmd -eq 'reset' -and $subArgs -match '(^|\s)--hard\b') {
                $lastToken = ($argTokens[-1] -replace '^[''"]|[''"]$', '')
                if ($lastToken -notmatch '^(refs/heads/)?checkpoint-[A-Za-z0-9_-]+$') {
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

# 3. Direct .NET destructive method invocations (e.g. [System.IO.Directory]::Delete)
$memberExpressions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.InvokeMemberExpressionAst] }, $true)
foreach ($mem in $memberExpressions) {
    $exprText = $mem.Expression.Extent.Text
    $memberVal = $mem.Member.Extent.Text
    if ($exprText -match 'System\.IO\.(Directory|File|Path)' -and $memberVal -eq 'Delete') {
        Write-Error "Safety Violation: Prohibited direct .NET file deletion '$($mem.Extent.Text)' detected."
        exit 1
    }
}

Write-Output $true
exit 0
