param(
    [Parameter(Mandatory = $true)]
    [string]$Task,

    [Parameter(Mandatory = $false)]
    [string]$FilePath
)

$ErrorActionPreference = "Stop"
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
    $fileName = Split-Path -Leaf $FilePath
    $backupPath = Join-Path $scratchDir "$fileName.bak"
    if (-not (Test-Path -Path $backupPath)) {
        Write-Error "Backup file not found in scratch: $backupPath"
        exit 1
    }
    Copy-Item -Path $backupPath -Destination $FilePath -Force
    Write-Output "Checkpoint restored: $backupPath -> $FilePath"
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
            $currentUntracked = Invoke-GitCmd @("ls-files", "--others", "--exclude-standard")
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
