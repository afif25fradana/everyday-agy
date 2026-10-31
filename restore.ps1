# Everyday-AGY Restore Script
# Deploys configurations from this repository into ~/.gemini/
$ErrorActionPreference = "Stop"

Write-Host ">>> Restoring Antigravity configuration to ~/.gemini/..." -ForegroundColor Cyan

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = (Get-Location).Path }

# Cross-platform ~/.gemini/ directory resolution (Windows, macOS, Linux pwsh)
$userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$geminiHome = Join-Path $userHome ".gemini"
$configHome = Join-Path $geminiHome "config"

# 1. Credential Scanner Definition & Pre-Flight Verification
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
                Write-Error "Credential leak detected in source deployment file: $filePath! ($($sp.Kind)). Restore aborted."
                exit 1
            }
        }
    }
}

Write-Host ">>> Running pre-flight credential audit on deployment files..." -ForegroundColor Cyan
$deployScanTargets = @(
    (Join-Path $scriptRoot "GEMINI.md"),
    (Join-Path $scriptRoot "config"),
    (Join-Path $scriptRoot "docs")
) | Where-Object { Test-Path $_ }

if ($deployScanTargets) {
    $deployFiles = Get-ChildItem -Path $deployScanTargets -Recurse -File -Include "*.md", "*.json", "*.ps1", "*.mjs", "*.py", "*.yml", "*.yaml", "LICENSE*"
    foreach ($df in $deployFiles) {
        Assert-NoCredentialsInFile $df.FullName
    }
}
Write-Host "[PASS] Pre-flight audit clean: zero unmasked credentials in source files." -ForegroundColor Green

# Ensure target directories exist
New-Item -ItemType Directory -Force -Path $geminiHome | Out-Null
New-Item -ItemType Directory -Force -Path $configHome | Out-Null

# Backup existing configuration if present to avoid accidental data loss
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$backupDir = Join-Path $geminiHome "backup_$timestamp"
$geminiMdPath = Join-Path $geminiHome "GEMINI.md"
$configAgents = Join-Path $configHome "agents"
$configSkills = Join-Path $configHome "skills"
$configPlugins = Join-Path $configHome "plugins"
$needsBackup = (Test-Path $geminiMdPath) -or (Test-Path $configAgents) -or (Test-Path $configSkills) -or (Test-Path $configPlugins)

if ($needsBackup) {
    Write-Host ">>> Existing configuration detected. Creating backup at $backupDir..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    if (Test-Path $geminiMdPath) {
        Copy-Item $geminiMdPath (Join-Path $backupDir "GEMINI.md") -Force
    }
    if (Test-Path $configAgents) {
        Copy-Item -Path $configAgents -Destination (Join-Path $backupDir "agents") -Recurse -Force
    }
    if (Test-Path $configSkills) {
        Copy-Item -Path $configSkills -Destination (Join-Path $backupDir "skills") -Recurse -Force
    }
    if (Test-Path $configPlugins) {
        Copy-Item -Path $configPlugins -Destination (Join-Path $backupDir "plugins") -Recurse -Force
    }
    Write-Host "[OK] Backup created successfully." -ForegroundColor Green
}

# 1. Restore Global Prompt & Rules
$srcGeminiMd = Join-Path $scriptRoot "GEMINI.md"
if (Test-Path $srcGeminiMd) {
    Copy-Item $srcGeminiMd $geminiMdPath -Force
    Write-Host "[OK] Restored GEMINI.md" -ForegroundColor Green
}

# 2. Restore Custom Agents
$srcAgents = Join-Path (Join-Path $scriptRoot "config") "agents"
if (Test-Path $srcAgents) {
    $dstAgents = Join-Path $configHome "agents"
    New-Item -ItemType Directory -Force -Path $dstAgents | Out-Null
    Copy-Item -Path (Join-Path $srcAgents "*") -Destination $dstAgents -Recurse -Force
    $agentCount = (Get-ChildItem -Path $srcAgents -Directory).Count
    Write-Host "[OK] Restored $agentCount Custom Agents" -ForegroundColor Green
}

# 3. Restore Custom Skills
$srcSkills = Join-Path (Join-Path $scriptRoot "config") "skills"
if (Test-Path $srcSkills) {
    $dstSkills = Join-Path $configHome "skills"
    New-Item -ItemType Directory -Force -Path $dstSkills | Out-Null
    Copy-Item -Path (Join-Path $srcSkills "*") -Destination $dstSkills -Recurse -Force
    $skillCount = (Get-ChildItem -Path $srcSkills -Directory).Count
    Write-Host "[OK] Restored $skillCount Custom Skills" -ForegroundColor Green
}

# 4. Restore Custom Plugins (if any local custom plugins exist)
$srcPlugins = Join-Path (Join-Path $scriptRoot "config") "plugins"
if (Test-Path $srcPlugins) {
    $customPluginList = Get-ChildItem -Path $srcPlugins -Directory
    if ($customPluginList.Count -gt 0) {
        $dstPlugins = Join-Path $configHome "plugins"
        New-Item -ItemType Directory -Force -Path $dstPlugins | Out-Null
        Copy-Item -Path (Join-Path $srcPlugins "*") -Destination $dstPlugins -Recurse -Force
        $pluginCount = (Get-ChildItem -Path $dstPlugins -Directory).Count
        Write-Host "[OK] Restored $pluginCount Custom Plugins" -ForegroundColor Green
    }
}

# 5. Restore Architectural Decision Records (ADRs)
$srcAdr = Join-Path (Join-Path $scriptRoot "docs") "adr"
if (Test-Path $srcAdr) {
    $dstAdr = Join-Path (Join-Path $configHome "docs") "adr"
    New-Item -ItemType Directory -Force -Path $dstAdr | Out-Null
    Copy-Item -Path (Join-Path $srcAdr "*") -Destination $dstAdr -Recurse -Force
    $adrCount = (Get-ChildItem -Path $dstAdr -Filter "*.md" | Where-Object { $_.Name -ne "README.md" }).Count
    Write-Host "[OK] Restored $adrCount Architectural Decision Records (ADRs)" -ForegroundColor Green
}

Write-Host ">>> Everyday-AGY restoration completed successfully!" -ForegroundColor Green
Write-Host ">>> Note: For Context7 MCP setup, refer to README.md and TOOLKIT.md." -ForegroundColor Yellow
Write-Host ">>> Tip: Recommended upstream skills & plugins (refer to official docs for Antigravity install):" -ForegroundColor Cyan
Write-Host "    - Taste-Skill (design-taste-frontend): https://github.com/Leonxlnx/taste-skill" -ForegroundColor DarkGray
Write-Host "    - Ponytail (lazy dev mode & audits):  https://github.com/DietrichGebert/ponytail" -ForegroundColor DarkGray
Write-Host "    - Antislop (clean copywriting & UI):  https://github.com/antislop-ai/antislop" -ForegroundColor DarkGray
Write-Host "    - Chrome DevTools & Web Guidance:     Install via Antigravity Marketplace" -ForegroundColor DarkGray
