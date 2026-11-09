# AuditCheckpoint.Tests.ps1
# Unit verification suite for New-AuditCheckpoint.ps1 and Restore-AuditCheckpoint.ps1
# Compatible with Windows PowerShell 5.1 and PowerShell 7.x

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$newScript = Join-Path $scriptDir "New-AuditCheckpoint.ps1"
$restoreScript = Join-Path $scriptDir "Restore-AuditCheckpoint.ps1"
$updateScript = Join-Path $scriptDir "Update-Gate2Diff.ps1"

$testsRun = 0
$testsPassed = 0
$testsFailed = 0

function Assert-Test {
    param(
        [string]$Name,
        [bool]$Condition,
        [string]$Details = ""
    )
    $script:testsRun++
    if ($Condition) {
        $script:testsPassed++
        Write-Host "  PASS: $Name" -ForegroundColor Green
    } else {
        $script:testsFailed++
        Write-Host "  FAIL: $Name" -ForegroundColor Red
        if ($Details) {
            Write-Host "        Details: $Details" -ForegroundColor Yellow
        }
    }
}

Write-Host "Starting AuditCheckpoint Test Suite..." -ForegroundColor Cyan

# Prepare isolated temp workspace
$testId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
$taskName = "audit-checkpoint-unit-test-$testId"
$testDir = Join-Path ([System.IO.Path]::GetTempPath()) "audit_test_$testId"
$userHome = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
$scratchDir = Join-Path $userHome ".gemini/antigravity/scratch/$taskName"

try {
    New-Item -ItemType Directory -Path $testDir -Force | Out-Null

    # Test 1: File mode backup creation
    $testFile = Join-Path $testDir "source_code.txt"
    Set-Content -Path $testFile -Value "initial version 1.0" -Encoding utf8
    
    & $newScript -Task $taskName -FilePath $testFile | Out-Null
    $hashesPath = Join-Path $scratchDir "hashes.txt"
    Assert-Test -Name "File mode creates hashes.txt" -Condition (Test-Path -Path $hashesPath)

    # Test 2: File mode restore when file is modified
    Set-Content -Path $testFile -Value "tampered corrupted version" -Encoding utf8
    & $restoreScript -Task $taskName -FilePath $testFile | Out-Null
    $restoredContent = (Get-Content -Path $testFile -Raw).Trim()
    Assert-Test -Name "File mode restores modified file" -Condition ($restoredContent -eq "initial version 1.0")

    # Test 3: File mode restore when file is deleted (GAP-REL-01 GetUnresolvedProviderPathFromPSPath)
    Remove-Item -Path $testFile -Force
    Assert-Test -Name "Source file successfully deleted before test" -Condition (-not (Test-Path -Path $testFile))

    & $restoreScript -Task $taskName -FilePath $testFile | Out-Null
    $recreatedContent = if (Test-Path -Path $testFile) { (Get-Content -Path $testFile -Raw).Trim() } else { "" }
    Assert-Test -Name "File mode restores deleted file using unresolved path" -Condition ($recreatedContent -eq "initial version 1.0")

    # Test 3b: File mode restore recreates deleted parent directory (GAP-REL-06)
    $nestedDir = Join-Path $testDir "sub/nested/folder"
    New-Item -ItemType Directory -Path $nestedDir -Force | Out-Null
    $nestedFile = Join-Path $nestedDir "nested_config.json"
    Set-Content -Path $nestedFile -Value '{"status":"ok"}' -Encoding utf8
    
    $nestedTask = "nested-$taskName"
    & $newScript -Task $nestedTask -FilePath $nestedFile | Out-Null
    
    # Intentionally delete the entire parent directory tree
    Remove-Item -Path (Join-Path $testDir "sub") -Recurse -Force
    Assert-Test -Name "Parent directory successfully deleted before test" -Condition (-not (Test-Path -Path $nestedDir))
    
    & $restoreScript -Task $nestedTask -FilePath $nestedFile | Out-Null
    $nestedRestored = if (Test-Path -Path $nestedFile) { (Get-Content -Path $nestedFile -Raw).Trim() } else { "" }
    Assert-Test -Name "File mode restore recreates parent directories" -Condition ($nestedRestored -eq '{"status":"ok"}')

    # Test 3c: File mode checkpoint & restore on bracket filenames like Next.js [id].tsx
    $bracketFile = Join-Path $testDir "[id].tsx"
    Set-Content -LiteralPath $bracketFile -Value "export default function Page() { return <div>ID</div>; }" -Encoding utf8
    $bracketTask = "bracket-$taskName"
    try {
        & $newScript -Task $bracketTask -FilePath $bracketFile 2>&1 | Out-Null
    } catch {
        # Expected failure on unmodified code
    }
    Set-Content -LiteralPath $bracketFile -Value "tampered bracket content" -Encoding utf8
    try {
        & $restoreScript -Task $bracketTask -FilePath $bracketFile 2>&1 | Out-Null
    } catch {
        # Expected failure on unmodified code
    }
    $restoredBracket = if (Test-Path -LiteralPath $bracketFile) { (Get-Content -LiteralPath $bracketFile -Raw).Trim() } else { "" }
    Assert-Test -Name "File mode checkpoint and restore on bracket filename [id].tsx" -Condition ($restoredBracket -eq "export default function Page() { return <div>ID</div>; }")

    # Test 4: File mode fails gracefully on missing backup
    $missingFile = Join-Path $testDir "never_backed_up.txt"
    Set-Content -Path $missingFile -Value "ghost" -Encoding utf8
    $failedGracefully = $false
    try {
        & $restoreScript -Task $taskName -FilePath $missingFile 2>&1 | Out-Null
    } catch {
        $failedGracefully = $true
    }
    Assert-Test -Name "Restore fails when backup does not exist" -Condition $failedGracefully

    # Test 4b: File mode restore rejects corrupted backup when hash does not match hashes.txt (GAP-R3-02)
    $corruptTask = "corrupt-$taskName"
    $corruptScratch = Join-Path $userHome ".gemini/antigravity/scratch/$corruptTask"
    $corruptFile = Join-Path $testDir "corrupt_test.txt"
    Set-Content -Path $corruptFile -Value "clean original content" -Encoding utf8
    & $newScript -Task $corruptTask -FilePath $corruptFile | Out-Null

    # Tamper with the backup file in scratch so its hash no longer matches hashes.txt
    $backupFile = Get-ChildItem -Path $corruptScratch -Filter "*.bak" | Select-Object -First 1
    Set-Content -LiteralPath $backupFile.FullName -Value "corrupted malicious payload" -Encoding utf8

    $global:LASTEXITCODE = 0
    $corruptFailed = $false
    try {
        & $restoreScript -Task $corruptTask -FilePath $corruptFile 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { $corruptFailed = $true }
    } catch {
        $corruptFailed = $true
    }
    $restoredCorrupt = (Get-Content -Path $corruptFile -Raw).Trim()
    $corruptRejected = $corruptFailed -and ($restoredCorrupt -eq "clean original content")
    Assert-Test -Name "File mode restore rejects corrupted backup against hashes.txt" -Condition $corruptRejected

    # Test 5: Git mode fail-closed when untracked_baseline.txt is missing (GAP-REL-03)
    # Initialize a temporary git repository
    $gitRepoDir = Join-Path $testDir "git_repo"
    New-Item -ItemType Directory -Path $gitRepoDir -Force | Out-Null
    
    $origPwd = Get-Location
    try {
        Set-Location -LiteralPath $gitRepoDir
        git init --quiet
        git config user.name "TestRunner"
        git config user.email "test@example.com"
        
        $trackedFile = Join-Path $gitRepoDir "tracked.txt"
        Set-Content -Path $trackedFile -Value "base commit" -Encoding utf8
        git add tracked.txt
        git commit -m "initial commit" --quiet
        
        # Create checkpoint
        $gitTask = "git-fail-closed-$testId"
        $gitScratch = Join-Path $userHome ".gemini/antigravity/scratch/$gitTask"
        & $newScript -Task $gitTask -RepoPath $gitRepoDir | Out-Null
        
        # Intentionally remove untracked_baseline.txt to simulate corrupted/missing baseline
        $baselinePath = Join-Path $gitScratch "untracked_baseline.txt"
        if (Test-Path -Path $baselinePath) {
            Remove-Item -Path $baselinePath -Force
        }
        
        # Add a new untracked file
        $untrackedFile = Join-Path $gitRepoDir "user_precious_untracked.txt"
        Set-Content -Path $untrackedFile -Value "precious user data" -Encoding utf8
        
        # Run restore - should warn and NOT delete user_precious_untracked.txt
        & $restoreScript -Task $gitTask -RepoPath $gitRepoDir | Out-Null
        
        $untrackedStillExists = Test-Path -Path $untrackedFile
        Assert-Test -Name "Git mode preserves untracked files when baseline is missing (Fail-Closed)" -Condition $untrackedStillExists

        # Test 6: Outside git without FilePath fails closed (GAP-HIGH-03)
        $nonGitDir = Join-Path $testDir "isolated_nongit"
        New-Item -ItemType Directory -Path $nonGitDir -Force | Out-Null
        $outsideFailedClosed = $false
        $prevGitDir = $env:GIT_DIR
        $failScratchPath = Join-Path $userHome ".gemini/antigravity/scratch/fail-nongit-$testId"
        try {
            # Prevent git from traversing up to user home repo during test
            $env:GIT_DIR = (Join-Path $nonGitDir ".nonexistent_git")
            & $newScript -Task "fail-nongit-$testId" -RepoPath $nonGitDir 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { $outsideFailedClosed = $true }
        } catch {
            $outsideFailedClosed = $true
        } finally {
            $env:GIT_DIR = $prevGitDir
        }
        $noScratchCreated = -not (Test-Path -Path $failScratchPath)
        Assert-Test -Name "Checkpoint creation outside git without FilePath fails closed and leaves no scratch folder" -Condition ($outsideFailedClosed -and $noScratchCreated)

        # Test 7: Subdirectory checkpointing anchors to repo root (GAP-CRIT-01)
        # Create root untracked file
        $rootUntracked = Join-Path $gitRepoDir "root_precious_untracked.txt"
        Set-Content -Path $rootUntracked -Value "root untracked data" -Encoding utf8
        
        # Create subdirectory in git repo and move into it
        $subFolder = Join-Path $gitRepoDir "src/nested"
        New-Item -ItemType Directory -Path $subFolder -Force | Out-Null
        $subUntracked = Join-Path $subFolder "sub_untracked.txt"
        Set-Content -Path $subUntracked -Value "sub untracked data" -Encoding utf8
        
        $subTask = "sub-anchor-$testId"
        Set-Location -LiteralPath $subFolder
        & $newScript -Task $subTask | Out-Null
        
        # Add new rogue file created during task
        $rogueFile = Join-Path $subFolder "rogue_task_output.tmp"
        Set-Content -Path $rogueFile -Value "temporary build output" -Encoding utf8
        
        # Run restore from subdirectory
        & $restoreScript -Task $subTask | Out-Null
        
        $rootSurvived = Test-Path -Path $rootUntracked
        $subSurvived = Test-Path -Path $subUntracked
        $rogueRemoved = -not (Test-Path -Path $rogueFile)
        Assert-Test -Name "Subdirectory checkpoint anchors to root and preserves pre-existing untracked files" -Condition ($rootSurvived -and $subSurvived -and $rogueRemoved) -Details "root=$rootSurvived, sub=$subSurvived, rogueRemoved=$rogueRemoved"

        # Test 8: Restore-AuditCheckpoint preserves staged pre-existing untracked files during rollback
        $stagedRepoDir = Join-Path $testDir "git_staged_repo"
        New-Item -ItemType Directory -Path $stagedRepoDir -Force | Out-Null
        Set-Location -LiteralPath $stagedRepoDir
        git init --quiet
        git config user.name "TestRunner"
        git config user.email "test@example.com"
        
        $initFile = Join-Path $stagedRepoDir "init.txt"
        Set-Content -Path $initFile -Value "initial commit" -Encoding utf8
        git add init.txt
        git commit -m "initial commit" --quiet
        
        # Create pre-existing untracked file
        $baselineFile = Join-Path $stagedRepoDir "baseline.txt"
        $baselineContent = "pre-existing untracked content"
        Set-Content -Path $baselineFile -Value $baselineContent -Encoding utf8
        
        # Create checkpoint
        $stageTask = "staged-untracked-$testId"
        & $newScript -Task $stageTask -RepoPath $stagedRepoDir | Out-Null
        
        # Stage baseline.txt
        git add baseline.txt
        
        # Run restore
        & $restoreScript -Task $stageTask -RepoPath $stagedRepoDir | Out-Null
        
        $baselineStillExists = Test-Path -Path $baselineFile
        $baselineRestoredContent = if ($baselineStillExists) { (Get-Content -Path $baselineFile -Raw).Trim() } else { "" }
        Assert-Test -Name "Restore-AuditCheckpoint preserves staged pre-existing untracked files during rollback" -Condition ($baselineStillExists -and ($baselineRestoredContent -eq $baselineContent)) -Details "exists=$baselineStillExists, contentMatch=$($baselineRestoredContent -eq $baselineContent)"

        # Test 8b: New-AuditCheckpoint fails when git status returns non-zero exit code (GAP-R3-03)
        $statusFailRepo = Join-Path $testDir "git_status_fail"
        New-Item -ItemType Directory -Path $statusFailRepo -Force | Out-Null
        Set-Location -LiteralPath $statusFailRepo
        git init --quiet
        git config user.name "TestRunner"
        git config user.email "test@example.com"
        $statusInit = Join-Path $statusFailRepo "init.txt"
        Set-Content -Path $statusInit -Value "init" -Encoding utf8
        git add init.txt
        git commit -m "init" --quiet
        # Corrupt git index so git status fails with exit code != 0
        Set-Content -Path (Join-Path $statusFailRepo ".git/index") -Value "corrupted_index" -Encoding utf8
        $statusCheckFailed = $false
        try {
            & $newScript -Task "status-fail-$testId" -RepoPath $statusFailRepo 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { $statusCheckFailed = $true }
        } catch {
            $statusCheckFailed = $true
        }
        git rev-parse --verify "refs/heads/checkpoint-status-fail-$testId" 2>$null | Out-Null
        $branchWasNotCreated = ($LASTEXITCODE -ne 0)
        Assert-Test -Name "New-AuditCheckpoint checks exit code on git status failure" -Condition ($statusCheckFailed -and $branchWasNotCreated)

        # Test 8c: Restore-AuditCheckpoint fails when git ls-files returns non-zero exit code (GAP-R3-01)
        $lsFailRepo = Join-Path $testDir "git_ls_fail"
        New-Item -ItemType Directory -Path $lsFailRepo -Force | Out-Null
        Set-Location -LiteralPath $lsFailRepo
        git init --quiet
        git config user.name "TestRunner"
        git config user.email "test@example.com"
        $lsInit = Join-Path $lsFailRepo "init.txt"
        Set-Content -Path $lsInit -Value "init" -Encoding utf8
        git add init.txt
        git commit -m "init" --quiet
        # Create a valid checkpoint first
        $lsTask = "ls-fail-$testId"
        & $newScript -Task $lsTask -RepoPath $lsFailRepo | Out-Null
        # Corrupt git index so git ls-files fails during restore
        Set-Content -Path (Join-Path $lsFailRepo ".git/index") -Value "corrupted_index" -Encoding utf8
        $lsCheckFailed = $false
        try {
            & $restoreScript -Task $lsTask -RepoPath $lsFailRepo 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { $lsCheckFailed = $true }
        } catch {
            $lsCheckFailed = $true
        }
        Assert-Test -Name "Restore-AuditCheckpoint checks exit code on git ls-files failure" -Condition $lsCheckFailed

        # Test 9: Update-Gate2Diff programmatic diff injection with untracked files, encoding, backrefs, and sanitization
        $diffRepoDir = Join-Path $testDir "git_diff_repo"
        New-Item -ItemType Directory -Path $diffRepoDir -Force | Out-Null
        Set-Location -LiteralPath $diffRepoDir
        git init --quiet
        git config user.name "TestRunner"
        git config user.email "test@example.com"
        git config core.autocrlf false

        $diffTrackedFile = Join-Path $diffRepoDir "tracked.txt"
        Set-Content -Path $diffTrackedFile -Value "initial tracked line 1" -Encoding utf8
        git add tracked.txt
        git commit -m "initial commit" --quiet

        # Modify tracked file
        Add-Content -Path $diffTrackedFile -Value "`nmodified tracked line 2" -Encoding utf8

        # Add newly created untracked file with multibyte chars, PS/regex patterns, tokens, and SHAs
        $untrackedFile = Join-Path $diffRepoDir "untracked_test.txt"
        $enDash = [char]0x2013
        $rightArrow = [char]0x2192
        $mojibake = "$([char]0x00E2)$([char]0x20AC)"
        $mockGhp = "ghp_" + ("mocktoken1234567890" * 2)
        $mockBearer = "Bearer " + "secret_mock_val_12345"
        $mockJwt = "eyJ" + "mockheader.eyJmockpayload.mocksignature12345"
        $mockPrivateKeyPayload = "MIIEowIBAAKCAQEA0mockprivkeysecretpayload123456789"
        $mockClosedKey = "-----BEGIN RSA PRIVATE KEY-----`r`n$mockPrivateKeyPayload`r`n-----END RSA PRIVATE KEY-----"
        $mockUnclosedKeyHeader = "-----BEGIN OPENSSH PRIVATE KEY-----"
        $untrackedLines = @(
            "Multibyte: Phases 1$($enDash)3 and A $($rightArrow) B",
            'Regex and PS: $Matches[1] and $& and $_',
            "GitHub Token: $mockGhp",
            "Bearer Token: $mockBearer",
            "JWT Token: $mockJwt",
            "Closed Key: $mockClosedKey",
            "Unclosed Key: $mockUnclosedKeyHeader",
            'Valid Git SHA: da39a3ee5e6b4b0d3255bfef95601890afd80709',
            'Valid SHA256: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
        )
        $untrackedContent = $untrackedLines -join "`r`n"
        [System.IO.File]::WriteAllText($untrackedFile, $untrackedContent, [System.Text.UTF8Encoding]::new($false))

        $testArtifact = Join-Path $testDir "test_gate2_handoff.md"
        $artifactLines = @(
            '# Review Request: Gate 2',
            '',
            '## Diff & Impact',
            '### Diffstat',
            '{{VERBATIM_GIT_DIFFSTAT}}',
            '',
            '### Unified Diff',
            '```diff',
            '{{VERBATIM_GIT_DIFF}}',
            '```'
        )
        $artifactInitial = $artifactLines -join "`r`n"
        [System.IO.File]::WriteAllText($testArtifact, $artifactInitial, [System.Text.UTF8Encoding]::new($false))

        $updateFailed = $false
        try {
            & $updateScript -ArtifactPath $testArtifact -RepoPath $diffRepoDir
        } catch {
            $updateFailed = $true
        }

        # Query git status to verify untracked file was un-staged (index idempotency)
        $gitStatus = git -c core.quotePath=false status --porcelain
        $untrackedStatus = @($gitStatus | Where-Object { $_ -match "^\?\?\s+untracked_test\.txt" })
        $indexIdempotent = ($untrackedStatus.Count -eq 1)

        $updatedArtifact = if (Test-Path -Path $testArtifact) {
            [System.IO.File]::ReadAllText($testArtifact, [System.Text.Encoding]::UTF8)
        } else {
            ""
        }

        $untrackedInDiff = $updatedArtifact.Contains("untracked_test.txt")
        $placeholdersReplaced = (-not $updatedArtifact.Contains("{{VERBATIM_GIT_DIFFSTAT}}")) -and (-not $updatedArtifact.Contains("{{VERBATIM_GIT_DIFF}}"))
        $multibytePreserved = $updatedArtifact.Contains("Phases 1$($enDash)3") -and $updatedArtifact.Contains("A $($rightArrow) B") -and (-not $updatedArtifact.Contains($mojibake))
        $backrefsPreserved = $updatedArtifact.Contains('$Matches[1]') -and $updatedArtifact.Contains('$&') -and $updatedArtifact.Contains('$_')
        $secretsSanitized = (-not $updatedArtifact.Contains($mockGhp)) -and `
                            (-not $updatedArtifact.Contains($mockBearer)) -and `
                            (-not $updatedArtifact.Contains($mockJwt)) -and `
                            $updatedArtifact.Contains("<TEST_HASH_SANITIZED>")
        $privateKeyRedacted = (-not $updatedArtifact.Contains($mockPrivateKeyPayload)) -and $updatedArtifact.Contains("[SANITIZED PRIVATE KEY BLOCK]")
        $unclosedHeaderRedacted = (-not $updatedArtifact.Contains($mockUnclosedKeyHeader)) -and $updatedArtifact.Contains("-----BEGIN PRIVATE KEY <TEST_HASH_SANITIZED>-----")
        $hashesIntact = $updatedArtifact.Contains("da39a3ee5e6b4b0d3255bfef95601890afd80709") -and `
                        $updatedArtifact.Contains("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")

        Assert-Test -Name "Update-Gate2Diff executes successfully" -Condition (-not $updateFailed)
        Assert-Test -Name "Untracked file is present in diff output" -Condition $untrackedInDiff
        Assert-Test -Name "Untracked file returns to ?? status after execution (index idempotency)" -Condition $indexIdempotent
        Assert-Test -Name "Diffstat and unified diff placeholders are replaced" -Condition $placeholdersReplaced
        Assert-Test -Name "Multibyte UTF-8 characters are preserved without mojibake" -Condition $multibytePreserved
        Assert-Test -Name "PowerShell variables and regex backreferences are preserved verbatim" -Condition $backrefsPreserved
        Assert-Test -Name "Secret tokens are sanitized to <TEST_HASH_SANITIZED>" -Condition $secretsSanitized
        Assert-Test -Name "Multiline private key payload is completely redacted" -Condition $privateKeyRedacted
        Assert-Test -Name "Unclosed private key header fallback is sanitized" -Condition $unclosedHeaderRedacted
        Assert-Test -Name "Legitimate Git SHA and SHA256 hashes are not sanitized" -Condition $hashesIntact
    } finally {
        Set-Location -LiteralPath $origPwd
        $gitScratchDir = Join-Path $userHome ".gemini/antigravity/scratch/git-fail-closed-$testId"
        if (Test-Path -Path $gitScratchDir) {
            Remove-Item -Path $gitScratchDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        $subScratchDir = Join-Path $userHome ".gemini/antigravity/scratch/sub-anchor-$testId"
        if (Test-Path -Path $subScratchDir) {
            Remove-Item -Path $subScratchDir -Recurse -Force -ErrorAction SilentlyContinue
        }
        $stageScratchDir = Join-Path $userHome ".gemini/antigravity/scratch/staged-untracked-$testId"
        if (Test-Path -Path $stageScratchDir) {
            Remove-Item -Path $stageScratchDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

} finally {
    # Cleanup temporary directories and test-created scratch locations
    if (Test-Path -Path $scratchDir) {
        Remove-Item -Path $scratchDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $corruptScratchDir = Join-Path $userHome ".gemini/antigravity/scratch/corrupt-$taskName"
    if (Test-Path -Path $corruptScratchDir) {
        Remove-Item -Path $corruptScratchDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $statusFailScratch = Join-Path $userHome ".gemini/antigravity/scratch/status-fail-$testId"
    if (Test-Path -Path $statusFailScratch) {
        Remove-Item -Path $statusFailScratch -Recurse -Force -ErrorAction SilentlyContinue
    }
    $lsFailScratch = Join-Path $userHome ".gemini/antigravity/scratch/ls-fail-$testId"
    if (Test-Path -Path $lsFailScratch) {
        Remove-Item -Path $lsFailScratch -Recurse -Force -ErrorAction SilentlyContinue
    }
    $nestedScratchDir = Join-Path $userHome ".gemini/antigravity/scratch/nested-$taskName"
    if (Test-Path -Path $nestedScratchDir) {
        Remove-Item -Path $nestedScratchDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $bracketScratchDir = Join-Path $userHome ".gemini/antigravity/scratch/bracket-$taskName"
    if (Test-Path -LiteralPath $bracketScratchDir) {
        Remove-Item -LiteralPath $bracketScratchDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    $failScratch = Join-Path $userHome ".gemini/antigravity/scratch/fail-nongit-$testId"
    if (Test-Path -Path $failScratch) {
        Remove-Item -Path $failScratch -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -Path $testDir) {
        Remove-Item -Path $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "AuditCheckpoint Test Summary: $testsPassed / $testsRun passed, $testsFailed failed." -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })

if ($testsFailed -gt 0) {
    exit 1
} else {
    exit 0
}
