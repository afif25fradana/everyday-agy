<#
.SYNOPSIS
    Antigravity PreToolUse and PostToolUse hook router.
.DESCRIPTION
    Enforces AST command safety, credential deny-path gates, and automatic Gate 2
    diff injection while isolating stdout JSON.
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
                    $readLen = [int][Math]::Min([long]$keepBytes, $fs.Length)
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
                for ($attempt = 0; $attempt -lt 2; $attempt++) {
                    try {
                        [System.IO.File]::WriteAllText($logPath, $tailText + $entry, $utf8NoBom)
                        return
                    } catch [System.IO.IOException] {
                        if ($attempt -eq 0) { Start-Sleep -Milliseconds 15 } else { throw }
                    }
                }
            }
        }
        for ($attempt = 0; $attempt -lt 2; $attempt++) {
            try {
                [System.IO.File]::AppendAllText($logPath, $entry, $utf8NoBom)
                break
            } catch [System.IO.IOException] {
                if ($attempt -eq 0) { Start-Sleep -Milliseconds 15 } else { throw }
            }
        }
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

function Test-HookPayloadHasError {
    param($RawError)
    if ($null -eq $RawError) { return $false }
    if ($RawError -is [bool]) { return $RawError }
    if ($RawError -is [string]) { return (-not [string]::IsNullOrWhiteSpace($RawError)) }
    if ($RawError -is [System.Collections.IDictionary]) { return ($RawError.Count -gt 0) }
    if ($RawError -is [System.Collections.IEnumerable]) { return (@($RawError).Count -gt 0) }
    if ($RawError -is [PSCustomObject]) { return (@($RawError.PSObject.Properties).Count -gt 0) }
    return (-not [string]::IsNullOrWhiteSpace([string]$RawError))
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
    if ($p -match '^file:///([A-Za-z]:.*)$') {
        $p = $Matches[1]
    } elseif ($p -match '^file://(/.*)$') {
        $p = $Matches[1]
    }
    if ($p -match '^//[\.\?]/([A-Za-z]:.*)$') {
        $p = $Matches[1]
    }

    $prefix = ""
    $rest = $p
    if ($p -match '^([A-Za-z]:)(.*)$') {
        $prefix = $Matches[1].ToLowerInvariant() + "/"
        $rest = $Matches[2].TrimStart("/")
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

function Test-LexicalDenyPath {
    param([string]$NormPath)
    if ([string]::IsNullOrWhiteSpace($NormPath)) { return $false }

    $parts = $NormPath -split '/'
    $leaf = $parts[-1] -replace ':.*$', ''
    $parts[-1] = $leaf
    $normNoAds = $parts -join '/'

    if ($leaf -match '^\.env' -and $leaf -notin @('.env.example', '.env.sample', '.env.template')) {
        return $true
    }
    if ($leaf -match '\.(key|pem)$') {
        return $true
    }
    if ($normNoAds -match '(^|/)(\.ssh|\.aws|\.gnupg)(/|$)') {
        return $true
    }
    if ($normNoAds -match '(^|/)\.gemini/(?:antigravity[^/]*/)?mcp(/|$)') {
        return $true
    }
    if ($normNoAds -match '(^|/)\.gemini/(?:config/|antigravity[^/]*/)?mcp_config[^/]*\.json$') {
        return $true
    }
    return $false
}

function Test-DenyPath {
    param(
        [string]$RawPath,
        [int]$Depth = 0
    )
    if ($Depth -gt 8) { return $false }

    $norm = Get-NormalizedPath -RawPath $RawPath
    if ([string]::IsNullOrWhiteSpace($norm)) { return $false }
    if (Test-LexicalDenyPath -NormPath $norm) { return $true }

    $expanded = $RawPath.Trim().Trim('"', "'")
    $userHome = if ($env:USERPROFILE) { $env:USERPROFILE } elseif ($HOME) { $HOME } else { "" }
    if ($userHome -and $expanded -match '^(~|\$HOME|\$\{HOME\}|\$env:USERPROFILE|%USERPROFILE%)(?=[/\\]|$)') {
        $expanded = $userHome.TrimEnd('\', '/') + $expanded.Substring($Matches[1].Length)
    }
    if ($expanded -match '^file:///([A-Za-z]:.*)$') {
        $expanded = $Matches[1]
    } elseif ($expanded -match '^file://(/.*)$') {
        $expanded = $Matches[1]
    }
    $expanded = $expanded -replace '/', '\'
    if ($expanded -match '^\\\\[\.\?]\\([A-Za-z]:.*)$') {
        $expanded = $Matches[1]
    }

    $drivePart = ""
    $bodyPart = $expanded
    if ($expanded -match '^([A-Za-z]:)(.*)$') {
        $drivePart = $Matches[1]
        $bodyPart = $Matches[2]
    }
    $lastSlash = $bodyPart.LastIndexOf('\')
    if ($lastSlash -ge 0) {
        $expanded = $drivePart + $bodyPart.Substring(0, $lastSlash + 1) + ($bodyPart.Substring($lastSlash + 1) -replace ':.*$', '')
    } else {
        $expanded = $drivePart + ($bodyPart -replace ':.*$', '')
    }

    try {
        $fullProbe = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($expanded)
    } catch {
        return $false
    }
    $fullNorm = Get-NormalizedPath -RawPath $fullProbe
    if (Test-LexicalDenyPath -NormPath $fullNorm) { return $true }

    $probe = $fullProbe.TrimEnd('\', '/')
    if ($probe -match '^[A-Za-z]:$') { $probe += '\' }
    $suffixParts = New-Object System.Collections.Generic.List[string]
    while (-not [string]::IsNullOrWhiteSpace($probe)) {
        $item = Get-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
            $rawTargets = @()
            if ($item.PSObject.Properties['LinkTarget'] -and -not [string]::IsNullOrWhiteSpace([string]$item.LinkTarget)) {
                $rawTargets = @([string]$item.LinkTarget)
            } elseif ($item.PSObject.Properties['Target'] -and $null -ne $item.Target) {
                $rawTargets = @($item.Target | ForEach-Object { [string]$_ })
            }
            foreach ($lt in $rawTargets) {
                if ([string]::IsNullOrWhiteSpace($lt)) { continue }
                $resolvedTarget = $lt
                if (-not [System.IO.Path]::IsPathRooted($resolvedTarget)) {
                    $probeParent = Split-Path -Parent $probe
                    if ($probeParent) {
                        $resolvedTarget = Join-Path $probeParent $resolvedTarget
                    }
                }
                $candidate = $resolvedTarget
                if ($suffixParts.Count -gt 0) {
                    $rev = New-Object System.Collections.Generic.List[string]
                    for ($si = $suffixParts.Count - 1; $si -ge 0; $si--) {
                        $rev.Add($suffixParts[$si])
                    }
                    $candidate = Join-Path $candidate ($rev -join [System.IO.Path]::DirectorySeparatorChar)
                }
                if (Test-DenyPath -RawPath $candidate -Depth ($Depth + 1)) {
                    return $true
                }
            }
        }
        $parent = Split-Path -Parent $probe
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -eq $probe) { break }
        $leafName = Split-Path -Leaf $probe
        if (-not [string]::IsNullOrEmpty($leafName)) {
            $suffixParts.Add($leafName)
        }
        $probe = $parent
    }

    return $false
}

try {
    $rawInput = ""
    if ([Console]::IsInputRedirected) {
        $inStream = [Console]::OpenStandardInput()
        $reader = New-Object System.IO.StreamReader($inStream, [System.Text.UTF8Encoding]::new($false), $true, 4096, $true)
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

    $pathPropKeys = @("AbsolutePath", "TargetFile", "Path", "FilePath", "file_path", "target_file", "absolute_path", "path")

    if ($Event -eq "PostToolUse") {
        $rawError = Get-PropValue -Object $payload -Names @("error")
        if (-not (Test-HookPayloadHasError -RawError $rawError) -and $toolName -in @("write_to_file", "write_file", "create_file", "replace_file_content", "multi_replace_file_content", "edit_file")) {
            $rawTargetFile = [string](Get-PropValue -Object $toolArgs -Names $pathPropKeys)
            $targetFile = if ($null -ne $rawTargetFile) { $rawTargetFile.Trim() } else { "" }
            if (-not [string]::IsNullOrWhiteSpace($targetFile) -and ([System.IO.Path]::GetFileName($targetFile) -ieq 'gate2_handoff.md')) {
                if (Test-Path -LiteralPath $targetFile) {
                    $fileText = [System.IO.File]::ReadAllText($targetFile, [System.Text.Encoding]::UTF8)
                    if ($fileText.Contains("{{VERBATIM_GIT_DIFF}}") -or $fileText.Contains("{{VERBATIM_GIT_DIFFSTAT}}")) {
                        try {
                            $updateScript = Join-Path $PSScriptRoot "Update-Gate2Diff.ps1"
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
                                $global:LASTEXITCODE = 0
                                if ($repoArg) {
                                    & $updateScript -ArtifactPath $targetFile -RepoPath $repoArg 1>$null 3>$null 4>$null 5>$null 6>$null
                                } else {
                                    & $updateScript -ArtifactPath $targetFile 1>$null 3>$null 4>$null 5>$null 6>$null
                                }
                                if ($LASTEXITCODE -ne 0) {
                                    throw "Update-Gate2Diff.ps1 exited with code $LASTEXITCODE"
                                }
                            } finally {
                                $ErrorActionPreference = $prevEap
                            }
                        } catch {
                            $g4Err = $_.Exception.Message
                            Write-HookLog -Message "Event=PostToolUse Guard4 Update-Gate2Diff failed: $g4Err"
                            $banner = "[ERROR: Update-Gate2Diff.ps1 failed $([char]0x2014) $g4Err]"
                            $updatedText = $fileText.Replace("{{VERBATIM_GIT_DIFFSTAT}}", $banner).Replace("{{VERBATIM_GIT_DIFF}}", $banner)
                            [System.IO.File]::WriteAllText($targetFile, $updatedText, [System.Text.UTF8Encoding]::new($false))
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
            $safetyScript = Join-Path $PSScriptRoot "Test-PowerShellCommandSafety.ps1"
            if (-not (Test-Path -LiteralPath $safetyScript)) {
                Write-HookResponse @{ decision = "deny"; reason = "Security Hook Misconfiguration: Test-PowerShellCommandSafety.ps1 not found at $safetyScript" }
                exit 0
            }
            $global:LASTEXITCODE = 0
            $blocked = $false
            $blockMsg = ""
            try {
                $out = & $safetyScript -CommandLine ([string]$cmdLine) *>&1
                if ($LASTEXITCODE -ne 0) {
                    $blocked = $true
                    $blockMsg = (($out | ForEach-Object {
                        if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { "$_" }
                    }) -join "`n").Trim()
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

        { $_ -in @("view_file", "read_file", "replace_file_content", "multi_replace_file_content", "edit_file", "write_to_file", "write_file", "create_file") } {
            $rawPath = Get-PropValue -Object $toolArgs -Names $pathPropKeys
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
