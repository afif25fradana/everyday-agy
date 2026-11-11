<#
.SYNOPSIS
    Pre-execution AST safety validator for shell commands in Antigravity.
.DESCRIPTION
    Inspects command lines using native .NET PowerShell AST parsing without execution.
    Halts on forbidden destructive cmdlets, recursive root deletions, git force pushes, and --no-verify flags.
    Adheres to ADR-0003.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [AllowEmptyString()]
    [string]$CommandLine
)

begin {
    $ErrorActionPreference = "Stop"

    function Get-NormalizedTokenText {
        param([string]$RawText)
        if ([string]::IsNullOrEmpty($RawText)) { return '' }
        $trimmed = $RawText -replace '^[''"]|[''"]$', ''
        # Strip PowerShell backtick escapes (`f -> f), internal quote obfuscation, control chars, and Unicode dashes
        return (((($trimmed -replace '`', '') -replace '[''"]', '') -replace '[\x00-\x1F\x7F]', '') -replace '[\u2013-\u2015]', '-')
    }

    function Test-IsRecurseSwitchActive {
        param($ParamAst)
        if ($ParamAst -isnot [System.Management.Automation.Language.CommandParameterAst]) {
            return $false
        }
        if ($ParamAst.ParameterName -notmatch '^(?i)r(e(c(u(r(s(e)?)?)?)?)?)?$') {
            return $false
        }
        if ($null -eq $ParamAst.Argument) {
            return $true
        }
        $argNorm = (Get-NormalizedTokenText $ParamAst.Argument.Extent.Text) -replace '[\(\)\s]', ''
        if ($argNorm -match '^(?i)(\$?false|0)$') {
            return $false
        }
        return $true
    }

    # 1. Deny forbidden destructive cmdlets and execution wrappers
    $forbiddenCommands = @(
        'Format-Volume', 'Format-Disk', 'Clear-Disk', 'Initialize-Disk',
        'Stop-Computer', 'Restart-Computer',
        'Start-Process', 'saps', 'start',
        'Invoke-CimMethod', 'icim', 'Invoke-WmiMethod', 'iwmi',
        'Invoke-Command', 'icm', 'Start-Job', 'sajb', 'Start-ThreadJob',
        'Remove-WmiObject', 'rwmi', 'Remove-CimInstance', 'rcim'
    )
}

process {
    if ([string]::IsNullOrWhiteSpace($CommandLine)) {
        return
    }

    $parseErrors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($CommandLine, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        Write-Error "Syntax error in command line: $($parseErrors[0].Message)" -ErrorAction Continue
        exit 1
    }

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
                    Write-Error "Safety Violation: Prohibited dynamic command invocation '$($cmdAst.Extent.Text)' detected." -ErrorAction Continue
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
            Write-Error "Safety Violation: Prohibited secondary shell interpreter '$rawCmdName' detected." -ErrorAction Continue
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
                if ($t -match '^-(f|file)\b') {
                    break
                }
                if ($t -match '^-(c|co|com|comm|comma|comman|command|e|en|enc|enco|encod|encode|encoded|encodedc|encodedco|encodedcom|encodedcomm|encodedcomma|encodedcomman|encodedcommand)\b') {
                    Write-Error "Safety Violation: Prohibited inline subshell evaluation '$($cmdAst.Extent.Text)' detected." -ErrorAction Continue
                    exit 1
                }
                if ($t -match '^-(executionpolicy|ep|ex|windowstyle|w|configurationname|config|custompipename|outputformat|of|inputformat|if|workingdirectory|wd|settingsfile)\b') {
                    if ($t -notmatch '[:=]') {
                        $skipNextArg = $true
                    }
                    continue
                }
                if ($t -match '^-') {
                    continue
                }
                Write-Error "Safety Violation: Prohibited inline subshell evaluation '$($cmdAst.Extent.Text)' detected." -ErrorAction Continue
                exit 1
            }
        }

        # Forbidden cmdlets
        if ($forbiddenCommands -contains $cmdName) {
            Write-Error "Safety Violation: Prohibited destructive cmdlet '$cmdName' detected." -ErrorAction Continue
            exit 1
        }

        # ForEach-Object / foreach / % Delete member execution
        if ($cmdName -in @('ForEach-Object', 'foreach', '%')) {
            for ($i = 1; $i -lt $targetElements.Count; $i++) {
                $feEl = $targetElements[$i]
                $feTok = Get-NormalizedTokenText $feEl.Extent.Text
                if ($feTok -eq 'Delete') {
                    Write-Error "Safety Violation: Prohibited dynamic member invocation '$($cmdAst.Extent.Text)' detected." -ErrorAction Continue
                    exit 1
                }
                if ($feEl -is [System.Management.Automation.Language.CommandParameterAst] -and $null -ne $feEl.Argument) {
                    $feArg = Get-NormalizedTokenText $feEl.Argument.Extent.Text
                    if ($feArg -eq 'Delete') {
                        Write-Error "Safety Violation: Prohibited dynamic member invocation '$($cmdAst.Extent.Text)' detected." -ErrorAction Continue
                        exit 1
                    }
                }
            }
        }

        # Destructive robocopy mirror/purge modes
        if ($cmdName -eq 'robocopy') {
            foreach ($el in $targetElements) {
                $t = Get-NormalizedTokenText $el.Extent.Text
                if ($t -match '(?i)^[/-](mir|purge|mov|move)$') {
                    Write-Error "Safety Violation: Prohibited destructive robocopy flag '$t' detected." -ErrorAction Continue
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
                    Write-Error "Safety Violation: Prohibited parameter splatting '$text' on '$cmdName'." -ErrorAction Continue
                    exit 1
                }

                $pathVal = $null
                if ($el -is [System.Management.Automation.Language.CommandParameterAst]) {
                    if (Test-IsRecurseSwitchActive $el) {
                        $hasRecurse = $true
                    }
                    if ($el.ParameterName -match '^(?i)f(o(r(c(e)?)?)?)?$') {
                        $forceArgNorm = if ($null -ne $el.Argument) { (Get-NormalizedTokenText $el.Argument.Extent.Text) -replace '[\(\)\s]', '' } else { '' }
                        if ($forceArgNorm -notmatch '^(?i)(\$?false|0)$') {
                            $hasForce = $true
                        }
                    }
                    $isPosixCluster = $text -match '^-(?i)[rfivd]{2,4}$'
                    if ($isPosixCluster -and $text -match '(?i)r') { $hasRecurse = $true }
                    if ($isPosixCluster -and $text -match '(?i)f') { $hasForce = $true }
                    if ($null -ne $el.Argument -and $el.ParameterName -notmatch '^(?i)(r(e(c(u(r(s(e)?)?)?)?)?)?|f(o(r(c(e)?)?)?)?)$') {
                        $pathVal = Get-NormalizedTokenText $el.Argument.Extent.Text
                    }
                } else {
                    $isPosixCluster = $text -match '^-(?i)[rfivd]{2,4}$'
                    if ($text -match '^/s$' -or ($isPosixCluster -and $text -match '(?i)r')) { $hasRecurse = $true }
                    if ($text -match '^/q$' -or ($isPosixCluster -and $text -match '(?i)f')) { $hasForce = $true }
                    $pathVal = $text -replace '^-[a-zA-Z]+:', ''
                }

                if (-not [string]::IsNullOrEmpty($pathVal)) {
                    # Check sensitive credential directory deletions (~/.ssh, ~/.aws, ~/.gnupg)
                    if ($pathVal -match '(?i)(^|[/\\])(\.ssh|\.aws|\.gnupg)($|[/\\])') {
                        Write-Error "Safety Violation: Prohibited deletion of credential or sensitive directory '$text' detected." -ErrorAction Continue
                        exit 1
                    }

                    # Check root targets, drive roots, root wildcards, home, and environment path variables (ADR-0003)
                    if ($pathVal -match '^[/\\]+(\*.*)?$' -or
                        $pathVal -match '^[a-zA-Z]:[/\\]*(\*.*)?$' -or
                        $pathVal -match '^~[/\\]*(\*.*)?$' -or
                        $pathVal -match '(?i)^(\.?[\/\\])?\*$' -or
                        $pathVal -match '^\$\{?(HOME|env:(USERPROFILE|SystemDrive))\}?([/\\]+(\*.*)?)?$') {
                        $targetRoot = $true
                    }
                }
            }

            # Walk all enclosing PipelineAst ancestors for upstream recursion (-r/-Recurse, -Depth, /s)
            $curNode = $cmdAst
            while ($null -ne $curNode -and $null -ne $curNode.Parent) {
                $parentNode = $curNode.Parent
                if ($parentNode -is [System.Management.Automation.Language.PipelineAst]) {
                    $pipeIdx = -1
                    for ($pi = 0; $pi -lt $parentNode.PipelineElements.Count; $pi++) {
                        if ($parentNode.PipelineElements[$pi] -eq $curNode) {
                            $pipeIdx = $pi
                            break
                        }
                    }
                    if ($pipeIdx -gt 0) {
                        for ($up = 0; $up -lt $pipeIdx; $up++) {
                            $upCmds = $parentNode.PipelineElements[$up].FindAll({ $args[0] -is [System.Management.Automation.Language.CommandAst] }, $true)
                            foreach ($upCmd in $upCmds) {
                                foreach ($upEl in $upCmd.CommandElements) {
                                    $upTxt = Get-NormalizedTokenText $upEl.Extent.Text
                                    if ($upEl -is [System.Management.Automation.Language.CommandParameterAst]) {
                                        if ((Test-IsRecurseSwitchActive $upEl) -or
                                            $upEl.ParameterName -match '^(?i)dep(th?)?$' -or
                                            ($upTxt -match '^-(?i)[rfivd]{2,4}$' -and $upTxt -match '(?i)r')) {
                                            $hasRecurse = $true
                                        }
                                    } elseif ($upTxt -match '^(?i)/s$') {
                                        $hasRecurse = $true
                                    }
                                }
                            }
                        }
                    }
                }
                $curNode = $parentNode
            }

            # Block recursive deletions OR root deletions regardless of -Force (ADR-0003)
            if ($hasRecurse -or $targetRoot) {
                Write-Error "Safety Violation: Prohibited recursive or root deletion '$($cmdAst.Extent.Text)' detected." -ErrorAction Continue
                exit 1
            }
        }

        # Git destructive commands & bypass flags (token-aware to avoid false positives inside commit messages)
        if ($cmdName -eq 'git') {
            $argTokens = @()
            $skipNext = $false
            $subCmd = $null
            $gitGlobalBools = @('--no-pager', '-p', '-P', '--paginate', '--bare', '--no-replace-objects', '--literal-pathspecs', '--no-optional-locks', '--no-lazy-fetch', '--no-advice', '-v', '--version')
            $dangerousGitConfigRe = '(?i)^(core\.(hookspath|fsmonitor|sshcommand|askpass|editor)|clean\.requireforce|sequence\.editor|safe\.directory|alias\.)'

            for ($i = 1; $i -lt $targetElements.Count; $i++) {
                if ($targetElements[$i] -is [System.Management.Automation.Language.VariableExpressionAst] -and $targetElements[$i].Splatted) {
                    Write-Error "Safety Violation: Prohibited parameter splatting '$($targetElements[$i].Extent.Text)' on git command." -ErrorAction Continue
                    exit 1
                }
                $t = Get-NormalizedTokenText $targetElements[$i].Extent.Text
                if ($skipNext) {
                    $skipNext = $false
                    continue
                }
                if ($null -eq $subCmd -and $t -notmatch '^-') {
                    $subCmd = $t
                }
                if ($null -eq $subCmd) {
                    if ($t -in $gitGlobalBools -or $t -in @('-h', '--help')) {
                        continue
                    }
                    if ($t -match '^--exec-path=') {
                        continue
                    }
                    if ($t -eq '--config-env') {
                        if ($i + 1 -lt $targetElements.Count) {
                            $cfgEnvPayload = Get-NormalizedTokenText $targetElements[$i + 1].Extent.Text
                            if ($cfgEnvPayload -match $dangerousGitConfigRe) {
                                Write-Error "Safety Violation: Prohibited git --config-env security override '$cfgEnvPayload' detected." -ErrorAction Continue
                                exit 1
                            }
                        }
                        $skipNext = $true
                        continue
                    }
                    if ($t -match '^--config-env=(?<cfg>.+)$') {
                        $cfgEnvPayload = Get-NormalizedTokenText $Matches['cfg']
                        if ($cfgEnvPayload -match $dangerousGitConfigRe) {
                            Write-Error "Safety Violation: Prohibited git --config-env security override '$cfgEnvPayload' detected." -ErrorAction Continue
                            exit 1
                        }
                        continue
                    }
                    if ($t -in @('--git-dir', '--work-tree', '--namespace') -or $t -ceq '-C') {
                        $skipNext = $true
                        continue
                    }
                    if ($t -ceq '-c') {
                        if ($i + 1 -lt $targetElements.Count) {
                            $cfgPayload = Get-NormalizedTokenText $targetElements[$i + 1].Extent.Text
                            if ($cfgPayload -match $dangerousGitConfigRe) {
                                Write-Error "Safety Violation: Prohibited git -c security override '$cfgPayload' detected." -ErrorAction Continue
                                exit 1
                            }
                        }
                        $skipNext = $true
                        continue
                    }
                    if ($t -cmatch '^-c(?<cfg>.+)$') {
                        $cfgPayload = Get-NormalizedTokenText ($Matches['cfg'] -replace '^=', '')
                        if ($cfgPayload -match $dangerousGitConfigRe) {
                            Write-Error "Safety Violation: Prohibited git -c security override '$cfgPayload' detected." -ErrorAction Continue
                            exit 1
                        }
                        continue
                    }
                    if ($t -match '^(--git-dir=|--work-tree=|--namespace=)' -or $t -cmatch '^-C') {
                        continue
                    }
                }
                # Handle commit/tag/merge message payload flags including clustered -am / -nm
                if ($subCmd -in @('commit', 'tag', 'merge') -and ($t -ceq '--message' -or $t -cmatch '^-[^-]*m$')) {
                    if ($subCmd -eq 'commit' -and $t -cmatch '^-[^-]*n') {
                        Write-Error "Safety Violation: Prohibited git commit --no-verify bypass flag detected." -ErrorAction Continue
                        exit 1
                    }
                    $skipNext = $true
                    continue
                }
                $isInlineMessagePayload = ($t -match '^--message=' -or ($t -cmatch '^-m.+' -and $t -cnotmatch '^-m$')) -and ($subCmd -in @('commit', 'tag', 'merge'))
                if ($isInlineMessagePayload) {
                    continue
                }
                $argTokens += $t
            }

            if ($argTokens.Count -gt 0) {
                $subCmd = $null
                $subIdx = -1
                for ($j = 0; $j -lt $argTokens.Count; $j++) {
                    if ($argTokens[$j] -notmatch '^-') {
                        $subCmd = $argTokens[$j]
                        $subIdx = $j
                        break
                    }
                }
                [string[]]$subTail = if ($subIdx -ge 0 -and ($subIdx + 1) -lt $argTokens.Count) {
                    @($argTokens[($subIdx + 1)..($argTokens.Count - 1)])
                } else {
                    @()
                }

                if ($subCmd -eq 'push') {
                    $hasForceFlag = [bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*f' -or $_ -match '^(--force|--force-with-lease|--force-if-includes)(=.*)?$' })
                    $hasForceRefspec = [bool]($subTail | Where-Object { $_ -match '^\+\S+' })
                    $hasRemoteDeletion = [bool]($subTail | Where-Object { $_ -match '^:\S+' -or $_ -ceq '--delete' -or $_ -cmatch '^-[^-]*d' })
                    if ($hasForceFlag -or $hasForceRefspec -or $hasRemoteDeletion) {
                        Write-Error "Safety Violation: Prohibited git push force or remote deletion detected." -ErrorAction Continue
                        exit 1
                    }
                }
                if ($subCmd -eq 'branch') {
                    $hasShortForceDelete = [bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*D' -or ($_ -cmatch '^-[^-]*d' -and $_ -cmatch '^-[^-]*f') })
                    $hasSplitForceDelete = ([bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*d' -or $_ -ceq '--delete' })) -and ([bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*f' -or $_ -ceq '--force' }))
                    if ($hasShortForceDelete -or $hasSplitForceDelete) {
                        Write-Error "Safety Violation: Prohibited destructive git branch force deletion detected." -ErrorAction Continue
                        exit 1
                    }
                    $hasForce = [bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*f' -or $_ -ceq '--force' })
                    $hasUpperMoveOrCopy = [bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*[MC]' })
                    $hasAnyMoveOrCopy = [bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*[mMcC]' -or $_ -in @('--move', '--copy') })
                    if ($hasForce -or $hasUpperMoveOrCopy) {
                        $branchArgFlags = @('-u', '--set-upstream-to', '--merged', '--no-merged', '--contains', '--no-contains', '--points-at', '--format', '--sort', '--forked', '--delete-merged')
                        $skipBranchVal = $false
                        $branchArgList = New-Object System.Collections.Generic.List[string]
                        foreach ($bt in $subTail) {
                            if ($skipBranchVal) { $skipBranchVal = $false; continue }
                            if ($bt -in $branchArgFlags) { $skipBranchVal = $true; continue }
                            if ($bt -eq '--') { continue }
                            if ($bt -notmatch '^-') { $branchArgList.Add($bt) }
                        }
                        [string[]]$branchArgs = $branchArgList.ToArray()
                        $targetBranch = if ($branchArgs.Count -eq 0) { '' } elseif ($hasAnyMoveOrCopy) { $branchArgs[-1] } else { $branchArgs[0] }
                        if ($targetBranch -notmatch '^checkpoint-[A-Za-z0-9_-]+$') {
                            Write-Error "Safety Violation: git branch (-f|--force) cannot overwrite arbitrary branch pointers." -ErrorAction Continue
                            exit 1
                        }
                    }
                }
                if ($subCmd -eq 'worktree') {
                    if ($subTail.Count -ge 1 -and $subTail[0] -eq 'remove') {
                        if ([bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*f' -or $_ -ceq '--force' })) {
                            Write-Error "Safety Violation: git worktree remove (-f|--force) is prohibited." -ErrorAction Continue
                            exit 1
                        }
                    }
                }
                if ($subCmd -eq 'clean' -and ([bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*f' -or $_ -ceq '--force' }))) {
                    Write-Error "Safety Violation: Prohibited git clean force flag detected." -ErrorAction Continue
                    exit 1
                }
                if ($subCmd -eq 'commit' -and ([bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*n' -or $_ -match '^--no-veri(f|fy)?$' }))) {
                    Write-Error "Safety Violation: Prohibited git commit --no-verify bypass flag detected." -ErrorAction Continue
                    exit 1
                }
                if ($subCmd -eq 'restore') {
                    if ($subTail.Count -eq 1 -and $subTail[0] -in @('-h', '--help')) {
                        # Lone help invocation does not mutate worktree
                    } else {
                        $hasStaged = [bool]($subTail | Where-Object { $_ -ceq '--staged' -or $_ -cmatch '^-[^-]*S' })
                        $hasWorktree = [bool]($subTail | Where-Object { $_ -match '^--worktree(=.*)?$' -or $_ -cmatch '^-[^-]*W' })
                        $hasSource = [bool]($subTail | Where-Object { $_ -match '^--source(=.*)?$' -or $_ -cmatch '^-[^-]*s' })
                        if (-not ($hasStaged -and -not $hasWorktree -and -not $hasSource)) {
                            Write-Error "Safety Violation: Prohibited destructive git 'restore' discard detected. Use Restore-AuditCheckpoint.ps1 instead." -ErrorAction Continue
                            exit 1
                        }
                    }
                }
                if ($subCmd -eq 'checkout') {
                    $isBranchCreate = [bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*[bB]' -or $_ -ceq '--orphan' })
                    $hasForce = [bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*f' -or $_ -ceq '--force' })
                    $hasDoubleDash = [bool]($subTail | Where-Object { $_ -eq '--' })
                    [string[]]$positional = @($subTail | Where-Object { $_ -ne '--' -and $_ -notmatch '^-' })
                    $hasDotOrWildcard = ([bool]($positional | Where-Object { $_ -eq '.' -or $_ -eq '*' })) -and -not $isBranchCreate
                    $hasMultiPositional = ($positional.Count -ge 2) -and -not $isBranchCreate
                    $hasFileTarget = $false
                    if ($positional.Count -ge 1 -and -not $isBranchCreate) {
                        $target = $positional[-1]
                        if ($target -match '^\.[/\\]' -or $target -match '\.(txt|md|json|js|ts|tsx|jsx|py|go|rs|c|cpp|h|cs|java|rb|php|html|css|scss|yml|yaml|xml|sh|ps1|bat|cmd|toml|ini|cfg|lock)$') {
                            $hasFileTarget = $true
                        }
                    }
                    if ($hasForce -or $hasDoubleDash -or $hasDotOrWildcard -or $hasMultiPositional -or $hasFileTarget) {
                        Write-Error "Safety Violation: Prohibited destructive git 'checkout' discard detected. Use Restore-AuditCheckpoint.ps1 instead." -ErrorAction Continue
                        exit 1
                    }
                }
                if ($subCmd -eq 'switch') {
                    if ([bool]($subTail | Where-Object { $_ -cmatch '^-[^-]*[fC]' -or $_ -in @('--force', '--discard-changes', '--force-create') })) {
                        Write-Error "Safety Violation: Prohibited destructive git 'switch' discard/force detected. Use Restore-AuditCheckpoint.ps1 instead." -ErrorAction Continue
                        exit 1
                    }
                }
                if ($subCmd -eq 'stash' -and ([bool]($subTail | Where-Object { $_ -in @('drop', 'clear') }))) {
                    Write-Error "Safety Violation: Prohibited destructive git 'stash' drop/clear detected." -ErrorAction Continue
                    exit 1
                }
                if ($subCmd -eq 'reset' -and ([bool]($subTail | Where-Object { $_ -ceq '--hard' }))) {
                    [string[]]$nonFlagArgs = @($subTail | Where-Object { $_ -notmatch '^-' })
                    if ($nonFlagArgs.Count -ne 1) {
                        Write-Error "Safety Violation: Prohibited uncheckpointed 'git reset --hard' detected." -ErrorAction Continue
                        exit 1
                    }
                    $targetRef = Get-NormalizedTokenText $nonFlagArgs[0]
                    if ($targetRef -notmatch '^(refs/heads/)?checkpoint-[A-Za-z0-9_-]+$') {
                        Write-Error "Safety Violation: Prohibited uncheckpointed 'git reset --hard' detected." -ErrorAction Continue
                        exit 1
                    }
                }
                if ($subCmd -eq 'config') {
                    if ([bool]($subTail | Where-Object { $_ -match '(?i)(core\.(hookspath|fsmonitor|sshcommand|askpass|editor)|clean\.requireforce|sequence\.editor|safe\.directory|alias\.)' })) {
                        Write-Error "Safety Violation: Prohibited git config security override detected." -ErrorAction Continue
                        exit 1
                    }
                }
            }
        }

        # COM object creation via New-Object
        if ($cmdName -eq 'New-Object') {
            foreach ($el in $targetElements) {
                $t = Get-NormalizedTokenText $el.Extent.Text
                if ($t -match '(?i)^-com(object)?\b') {
                    Write-Error "Safety Violation: New-Object COM object creation is prohibited." -ErrorAction Continue
                    exit 1
                }
                if ($t -match '(?i)(^|\[\s*)(System\.)?Diagnostics\.Process(\s*\]|$)') {
                    Write-Error "Safety Violation: Prohibited .NET process object instantiation '$t' detected." -ErrorAction Continue
                    exit 1
                }
            }
        }

        # Dynamic code execution
        if ($cmdName -in @('Invoke-Expression', 'iex')) {
            Write-Error "Safety Violation: Prohibited dynamic code execution ($cmdName) detected." -ErrorAction Continue
            exit 1
        }
    }

    # 3. Direct .NET destructive method invocations, process execution & dynamic reflection execution
    $memberExpressions = $ast.FindAll({ $args[0] -is [System.Management.Automation.Language.InvokeMemberExpressionAst] }, $true)
    foreach ($mem in $memberExpressions) {
        $exprText = Get-NormalizedTokenText $mem.Expression.Extent.Text
        $memberVal = (Get-NormalizedTokenText $mem.Member.Extent.Text) -replace '^[\(\s]+|[\)\s]+$', ''

        # Intercept direct process execution via .NET Process::Start and constructor instantiation (GAP-CRIT-04)
        $isProcessType = $exprText -match '(?i)Diagnostics\.Process'
        $isProcessVar = $false
        if ($mem.Expression -is [System.Management.Automation.Language.VariableExpressionAst]) {
            $varName = $mem.Expression.VariablePath.UserPath
            $matchingAssign = $ast.FindAll({
                $args[0] -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $args[0].Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $args[0].Left.VariablePath.UserPath -eq $varName -and
                $args[0].Right.Extent.Text -match '(?i)Diagnostics\.Process'
            }, $true)
            if ($matchingAssign.Count -gt 0) { $isProcessVar = $true }
        }
        if (($memberVal -in @('Start', 'new') -and $isProcessType) -or ($memberVal -eq 'Start' -and $isProcessVar)) {
            Write-Error "Safety Violation: Prohibited direct .NET process execution '$($mem.Extent.Text)' detected." -ErrorAction Continue
            exit 1
        }

        # Intercept WMI process creation (GAP-CRIT-04)
        if ($memberVal -eq 'Create' -and ($exprText -match '(?i)(wmiclass|Win32_Process)' -or $mem.Extent.Text -match '(?i)(wmiclass|Win32_Process)')) {
            Write-Error "Safety Violation: WMI process creation is prohibited." -ErrorAction Continue
            exit 1
        }

        # Intercept COM ProgID/CLSID instantiation via .NET Type reflection
        if ($memberVal -in @('GetTypeFromProgID', 'GetTypeFromCLSID')) {
            Write-Error "Safety Violation: Prohibited COM ProgID/CLSID instantiation '$($mem.Extent.Text)' detected." -ErrorAction Continue
            exit 1
        }

        # Intercept destructive .NET deletions on files, directories, and IO object variables
        if ($memberVal -eq 'Delete' -and (
            $exprText -match '(?i)(^|\[\s*)(System\.)?IO\.(Directory|File|Path|DirectoryInfo|FileInfo)' -or
            $exprText -match '(?i)\b(Get-Item|Get-ChildItem|gi|gci|dir|ls|DirectoryInfo|FileInfo)\b' -or
            $mem.Expression -is [System.Management.Automation.Language.VariableExpressionAst])) {
            Write-Error "Safety Violation: Prohibited direct .NET file/directory deletion '$($mem.Extent.Text)' detected." -ErrorAction Continue
            exit 1
        }
        if (($memberVal -eq 'Create' -and $exprText -match '(?i)(^|\[\s*)(System\.Management\.Automation\.)?ScriptBlock(\s*\]|:|$)') -or
            ($memberVal -in @('Invoke', 'InvokeReturnAsIs', 'InvokeScript', 'BeginInvoke', 'ExpandString') -and (
                $exprText -match '(?i)(scriptblock|InvokeCommand|PowerShell)' -or
                $mem.Expression -is [System.Management.Automation.Language.VariableExpressionAst]))) {
            Write-Error "Safety Violation: Prohibited dynamic script reflection execution '$($mem.Extent.Text)' detected." -ErrorAction Continue
            exit 1
        }
    }
}

end {
    Write-Output $true
    exit 0
}
