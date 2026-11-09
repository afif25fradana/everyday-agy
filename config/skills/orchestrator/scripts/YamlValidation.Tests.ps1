# YamlValidation.Tests.ps1
# Comprehensive YAML Syntax, Frontmatter & Schema Verification Suite
# Compatible with Windows PowerShell 5.1 and PowerShell Core 7.x (Ubuntu + Windows)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) { $scriptDir = (Get-Location).Path }

# Discover repository root
$repoRoot = $scriptDir
while ($repoRoot -and -not (Test-Path (Join-Path $repoRoot ".git")) -and -not (Test-Path (Join-Path $repoRoot "config/GEMINI.md"))) {
    $parent = Split-Path -Parent $repoRoot
    if ($parent -eq $repoRoot) { break }
    $repoRoot = $parent
}
if (-not $repoRoot -or -not (Test-Path (Join-Path $repoRoot "config/GEMINI.md"))) {
    $repoRoot = (Get-Location).Path
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

        # If line starts a list item (- key: val or - val), handle item
        if ($trimmed -match '^-\s*(.*)$') {
            $scopes[$lineIndent] = @{}
            $trimmed = $Matches[1].Trim()
        }

        # 2. Check Key-Value Pairs
        if ($trimmed -match '^([A-Za-z0-9_-]+):\s*(.*)$') {
            $key = $Matches[1]
            $val = $Matches[2].Trim()

            if (-not $scopes.ContainsKey($lineIndent)) {
                $scopes[$lineIndent] = @{}
            }

            if ($scopes[$lineIndent].ContainsKey($key)) {
                return @{ Success = $false; Error = "Line ${lineNum}: Duplicate key '$key' detected in mapping scope." }
            }
            $scopes[$lineIndent][$key] = $true

            # Check for Block Scalar indicator (| or > with optional chomp + / -)
            if ($val -match '^[>|][+-]?\s*(?:#.*)?$') {
                $inBlockScalar = $true
                $blockScalarIndent = $lineIndent
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
$yamlFiles = Get-ChildItem -Path (Join-Path $repoRoot ".github") -Include "*.yml", "*.yaml" -Recurse

foreach ($f in $yamlFiles) {
    $content = Get-Content -LiteralPath $f.FullName -Raw
    $syntaxResult = Test-YamlBlockSyntax -Content $content -FilePath $f.FullName
    Assert-Test -Name "Pure YAML Syntax: $($f.Name)" -Condition ($syntaxResult.Success) -Details ($syntaxResult.Error)
}

# ---------------------------------------------------------
# Part 2: Custom Agent Frontmatter (config/agents/*/agent.md)
# ---------------------------------------------------------
Write-Host "`n[2] Validating Custom Agent Frontmatter..." -ForegroundColor White
$agents = Get-ChildItem -Path (Join-Path $repoRoot "config/agents") -Directory

foreach ($a in $agents) {
    $agentFile = Join-Path $a.FullName "agent.md"
    if (-not (Test-Path $agentFile)) {
        Assert-Test -Name "Agent manifest exists ($($a.Name))" -Condition $false -Details "Missing agent.md"
        continue
    }

    $raw = Get-Content -LiteralPath $agentFile -Raw
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
$skills = Get-ChildItem -Path (Join-Path $repoRoot "config/skills") -Filter "SKILL.md" -Recurse

foreach ($s in $skills) {
    $parentDir = Split-Path -Parent $s.FullName
    $skillName = Split-Path -Leaf $parentDir

    $raw = Get-Content -LiteralPath $s.FullName -Raw
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
