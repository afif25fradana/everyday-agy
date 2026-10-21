# Everyday-AGY Sync Script
# Pulls active live configurations from ~/.gemini/ into this repository
$ErrorActionPreference = "Stop"

Write-Host ">>> Syncing active Antigravity configurations into everyday-agy..." -ForegroundColor Cyan

$scriptRoot = $PSScriptRoot
if (-not $scriptRoot) { $scriptRoot = Get-Location }

# 1. Credential Scanner: Ensure no live tokens leak into tracked files
$secretPatterns = @(
    @{ Kind = "Bearer token"; Pattern = 'Bearer\s+(?!<)[A-Za-z0-9_\-\.]{12,}' },
    @{ Kind = "Credential assignment"; Pattern = '["'']?(?:api[_-]?key|access[_-]?token|secret[_-]?key|token)["'']?\s*[:=]\s*["''](?!<)[^\s"'']{16,}["'']' }
)

$geminiHome = "$env:USERPROFILE\.gemini"
$configHome = "$geminiHome\config"

# 2. Sync Global Prompt & Rules
if (Test-Path "$geminiHome\GEMINI.md") {
    $content = Get-Content -Path "$geminiHome\GEMINI.md"
    foreach ($line in $content) {
        foreach ($sp in $secretPatterns) {
            if ($line -match $sp.Pattern) {
                Write-Error "Credential detected in $geminiHome\GEMINI.md! Aborting sync."
                exit 1
            }
        }
    }
    Copy-Item "$geminiHome\GEMINI.md" "$scriptRoot\GEMINI.md" -Force
    Write-Host "[OK] Synced GEMINI.md" -ForegroundColor Green
}

# 3. Sync Custom Agents
if (Test-Path "$configHome\agents") {
    $dstAgents = "$scriptRoot\config\agents"
    New-Item -ItemType Directory -Force -Path $dstAgents | Out-Null
    Copy-Item -Path "$configHome\agents\*" -Destination $dstAgents -Recurse -Force
    Write-Host "[OK] Synced 9 Custom Agents" -ForegroundColor Green
}

# 4. Sync Custom Skills
if (Test-Path "$configHome\skills") {
    $dstSkills = "$scriptRoot\config\skills"
    New-Item -ItemType Directory -Force -Path $dstSkills | Out-Null
    Copy-Item -Path "$configHome\skills\*" -Destination $dstSkills -Recurse -Force
    Write-Host "[OK] Synced Custom Skills (spec-kit, gh-workflow, ponytail, audit, etc.)" -ForegroundColor Green
}

# 5. Sync Custom Plugins (exclude official marketplace plugins)
$officialPlugins = @("chrome-devtools-plugin", "modern-web-guidance-plugin", "android-cli-plugin")
if (Test-Path "$configHome\plugins") {
    $dstPlugins = "$scriptRoot\config\plugins"
    New-Item -ItemType Directory -Force -Path $dstPlugins | Out-Null
    Get-ChildItem -Path "$configHome\plugins" -Directory | Where-Object { $_.Name -notin $officialPlugins } | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination "$dstPlugins\$($_.Name)" -Recurse -Force
    }
    # Remove nested .git if any
    Get-ChildItem -Path $dstPlugins -Filter ".git" -Recurse -Directory -Hidden -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "[OK] Synced Custom Plugins (excluding official marketplace plugins)" -ForegroundColor Green
}

# 6. Sync Architectural Decision Records (ADRs)
if (Test-Path "$configHome\docs\adr") {
    $dstAdr = "$scriptRoot\docs\adr"
    New-Item -ItemType Directory -Force -Path $dstAdr | Out-Null
    Copy-Item -Path "$configHome\docs\adr\*" -Destination $dstAdr -Recurse -Force
    Write-Host "[OK] Synced Architectural Decision Records (ADRs)" -ForegroundColor Green
}

Write-Host ">>> Everyday-AGY sync completed successfully!" -ForegroundColor Green
