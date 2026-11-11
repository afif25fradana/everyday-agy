[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Task,

    [Parameter(Mandatory = $false)]
    [string[]]$FilePath,

    [Parameter(Mandatory = $false)]
    [string]$RepoPath
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

Push-Location
try {
    if ($RepoPath) {
        if (-not (Test-Path -LiteralPath $RepoPath)) {
            Write-Error "Specified RepoPath does not exist: $RepoPath"
            exit 1
        }
        Set-Location -LiteralPath $RepoPath
    }

    $safeTask = ($Task -replace '[^A-Za-z0-9_-]', '-')
    if ($safeTask -notmatch '[A-Za-z0-9]') {
        Write-Error "Invalid Task name '$Task': must contain at least one alphanumeric character."
        exit 1
    }
    $userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
    $scratchDir = Join-Path $userHome ".gemini/antigravity/scratch/$safeTask"

    function Ensure-ScratchDir {
        if (-not (Test-Path -LiteralPath $scratchDir)) {
            New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null
        }
    }

    function Invoke-GitCmd {
        param([string[]]$Arguments)
        git @Arguments
    }

    if ($FilePath -and $FilePath.Count -gt 0) {
        Ensure-ScratchDir
        foreach ($rawTarget in $FilePath) {
            $target = "$rawTarget".Trim().Trim('"').Trim("'")
            if ([string]::IsNullOrWhiteSpace($target)) { continue }
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
                Write-Error "Target file not found or is not a file: $target"
                exit 1
            }
            $resolvedPath = (Resolve-Path -LiteralPath $target).Path
            $pathHashKey = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { $resolvedPath.ToLowerInvariant() } else { $resolvedPath }
            $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($pathHashKey)
            $sha1 = [System.Security.Cryptography.SHA1]::Create()
            try {
                $pathHash = ([BitConverter]::ToString($sha1.ComputeHash($pathBytes))).Replace('-', '').ToLower().Substring(0, 8)
            } finally {
                $sha1.Dispose()
            }
            $leafName = Split-Path -Leaf $resolvedPath
            $backupPath = Join-Path $scratchDir "${pathHash}_${leafName}.bak"
            Copy-Item -LiteralPath $resolvedPath -Destination $backupPath -Force

            $sha = [System.Security.Cryptography.SHA256]::Create()
            try { $fullHash = ([BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($backupPath)))).Replace('-', '').ToLower() }
            finally { $sha.Dispose() }
            $shortHash = $fullHash.Substring(0, 12)
            "$fullHash  $backupPath  $resolvedPath" | Add-Content -LiteralPath (Join-Path $scratchDir "hashes.txt") -Encoding utf8
            Write-Output "Checkpoint created: $backupPath (sha $shortHash)"
        }
    } else {
        $gitCheckOut = Invoke-GitCmd @("rev-parse", "--is-inside-work-tree") 2>&1
        $gitCheckRc = $LASTEXITCODE
        $gitCheck = ($gitCheckOut | Where-Object { $_ -isnot [System.Management.Automation.ErrorRecord] } | Out-String).Trim()
        if ($gitCheckRc -ne 0) {
            $gitErrText = ($gitCheckOut | ForEach-Object { if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { "$_" } }) -join " "
            if ($gitCheckRc -ne 128 -and $gitErrText -notmatch 'not a git repository') {
                Write-Error "git rev-parse failed (exit code $gitCheckRc): $gitErrText"
                exit 1
            }
            Write-Error "Cannot create checkpoint: current location is not a git repository and no FilePath was specified."
            exit 1
        }
        if ($gitCheck -eq "true") {
            $repoRoot = ((Invoke-GitCmd @("rev-parse", "--show-toplevel")) | Out-String).Trim()
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
                Write-Error "Failed to resolve git repository root (exit code $LASTEXITCODE)."
                exit 1
            }
            if (Test-Path -LiteralPath $repoRoot) {
                Set-Location -LiteralPath $repoRoot
            }
            $dirtyPreexisting = ((Invoke-GitCmd @("status", "--porcelain", "-uno")) | Out-String).Trim()
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to query git status before creating checkpoint (exit code $LASTEXITCODE)."
                exit 1
            }
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
            $baseBranchFile = Join-Path $scratchDir "base_branch.txt"
            $currentBranch = ((Invoke-GitCmd @("symbolic-ref", "--quiet", "--short", "HEAD")) 2>$null | Out-String).Trim()
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($currentBranch)) {
                [System.IO.File]::WriteAllText($baseBranchFile, $currentBranch, [System.Text.UTF8Encoding]::new($false))
            } elseif (Test-Path -LiteralPath $baseBranchFile) {
                Remove-Item -LiteralPath $baseBranchFile -Force -ErrorAction SilentlyContinue
            }
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
            [string[]]$baselineItems = @((@($untrackedFiles) + @($untrackedDirs)) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
            [System.IO.File]::WriteAllLines($untrackedBaseline, $baselineItems, [System.Text.UTF8Encoding]::new($false))
            $rawSha = ((Invoke-GitCmd @("rev-parse", "HEAD")) | Out-String).Trim()
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($rawSha)) {
                Write-Error "Failed to resolve HEAD commit SHA."
                exit 1
            }
            $headSha = $rawSha.Substring(0, [Math]::Min(12, $rawSha.Length))
            Write-Output "Checkpoint created: git branch $branchName (sha $headSha)"
        } else {
            Write-Error "Cannot create checkpoint: current location is not a git repository and no FilePath was specified."
            exit 1
        }
    }
} finally {
    Pop-Location
}
