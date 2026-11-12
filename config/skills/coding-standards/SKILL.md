---
name: coding-standards
description: Baseline cross-project coding conventions (/coding-standards) for naming, immutability, fail-loud errors, and boundary types.
---

# Coding Standards & Best Practices

Baseline conventions across **TypeScript**, **Python**, **Vanilla JavaScript**, and **Kotlin**.

## When to Activate
- Authoring new modules, features, or tests; reviewing code quality; setting up type/lint baselines.

## Core Principles
1. **Readability First**: Clear domain intent trumps clever shorthand.
2. **KISS & Ponytail**: Shortest working diff wins; zero single-impl interfaces or speculative abstractions.
3. **Immutability by Default**: Pure transformations and readonly structures over in-place reference mutation.
4. **Fail Loudly**: Never swallow exceptions or mask errors with fallback defaults (MITRE CWE-390/CWE-252).
5. **Self-Documenting Code**: Meaningful identifiers; reserve comments for non-obvious *why* rationale (see [`clean-docs`](../clean-docs/SKILL.md#3-code-comment-hygiene)).

---

## Universal Standards

### 1. Naming Conventions

| Language | Variables & Functions | Types & Classes | Constants | Authority |
| :--- | :--- | :--- | :--- | :--- |
| **TypeScript** | `lowerCamelCase` | `PascalCase` | `UPPER_SNAKE_CASE` | Google TS Style Guide §5.1 |
| **Python** | `snake_case` | `CapWords` (`PascalCase`) | `UPPER_SNAKE_CASE` | PEP 8 Naming Conventions |
| **Vanilla JS** | `lowerCamelCase` | `PascalCase` | `UPPER_SNAKE_CASE` | Google JS Style Guide §5 |
| **Kotlin** | `lowerCamelCase` | `PascalCase` | `UPPER_SNAKE_CASE` | JetBrains Kotlin Conventions |

Use verb-noun action pairs (`fetchMarketData`, `isValidEmail`). Ban single-letter and cryptic identifiers (`q`, `flag`, `x`).

### 2. Immutability Pattern
- **TypeScript**: `readonly` interfaces and spread copies (`const next = { ...user, name: 'New' };`).
- **Python**: Frozen dataclasses and non-mutating updates (`replace(user, name="New")`).
- **Vanilla JS**: `Object.freeze()` configs, spread shallow copies, and `structuredClone()` for deep trees.
- **Kotlin**: Read-only `val`, `.copy()` on data classes, and read-only collections (`List<T>` over `MutableList<T>`).

### 3. Error Handling & Silent Failure Prevention
- **Explicit `fetch` HTTP Verification**: `fetch()` does not reject on 4xx/5xx; verify `if (!response.ok) throw new Error(...)`.
- **Cause Chaining**: Preserve diagnostic context. TS: `new Error("msg", { cause: err })`; Python: `raise CustomError(...) from exc`.
- **Idiomatic Kotlin**: Use `runCatching { ... }` or `require(condition) { "msg" }`; strictly avoid unchecked `!!` assertions.
- **Fail Loudly**: Never swallow errors silently or return masking defaults (`catch { return [] }` / `except: pass`) without logging or error elevation (MITRE CWE-390 / CWE-252).

```typescript
// Explicit fetch validation and error cause chaining
if (!response.ok) throw new Error(`HTTP ${response.status}: ${response.statusText}`);
```

### 4. Async Concurrency
- **Concurrent Dispatch**: Run independent asynchronous operations in parallel instead of sequential waterfall awaits:
  - TS/JS: `Promise.all([fetchA(), fetchB()])` (or `Promise.allSettled`).
  - Python: `await asyncio.gather(fetch_a(), fetch_b())` or `asyncio.TaskGroup()` (Python 3.11+).
  - Kotlin: `coroutineScope { val a = async { fetchA() }; val b = async { fetchB() }; a.await() to b.await() }`.
- **Deterministic Test Polling**: Use predicate loops; never insert arbitrary fixed sleeps (`sleep 1000` / `setTimeout(r, 1000)`):

```typescript
async function waitFor(predicate: () => Promise<boolean> | boolean, timeoutMs = 2000, intervalMs = 50): Promise<void> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await predicate()) return;
    await new Promise(r => setTimeout(r, intervalMs));
  }
  throw new Error(`waitFor condition timed out after ${timeoutMs}ms`);
}
```

### 5. Type Safety & Boundary Validation
- Validate untrusted inputs at system boundaries (HTTP, IPC, DB, CLI) before feeding internal domain logic:
  - **TypeScript**: Discriminated unions, literal types, and runtime schema parsers (Zod/TypeBox).
  - **Python**: Type hints (PEP 484/585/604) backed by boundary validation (`pydantic.BaseModel` / `@dataclass`).
  - **Vanilla JS**: Require `// @ts-check` with comprehensive `@param`/`@typedef` JSDoc annotations and defensive type guards.
  - **Kotlin**: Sealed interfaces with exhaustive `when` expressions and `@JvmInline value class` domain primitives.

### 6. Active LTS Runtime Floors

| Runtime / Ecosystem | Minimum Supported Baseline | Verification Mandate |
| :--- | :--- | :--- |
| **Node.js** | Node 20+ LTS | Context7 API audit |
| **Python** | Python 3.12+ | PEP 695 / Modern Type Syntax |
| **Go** | Go 1.22+ | Toolchain & Range over Int |
| **Java / JVM** | Java 21 / 25 LTS | Virtual Threads & Pattern Matching |

---

## Anti-Patterns to Reject
- **Primitive Obsession**: Passing raw strings/integers for currency, durations, or identifiers (`amountCents`, `timeoutMs`, `OrderId` vs raw `number`).
- **Boolean Blindness**: Multi-argument boolean traps (`update(true, false, true)`). Mitigate idiomatically:
  - TS/JS: Options objects (`update({ notify: true, dryRun: false })`).
  - Python: Keyword-only arguments (`def update(*, notify: bool, dry_run: bool):`).
  - Kotlin: Named arguments (`update(notify = true, dryRun = false)`).
- **Masking Catch Blocks (CWE-390 / CWE-252)**: Bare `catch {}` or generic `.catch(() => {})` with zero logging or rethrow.
- **Speculative Abstractions**: Single-implementation interfaces, premature factory wrappers, and hypothetical extension layers (YAGNI).

---

## Related Skills & Agents
- [`ponytail`](https://github.com/DietrichGebert/ponytail) - Minimalist, YAGNI implementation discipline.
- [`clean-docs`](../clean-docs/SKILL.md) - Plain-spoken repo prose, zero process leaks, and code comment hygiene (Section 3).
- [`code-auditor`](../../agents/code-auditor/agent.md) - Code quality and security auditing specialist.
- [`spec-verifier`](../../agents/spec-verifier/agent.md) - Documentation and official API verification specialist.
