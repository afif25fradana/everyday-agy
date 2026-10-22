param(
    [Parameter(Mandatory = $true)]
    [string]$Task,

    [Parameter(Mandatory = $false)]
    [string]$FilePath
)

$ErrorActionPreference = "Stop"
$scratchDir = "$env:USERPROFILE\.gemini\antigravity\scratch\$Task"

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
        $branchName = "checkpoint-$Task"
        $branchExists = Invoke-GitCmd @("rev-parse", "--verify", "refs/heads/$branchName") 2>$null
        if ($branchExists) {
            Invoke-GitCmd @("reset", "--hard", $branchName) | Out-Null
            $restoredSha = (Invoke-GitCmd @("rev-parse", "HEAD")).Substring(0, 12)
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
