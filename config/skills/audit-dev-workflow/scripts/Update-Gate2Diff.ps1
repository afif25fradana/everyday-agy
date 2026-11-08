[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Mandatory = $true)]
    [Alias("HandoffPath")]
    [string]$ArtifactPath,

    [Parameter(Mandatory = $false)]
    [string]$RepoPath = (Get-Location).Path
)

$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false

function Sanitize-DiffContent {
    param(
        [Parameter(Mandatory = $false)]
        [string]$Content
    )

    if ([string]::IsNullOrEmpty($Content)) {
        return $Content
    }

    # Bearer tokens
    $Content = [System.Text.RegularExpressions.Regex]::Replace($Content, '(?i)Bearer\s+(?!<)[A-Za-z0-9_\-\.]{12,}', 'Bearer <TEST_HASH_SANITIZED>')

    # Quoted key-value tokens
    $Content = [System.Text.RegularExpressions.Regex]::Replace($Content, '(?i)(["'']?(?:api[_-]?key|access[_-]?token|secret[_-]?key|token)["'']?\s*[:=]\s*["''])(?!<)[^\s"'']{16,}(["''])', '${1}<TEST_HASH_SANITIZED>${2}')

    # Unquoted env-style key-values (matching diff + / - line prefixes)
    $Content = [System.Text.RegularExpressions.Regex]::Replace($Content, '(?mi)(^[+\-\s]*(?:[A-Za-z0-9_]*_)?(?:api[_-]?key|access[_-]?token|secret[_-]?key)\s*[:=]\s*)(?!<)[A-Za-z0-9_\-\.]{20,}(\s*$)', '${1}<TEST_HASH_SANITIZED>${2}')

    # GitHub tokens
    $Content = [System.Text.RegularExpressions.Regex]::Replace($Content, '\b(ghp|github_pat|gho|ghu|ghs|ghr)_[A-Za-z0-9_]{20,}', '<TEST_HASH_SANITIZED>')

    # Private keys
    $Content = [System.Text.RegularExpressions.Regex]::Replace($Content, '(?i)-----BEGIN\s+([A-Z0-9_-]+\s+)?PRIVATE\s+KEY-----', '-----BEGIN PRIVATE KEY <TEST_HASH_SANITIZED>-----')

    # Cloud API keys
    $Content = [System.Text.RegularExpressions.Regex]::Replace($Content, '\b(AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|AIza[0-9A-Za-z\-_]{35}|sk-ant-(?:api|admin)\d{2}-[a-zA-Z0-9_-]{30,}|sk-(?:proj|svcacct|admin)-[a-zA-Z0-9_-]{30,}|sk-[a-zA-Z0-9]{20,})\b', '<TEST_HASH_SANITIZED>')

    # JWT tokens
    $Content = [System.Text.RegularExpressions.Regex]::Replace($Content, '\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b', '<TEST_HASH_SANITIZED>')

    return $Content
}

# Resolve artifact to an absolute path before changing working location
$resolvedArtifact = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ArtifactPath)
if (-not (Test-Path -LiteralPath $resolvedArtifact)) {
    throw "Artifact file not found: $resolvedArtifact"
}

$resolvedRepoPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($RepoPath)
if (-not (Test-Path -LiteralPath $resolvedRepoPath)) {
    throw "RepoPath does not exist: $resolvedRepoPath"
}

Push-Location -LiteralPath $resolvedRepoPath
try {
    $isInsideWorkTree = git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or $isInsideWorkTree -ne "true") {
        throw "Target path '$resolvedRepoPath' is not inside a git working tree."
    }

    $repoRoot = (git rev-parse --show-toplevel).Trim()
    Set-Location -LiteralPath $repoRoot

    $artifactContent = [System.IO.File]::ReadAllText($resolvedArtifact, [System.Text.Encoding]::UTF8)

    $hasDiffPlaceholder = $artifactContent.Contains("{{VERBATIM_GIT_DIFF}}")
    $hasStatPlaceholder = $artifactContent.Contains("{{VERBATIM_GIT_DIFFSTAT}}")
    if (-not ($hasDiffPlaceholder -or $hasStatPlaceholder)) {
        return
    }

    $untracked = @(git -c core.quotePath=false ls-files --others --exclude-standard | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -LiteralPath $_ -PathType Leaf) })

    $tempDiff = [System.IO.Path]::GetTempFileName()
    $tempStat = [System.IO.Path]::GetTempFileName()

    try {
        if ($untracked.Count -gt 0) {
            git add -N -- $untracked
        }

        git --no-pager -c core.quotePath=false diff --output=$tempDiff HEAD
        if ($LASTEXITCODE -ne 0) {
            throw "git diff failed with exit code $LASTEXITCODE"
        }
        git --no-pager diff --stat=140,80 --output=$tempStat HEAD
        if ($LASTEXITCODE -ne 0) {
            throw "git diff --stat failed with exit code $LASTEXITCODE"
        }

        $rawDiff = [System.IO.File]::ReadAllText($tempDiff, [System.Text.Encoding]::UTF8)
        $rawStat = [System.IO.File]::ReadAllText($tempStat, [System.Text.Encoding]::UTF8)

        $sanitizedDiff = Sanitize-DiffContent -Content $rawDiff
        $sanitizedStat = Sanitize-DiffContent -Content $rawStat

        if ($hasStatPlaceholder) {
            $artifactContent = $artifactContent.Replace("{{VERBATIM_GIT_DIFFSTAT}}", $sanitizedStat)
        }
        if ($hasDiffPlaceholder) {
            $artifactContent = $artifactContent.Replace("{{VERBATIM_GIT_DIFF}}", $sanitizedDiff)
        }

        [System.IO.File]::WriteAllText($resolvedArtifact, $artifactContent, [System.Text.UTF8Encoding]::new($false))
    }
    finally {
        if ($untracked.Count -gt 0) {
            git reset -q HEAD -- $untracked 2>$null
        }
        if ($tempDiff -and (Test-Path -LiteralPath $tempDiff)) {
            Remove-Item -LiteralPath $tempDiff -Force -ErrorAction SilentlyContinue
        }
        if ($tempStat -and (Test-Path -LiteralPath $tempStat)) {
            Remove-Item -LiteralPath $tempStat -Force -ErrorAction SilentlyContinue
        }
    }
}
finally {
    Pop-Location
}
