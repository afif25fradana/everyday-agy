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
    @{ Kind = "Quoted Credential assignment"; Pattern = '["'']?(?:api[_-]?key|access[_-]?token|secret[_-]?key|token)["'']?\s*[:=]\s*["''](?!<)[^\s"'']{16,}["'']' },
    @{ Kind = "Unquoted Key Assignment"; Pattern = '(?m)^\s*(?:[A-Za-z0-9_]*_)?(?:api[_-]?key|access[_-]?token|secret[_-]?key)\s*[:=]\s*(?!<)[A-Za-z0-9_\-\.]{20,}\s*$' },
    @{ Kind = "GitHub Token"; Pattern = '\b(ghp|github_pat|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{20,}' },
    @{ Kind = "Private Key Header"; Pattern = '-----BEGIN\s+([A-Z0-9_-]+\s+)?PRIVATE\s+KEY-----' },
    @{ Kind = "Cloud API Key"; Pattern = '\b(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z\-_]{35}|sk-ant-(?:api|admin)\d{2}-[a-zA-Z0-9_-]{30,}|sk-(?:proj|svcacct|admin)-[a-zA-Z0-9_-]{30,}|sk-[a-zA-Z0-9]{20,})\b' },
    @{ Kind = "JWT Token"; Pattern = '\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b' }
)

$binaryExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.webp', '.woff', '.woff2', '.ttf', '.otf', '.zip', '.pdf')

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
                Write-Error "Credential leak detected in source deployment file: $filePath! ($($sp.Kind)). Restore aborted."
                exit 1
            }
        }
    }
}

Write-Host ">>> Running pre-flight credential audit on deployment files..." -ForegroundColor Cyan
$deployScanTargets = @(
    (Join-Path $scriptRoot "README.md"),
    (Join-Path $scriptRoot "TOOLKIT.md"),
    (Join-Path $scriptRoot "config"),
    (Join-Path $scriptRoot "docs")
) | Where-Object { Test-Path $_ }

if ($deployScanTargets) {
    $deployFiles = Get-ChildItem -Path $deployScanTargets -Recurse -File -Force | Where-Object { $_.Extension.ToLowerInvariant() -notin $binaryExtensions }
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
$hooksJsonPath = Join-Path $configHome "hooks.json"
$configScripts = Join-Path $configHome "scripts"
$configAgents = Join-Path $configHome "agents"
$configSkills = Join-Path $configHome "skills"
$docsAdr = Join-Path (Join-Path $geminiHome "docs") "adr"
$legacyAdr = Join-Path (Join-Path $configHome "docs") "adr"
$needsBackup = (Test-Path $geminiMdPath) -or (Test-Path $hooksJsonPath) -or (Test-Path $configScripts) -or (Test-Path $configAgents) -or (Test-Path $configSkills) -or (Test-Path $docsAdr) -or (Test-Path $legacyAdr)

if ($needsBackup) {
    Write-Host ">>> Existing configuration detected. Creating backup at $backupDir..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
    if (Test-Path $geminiMdPath) {
        Copy-Item $geminiMdPath (Join-Path $backupDir "GEMINI.md") -Force
    }
    if (Test-Path $hooksJsonPath) {
        Copy-Item $hooksJsonPath (Join-Path $backupDir "hooks.json") -Force
    }
    if (Test-Path $configScripts) {
        Copy-Item -Path $configScripts -Destination (Join-Path $backupDir "scripts") -Recurse -Force
    }
    if (Test-Path $configAgents) {
        Copy-Item -Path $configAgents -Destination (Join-Path $backupDir "agents") -Recurse -Force
    }
    if (Test-Path $configSkills) {
        Copy-Item -Path $configSkills -Destination (Join-Path $backupDir "skills") -Recurse -Force
    }
    if (Test-Path $docsAdr) {
        Copy-Item -Path $docsAdr -Destination (Join-Path $backupDir "adr") -Recurse -Force
    }
    if (Test-Path $legacyAdr) {
        Copy-Item -Path $legacyAdr -Destination (Join-Path $backupDir "legacy_adr") -Recurse -Force
    }
    Write-Host "[OK] Backup created successfully." -ForegroundColor Green
}

# 1. Restore Global Prompt & Rules
$srcGeminiMd = Join-Path (Join-Path $scriptRoot "config") "GEMINI.md"
if (Test-Path $srcGeminiMd) {
    Copy-Item $srcGeminiMd $geminiMdPath -Force
    Write-Host "[OK] Restored GEMINI.md" -ForegroundColor Green
}

# 2. Restore Hooks Configuration & Scripts
$srcHooksJson = Join-Path (Join-Path $scriptRoot "config") "hooks.json"
if (Test-Path $srcHooksJson) {
    Copy-Item $srcHooksJson $hooksJsonPath -Force
    Write-Host "[OK] Restored hooks.json" -ForegroundColor Green
}

$srcScripts = Join-Path (Join-Path $scriptRoot "config") "scripts"
if (Test-Path $srcScripts) {
    $dstScripts = Join-Path $configHome "scripts"
    New-Item -ItemType Directory -Force -Path $dstScripts | Out-Null
    $srcScriptFiles = @(Get-ChildItem -Path $srcScripts -Recurse -File)
    if ($srcScriptFiles.Count -gt 0) {
        Copy-Item -Path (Join-Path $srcScripts "*") -Destination $dstScripts -Recurse -Force
    }
    Write-Host "[OK] Restored $($srcScriptFiles.Count) Config Scripts" -ForegroundColor Green
}

# 3. Restore Custom Agents (preserve user/external agents; prune only retired repo-owned agents)
$srcAgents = Join-Path (Join-Path $scriptRoot "config") "agents"
if (Test-Path $srcAgents) {
    $dstAgents = Join-Path $configHome "agents"
    New-Item -ItemType Directory -Force -Path $dstAgents | Out-Null
    $retiredRepoAgents = @("database-reviewer")
    foreach ($retiredAgent in $retiredRepoAgents) {
        $retiredPath = Join-Path $dstAgents $retiredAgent
        if (Test-Path -LiteralPath $retiredPath) {
            Remove-Item -LiteralPath $retiredPath -Recurse -Force
            Write-Host "[CLEANUP] Pruned retired repo agent: $retiredAgent" -ForegroundColor DarkGray
        }
    }
    $srcAgentDirs = @(Get-ChildItem -Path $srcAgents -Directory)
    foreach ($aDir in $srcAgentDirs) {
        $targetDir = Join-Path $dstAgents $aDir.Name
        if (Test-Path $targetDir) {
            $srcFiles = @(Get-ChildItem -LiteralPath $aDir.FullName -Recurse -File | ForEach-Object {
                $_.FullName.Substring($aDir.FullName.Length).Replace('\', '/')
            })
            Get-ChildItem -LiteralPath $targetDir -Recurse -File | ForEach-Object {
                $rel = $_.FullName.Substring($targetDir.Length).Replace('\', '/')
                if ($rel -notin $srcFiles) {
                    Remove-Item -LiteralPath $_.FullName -Force
                    Write-Host "[CLEANUP] Pruned orphan agent file: $($aDir.Name)$rel" -ForegroundColor DarkGray
                }
            }
        } else {
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        }
        if (@(Get-ChildItem -Path $aDir.FullName -Force).Count -gt 0) {
            Copy-Item -Path (Join-Path $aDir.FullName "*") -Destination $targetDir -Recurse -Force
        }
    }
    Write-Host "[OK] Restored $($srcAgentDirs.Count) Custom Agents" -ForegroundColor Green
}

# 4. Restore Custom Skills (preserve external skills; prune only retired repo-owned skills and orphan files within tracked skills)
$srcSkills = Join-Path (Join-Path $scriptRoot "config") "skills"
if (Test-Path $srcSkills) {
    $dstSkills = Join-Path $configHome "skills"
    New-Item -ItemType Directory -Force -Path $dstSkills | Out-Null
    $retiredRepoSkills = @("audit-dev-workflow")
    foreach ($retiredSkill in $retiredRepoSkills) {
        $retiredPath = Join-Path $dstSkills $retiredSkill
        if (Test-Path -LiteralPath $retiredPath) {
            Remove-Item -LiteralPath $retiredPath -Recurse -Force
            Write-Host "[CLEANUP] Pruned retired repo skill: $retiredSkill" -ForegroundColor DarkGray
        }
    }
    $srcSkillDirs = @(Get-ChildItem -Path $srcSkills -Directory)
    foreach ($sDir in $srcSkillDirs) {
        $targetDir = Join-Path $dstSkills $sDir.Name
        if (Test-Path $targetDir) {
            $srcFiles = @(Get-ChildItem -LiteralPath $sDir.FullName -Recurse -File | ForEach-Object {
                $_.FullName.Substring($sDir.FullName.Length).Replace('\', '/')
            })
            Get-ChildItem -LiteralPath $targetDir -Recurse -File | ForEach-Object {
                $rel = $_.FullName.Substring($targetDir.Length).Replace('\', '/')
                if ($rel -notin $srcFiles) {
                    Remove-Item -LiteralPath $_.FullName -Force
                    Write-Host "[CLEANUP] Pruned orphan skill file: $($sDir.Name)$rel" -ForegroundColor DarkGray
                }
            }
            Get-ChildItem -LiteralPath $targetDir -Recurse -Directory | Sort-Object -Property FullName -Descending | ForEach-Object {
                if (@(Get-ChildItem -LiteralPath $_.FullName -Force).Count -eq 0) {
                    Remove-Item -LiteralPath $_.FullName -Force
                }
            }
        } else {
            New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
        }
        if (@(Get-ChildItem -Path $sDir.FullName -Force).Count -gt 0) {
            Copy-Item -Path (Join-Path $sDir.FullName "*") -Destination $targetDir -Recurse -Force
        }
    }
    Write-Host "[OK] Restored $($srcSkillDirs.Count) Custom Skills" -ForegroundColor Green
}

# 5. Restore Architectural Decision Records (ADRs)
$srcAdr = Join-Path (Join-Path $scriptRoot "docs") "adr"
if (Test-Path $srcAdr) {
    $dstAdr = Join-Path (Join-Path $geminiHome "docs") "adr"
    New-Item -ItemType Directory -Force -Path $dstAdr | Out-Null

    $legacyAdr = Join-Path (Join-Path $configHome "docs") "adr"
    if (Test-Path $legacyAdr) {
        Remove-Item -Path $legacyAdr -Recurse -Force
        Write-Host "[CLEANUP] Pruned legacy ADR path: $legacyAdr" -ForegroundColor DarkGray
    }

    $srcAdrNames = @(Get-ChildItem -Path $srcAdr -Filter "*.md" | ForEach-Object { $_.Name })
    if ($srcAdrNames.Count -gt 0) {
        Get-ChildItem -Path $dstAdr -Filter "*.md" | ForEach-Object {
            if ($_.Name -notin $srcAdrNames) {
                Remove-Item -Path $_.FullName -Force
                Write-Host "[CLEANUP] Pruned stale ADR: $($_.Name)" -ForegroundColor DarkGray
            }
        }
        Copy-Item -Path (Join-Path $srcAdr "*") -Destination $dstAdr -Recurse -Force
    }
    $adrCount = (Get-ChildItem -Path $dstAdr -Filter "*.md" | Where-Object { $_.Name -ne "README.md" }).Count
    Write-Host "[OK] Restored $adrCount Architectural Decision Records (ADRs)" -ForegroundColor Green
}

Write-Host ">>> Everyday-AGY restoration completed successfully!" -ForegroundColor Green
Write-Host ">>> Note: For Context7 MCP setup, refer to README.md and TOOLKIT.md." -ForegroundColor Yellow
Write-Host ">>> Tip: Recommended upstream skills & plugins (refer to official docs for Antigravity install):" -ForegroundColor Cyan
Write-Host "    - Taste-Skill (design-taste-frontend): https://github.com/Leonxlnx/taste-skill" -ForegroundColor DarkGray
Write-Host "    - Ponytail (lazy dev mode & audits):  https://github.com/DietrichGebert/ponytail" -ForegroundColor DarkGray
Write-Host "    - Anti-Slop (clean copywriting & UI): https://github.com/miqdadbadjuber/anti-slop" -ForegroundColor DarkGray
Write-Host "    - Chrome DevTools & Web Guidance:     Install via Antigravity Marketplace" -ForegroundColor DarkGray
