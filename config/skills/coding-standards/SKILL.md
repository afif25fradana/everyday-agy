---
name: coding-standards
description: Baseline cross-project coding conventions for naming, readability, immutability, error handling, and type safety. Use when setting up project conventions, reviewing code quality, or refactoring without framework-specific guidance.
---

# Coding Standards & Best Practices

Baseline coding conventions applicable across projects. Governed by the principles of readability first, immutability by default, and fail-loud error handling.

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
4. **Fail Loudly**: Never swallow errors silently or return masking defaults (`catch { return [] }`) on critical paths.
5. **Self-Documenting Code**: Choose descriptive variable and function names; reserve comments for non-obvious *why* rationale (per `antislop-code`).

---

## Universal Standards

### 1. Naming Conventions

```typescript
// GOOD: Descriptive, intention-revealing names
const marketSearchQuery = 'election';
const isUserAuthenticated = true;
const totalRevenueCents = 100000;

// BAD: Single-letter, cryptic, or misleading names
const q = 'election';
const flag = true;
const x = 100000;
```

```typescript
// GOOD: Verb-noun action names
async function fetchMarketData(marketId: string): Promise<MarketData> { }
function isValidEmail(email: string): boolean { }
function calculateWeightedAverage(values: number[], weights: number[]): number { }

// BAD: Ambiguous or noun-only function names
async function market(id: string) { }
function data(e: string) { }
```

### 2. Immutability Pattern

```typescript
// GOOD: Pure transformations using spread or copy
const updatedUser = {
  ...user,
  name: 'New Name',
  updatedAt: new Date()
};
const updatedItems = [...items, newItem];
const filteredItems = items.filter(item => item.id !== targetId);

// BAD: In-place mutation of shared references
user.name = 'New Name';
items.push(newItem);
delete user.temporaryToken;
```

### 3. Error Handling & Silent Failure Prevention

```typescript
// GOOD: Explicit validation and descriptive error propagation
async function fetchProfile(userId: string): Promise<UserProfile> {
  const response = await fetch(`/api/users/${encodeURIComponent(userId)}`);

  if (!response.ok) {
    throw new Error(`Failed to fetch profile for user ${userId}: HTTP ${response.status} ${response.statusText}`);
  }

  return await response.json();
}

// BAD: Swallowing errors or returning silent masking defaults
async function fetchProfile(userId: string) {
  try {
    const res = await fetch(`/api/users/${userId}`);
    return await res.json();
  } catch (err) {
    // Masking failure - caller cannot distinguish between empty profile and network breakdown
    return null;
  }
}
```

### 4. Async Concurrency

```typescript
// GOOD: Run independent asynchronous operations in parallel
const [userProfile, orderHistory, accountBalance] = await Promise.all([
  fetchUserProfile(userId),
  fetchOrderHistory(userId),
  fetchAccountBalance(userId)
]);

// BAD: Serial waterfall when operations do not depend on each other
const userProfile = await fetchUserProfile(userId);
const orderHistory = await fetchOrderHistory(userId);
const accountBalance = await fetchAccountBalance(userId);
```

### 5. Type Safety & Boundary Validation

```typescript
// GOOD: Strict interfaces and runtime boundary validation
interface OrderPayload {
  readonly orderId: string;
  readonly amount: number;
  readonly currency: 'USD' | 'EUR' | 'IDR';
}

function processOrder(payload: OrderPayload): void {
  if (payload.amount <= 0) {
    throw new IllegalArgumentError(`Order amount must be positive. Received: ${payload.amount}`);
  }
}

// BAD: Any-typing and unvalidated inputs
function processOrder(payload: any) {
  // Vulnerable to runtime TypeError if payload is unexpected
  console.log(payload.amount.toFixed(2));
}
```

---

## Anti-Patterns to Reject

- **Primitive Obsession**: Passing naked numbers for IDs, money, or units without descriptive naming (`amountCents`, `timeoutMs`).
- **Boolean Blindness**: Functions accepting multiple consecutive boolean flags (`processUser(true, false, true)`). Use options objects instead (`processUser({ sendEmail: true, dryRun: false })`).
- **Masking Catch Blocks**: `try { ... } catch {}` or `.catch(() => {})` with zero logging or error elevation.
- **Speculative Abstractions**: Abstract factories, single-implementation interfaces, or polymorphic hierarchies built for hypothetical future requirements.

## Related Skills & Agents

- [`ponytail`](../ponytail/SKILL.md) - Minimalist, YAGNI implementation discipline.
- `antislop-code` (plugin skill) - Comment hygiene and anti-slop rules.
- [`code-auditor`](../../agents/code-auditor/agent.md) - Code quality and security auditing specialist.
