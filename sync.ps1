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

# Plugins and skills excluded from sync (maintained by upstream repositories with dedicated Antigravity installers)
$officialPlugins = @("chrome-devtools-plugin", "modern-web-guidance-plugin", "android-cli-plugin", "antislop", "context7")
$externalSkills = @(
    "design-taste-frontend",
    "ponytail",
    "ponytail-audit",
    "ponytail-debt",
    "ponytail-gain",
    "ponytail-help",
    "ponytail-review"
)

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
$srcGeminiMd = Join-Path $geminiHome "GEMINI.md"
if (Test-Path $srcGeminiMd) {
    Assert-NoCredentialsInFile $srcGeminiMd
}

# 1b. Scan custom plugins at source (excluding official marketplace plugins)
$pluginsDir = Join-Path $configHome "plugins"
$customPluginDirs = if (Test-Path $pluginsDir) {
    Get-ChildItem -Path $pluginsDir -Directory | Where-Object { $_.Name -notin $officialPlugins } | Select-Object -ExpandProperty FullName
} else { @() }

# 1c. Scan all custom text files across candidate source directories (excluding external decoupled skills)
$allSkillsDir = Join-Path $configHome "skills"
$customSkillDirs = if (Test-Path $allSkillsDir) {
    Get-ChildItem -Path $allSkillsDir -Directory | Where-Object { $_.Name -notin $externalSkills } | Select-Object -ExpandProperty FullName
} else { @() }

$sourceScanTargets = @(
    (Join-Path $configHome "agents"),
    (Join-Path (Join-Path $configHome "docs") "adr")
) + $customSkillDirs + $customPluginDirs | Where-Object { $_ -and (Test-Path $_) }

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
if (Test-Path $srcGeminiMd) {
    Copy-Item $srcGeminiMd (Join-Path $scriptRoot "GEMINI.md") -Force
    Write-Host "[OK] Synced GEMINI.md" -ForegroundColor Green
}

# 3. Sync Custom Agents
$srcAgents = Join-Path $configHome "agents"
if (Test-Path $srcAgents) {
    $dstAgents = Join-Path (Join-Path $scriptRoot "config") "agents"
    New-Item -ItemType Directory -Force -Path $dstAgents | Out-Null
    Copy-Item -Path (Join-Path $srcAgents "*") -Destination $dstAgents -Recurse -Force
    $agentCount = (Get-ChildItem -Path $dstAgents -Directory).Count
    Write-Host "[OK] Synced $agentCount Custom Agents" -ForegroundColor Green
}

# 4. Sync Custom Skills (excluding decoupled upstream skills)
$srcSkills = Join-Path $configHome "skills"
if (Test-Path $srcSkills) {
    $dstSkills = Join-Path (Join-Path $scriptRoot "config") "skills"
    New-Item -ItemType Directory -Force -Path $dstSkills | Out-Null
    $customSkills = Get-ChildItem -Path $srcSkills -Directory | Where-Object { $_.Name -notin $externalSkills }
    foreach ($cs in $customSkills) {
        $targetDir = Join-Path $dstSkills $cs.Name
        New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        Copy-Item -Path (Join-Path $cs.FullName "*") -Destination $targetDir -Recurse -Force
    }
    $skillCount = (Get-ChildItem -Path $dstSkills -Directory).Count
    Write-Host "[OK] Synced $skillCount Custom Skills (excluding decoupled upstream skills)" -ForegroundColor Green
}

# 5. Sync Custom Plugins (exclude official marketplace and external plugins)
if (Test-Path $pluginsDir) {
    $customPluginList = Get-ChildItem -Path $pluginsDir -Directory | Where-Object { $_.Name -notin $officialPlugins }
    if ($customPluginList.Count -gt 0) {
        $dstPlugins = Join-Path (Join-Path $scriptRoot "config") "plugins"
        New-Item -ItemType Directory -Force -Path $dstPlugins | Out-Null
        $customPluginList | ForEach-Object {
            $targetDir = Join-Path $dstPlugins $_.Name
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
            Copy-Item -Path (Join-Path $_.FullName "*") -Destination $targetDir -Recurse -Force
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
$srcAdrsDir = Join-Path (Join-Path $configHome "docs") "adr"
if (Test-Path $srcAdrsDir) {
    $srcAdrs = Get-ChildItem -Path $srcAdrsDir -Filter "*.md"
    if ($srcAdrs.Count -gt 0) {
        $dstAdr = Join-Path (Join-Path $scriptRoot "docs") "adr"
        New-Item -ItemType Directory -Force -Path $dstAdr | Out-Null
        Copy-Item -Path (Join-Path $srcAdrsDir "*") -Destination $dstAdr -Recurse -Force
        $adrCount = (Get-ChildItem -Path $dstAdr -Filter "*.md" | Where-Object { $_.Name -ne "README.md" }).Count
        Write-Host "[OK] Synced $adrCount Architectural Decision Records (ADRs)" -ForegroundColor Green
    }
}

Write-Host ">>> Everyday-AGY sync completed successfully!" -ForegroundColor Green
