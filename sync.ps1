# Everyday-AGY Sync Script
# Pulls active live configurations from ~/.gemini/ into this repository
$ErrorActionPreference = "Stop"

Write-Host ">>> Syncing active Antigravity configurations into everyday-agy..." -ForegroundColor Cyan

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = (Get-Location).Path }

# Cross-platform ~/.gemini/ directory resolution (Windows, macOS, Linux pwsh)
$userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$geminiHome = Join-Path $userHome ".gemini"
$configHome = Join-Path $geminiHome "config"

# 1. Credential Scanner Definition
$secretPatterns = @(
    @{ Kind = "Bearer token"; Pattern = 'Bearer\s+(?!<)[A-Za-z0-9_\-\.]{12,}' },
    @{ Kind = "Credential assignment"; Pattern = '["'']?(?:api[_-]?key|access[_-]?token|secret[_-]?key|token)["'']?\s*[:=]\s*["''](?!<)[^\s"'']{16,}["'']' }
)

function Assert-NoCredentialsInFile($filePath) {
    if (-not (Test-Path $filePath)) { return }
    $lines = Get-Content -Path $filePath -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        foreach ($sp in $secretPatterns) {
            if ($line -match $sp.Pattern) {
                Write-Error "Credential leak detected in $filePath! ($($sp.Kind)). Aborting sync."
                exit 1
            }
        }
    }
}

# 2. Sync Global Prompt & Rules
if (Test-Path "$geminiHome\GEMINI.md") {
    Assert-NoCredentialsInFile "$geminiHome\GEMINI.md"
    Copy-Item "$geminiHome\GEMINI.md" "$scriptRoot\GEMINI.md" -Force
    Write-Host "[OK] Synced GEMINI.md" -ForegroundColor Green
}

# 3. Sync Custom Agents
if (Test-Path "$configHome\agents") {
    $dstAgents = "$scriptRoot\config\agents"
    New-Item -ItemType Directory -Force -Path $dstAgents | Out-Null
    Copy-Item -Path "$configHome\agents\*" -Destination $dstAgents -Recurse -Force
    $agentCount = (Get-ChildItem -Path $dstAgents -Directory).Count
    Write-Host "[OK] Synced $agentCount Custom Agents" -ForegroundColor Green
}

# 4. Sync Custom Skills
if (Test-Path "$configHome\skills") {
    $dstSkills = "$scriptRoot\config\skills"
    New-Item -ItemType Directory -Force -Path $dstSkills | Out-Null
    Copy-Item -Path "$configHome\skills\*" -Destination $dstSkills -Recurse -Force
    $skillCount = (Get-ChildItem -Path $dstSkills -Directory).Count
    Write-Host "[OK] Synced $skillCount Custom Skills (spec-kit, gh-workflow, ponytail, audit, etc.)" -ForegroundColor Green
}

# 5. Sync Custom Plugins (exclude official marketplace plugins)
$officialPlugins = @("chrome-devtools-plugin", "modern-web-guidance-plugin", "android-cli-plugin")
if (Test-Path "$configHome\plugins") {
    $dstPlugins = "$scriptRoot\config\plugins"
    New-Item -ItemType Directory -Force -Path $dstPlugins | Out-Null
    Get-ChildItem -Path "$configHome\plugins" -Directory | Where-Object { $_.Name -notin $officialPlugins } | ForEach-Object {
        $targetDir = "$dstPlugins\$($_.Name)"
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        Copy-Item -Path "$($_.FullName)\*" -Destination $targetDir -Recurse -Force
    }
    # Remove nested .git if any
    Get-ChildItem -Path $dstPlugins -Filter ".git" -Recurse -Directory -Hidden -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    $pluginCount = (Get-ChildItem -Path $dstPlugins -Directory).Count
    Write-Host "[OK] Synced $pluginCount Custom Plugins (excluding official marketplace plugins)" -ForegroundColor Green
}

# 6. Sync Architectural Decision Records (ADRs)
if (Test-Path "$configHome\docs\adr") {
    $dstAdr = "$scriptRoot\docs\adr"
    New-Item -ItemType Directory -Force -Path $dstAdr | Out-Null
    Copy-Item -Path "$configHome\docs\adr\*" -Destination $dstAdr -Recurse -Force
    $adrCount = (Get-ChildItem -Path $dstAdr -Filter "*.md" | Where-Object { $_.Name -ne "README.md" }).Count
    Write-Host "[OK] Synced $adrCount Architectural Decision Records (ADRs)" -ForegroundColor Green
}

# 7. Comprehensive Recursive Credential Scan across all tracked file types
Write-Host ">>> Running recursive credential scanner across all synchronized files..." -ForegroundColor Cyan
$scanTargets = Get-ChildItem -Path "$scriptRoot\config", "$scriptRoot\docs" -Recurse -File -Include "*.md", "*.json", "*.ps1", "*.mjs", "*.py", "*.yml", "*.yaml"
foreach ($target in $scanTargets) {
    Assert-NoCredentialsInFile $target.FullName
}
Write-Host "[PASS] All synchronized files clean: zero credentials or secrets detected." -ForegroundColor Green

Write-Host ">>> Everyday-AGY sync completed successfully!" -ForegroundColor Green
