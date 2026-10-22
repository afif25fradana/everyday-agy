# ADR-0008: Tri-Pillar Deliberative Multi-Agent Council Architecture

## Status
Accepted

## Date
2026-10-22

## Context
Single-agent code reviews and architectural audits suffer from inherent confirmation bias, localized hallucinations, and blind spots. While the broader AI ecosystem has introduced multi-agent committee patterns (such as Andrej Karpathy's `llm-council`, Anthropic's Evaluator-Optimizer research, and Addy Osmani's SDLC gating), these tools are typically built for external runtimes like Claude Code or bespoke Docker environments.

Antigravity features a pool of 9 specialized custom subagents (`system-architect`, `code-auditor`, `silent-failure-hunter`, `tdd-guide`, `database-reviewer`, `ui-crafter`, `docs-architect`, `build-error-resolver`, `maintenance-bot`) operating with `model: inherit` (ADR-0004). However, the environment lacked a formalized workflow to convene these specialists into a coordinated, adversarial review board.

## Decision
1. **Adopt the Tri-Pillar Council Lifecycle (`council-review`)**:
   - **Pillar 1 (Cold Context Grounding)**: Enforce objective fact-mapping via `audit-context-building` (guarantees, unvalidated assumptions, and caller topology) before opening debate.
   - **Pillar 2 (Socratic Council Formation)**: Use `grill-me` with modal dialogs (`ask_question`) to allow human operators to select 3 to 5 domain seats and establish acceptance criteria.
   - **Pillar 3 (Autonomous Council Deliberation)**: Delegate execution to `teamwork-preview`. The Sentinel and Orchestrator dispatch parallel custom subagents, submit findings to adversarial challengers testing line citations, compile Chairman scorecards with arithmetic closure, and require independent Victory Auditor certification.
2. **Enforce Read-Only Boundary**:
   Council runs are strictly diagnostic. Zero file mutations and zero package installations are permitted during execution.
3. **Standardize Deliverable Formats**:
   Require all council outputs to feature a normalized 16-cell scorecard (Rigor, Ergonomics, Token Efficiency, Spec Alignment), a prioritized Gap Matrix (Critical, High, Medium, Low), and an actionable non-breaking roadmap.

## Consequences
- **Positive**:
  - Eliminates single-model hallucination and self-certification traps.
  - Converts loose prompts into verifiable, mathematically reconciled scorecards.
  - Reuses existing specialized custom subagents rather than generic prompts.
- **Trade-offs / Operational Requirements**:
  - Higher token expenditure and wall-clock latency due to multi-agent exploration and adversarial verification gates.
