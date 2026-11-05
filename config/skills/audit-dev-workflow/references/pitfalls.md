# Engineering Pitfalls & Edge-Case Traps
**Operational Checklist for Five-Axis Pre-Flight & Review Alignment**

Consult this checklist when evaluating plans, diffs, test logs, and audit reports. High-level rubric definitions are maintained in [`SKILL.md`](../SKILL.md#phase-4-local-verification--review).

---

## A. Agentic Engineering Traps

1. **API Drift & Hallucinated Methods**: Calling library methods, flags, or configuration options from outdated pre-training data without verifying against Context7 MCP (`resolve-library-id`, `query-docs`) or local lockfiles.
2. **EOL Runtime Targets**: Generating code targeting unsupported runtimes (e.g. Python <= 3.10, Node <= 18) instead of modern active/LTS floors (Python 3.12+, Node 20/22+).
3. **Unchecked Mutating Actions**: Modifying repository files without a verified rollback checkpoint (`New-AuditCheckpoint.ps1`), or mutating files on Tier 2/3 tasks and package installations before obtaining explicit Gate 1 user confirmation per ADR-0015.
4. **Mock & Harness Drift**: Relying on passing unit tests where mocks or test fixtures reflect outdated assumptions rather than real API/database payloads.
5. **State & Concurrency Blindness**: Overlooking async event loops, thread safety, daemon lifecycles, or race conditions during refactoring.
6. **Premature Abstraction / YAGNI**: Writing speculative interfaces, single-implementation factories, or wrapper classes when native platform features or stdlib suffice.
7. **Secret Scanner False Positives**: Using unbracketed sample tokens or raw test secrets longer than 12-16 characters instead of `<...>` bracketed format (`<TOKEN>`, `<API_KEY>`). Always scrub real test output tokens to `<TEST_HASH_SANITIZED>` or `<MOCK_TOKEN>`.

---

## B. Logic & Implementation Pitfalls

8. **Coverage Gaps in Conditionals**: Boundary checks that look safe individually but leave edge-case values (`0`, `null`, `undefined`, negative numbers, or exact breakpoint pixels) uncovered.
9. **Specificity & Precedence Surprises**: Broader defaults silently overriding specific rules (e.g. Light DOM overriding `:host()`, CSS cascade order, or config fallback hierarchy). Preserve comments explaining workarounds that depend on this behavior.
10. **Unverified "Dead Code" Claims**: Calling code or dependencies unused based on a narrow grep instead of verifying callers across the full repository (including dynamic imports, templates, or build scripts) with `rtk rg`.
11. **"Clean" Rewrites Dropping Defenses**: A rewrite that quietly drops a retry, an error boundary, a timeout, or a calibrated threshold. Always verify: *"Does this lose any defensive behavior from the original?"*
12. **Symptom Patching**: Adding a defensive fallback at one call site when multiple callers share the same broken upstream state or parser bug.
13. **Swallowed Exceptions & Masking Defaults**: Bare `catch {}` blocks, masking fallbacks (`.catch(() => [])` or returning empty collections/`null` on critical error paths) that silently hide failures instead of propagating or handling them cleanly.
14. **Resource Leaks Across Return Paths**: Leaving streams open, subprocesses orphaned, event listeners lingering, or locks unreleased across early return branches or exception handlers.
15. **Mock-Cheating & Superficial Assertions**: Unit tests where mocks replace the unit under test itself, or assertions limited to `mock.called == True` without verifying returned payloads, mutated state, or error propagation. Perform temporary fault injection (flip a condition) to ensure the test fails when broken.
16. **Architectural Coupling Signal on Rollback**: When the 2-attempt circuit breaker triggers `Restore-AuditCheckpoint.ps1` and each failed fix attempt exposed cascading breakages across different files or shared state, treat this as a strong signal of architectural coupling or missing domain boundaries—not a localized bug. Stop attempting local patches, report the coupling evidence, and escalate to an architectural design discussion (`system-architect`).

---

## C. Platform & Shell Pitfalls (PowerShell & Git Diffing)

17. **PowerShell Scalar-to-Array Concatenation Trap**: Expression `@($a + $b)` evaluates operator `+` before `@()`. If `$a` and `$b` are scalar strings (e.g. single-item output from `git ls-files`), PowerShell performs string concatenation (`"file1file2"`) rather than array combination. Always cast each operand individually to an array before combining: `(@($a) + @($b))`.
18. **Nested Empty Directory False Negatives**: Testing `$items = Get-ChildItem -LiteralPath $dir -Force; if ($items.Count -eq 0)` to detect empty directories fails when nested subdirectories exist (`dir/sub/`), because `Get-ChildItem` returns the child directory object `sub`. Always test for remaining files recursively: `$remainingFiles = @(Get-ChildItem -LiteralPath $dir -Recurse -File -Force); if ($remainingFiles.Count -eq 0)`.
19. **Git Diffstat Path Truncation in Review Payloads**: Standard `git diff --stat` truncates long directory paths with ellipsis (`.../`) on 80-column terminals, obscuring module hierarchy. For formal review payloads, always invoke `git diff --stat=140,80 HEAD` to preserve untruncated file coordinates.
20. **Safety Validator Scope Boundary**: `Test-PowerShellCommandSafety.ps1` validates arbitrary, ad-hoc shell strings executed by agents (`run_command`). Trusted infrastructure scripts (such as `Restore-AuditCheckpoint.ps1` utilizing `Remove-Item -Recurse -Force` to clean task-generated untracked artifacts) execute via `-File` invocations permitted by design; do not flag trusted script internals as safety violations.
