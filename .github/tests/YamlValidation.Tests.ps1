# YamlValidation.Tests.ps1
# Comprehensive YAML Syntax, Frontmatter & Schema Verification Suite
# Compatible with Windows PowerShell 5.1 and PowerShell Core 7.x (Ubuntu + Windows)

$ErrorActionPreference = "Stop"

$repoRoot = if ($PSScriptRoot) {
    Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
} else {
    (Get-Location).Path
}

$testsRun = 0
$testsPassed = 0
$testsFailed = 0

function Assert-Test {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$Details = ""
    )
    $script:testsRun++
    if ($Condition) {
        $script:testsPassed++
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        $script:testsFailed++
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Details) {
            Write-Host "         Details: $Details" -ForegroundColor Yellow
        }
    }
}

function Test-YamlBlockSyntax {
    param(
        [string]$Content,
        [string]$FilePath = ""
    )

    $lines = ($Content -replace "`r`n", "`n") -split "`n"
    $scopes = @{} # depth -> hashtable of seen keys
    $inBlockScalar = $false
    $blockScalarIndent = -1

    for ($i = 0; $i -lt $lines.Length; $i++) {
        $lineNum = $i + 1
        $line = $lines[$i]

        # 1. Reject Tabs in indentation
        if ($line -match '^[ ]*\t') {
            return @{ Success = $false; Error = "Line ${lineNum} contains tab indentation (\t). YAML strictly forbids tabs." }
        }

        # Calculate indentation
        $lineIndent = 0
        if ($line -match '^( +)') {
            $lineIndent = $Matches[1].Length
        }

        # Handle Block Scalar State (| or >)
        if ($inBlockScalar) {
            # Empty or whitespace-only lines continue the block scalar
            if ($line -match '^\s*$') {
                continue
            }
            # Lines indented deeper than the block scalar parent stay inside scalar
            if ($lineIndent -gt $blockScalarIndent) {
                continue
            }
            # Indentation returned to parent level or less -> exit block scalar
            $inBlockScalar = $false
            $blockScalarIndent = -1
        }

        # Skip empty lines and comments
        if ($line -match '^\s*$' -or $line -match '^\s*#') { continue }

        # Clear scopes deeper than current indentation
        $depthsToRemove = @($scopes.Keys | Where-Object { $_ -gt $lineIndent })
        foreach ($d in $depthsToRemove) { $scopes.Remove($d) }

        $trimmed = $line.Trim()
        $scopeDepth = $lineIndent

        # If line starts a list item (- key: val or - val), handle item
        if ($trimmed -match '^(-\s*)(.*)$') {
            $scopeDepth = $lineIndent + $Matches[1].Length
            $scopes[$scopeDepth] = @{}
            $trimmed = $Matches[2].Trim()
        }

        # 2. Check Key-Value Pairs
        if ($trimmed -match '^([''"][^''"]+[''"]|[A-Za-z0-9_./-]+):(?:\s+(.*)|\s*)$') {
            $key = $Matches[1]
            $val = ([string]$Matches[2]).Trim()

            if (-not $scopes.ContainsKey($scopeDepth)) {
                $scopes[$scopeDepth] = @{}
            }

            if ($scopes[$scopeDepth].ContainsKey($key)) {
                return @{ Success = $false; Error = "Line ${lineNum}: Duplicate key '$key' detected in mapping scope." }
            }
            $scopes[$scopeDepth][$key] = $true

            # Check for Block Scalar indicator (| or > with optional chomp + / -)
            if ($val -match '^[>|][+-]?\s*(?:#.*)?$') {
                $inBlockScalar = $true
                $blockScalarIndent = $scopeDepth
                continue
            }

            # 3. Check Unquoted Colons in Scalar Values (skip flow mappings, arrays, or quoted strings)
            $val = $val -replace '^("[^"]*"|''[^'']*'')\s+#.*$', '$1'
            if ($val -and $val -notmatch '^\[.*\]$' -and $val -notmatch '^\{.*\}$') {
                $isQuoted = ($val -match '^".*"$' -or $val -match "^'.*'$")
                if (-not $isQuoted -and $val -match ':\s') {
                    return @{ Success = $false; Error = "Line ${lineNum}: Unquoted scalar value contains ': ' sequence: '$val'. Must be quoted or folded." }
                }

                # 4. Check Unbalanced Quotes
                if (($val.StartsWith('"') -and -not $val.EndsWith('"')) -or ($val.StartsWith("'") -and -not $val.EndsWith("'"))) {
                    return @{ Success = $false; Error = "Line ${lineNum}: Unbalanced quotes in scalar value: '$val'" }
                }
            }
        }
    }

    return @{ Success = $true; Error = "" }
}

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  Running YAML Syntax & Schema Validation Suite   " -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# ---------------------------------------------------------
# Part 1: Pure YAML Files (.github/**/*.yml)
# ---------------------------------------------------------
Write-Host "`n[1] Validating Pure YAML Files (.github/**/*.yml)..." -ForegroundColor White
$yamlFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot ".github") -Recurse -File | Where-Object { $_.Extension -in @(".yml", ".yaml") })
Assert-Test -Name "Pure YAML files discovered under .github/" -Condition ($yamlFiles.Count -ge 1) -Details "No .yml/.yaml files found under .github"

foreach ($f in $yamlFiles) {
    $content = Get-Content -LiteralPath $f.FullName -Raw -Encoding utf8
    $syntaxResult = Test-YamlBlockSyntax -Content $content -FilePath $f.FullName
    Assert-Test -Name "Pure YAML Syntax: $($f.Name)" -Condition ($syntaxResult.Success) -Details ($syntaxResult.Error)
}

# ---------------------------------------------------------
# Part 2: Custom Agent Frontmatter (config/agents/*/agent.md)
# ---------------------------------------------------------
Write-Host "`n[2] Validating Custom Agent Frontmatter..." -ForegroundColor White
$agents = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "config/agents") -Directory)
Assert-Test -Name "Custom agent directories discovered under config/agents" -Condition ($agents.Count -ge 1) -Details "No agent directories found under config/agents"

foreach ($a in $agents) {
    $agentFile = Join-Path $a.FullName "agent.md"
    if (-not (Test-Path -LiteralPath $agentFile)) {
        Assert-Test -Name "Agent manifest exists ($($a.Name))" -Condition $false -Details "Missing agent.md"
        continue
    }

    $raw = Get-Content -LiteralPath $agentFile -Raw -Encoding utf8
    $clean = $raw.TrimStart([char]0xFEFF)

    # Validate delimiter bounds (CRLF & LF safe)
    $hasFrontmatter = ($clean -match '(?s)^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)')
    Assert-Test -Name "Agent frontmatter delimiters ($($a.Name))" -Condition $hasFrontmatter -Details "Missing or invalid '---' bounds"

    if ($hasFrontmatter) {
        $frontmatter = $Matches[1]
        $syntaxResult = Test-YamlBlockSyntax -Content $frontmatter -FilePath $agentFile
        Assert-Test -Name "Agent frontmatter syntax ($($a.Name))" -Condition ($syntaxResult.Success) -Details ($syntaxResult.Error)

        # Validate Schema Invariants
        $hasName = ($frontmatter -match '(?m)^name:\s+' + [regex]::Escape($a.Name) + '\s*$')
        $hasDesc = ($frontmatter -match '(?m)^description:\s+\S+')
        $hasModel = ($frontmatter -match '(?m)^model:\s+(inherit|flash)\s*$')
        $hasTools = ($frontmatter -match '(?m)^tools:\s*$' -and $frontmatter -match '(?m)^\s*-\s+\w+')
        $hasSubagent = ($frontmatter -match '(?m)^subagent:\s+true\s*$')
        $hasMainAgentFalse = ($frontmatter -match '(?m)^mainAgent:\s+false\s*$')
        $hasAskQuestion = ($frontmatter -match '(?m)^\s*-\s*ask_question\b')
        $hasCallMcpTool = ($frontmatter -match '(?m)^\s*-\s*call_mcp_tool\b')

        Assert-Test -Name "Agent schema requirements ($($a.Name))" -Condition ($hasName -and $hasDesc -and $hasModel -and $hasTools -and $hasSubagent) -Details "Failed name/desc/model/tools/subagent validation"
        Assert-Test -Name "Pure subagent property mainAgent: false ($($a.Name))" -Condition $hasMainAgentFalse -Details "Subagents must declare mainAgent: false"
        Assert-Test -Name "Interactive tool ask_question absent ($($a.Name))" -Condition (-not $hasAskQuestion) -Details "Subagents must not declare interactive tool ask_question"
        Assert-Test -Name "Invalid subagent tool call_mcp_tool absent ($($a.Name))" -Condition (-not $hasCallMcpTool) -Details "Subagents must use inheritMcp: true instead of call_mcp_tool in tools"

        # Security Invariant: build-error-resolver must not possess write_to_file
        if ($a.Name -eq "build-error-resolver") {
            $hasWriteTool = ($frontmatter -match '(?m)^\s*-\s*write_to_file\b')
            Assert-Test -Name "Security Invariant: build-error-resolver lacks write_to_file" -Condition (-not $hasWriteTool) -Details "build-error-resolver must not have write_to_file"
        }
    }
}

# ---------------------------------------------------------
# Part 3: Bundled Skills Frontmatter (config/skills/*/SKILL.md)
# ---------------------------------------------------------
Write-Host "`n[3] Validating Bundled Skill Frontmatter..." -ForegroundColor White
$skills = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot "config/skills") -Filter "SKILL.md" -Recurse)
Assert-Test -Name "Bundled skill manifests discovered under config/skills" -Condition ($skills.Count -ge 1) -Details "No SKILL.md files found under config/skills"

foreach ($s in $skills) {
    $parentDir = Split-Path -Parent $s.FullName
    $skillName = Split-Path -Leaf $parentDir

    $raw = Get-Content -LiteralPath $s.FullName -Raw -Encoding utf8
    $clean = $raw.TrimStart([char]0xFEFF)

    # Validate delimiter bounds (CRLF & LF safe)
    $hasFrontmatter = ($clean -match '(?s)^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)')
    Assert-Test -Name "Skill frontmatter delimiters ($skillName)" -Condition $hasFrontmatter -Details "Missing or invalid '---' bounds"

    if ($hasFrontmatter) {
        $frontmatter = $Matches[1]
        $syntaxResult = Test-YamlBlockSyntax -Content $frontmatter -FilePath $s.FullName
        Assert-Test -Name "Skill frontmatter syntax ($skillName)" -Condition ($syntaxResult.Success) -Details ($syntaxResult.Error)

        # Validate description length <= 128 characters
        if ($frontmatter -match '(?m)^description:\s*(?:>|\|)?\s*(.+)$') {
            $rawDesc = $Matches[1].Trim()
            $desc = $rawDesc.Trim('''', '"').Replace("`r", "")
            $validLength = ($desc.Length -le 128)
            Assert-Test -Name "Skill description length <= 128 ($skillName)" -Condition $validLength -Details "Description length ($($desc.Length)) exceeds 128 chars: $desc"
        } else {
            Assert-Test -Name "Skill description present ($skillName)" -Condition $false -Details "Missing description field"
        }
    }
}

# ---------------------------------------------------------
# Part 4: Parser Unit Tests
# ---------------------------------------------------------
Write-Host "`n[4] Running Parser Unit Tests..." -ForegroundColor White

$inlineCommentYaml = 'title: "[BUG]: " # issue prefix'
$inlineCommentResult = Test-YamlBlockSyntax -Content $inlineCommentYaml -FilePath "inline-comment-test.yml"
Assert-Test -Name "Quoted scalar with inline comment syntax" -Condition ($inlineCommentResult.Success) -Details ($inlineCommentResult.Error)

$tabAfterSpaceYaml = "key:`n  `tvalue"
$tabAfterSpaceResult = Test-YamlBlockSyntax -Content $tabAfterSpaceYaml -FilePath "tab-after-space-test.yml"
Assert-Test -Name "Tab following spaces in indentation is rejected" -Condition (-not $tabAfterSpaceResult.Success) -Details ($tabAfterSpaceResult.Error)

$zeroIndentSeqParentDupYaml = @(
    "rootKey: first",
    "items:",
    "- name: alpha",
    "- name: beta",
    "rootKey: duplicate"
) -join "`n"
$zeroIndentSeqParentDupRes = Test-YamlBlockSyntax -Content $zeroIndentSeqParentDupYaml -FilePath "seq-parent-dup.yml"
Assert-Test -Name "Zero-indent sequence preserves parent scope and rejects duplicate root key" -Condition ((-not $zeroIndentSeqParentDupRes.Success) -and ($zeroIndentSeqParentDupRes.Error -match "Duplicate key 'rootKey'")) -Details $zeroIndentSeqParentDupRes.Error

$zeroIndentSeqItemDupYaml = @(
    "items:",
    "- name: alpha",
    "  name: beta"
) -join "`n"
$zeroIndentSeqItemDupRes = Test-YamlBlockSyntax -Content $zeroIndentSeqItemDupYaml -FilePath "seq-item-dup.yml"
Assert-Test -Name "Zero-indent sequence mapping detects duplicate key inside item" -Condition ((-not $zeroIndentSeqItemDupRes.Success) -and ($zeroIndentSeqItemDupRes.Error -match "Duplicate key 'name'")) -Details $zeroIndentSeqItemDupRes.Error

$zeroIndentSeqValidYaml = @(
    "rootKey: ok",
    "items:",
    "- name: alpha",
    "  role: admin",
    "- name: beta",
    "  role: user"
) -join "`n"
$zeroIndentSeqValidRes = Test-YamlBlockSyntax -Content $zeroIndentSeqValidYaml -FilePath "seq-valid.yml"
Assert-Test -Name "Zero-indent sequence of distinct multi-key mapping items passes" -Condition ($zeroIndentSeqValidRes.Success) -Details $zeroIndentSeqValidRes.Error

$specialKeysValidYaml = @(
    "config/hooks.json: ok",
    "app.env: prod",
    "'quoted:key': value",
    '"path/key.name": "quoted value"'
) -join "`n"
$specialKeysValidRes = Test-YamlBlockSyntax -Content $specialKeysValidYaml -FilePath "special-keys-valid.yml"
Assert-Test -Name "Keys containing dots, slashes, or quotes pass when distinct" -Condition ($specialKeysValidRes.Success) -Details $specialKeysValidRes.Error

$specialKeysDupSlashYaml = "config/hooks.json: one`nconfig/hooks.json: two"
$specialKeysDupSlashRes = Test-YamlBlockSyntax -Content $specialKeysDupSlashYaml -FilePath "special-keys-dup-slash.yml"
Assert-Test -Name "Duplicate keys containing slashes and dots are rejected" -Condition (-not $specialKeysDupSlashRes.Success) -Details $specialKeysDupSlashRes.Error

$specialKeysDupQuoteYaml = "'quoted:key': one`n'quoted:key': two"
$specialKeysDupQuoteRes = Test-YamlBlockSyntax -Content $specialKeysDupQuoteYaml -FilePath "special-keys-dup-quote.yml"
Assert-Test -Name "Duplicate quoted keys are rejected" -Condition (-not $specialKeysDupQuoteRes.Success) -Details $specialKeysDupQuoteRes.Error

$seqUrlYaml = "links:`n- https://example.com/docs"
$seqUrlRes = Test-YamlBlockSyntax -Content $seqUrlYaml -FilePath "seq-url.yml"
Assert-Test -Name "Sequence item URL is not misparsed as key-value pair" -Condition ($seqUrlRes.Success) -Details $seqUrlRes.Error

# ---------------------------------------------------------
# Part 5: Hooks Configuration & Script Integrity
# ---------------------------------------------------------
Write-Host "`n[5] Validating Antigravity Hooks Configuration & Scripts..." -ForegroundColor White

$hooksJsonPath = Join-Path (Join-Path $repoRoot "config") "hooks.json"
$hooksExist = Test-Path -LiteralPath $hooksJsonPath
Assert-Test -Name "config/hooks.json exists" -Condition $hooksExist -Details "Missing $hooksJsonPath"

if ($hooksExist) {
    $rawBytes = [System.IO.File]::ReadAllBytes($hooksJsonPath)
    $hasBom = ($rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF)
    Assert-Test -Name "config/hooks.json has no UTF-8 BOM" -Condition (-not $hasBom) -Details "hooks.json must be UTF-8 without BOM"

    $hooksObj = $null
    $jsonValid = $false
    $jsonError = ""
    try {
        $hooksText = [System.IO.File]::ReadAllText($hooksJsonPath, [System.Text.Encoding]::UTF8)
        $hooksObj = $hooksText | ConvertFrom-Json
        $jsonValid = ($null -ne $hooksObj)
    } catch {
        $jsonValid = $false
        $jsonError = $_.Exception.Message
    }
    Assert-Test -Name "config/hooks.json parses as valid JSON" -Condition $jsonValid -Details $jsonError

    if ($jsonValid) {
        $preMatchers = @()
        $postMatchers = @()
        $allCommandsValid = $true
        $allGroupsHaveHooks = $true

        foreach ($prop in $hooksObj.PSObject.Properties) {
            $hookSpec = $prop.Value
            if ($hookSpec.PSObject.Properties["PreToolUse"]) {
                foreach ($group in @($hookSpec.PreToolUse)) {
                    $preMatchers += [string]$group.matcher
                    if (-not ($null -ne $group.hooks -and @($group.hooks).Count -ge 1)) {
                        $allGroupsHaveHooks = $false
                        $allCommandsValid = $false
                    }
                    foreach ($h in @($group.hooks)) {
                        $cmd = [string]$h.command
                        if ($cmd -notmatch '^powershell\s+-NoProfile\s+-NonInteractive\s+-ExecutionPolicy\s+Bypass\s+-File\s+\./scripts/Invoke-AntigravityHook\.ps1\s+-Event\s+PreToolUse\s*$') {
                            $allCommandsValid = $false
                        }
                    }
                }
            }
            if ($hookSpec.PSObject.Properties["PostToolUse"]) {
                foreach ($group in @($hookSpec.PostToolUse)) {
                    $postMatchers += [string]$group.matcher
                    if (-not ($null -ne $group.hooks -and @($group.hooks).Count -ge 1)) {
                        $allGroupsHaveHooks = $false
                        $allCommandsValid = $false
                    }
                    foreach ($h in @($group.hooks)) {
                        $cmd = [string]$h.command
                        if ($cmd -notmatch '^powershell\s+-NoProfile\s+-NonInteractive\s+-ExecutionPolicy\s+Bypass\s+-File\s+\./scripts/Invoke-AntigravityHook\.ps1\s+-Event\s+PostToolUse\s*$') {
                            $allCommandsValid = $false
                        }
                    }
                }
            }
        }

        $expectedPre = @(
            "run_command",
            "view_file|read_file|replace_file_content|multi_replace_file_content|edit_file|write_to_file|write_file|create_file"
        )
        $expectedPost = @(
            "write_to_file|write_file|create_file|replace_file_content|multi_replace_file_content|edit_file"
        )
        $hasExactPre = ($preMatchers.Count -eq 2) -and ($expectedPre[0] -in $preMatchers) -and ($expectedPre[1] -in $preMatchers) -and ("invoke_subagent" -notin $preMatchers)
        $hasExactPost = ($postMatchers.Count -eq 1) -and ($expectedPost[0] -in $postMatchers)

        Assert-Test -Name "config/hooks.json defines exact 2 PreToolUse matchers (no invoke_subagent)" -Condition $hasExactPre -Details ("Found: " + ($preMatchers -join ", "))
        Assert-Test -Name "config/hooks.json defines exact 1 PostToolUse matcher" -Condition $hasExactPost -Details ("Found: " + ($postMatchers -join ", "))
        Assert-Test -Name "config/hooks.json matcher groups define at least 1 hook handler" -Condition $allGroupsHaveHooks
        Assert-Test -Name "config/hooks.json handlers invoke ./scripts/Invoke-AntigravityHook.ps1 correctly" -Condition $allCommandsValid
    }
}

$configScriptsDir = Join-Path (Join-Path $repoRoot "config") "scripts"
$expectedScripts = @(
    "Invoke-AntigravityHook.ps1",
    "Test-PowerShellCommandSafety.ps1",
    "New-AuditCheckpoint.ps1",
    "Restore-AuditCheckpoint.ps1",
    "Update-Gate2Diff.ps1"
)
foreach ($scriptName in $expectedScripts) {
    $scriptPath = Join-Path $configScriptsDir $scriptName
    $scriptExists = Test-Path -LiteralPath $scriptPath -PathType Leaf
    Assert-Test -Name "config/scripts/$scriptName exists" -Condition $scriptExists -Details "Missing $scriptPath"

    if ($scriptExists) {
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$parseErrors) | Out-Null
        $astValid = (-not $parseErrors) -or ($parseErrors.Count -eq 0)
        Assert-Test -Name "$scriptName passes PowerShell AST parse" -Condition $astValid -Details ("$parseErrors")
    }
}

$retiredOrchestratorScriptsDir = Join-Path (Join-Path (Join-Path (Join-Path $repoRoot "config") "skills") "orchestrator") "scripts"
Assert-Test -Name "config/skills/orchestrator/scripts directory is absent" -Condition (-not (Test-Path -LiteralPath $retiredOrchestratorScriptsDir)) -Details "Retired directory still exists at $retiredOrchestratorScriptsDir"

$retiredSubagentPatternsPath = Join-Path (Join-Path (Join-Path (Join-Path (Join-Path $repoRoot "config") "skills") "orchestrator") "references") "subagent-patterns.md"
Assert-Test -Name "config/skills/orchestrator/references/subagent-patterns.md is absent" -Condition (-not (Test-Path -LiteralPath $retiredSubagentPatternsPath)) -Details "Retired file still exists at $retiredSubagentPatternsPath"

foreach ($rootScriptName in @("sync.ps1", "restore.ps1")) {
    $rootScriptPath = Join-Path $repoRoot $rootScriptName
    $scriptText = Get-Content -LiteralPath $rootScriptPath -Raw -Encoding utf8
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($rootScriptPath, [ref]$null, [ref]$parseErrors) | Out-Null
    $astValid = (-not $parseErrors) -or ($parseErrors.Count -eq 0)
    Assert-Test -Name "$rootScriptName passes PowerShell AST parse" -Condition $astValid -Details ("$parseErrors")
    Assert-Test -Name "$rootScriptName removes legacy externalSkills/officialPlugins lists" -Condition ($scriptText -notmatch '\$externalSkills' -and $scriptText -notmatch '\$officialPlugins')
    Assert-Test -Name "$rootScriptName includes hooks.json and scripts/ support" -Condition ($scriptText -match 'hooks\.json' -and $scriptText -match 'scripts')
}

# ---------------------------------------------------------
# Part 6: Deployment Scripts, 4-Way Secret Parity & CI/Gitignore Hardening
# ---------------------------------------------------------
Write-Host "`n[6] Validating Deployment Scripts, Secret Parity, CI & Gitignore..." -ForegroundColor White

$syncPath = Join-Path $repoRoot "sync.ps1"
$restorePath = Join-Path $repoRoot "restore.ps1"
$updateGate2Path = Join-Path $repoRoot "config/scripts/Update-Gate2Diff.ps1"
$ciWorkflowPath = Join-Path $repoRoot ".github/workflows/ci.yml"
$gitignorePath = Join-Path $repoRoot ".gitignore"

function Get-SecretPatternsFromSyncOrRestore {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errs)
    if ($errs) { return @() }
    $assign = $ast.FindAll({
        param($n)
        $n -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $n.Left.Extent.Text -eq '$secretPatterns'
    }, $true) | Select-Object -First 1
    if (-not $assign) { return @() }
    $patterns = @()
    foreach ($ht in $assign.Right.FindAll({ param($n) $n -is [System.Management.Automation.Language.HashtableAst] }, $true)) {
        foreach ($kv in $ht.KeyValuePairs) {
            if ($kv.Item1.Value -eq "Pattern") {
                $strAst = $kv.Item2.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true) | Select-Object -First 1
                if ($strAst) { $patterns += $strAst.Value }
            }
        }
    }
    return @($patterns)
}

function Get-SecretPatternsFromUpdateGate2 {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$errs)
    if ($errs) { return @() }
    $fn = $ast.FindAll({
        param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
        $n.Name -eq 'Sanitize-DiffContent'
    }, $true) | Select-Object -First 1
    if (-not $fn) { return @() }
    $patterns = @()
    foreach ($call in $fn.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] }, $true)) {
        if ($call.Member.Value -eq "Replace" -and $call.Arguments.Count -ge 2) {
            $strAst = $call.Arguments[1] -as [System.Management.Automation.Language.StringConstantExpressionAst]
            if ($strAst -and $strAst.Value -notmatch '^\(\?ms\).*-----END') {
                $patterns += $strAst.Value
            }
        }
    }
    return @($patterns)
}

function Get-SecretPatternsFromCi {
    param([string]$Path)
    $ciText = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    if ($ciText -notmatch '(?ms)(\$secretPatterns\s*=\s*@\([\s\S]*?\r?\n\s*\))') {
        return @()
    }
    $snippet = $Matches[1]
    $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($snippet, [ref]$null, [ref]$errs)
    if ($errs) { return @() }
    $arr = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.ArrayExpressionAst] }, $true) | Select-Object -First 1
    if (-not $arr) { return @() }
    $patterns = @()
    foreach ($strAst in $arr.FindAll({ param($n) $n -is [System.Management.Automation.Language.StringConstantExpressionAst] }, $true)) {
        $patterns += $strAst.Value
    }
    return @($patterns)
}

$syncPatterns = @(Get-SecretPatternsFromSyncOrRestore -Path $syncPath)
$restorePatterns = @(Get-SecretPatternsFromSyncOrRestore -Path $restorePath)
$updatePatterns = @(Get-SecretPatternsFromUpdateGate2 -Path $updateGate2Path)
$ciPatterns = @(Get-SecretPatternsFromCi -Path $ciWorkflowPath)

$parityOk = ($updatePatterns.Count -eq 7) -and
    ($syncPatterns.Count -eq $updatePatterns.Count) -and
    ($restorePatterns.Count -eq $updatePatterns.Count) -and
    ($ciPatterns.Count -eq $updatePatterns.Count)
if ($parityOk) {
    for ($idx = 0; $idx -lt $updatePatterns.Count; $idx++) {
        if (($syncPatterns[$idx] -cne $updatePatterns[$idx]) -or
            ($restorePatterns[$idx] -cne $updatePatterns[$idx]) -or
            ($ciPatterns[$idx] -cne $updatePatterns[$idx])) {
            $parityOk = $false
            break
        }
    }
}
Assert-Test -Name "4-way secretPatterns regex parity across sync.ps1, restore.ps1, Update-Gate2Diff.ps1, and ci.yml" -Condition $parityOk -Details "counts: sync=$($syncPatterns.Count) restore=$($restorePatterns.Count) update=$($updatePatterns.Count) ci=$($ciPatterns.Count)"

$gitignoreText = Get-Content -LiteralPath $gitignorePath -Raw -Encoding utf8
$hasGitignoreGuards = ($gitignoreText -match '(?m)^id_ed25519\*\s*$') -and
    ($gitignoreText -match '(?m)^id_ecdsa\*\s*$') -and
    ($gitignoreText -match '(?m)^\*\.p12\s*$') -and
    ($gitignoreText -match '(?m)^\*\.pfx\s*$')
Assert-Test -Name ".gitignore includes id_ed25519*, id_ecdsa*, *.p12, and *.pfx secret guards" -Condition $hasGitignoreGuards

$ciRaw = Get-Content -LiteralPath $ciWorkflowPath -Raw -Encoding utf8
$ciHardened = ($ciRaw -match 'git\s+-c\s+core\.quotePath=false\s+ls-files') -and
    ($ciRaw -match '\$LASTEXITCODE\s+-ne\s+0') -and
    ($ciRaw -match '-Encoding\s+utf8') -and
    ($ciRaw -match '\(\?s\)\^---\\r\?\\n')
Assert-Test -Name "ci.yml bounds SKILL.md scan to frontmatter with UTF-8 and scans tracked files via git ls-files" -Condition $ciHardened

$psExe = if ($PSVersionTable.PSEdition -eq "Core") { (Get-Process -Id $PID).Path } else { Join-Path $PSHOME "powershell.exe" }
function Invoke-DeploySandboxScript {
    param(
        [string]$ScriptPath,
        [string]$HomeDir
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $psExe
    $psi.Arguments = "-NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.EnvironmentVariables["USERPROFILE"] = $HomeDir
    $psi.EnvironmentVariables["HOME"] = $HomeDir
    $proc = [System.Diagnostics.Process]::Start($psi)
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $proc.WaitForExit()
    return @{
        ExitCode = $proc.ExitCode
        StdOut   = $outTask.Result
        StdErr   = $errTask.Result
    }
}

$sandboxRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("yaml_deploy_" + [System.Guid]::NewGuid().ToString("N").Substring(0, 8))
try {
    $repoBracket = Join-Path $sandboxRoot "repo[1]"
    $homeBracket = Join-Path $sandboxRoot "home[1]"
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $repoBracket "config/scripts"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $repoBracket "config/agents/tdd-guide/sub"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $repoBracket "config/skills/orchestrator/refs"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $homeBracket ".gemini/config/agents/tdd-guide/stale_sub"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $homeBracket ".gemini/config/skills/orchestrator/stale_sub"))

    Copy-Item -LiteralPath $syncPath -Destination (Join-Path $repoBracket "sync.ps1") -Force
    Copy-Item -LiteralPath $restorePath -Destination (Join-Path $repoBracket "restore.ps1") -Force
    [System.IO.File]::WriteAllText((Join-Path $repoBracket "config/GEMINI.md"), "# Repo GEMINI", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $repoBracket "config/hooks.json"), "{}", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $repoBracket "config/scripts/helper.ps1"), "# helper", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $repoBracket "config/agents/tdd-guide/agent.md"), "name: tdd-guide", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $repoBracket "config/agents/tdd-guide/.hidden"), "agent-dot", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $repoBracket "config/agents/tdd-guide/sub/nested.txt"), "agent-nested", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $repoBracket "config/skills/orchestrator/SKILL.md"), "name: orchestrator", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $repoBracket "config/skills/orchestrator/.hidden"), "skill-dot", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $repoBracket "config/skills/orchestrator/refs/doc.md"), "skill-nested", [System.Text.UTF8Encoding]::new($false))

    [System.IO.File]::WriteAllText((Join-Path $homeBracket ".gemini/GEMINI.md"), "# Home GEMINI", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $homeBracket ".gemini/config/hooks.json"), '{"old":true}', [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $homeBracket ".gemini/config/agents/tdd-guide/stale_sub/orphan.txt"), "stale", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $homeBracket ".gemini/config/skills/orchestrator/stale_sub/orphan.txt"), "stale", [System.Text.UTF8Encoding]::new($false))

    # Pre-seed backup_<ts> directories across a 3-second window to deterministically test same-second collision disambiguation
    $nowTs = Get-Date
    foreach ($offset in @(0, 1, 2)) {
        $tsStr = $nowTs.AddSeconds($offset).ToString("yyyyMMdd_HHmmss")
        $preBakScripts = Join-Path (Join-Path (Join-Path $homeBracket ".gemini") "backup_$tsStr") "scripts"
        $null = [System.IO.Directory]::CreateDirectory($preBakScripts)
        [System.IO.File]::WriteAllText((Join-Path $preBakScripts "preexisting.ps1"), "# pre", [System.Text.UTF8Encoding]::new($false))
    }

    $restoreBracketRes = Invoke-DeploySandboxScript -ScriptPath (Join-Path $repoBracket "restore.ps1") -HomeDir $homeBracket
    $deployedAgentDot = Test-Path -LiteralPath (Join-Path $homeBracket ".gemini/config/agents/tdd-guide/.hidden")
    $deployedAgentNested = Test-Path -LiteralPath (Join-Path $homeBracket ".gemini/config/agents/tdd-guide/sub/nested.txt")
    $deployedSkillDot = Test-Path -LiteralPath (Join-Path $homeBracket ".gemini/config/skills/orchestrator/.hidden")
    $deployedSkillNested = Test-Path -LiteralPath (Join-Path $homeBracket ".gemini/config/skills/orchestrator/refs/doc.md")
    $deployedScriptBracket = Test-Path -LiteralPath (Join-Path $homeBracket ".gemini/config/scripts/helper.ps1")
    $prunedAgentEmptySub = -not (Test-Path -LiteralPath (Join-Path $homeBracket ".gemini/config/agents/tdd-guide/stale_sub"))
    $disambiguatedBak = @(Get-ChildItem -LiteralPath (Join-Path $homeBracket ".gemini") -Directory | Where-Object { $_.Name -match '^backup_\d{8}_\d{6}_1$' })
    $noNestedScriptsBak = -not (Test-Path -LiteralPath (Join-Path $homeBracket ".gemini/backup_$($nowTs.ToString('yyyyMMdd_HHmmss'))/scripts/scripts"))

    Assert-Test -Name "restore.ps1 deploys dotfiles and nested files into [ ] paths without wildcards" -Condition ($restoreBracketRes.ExitCode -eq 0 -and $deployedAgentDot -and $deployedAgentNested -and $deployedSkillDot -and $deployedSkillNested -and $deployedScriptBracket) -Details "rc=$($restoreBracketRes.ExitCode) aDot=$deployedAgentDot aNest=$deployedAgentNested sDot=$deployedSkillDot sNest=$deployedSkillNested scr=$deployedScriptBracket err=$($restoreBracketRes.StdErr)"
    Assert-Test -Name "restore.ps1 prunes empty subdirectories in agents/ after orphan cleanup" -Condition $prunedAgentEmptySub -Details "stale_sub still present"
    Assert-Test -Name "restore.ps1 disambiguates same-second backup directory collisions without nesting" -Condition ($disambiguatedBak.Count -eq 1 -and $noNestedScriptsBak) -Details "disambigCount=$($disambiguatedBak.Count) noNested=$noNestedScriptsBak"

    # sync.ps1 Phase 2 -Force dotfiles, [ ] paths, and agents/ empty-subdir cleanup
    [System.IO.File]::WriteAllText((Join-Path $homeBracket ".gemini/config/agents/tdd-guide/.syncdot"), "from-home-agent", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $homeBracket ".gemini/config/skills/orchestrator/.syncdot"), "from-home-skill", [System.Text.UTF8Encoding]::new($false))
    $repoAgentEmptyDir = Join-Path $repoBracket "config/agents/tdd-guide/empty_only"
    $null = [System.IO.Directory]::CreateDirectory($repoAgentEmptyDir)
    [System.IO.File]::WriteAllText((Join-Path $repoAgentEmptyDir "orphan.md"), "orphan", [System.Text.UTF8Encoding]::new($false))

    $syncBracketRes = Invoke-DeploySandboxScript -ScriptPath (Join-Path $repoBracket "sync.ps1") -HomeDir $homeBracket
    $syncedAgentDot = Test-Path -LiteralPath (Join-Path $repoBracket "config/agents/tdd-guide/.syncdot")
    $syncedSkillDot = Test-Path -LiteralPath (Join-Path $repoBracket "config/skills/orchestrator/.syncdot")
    $prunedSyncAgentEmpty = -not (Test-Path -LiteralPath $repoAgentEmptyDir)

    Assert-Test -Name "sync.ps1 copies dotfiles into [ ] repo paths and prunes empty agents/ subdirectories" -Condition ($syncBracketRes.ExitCode -eq 0 -and $syncedAgentDot -and $syncedSkillDot -and $prunedSyncAgentEmpty) -Details "rc=$($syncBracketRes.ExitCode) aDot=$syncedAgentDot sDot=$syncedSkillDot prunedEmpty=$prunedSyncAgentEmpty err=$($syncBracketRes.StdErr)"

    # Negative credential rejection tests in [ ] paths for both sync.ps1 and restore.ps1
    $secretPayloads = @(
        @{ Label = "base64 Bearer"; Line = ("Authorization: Bearer " + "ab+cd/ef==123456") },
        @{ Label = "unquoted TOKEN="; Line = ("TOKEN=" + "unquoted_secret_token_val_123456") },
        @{ Label = "quoted my_api_key_v2"; Line = ('"my_api_key_v2": "' + 'super_secret_key_value_123"') }
    )
    foreach ($spCase in $secretPayloads) {
        $homeLeak = Join-Path $homeBracket ".gemini/config/agents/tdd-guide/leak.md"
        $repoLeak = Join-Path $repoBracket "config/agents/tdd-guide/leak.md"
        if (Test-Path -LiteralPath $repoLeak) { Remove-Item -LiteralPath $repoLeak -Force }
        [System.IO.File]::WriteAllText($homeLeak, $spCase.Line, [System.Text.UTF8Encoding]::new($false))
        $syncLeakRes = Invoke-DeploySandboxScript -ScriptPath (Join-Path $repoBracket "sync.ps1") -HomeDir $homeBracket
        $syncBlocked = ($syncLeakRes.ExitCode -ne 0) -and ($syncLeakRes.StdErr -match 'Credential leak detected') -and (-not (Test-Path -LiteralPath $repoLeak))
        Assert-Test -Name "sync.ps1 rejects $($spCase.Label) credential in [ ] path before copying" -Condition $syncBlocked -Details "rc=$($syncLeakRes.ExitCode) copied=$(Test-Path -LiteralPath $repoLeak) err=$($syncLeakRes.StdErr)"
        Remove-Item -LiteralPath $homeLeak -Force

        $restoreLeakTarget = Join-Path $homeBracket ".gemini/config/agents/tdd-guide/repo_leak.md"
        if (Test-Path -LiteralPath $restoreLeakTarget) { Remove-Item -LiteralPath $restoreLeakTarget -Force }
        $repoSourceLeak = Join-Path $repoBracket "config/agents/tdd-guide/repo_leak.md"
        [System.IO.File]::WriteAllText($repoSourceLeak, $spCase.Line, [System.Text.UTF8Encoding]::new($false))
        $restoreLeakRes = Invoke-DeploySandboxScript -ScriptPath (Join-Path $repoBracket "restore.ps1") -HomeDir $homeBracket
        $restoreBlocked = ($restoreLeakRes.ExitCode -ne 0) -and ($restoreLeakRes.StdErr -match 'Credential leak detected') -and (-not (Test-Path -LiteralPath $restoreLeakTarget))
        Assert-Test -Name "restore.ps1 rejects $($spCase.Label) credential in [ ] path before deploying" -Condition $restoreBlocked -Details "rc=$($restoreLeakRes.ExitCode) deployed=$(Test-Path -LiteralPath $restoreLeakTarget) err=$($restoreLeakRes.StdErr)"
        Remove-Item -LiteralPath $repoSourceLeak -Force
    }

    # restore.ps1 deployment rollback on failure
    $rbRepo = Join-Path $sandboxRoot "rb_repo"
    $rbHome = Join-Path $sandboxRoot "rb_home"
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $rbRepo "config/scripts"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $rbRepo "config/agents/tdd-guide"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $rbRepo "config/skills/orchestrator"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $rbHome ".gemini/config/scripts"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $rbHome ".gemini/config/agents/tdd-guide"))
    Copy-Item -LiteralPath $restorePath -Destination (Join-Path $rbRepo "restore.ps1") -Force
    [System.IO.File]::WriteAllText((Join-Path $rbRepo "config/GEMINI.md"), "# New Repo GEMINI", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $rbRepo "config/hooks.json"), '{"new":true}', [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $rbRepo "config/scripts/s.ps1"), "# new script", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $rbRepo "config/agents/tdd-guide/agent.md"), "name: new-agent", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $rbRepo "config/skills/orchestrator/SKILL.md"), "name: new-skill", [System.Text.UTF8Encoding]::new($false))

    [System.IO.File]::WriteAllText((Join-Path $rbHome ".gemini/GEMINI.md"), "# Original User GEMINI", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $rbHome ".gemini/config/hooks.json"), '{"original":true}', [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $rbHome ".gemini/config/scripts/s.ps1"), "# original script", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $rbHome ".gemini/config/agents/tdd-guide/agent.md"), "name: original-agent", [System.Text.UTF8Encoding]::new($false))
    # Blocking regular file at config/skills triggers deployment failure mid-run
    [System.IO.File]::WriteAllText((Join-Path $rbHome ".gemini/config/skills"), "collision-file", [System.Text.UTF8Encoding]::new($false))

    $rbRes = Invoke-DeploySandboxScript -ScriptPath (Join-Path $rbRepo "restore.ps1") -HomeDir $rbHome
    $rbGeminiRestored = ([System.IO.File]::ReadAllText((Join-Path $rbHome ".gemini/GEMINI.md"), [System.Text.Encoding]::UTF8).Trim() -eq "# Original User GEMINI")
    $rbHooksRestored = ([System.IO.File]::ReadAllText((Join-Path $rbHome ".gemini/config/hooks.json"), [System.Text.Encoding]::UTF8).Trim() -eq '{"original":true}')
    $rbScriptRestored = ([System.IO.File]::ReadAllText((Join-Path $rbHome ".gemini/config/scripts/s.ps1"), [System.Text.Encoding]::UTF8).Trim() -eq "# original script")
    $rbAgentRestored = ([System.IO.File]::ReadAllText((Join-Path $rbHome ".gemini/config/agents/tdd-guide/agent.md"), [System.Text.Encoding]::UTF8).Trim() -eq "name: original-agent")

    Assert-Test -Name "restore.ps1 rolls back partial deployment from backup on failure" -Condition ($rbRes.ExitCode -ne 0 -and $rbGeminiRestored -and $rbHooksRestored -and $rbScriptRestored -and $rbAgentRestored) -Details "rc=$($rbRes.ExitCode) gem=$rbGeminiRestored hooks=$rbHooksRestored scr=$rbScriptRestored ag=$rbAgentRestored"

    # Case 1: Reparse-point / junction safety for retired skills and legacy ADR paths
    $linkType = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { "Junction" } else { "SymbolicLink" }
    $case1Repo = Join-Path $sandboxRoot "link_repo"
    $case1Home = Join-Path $sandboxRoot "link_home"
    $case1ExternalSkillTarget = Join-Path $sandboxRoot "external_skill_target"
    $case1ExternalAdrTarget = Join-Path $sandboxRoot "external_adr_target"
    $case1ExternalDocsTarget = Join-Path $sandboxRoot "external_docs_target"
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $case1Repo "config/scripts"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $case1Repo "config/agents/tdd-guide"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $case1Repo "config/skills/orchestrator"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $case1Home ".gemini/config/skills"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $case1Home ".gemini/docs"))
    $null = [System.IO.Directory]::CreateDirectory($case1ExternalSkillTarget)
    $null = [System.IO.Directory]::CreateDirectory($case1ExternalAdrTarget)
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $case1ExternalDocsTarget "adr"))

    Copy-Item -LiteralPath $restorePath -Destination (Join-Path $case1Repo "restore.ps1") -Force
    [System.IO.File]::WriteAllText((Join-Path $case1Repo "config/GEMINI.md"), "# Repo GEMINI", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $case1Repo "config/hooks.json"), "{}", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $case1Repo "config/scripts/s.ps1"), "# script", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $case1Repo "config/agents/tdd-guide/agent.md"), "name: tdd-guide", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $case1Repo "config/skills/orchestrator/SKILL.md"), "name: orchestrator", [System.Text.UTF8Encoding]::new($false))

    $skillSentinel = Join-Path $case1ExternalSkillTarget "sentinel.txt"
    $adrSentinel = Join-Path $case1ExternalAdrTarget "sentinel.txt"
    $docsParentSentinel = Join-Path $case1ExternalDocsTarget "adr/sentinel.txt"
    [System.IO.File]::WriteAllText($skillSentinel, "keep-skill-target", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($adrSentinel, "keep-adr-target", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText($docsParentSentinel, "keep-docs-parent-target", [System.Text.UTF8Encoding]::new($false))

    $retiredSkillLink = Join-Path $case1Home ".gemini/config/skills/audit-dev-workflow"
    $legacyAdrLink = Join-Path $case1Home ".gemini/docs/adr"
    $docsParentLink = Join-Path $case1Home ".gemini/config/docs"
    $null = New-Item -ItemType $linkType -Path $retiredSkillLink -Target $case1ExternalSkillTarget
    $null = New-Item -ItemType $linkType -Path $legacyAdrLink -Target $case1ExternalAdrTarget
    $null = New-Item -ItemType $linkType -Path $docsParentLink -Target $case1ExternalDocsTarget
    $testLinks = @($retiredSkillLink, $legacyAdrLink, $docsParentLink)

    $case1Res = Invoke-DeploySandboxScript -ScriptPath (Join-Path $case1Repo "restore.ps1") -HomeDir $case1Home
    $skillLinkRemoved = -not (Test-Path -LiteralPath $retiredSkillLink)
    $adrLinkRemoved = -not (Test-Path -LiteralPath $legacyAdrLink)
    $skillSentinelPreserved = Test-Path -LiteralPath $skillSentinel -PathType Leaf
    $adrSentinelPreserved = Test-Path -LiteralPath $adrSentinel -PathType Leaf
    $docsParentPreserved = Test-Path -LiteralPath $docsParentSentinel -PathType Leaf
    Assert-Test -Name "restore.ps1 unlinks retired skill and ADR junctions/symlinks without deleting target contents" -Condition ($case1Res.ExitCode -eq 0 -and $skillLinkRemoved -and $adrLinkRemoved -and $skillSentinelPreserved -and $adrSentinelPreserved -and $docsParentPreserved) -Details "rc=$($case1Res.ExitCode) skillGone=$skillLinkRemoved adrGone=$adrLinkRemoved skillSentinel=$skillSentinelPreserved adrSentinel=$adrSentinelPreserved docsParentSentinel=$docsParentPreserved err=$($case1Res.StdErr)"

    # Case 2: Leaf-file-to-directory collision in agents/ and skills/
    $case2Repo = Join-Path $sandboxRoot "leaf_repo"
    $case2Home = Join-Path $sandboxRoot "leaf_home"
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $case2Repo "config/scripts"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $case2Repo "config/agents/ui-crafter"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $case2Repo "config/skills/coding-standards"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $case2Home ".gemini/config/agents"))
    $null = [System.IO.Directory]::CreateDirectory((Join-Path $case2Home ".gemini/config/skills"))

    Copy-Item -LiteralPath $restorePath -Destination (Join-Path $case2Repo "restore.ps1") -Force
    [System.IO.File]::WriteAllText((Join-Path $case2Repo "config/GEMINI.md"), "# Repo GEMINI", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $case2Repo "config/hooks.json"), "{}", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $case2Repo "config/scripts/s.ps1"), "# script", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $case2Repo "config/agents/ui-crafter/agent.md"), "name: ui-crafter", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $case2Repo "config/skills/coding-standards/SKILL.md"), "name: coding-standards", [System.Text.UTF8Encoding]::new($false))

    [System.IO.File]::WriteAllText((Join-Path $case2Home ".gemini/config/agents/ui-crafter"), "colliding-agent-leaf", [System.Text.UTF8Encoding]::new($false))
    [System.IO.File]::WriteAllText((Join-Path $case2Home ".gemini/config/skills/coding-standards"), "colliding-skill-leaf", [System.Text.UTF8Encoding]::new($false))

    $case2Res = Invoke-DeploySandboxScript -ScriptPath (Join-Path $case2Repo "restore.ps1") -HomeDir $case2Home
    $deployedAgentLeafFix = Test-Path -LiteralPath (Join-Path $case2Home ".gemini/config/agents/ui-crafter/agent.md") -PathType Leaf
    $deployedSkillLeafFix = Test-Path -LiteralPath (Join-Path $case2Home ".gemini/config/skills/coding-standards/SKILL.md") -PathType Leaf
    Assert-Test -Name "restore.ps1 replaces colliding leaf files in agents/ and skills/ with deployed directories" -Condition ($case2Res.ExitCode -eq 0 -and $deployedAgentLeafFix -and $deployedSkillLeafFix) -Details "rc=$($case2Res.ExitCode) agent=$deployedAgentLeafFix skill=$deployedSkillLeafFix err=$($case2Res.StdErr)"
} finally {
    foreach ($lnk in @($testLinks)) {
        if ($lnk) {
            try {
                $item = Get-Item -LiteralPath $lnk -Force -ErrorAction SilentlyContinue
                if ($item -and (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
                    if ($item.PSIsContainer) {
                        [System.IO.Directory]::Delete($lnk, $false)
                    } else {
                        [System.IO.File]::Delete($lnk)
                    }
                }
            } catch { }
        }
    }
    if (Test-Path -LiteralPath $sandboxRoot) {
        Remove-Item -LiteralPath $sandboxRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------
# Final Summary
# ---------------------------------------------------------
Write-Host "`n==================================================" -ForegroundColor Cyan
Write-Host "YAML Validation Summary: $testsPassed / $testsRun passed ($testsFailed failed)" -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })
Write-Host "==================================================" -ForegroundColor Cyan

if ($testsFailed -gt 0) {
    exit 1
}
exit 0
