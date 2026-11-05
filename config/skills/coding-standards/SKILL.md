---
name: coding-standards
description: Baseline cross-project coding conventions (/coding-standards) for naming, immutability, fail-loud errors, and boundary types.
---

# Coding Standards & Best Practices

Baseline coding conventions applicable across projects. Governed by the principles of readability first, immutability by default, and fail-loud error handling across **TypeScript**, **Python**, **Vanilla JavaScript**, and **Kotlin**.

## When to Activate

- Starting a new module or feature
- Reviewing code quality and maintainability
- Refactoring existing code to improve clarity
- Enforcing naming, formatting, or structural consistency
- Setting up linting, formatting, or type-checking baselines

## Core Principles

1. **Readability First**: Code is read far more often than it is written. Clear intent trumps clever shorthand.
2. **KISS & Ponytail**: The simplest solution that completely solves the problem. No premature generalizations or single-impl interfaces.
3. **Immutability by Default**: Prefer pure functions, immutable updates, and readonly structures over in-place mutation.
4. **Fail Loudly**: Never swallow errors silently or return masking defaults (`catch { return [] }`) on critical paths (MITRE CWE-390).
5. **Self-Documenting Code**: Choose descriptive variable and function names; reserve comments for non-obvious *why* rationale (per `antislop-code` and [`clean-docs`](../clean-docs/SKILL.md)).

---

## Universal Standards

### 1. Naming Conventions

Identifiers must reveal intent and domain units. Follow official language naming standards:

| Language | Variables & Functions | Types, Classes & Enums | Constants | Authority |
| :--- | :--- | :--- | :--- | :--- |
| **TypeScript** | `lowerCamelCase` | `PascalCase` | `UPPER_SNAKE_CASE` | Google TS Style Guide §5.1 |
| **Python** | `snake_case` | `CapWords` (`PascalCase`) | `UPPER_SNAKE_CASE` | PEP 8 Naming Conventions |
| **Vanilla JS** | `lowerCamelCase` | `PascalCase` | `UPPER_SNAKE_CASE` | Google JS Style Guide §5 |
| **Kotlin** | `lowerCamelCase` | `PascalCase` | `UPPER_SNAKE_CASE` (`const val`) | JetBrains Kotlin Conventions |

```typescript
// TypeScript & Vanilla JS: lowerCamelCase variables, verb-noun action functions
const marketSearchQuery = 'inflation';
const isUserAuthenticated = true;
const totalRevenueCents = 150000;

async function fetchMarketData(marketId: string): Promise<MarketData> { }
function isValidEmail(email: string): boolean { }
```

```python
# Python: PEP 8 snake_case variables and verb-noun action functions
market_search_query = "inflation"
is_user_authenticated = True
total_revenue_cents = 150_000

async def fetch_market_data(market_id: str) -> MarketData: ...
def is_valid_email(email: str) -> bool: ...
```

```kotlin
// Kotlin: lowerCamelCase properties and action-oriented functions
val marketSearchQuery: String = "inflation"
val isUserAuthenticated: Boolean = true
val totalRevenueCents: Long = 150_000L

suspend fun fetchMarketData(marketId: String): MarketData { }
fun isValidEmail(email: String): Boolean { }
```

```typescript
// BAD (Across all languages): Cryptic, single-letter, or noun-only function names
const q = 'inflation';
const flag = true;
const x = 150000;
async function market(id: string) { }
```

---

### 2. Immutability Pattern

Prefer pure transformations that return fresh instances over mutating shared references.

```typescript
// TypeScript: Readonly properties and spread copies
interface UserState {
  readonly id: string;
  readonly name: string;
  readonly tags: readonly string[];
}

const updatedUser: UserState = {
  ...user,
  name: 'New Name',
  tags: [...user.tags, 'verified']
};

// BAD: In-place mutation of shared object references
user.name = 'New Name';
user.tags.push('verified');
delete user.temporaryToken;
```

```python
# Python: Frozen dataclasses and dataclasses.replace
from dataclasses import dataclass, replace

@dataclass(frozen=True)
class UserState:
    id: str
    name: str
    tags: tuple[str, ...] = ()

# GOOD: Non-mutating transform producing a new instance
updated_user = replace(user, name="New Name", tags=(*user.tags, "verified"))

# BAD: In-place mutation (raises FrozenInstanceError)
# user.name = "New Name"
```

```javascript
// Vanilla JS: Object.freeze for configs, spread syntax, and structuredClone for deep copies
const baseConfig = Object.freeze({ timeoutMs: 5000, retries: 3 });
const updatedConfig = { ...baseConfig, timeoutMs: 10000 };
const deepStateCopy = structuredClone(currentState);

// BAD: Mutating frozen objects or mutating shared caller state
// baseConfig.timeoutMs = 10000; // TypeError in strict mode
```

```kotlin
// Kotlin: Read-only properties (val), .copy(), and immutable collections (List vs MutableList)
data class UserState(
    val id: String,
    val name: String,
    val tags: List<String> = emptyList()
)

val updatedUser = user.copy(
    name = "New Name",
    tags = user.tags + "verified"
)

// BAD: Mutable class exposing mutable collection
class MutableUserState(var name: String, val tags: MutableList<String>)
```

---

### 3. Error Handling & Silent Failure Prevention

Never swallow errors silently or return masking defaults (`catch { return null }` / `except: pass`) without logging or error elevation.

```typescript
// TypeScript & Vanilla JS: Explicit response.ok check (fetch does not reject on 4xx/5xx)
async function fetchProfile(userId: string): Promise<UserProfile> {
  const response = await fetch(`/api/users/${encodeURIComponent(userId)}`);

  if (!response.ok) {
    throw new Error(`Failed to fetch profile for user ${userId}: HTTP ${response.status} ${response.statusText}`);
  }

  return (await response.json()) as UserProfile;
}

// BAD (MITRE CWE-390): Masking failure - caller cannot distinguish not-found from network outage
async function fetchProfileBad(userId: string) {
  try {
    const res = await fetch(`/api/users/${userId}`);
    return await res.json();
  } catch (err) {
    return null;
  }
}
```

```python
# Python: Catch specific exceptions, chain causes (from exc), raise_for_status
import httpx
from http import HTTPStatus

async def fetch_profile(user_id: str, client: httpx.AsyncClient) -> dict:
    try:
        response = await client.get(f"/api/users/{user_id}")
        response.raise_for_status()
        return response.json()
    except httpx.HTTPStatusError as exc:
        if exc.response.status_code == HTTPStatus.NOT_FOUND:
            raise KeyError(f"User {user_id} not found") from exc
        raise RuntimeError(f"Upstream API failure: {exc.response.status_code}") from exc
    except httpx.RequestError as exc:
        raise ConnectionError(f"Network failure reaching user service: {exc}") from exc

# BAD (MITRE CWE-390): Bare except or swallowing all exceptions
def fetch_profile_bad(user_id: str):
    try:
        ...
    except Exception:
        return None
```

```kotlin
// Kotlin: Result<T>, runCatching, safe calls (?.) and elvis (?:) over dangerous (!!)
fun parsePortNumber(portString: String): Result<Int> = runCatching {
    val port = portString.toInt()
    require(port in 1..65535) { "Port must be 1..65535, received: $port" }
    port
}

// BAD (MITRE CWE-390): Catch and return null without logging or action
fun parsePortBad(portString: String): Int? = try {
    portString.toInt()
} catch (e: Exception) {
    null
}
```

---

### 4. Async Concurrency

Run independent asynchronous operations concurrently instead of sequential waterfall awaits.

```typescript
// TypeScript & Vanilla JS: Promise.all parallel vs serial waterfall
const [userProfile, orderHistory, accountBalance] = await Promise.all([
  fetchUserProfile(userId),
  fetchOrderHistory(userId),
  fetchAccountBalance(userId)
]);

// BAD: Serial waterfall when operations do not depend on each other
const userProfile = await fetchUserProfile(userId);
const orderHistory = await fetchOrderHistory(userId);
const accountBalance = await fetchAccountBalance(userId);

// GOOD: Deterministic condition-based waiting in async tests
async function waitFor(predicate: () => Promise<boolean> | boolean, timeoutMs = 2000, intervalMs = 50): Promise<void> {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (await predicate()) return;
    await new Promise(r => setTimeout(r, intervalMs));
  }
  throw new Error(`waitFor condition timed out after ${timeoutMs}ms`);
}

// BAD: Arbitrary fixed sleep in async tests
await new Promise(r => setTimeout(r, 1000));
```

```python
# Python: asyncio.gather or asyncio.TaskGroup (Python 3.11+)
profile, orders, balance = await asyncio.gather(
    fetch_user_profile(user_id),
    fetch_order_history(user_id),
    fetch_account_balance(user_id)
)

# BAD: Awaiting independent coroutines serially inside a loop
for task in tasks:
    await task()
```

```kotlin
// Kotlin: coroutineScope with async / awaitAll
suspend fun loadDashboardData(userId: String): DashboardData = coroutineScope {
    val profile = async { fetchUserProfile(userId) }
    val orders = async { fetchOrderHistory(userId) }
    val balance = async { fetchAccountBalance(userId) }

    DashboardData(profile.await(), orders.await(), balance.await())
}
```

---

### 5. Type Safety & Boundary Validation

Enforce strict compile-time types and validate untrusted inputs at system boundaries (HTTP, IPC, DB, CLI).

```typescript
// TypeScript: readonly interfaces, literal union types, runtime guards
type Currency = 'USD' | 'EUR' | 'IDR';

interface OrderPayload {
  readonly orderId: string;
  readonly amountCents: number;
  readonly currency: Currency;
}

function processOrder(payload: OrderPayload): void {
  if (payload.amountCents <= 0) {
    throw new IllegalArgumentError(`Order amount must be positive. Received: ${payload.amountCents}`);
  }
}

// BAD: any-typing and unvalidated inputs
function processOrderBad(payload: any) {
  console.log(payload.amountCents.toFixed(2));
}
```

```python
# Python: Type hints (PEP 484/585/604) with runtime boundary validation (Pydantic / dataclass)
from typing import Literal
from pydantic import BaseModel, Field

class OrderPayload(BaseModel):
    order_id: str = Field(min_length=1)
    amount_cents: int = Field(gt=0)
    currency: Literal["USD", "EUR", "IDR"]

def process_order(raw_data: dict) -> None:
    payload = OrderPayload.model_validate(raw_data)
    print(f"Processing order {payload.order_id}: {payload.amount_cents}")
```

```javascript
// Vanilla JS: // @ts-check + JSDoc type annotations + runtime guard clauses
// @ts-check

/**
 * @typedef {'USD' | 'EUR' | 'IDR'} Currency
 * @typedef {{ orderId: string, amountCents: number, currency: Currency }} OrderPayload
 */

/**
 * @param {OrderPayload} payload
 */
function processOrder(payload) {
  if (typeof payload !== 'object' || payload === null) {
    throw new TypeError('Order payload must be a non-null object');
  }
  if (typeof payload.orderId !== 'string' || !payload.orderId.trim()) {
    throw new TypeError('orderId must be a non-empty string');
  }
  if (!Number.isFinite(payload.amountCents) || payload.amountCents <= 0) {
    throw new TypeError(`amountCents must be a positive number: ${payload.amountCents}`);
  }
}
```

```kotlin
// Kotlin: sealed interface with exhaustive when & @JvmInline value class
@JvmInline
value class OrderId(val value: String) {
    init { require(value.isNotBlank()) { "OrderId cannot be blank" } }
}

sealed interface PaymentStatus {
    data class Success(val transactionId: String) : PaymentStatus
    data class Failed(val errorCode: String, val message: String) : PaymentStatus
    object Pending : PaymentStatus
}

fun renderPaymentStatus(status: PaymentStatus): String = when (status) {
    is PaymentStatus.Success -> "Paid: ${status.transactionId}"
    is PaymentStatus.Failed -> "Declined: ${status.message}"
    PaymentStatus.Pending -> "Pending confirmation"
}
```

---

## Anti-Patterns to Reject

- **Primitive Obsession**: Passing naked numbers for IDs, money, or units without descriptive naming or wrappers (`amountCents`, `timeoutMs`, `OrderId`).
- **Boolean Blindness / Boolean Trap**: Passing sequential boolean flags (`processUser(true, false, true)`). Mitigate idiomatically:
  - **TypeScript & Vanilla JS**: Use options objects (`processUser(id, { sendEmail: true, dryRun: false })`).
  - **Python**: Use keyword-only arguments per PEP 3102 (`def process_user(user_id: str, *, send_email: bool, dry_run: bool):`).
  - **Kotlin**: Use named arguments (`processUser(userId, sendEmail = true, dryRun = false)`).
- **Masking Catch Blocks (MITRE CWE-390 & CWE-252)**: `try { ... } catch {}` or `.catch(() => {})` with zero logging or error elevation. Never catch an exception without either fully handling it, logging diagnostics, or re-raising a contextualized domain exception.
- **Speculative Abstractions**: Abstract factories, single-implementation interfaces, or polymorphic hierarchies built for hypothetical future requirements (YAGNI).

---

## Related Skills & Agents

- [`ponytail`](https://github.com/DietrichGebert/ponytail) - Minimalist, YAGNI implementation discipline.
- `antislop-code` (plugin skill) - Comment hygiene and anti-slop rules.
- [`code-auditor`](../../agents/code-auditor/agent.md) - Code quality and security auditing specialist.
- [`spec-verifier`](../../agents/spec-verifier/agent.md) - Documentation and official API verification specialist.
