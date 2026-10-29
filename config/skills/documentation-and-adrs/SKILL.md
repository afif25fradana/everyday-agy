---
name: documentation-and-adrs
description: Records decisions and documentation. Use when you need to document an architecture decision (ADR) or the reasoning behind a design choice, when changing public APIs, shipping features, or when you need to record context that future engineers and agents will need to understand the codebase.
---

# Documentation and ADRs

## Overview

Document decisions, not just code. The most valuable documentation captures the *why* — the context, constraints, and trade-offs that led to a decision. Code shows *what* was built; documentation explains *why it was built this way* and *what alternatives were considered*. This context is essential for future humans and autonomous agents working in the codebase.

## When to Use

- Making a significant architectural decision
- Choosing between competing approaches or libraries
- Adding or changing a public API
- Shipping a feature that changes user-facing behavior
- Onboarding new engineers or agents to the project
- When you find yourself explaining the same thing repeatedly

**When NOT to use:** Don't document obvious code. Don't add comments that restate what the code already says. Don't write ceremonial docs for throwaway prototypes.

---

## Architecture Decision Records (ADRs)

ADRs capture the reasoning behind significant technical decisions. They are the highest-value documentation you can write.

### When to Write an ADR

- Choosing a framework, library, runtime, or major dependency
- Designing a data model, database schema, or persistence layer
- Selecting an authentication, cryptography, or security boundary strategy
- Deciding on an API architecture (REST vs. GraphQL vs. tRPC vs. loopback HTTP)
- Choosing between build tools, packaging systems, or infrastructure
- Any decision that would be expensive or painful to reverse

### Convention Discovery (Twin-Repo vs. Single-Repo)

Before creating an ADR, use tools (`rtk rg` or `view_file`) to inspect the project layout and follow the established convention:

1. **Twin-Repo Architecture (`<Project>-AI-Context/`)**:
   - In workflows using a companion context repository, ADRs live in the context repository:
     `<Project>-AI-Context/docs/adr/0001-<slug>.md`
   - Keep ADRs cataloged in `<Project>-AI-Context/architecture.md`.
   - This isolates internal architectural explorations and sensitive notes from public code repositories.
2. **Single-Repo Architecture**:
   - Store ADRs in `docs/adr/` or `docs/decisions/` with sequential numbering (`0001-<slug>.md` or `ADR-001-<slug>.md`).
   - Match existing numbering, directory, file extension, and markup (Markdown vs reStructuredText).

If the available evidence conflicts, surface the discrepancy in chat rather than silently introducing another scheme.

### ADR Template (Michael Nygard Standard)

Use the clean, modular Nygard format:

```markdown
# ADR-0001: Decoupled Local Inference via OpenAI-Compatible HTTP Backend

## Status
Accepted

## Date
2026-10-18

## Context
<Explain the problem, technical constraints, operating systems, dependency sizes, and why a decision is necessary.>

## Decision
<State the chosen architecture, component responsibilities, and protocols adopted.>

## Alternatives Considered & Rejected
- **<Option A>**: <Reason for rejection, e.g. dependency bloat, fragile compilation, or licensing>
- **<Option B>**: <Reason for rejection, e.g. lack of concurrency support or security risks>

## Consequences
- <Positive impact: performance, decoupling, simplicity>
- <Trade-offs or operational requirements: loopback security, supervision, configuration>
```

> [!TIP]
> When evaluating external libraries or third-party APIs during ADR drafting, use Context7 MCP (`resolve-library-id` -> `query-docs`) to verify official constraints, APIs, and licensing rather than relying on stale pre-training memory.

### ADR Lifecycle & Relationship with Task State

```
PROPOSED -> ACCEPTED -> (SUPERSEDED or DEPRECATED)
```

- **Don't delete old ADRs**: They capture historical context. When a decision changes, write a new ADR that references and supersedes the previous one.
- **ADR vs. `task_state.md`**:
  - **ADR (`docs/adr/`)**: Permanent engineering rationale ("Why was this designed this way?").
  - **Task State (`task_state.md`)**: Ephemeral, active task progress ("What are we building right now?").
  - When an investigation or edge case triggers an architectural decision, record the decision in an ADR and link to it from `task_state.md`.

---

## Inline Documentation

### When to Comment

Comment the *why*, not the *what*:

```typescript
// BAD: Restates the code
// Increment counter by 1
counter += 1;

// GOOD: Explains non-obvious intent
// Rate limit uses a sliding window — reset counter at window boundary,
// not on a fixed schedule, to prevent burst attacks at window edges
if (now - windowStart > WINDOW_SIZE_MS) {
  counter = 0;
  windowStart = now;
}
```

### When NOT to Comment

```typescript
// Don't comment self-explanatory code
function calculateTotal(items: CartItem[]): number {
  return items.reduce((sum, item) => sum + item.price * item.quantity, 0);
}

// Don't leave TODO comments for things you should just do now
// TODO: add error handling -> Just add it

// Don't leave commented-out code
// const oldImplementation = () => { ... } -> Delete it, git has history
```

### Document Known Gotchas

For non-obvious behavioral constraints, reference the ADR or underlying issue:

```typescript
/**
 * IMPORTANT: This function must be called before the first render.
 * If called after hydration, it causes a flash of unstyled content
 * because the theme context isn't available during SSR.
 *
 * See ADR-0003 for the full design rationale.
 */
export function initializeTheme(theme: Theme): void {
  // ...
}
```

---

## API Documentation

For public APIs (REST, GraphQL, library interfaces):

### Inline with Types (Preferred for TypeScript / Python)

```typescript
/**
 * Creates a new task.
 *
 * @param input - Task creation data (title required, description optional)
 * @returns The created task with server-generated ID and timestamps
 * @throws {ValidationError} If title is empty or exceeds 200 characters
 * @throws {AuthenticationError} If the user is not authenticated
 *
 * @example
 * const task = await createTask({ title: 'Buy groceries' });
 * console.log(task.id); // "task_abc123"
 */
export async function createTask(input: CreateTaskInput): Promise<Task> {
  // ...
}
```

### OpenAPI / Swagger for REST APIs

```yaml
paths:
  /api/tasks:
    post:
      summary: Create a task
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateTaskInput'
      responses:
        '201':
          description: Task created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Task'
        '422':
          description: Validation error
```

---

## README Structure

Every project should have a clean, public README that covers:

```markdown
# Project Name

One-paragraph description of what this project does.

## Quick Start
1. Clone the repo
2. Install dependencies: `npm install`
3. Set up environment: `cp .env.example .env`
4. Run the dev server: `npm run dev`

## Commands
| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server |
| `npm test` | Run tests |
| `npm run build` | Production build |
| `npm run lint` | Run linter |

## Architecture
Brief overview of the project structure and key design decisions.
Link to ADRs for details.

## Contributing
How to contribute, coding standards, PR process.
```

---

## Changelog Maintenance

For shipped features (following [Keep a Changelog](https://keepachangelog.com/)):

```markdown
# Changelog

## [1.2.0] - 2026-10-18
### Added
- Task sharing: users can share tasks with team members (#123)
- Email notifications for task assignments (#124)

### Fixed
- Duplicate tasks appearing when rapidly clicking create button (#125)

### Changed
- Task list now loads 50 items per page (was 20) for better UX (#126)
```

---

## Documentation for Agents & Tooling

Special consideration for AI agent context in Antigravity:

- **Twin-Repo Context (`architecture.md` & `task_state.md`)**:
  - In Twin-Repo workflows (`*-AI-Context`), `architecture.md` maintains a lean system topology index and ADR directory.
  - `task_state.md` tracks active tasks and tactical gotchas without leaking internal state to public code repositories.
- **Rule Files (`GEMINI.md` / `AGENTS.md`)**:
  - Document project conventions, verified dev tooling (`rtk`, `pwsh`), and safety guardrails so agents adhere to them across sessions.
- **Specification Files**:
  - Keep specs and PRDs updated so agents build against current requirements rather than inferred guesses.
- **ADRs**:
  - Help agents understand *why* architectural decisions were made, preventing repetitive regressions or unneeded re-architecting.
- **Inline Gotchas**:
  - Flag tricky invariants and concurrency traps to prevent agents from breaking subtle workarounds.

---

## Prose Review & Anti-Slop Discipline

After drafting documentation, review the prose to ensure technical accuracy and readability:

1. **Preserve Concrete Facts**: Keep names, numbers, units, verified commands, paths, links, and trade-offs. Check them against live code using `view_file` or `rtk rg`.
2. **Eliminate Fluff & Corporate Buzzwords**: Remove vague hype, self-congratulatory descriptions, and decorative prose. State plainly what the code does.
3. **Verify Links & References**: Ensure relative file links use the `file://` scheme or standard Markdown links and point to valid coordinates.

---

## Process Documentation: Match Form to Failure

When authoring operational runbooks, agent skills, or prompt contracts:

1. **Output Shaping Failures** (verbose narrative or unstructured responses):
   - Provide a **positive structural recipe** defining what the output *is* (order, headings, slots). Never rely on prohibition lists ("don't restate"), which invite prompt negotiation.
2. **Discipline & Rule Violations Under Pressure** (skipping steps or cutting corners):
   - Use **explicit prohibitions + anti-rationalization tables + red flags**. Avoid soft guidance ("prefer", "consider") that collapses under pressure.
3. **Omission of Required Elements**:
   - Use **explicit uppercase schema slots** (e.g. `<TARGET_COORDINATES>`) instead of prose reminders.
4. **Zero Nuance Clauses**:
   - Never append escape clauses ("Don't X unless Y"). Nuance clauses reopen behavioral bargaining.

---

## Red Flags

- Architectural decisions made with no written rationale
- Public APIs with missing parameter or return types
- README that fails to document how to build, test, and run the project
- Commented-out code left behind instead of relying on git history
- TODO comments left indefinitely without owner or issue tracker reference
- No ADRs in a repository with significant architectural complexity
- Comments that restate the code instead of explaining non-obvious intent

---

## Verification Checklist

After documenting:

- [ ] ADRs exist for significant architectural choices (frameworks, databases, security, protocols)
- [ ] README covers quick start, verified commands table, and architecture overview
- [ ] API functions have parameter and return type documentation
- [ ] Known gotchas are documented inline where they matter, citing ADRs when applicable
- [ ] No commented-out code remains in tracked files
- [ ] Project rule files (`GEMINI.md` / `AGENTS.md`) are accurate and current
- [ ] Prose review verified: zero generic AI buzzwords, zero unverified claims, clean formatting
