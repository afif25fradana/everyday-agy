# AuditCheckpoint.Tests.ps1
# Unit verification suite for New-AuditCheckpoint.ps1 and Restore-AuditCheckpoint.ps1
# Compatible with Windows PowerShell 5.1 and PowerShell 7.x

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$newScript = Join-Path $scriptDir "New-AuditCheckpoint.ps1"
$restoreScript = Join-Path $scriptDir "Restore-AuditCheckpoint.ps1"

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
    } finally {
        Set-Location -LiteralPath $origPwd
        $gitScratchDir = Join-Path $userHome ".gemini/antigravity/scratch/git-fail-closed-$testId"
        if (Test-Path -Path $gitScratchDir) {
            Remove-Item -Path $gitScratchDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

} finally {
    # Cleanup temporary directories
    if (Test-Path -Path $scratchDir) {
        Remove-Item -Path $scratchDir -Recurse -Force -ErrorAction SilentlyContinue
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
