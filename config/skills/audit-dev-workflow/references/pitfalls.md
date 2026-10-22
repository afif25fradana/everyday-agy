# Engineering Pitfalls & Edge-Case Traps
**Operational Checklist for Five-Axis Pre-Flight & Review Alignment**

Consult this checklist when evaluating plans, diffs, test logs, and audit reports. High-level rubric definitions are maintained in [`SKILL.md`](../SKILL.md#3-five-axis-pre-flight-rubric).

---

## A. Agentic Engineering Traps

1. **API Drift & Hallucinated Methods**: Calling library methods, flags, or configuration options from outdated pre-training data without verifying against Context7 MCP (`resolve-library-id`, `query-docs`) or local lockfiles.
2. **EOL Runtime Targets**: Generating code targeting unsupported runtimes (e.g. Python <= 3.10, Node <= 18) instead of modern active/LTS floors (Python 3.12+, Node 20/22+).
3. **Unchecked Mutating Actions**: Modifying repository files, merging PRs, or executing state-changing commands before obtaining explicit user confirmation in chat or Gate 1 approval.
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
