param(
    [Parameter(Mandatory = $true)]
    [string]$Task,

    [Parameter(Mandatory = $false)]
    [string]$FilePath,

    [Parameter(Mandatory = $false)]
    [string]$RepoPath
)

$ErrorActionPreference = "Stop"
if ($RepoPath -and (Test-Path -Path $RepoPath)) {
    Set-Location -LiteralPath $RepoPath
}

$safeTask = ($Task -replace '[^A-Za-z0-9_-]', '-')
$scratchDir = "$env:USERPROFILE\.gemini\antigravity\scratch\$safeTask"

function Invoke-GitCmd {
    param([string[]]$Arguments)
    if (Get-Command rtk -ErrorAction SilentlyContinue) {
        rtk git @Arguments
    } else {
        git @Arguments
    }
}

if ($FilePath) {
    $resolvedPath = if (Test-Path -Path $FilePath) { (Resolve-Path -LiteralPath $FilePath).Path } else { $FilePath }
    $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($resolvedPath.ToLowerInvariant())
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $pathHash = ([BitConverter]::ToString($sha1.ComputeHash($pathBytes))).Replace('-', '').ToLower().Substring(0, 8)
    } finally {
        $sha1.Dispose()
    }
    $leafName = Split-Path -Leaf $resolvedPath
    $hashedBackup = Join-Path $scratchDir "${pathHash}_${leafName}.bak"
    $legacyBackup = Join-Path $scratchDir "$leafName.bak"

    $backupPath = if (Test-Path -Path $hashedBackup) { $hashedBackup } elseif (Test-Path -Path $legacyBackup) { $legacyBackup } else { $null }

    if (-not $backupPath) {
        Write-Error "Backup file not found in scratch: checked '$hashedBackup' and '$legacyBackup'"
        exit 1
    }
    Copy-Item -Path $backupPath -Destination $resolvedPath -Force
    Write-Output "Checkpoint restored: $backupPath -> $resolvedPath"
} else {
    $gitCheck = Invoke-GitCmd @("rev-parse", "--is-inside-work-tree") 2>$null
    if ($gitCheck -eq "true") {
        $branchName = "checkpoint-$safeTask"
        $branchExists = Invoke-GitCmd @("rev-parse", "--verify", "refs/heads/$branchName") 2>$null
        if ($LASTEXITCODE -eq 0 -and $branchExists) {
            Invoke-GitCmd @("reset", "--hard", $branchName) | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to reset working tree to '$branchName'."
                exit 1
            }
            $untrackedBaseline = Join-Path $scratchDir "untracked_baseline.txt"
            $baselineSet = @{}
            if (Test-Path -Path $untrackedBaseline) {
                foreach ($line in (Get-Content -Path $untrackedBaseline)) {
                    if (-not [string]::IsNullOrWhiteSpace($line)) { $baselineSet[$line.Trim()] = $true }
                }
            }
            $currentUntracked = Invoke-GitCmd @("-c", "core.quotePath=false", "ls-files", "--others", "--exclude-standard")
            foreach ($relPath in @($currentUntracked)) {
                $cleanRel = "$relPath".Trim()
                if (-not [string]::IsNullOrWhiteSpace($cleanRel) -and -not $baselineSet.ContainsKey($cleanRel)) {
                    if (Test-Path -LiteralPath $cleanRel) {
                        Remove-Item -LiteralPath $cleanRel -Recurse -Force
                    }
                }
            }
            $rawSha = ((Invoke-GitCmd @("rev-parse", "HEAD")) | Out-String).Trim()
            $restoredSha = $rawSha.Substring(0, [Math]::Min(12, $rawSha.Length))
            Write-Output "Checkpoint restored: reset working tree to branch $branchName (sha $restoredSha)"
        } else {
            Write-Error "Checkpoint branch '$branchName' not found."
            exit 1
        }
    } else {
        Write-Error "Outside git repository and no FilePath specified. Cannot restore checkpoint."
        exit 1
    }
}
