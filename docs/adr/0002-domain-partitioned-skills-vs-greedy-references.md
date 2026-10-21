# ADR-0002: Domain-Partitioned Skills vs Greedy References

## Status
Accepted

## Date
2026-10-22

## Context
Antigravity's official skill documentation recommends using a single `SKILL.md` with a `references/` subdirectory for large documentation bundles to stay under the 24 KB file limit.
However, real-world agent interaction with multi-domain frameworks like `antislop` revealed a severe anti-pattern: *greedy retrieval*. When a master skill containing a tree of reference files is loaded, the LLM often indexes or recursively reads the entire directory structure regardless of the immediate task. For example, during a copywriting task, rules for UI visual styling, mobile layouts, and human accessibility were pulled into context, massively inflating token consumption and causing cross-domain instruction confusion.

## Decision
Keep domain-specific rules partitioned into independent, granular skills:
- `antislop-copywriting`: Text, headlines, anti-AI copywriting rules.
- `antislop-ui`: Visual craft, colors, layout components.
- `antislop-code`: Comment hygiene and code quality.
- `antislop-human`: Contrast, focus states, keyboard navigation.
- `antislop-layoutmobile`: Responsive grids and mobile touch targets.

Antigravity's progressive disclosure router matches ONLY the exact skill relevant to the user prompt, loading only that skill's concise body into context.

## Alternatives Considered & Rejected
- **Single monolithic `antislop` skill with `references/` subfolder**: Rejected because agent runs greedily explore and read all references, blowing token budgets and diluting domain focus.
- **Inlining all rules into a single file**: Rejected due to the 24 KB per-file hard cap and massive prompt token waste.

## Consequences
- **Positive**: Zero cross-domain token waste. Copywriting prompts only load text rules; frontend prompts only load UI rules.
- **Trade-off**: Requires maintaining distinct `SKILL.md` descriptors, but this overhead is negligible (~30-50 tokens per description).
