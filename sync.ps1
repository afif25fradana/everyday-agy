# Everyday-AGY Sync Script
# Pulls active live configurations from ~/.gemini/ into this repository
$ErrorActionPreference = "Stop"

Write-Host ">>> Starting Everyday-AGY pre-flight sync..." -ForegroundColor Cyan

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = (Get-Location).Path }

# Cross-platform ~/.gemini/ directory resolution (Windows, macOS, Linux pwsh)
$userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$geminiHome = Join-Path $userHome ".gemini"
$configHome = Join-Path $geminiHome "config"

if (-not (Test-Path $geminiHome)) {
    Write-Error "Antigravity home directory not found at $geminiHome! Aborting sync."
    exit 1
}

# 1. Credential Scanner Definition
$secretPatterns = @(
    @{ Kind = "Bearer token"; Pattern = 'Bearer\s+(?!<)[A-Za-z0-9_\-\.]{12,}' },
    @{ Kind = "Credential assignment"; Pattern = '["'']?(?:api[_-]?key|access[_-]?token|secret[_-]?key|token)["'']?\s*[:=]\s*["''](?!<)[^\s"'']{16,}["'']' }
)

# Plugins excluded from sync (maintained by official Antigravity Marketplace or external installers)
$officialPlugins = @("chrome-devtools-plugin", "modern-web-guidance-plugin", "android-cli-plugin", "antislop")

function Assert-NoCredentialsInFile($filePath) {
    if (-not (Test-Path $filePath)) { return }
    $lines = Get-Content -Path $filePath -ErrorAction SilentlyContinue
    foreach ($line in $lines) {
        foreach ($sp in $secretPatterns) {
            if ($line -match $sp.Pattern) {
                Write-Error "Credential leak detected at source: $filePath! ($($sp.Kind)). Sync aborted before copying."
                exit 1
            }
        }
    }
}

# ==============================================================================
# PHASE 1: PRE-FLIGHT CREDENTIAL SCAN AT SOURCE (~/.gemini/)
# Scans all source candidate files BEFORE touching repository disk
# ==============================================================================
Write-Host ">>> Running pre-flight credential audit on source files ($geminiHome)..." -ForegroundColor Cyan

# 1a. Scan GEMINI.md at source
if (Test-Path "$geminiHome\GEMINI.md") {
    Assert-NoCredentialsInFile "$geminiHome\GEMINI.md"
}

# 1b. Scan custom plugins at source (excluding official marketplace plugins)
$customPluginDirs = if (Test-Path "$configHome\plugins") {
    Get-ChildItem -Path "$configHome\plugins" -Directory | Where-Object { $_.Name -notin $officialPlugins } | Select-Object -ExpandProperty FullName
} else { @() }

# 1c. Scan all custom text files across candidate source directories
$sourceScanTargets = @(
    "$configHome\agents",
    "$configHome\skills",
    "$configHome\docs\adr"
) + $customPluginDirs | Where-Object { $_ -and (Test-Path $_) }

if ($sourceScanTargets) {
    $sourceFiles = Get-ChildItem -Path $sourceScanTargets -Recurse -File -Include "*.md", "*.json", "*.ps1", "*.mjs", "*.py", "*.yml", "*.yaml", "LICENSE*"
    foreach ($sf in $sourceFiles) {
        Assert-NoCredentialsInFile $sf.FullName
    }
}

Write-Host "[PASS] Pre-flight audit clean: zero secrets detected in candidate source files." -ForegroundColor Green
Write-Host ">>> Proceeding to copy configurations into everyday-agy repository..." -ForegroundColor Cyan

# ==============================================================================
# PHASE 2: SYNCHRONIZATION
# ==============================================================================

# 2. Sync Global Prompt & Rules
if (Test-Path "$geminiHome\GEMINI.md") {
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

# 5. Sync Custom Plugins (exclude official marketplace and external plugins)
if (Test-Path "$configHome\plugins") {
    $customPluginList = Get-ChildItem -Path "$configHome\plugins" -Directory | Where-Object { $_.Name -notin $officialPlugins }
    if ($customPluginList.Count -gt 0) {
        $dstPlugins = "$scriptRoot\config\plugins"
        New-Item -ItemType Directory -Force -Path $dstPlugins | Out-Null
        $customPluginList | ForEach-Object {
            $targetDir = "$dstPlugins\$($_.Name)"
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
            Copy-Item -Path "$($_.FullName)\*" -Destination $targetDir -Recurse -Force
        }
        # Remove nested .git if any (scoped strictly to target plugin directories)
        $resolvedDst = (Resolve-Path $dstPlugins).Path
        Get-ChildItem -Path $dstPlugins -Filter ".git" -Recurse -Directory -Hidden -Force | ForEach-Object {
            if ($_.FullName.StartsWith($resolvedDst)) {
                Remove-Item -Path $_.FullName -Recurse -Force
            }
        }
        $pluginCount = (Get-ChildItem -Path $dstPlugins -Directory).Count
        Write-Host "[OK] Synced $pluginCount Custom Plugins" -ForegroundColor Green
    } else {
        Write-Host "[INFO] All active plugins are external (antislop, devtools); skipped syncing." -ForegroundColor DarkGray
    }
}

# 6. Sync Architectural Decision Records (ADRs)
if (Test-Path "$configHome\docs\adr") {
    $srcAdrs = Get-ChildItem -Path "$configHome\docs\adr" -Filter "*.md"
    if ($srcAdrs.Count -gt 0) {
        $dstAdr = "$scriptRoot\docs\adr"
        New-Item -ItemType Directory -Force -Path $dstAdr | Out-Null
        Copy-Item -Path "$configHome\docs\adr\*" -Destination $dstAdr -Recurse -Force
        $adrCount = (Get-ChildItem -Path $dstAdr -Filter "*.md" | Where-Object { $_.Name -ne "README.md" }).Count
        Write-Host "[OK] Synced $adrCount Architectural Decision Records (ADRs)" -ForegroundColor Green
    }
}

Write-Host ">>> Everyday-AGY sync completed successfully!" -ForegroundColor Green
