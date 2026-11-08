# ADR-0025: Programmatic Diff Injection and Two-Layer YAML Validation

## Status
Accepted

## Date
2026-11-08

## Context
In reviewing our change handoff workflow and repository validation checks, we encountered two distinct operational reliability problems:

1. **Diff Injection Encoding and Substitution Corruptions**:
   - Review handoff documents rely on unified diffs and stat summaries. When inserting diff output using ad-hoc PowerShell commands, several failure modes occurred.
   - Under Windows PowerShell 5.1, string file writes defaulted to Windows-1252 (ANSI), converting valid UTF-8 characters into mojibake (for example, UTF-8 dashes appearing as `â€“`).
   - Using PowerShell's `-replace` operator interpreted tokens such as `$1`, `$_`, and `$&` as regular expression replacement groups. Because unified diffs frequently include regexes, PowerShell variables, and shell scripts, this silently corrupted the injected diff content.
   - Standard `git diff HEAD` ignored newly added untracked files unless they had been explicitly staged, resulting in incomplete diffs.
   - Direct diff output risked including development tokens or test keys in handoff documents.

2. **YAML Validation Gaps and Tooling Limits**:
   - The repository contains both standalone YAML files (such as GitHub Actions workflows and issue templates) and YAML frontmatter headers in Markdown files (`agent.md` and `SKILL.md`).
   - Continuous integration lacked automated YAML syntax verification.
   - Standard Python YAML parsers like PyYAML have known limitations: `yaml.safe_load()` silently ignores duplicate mapping keys instead of failing.
   - External linters like `yamllint` cannot parse Markdown frontmatter blocks directly and require Python dependencies that are not pre-installed on standard developer environments.

## Decision

1. **Dedicated Diff Injection Utility (`Update-Gate2Diff.ps1`)**:
   We introduced a dedicated helper script (`config/skills/audit-dev-workflow/scripts/Update-Gate2Diff.ps1`) to handle diff capture, sanitization, and document injection:
   - **Direct Output Redirection**: Uses `git --no-pager diff --output=<tempFile>` and `git --no-pager diff --stat=140,80 --output=<tempFile>` to capture diffs directly to temporary files on disk. This avoids console handle allocation problems in headless PowerShell 5.1 environments.
   - **Intent-to-Add for Untracked Files**: Automatically runs `git add -N` on untracked files before capturing the diff, ensuring new files appear in the unified diff without requiring manual staging. A `finally` block runs `git reset -q HEAD -- $untracked` to restore index state, guaranteeing staging idempotency.
   - **Literal String Replacement**: Replaces `{{VERBATIM_GIT_DIFF}}` and `{{VERBATIM_GIT_DIFFSTAT}}` placeholders using .NET string literal `.Replace()`, eliminating regex backreference substitutions.
   - **BOM-less UTF-8 Encoding**: Reads and writes files using `[System.Text.UTF8Encoding]::new($false)`, preventing both ANSI corruption and unwanted UTF-8 byte order marks.
   - **Token Sanitization**: Scrubs potential credentials (bearer tokens, private keys, API keys, JWTs) against repository scanner patterns while preserving 40-character Git commit SHAs and SHA-256 hashes.

2. **Two-Layer YAML Validation**:
   We implemented a two-layer validation strategy covering both local developer environments and continuous integration:
   - **Layer 1: Native PowerShell Test Suite (`YamlValidation.Tests.ps1`)**:
     - Operates with zero external dependencies across Windows PowerShell 5.1 and PowerShell 7.x on both Windows and Linux.
     - Validates pure YAML files (`.github/**/*.yml`) and frontmatter blocks in `config/agents/*/agent.md` and `config/skills/**/SKILL.md`.
     - Detects syntax errors, forbids tab indentation, checks for duplicate mapping keys across nested scopes, handles multiline block scalars (`|` and `>`), and normalizes CRLF and LF line endings.
     - Validates agent frontmatter schemas (requiring `name`, `description`, `model`, `tools`) and skill schemas (enforcing description length limits of 128 characters or fewer).
   - **Layer 2: CI Linter Configuration (`.yamllint.yml`)**:
     - Configures `yamllint` for standard GitHub Actions workflows and templates in `.github/workflows/ci.yml`.
     - Disables noisy rules for workflow files (`truthy`, `line-length`, `document-start`) while enforcing duplicate key checks, 2-space indentation, and bracket spacing.
     - Excludes markdown documentation and agent directories, which are validated by Layer 1.

## Alternatives Considered & Rejected
- **Inline PowerShell `-replace` Commands**: Rejected because regex group substitution corrupts PowerShell scripts, regex patterns, and special symbols in code diffs.
- **Third-Party Node.js or Python Diff Injection Packages**: Rejected to avoid adding external runtime dependencies to lightweight developer workflows. Native PowerShell and Git standard capabilities fully solve the problem.
- **PyYAML-Only Validation in CI**: Rejected because PyYAML silently permits duplicate dictionary keys and fails to catch mapping collisions.
- **yamllint for Frontmatter Validation**: Rejected because `yamllint` treats Markdown documents with frontmatter as invalid YAML documents unless wrapped in custom preprocessors.

## Consequences
- **Positive**: Handoff documents consistently contain exact, uncorrupted diffs with correct UTF-8 encoding and sanitized secrets.
- **Positive**: Untracked new files are automatically included in handoff diffs without modifying Git index state permanently.
- **Positive**: Zero-dependency YAML validation runs locally on developer workstations without installing Python or Node.js packages.
- **Positive**: Continuous integration catches duplicate YAML keys and syntax errors before merges.
- **Neutral / Operational Requirements**: Handoff generation must invoke `Update-Gate2Diff.ps1` instead of manual text substitution.
