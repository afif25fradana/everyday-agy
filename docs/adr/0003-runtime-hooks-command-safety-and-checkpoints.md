# ADR-0003: Runtime Hooks, AST Command Safety, Checkpoints, and YAML Validation

## Status
Accepted

## Date
2026-11-11

## Context
Text-only rules in `config/GEMINI.md` are easy for models to overlook during long sessions, while Node.js wrappers and POSIX shell hooks break on Windows PowerShell 5.1 (where `&&` and `||` fail to parse and bash heredocs error out). Running autonomous edits on Windows also exposed specific failure modes across command filtering, rollbacks, diff generation, and CI validation:
1. **Command safety bypasses**: Early checks inspected raw token strings only, so they missed direct `[System.IO.Directory]::Delete` calls, `Start-Process` / `saps` / `start`, parameter abbreviations (`Remove-Item -rec`), backtick/quote obfuscation (``--`force``), wrapper flags (`rtk -v`, `sudo -u`), splatting (`@var`), WMI/COM process spawning, subcommand-unaware git `-m` skipping (such as `git checkout -m` hiding `-f`), relative `.ssh`/`.aws`/`.gnupg` targets, and `git config` hook overrides. Meanwhile, an earlier `PreToolUse` hook on `invoke_subagent` broke `teamwork` council prompts (`"Requested team: ..."`), built-in `research`/`self` agents, and leaner 3-slot XML briefs.
2. **Rollback and diff corruption**: `git reset --hard` wiped newly staged untracked files, file-mode restores lacked integrity checksums, and ad-hoc PowerShell diff scripts defaulted to Windows-1252 mojibake (`â€“`) in PS 5.1, mangled `$1`/`$_`/`$&` regex tokens via `-replace`, missed untracked files, and leaked multiline private keys in handoffs.
3. **Test framework limits on Windows**: Windows PowerShell 5.1 ships with Pester 3.4.0 natively, while Pester 5 requires external package installation. CI needed regression suites that run identically across PS 5.1 and `pwsh` 7.6 (Windows and Linux) with zero external dependencies, without leaking repo-only test files into `~/.gemini/` on restore.
4. **YAML parser gaps**: Standard Python `yaml.safe_load()` (PyYAML) silently ignores duplicate mapping keys instead of rejecting them, while external `yamllint` cannot parse Markdown frontmatter headers directly and requires a Python install.

## Decision

### 1. Native Security and Diff Hook Router (`config/hooks.json`, `config/scripts/Invoke-AntigravityHook.ps1`)
I wired Antigravity's native hook events to deterministic security and diff guards, leaving out `invoke_subagent` so `teamwork`, `research`, `self`, and 3-slot briefs pass through untouched:
- **Guard 1 (`PreToolUse`, matcher `run_command`)**: Pipes `CommandLine` through `Test-PowerShellCommandSafety.ps1` and emits JSON `{"decision":"allow"|"deny"|"ask"}`.
- **Guard 2 (`PreToolUse`, matcher `view_file|replace_file_content|multi_replace_file_content|write_to_file`)**: Runs `Test-DenyPath` (normalizing `~`, `$HOME`, `$env:USERPROFILE`, `%USERPROFILE%`, and `..` segments to block `.env*` except `.env.example`/`.env.sample`/`.env.template`, `.ssh`/`.aws`/`.gnupg`, `*.key`, `*.pem`, and `.gemini/(antigravity*/)?mcp`). It enforces secret deny-paths only; workspace and role boundaries remain governed by `config/GEMINI.md` and `orchestrator/SKILL.md`.
- **Guard 4 (`PostToolUse`, matcher `write_to_file|replace_file_content|multi_replace_file_content`)**: Runs `Update-Gate2Diff.ps1` when `error` is empty, the exact filename basename is `gate2_handoff.md`, and `{{VERBATIM_GIT_DIFF}}` or `{{VERBATIM_GIT_DIFFSTAT}}` placeholders are present, then returns `{}`.
- **Runtime isolation**: Strips UTF-8 BOM from stdin JSON, writes machine JSON strictly to stdout, falls back to `ask` (`PreToolUse`) or `{}` (`PostToolUse`) on malformed payloads, and logs errors to a `5 MB` cap-rotated `hooks.log` in `~/.gemini/antigravity/scratch/`.

### 2. PowerShell AST Command Safety Validator (`Test-PowerShellCommandSafety.ps1`)
Instead of fragile regex matching, `config/skills/orchestrator/scripts/Test-PowerShellCommandSafety.ps1` parses command lines with `[System.Management.Automation.Language.Parser]::ParseInput` without executing them:
- **Token normalization and wrapper unwrapping**: Strips backticks, internal quotes, control characters, module prefixes, and `.exe`/`.cmd`/`.bat` extensions; unwraps `rtk`, `sudo`, and `gsudo` across flags (`-u`, `-C`, `proxy`, etc.).
- **Blocked execution primitives**: Rejects dynamic `&`/`.` invocations, secondary shells (`cmd`, `wsl`, `bash`, `sh`), inline `pwsh`/`powershell` strings without `-File`, destructive/wrapper cmdlets (`Format-*`, `Clear-Disk`, `Start-Process`/`saps`/`start`, `Invoke-Expression`/`iex`, `Invoke-CimMethod`/`Invoke-WmiMethod`, `Start-Job`), `robocopy` `/mir`/`-mir`/`purge`/`mov`/`move`, `New-Object -ComObject` or `Diagnostics.Process`, .NET `Process::Start`, WMI `Win32_Process.Create`, COM `GetTypeFromProgID`/`GetTypeFromCLSID`, .NET `IO.*.Delete` / `(gi/gci).Delete()`, and `ScriptBlock::Create`/`.Invoke()`.
- **Deletion and credential protection**: Blocks `Remove-Item` aliases (`rm`, `del`, `rd`, `rmdir`, etc.) on any recursive prefix (`-r`..`-recurse`, `/s`, clustered POSIX `-rf`, pipelined recursion), parameter splatting, root/drive/`~`/`$HOME` wildcards, and relative or rooted `.ssh`/`.aws`/`.gnupg` paths.
- **Subcommand-aware Git rules**: Consumes `-m`/`--message` payloads only for `commit`, `tag`, and `merge`; blocks `git -c` and `git config` overrides (`core.hooksPath`, `core.sshCommand`, `core.editor`, `core.fsmonitor`, `clean.requireForce`, `safe.directory`, `alias.*`); blocks force pushes/refspecs/remote deletes, branch `-D`/`-df` and non-`checkpoint-*` `branch -f`/`-M`, `worktree remove -f`, `clean -f`, `commit -n`/`--no-verify`, destructive `restore`/`checkout`/`switch`, `stash drop/clear`, and `reset --hard` outside `^(refs/heads/)?checkpoint-[A-Za-z0-9_-]+$`.

### 3. Atomic Checkpoints and Programmatic Gate 2 Diff Injection
- **Checkpoints (`New-AuditCheckpoint.ps1`, `Restore-AuditCheckpoint.ps1`)**: Both scripts invoke raw `git @Arguments` (avoiding `rtk` console proxy dependencies), preserve directory context with `Push-Location`/`Pop-Location`, and verify `$LASTEXITCODE`.
  - *Git mode*: Requires a clean tracked working tree, force-updates `checkpoint-<task>`, and records `untracked_baseline.txt` (files plus `--directory` with `-c core.quotePath=false`). Rollback executes a two-stage `git reset` (mixed) before `git reset --hard` so newly staged untracked files are unstaged rather than wiped, fails closed if `untracked_baseline.txt` is missing, and deletes only post-checkpoint untracked paths inside `try/catch` blocks so Windows file locks warn instead of aborting recovery.
  - *File mode (non-git)*: Stores `<sha1>_<leaf>.bak` copies and SHA-256 checksums in `hashes.txt`; rollback verifies SHA-256 integrity, resolves deleted targets via `GetUnresolvedProviderPathFromPSPath`, and recreates missing parent directories.
- **Diff Injection (`Update-Gate2Diff.ps1`)**: Stages untracked files temporarily with `git add -N` inside a `try/finally` block (`git reset -q HEAD`), captures `--output=` diffs and `--stat=140,80` directly to temp files, substitutes `{{VERBATIM_GIT_DIFF*}}` via literal `.Replace()` (preventing `$1`/`$_`/`$&` corruption), writes UTF-8 without BOM (`[System.Text.UTF8Encoding]::new($false)`), and scrubs bearer tokens, API keys, JWTs, and multiline or unclosed private key blocks to `<TEST_HASH_SANITIZED>` while leaving 40-char Git SHAs and 64-char SHA-256 hashes intact.

### 4. Two-Layer YAML Validation, Standalone `.Tests.ps1`, and CI Matrix
- **Two-layer YAML validation**:
  - *Layer 1 (`YamlValidation.Tests.ps1`)*: A zero-dependency PowerShell validator running on both PS 5.1 and `pwsh` 7.6 that inspects `.github/**/*.yml`, agent manifests (10 agents, `subagent: true`, `mainAgent: false`, no `ask_question`, no `call_mcp_tool`, `build-error-resolver` missing `write_to_file`), skill frontmatter (15 skills, `<= 128` chars, quoted `: `), `hooks.json` matcher structure, `subagent-patterns.md` absence, and `sync.ps1`/`restore.ps1` AST parity.
  - *Layer 2 (`.yamllint.yml`)*: Validates `.github/` YAML files in CI (`2`-space indent, `key-duplicates: enable`, ignoring `/config/agents/`, `/config/skills/`, `/docs/`).
- **Standalone `.Tests.ps1` isolation (`.github/tests/`)**: I moved `Test-PowerShellCommandSafety.Tests.ps1`, `AuditCheckpoint.Tests.ps1`, and `YamlValidation.Tests.ps1` out of `config/skills/` into `.github/tests/` so `restore.ps1` never copies CI test suites into `~/.gemini/`. I kept standalone assertion helpers instead of Pester so tests run identically on `windows-latest` (PS 5.1 + `pwsh`) and `ubuntu-latest` (`pwsh`) with zero third-party installs.
- **CI Index & Credential Gates (`.github/workflows/ci.yml`)**: Enforces the `5-8` Living Domain ADR count bound with case-sensitive `[System.StringComparer]::Ordinal` two-way bijection parity against `docs/adr/README.md`, alongside the non-binary credential scanner shared with `sync.ps1` and `restore.ps1`.

## Alternatives Considered & Rejected
- **Adopting Pester 5 for PowerShell tests**: Rejected because Windows PowerShell 5.1 bundles Pester 3.4.0 while Pester 5 requires external package installation; standalone `.Tests.ps1` scripts run cross-shell with zero dependencies.
- **PyYAML-only validation or running `yamllint` on Markdown frontmatter**: Rejected because PyYAML `safe_load()` silently ignores duplicate keys and `yamllint` cannot parse Markdown YAML frontmatter directly without preprocessors and a Python dependency.
- **Keeping Guard 3 on `invoke_subagent` or using `git clean -fdx` on rollback**: Rejected because Guard 3 blocked `teamwork`/`research`/`self` and `git clean -fdx` risks deleting unrelated developer untracked files.
- **Using PowerShell `-replace` or `rtk git` inside checkpoint/diff scripts**: Rejected because regex replacement corrupts diff backreferences and console proxies add fragile parsing to rollback paths.
- **Keeping `.Tests.ps1` inside `config/skills/orchestrator/scripts/`**: Rejected because `restore.ps1` copies skill folders into `~/.gemini/`.

## Consequences
- **Positive**: Enforces command safety, deny-paths, index-idempotent diffs, duplicate-key YAML checks, and SHA-verified rollbacks deterministically across Windows and Linux CI.
- **Negative / Operational Requirements**:
  - Workflows genuinely needing `Start-Process`, `git clean -f`, or uncheckpointed resets must be run by the developer outside the agent session.
  - Static AST inspection cannot inspect dynamically constructed `[char]` expressions at runtime, relying on Guard 2 deny-paths and OS permissions as defense in depth.
