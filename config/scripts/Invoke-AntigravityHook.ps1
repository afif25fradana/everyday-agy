<#
.SYNOPSIS
    Antigravity PreToolUse and PostToolUse hook router.
.DESCRIPTION
    Enforces AST command safety, credential deny-path gates, subagent 4-slot contract
    validation, and automatic Gate 2 diff injection while isolating stdout JSON.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("PreToolUse", "PostToolUse")]
    [string]$Event = "PreToolUse"
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
try {
    [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
} catch {
    # Ignore hosts without an attached console handle
}

function Write-HookResponse {
    param(
        [Parameter(Mandatory = $true)]
        $Payload
    )
    $json = $Payload | ConvertTo-Json -Depth 5 -Compress
    [Console]::Out.WriteLine($json)
    [Console]::Out.Flush()
}

function Write-HookLog {
    param([string]$Message)
    try {
        $userHome = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($HOME) { $HOME } else { [Environment]::GetFolderPath("UserProfile") }
        $scratchDir = Join-Path (Join-Path (Join-Path $userHome ".gemini") "antigravity") "scratch"
        if (-not (Test-Path -LiteralPath $scratchDir)) {
            New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
        }
        $logPath = Join-Path $scratchDir "hooks.log"
        $maxBytes = 5 * 1024 * 1024
        $timestamp = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        $entry = "[$timestamp] $Message`n"
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        $entryBytes = $utf8NoBom.GetBytes($entry)

        if (Test-Path -LiteralPath $logPath) {
            $info = Get-Item -LiteralPath $logPath
            if (($info.Length + $entryBytes.Length) -gt $maxBytes) {
                $keepBytes = 1024 * 1024
                $fs = [System.IO.FileStream]::new($logPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                $tailText = ""
                try {
                    $readLen = [Math]::Min($keepBytes, [int]$fs.Length)
                    $fs.Seek(-$readLen, [System.IO.SeekOrigin]::End) | Out-Null
                    $buf = New-Object byte[] $readLen
                    $readCount = $fs.Read($buf, 0, $readLen)
                    $tailText = [System.Text.Encoding]::UTF8.GetString($buf, 0, $readCount)
                    $firstNl = $tailText.IndexOf("`n")
                    if ($firstNl -ge 0 -and ($firstNl + 1) -lt $tailText.Length) {
                        $tailText = $tailText.Substring($firstNl + 1)
                    }
                } finally {
                    $fs.Dispose()
                }
                [System.IO.File]::WriteAllText($logPath, $tailText + $entry, $utf8NoBom)
                return
            }
        }
        [System.IO.File]::AppendAllText($logPath, $entry, $utf8NoBom)
    } catch {
        # Preserve JSON stdout contract even if logging fails
    }
}

function Get-PropValue {
    param(
        [Parameter(Mandatory = $false)]
        $Object,
        [Parameter(Mandatory = $true)]
        [string[]]$Names
    )
    if ($null -eq $Object) { return $null }
    if ($Object -is [System.Collections.IDictionary]) {
        foreach ($name in $Names) {
            if ($Object.Contains($name)) { return $Object[$name] }
            foreach ($k in $Object.Keys) {
                if ("$k".Equals($name, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return $Object[$k]
                }
            }
        }
        return $null
    }
    $props = $Object.PSObject.Properties
    if ($props) {
        foreach ($name in $Names) {
            $exact = $props | Where-Object { $_.Name -ceq $name } | Select-Object -First 1
            if ($exact) { return $exact.Value }
        }
        foreach ($name in $Names) {
            $ci = $props | Where-Object { $_.Name.Equals($name, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
            if ($ci) { return $ci.Value }
        }
    }
    return $null
}

function Get-NormalizedPath {
    param([string]$RawPath)
    if ([string]::IsNullOrWhiteSpace($RawPath)) { return "" }
    $p = $RawPath.Trim().Trim('"', "'")
    $userHome = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($HOME) { $HOME } else { "" }
    $userHomeNorm = ($userHome -replace '\\', '/').TrimEnd('/')

    if ($userHomeNorm -and $p -match '^(~|\$HOME|\$\{HOME\}|\$env:USERPROFILE|%USERPROFILE%)(?=[/\\]|$)') {
        $p = $userHomeNorm + $p.Substring($Matches[1].Length)
    }
    $p = $p -replace '\\', '/'

    $prefix = ""
    $rest = $p
    if ($p -match '^([A-Za-z]:)(.*)$') {
        $prefix = $Matches[1].ToLowerInvariant()
        $rest = $Matches[2]
        if ($rest.StartsWith("/")) {
            $prefix += "/"
            $rest = $rest.TrimStart("/")
        }
    } elseif ($p.StartsWith("//")) {
        $prefix = "//"
        $rest = $p.TrimStart("/")
    } elseif ($p.StartsWith("/")) {
        $prefix = "/"
        $rest = $p.TrimStart("/")
    }

    $stack = New-Object System.Collections.Generic.List[string]
    foreach ($seg in ($rest -split '/')) {
        if ([string]::IsNullOrEmpty($seg) -or $seg -eq ".") { continue }
        if ($seg -eq "..") {
            if ($stack.Count -gt 0 -and $stack[$stack.Count - 1] -ne "..") {
                $stack.RemoveAt($stack.Count - 1)
            } elseif (-not $prefix) {
                $stack.Add("..")
            }
            continue
        }
        $stack.Add($seg.ToLowerInvariant())
    }

    return $prefix + ($stack -join '/')
}

function Test-DenyPath {
    param([string]$RawPath)
    $norm = Get-NormalizedPath -RawPath $RawPath
    if ([string]::IsNullOrWhiteSpace($norm)) { return $false }

    $leaf = ($norm -split '/')[-1]
    if ($leaf -match '^\.env' -and $leaf -notin @('.env.example', '.env.sample', '.env.template')) {
        return $true
    }
    if ($leaf -match '\.(key|pem)$') {
        return $true
    }
    if ($norm -match '(^|/)(\.ssh|\.aws|\.gnupg)(/|$)') {
        return $true
    }
    if ($norm -match '(^|/)\.gemini/(?:antigravity[^/]*/)?mcp(/|$)') {
        return $true
    }
    return $false
}

try {
    $rawInput = ""
    if ([Console]::IsInputRedirected) {
        $inStream = [Console]::OpenStandardInput()
        $reader = New-Object System.IO.StreamReader($inStream, [System.Text.UTF8Encoding]::new($false), $true)
        try {
            $rawInput = $reader.ReadToEnd()
        } finally {
            $reader.Dispose()
        }
    }

    if ($null -ne $rawInput) {
        $rawInput = $rawInput.TrimStart([char]0xFEFF).Trim()
    }
    if ([string]::IsNullOrWhiteSpace($rawInput)) {
        throw "Empty hook payload on stdin."
    }

    $payload = $rawInput | ConvertFrom-Json
    $toolCall = Get-PropValue -Object $payload -Names @("toolCall")
    if ($null -eq $toolCall) {
        throw "Missing toolCall object in hook payload."
    }

    $toolName = [string](Get-PropValue -Object $toolCall -Names @("name"))
    $toolArgs = Get-PropValue -Object $toolCall -Names @("args")

    $configRoot = Split-Path -Parent $PSScriptRoot
    $orchestratorScripts = Join-Path (Join-Path (Join-Path $configRoot "skills") "orchestrator") "scripts"

    if ($Event -eq "PostToolUse") {
        $toolError = [string](Get-PropValue -Object $payload -Names @("error"))
        if ([string]::IsNullOrWhiteSpace($toolError) -and $toolName -in @("write_to_file", "replace_file_content", "multi_replace_file_content")) {
            $targetFile = [string](Get-PropValue -Object $toolArgs -Names @("TargetFile", "Path", "AbsolutePath"))
            if (-not [string]::IsNullOrWhiteSpace($targetFile) -and ([System.IO.Path]::GetFileName($targetFile.Trim()) -ieq 'gate2_handoff.md')) {
                if (Test-Path -LiteralPath $targetFile) {
                    $fileText = [System.IO.File]::ReadAllText($targetFile, [System.Text.Encoding]::UTF8)
                    if ($fileText.Contains("{{VERBATIM_GIT_DIFF}}") -or $fileText.Contains("{{VERBATIM_GIT_DIFFSTAT}}")) {
                        $updateScript = Join-Path $orchestratorScripts "Update-Gate2Diff.ps1"
                        if (-not (Test-Path -LiteralPath $updateScript)) {
                            throw "Update-Gate2Diff.ps1 not found at $updateScript"
                        }
                        $repoArg = $null
                        $wsPaths = Get-PropValue -Object $payload -Names @("workspacePaths")
                        $prevEap = $ErrorActionPreference
                        $ErrorActionPreference = "Continue"
                        try {
                            if ($null -ne $wsPaths) {
                                foreach ($ws in @($wsPaths)) {
                                    $wsStr = [string]$ws
                                    if (-not [string]::IsNullOrWhiteSpace($wsStr) -and (Test-Path -LiteralPath $wsStr -PathType Container)) {
                                        $inGit = (git -C $wsStr rev-parse --is-inside-work-tree 2>$null | Out-String).Trim()
                                        if ($LASTEXITCODE -eq 0 -and $inGit -eq "true") {
                                            $repoArg = $wsStr
                                            break
                                        }
                                        if (-not $repoArg) { $repoArg = $wsStr }
                                    }
                                }
                            }
                            if ($repoArg) {
                                & $updateScript -ArtifactPath $targetFile -RepoPath $repoArg 1>$null 3>$null 4>$null 5>$null 6>$null
                            } else {
                                & $updateScript -ArtifactPath $targetFile 1>$null 3>$null 4>$null 5>$null 6>$null
                            }
                        } finally {
                            $ErrorActionPreference = $prevEap
                        }
                    }
                }
            }
        }
        Write-HookResponse @{}
        exit 0
    }

    switch ($toolName) {
        "run_command" {
            $cmdLine = Get-PropValue -Object $toolArgs -Names @("CommandLine", "commandLine", "command")
            if ([string]::IsNullOrWhiteSpace([string]$cmdLine)) {
                Write-HookResponse @{ decision = "ask"; reason = "Missing CommandLine argument in run_command payload." }
                exit 0
            }
            $safetyScript = Join-Path $orchestratorScripts "Test-PowerShellCommandSafety.ps1"
            if (-not (Test-Path -LiteralPath $safetyScript)) {
                throw "Test-PowerShellCommandSafety.ps1 not found at $safetyScript"
            }
            $global:LASTEXITCODE = 0
            $blocked = $false
            $blockMsg = ""
            try {
                $out = & $safetyScript -CommandLine ([string]$cmdLine) *>&1
                if ($LASTEXITCODE -ne 0) {
                    $blocked = $true
                    $blockMsg = ($out | Out-String).Trim()
                }
            } catch {
                $blocked = $true
                $blockMsg = $_.Exception.Message
            }
            if ($blocked) {
                if ($blockMsg -match '(?s)(Safety Violation:.*|Syntax error in command line:.*)') {
                    $blockMsg = $Matches[1].Trim()
                }
                Write-HookResponse @{ decision = "deny"; reason = $blockMsg }
                exit 0
            }
            Write-HookResponse @{ decision = "allow" }
            exit 0
        }

        { $_ -in @("view_file", "replace_file_content", "multi_replace_file_content", "write_to_file") } {
            $rawPath = Get-PropValue -Object $toolArgs -Names @("AbsolutePath", "TargetFile", "Path", "FilePath")
            if ([string]::IsNullOrWhiteSpace([string]$rawPath)) {
                Write-HookResponse @{ decision = "ask"; reason = "Missing target file path argument in $toolName payload." }
                exit 0
            }
            if (Test-DenyPath -RawPath ([string]$rawPath)) {
                Write-HookResponse @{ decision = "deny"; reason = "Blocked by Security Hook: Access to credential or secret path '$rawPath' is prohibited." }
                exit 0
            }
            Write-HookResponse @{ decision = "allow" }
            exit 0
        }

        "invoke_subagent" {
            $missingTagReason = "Blocked by Orchestrator Hook: Subagent prompt is missing mandatory 4-Slot Delegation Contract tags (<ROLE_AND_OBJECTIVE>, <SCOPE_AND_BOUNDARIES>, <TOOLS_AND_ABSOLUTE_SKILL_PATHS>, <RETURN_CONTRACT>). Read ~/.gemini/config/skills/orchestrator/references/subagent-patterns.md and include all 4 tags."
            $requiredTags = @(
                "<ROLE_AND_OBJECTIVE>",
                "<SCOPE_AND_BOUNDARIES>",
                "<TOOLS_AND_ABSOLUTE_SKILL_PATHS>",
                "<RETURN_CONTRACT>"
            )
            $allowedModels = @("inherit", "flash", "pro")

            $topModel = Get-PropValue -Object $toolArgs -Names @("Model", "model")
            if ($null -ne $topModel -and -not [string]::IsNullOrWhiteSpace([string]$topModel)) {
                $topModelStr = [string]$topModel
                if ($topModelStr -cnotin $allowedModels) {
                    Write-HookResponse @{ decision = "deny"; reason = "Blocked by Orchestrator Hook: Invalid subagent Model '$topModelStr'. Allowed values are inherit, flash, or pro." }
                    exit 0
                }
            }

            $subagentsVal = Get-PropValue -Object $toolArgs -Names @("Subagents", "subagents")
            $entries = @()
            if ($null -ne $subagentsVal) {
                $entries = @($subagentsVal)
                if ($entries.Count -eq 0) {
                    Write-HookResponse @{ decision = "deny"; reason = $missingTagReason }
                    exit 0
                }
            } else {
                $entries = @($toolArgs)
            }

            foreach ($entry in $entries) {
                $entryModel = Get-PropValue -Object $entry -Names @("Model", "model")
                if ($null -ne $entryModel -and -not [string]::IsNullOrWhiteSpace([string]$entryModel)) {
                    $modelStr = [string]$entryModel
                    if ($modelStr -cnotin $allowedModels) {
                        Write-HookResponse @{ decision = "deny"; reason = "Blocked by Orchestrator Hook: Invalid subagent Model '$modelStr'. Allowed values are inherit, flash, or pro." }
                        exit 0
                    }
                }
                $promptVal = [string](Get-PropValue -Object $entry -Names @("Prompt", "prompt"))
                foreach ($tag in $requiredTags) {
                    if (-not $promptVal.Contains($tag)) {
                        Write-HookResponse @{ decision = "deny"; reason = $missingTagReason }
                        exit 0
                    }
                }
            }

            Write-HookResponse @{ decision = "allow" }
            exit 0
        }

        default {
            Write-HookResponse @{ decision = "allow" }
            exit 0
        }
    }
} catch {
    $errMsg = $_.Exception.Message
    Write-HookLog -Message "Event=$Event Error=$errMsg"
    if ($Event -eq "PostToolUse") {
        Write-HookResponse @{}
    } else {
        Write-HookResponse @{ decision = "ask"; reason = "Hook fallback ($Event): $errMsg" }
    }
    exit 0
}
