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

if (-not (Test-Path -LiteralPath $geminiHome)) {
    Write-Error "Antigravity home directory not found at $geminiHome! Aborting sync."
    exit 1
}

# 1. Credential Scanner Definition
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
                Write-Error "Credential leak detected at source: $filePath! ($($sp.Kind)). Sync aborted before copying."
                exit 1
            }
        }
    }
}

# Discover tracked targets strictly from this repository
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
$repoConfigDir = Join-Path $scriptRoot "config"
$dstGeminiMd = Join-Path $repoConfigDir "GEMINI.md"
$dstHooksJson = Join-Path $repoConfigDir "hooks.json"
$dstScripts = Join-Path $repoConfigDir "scripts"
$dstAgents = Join-Path $repoConfigDir "agents"
$dstSkills = Join-Path $repoConfigDir "skills"

$trackedAgentNames = if (Test-Path -LiteralPath $dstAgents) { @(Get-ChildItem -LiteralPath $dstAgents -Directory | ForEach-Object { $_.Name }) } else { @() }
$trackedSkillNames = if (Test-Path -LiteralPath $dstSkills) { @(Get-ChildItem -LiteralPath $dstSkills -Directory | ForEach-Object { $_.Name }) } else { @() }
$trackedScriptRels = if (Test-Path -LiteralPath $dstScripts) {
    @(Get-ChildItem -LiteralPath $dstScripts -Recurse -File -Force | ForEach-Object {
        $_.FullName.Substring($dstScripts.Length).TrimStart('\', '/').Replace('\', '/')
    })
} else { @() }

$srcGeminiMd = Join-Path $geminiHome "GEMINI.md"
$srcHooksJson = Join-Path $configHome "hooks.json"
$srcScriptsDir = Join-Path $configHome "scripts"
$srcAgentsDir = Join-Path $configHome "agents"
$srcSkillsDir = Join-Path $configHome "skills"

# ==============================================================================
# PHASE 1: PRE-FLIGHT CREDENTIAL SCAN AT SOURCE (~/.gemini/)
# Scans only tracked candidate source files BEFORE touching repository disk
# ==============================================================================
Write-Host ">>> Running pre-flight credential audit on tracked source files ($geminiHome)..." -ForegroundColor Cyan

if (Test-Path -LiteralPath $srcGeminiMd) {
    Assert-NoCredentialsInFile $srcGeminiMd
}
if (Test-Path -LiteralPath $srcHooksJson) {
    Assert-NoCredentialsInFile $srcHooksJson
}
foreach ($relScript in $trackedScriptRels) {
    $srcScriptFile = Join-Path $srcScriptsDir $relScript
    if (Test-Path -LiteralPath $srcScriptFile) {
        Assert-NoCredentialsInFile $srcScriptFile
    }
}

$trackedSourceDirs = @()
foreach ($aName in $trackedAgentNames) {
    $p = Join-Path $srcAgentsDir $aName
    if (Test-Path -LiteralPath $p) { $trackedSourceDirs += $p }
}
foreach ($sName in $trackedSkillNames) {
    $p = Join-Path $srcSkillsDir $sName
    if (Test-Path -LiteralPath $p) { $trackedSourceDirs += $p }
}

if ($trackedSourceDirs.Count -gt 0) {
    $sourceFiles = foreach ($td in $trackedSourceDirs) { Get-ChildItem -LiteralPath $td -Recurse -File -Force | Where-Object { $_.Extension.ToLowerInvariant() -notin $binaryExtensions } }
    foreach ($sf in $sourceFiles) {
        Assert-NoCredentialsInFile $sf.FullName
    }
}

Write-Host "[PASS] Pre-flight audit clean: zero secrets detected in tracked source files." -ForegroundColor Green
Write-Host ">>> Proceeding to copy configurations into everyday-agy repository..." -ForegroundColor Cyan

# ==============================================================================
# PHASE 2: REPO-SCOPED SYNCHRONIZATION
# ==============================================================================

# 1. Sync Global Prompt & Rules
if ((Test-Path -LiteralPath $srcGeminiMd) -and ((Get-Item -LiteralPath $srcGeminiMd).Length -gt 0)) {
    Copy-Item -LiteralPath $srcGeminiMd -Destination $dstGeminiMd -Force
    Write-Host "[OK] Synced GEMINI.md to config/GEMINI.md" -ForegroundColor Green
}

# 2. Sync Hooks Configuration & Tracked Scripts
if ((Test-Path -LiteralPath $srcHooksJson) -and ((Get-Item -LiteralPath $srcHooksJson).Length -gt 0)) {
    Copy-Item -LiteralPath $srcHooksJson -Destination $dstHooksJson -Force
    Write-Host "[OK] Synced hooks.json to config/hooks.json" -ForegroundColor Green
}

$syncedScripts = 0
foreach ($relScript in $trackedScriptRels) {
    $srcScriptFile = Join-Path $srcScriptsDir $relScript
    $dstScriptFile = Join-Path $dstScripts $relScript
    if ((Test-Path -LiteralPath $srcScriptFile) -and ((Get-Item -LiteralPath $srcScriptFile).Length -gt 0)) {
        $dstParent = Split-Path -Parent $dstScriptFile
        if (-not (Test-Path -LiteralPath $dstParent)) {
            $null = [System.IO.Directory]::CreateDirectory($dstParent)
        }
        Copy-Item -LiteralPath $srcScriptFile -Destination $dstScriptFile -Force
        $syncedScripts++
    }
}
Write-Host "[OK] Synced $syncedScripts Tracked Config Scripts" -ForegroundColor Green

# 3. Sync Tracked Custom Agents (guard against empty source deletion)
$syncedAgents = 0
foreach ($aName in $trackedAgentNames) {
    $srcAgentDir = Join-Path $srcAgentsDir $aName
    $dstAgentDir = Join-Path $dstAgents $aName
    if (Test-Path -LiteralPath $srcAgentDir) {
        $srcFiles = @(Get-ChildItem -LiteralPath $srcAgentDir -Recurse -File -Force | ForEach-Object {
            $_.FullName.Substring($srcAgentDir.TrimEnd('\', '/').Length).Replace('\', '/')
        })
        if ($srcFiles.Count -gt 0) {
            Get-ChildItem -LiteralPath $dstAgentDir -Recurse -File -Force | ForEach-Object {
                $rel = $_.FullName.Substring($dstAgentDir.TrimEnd('\', '/').Length).Replace('\', '/')
                if ($rel -notin $srcFiles) {
                    Remove-Item -LiteralPath $_.FullName -Force
                    Write-Host "[CLEANUP] Pruned orphan agent file from repo: $aName$rel" -ForegroundColor DarkGray
                }
            }
            Get-ChildItem -LiteralPath $dstAgentDir -Recurse -Directory -Force | Sort-Object -Property FullName -Descending | ForEach-Object {
                if (@(Get-ChildItem -LiteralPath $_.FullName -Force).Count -eq 0) {
                    Remove-Item -LiteralPath $_.FullName -Force
                }
            }
            Copy-DirectoryContentsLiteral -SourceDir $srcAgentDir -DestDir $dstAgentDir
            $syncedAgents++
        }
    }
}
Write-Host "[OK] Synced $syncedAgents Tracked Custom Agents" -ForegroundColor Green

# 4. Sync Tracked Custom Skills (guard against empty source deletion)
$syncedSkills = 0
foreach ($sName in $trackedSkillNames) {
    $srcSkillDir = Join-Path $srcSkillsDir $sName
    $dstSkillDir = Join-Path $dstSkills $sName
    if (Test-Path -LiteralPath $srcSkillDir) {
        $srcFiles = @(Get-ChildItem -LiteralPath $srcSkillDir -Recurse -File -Force | ForEach-Object {
            $_.FullName.Substring($srcSkillDir.TrimEnd('\', '/').Length).Replace('\', '/')
        })
        if ($srcFiles.Count -gt 0) {
            Get-ChildItem -LiteralPath $dstSkillDir -Recurse -File -Force | ForEach-Object {
                $rel = $_.FullName.Substring($dstSkillDir.TrimEnd('\', '/').Length).Replace('\', '/')
                if ($rel -notin $srcFiles) {
                    Remove-Item -LiteralPath $_.FullName -Force
                    Write-Host "[CLEANUP] Pruned orphan skill file from repo: $sName$rel" -ForegroundColor DarkGray
                }
            }
            Get-ChildItem -LiteralPath $dstSkillDir -Recurse -Directory -Force | Sort-Object -Property FullName -Descending | ForEach-Object {
                if (@(Get-ChildItem -LiteralPath $_.FullName -Force).Count -eq 0) {
                    Remove-Item -LiteralPath $_.FullName -Force
                }
            }
            Copy-DirectoryContentsLiteral -SourceDir $srcSkillDir -DestDir $dstSkillDir
            $syncedSkills++
        }
    }
}
Write-Host "[OK] Synced $syncedSkills Tracked Custom Skills" -ForegroundColor Green

Write-Host ">>> Everyday-AGY sync completed successfully!" -ForegroundColor Green
