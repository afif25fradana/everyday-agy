<#
.SYNOPSIS
    Pre-execution AST safety validator for shell commands in Antigravity.
.DESCRIPTION
    Inspects command lines using native .NET PowerShell AST parsing without execution.
    Halts on forbidden destructive cmdlets, recursive root deletions, git force pushes, and --no-verify flags.
    Adheres to ADR-0009 (ECC Selective Adaptation & Pre-Execution AST Security).
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
    $cmdName = $cmdAst.GetCommandName()

    # Block indirect dynamic expression invocations (e.g. & (Get-Command Remove-Item))
    if (-not $cmdName) {
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

    # Forbidden cmdlets
    if ($forbiddenCommands -contains $cmdName) {
        Write-Error "Safety Violation: Prohibited destructive cmdlet '$cmdName' detected."
        exit 1
    }

    # Remove-Item destructive combinations
    if ($cmdName -in @('Remove-Item', 'rm', 'del', 'erase', 'rd', 'ri', 'rmdir')) {
        $elements = $cmdAst.CommandElements
        $hasRecurse = $false
        $hasForce = $false
        $targetRoot = $false

        foreach ($el in $elements) {
            $text = $el.Extent.Text
            if ($text -match '^-(r|recurse)$') { $hasRecurse = $true }
            if ($text -match '^-(f|force)$') { $hasForce = $true }
            if ($text -match '^[/\\]+$|^[a-zA-Z]:[/\\]*$|^~[/\\]*' -or $text -in @('$env:SystemDrive', '$HOME', '$env:USERPROFILE')) { $targetRoot = $true }
        }

        if ($hasRecurse -or ($hasForce -and $targetRoot)) {
            Write-Error "Safety Violation: Prohibited recursive or root deletion '$($cmdAst.Extent.Text)' detected."
            exit 1
        }
    }

    # Git destructive commands & bypass flags
    if ($cmdName -in @('git', 'rtk')) {
        $cmdLineText = $cmdAst.Extent.Text
        if ($cmdLineText -match 'push\s+.*(-f\b|--force\b)') {
            Write-Error "Safety Violation: Prohibited git push force flag detected."
            exit 1
        }
        if ($cmdLineText -match 'clean\s+.*(-[a-zA-Z]*f|--force)') {
            Write-Error "Safety Violation: Prohibited git clean force flag detected."
            exit 1
        }
        if ($cmdLineText -match 'commit\s+.*--no-verify') {
            Write-Error "Safety Violation: Prohibited git commit --no-verify bypass flag detected."
            exit 1
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
