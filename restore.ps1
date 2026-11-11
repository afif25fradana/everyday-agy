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
    @{ Kind = "Bearer token"; Pattern = '(?i)Bearer\s+(?!<)[A-Za-z0-9_\-\.+/=]{12,}' },
    @{ Kind = "Quoted Credential assignment"; Pattern = '(?i)(["'']?(?:[A-Za-z0-9_]*_)?(?:api[_-]?key|access[_-]?token|secret[_-]?key|token)[A-Za-z0-9_-]*["'']?\s*[:=]\s*["''])(?!<)[^\s"'']{16,}(["''])' },
    @{ Kind = "Unquoted Key Assignment"; Pattern = '(?mi)(^[+\-\s]*(?:[A-Za-z0-9_]*_)?(?:api[_-]?key|access[_-]?token|secret[_-]?key|token)(?:_[A-Za-z0-9_]+)?\s*[:=]\s*)(?!<)[A-Za-z0-9_\-\.+/=]{20,}(\s*$)' },
    @{ Kind = "GitHub Token"; Pattern = '\b(ghp|github_pat|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{20,}' },
    @{ Kind = "Private Key Header"; Pattern = '(?i)-----BEGIN\s+([A-Z0-9_-]+\s+)?PRIVATE\s+KEY-----' },
    @{ Kind = "Cloud API Key"; Pattern = '\b(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z\-_]{35}|sk-ant-(?:api|admin)\d{2}-[a-zA-Z0-9_-]{30,}|sk-(?:proj|svcacct|admin)-[a-zA-Z0-9_-]{30,}|sk-[a-zA-Z0-9]{20,})\b' },
    @{ Kind = "JWT Token"; Pattern = '\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b' }
)

$binaryExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.ico', '.webp', '.woff', '.woff2', '.ttf', '.otf', '.zip', '.pdf')

function Assert-NoCredentialsInFile($filePath) {
    if (-not (Test-Path -LiteralPath $filePath)) { return }
    try {
        $lines = Get-Content -LiteralPath $filePath -Encoding utf8 -ErrorAction Stop
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

function Copy-DirectoryContentsLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceDir,

        [Parameter(Mandatory = $true)]
        [string]$DestDir
    )
    if (-not (Test-Path -LiteralPath $SourceDir -PathType Container)) { return }
    $srcNormalized = $SourceDir.TrimEnd('\', '/')
    if (-not (Test-Path -LiteralPath $DestDir -PathType Container)) {
        $null = [System.IO.Directory]::CreateDirectory($DestDir)
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $srcNormalized -Recurse -File -Force)) {
        $rel = $file.FullName.Substring($srcNormalized.Length).TrimStart('\', '/')
        $targetFile = Join-Path $DestDir $rel
        $targetParent = Split-Path -Parent $targetFile
        if (-not (Test-Path -LiteralPath $targetParent -PathType Container)) {
            $null = [System.IO.Directory]::CreateDirectory($targetParent)
        }
        Copy-Item -LiteralPath $file.FullName -Destination $targetFile -Force
    }
}

Write-Host ">>> Running pre-flight credential audit on deployment files..." -ForegroundColor Cyan
$deployScanTargets = @(
    (Join-Path $scriptRoot "README.md"),
    (Join-Path $scriptRoot "TOOLKIT.md"),
    (Join-Path $scriptRoot "config"),
    (Join-Path $scriptRoot "docs")
) | Where-Object { Test-Path -LiteralPath $_ }

if ($deployScanTargets) {
    $deployFiles = @($deployScanTargets | ForEach-Object { if (Test-Path -LiteralPath $_ -PathType Leaf) { Get-Item -LiteralPath $_ -Force } else { Get-ChildItem -LiteralPath $_ -Recurse -File -Force } }) | Where-Object { $_.Extension.ToLowerInvariant() -notin $binaryExtensions }
    foreach ($df in $deployFiles) {
        Assert-NoCredentialsInFile $df.FullName
    }
}
Write-Host "[PASS] Pre-flight audit clean: zero unmasked credentials in source files." -ForegroundColor Green

# Ensure target directories exist
$null = [System.IO.Directory]::CreateDirectory($geminiHome)
$null = [System.IO.Directory]::CreateDirectory($configHome)

# Backup existing configuration if present to avoid accidental data loss
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$backupDir = Join-Path $geminiHome "backup_$timestamp"
$suffix = 1
while (Test-Path -LiteralPath $backupDir) {
    $backupDir = Join-Path $geminiHome "backup_${timestamp}_$suffix"
    $suffix++
}
$geminiMdPath = Join-Path $geminiHome "GEMINI.md"
$hooksJsonPath = Join-Path $configHome "hooks.json"
$configScripts = Join-Path $configHome "scripts"
$configAgents = Join-Path $configHome "agents"
$configSkills = Join-Path $configHome "skills"
$needsBackup = (Test-Path -LiteralPath $geminiMdPath) -or (Test-Path -LiteralPath $hooksJsonPath) -or (Test-Path -LiteralPath $configScripts) -or (Test-Path -LiteralPath $configAgents) -or (Test-Path -LiteralPath $configSkills)

if ($needsBackup) {
    Write-Host ">>> Existing configuration detected. Creating backup at $backupDir..." -ForegroundColor Yellow
    $null = [System.IO.Directory]::CreateDirectory($backupDir)
    if (Test-Path -LiteralPath $geminiMdPath) {
        Copy-Item -LiteralPath $geminiMdPath -Destination (Join-Path $backupDir "GEMINI.md") -Force
    }
    if (Test-Path -LiteralPath $hooksJsonPath) {
        Copy-Item -LiteralPath $hooksJsonPath -Destination (Join-Path $backupDir "hooks.json") -Force
    }
    if (Test-Path -LiteralPath $configScripts -PathType Container) {
        Copy-DirectoryContentsLiteral -SourceDir $configScripts -DestDir (Join-Path $backupDir "scripts")
    }
    if (Test-Path -LiteralPath $configAgents -PathType Container) {
        Copy-DirectoryContentsLiteral -SourceDir $configAgents -DestDir (Join-Path $backupDir "agents")
    }
    if (Test-Path -LiteralPath $configSkills -PathType Container) {
        Copy-DirectoryContentsLiteral -SourceDir $configSkills -DestDir (Join-Path $backupDir "skills")
    }
    Write-Host "[OK] Backup created successfully." -ForegroundColor Green
}

try {
# 1. Restore Global Prompt & Rules
$srcGeminiMd = Join-Path (Join-Path $scriptRoot "config") "GEMINI.md"
if (Test-Path -LiteralPath $srcGeminiMd) {
    Copy-Item -LiteralPath $srcGeminiMd -Destination $geminiMdPath -Force
    Write-Host "[OK] Restored GEMINI.md" -ForegroundColor Green
}

# 2. Restore Hooks Configuration & Scripts
$srcHooksJson = Join-Path (Join-Path $scriptRoot "config") "hooks.json"
if (Test-Path -LiteralPath $srcHooksJson) {
    Copy-Item -LiteralPath $srcHooksJson -Destination $hooksJsonPath -Force
    Write-Host "[OK] Restored hooks.json" -ForegroundColor Green
}

$srcScripts = Join-Path (Join-Path $scriptRoot "config") "scripts"
if (Test-Path -LiteralPath $srcScripts) {
    $dstScripts = Join-Path $configHome "scripts"
    $null = [System.IO.Directory]::CreateDirectory($dstScripts)
    $srcScriptFiles = @(Get-ChildItem -LiteralPath $srcScripts -Recurse -File -Force)
    $srcNormalized = $srcScripts.TrimEnd('\', '/')
    $dstNormalized = $dstScripts.TrimEnd('\', '/')
    $srcScriptRels = @($srcScriptFiles | ForEach-Object {
        $_.FullName.Substring($srcNormalized.Length).Replace('\', '/')
    })
    Get-ChildItem -LiteralPath $dstScripts -Recurse -File -Force | ForEach-Object {
        $rel = $_.FullName.Substring($dstNormalized.Length).Replace('\', '/')
        if ($rel -notin $srcScriptRels) {
            Remove-Item -LiteralPath $_.FullName -Force
            Write-Host "[CLEANUP] Pruned orphan script file: scripts$rel" -ForegroundColor DarkGray
        }
    }
    Get-ChildItem -LiteralPath $dstScripts -Recurse -Directory -Force | Sort-Object -Property FullName -Descending | ForEach-Object {
        if (@(Get-ChildItem -LiteralPath $_.FullName -Force).Count -eq 0) {
            Remove-Item -LiteralPath $_.FullName -Force
        }
    }
    if ($srcScriptFiles.Count -gt 0) {
        Copy-DirectoryContentsLiteral -SourceDir $srcScripts -DestDir $dstScripts
    }
    Write-Host "[OK] Restored $($srcScriptFiles.Count) Config Scripts" -ForegroundColor Green
}

# 3. Restore Custom Agents (preserve user/external agents; prune only retired repo-owned agents)
$srcAgents = Join-Path (Join-Path $scriptRoot "config") "agents"
if (Test-Path -LiteralPath $srcAgents) {
    $dstAgents = Join-Path $configHome "agents"
    $null = [System.IO.Directory]::CreateDirectory($dstAgents)
    $retiredRepoAgents = @("database-reviewer")
    foreach ($retiredAgent in $retiredRepoAgents) {
        $retiredPath = Join-Path $dstAgents $retiredAgent
        if (Test-Path -LiteralPath $retiredPath) {
            Remove-Item -LiteralPath $retiredPath -Recurse -Force
            Write-Host "[CLEANUP] Pruned retired repo agent: $retiredAgent" -ForegroundColor DarkGray
        }
    }
    $srcAgentDirs = @(Get-ChildItem -LiteralPath $srcAgents -Directory)
    foreach ($aDir in $srcAgentDirs) {
        $targetDir = Join-Path $dstAgents $aDir.Name
        if (Test-Path -LiteralPath $targetDir) {
            $srcFiles = @(Get-ChildItem -LiteralPath $aDir.FullName -Recurse -File -Force | ForEach-Object {
                $_.FullName.Substring($aDir.FullName.TrimEnd('\', '/').Length).Replace('\', '/')
            })
            Get-ChildItem -LiteralPath $targetDir -Recurse -File -Force | ForEach-Object {
                $rel = $_.FullName.Substring($targetDir.TrimEnd('\', '/').Length).Replace('\', '/')
                if ($rel -notin $srcFiles) {
                    Remove-Item -LiteralPath $_.FullName -Force
                    Write-Host "[CLEANUP] Pruned orphan agent file: $($aDir.Name)$rel" -ForegroundColor DarkGray
                }
            }
        } else {
            $null = [System.IO.Directory]::CreateDirectory($targetDir)
        }
        if (Test-Path -LiteralPath $targetDir -PathType Container) {
            Get-ChildItem -LiteralPath $targetDir -Recurse -Directory -Force | Sort-Object -Property FullName -Descending | ForEach-Object {
                if (@(Get-ChildItem -LiteralPath $_.FullName -Force).Count -eq 0) {
                    Remove-Item -LiteralPath $_.FullName -Force
                }
            }
        }
        if (@(Get-ChildItem -LiteralPath $aDir.FullName -Force).Count -gt 0) {
            Copy-DirectoryContentsLiteral -SourceDir $aDir.FullName -DestDir $targetDir
        }
    }
    Write-Host "[OK] Restored $($srcAgentDirs.Count) Custom Agents" -ForegroundColor Green
}

# 4. Restore Custom Skills (preserve external skills; prune only retired repo-owned skills and orphan files within tracked skills)
$srcSkills = Join-Path (Join-Path $scriptRoot "config") "skills"
if (Test-Path -LiteralPath $srcSkills) {
    $dstSkills = Join-Path $configHome "skills"
    $null = [System.IO.Directory]::CreateDirectory($dstSkills)
    $retiredRepoSkills = @("audit-dev-workflow")
    foreach ($retiredSkill in $retiredRepoSkills) {
        $retiredPath = Join-Path $dstSkills $retiredSkill
        if (Test-Path -LiteralPath $retiredPath) {
            Remove-Item -LiteralPath $retiredPath -Recurse -Force
            Write-Host "[CLEANUP] Pruned retired repo skill: $retiredSkill" -ForegroundColor DarkGray
        }
    }
    $srcSkillDirs = @(Get-ChildItem -LiteralPath $srcSkills -Directory)
    foreach ($sDir in $srcSkillDirs) {
        $targetDir = Join-Path $dstSkills $sDir.Name
        if (Test-Path -LiteralPath $targetDir) {
            $srcFiles = @(Get-ChildItem -LiteralPath $sDir.FullName -Recurse -File -Force | ForEach-Object {
                $_.FullName.Substring($sDir.FullName.TrimEnd('\', '/').Length).Replace('\', '/')
            })
            Get-ChildItem -LiteralPath $targetDir -Recurse -File -Force | ForEach-Object {
                $rel = $_.FullName.Substring($targetDir.TrimEnd('\', '/').Length).Replace('\', '/')
                if ($rel -notin $srcFiles) {
                    Remove-Item -LiteralPath $_.FullName -Force
                    Write-Host "[CLEANUP] Pruned orphan skill file: $($sDir.Name)$rel" -ForegroundColor DarkGray
                }
            }
            Get-ChildItem -LiteralPath $targetDir -Recurse -Directory -Force | Sort-Object -Property FullName -Descending | ForEach-Object {
                if (@(Get-ChildItem -LiteralPath $_.FullName -Force).Count -eq 0) {
                    Remove-Item -LiteralPath $_.FullName -Force
                }
            }
        } else {
            $null = [System.IO.Directory]::CreateDirectory($targetDir)
        }
        if (@(Get-ChildItem -LiteralPath $sDir.FullName -Force).Count -gt 0) {
            Copy-DirectoryContentsLiteral -SourceDir $sDir.FullName -DestDir $targetDir
        }
    }
    Write-Host "[OK] Restored $($srcSkillDirs.Count) Custom Skills" -ForegroundColor Green
}

# 5. Prune legacy ADR deployments (ADRs stay repo-only)
foreach ($docsParent in @((Join-Path $geminiHome "docs"), (Join-Path $configHome "docs"))) {
    $staleAdr = Join-Path $docsParent "adr"
    if (Test-Path -LiteralPath $staleAdr -PathType Container) {
        Remove-Item -LiteralPath $staleAdr -Recurse -Force
        Write-Host "[CLEANUP] Pruned legacy ADR path: $staleAdr" -ForegroundColor DarkGray
    }
    if ((Test-Path -LiteralPath $docsParent -PathType Container) -and (@(Get-ChildItem -LiteralPath $docsParent -Force).Count -eq 0)) {
        Remove-Item -LiteralPath $docsParent -Force
        Write-Host "[CLEANUP] Pruned empty docs directory: $docsParent" -ForegroundColor DarkGray
    }
}

} catch {
    $deployErr = $_.Exception.Message
    if ($needsBackup -and (Test-Path -LiteralPath $backupDir -PathType Container)) {
        Write-Host ">>> Deployment failed ($deployErr). Attempting best-effort rollback from $backupDir..." -ForegroundColor Yellow
        $bakGemini = Join-Path $backupDir "GEMINI.md"
        if (Test-Path -LiteralPath $bakGemini -PathType Leaf) {
            try { Copy-Item -LiteralPath $bakGemini -Destination $geminiMdPath -Force } catch { Write-Warning "Rollback warning while restoring GEMINI.md: $_" }
        }
        $bakHooks = Join-Path $backupDir "hooks.json"
        if (Test-Path -LiteralPath $bakHooks -PathType Leaf) {
            try { Copy-Item -LiteralPath $bakHooks -Destination $hooksJsonPath -Force } catch { Write-Warning "Rollback warning while restoring hooks.json: $_" }
        }
        foreach ($dirName in @("scripts", "agents", "skills")) {
            $bakSub = Join-Path $backupDir $dirName
            $dstSub = Join-Path $configHome $dirName
            if (Test-Path -LiteralPath $bakSub -PathType Container) {
                try { Copy-DirectoryContentsLiteral -SourceDir $bakSub -DestDir $dstSub } catch { Write-Warning "Rollback warning while restoring ${dirName}: $_" }
            }
        }
    }
    Write-Error "Deployment failed: $deployErr"
    exit 1
}

Write-Host ">>> Everyday-AGY restoration completed successfully!" -ForegroundColor Green
Write-Host ">>> Note: For Context7 MCP setup, refer to README.md and TOOLKIT.md." -ForegroundColor Yellow
Write-Host ">>> Tip: Recommended upstream skills & plugins (refer to official docs for Antigravity install):" -ForegroundColor Cyan
Write-Host "    - Taste-Skill (design-taste-frontend): https://github.com/Leonxlnx/taste-skill" -ForegroundColor DarkGray
Write-Host "    - Ponytail (lazy dev mode & audits):  https://github.com/DietrichGebert/ponytail" -ForegroundColor DarkGray
Write-Host "    - Anti-Slop (clean copywriting & UI): https://github.com/miqdadbadjuber/anti-slop" -ForegroundColor DarkGray
Write-Host "    - Chrome DevTools & Web Guidance:     Install via Antigravity Marketplace" -ForegroundColor DarkGray
