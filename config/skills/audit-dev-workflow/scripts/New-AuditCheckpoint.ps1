param(
    [Parameter(Mandatory = $true)]
    [string]$Task,

    [Parameter(Mandatory = $false)]
    [string]$FilePath
)

$ErrorActionPreference = "Stop"
$safeTask = ($Task -replace '[^A-Za-z0-9_-]', '-')
$scratchDir = "$env:USERPROFILE\.gemini\antigravity\scratch\$safeTask"
if (-not (Test-Path -Path $scratchDir)) {
    New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
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
    $fileName = Split-Path -Leaf $FilePath
    $backupPath = Join-Path $scratchDir "$fileName.bak"
    Copy-Item -Path $FilePath -Destination $backupPath -Force
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { $fullHash = ([BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($backupPath)))).Replace('-', '').ToLower() }
    finally { $sha.Dispose() }
    $shortHash = $fullHash.Substring(0, 12)
    "$fullHash  $backupPath" | Add-Content -Path (Join-Path $scratchDir "hashes.txt")
    Write-Output "Checkpoint created: $backupPath (sha $shortHash)"
} else {
    $gitCheck = Invoke-GitCmd @("rev-parse", "--is-inside-work-tree") 2>$null
    if ($gitCheck -eq "true") {
        $branchName = "checkpoint-$safeTask"
        Invoke-GitCmd @("branch", "-f", $branchName) 2>$null | Out-Null
        $headSha = (Invoke-GitCmd @("rev-parse", "HEAD")).Substring(0, 12)
        Write-Output "Checkpoint created: git branch $branchName (sha $headSha)"
    } else {
        Write-Output "Checkpoint notice: outside git repository and no FilePath specified. Scratch directory prepared at $scratchDir"
    }
}
