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

    function Invoke-GitCmd {
        param([string[]]$Arguments)
        git @Arguments
    }

    function Remove-PathSafeNoFollow {
        param([string]$TargetPath)
        $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($TargetPath)
        if ($fullPath.Length -gt 1 -and $fullPath -notmatch '^[A-Za-z]:[/\\]?$') {
            $fullPath = $fullPath.TrimEnd('\', '/')
        }
        $item = Get-Item -LiteralPath $fullPath -Force -ErrorAction Stop
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            if ($item.PSIsContainer) {
                [System.IO.Directory]::Delete($fullPath, $false)
            } else {
                [System.IO.File]::Delete($fullPath)
            }
            return
        }
        if ($item.PSIsContainer) {
            foreach ($child in @(Get-ChildItem -LiteralPath $fullPath -Force -ErrorAction Stop)) {
                Remove-PathSafeNoFollow -TargetPath $child.FullName
            }
            [System.IO.Directory]::Delete($fullPath, $false)
        } else {
            Remove-Item -LiteralPath $fullPath -Force -ErrorAction Stop
        }
    }

    function Test-DirectoryHasNonNewContentNoFollow {
        param(
            [string]$DirPath,
            [string]$RelativePrefix,
            [hashtable]$BaselineSet
        )
        $entries = @(Get-ChildItem -LiteralPath $DirPath -Force -ErrorAction Stop)
        foreach ($entry in $entries) {
            $rel = if ($RelativePrefix) { "$RelativePrefix/$($entry.Name)" } else { $entry.Name }
            $isReparse = ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
            if ($isReparse) {
                if ($BaselineSet.ContainsKey($rel) -or $BaselineSet.ContainsKey("$rel/")) {
                    return $true
                }
                continue
            }
            if ($entry.PSIsContainer) {
                if (Test-DirectoryHasNonNewContentNoFollow -DirPath $entry.FullName -RelativePrefix $rel -BaselineSet $BaselineSet) {
                    return $true
                }
            } else {
                return $true
            }
        }
        return $false
    }

    if ($FilePath -and $FilePath.Count -gt 0) {
        foreach ($rawTarget in $FilePath) {
            $target = "$rawTarget".Trim().Trim('"').Trim("'")
            if ([string]::IsNullOrWhiteSpace($target)) { continue }
            $resolvedPath = if (Test-Path -LiteralPath $target) {
                (Resolve-Path -LiteralPath $target).Path
            } else {
                $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($target)
            }
            $pathHashKey = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { $resolvedPath.ToLowerInvariant() } else { $resolvedPath }
            $pathBytes = [System.Text.Encoding]::UTF8.GetBytes($pathHashKey)
            $sha1 = [System.Security.Cryptography.SHA1]::Create()
            try {
                $pathHash = ([BitConverter]::ToString($sha1.ComputeHash($pathBytes))).Replace('-', '').ToLower().Substring(0, 8)
            } finally {
                $sha1.Dispose()
            }
            $leafName = Split-Path -Leaf $resolvedPath
            $hashedBackup = Join-Path $scratchDir "${pathHash}_${leafName}.bak"
            $legacyBackup = Join-Path $scratchDir "$leafName.bak"

            $backupPath = if (Test-Path -LiteralPath $hashedBackup) { $hashedBackup } elseif (Test-Path -LiteralPath $legacyBackup) { $legacyBackup } else { $null }

            if (-not $backupPath) {
                Write-Error "Backup file not found in scratch: checked '$hashedBackup' and '$legacyBackup'"
                exit 1
            }
            $hashesFile = Join-Path $scratchDir "hashes.txt"
            if (-not (Test-Path -LiteralPath $hashesFile)) {
                Write-Error "Integrity Failure: Missing hashes.txt manifest at '$hashesFile'."
                exit 1
            }
            $expectedLine = Get-Content -LiteralPath $hashesFile -Encoding utf8 | Where-Object { $_ -match [regex]::Escape($backupPath) } | Select-Object -Last 1
            if (-not $expectedLine) {
                Write-Error "Integrity Failure: No checksum entry for '$backupPath' in '$hashesFile'."
                exit 1
            }
            $expectedHash = ($expectedLine -split '\s+')[0]
            $sha = [System.Security.Cryptography.SHA256]::Create()
            try { $actualHash = ([BitConverter]::ToString($sha.ComputeHash([System.IO.File]::ReadAllBytes($backupPath)))).Replace('-', '').ToLower() }
            finally { $sha.Dispose() }
            if ($expectedHash -ne $actualHash) {
                Write-Error "Integrity Failure: Checksum mismatch for '$backupPath'. Expected $expectedHash, got $actualHash."
                exit 1
            }
            $parentDir = Split-Path -Parent $resolvedPath
            if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
                New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $backupPath -Destination $resolvedPath -Force
            Write-Output "Checkpoint restored: $backupPath -> $resolvedPath"
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
            Write-Error "Outside git repository and no FilePath specified. Cannot restore checkpoint."
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
            $branchName = "checkpoint-$safeTask"
            $branchExists = Invoke-GitCmd @("rev-parse", "--verify", "refs/heads/$branchName") 2>$null
            if ($LASTEXITCODE -eq 0 -and $branchExists) {
                $baseBranchFile = Join-Path $scratchDir "base_branch.txt"
                if (Test-Path -LiteralPath $baseBranchFile) {
                    $baseBranch = ([System.IO.File]::ReadAllText($baseBranchFile, [System.Text.Encoding]::UTF8)).Trim()
                    if (-not [string]::IsNullOrWhiteSpace($baseBranch)) {
                        $activeBranch = ((Invoke-GitCmd @("symbolic-ref", "--quiet", "--short", "HEAD")) 2>$null | Out-String).Trim()
                        if ($LASTEXITCODE -ne 0 -or $activeBranch -ne $baseBranch) {
                            Invoke-GitCmd @("checkout", "-q", $baseBranch) | Out-Null
                            if ($LASTEXITCODE -ne 0) {
                                Write-Error "Failed to restore base branch '$baseBranch' before resetting to '$branchName'."
                                exit 1
                            }
                        }
                    }
                }
                Invoke-GitCmd @("reset", $branchName) | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Failed to reset index to '$branchName'."
                    exit 1
                }
                Invoke-GitCmd @("reset", "--hard", $branchName) | Out-Null
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Failed to reset working tree to '$branchName'."
                    exit 1
                }
                $untrackedBaseline = Join-Path $scratchDir "untracked_baseline.txt"
                if (Test-Path -LiteralPath $untrackedBaseline) {
                    $baselineSet = @{}
                    foreach ($line in (Get-Content -LiteralPath $untrackedBaseline -Encoding utf8)) {
                        $cleanLine = $line.Trim().TrimStart([char]0xFEFF)
                        if (-not [string]::IsNullOrWhiteSpace($cleanLine)) { $baselineSet[$cleanLine] = $true }
                    }
                    $currentUntracked = Invoke-GitCmd @("-c", "core.quotePath=false", "ls-files", "--others", "--exclude-standard")
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Failed to query untracked files from git during rollback (exit code $LASTEXITCODE)."
                        exit 1
                    }
                    foreach ($relPath in @($currentUntracked)) {
                        $cleanRel = "$relPath".Trim().TrimEnd('/', '\')
                        if (-not [string]::IsNullOrWhiteSpace($cleanRel) -and -not $baselineSet.ContainsKey($cleanRel) -and -not $baselineSet.ContainsKey("$cleanRel/")) {
                            # Unlink any untracked ReparsePoint ancestor before descending so junction targets stay untouched
                            $parts = $cleanRel -split '[/\\]'
                            $accum = ""
                            $handledReparse = $false
                            foreach ($seg in $parts) {
                                if ([string]::IsNullOrEmpty($seg)) { continue }
                                $accum = if ($accum) { "$accum/$seg" } else { $seg }
                                $segItem = Get-Item -LiteralPath $accum -Force -ErrorAction SilentlyContinue
                                if ($null -ne $segItem -and (($segItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
                                    if (-not $baselineSet.ContainsKey($accum) -and -not $baselineSet.ContainsKey("$accum/")) {
                                        try {
                                            Remove-PathSafeNoFollow -TargetPath $accum
                                        } catch {
                                            Write-Warning "Unable to remove untracked reparse point '$accum': $($_.Exception.Message)"
                                        }
                                    }
                                    $handledReparse = $true
                                    break
                                }
                            }
                            if (-not $handledReparse -and (Test-Path -LiteralPath $cleanRel)) {
                                try {
                                    Remove-PathSafeNoFollow -TargetPath $cleanRel
                                } catch {
                                    Write-Warning "Unable to remove untracked path '$cleanRel' (file locked): $($_.Exception.Message)"
                                }
                            }
                        }
                    }
                    # Clean up empty untracked directories and untracked junctions created during task
                    $currentUntrackedDirs = Invoke-GitCmd @("-c", "core.quotePath=false", "ls-files", "--others", "--exclude-standard", "--directory")
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "Failed to query untracked directories from git during rollback (exit code $LASTEXITCODE)."
                        exit 1
                    }
                    foreach ($dirRel in @($currentUntrackedDirs)) {
                        $cleanDir = "$dirRel".Trim().TrimEnd('/', '\')
                        if (-not [string]::IsNullOrWhiteSpace($cleanDir) -and -not $baselineSet.ContainsKey($cleanDir) -and -not $baselineSet.ContainsKey("$cleanDir/")) {
                            $dirItem = Get-Item -LiteralPath $cleanDir -Force -ErrorAction SilentlyContinue
                            if ($null -ne $dirItem -and $dirItem.PSIsContainer) {
                                if (($dirItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                                    try {
                                        Remove-PathSafeNoFollow -TargetPath $cleanDir
                                    } catch {
                                        Write-Warning "Unable to remove untracked junction '$cleanDir': $($_.Exception.Message)"
                                    }
                                    continue
                                }
                                try {
                                    $hasBaselineOrFiles = Test-DirectoryHasNonNewContentNoFollow -DirPath $dirItem.FullName -RelativePrefix $cleanDir -BaselineSet $baselineSet
                                } catch {
                                    Write-Warning "Unable to inspect untracked directory '$cleanDir': $($_.Exception.Message)"
                                    continue
                                }
                                if (-not $hasBaselineOrFiles) {
                                    try {
                                        Remove-PathSafeNoFollow -TargetPath $cleanDir
                                    } catch {
                                        Write-Warning "Unable to remove untracked directory '$cleanDir' (locked): $($_.Exception.Message)"
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Write-Warning "Untracked baseline '$untrackedBaseline' not found; skipping untracked cleanup to preserve untracked files."
                }
                $rawSha = ((Invoke-GitCmd @("rev-parse", "HEAD")) | Out-String).Trim()
                if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($rawSha)) {
                    Write-Error "Failed to resolve HEAD commit SHA after restore."
                    exit 1
                }
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
} finally {
    Pop-Location
}
