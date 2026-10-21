# Categories of Pitfalls to Double-Check

Consult this checklist when evaluating plans, diffs, and audit reports:

---

## A. Agentic Engineering & AI Traps

1. **API Drift & Hallucinated Methods**: Calling library methods, flags, or configuration options from outdated pre-training data without verifying against MCP `context7` (`resolve-library-id`, `query-docs`) or local lockfiles.
2. **End-of-Life (EOL) Runtime Targets**: Generating code targeting unsupported runtimes (e.g. Python <= 3.10, Node <= 18) instead of modern active/LTS floors (Python 3.12+, Node 20/22+).
3. **Unchecked Mutating Actions**: Modifying repository files, merging PRs, or executing state-changing commands before obtaining explicit user confirmation in chat.
4. **Mock & Harness Drift**: Relying on passing unit tests where mocks or test fixtures reflect outdated assumptions rather than real API/database payloads.
5. **State & Concurrency Blindness**: Overlooking async event loops, thread safety, daemon lifecycles, or race conditions during refactoring.
6. **Premature Abstraction / YAGNI Violations**: Writing speculative interfaces, single-implementation factories, or wrapper classes when native platform features or stdlib suffice.

---

## B. Engineering & Logic Pitfalls (`ponytail` & Five-Axis Review)

7. **Coverage Gaps Between Conditional Rules**: Two rules (e.g. CSS media queries, config conditionals, numeric boundary checks) that each look safe individually but leave an edge-case value (like `0`, `null`, or exact breakpoint pixel) uncovered.
8. **Specificity & Precedence Surprises**: Broader defaults silently overriding specific rules (e.g. Light DOM overriding `:host()`, CSS cascade order, or config fallback order). Preserve comments explaining workarounds that depend on this behavior.
9. **Unverified "Dead/Unused" Claims**: Calling code, config keys, or dependencies unused based on a narrow grep instead of verifying callers across the full repository (including dynamic imports, templates, packaging specs, or build scripts).
10. **"Elegant" Rewrites Dropping Defensive Logic**: A clean rewrite that quietly drops a retry, an error boundary, a timeout, or a calibrated threshold. Always ask: *"Does this lose any defensive behavior from the original?"*
11. **Symptom Patching Over Shared Root Cause**: Adding a defensive fallback at one call site when multiple callers share the same broken upstream state or parser bug.
