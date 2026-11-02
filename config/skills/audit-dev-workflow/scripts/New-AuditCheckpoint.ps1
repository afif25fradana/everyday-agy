param(
    [Parameter(Mandatory = $true)]
    [string]$Task,

    [Parameter(Mandatory = $false)]
    [string]$FilePath,

    [Parameter(Mandatory = $false)]
    [string]$RepoPath
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
if ($RepoPath -and (Test-Path -Path $RepoPath)) {
    Set-Location -LiteralPath $RepoPath
}

$safeTask = ($Task -replace '[^A-Za-z0-9_-]', '-')
$userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$scratchDir = Join-Path $userHome ".gemini/antigravity/scratch/$safeTask"

function Ensure-ScratchDir {
    if (-not (Test-Path -Path $scratchDir)) {
        New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
    }
}

function Invoke-GitCmd {
    param([string[]]$Arguments)
    if (Get-Command rtk -ErrorAction SilentlyContinue) {
        rtk git @Arguments
    } else {
        git @Arguments
    }
}

if ($FilePath) {
    if (-not (Test-Path -Path $FilePath)) {
        Write-Error "Target file not found: $FilePath"
        exit 1
    }
    Ensure-ScratchDir
    $resolvedPath = (Resolve-Path -LiteralPath $FilePath).Path
    $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($resolvedPath.ToLowerInvariant())
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $pathHash = ([BitConverter]::ToString($sha1.ComputeHash($pathBytes))).Replace('-', '').ToLower().Substring(0, 8)
    } finally {
        $sha1.Dispose()
    }
    $leafName = Split-Path -Leaf $resolvedPath
    $backupPath = Join-Path $scratchDir "${pathHash}_${leafName}.bak"
    Copy-Item -Path $resolvedPath -Destination $backupPath -Force

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $fullHash = ([BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($backupPath)))).Replace('-', '').ToLower() }
    finally { $sha.Dispose() }
    $shortHash = $fullHash.Substring(0, 12)
    "$fullHash  $backupPath  $resolvedPath" | Add-Content -Path (Join-Path $scratchDir "hashes.txt")
    Write-Output "Checkpoint created: $backupPath (sha $shortHash)"
} else {
    $gitCheck = Invoke-GitCmd @("rev-parse", "--is-inside-work-tree") 2>$null
    if ($gitCheck -eq "true") {
        $repoRoot = ((Invoke-GitCmd @("rev-parse", "--show-toplevel")) | Out-String).Trim()
        if ($repoRoot -and (Test-Path -LiteralPath $repoRoot)) {
            Set-Location -LiteralPath $repoRoot
        }
        $dirtyPreexisting = ((Invoke-GitCmd @("status", "--porcelain", "-uno")) | Out-String).Trim()
        if (-not [string]::IsNullOrWhiteSpace($dirtyPreexisting)) {
            Write-Error "Working tree has uncommitted tracked changes. Commit or stash changes before creating an autonomous checkpoint so rollback does not wipe prior work."
            exit 1
        }
        $branchName = "checkpoint-$safeTask"
        Invoke-GitCmd @("branch", "-f", $branchName) | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to create or update git checkpoint branch '$branchName'."
            exit 1
        }
        Ensure-ScratchDir
        $untrackedBaseline = Join-Path $scratchDir "untracked_baseline.txt"
        $untrackedFiles = Invoke-GitCmd @("-c", "core.quotePath=false", "ls-files", "--others", "--exclude-standard")
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to record untracked files baseline."
            exit 1
        }
        $untrackedDirs = Invoke-GitCmd @("-c", "core.quotePath=false", "ls-files", "--others", "--exclude-standard", "--directory")
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to record untracked directories baseline."
            exit 1
        }
        (@($untrackedFiles) + @($untrackedDirs)) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique | Set-Content -Path $untrackedBaseline -Encoding utf8
        $rawSha = ((Invoke-GitCmd @("rev-parse", "HEAD")) | Out-String).Trim()
        $headSha = $rawSha.Substring(0, [Math]::Min(12, $rawSha.Length))
        Write-Output "Checkpoint created: git branch $branchName (sha $headSha)"
    } else {
        Write-Error "Cannot create checkpoint: current location is not a git repository and no FilePath was specified."
        exit 1
    }
}
