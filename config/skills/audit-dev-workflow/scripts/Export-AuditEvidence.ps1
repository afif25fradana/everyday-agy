param(
    [Parameter(Mandatory = $true)]
    [string]$Task,

    [Parameter(Mandatory = $false)]
    [string]$RepoPath = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$scratchDir = "$env:USERPROFILE\.gemini\antigravity\scratch\$Task"
if (-not (Test-Path -Path $scratchDir)) {
    New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
}

$diffPath = Join-Path $scratchDir "$Task.diff"
git -C $RepoPath diff HEAD > $diffPath

if (-not (Test-Path -Path $diffPath) -or ((Get-Item $diffPath).Length -eq 0)) {
    # If no git diff HEAD, check unstaged git diff
    git -C $RepoPath diff > $diffPath
}

$lineCount = 0
if (Test-Path -Path $diffPath) {
    $lineCount = (Get-Content -Path $diffPath | Measure-Object -Line).Lines
    $hashObj = Get-FileHash -Algorithm SHA256 -Path $diffPath
    $fullHash = $hashObj.Hash.ToLower()
    $shortHash = $fullHash.Substring(0, 12)
    "$fullHash  $diffPath" | Add-Content -Path (Join-Path $scratchDir "hashes.txt")
    Write-Output "Evidence exported: $diffPath (sha $shortHash, $lineCount lines)"
} else {
    Write-Output "Evidence exported: empty diff at $diffPath (0 lines)"
}
