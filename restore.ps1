# Everyday-AGY Restore Script
# Deploys configurations from this repository into ~/.gemini/
$ErrorActionPreference = "Stop"

Write-Host ">>> Restoring Antigravity configuration to ~/.gemini/..." -ForegroundColor Cyan

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Get-Location }

$geminiHome = "$env:USERPROFILE\.gemini"
$configHome = "$geminiHome\config"

# Ensure target directories exist
New-Item -ItemType Directory -Force -Path $geminiHome | Out-Null
New-Item -ItemType Directory -Force -Path $configHome | Out-Null

# Backup existing configuration if present to avoid accidental data loss
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$backupDir = "$geminiHome\backup_$timestamp"
$needsBackup = (Test-Path "$geminiHome\GEMINI.md") -or (Test-Path "$configHome\agents") -or (Test-Path "$configHome\skills")

if ($needsBackup) {
    Write-Host ">>> Existing configuration detected. Creating backup at $backupDir..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    if (Test-Path "$geminiHome\GEMINI.md") {
        Copy-Item "$geminiHome\GEMINI.md" "$backupDir\GEMINI.md" -Force
    }
    if (Test-Path "$configHome\agents") {
        Copy-Item -Path "$configHome\agents" -Destination "$backupDir\agents" -Recurse -Force
    }
    if (Test-Path "$configHome\skills") {
        Copy-Item -Path "$configHome\skills" -Destination "$backupDir\skills" -Recurse -Force
    }
    Write-Host "[OK] Backup created successfully." -ForegroundColor Green
}

# 1. Restore Global Prompt & Rules
if (Test-Path "$scriptRoot\GEMINI.md") {
    Copy-Item "$scriptRoot\GEMINI.md" "$geminiHome\GEMINI.md" -Force
    Write-Host "[OK] Restored GEMINI.md" -ForegroundColor Green
}

# 2. Restore Custom Agents
if (Test-Path "$scriptRoot\config\agents") {
    $dstAgents = "$configHome\agents"
    New-Item -ItemType Directory -Force -Path $dstAgents | Out-Null
    Copy-Item -Path "$scriptRoot\config\agents\*" -Destination $dstAgents -Recurse -Force
    Write-Host "[OK] Restored Custom Agents" -ForegroundColor Green
}

# 3. Restore Custom Skills
if (Test-Path "$scriptRoot\config\skills") {
    $dstSkills = "$configHome\skills"
    New-Item -ItemType Directory -Force -Path $dstSkills | Out-Null
    Copy-Item -Path "$scriptRoot\config\skills\*" -Destination $dstSkills -Recurse -Force
    Write-Host "[OK] Restored Custom Skills" -ForegroundColor Green
}

# 4. Restore Plugins
if (Test-Path "$scriptRoot\config\plugins") {
    $dstPlugins = "$configHome\plugins"
    New-Item -ItemType Directory -Force -Path $dstPlugins | Out-Null
    Copy-Item -Path "$scriptRoot\config\plugins\*" -Destination $dstPlugins -Recurse -Force
    Write-Host "[OK] Restored Plugins" -ForegroundColor Green
}

# 5. Restore Architectural Decision Records (ADRs)
if (Test-Path "$scriptRoot\docs\adr") {
    $dstAdr = "$configHome\docs\adr"
    New-Item -ItemType Directory -Force -Path $dstAdr | Out-Null
    Copy-Item -Path "$scriptRoot\docs\adr\*" -Destination $dstAdr -Recurse -Force
    Write-Host "[OK] Restored Architectural Decision Records (ADRs)" -ForegroundColor Green
}

Write-Host ">>> Everyday-AGY restoration completed successfully!" -ForegroundColor Green
Write-Host ">>> Note: For Context7 MCP setup, refer to README.md and TOOLKIT.md." -ForegroundColor Yellow
