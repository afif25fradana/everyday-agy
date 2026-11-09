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
    @{ Kind = "Quoted Credential assignment"; Pattern = '["'']?(?:api[_-]?key|access[_-]?token|secret[_-]?key|token)["'']?\s*[:=]\s*["''](?!<)[^\s"'']{16,}["'']' },
    @{ Kind = "Unquoted Key Assignment"; Pattern = '(?m)^\s*(?:[A-Za-z0-9_]*_)?(?:api[_-]?key|access[_-]?token|secret[_-]?key)\s*[:=]\s*(?!<)[A-Za-z0-9_\-\.]{20,}\s*$' },
    @{ Kind = "GitHub Token"; Pattern = '\b(ghp|github_pat|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{20,}' },
    @{ Kind = "Private Key Header"; Pattern = '-----BEGIN\s+([A-Z0-9_-]+\s+)?PRIVATE\s+KEY-----' },
    @{ Kind = "Cloud API Key"; Pattern = '\b(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z\-_]{35}|sk-ant-(?:api|admin)\d{2}-[a-zA-Z0-9_-]{30,}|sk-(?:proj|svcacct|admin)-[a-zA-Z0-9_-]{30,}|sk-[a-zA-Z0-9]{20,})\b' },
    @{ Kind = "JWT Token"; Pattern = '\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b' }
)

$binaryExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.webp', '.woff', '.woff2', '.ttf', '.otf', '.zip', '.pdf')

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
    if (-not (Test-Path -LiteralPath $filePath)) { return }
    try {
        $lines = Get-Content -LiteralPath $filePath -ErrorAction Stop
    } catch {
        Write-Error "Security Audit Failure: Unable to read file for credential verification ($filePath): $($_.Exception.Message). Aborting to prevent credential leaks."
        exit 1
    }
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

# 1c. Scan all candidate source files (excluding external decoupled skills and binary assets)
$allSkillsDir = Join-Path $configHome "skills"
$customSkillDirs = if (Test-Path $allSkillsDir) {
    Get-ChildItem -Path $allSkillsDir -Directory | Where-Object { $_.Name -notin $externalSkills } | Select-Object -ExpandProperty FullName
} else { @() }

$sourceScanTargets = @(
    (Join-Path $configHome "agents"),
    (Join-Path (Join-Path $geminiHome "docs") "adr"),
    (Join-Path (Join-Path $configHome "docs") "adr")
) + $customSkillDirs + $customPluginDirs | Where-Object { $_ -and (Test-Path $_) }

if ($sourceScanTargets) {
    $sourceFiles = Get-ChildItem -Path $sourceScanTargets -Recurse -File -Force | Where-Object { $_.Extension.ToLowerInvariant() -notin $binaryExtensions }
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
    Copy-Item $srcGeminiMd (Join-Path (Join-Path $scriptRoot "config") "GEMINI.md") -Force
    Write-Host "[OK] Synced GEMINI.md to config/GEMINI.md" -ForegroundColor Green
}

# 3. Sync Custom Agents
$srcAgents = Join-Path $configHome "agents"
if (Test-Path $srcAgents) {
    $dstAgents = Join-Path (Join-Path $scriptRoot "config") "agents"
    New-Item -ItemType Directory -Force -Path $dstAgents | Out-Null
    # Prune repo agents that no longer exist in configHome (prevent zombie resurrection)
    $activeAgentNames = @(Get-ChildItem -Path $srcAgents -Directory | ForEach-Object { $_.Name })
    Get-ChildItem -Path $dstAgents -Directory | ForEach-Object {
        if ($_.Name -notin $activeAgentNames) {
            Remove-Item -Path $_.FullName -Recurse -Force
            Write-Host "[CLEANUP] Pruned deleted agent from repo: $($_.Name)" -ForegroundColor DarkGray
        }
    }
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
    $activeCustomSkillNames = @($customSkills | ForEach-Object { $_.Name })
    Get-ChildItem -Path $dstSkills -Directory | ForEach-Object {
        if ($_.Name -notin $activeCustomSkillNames) {
            Remove-Item -Path $_.FullName -Recurse -Force
            Write-Host "[CLEANUP] Pruned deleted skill from repo: $($_.Name)" -ForegroundColor DarkGray
        }
    }
    foreach ($cs in $customSkills) {
        $targetDir = Join-Path $dstSkills $cs.Name
        if (Test-Path $targetDir) {
            # Prune orphan files inside tracked skill directory
            $srcFiles = @(Get-ChildItem -Path $cs.FullName -Recurse -File | ForEach-Object {
                $_.FullName.Substring($cs.FullName.Length)
            })
            Get-ChildItem -Path $targetDir -Recurse -File | ForEach-Object {
                $rel = $_.FullName.Substring($targetDir.Length)
                if ($rel -notin $srcFiles) {
                    Remove-Item -Path $_.FullName -Force
                    Write-Host "[CLEANUP] Pruned orphan skill file from repo: $($cs.Name)$rel" -ForegroundColor DarkGray
                }
            }
        } else {
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        }
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
$srcAdrsDir = Join-Path (Join-Path $geminiHome "docs") "adr"
if (-not (Test-Path $srcAdrsDir)) {
    # Fallback to legacy path during migration
    $srcAdrsDir = Join-Path (Join-Path $configHome "docs") "adr"
}
if (Test-Path $srcAdrsDir) {
    $srcAdrs = Get-ChildItem -Path $srcAdrsDir -Filter "*.md"
    if ($srcAdrs.Count -gt 0) {
        $dstAdr = Join-Path (Join-Path $scriptRoot "docs") "adr"
        New-Item -ItemType Directory -Force -Path $dstAdr | Out-Null
        $srcAdrNames = @(Get-ChildItem -Path $srcAdrsDir -Filter "*.md" | ForEach-Object { $_.Name })
        Get-ChildItem -Path $dstAdr -Filter "*.md" | ForEach-Object {
            if ($_.Name -notin $srcAdrNames) {
                Remove-Item -Path $_.FullName -Force
                Write-Host "[CLEANUP] Pruned stale ADR: $($_.Name)" -ForegroundColor DarkGray
            }
        }
        Copy-Item -Path (Join-Path $srcAdrsDir "*") -Destination $dstAdr -Recurse -Force
        $adrCount = (Get-ChildItem -Path $dstAdr -Filter "*.md" | Where-Object { $_.Name -ne "README.md" }).Count
        Write-Host "[OK] Synced $adrCount Architectural Decision Records (ADRs)" -ForegroundColor Green
    }
}

Write-Host ">>> Everyday-AGY sync completed successfully!" -ForegroundColor Green
