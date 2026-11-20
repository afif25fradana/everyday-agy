# SecurityHooks.Tests.ps1
# Comprehensive Security Hook Router and Guard Test Suite
# Validates both Invoke-AntigravityHook.ps1 (PowerShell AST) and invoke-antigravity-hook.mjs (File Tools & Gate 2 Diff)

$ErrorActionPreference = "Continue"

$repoRoot = if ($PSScriptRoot) {
    Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
} else {
    (Get-Location).Path
}

$passed = 0
$failed = 0

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

$psHookScript = Join-Path (Join-Path (Join-Path $repoRoot "config") "scripts") "Invoke-AntigravityHook.ps1"
$nodeHookScript = Join-Path (Join-Path (Join-Path $repoRoot "config") "scripts") "invoke-antigravity-hook.mjs"

function Invoke-HookCli {
    param(
        [string]$EventName,
        [string]$JsonInput = "",
        [byte[]]$RawBytes = $null,
        [string]$WorkDir = "",
        [string]$HomeOverride = ""
    )
    if (-not (Test-Path -LiteralPath $psHookScript)) {
        return [PSCustomObject]@{
            MissingScript = $true
            ExitCode      = -1
            StdOut        = ""
            StdErr        = "Missing script: $psHookScript"
            SingleJson    = $false
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
    $psi.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$psHookScript`" -Event $EventName"
    $psi.WorkingDirectory = if ($WorkDir) { $WorkDir } else { Split-Path -Parent (Split-Path -Parent $psHookScript) }
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

function Invoke-NodeHookCli {
    param(
        [string]$EventName,
        [string]$JsonInput = "",
        [byte[]]$RawBytes = $null,
        [string]$WorkDir = "",
        [string]$HomeOverride = "",
        [switch]$UseEventFlag
    )
    if (-not (Test-Path -LiteralPath $nodeHookScript)) {
        return [PSCustomObject]@{
            MissingScript = $true
            ExitCode      = -1
            StdOut        = ""
            StdErr        = "Missing script: $nodeHookScript"
            SingleJson    = $false
            Parsed        = $null
        }
    }
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "node"
    $eventArg = if ($UseEventFlag) { "-Event $EventName" } else { "$EventName" }
    $psi.Arguments = "`"$nodeHookScript`" $eventArg"
    $psi.WorkingDirectory = if ($WorkDir) { $WorkDir } else { Split-Path -Parent (Split-Path -Parent $nodeHookScript) }
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
$hookTempDir = Join-Path ([System.IO.Path]::GetTempPath()) "agy_sechook_test_$hookTestId"
$isolatedHome = Join-Path $hookTempDir "home"
New-Item -ItemType Directory -Path $isolatedHome -Force | Out-Null

try {
    Write-Host "`n>>> [SECTION 1] Invoke-AntigravityHook.ps1 (PowerShell AST Guard 1 & Pass-Through)..." -ForegroundColor Cyan

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

    # Pass-through: invoke_subagent
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

    # PowerShell Router BOM stripping & Malformed JSON fallback
    $bomPayload = '{"toolCall":{"name":"run_command","args":{"CommandLine":"git status"}}}'
    $bomBytes = [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.UTF8Encoding]::new($false).GetBytes($bomPayload)
    $bomRes = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -RawBytes $bomBytes
    Assert-HookCondition -Name "PS Hook strips UTF-8 BOM from stdin JSON" -Condition ($bomRes.ExitCode -eq 0 -and $bomRes.SingleJson -and $bomRes.Parsed.decision -eq "allow") -Details "out=$($bomRes.StdOut)"

    $badJsonRes = Invoke-HookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput "{malformed json"
    $psLogFile = Join-Path $isolatedHome ".gemini/antigravity/scratch/hooks.log"
    Assert-HookCondition -Name "PS Hook: Malformed JSON degrades gracefully to decision=ask and logs error" -Condition ($badJsonRes.ExitCode -eq 0 -and $badJsonRes.SingleJson -and $badJsonRes.Parsed.decision -eq "ask" -and -not [string]::IsNullOrWhiteSpace($badJsonRes.Parsed.reason) -and (Test-Path -LiteralPath $psLogFile)) -Details "out=$($badJsonRes.StdOut) logExists=$(Test-Path -LiteralPath $psLogFile)"


    Write-Host "`n>>> [SECTION 2] invoke-antigravity-hook.mjs (Node.js File Tools Router & Guard 2)..." -ForegroundColor Cyan

    # Node CLI Argument parsing: Positional vs -Event flag
    $posRes = Invoke-NodeHookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput '{"toolCall":{"name":"view_file","args":{"AbsolutePath":"D:\\repo\\src\\index.ts"}}}'
    Assert-HookCondition -Name "Node Hook: Positional Event argument (PreToolUse) accepted" -Condition ($posRes.ExitCode -eq 0 -and $posRes.SingleJson -and $posRes.Parsed.decision -eq "allow") -Details "out=$($posRes.StdOut) err=$($posRes.StdErr)"

    $flagRes = Invoke-NodeHookCli -EventName "PreToolUse" -UseEventFlag -HomeOverride $isolatedHome -JsonInput '{"toolCall":{"name":"view_file","args":{"AbsolutePath":"D:\\repo\\src\\index.ts"}}}'
    Assert-HookCondition -Name "Node Hook: -Event flag argument (-Event PreToolUse) accepted" -Condition ($flagRes.ExitCode -eq 0 -and $flagRes.SingleJson -and $flagRes.Parsed.decision -eq "allow") -Details "out=$($flagRes.StdOut) err=$($flagRes.StdErr)"

    # Node Hook UTF-8 BOM stripping
    $nodeBomRes = Invoke-NodeHookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -RawBytes $bomBytes
    Assert-HookCondition -Name "Node Hook strips UTF-8 BOM from stdin JSON" -Condition ($nodeBomRes.ExitCode -eq 0 -and $nodeBomRes.SingleJson -and $nodeBomRes.Parsed.decision -eq "allow") -Details "out=$($nodeBomRes.StdOut)"

    # Node Hook malformed JSON fallback
    $nodeBadJson = Invoke-NodeHookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput "{bad json payload"
    Assert-HookCondition -Name "Node Hook: Malformed JSON degrades to decision=ask in PreToolUse" -Condition ($nodeBadJson.ExitCode -eq 0 -and $nodeBadJson.SingleJson -and $nodeBadJson.Parsed.decision -eq "ask") -Details "out=$($nodeBadJson.StdOut)"

    $nodeBadPost = Invoke-NodeHookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -JsonInput "{bad json payload"
    Assert-HookCondition -Name "Node Hook: Malformed JSON in PostToolUse emits strictly {}" -Condition ($nodeBadPost.ExitCode -eq 0 -and $nodeBadPost.StdOut.Trim() -eq "{}") -Details "out=$($nodeBadPost.StdOut)"

    # Guard 2 Comprehensive Lexical & Canonical Matrix
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
        @{ Tool = "write_to_file"; Key = "TargetFile"; Path = "D:\\repo\\src\\index.ts"; Expected = "allow"; Label = "Normal source write allowed regardless of role" },
        @{ Tool = "read_file"; Key = "Path"; Path = "~/.gemini/config/mcp_config.json"; Expected = "deny"; Label = "read_file on ~/.gemini/config/mcp_config.json" },
        @{ Tool = "write_file"; Key = "file_path"; Path = "~/.gemini/antigravity/mcp_config.json"; Expected = "deny"; Label = "write_file on ~/.gemini/antigravity/mcp_config.json" },
        @{ Tool = "edit_file"; Key = "Path"; Path = "C:.env"; Expected = "deny"; Label = "edit_file on drive-relative C:.env" },
        @{ Tool = "create_file"; Key = "TargetFile"; Path = "C:\\repo\\private.key:stream:`$DATA"; Expected = "deny"; Label = "create_file on multi-colon NTFS ADS private.key:stream:`$DATA" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "C:\\repo\\.env.example::`$DATA"; Expected = "allow"; Label = "view_file on .env.example ADS exception" },
        @{ Tool = "read_file"; Key = "file_path"; Path = "file:///C:/Users/Alice/.ssh/id_rsa"; Expected = "deny"; Label = "read_file on file:/// URI to .ssh" },
        @{ Tool = "write_file"; Key = "Path"; Path = "D:\\repo\\tdd-guide\\feature.ts"; Expected = "allow"; Label = "write_file allowed for non-secret tdd-guide path" },
        @{ Tool = "edit_file"; Key = "Path"; Path = "D:\\repo\\DISPATCH.md"; Expected = "allow"; Label = "edit_file allowed for non-secret teamwork artifact" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "C:\\"; Expected = "allow"; Label = "Windows root C:\ exits ancestor loop cleanly" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "/"; Expected = "allow"; Label = "POSIX root / exits ancestor loop cleanly" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "C:\\repo\\bad|dir\\app.ts"; Expected = "allow"; Label = "Non-existent path with illegal Win32 char does not trigger fallback error" },
        @{ Tool = "read_file"; Key = "Path"; Path = "C:\\repo\\secret.pem."; Expected = "deny"; Label = "Win32 trailing period bypass secret.pem." },
        @{ Tool = "edit_file"; Key = "Path"; Path = "C:\\repo\\.gemini\\config\\mcp_config.json "; Expected = "deny"; Label = "Win32 trailing space bypass mcp_config.json " },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "~/.gemini/antigravity/mcp_oauth_tokens.json"; Expected = "deny"; Label = "view_file on ~/.gemini/antigravity/mcp_oauth_tokens.json" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = "~/.gemini/antigravity/mcp_oauth_tokens_v2.json"; Expected = "deny"; Label = "view_file on ~/.gemini/antigravity/mcp_oauth_tokens_v2.json" },
        @{ Tool = "read_file"; Key = "Path"; Path = "D:\\repo\\.agents\\mcp_config.json"; Expected = "deny"; Label = "read_file on workspace .agents/mcp_config.json" },
        @{ Tool = "write_file"; Key = "Path"; Path = "D:\\repo\\.agents\\mcp_config.local.json"; Expected = "deny"; Label = "write_file on workspace .agents/mcp_config.local.json" },
        @{ Tool = "grep_search"; Key = "SearchPath"; Path = "~/.ssh"; Expected = "deny"; Label = "grep_search targeting ~/.ssh" },
        @{ Tool = "grep_search"; Key = "search_path"; Path = "C:\\repo\\.env"; Expected = "deny"; Label = "grep_search targeting .env" },
        @{ Tool = "grep_search"; Key = "SearchPath"; Path = "D:\\repo\\src"; Expected = "allow"; Label = "grep_search targeting normal src" },
        @{ Tool = "apply_diff"; Key = "Path"; Path = "C:\\repo\\.env"; Expected = "deny"; Label = "apply_diff targeting .env" },
        @{ Tool = "apply_diff"; Key = "Path"; Path = "D:\\repo\\src\\app.ts"; Expected = "allow"; Label = "apply_diff targeting normal source" }
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
        $res = Invoke-NodeHookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput $jsonPayload
        Assert-HookCondition -Name "Node Guard 2 ($($g2.Tool)): $($g2.Label) -> $($g2.Expected)" -Condition ($res.ExitCode -eq 0 -and $res.SingleJson -and $res.Parsed.decision -eq $g2.Expected) -Details "out=$($res.StdOut)"
    }

    # Node Guard 2: grep_search with omitted SearchPath defaults to "."
    $grepDefaultPayload = '{"toolCall":{"name":"grep_search","args":{}}}'
    $grepDefaultRes = Invoke-NodeHookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput $grepDefaultPayload
    Assert-HookCondition -Name "Node Guard 2 (grep_search): Omitted SearchPath defaults to '.' and evaluates safely" -Condition ($grepDefaultRes.ExitCode -eq 0 -and $grepDefaultRes.SingleJson -and $grepDefaultRes.Parsed.decision -eq "allow") -Details "out=$($grepDefaultRes.StdOut)"

    # Node Guard 2: Missing target path on file tools returns decision=ask
    $missingPathPayload = '{"toolCall":{"name":"view_file","args":{}}}'
    $missingPathRes = Invoke-NodeHookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput $missingPathPayload
    Assert-HookCondition -Name "Node Guard 2: Missing target file path degrades to decision=ask" -Condition ($missingPathRes.ExitCode -eq 0 -and $missingPathRes.SingleJson -and $missingPathRes.Parsed.decision -eq "ask" -and $missingPathRes.Parsed.reason -match 'Missing target file path') -Details "out=$($missingPathRes.StdOut)"

    # Guard 2 ReparsePoint (NTFS junction & Symlink Ancestor Walk) tests
    $juncStage = Join-Path $hookTempDir "junc_stage"
    $secretOrigin = Join-Path $juncStage "secret_origin"
    $secretSsh = Join-Path $secretOrigin ".ssh"
    $normalOrigin = Join-Path $juncStage "normal_origin"
    $safeLinks = Join-Path $juncStage "safe_links"
    New-Item -ItemType Directory -Path $secretSsh, $normalOrigin, $safeLinks -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $secretSsh "id_rsa") -Value "PRIVATE" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $normalOrigin "app.ts") -Value "export const ok = true;" -Encoding utf8

    $bracketDir = Join-Path $safeLinks "dir[1]"
    New-Item -ItemType Directory -Path $bracketDir -Force | Out-Null
    $leafJunc = Join-Path $safeLinks "junc_ssh"
    $rootJunc = Join-Path $safeLinks "junc_root"
    $normalJunc = Join-Path $safeLinks "junc_normal"
    $bracketJunc = Join-Path $bracketDir "junc_ssh"
    $relSshLink = Join-Path $safeLinks "rel_ssh"
    $linkType = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { "Junction" } else { "SymbolicLink" }
    $null = New-Item -ItemType $linkType -Path $leafJunc -Target $secretSsh -ErrorAction Stop
    $null = New-Item -ItemType $linkType -Path $rootJunc -Target $secretOrigin -ErrorAction Stop
    $null = New-Item -ItemType $linkType -Path $normalJunc -Target $normalOrigin -ErrorAction Stop
    $null = New-Item -ItemType $linkType -Path $bracketJunc -Target $secretSsh -ErrorAction Stop

    $nodeJuncCases = @(
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = (Join-Path $leafJunc "id_rsa"); Expected = "deny"; Label = "Leaf junction pointing to .ssh/id_rsa" },
        @{ Tool = "view_file"; Key = "AbsolutePath"; Path = (Join-Path $bracketJunc "id_rsa"); Expected = "deny"; Label = "Junction inside [1] bracketed folder pointing to .ssh/id_rsa" },
        @{ Tool = "write_file"; Key = "Path"; Path = (Join-Path (Join-Path $rootJunc ".ssh") "brand_new_key.txt"); Expected = "deny"; Label = "Non-existent write under ancestor junction to .ssh" },
        @{ Tool = "write_file"; Key = "Path"; Path = (Join-Path (Join-Path $leafJunc "nested") "brand_new_key.txt"); Expected = "deny"; Label = "Non-existent nested write under leaf .ssh junction" },
        @{ Tool = "read_file"; Key = "Path"; Path = (Join-Path $normalJunc "app.ts"); Expected = "allow"; Label = "Benign junction to normal directory allowed" }
    )
    if ([System.IO.Path]::DirectorySeparatorChar -eq '/') {
        $null = New-Item -ItemType SymbolicLink -Path $relSshLink -Target "../secret_origin/.ssh" -ErrorAction Stop
        $mixedPath = ($leafJunc -replace '/', '\') + '\id_rsa'
        $nodeJuncCases += @(
            @{ Tool = "view_file"; Key = "AbsolutePath"; Path = (Join-Path $relSshLink "id_rsa"); Expected = "deny"; Label = "Relative POSIX symlink pointing to ../.ssh/id_rsa" },
            @{ Tool = "view_file"; Key = "AbsolutePath"; Path = $mixedPath; Expected = "deny"; Label = "Mixed backslash path through POSIX symlink to .ssh/id_rsa" }
        )
    }
    foreach ($jc in $nodeJuncCases) {
        $jPayload = @{ toolCall = @{ name = $jc.Tool; args = @{ $jc.Key = $jc.Path } } } | ConvertTo-Json -Depth 5 -Compress
        $jRes = Invoke-NodeHookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput $jPayload
        Assert-HookCondition -Name "Node Guard 2 ReparsePoint ($($jc.Tool)): $($jc.Label) -> $($jc.Expected)" -Condition ($jRes.ExitCode -eq 0 -and $jRes.SingleJson -and $jRes.Parsed.decision -eq $jc.Expected) -Details "out=$($jRes.StdOut)"
    }

    # Guard 2 Fail-Closed on Junction Depth > 8
    $deepDirA = Join-Path $juncStage "deepA"
    $deepDirB = Join-Path $juncStage "deepB"
    New-Item -ItemType Directory -Path $deepDirA, $deepDirB -Force | Out-Null
    $deepLinkA = Join-Path $deepDirA "linkB"
    $deepLinkB = Join-Path $deepDirB "linkA"
    $null = New-Item -ItemType $linkType -Path $deepLinkA -Target $deepDirB -Force -ErrorAction Stop
    $null = New-Item -ItemType $linkType -Path $deepLinkB -Target $deepDirA -Force -ErrorAction Stop
    $deepPath = Join-Path $deepDirA "linkB/linkA/linkB/linkA/linkB/linkA/linkB/linkA/linkB/file.txt"
    $deepPayload = @{ toolCall = @{ name = "read_file"; args = @{ Path = $deepPath } } } | ConvertTo-Json -Depth 5 -Compress
    $deepRes = Invoke-NodeHookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput $deepPayload
    Assert-HookCondition -Name "Node Guard 2: Cyclic/excessive reparse depth (> 8) fails closed with deny" -Condition ($deepRes.ExitCode -eq 0 -and $deepRes.SingleJson -and $deepRes.Parsed.decision -eq "deny") -Details "out=$($deepRes.StdOut)"


    Write-Host "`n>>> [SECTION 3] Guard 4 (Node.js PostToolUse Diff Injection & Update-Gate2Diff)..." -ForegroundColor Cyan

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
    $g4Res = Invoke-NodeHookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -WorkDir $postRepo -JsonInput (@{
        workspacePaths = @($postRepo)
        toolCall = @{
            name = "write_to_file"
            args = @{
                TargetFile = $gate2File
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    $g4Text = [System.IO.File]::ReadAllText($gate2File, [System.Text.Encoding]::UTF8)
    Assert-HookCondition -Name "Node Guard 4 injects git diff into gate2_handoff.md and emits strictly {}" -Condition ($g4Res.ExitCode -eq 0 -and $g4Res.StdOut.Trim() -eq "{}" -and $g4Text.Contains("line2_hook_test") -and (-not $g4Text.Contains("{{VERBATIM_GIT_DIFF}}"))) -Details "out=$($g4Res.StdOut)"

    $gate2ErrFile = Join-Path $postArtifactDir "err_dir/gate2_handoff.md"
    New-Item -ItemType Directory -Path (Split-Path -Parent $gate2ErrFile) -Force | Out-Null
    [System.IO.File]::WriteAllText($gate2ErrFile, "{{VERBATIM_GIT_DIFF}}", [System.Text.UTF8Encoding]::new($false))
    $g4ErrRes = Invoke-NodeHookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -WorkDir $postRepo -JsonInput (@{
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
    Assert-HookCondition -Name "Node Guard 4 skips diff injection when PostToolUse error is non-empty" -Condition ($g4ErrRes.ExitCode -eq 0 -and $g4ErrRes.StdOut.Trim() -eq "{}" -and $g4ErrText.Contains("{{VERBATIM_GIT_DIFF}}")) -Details "out=$($g4ErrRes.StdOut)"

    $nonGate2File = Join-Path $postArtifactDir "foo_gate2_handoff.md"
    [System.IO.File]::WriteAllText($nonGate2File, "{{VERBATIM_GIT_DIFF}}", [System.Text.UTF8Encoding]::new($false))
    $g4SuffixRes = Invoke-NodeHookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -WorkDir $postRepo -JsonInput (@{
        workspacePaths = @($postRepo)
        toolCall = @{
            name = "write_to_file"
            args = @{
                TargetFile = $nonGate2File
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    $g4SuffixText = [System.IO.File]::ReadAllText($nonGate2File, [System.Text.Encoding]::UTF8)
    Assert-HookCondition -Name "Node Guard 4 does not inject diff into foo_gate2_handoff.md" -Condition ($g4SuffixRes.ExitCode -eq 0 -and $g4SuffixRes.StdOut.Trim() -eq "{}" -and $g4SuffixText.Contains("{{VERBATIM_GIT_DIFF}}") -and (-not $g4SuffixText.Contains("line2_hook_test"))) -Details "out=$($g4SuffixRes.StdOut) text=$g4SuffixText"

    # Node Guard 4 with canonical tools write_file, edit_file, apply_diff
    $g4WriteFileDir = Join-Path $postArtifactDir "write_file_dir"
    New-Item -ItemType Directory -Path $g4WriteFileDir -Force | Out-Null
    $g4WriteFilePath = Join-Path $g4WriteFileDir "gate2_handoff.md"
    [System.IO.File]::WriteAllText($g4WriteFilePath, $gate2Template, [System.Text.UTF8Encoding]::new($false))
    $g4WriteFileRes = Invoke-NodeHookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -WorkDir $postRepo -JsonInput (@{
        workspacePaths = @($postRepo)
        error = $false
        toolCall = @{
            name = "write_file"
            args = @{
                Path = "  $g4WriteFilePath  "
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    $g4WriteFileText = [System.IO.File]::ReadAllText($g4WriteFilePath, [System.Text.Encoding]::UTF8)
    Assert-HookCondition -Name "Node Guard 4 injects diff for write_file with trimmed Path and error=false" -Condition ($g4WriteFileRes.ExitCode -eq 0 -and $g4WriteFileRes.StdOut.Trim() -eq "{}" -and $g4WriteFileText.Contains("line2_hook_test") -and (-not $g4WriteFileText.Contains("{{VERBATIM_GIT_DIFF}}"))) -Details "out=$($g4WriteFileRes.StdOut)"

    $g4EditFileDir = Join-Path $postArtifactDir "edit_file_dir"
    New-Item -ItemType Directory -Path $g4EditFileDir -Force | Out-Null
    $g4EditFilePath = Join-Path $g4EditFileDir "gate2_handoff.md"
    [System.IO.File]::WriteAllText($g4EditFilePath, $gate2Template, [System.Text.UTF8Encoding]::new($false))
    $g4EditFileRes = Invoke-NodeHookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -WorkDir $postRepo -JsonInput (@{
        workspacePaths = @($postRepo)
        error = @{}
        toolCall = @{
            name = "edit_file"
            args = @{
                file_path = $g4EditFilePath
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    $g4EditFileText = [System.IO.File]::ReadAllText($g4EditFilePath, [System.Text.Encoding]::UTF8)
    Assert-HookCondition -Name "Node Guard 4 injects diff for edit_file with snake_case file_path and empty error object" -Condition ($g4EditFileRes.ExitCode -eq 0 -and $g4EditFileRes.StdOut.Trim() -eq "{}" -and $g4EditFileText.Contains("line2_hook_test") -and (-not $g4EditFileText.Contains("{{VERBATIM_GIT_DIFF}}"))) -Details "out=$($g4EditFileRes.StdOut)"

    $g4ApplyDiffDir = Join-Path $postArtifactDir "apply_diff_dir"
    New-Item -ItemType Directory -Path $g4ApplyDiffDir -Force | Out-Null
    $g4ApplyDiffPath = Join-Path $g4ApplyDiffDir "gate2_handoff.md"
    [System.IO.File]::WriteAllText($g4ApplyDiffPath, $gate2Template, [System.Text.UTF8Encoding]::new($false))
    $g4ApplyDiffRes = Invoke-NodeHookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -WorkDir $postRepo -JsonInput (@{
        workspacePaths = @($postRepo)
        toolCall = @{
            name = "apply_diff"
            args = @{
                Path = $g4ApplyDiffPath
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    $g4ApplyDiffText = [System.IO.File]::ReadAllText($g4ApplyDiffPath, [System.Text.Encoding]::UTF8)
    Assert-HookCondition -Name "Node Guard 4 injects diff for apply_diff" -Condition ($g4ApplyDiffRes.ExitCode -eq 0 -and $g4ApplyDiffRes.StdOut.Trim() -eq "{}" -and $g4ApplyDiffText.Contains("line2_hook_test") -and (-not $g4ApplyDiffText.Contains("{{VERBATIM_GIT_DIFF}}"))) -Details "out=$($g4ApplyDiffRes.StdOut)"

    $g4MultiDir = Join-Path $postArtifactDir "multi_replace_dir"
    New-Item -ItemType Directory -Path $g4MultiDir -Force | Out-Null
    $g4MultiPath = Join-Path $g4MultiDir "gate2_handoff.md"
    [System.IO.File]::WriteAllText($g4MultiPath, $gate2Template, [System.Text.UTF8Encoding]::new($false))
    $g4MultiRes = Invoke-NodeHookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -WorkDir $postRepo -JsonInput (@{
        workspacePaths = @($postRepo)
        toolCall = @{
            name = "multi_replace_file_content"
            args = @{
                Path = $g4MultiPath
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    $g4MultiText = [System.IO.File]::ReadAllText($g4MultiPath, [System.Text.Encoding]::UTF8)
    Assert-HookCondition -Name "Node Guard 4 injects diff for multi_replace_file_content" -Condition ($g4MultiRes.ExitCode -eq 0 -and $g4MultiRes.StdOut.Trim() -eq "{}" -and $g4MultiText.Contains("line2_hook_test") -and (-not $g4MultiText.Contains("{{VERBATIM_GIT_DIFF}}"))) -Details "out=$($g4MultiRes.StdOut)"

    $g4BinOverrideDir = Join-Path $postArtifactDir "bin_override_dir"
    New-Item -ItemType Directory -Path $g4BinOverrideDir -Force | Out-Null
    $g4BinOverridePath = Join-Path $g4BinOverrideDir "gate2_handoff.md"
    [System.IO.File]::WriteAllText($g4BinOverridePath, $gate2Template, [System.Text.UTF8Encoding]::new($false))
    $prevPsBin = $env:POWERSHELL_BIN
    try {
        $env:POWERSHELL_BIN = if ($PSVersionTable.PSEdition -eq "Core") { (Get-Process -Id $PID).Path } else { Join-Path $PSHOME "powershell.exe" }
        $g4BinRes = Invoke-NodeHookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -WorkDir $postRepo -JsonInput (@{
            workspacePaths = @($postRepo)
            toolCall = @{
                name = "write_file"
                args = @{
                    Path = $g4BinOverridePath
                }
            }
        } | ConvertTo-Json -Depth 6 -Compress)
        $g4BinText = [System.IO.File]::ReadAllText($g4BinOverridePath, [System.Text.Encoding]::UTF8)
        Assert-HookCondition -Name "Node Guard 4 respects POWERSHELL_BIN environment override" -Condition ($g4BinRes.ExitCode -eq 0 -and $g4BinRes.StdOut.Trim() -eq "{}" -and $g4BinText.Contains("line2_hook_test") -and (-not $g4BinText.Contains("{{VERBATIM_GIT_DIFF}}"))) -Details "out=$($g4BinRes.StdOut)"
    } finally {
        $env:POWERSHELL_BIN = $prevPsBin
    }

    # Node Guard 4 surfaces failure cleanly in gate2_handoff.md and hooks.log while emitting {}
    $nonGitHookDir = Join-Path $hookTempDir "non_git_hook_dir"
    $g4FailDir = Join-Path $postArtifactDir "g4_fail_dir"
    New-Item -ItemType Directory -Path $nonGitHookDir, $g4FailDir -Force | Out-Null
    $g4FailFile = Join-Path $g4FailDir "gate2_handoff.md"
    [System.IO.File]::WriteAllText($g4FailFile, $gate2Template, [System.Text.UTF8Encoding]::new($false))
    $g4FailRes = Invoke-NodeHookCli -EventName "PostToolUse" -HomeOverride $isolatedHome -WorkDir $nonGitHookDir -JsonInput (@{
        workspacePaths = @($nonGitHookDir)
        toolCall = @{
            name = "create_file"
            args = @{
                TargetFile = $g4FailFile
            }
        }
    } | ConvertTo-Json -Depth 6 -Compress)
    $g4FailText = [System.IO.File]::ReadAllText($g4FailFile, [System.Text.Encoding]::UTF8)
    $nodeLogPath = Join-Path $isolatedHome ".gemini/antigravity/scratch/hooks.log"
    $nodeLogText = if (Test-Path -LiteralPath $nodeLogPath) { [System.IO.File]::ReadAllText($nodeLogPath, [System.Text.Encoding]::UTF8) } else { "" }
    Assert-HookCondition -Name "Node Guard 4 surfaces Update-Gate2Diff failure in gate2_handoff.md and hooks.log while emitting {}" -Condition ($g4FailRes.ExitCode -eq 0 -and $g4FailRes.StdOut.Trim() -eq "{}" -and ($g4FailText -match '\[ERROR: Update-Gate2Diff\.ps1 failed') -and (-not $g4FailText.Contains("{{VERBATIM_GIT_DIFF}}")) -and ($nodeLogText -match 'Guard4 Update-Gate2Diff failed')) -Details "out=$($g4FailRes.StdOut) text=$g4FailText"

    # Node Hook 5 MB bounded log check
    if (Test-Path -LiteralPath (Split-Path -Parent $nodeLogPath)) {
        $oversizeChunk = ("x" * 1023) + "`n"
        $sw = [System.IO.StreamWriter]::new($nodeLogPath, $false, [System.Text.UTF8Encoding]::new($false))
        try {
            for ($k = 0; $k -lt 5300; $k++) { $sw.Write($oversizeChunk) }
        } finally {
            $sw.Dispose()
        }
        $null = Invoke-NodeHookCli -EventName "PreToolUse" -HomeOverride $isolatedHome -JsonInput "{still malformed"
        $finalLogLen = (Get-Item -LiteralPath $nodeLogPath).Length
        Assert-HookCondition -Name "Node Hook hooks.log stays bounded <= 5 MB after rotation/truncation" -Condition ($finalLogLen -le (5 * 1024 * 1024) -and $finalLogLen -gt 0) -Details "len=$finalLogLen"
    } else {
        Assert-HookCondition -Name "Node Hook hooks.log stays bounded <= 5 MB after rotation/truncation" -Condition $false -Details "Scratch log dir missing"
    }
} finally {
    foreach ($jp in @($leafJunc, $rootJunc, $normalJunc, $bracketJunc, $relSshLink, $deepLinkA, $deepLinkB)) {
        if ($jp -and (Test-Path -LiteralPath $jp)) {
            try { [System.IO.Directory]::Delete($jp, $false) } catch {}
        }
    }
    if (Test-Path -LiteralPath $hookTempDir) {
        Remove-Item -LiteralPath $hookTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$statusColor = if ($failed -eq 0) { "Green" } else { "Red" }
Write-Host "`n>>> SecurityHooks Results: $passed Passed, $failed Failed." -ForegroundColor $statusColor

if ($failed -gt 0) {
    exit 1
}

exit 0
