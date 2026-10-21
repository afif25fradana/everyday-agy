param(
    [Parameter(Mandatory = $true)]
    [string]$Task,

    [Parameter(Mandatory = $false)]
    [string]$FilePath
)

$ErrorActionPreference = "Stop"
$scratchDir = "$env:USERPROFILE\.gemini\antigravity\scratch\$Task"
if (-not (Test-Path -Path $scratchDir)) {
    New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
}

if ($FilePath) {
    if (-not (Test-Path -Path $FilePath)) {
        Write-Error "Target file not found: $FilePath"
        exit 1
    }
    $fileName = Split-Path -Leaf $FilePath
    $backupPath = Join-Path $scratchDir "$fileName.bak"
    Copy-Item -Path $FilePath -Destination $backupPath -Force
    $hashObj = Get-FileHash -Algorithm SHA256 -Path $backupPath
    $fullHash = $hashObj.Hash.ToLower()
    $shortHash = $fullHash.Substring(0, 12)
    "$fullHash  $backupPath" | Add-Content -Path (Join-Path $scratchDir "hashes.txt")
    Write-Output "Checkpoint created: $backupPath (sha $shortHash)"
} else {
    $gitCheck = git rev-parse --is-inside-work-tree 2>$null
    if ($gitCheck -eq "true") {
        $branchName = "checkpoint-$Task"
        git branch $branchName 2>$null | Out-Null
        $headSha = (git rev-parse HEAD).Substring(0, 12)
        Write-Output "Checkpoint created: git branch $branchName (sha $headSha)"
    } else {
        Write-Output "Checkpoint notice: outside git repository and no FilePath specified. Scratch directory prepared at $scratchDir"
    }
}
