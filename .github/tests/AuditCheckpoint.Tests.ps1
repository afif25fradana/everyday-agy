# AuditCheckpoint.Tests.ps1
# Unit verification suite for New-AuditCheckpoint.ps1 and Restore-AuditCheckpoint.ps1
# Compatible with Windows PowerShell 5.1 and PowerShell 7.x

$repoRoot = if ($PSScriptRoot) {
    Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
} elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path))
} else {
    (Get-Location).Path
}
$configScriptsDir = Join-Path (Join-Path $repoRoot "config") "scripts"
$newScript = Join-Path $configScriptsDir "New-AuditCheckpoint.ps1"
$restoreScript = Join-Path $configScriptsDir "Restore-AuditCheckpoint.ps1"
$updateScript = Join-Path $configScriptsDir "Update-Gate2Diff.ps1"
foreach ($requiredScript in @($newScript, $restoreScript, $updateScript)) {
    if (-not (Test-Path -LiteralPath $requiredScript)) {
        Write-Error "Required script not found at $requiredScript!"
        exit 1
    }
}

$ErrorActionPreference = "Stop"

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

    # Test 4c: Fail-closed hashes.txt enforcement when manifest is missing or lacks entry
    $missingHashesTask = "missinghashes-$taskName"
    $missingHashesScratch = Join-Path $userHome ".gemini/antigravity/scratch/$missingHashesTask"
    $missingHashesFile = Join-Path $testDir "missing_hashes.txt"
    Set-Content -LiteralPath $missingHashesFile -Value "original safe content" -Encoding utf8
    & $newScript -Task $missingHashesTask -FilePath $missingHashesFile | Out-Null
    Set-Content -LiteralPath $missingHashesFile -Value "tampered content" -Encoding utf8
    Remove-Item -LiteralPath (Join-Path $missingHashesScratch "hashes.txt") -Force

    $global:LASTEXITCODE = 0
    $missingHashesFailed = $false
    try {
        & $restoreScript -Task $missingHashesTask -FilePath $missingHashesFile 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { $missingHashesFailed = $true }
    } catch {
        $missingHashesFailed = $true
    }
    $afterMissingHashes = (Get-Content -LiteralPath $missingHashesFile -Raw).Trim()
    Assert-Test -Name "File mode restore fails closed when hashes.txt is missing" -Condition ($missingHashesFailed -and $afterMissingHashes -eq "tampered content") -Details "failed=$missingHashesFailed content=$afterMissingHashes"

    $noEntryTask = "noentry-$taskName"
    $noEntryScratch = Join-Path $userHome ".gemini/antigravity/scratch/$noEntryTask"
    $noEntryFile = Join-Path $testDir "no_entry.txt"
    Set-Content -LiteralPath $noEntryFile -Value "original safe content" -Encoding utf8
    & $newScript -Task $noEntryTask -FilePath $noEntryFile | Out-Null
    Set-Content -LiteralPath $noEntryFile -Value "tampered noentry content" -Encoding utf8
    Set-Content -LiteralPath (Join-Path $noEntryScratch "hashes.txt") -Value "0000000000000000000000000000000000000000000000000000000000000000  C:\other\none.bak  C:\other\none" -Encoding utf8

    $global:LASTEXITCODE = 0
    $noEntryFailed = $false
    try {
        & $restoreScript -Task $noEntryTask -FilePath $noEntryFile 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { $noEntryFailed = $true }
    } catch {
        $noEntryFailed = $true
    }
    $afterNoEntry = (Get-Content -LiteralPath $noEntryFile -Raw).Trim()
    Assert-Test -Name "File mode restore fails closed when hashes.txt lacks backup entry" -Condition ($noEntryFailed -and $afterNoEntry -eq "tampered noentry content") -Details "failed=$noEntryFailed content=$afterNoEntry"

    # Test 4d: Task alphanumeric validation, directory rejection, and literal comma filename support
    $global:LASTEXITCODE = 0
    $badTaskRejected = $false
    try {
        & $newScript -Task "..." -FilePath $testFile 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { $badTaskRejected = $true }
    } catch {
        $badTaskRejected = $true
    }
    Assert-Test -Name "New-AuditCheckpoint rejects Task with no alphanumeric characters" -Condition $badTaskRejected

    $global:LASTEXITCODE = 0
    $dirRejected = $false
    try {
        & $newScript -Task "dir-reject-$testId" -FilePath $testDir 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { $dirRejected = $true }
    } catch {
        $dirRejected = $true
    }
    Assert-Test -Name "New-AuditCheckpoint rejects directory path in -FilePath" -Condition $dirRejected

    $commaFile = Join-Path $testDir "a,b.txt"
    $commaTask = "comma-$taskName"
    Set-Content -LiteralPath $commaFile -Value "comma original" -Encoding utf8
    $commaOk = $true
    try {
        & $newScript -Task $commaTask -FilePath $commaFile | Out-Null
        if ($LASTEXITCODE -ne 0) { $commaOk = $false }
        Set-Content -LiteralPath $commaFile -Value "comma modified" -Encoding utf8
        & $restoreScript -Task $commaTask -FilePath $commaFile | Out-Null
        if ($LASTEXITCODE -ne 0) { $commaOk = $false }
    } catch {
        $commaOk = $false
    }
    $commaRestored = if (Test-Path -LiteralPath $commaFile) { (Get-Content -LiteralPath $commaFile -Raw).Trim() } else { "" }
    Assert-Test -Name "File mode preserves literal comma filename a,b.txt without splitting" -Condition ($commaOk -and $commaRestored -eq "comma original")

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
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        git rev-parse --verify "refs/heads/checkpoint-status-fail-$testId" 2>$null | Out-Null
        $branchWasNotCreated = ($LASTEXITCODE -ne 0)
        $ErrorActionPreference = $prevEAP
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
        $mockBase64Bearer = "Bearer " + "ab+cd/ef==123456"
        $mockQuotedV2 = '"my_api_key_v2"' + ': "super_secret_key_value_123"'
        $mockUnquotedToken = "TOKEN" + "=unquoted_secret_token_val_123456"
        $mockJwt = "eyJ" + "mockheader.eyJmockpayload.mocksignature12345"
        $mockPrivateKeyPayload = "MIIEowIBAAKCAQEA0mockprivkeysecretpayload123456789"
        $mockClosedKey = ("-----" + "BEGIN RSA " + "PRIVATE KEY-----") + "`r`n$mockPrivateKeyPayload`r`n" + ("-----" + "END RSA " + "PRIVATE KEY-----")
        $mockUnclosedKeyHeader = "-----" + "BEGIN OPENSSH " + "PRIVATE KEY-----"
        $untrackedLines = @(
            "Multibyte: Phases 1$($enDash)3 and A $($rightArrow) B",
            'Regex and PS: $Matches[1] and $& and $_',
            "GitHub Token: $mockGhp",
            "Bearer Token: $mockBearer",
            "Base64 Bearer: $mockBase64Bearer",
            "Quoted V2 Key: $mockQuotedV2",
            $mockUnquotedToken,
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
                            (-not $updatedArtifact.Contains("ab+cd/ef==123456")) -and `
                            (-not $updatedArtifact.Contains("super_secret_key_value_123")) -and `
                            (-not $updatedArtifact.Contains("unquoted_secret_token_val_123456")) -and `
                            (-not $updatedArtifact.Contains($mockJwt)) -and `
                            $updatedArtifact.Contains("<TEST_HASH_SANITIZED>")
        $privateKeyRedacted = (-not $updatedArtifact.Contains($mockPrivateKeyPayload)) -and $updatedArtifact.Contains("[SANITIZED PRIVATE KEY BLOCK]") -and (-not $updatedArtifact.Contains('`n['))
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

    # Test 10: Multi-checkpoint update on same file restores latest backup (REL-01)
    $multiFile = Join-Path $testDir "multi_checkpoint.txt"
    Set-Content -LiteralPath $multiFile -Value "initial version 1" -Encoding utf8
    $multiTask = "multi-$taskName"
    & $newScript -Task $multiTask -FilePath $multiFile | Out-Null

    # Second checkpoint for same file with updated content
    Set-Content -LiteralPath $multiFile -Value "updated version 2" -Encoding utf8
    & $newScript -Task $multiTask -FilePath $multiFile | Out-Null

    # Tamper file on disk
    Set-Content -LiteralPath $multiFile -Value "tampered corrupted version 3" -Encoding utf8

    # Restore should restore the latest backup (version 2)
    try {
        & $restoreScript -Task $multiTask -FilePath $multiFile | Out-Null
    } catch {
        # Recorded restore failure
    }
    $restoredMulti = if (Test-Path -LiteralPath $multiFile) { (Get-Content -LiteralPath $multiFile -Raw).Trim() } else { "" }
    Assert-Test -Name "Multi-checkpoint update on same file restores latest backup" -Condition ($restoredMulti -eq "updated version 2")

    # Test 11: Untracked multibyte UTF-8 baseline reading in PS 5.1 (REL-02)
    $mbRepoDir = Join-Path $testDir "git_mb_repo"
    New-Item -ItemType Directory -Path $mbRepoDir -Force | Out-Null
    $mbOrigPwd = Get-Location
    $mbTask = "mb-untracked-$testId"
    $mbScratchDir = Join-Path $userHome ".gemini/antigravity/scratch/$mbTask"
    try {
        Set-Location -LiteralPath $mbRepoDir
        git init --quiet
        git config user.name "TestRunner"
        git config user.email "test@example.com"
        git config core.quotepath false

        $mbTracked = Join-Path $mbRepoDir "tracked.txt"
        Set-Content -Path $mbTracked -Value "base" -Encoding utf8
        git add tracked.txt
        git commit -m "base" --quiet

        # Create multibyte untracked file
        $mbUntracked = Join-Path $mbRepoDir "café_測試.txt"
        Set-Content -LiteralPath $mbUntracked -Value "precious multibyte data" -Encoding utf8
        $mbNewRogue = Join-Path $mbRepoDir "new_$([char]0x00E9)_$([char]0x6E2C).txt"

        # Verify both New-AuditCheckpoint and Restore-AuditCheckpoint under forced CP437 output encoding
        $isWin = $IsWindows -or (-not (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue))
        if ($isWin) {
            $newCmd437 = "[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(437); & '$newScript' -Task '$mbTask' -RepoPath '$mbRepoDir'"
            powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $newCmd437 2>&1 | Out-Null
            $mbNewRc = $LASTEXITCODE
            Set-Content -LiteralPath $mbNewRogue -Value "post-checkpoint rogue multibyte" -Encoding utf8
            $restoreCmd437 = "[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding(437); & '$restoreScript' -Task '$mbTask' -RepoPath '$mbRepoDir'"
            powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $restoreCmd437 2>&1 | Out-Null
            $mbRestoreRc = $LASTEXITCODE
            $mbPreserved = ($mbNewRc -eq 0) -and ($mbRestoreRc -eq 0) -and (Test-Path -LiteralPath $mbUntracked) -and (-not (Test-Path -LiteralPath $mbNewRogue))
            Assert-Test -Name "New and Restore preserve pre-existing multibyte file and prune rogue multibyte file under CP437 in PS 5.1" -Condition $mbPreserved -Details "newRc=$mbNewRc restoreRc=$mbRestoreRc preserved=$(Test-Path -LiteralPath $mbUntracked) rogueGone=$(-not (Test-Path -LiteralPath $mbNewRogue))"
        } else {
            & $newScript -Task $mbTask -RepoPath $mbRepoDir | Out-Null
            $mbNewRc = $LASTEXITCODE
            Set-Content -LiteralPath $mbNewRogue -Value "post-checkpoint rogue multibyte" -Encoding utf8
            & $restoreScript -Task $mbTask -RepoPath $mbRepoDir | Out-Null
            $mbRestoreRc = $LASTEXITCODE
            $mbPreserved = ($mbNewRc -eq 0) -and ($mbRestoreRc -eq 0) -and (Test-Path -LiteralPath $mbUntracked) -and (-not (Test-Path -LiteralPath $mbNewRogue))
            Assert-Test -Name "New and Restore preserve pre-existing multibyte file and prune rogue multibyte file" -Condition $mbPreserved
        }
    } finally {
        Set-Location -LiteralPath $mbOrigPwd
        if (Test-Path -LiteralPath $mbScratchDir) {
            Remove-Item -LiteralPath $mbScratchDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Test 12: base_branch.txt restores detached HEAD back to base branch and remains optional when absent
    $bbRepoDir = Join-Path $testDir "git_basebranch_repo"
    New-Item -ItemType Directory -Path $bbRepoDir -Force | Out-Null
    $bbOrigPwd = Get-Location
    $bbTask = "basebranch-$testId"
    $bbScratchDir = Join-Path $userHome ".gemini/antigravity/scratch/$bbTask"
    try {
        Set-Location -LiteralPath $bbRepoDir
        git init --quiet
        git config user.name "TestRunner"
        git config user.email "test@example.com"
        $bbFile = Join-Path $bbRepoDir "tracked.txt"
        Set-Content -LiteralPath $bbFile -Value "v1" -Encoding utf8
        git add tracked.txt
        git commit -m "init" --quiet
        $initialBranch = (git symbolic-ref --quiet --short HEAD).Trim()

        & $newScript -Task $bbTask -RepoPath $bbRepoDir | Out-Null
        $bbFilePath = Join-Path $bbScratchDir "base_branch.txt"
        $savedBranch = if (Test-Path -LiteralPath $bbFilePath) { (Get-Content -LiteralPath $bbFilePath -Raw -Encoding utf8).Trim() } else { "" }

        git checkout --detach HEAD --quiet
        Set-Content -LiteralPath $bbFile -Value "dirty" -Encoding utf8
        $global:LASTEXITCODE = 0
        & $restoreScript -Task $bbTask -RepoPath $bbRepoDir | Out-Null
        $bbRc1 = $LASTEXITCODE
        $restoredBranch = (git symbolic-ref --quiet --short HEAD 2>$null | Out-String).Trim()
        Assert-Test -Name "Restore-AuditCheckpoint returns detached HEAD to base_branch.txt" -Condition ($bbRc1 -eq 0 -and $savedBranch -eq $initialBranch -and $restoredBranch -eq $initialBranch) -Details "saved=$savedBranch restored=$restoredBranch rc=$bbRc1"

        # Backward compatibility: base_branch.txt is optional when absent
        if (Test-Path -LiteralPath $bbFilePath) {
            Remove-Item -LiteralPath $bbFilePath -Force
        }
        Set-Content -LiteralPath $bbFile -Value "dirty2" -Encoding utf8
        $global:LASTEXITCODE = 0
        & $restoreScript -Task $bbTask -RepoPath $bbRepoDir | Out-Null
        $bbRc2 = $LASTEXITCODE
        $bbContent2 = (Get-Content -LiteralPath $bbFile -Raw).Trim()
        Assert-Test -Name "Restore-AuditCheckpoint succeeds when base_branch.txt is absent" -Condition ($bbRc2 -eq 0 -and $bbContent2 -eq "v1") -Details "rc=$bbRc2 content=$bbContent2"
    } finally {
        Set-Location -LiteralPath $bbOrigPwd
        if (Test-Path -LiteralPath $bbScratchDir) {
            Remove-Item -LiteralPath $bbScratchDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Test 13: Safe ReparsePoint (NTFS junction) cleanup does not follow links into target directories
    $juncRepoDir = Join-Path $testDir "git_junc_repo"
    $outsidePrecious = Join-Path $testDir "outside_precious"
    New-Item -ItemType Directory -Path $juncRepoDir, $outsidePrecious -Force | Out-Null
    $preciousTargetFile = Join-Path $outsidePrecious "precious.txt"
    Set-Content -LiteralPath $preciousTargetFile -Value "do not delete via junction" -Encoding utf8
    $juncOrigPwd = Get-Location
    $juncTask = "junc-$testId"
    $juncScratchDir = Join-Path $userHome ".gemini/antigravity/scratch/$juncTask"
    try {
        Set-Location -LiteralPath $juncRepoDir
        git init --quiet
        git config user.name "TestRunner"
        git config user.email "test@example.com"
        $jInit = Join-Path $juncRepoDir "init.txt"
        Set-Content -LiteralPath $jInit -Value "init" -Encoding utf8
        git add init.txt
        git commit -m "init" --quiet

        & $newScript -Task $juncTask -RepoPath $juncRepoDir | Out-Null

        $rogueParent = Join-Path $juncRepoDir "rogue_dir"
        $bracketRogueParent = Join-Path $juncRepoDir "dir[1]"
        New-Item -ItemType Directory -Path $rogueParent, $bracketRogueParent -Force | Out-Null
        $nestedJunc = Join-Path $rogueParent "junc_out"
        $bracketJunc = Join-Path $bracketRogueParent "junc_bracket"
        $directJunc = Join-Path $juncRepoDir "direct_junc"
        $juncLinkType = if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { "Junction" } else { "SymbolicLink" }
        $null = New-Item -ItemType $juncLinkType -Path $nestedJunc -Target $outsidePrecious -ErrorAction Stop
        $null = New-Item -ItemType $juncLinkType -Path $bracketJunc -Target $outsidePrecious -ErrorAction Stop
        $null = New-Item -ItemType $juncLinkType -Path $directJunc -Target $outsidePrecious -ErrorAction Stop

        $global:LASTEXITCODE = 0
        & $restoreScript -Task $juncTask -RepoPath $juncRepoDir | Out-Null
        $jRc = $LASTEXITCODE
        $juncGone = (-not (Test-Path -LiteralPath $nestedJunc)) -and (-not (Test-Path -LiteralPath $bracketJunc)) -and (-not (Test-Path -LiteralPath $bracketRogueParent)) -and (-not (Test-Path -LiteralPath $directJunc))
        $targetSurvived = (Test-Path -LiteralPath $preciousTargetFile) -and ((Get-Content -LiteralPath $preciousTargetFile -Raw).Trim() -eq "do not delete via junction")
        Assert-Test -Name "Restore-AuditCheckpoint unlinks untracked junctions (including dir[1] ancestors) without deleting target files" -Condition ($jRc -eq 0 -and $juncGone -and $targetSurvived) -Details "rc=$jRc juncGone=$juncGone targetSurvived=$targetSurvived"

        # Direct Remove-PathSafeNoFollow verification with trailing slash and [1] bracketed parent folder
        $trailRoot = Join-Path $testDir "trail_dir[1]"
        New-Item -ItemType Directory -Path $trailRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $trailRoot "regular.txt") -Value "temp" -Encoding utf8
        $trailNestedJunc = Join-Path $trailRoot "sub_junc"
        $trailDirectJunc = Join-Path $testDir "direct_trail[1]"
        $null = New-Item -ItemType $juncLinkType -Path $trailNestedJunc -Target $outsidePrecious -ErrorAction Stop
        $null = New-Item -ItemType $juncLinkType -Path $trailDirectJunc -Target $outsidePrecious -ErrorAction Stop

        $restoreAstErr = $null
        $restoreAst = [System.Management.Automation.Language.Parser]::ParseFile($restoreScript, [ref]$null, [ref]$restoreAstErr)
        $removeFnAst = $restoreAst.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq "Remove-PathSafeNoFollow" }, $true)
        $trailOk = $false
        if ($null -ne $removeFnAst) {
            & {
                . ([scriptblock]::Create($removeFnAst.Extent.Text))
                Remove-PathSafeNoFollow -TargetPath ($trailDirectJunc + "/")
                Remove-PathSafeNoFollow -TargetPath ($trailRoot + "/")
            }
            $trailOk = (-not (Test-Path -LiteralPath $trailDirectJunc)) -and (-not (Test-Path -LiteralPath $trailRoot)) -and (Test-Path -LiteralPath $preciousTargetFile) -and ((Get-Content -LiteralPath $preciousTargetFile -Raw).Trim() -eq "do not delete via junction")
        }
        Assert-Test -Name "Remove-PathSafeNoFollow unlinks bracketed and trailing-slash reparse targets safely" -Condition $trailOk -Details "directGone=$(-not (Test-Path -LiteralPath $trailDirectJunc)) rootGone=$(-not (Test-Path -LiteralPath $trailRoot)) targetExists=$(Test-Path -LiteralPath $preciousTargetFile)"
    } finally {
        foreach ($jp in @($nestedJunc, $bracketJunc, $directJunc, $trailNestedJunc, $trailDirectJunc)) {
            if ($jp -and (Test-Path -LiteralPath $jp)) {
                try { [System.IO.Directory]::Delete($jp, $false) } catch {}
            }
        }
        Set-Location -LiteralPath $juncOrigPwd
        if (Test-Path -LiteralPath $juncScratchDir) {
            Remove-Item -LiteralPath $juncScratchDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Test 14: File mode $pathHash preserves case on POSIX and stays case-insensitive on Windows
    $caseTask = "case-$taskName"
    $caseScratchDir = Join-Path $userHome ".gemini/antigravity/scratch/$caseTask"
    if ([System.IO.Path]::DirectorySeparatorChar -eq '/') {
        $caseDir = Join-Path $testDir "case_posix"
        $upperSub = Join-Path $caseDir "DirCase"
        $lowerSub = Join-Path $caseDir "dircase"
        New-Item -ItemType Directory -Path $upperSub, $lowerSub -Force | Out-Null
        $upperFoo = Join-Path $caseDir "Foo.txt"
        $lowerFoo = Join-Path $caseDir "foo.txt"
        $upperItem = Join-Path $upperSub "item.txt"
        $lowerItem = Join-Path $lowerSub "item.txt"
        Set-Content -LiteralPath $upperFoo -Value "upper foo" -Encoding utf8
        Set-Content -LiteralPath $lowerFoo -Value "lower foo" -Encoding utf8
        Set-Content -LiteralPath $upperItem -Value "upper dir item" -Encoding utf8
        Set-Content -LiteralPath $lowerItem -Value "lower dir item" -Encoding utf8

        & $newScript -Task $caseTask -FilePath @($upperFoo, $lowerFoo, $upperItem, $lowerItem) | Out-Null
        $itemBackups = @(Get-ChildItem -LiteralPath $caseScratchDir | Where-Object { $_.Name -clike "*_item.txt.bak" })
        $upperFooBak = Get-ChildItem -LiteralPath $caseScratchDir | Where-Object { $_.Name -clike "*_Foo.txt.bak" } | Select-Object -First 1
        $lowerFooBak = Get-ChildItem -LiteralPath $caseScratchDir | Where-Object { $_.Name -clike "*_foo.txt.bak" } | Select-Object -First 1
        $upperPrefix = if ($upperFooBak) { ($upperFooBak.Name -split '_')[0] } else { "" }
        $lowerPrefix = if ($lowerFooBak) { ($lowerFooBak.Name -split '_')[0] } else { "" }

        Set-Content -LiteralPath $upperFoo -Value "tampered 1" -Encoding utf8
        Set-Content -LiteralPath $lowerFoo -Value "tampered 2" -Encoding utf8
        Set-Content -LiteralPath $upperItem -Value "tampered 3" -Encoding utf8
        Set-Content -LiteralPath $lowerItem -Value "tampered 4" -Encoding utf8
        & $restoreScript -Task $caseTask -FilePath @($upperFoo, $lowerFoo, $upperItem, $lowerItem) | Out-Null

        $posixCaseOk = ($itemBackups.Count -eq 2) -and (-not [string]::IsNullOrEmpty($upperPrefix)) -and (-not [string]::IsNullOrEmpty($lowerPrefix)) -and ($upperPrefix -ne $lowerPrefix) -and
            ((Get-Content -LiteralPath $upperFoo -Raw).Trim() -eq "upper foo") -and
            ((Get-Content -LiteralPath $lowerFoo -Raw).Trim() -eq "lower foo") -and
            ((Get-Content -LiteralPath $upperItem -Raw).Trim() -eq "upper dir item") -and
            ((Get-Content -LiteralPath $lowerItem -Raw).Trim() -eq "lower dir item")
        Assert-Test -Name "File mode preserves case-sensitive pathHash on POSIX without collisions" -Condition $posixCaseOk -Details "itemBackups=$($itemBackups.Count) upperPrefix=$upperPrefix lowerPrefix=$lowerPrefix"
    } else {
        $winCaseFile = Join-Path $testDir "CaseWindow.txt"
        $winCaseFileLower = Join-Path $testDir "casewindow.txt"
        Set-Content -LiteralPath $winCaseFile -Value "win case original" -Encoding utf8
        & $newScript -Task $caseTask -FilePath $winCaseFile | Out-Null
        Remove-Item -LiteralPath $winCaseFile -Force
        & $restoreScript -Task $caseTask -FilePath $winCaseFileLower | Out-Null
        $winRestored = if (Test-Path -LiteralPath $winCaseFileLower) { (Get-Content -LiteralPath $winCaseFileLower -Raw).Trim() } else { "" }
        Assert-Test -Name "File mode maintains case-insensitive pathHash matching on Windows" -Condition ($winRestored -eq "win case original") -Details "restored=$winRestored"
    }

} finally {
    # Cleanup temporary directories and test-created scratch locations
    foreach ($extraTask in @($taskName, "multi-$taskName", "corrupt-$taskName", "missinghashes-$taskName", "noentry-$taskName", "comma-$taskName", "status-fail-$testId", "ls-fail-$testId", "nested-$taskName", "bracket-$taskName", "fail-nongit-$testId", "case-$taskName")) {
        $extraScratch = Join-Path $userHome ".gemini/antigravity/scratch/$extraTask"
        if (Test-Path -LiteralPath $extraScratch) {
            Remove-Item -LiteralPath $extraScratch -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    if (Test-Path -LiteralPath $testDir) {
        Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "AuditCheckpoint Test Summary: $testsPassed / $testsRun passed, $testsFailed failed." -ForegroundColor $(if ($testsFailed -eq 0) { "Green" } else { "Red" })

if ($testsFailed -gt 0) {
    exit 1
} else {
    exit 0
}
