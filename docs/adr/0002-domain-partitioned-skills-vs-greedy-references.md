# ADR-0002: Domain-Scoped Skills vs Monolithic Reference Trees

## Status
Superseded by ADR-0016 for vendored skills; architectural principle of domain-scoped skills retained.

## Date
2026-10-22

## Context
Antigravity documentation suggests using a single `SKILL.md` with a `references/` subdirectory for large documentation bundles to stay under the 24 KB per-file limit.

However, when a master skill containing a tree of reference files was loaded, language models frequently read the entire directory structure into context regardless of the immediate task. For example, during a copywriting task, rules for UI visual styling, mobile layouts, and human accessibility were pulled into context, consuming tokens and diluting instructions.

## Decision
Keep domain-specific rules partitioned into independent, granular skills:
- `antislop-copywriting`: Text, headlines, and copywriting rules.
- `antislop-ui`: Visual craft, colors, and layout components.
- `antislop-code`: Comment hygiene and code structure.
- `antislop-human`: Contrast, focus states, and keyboard navigation.
- `antislop-layoutmobile`: Responsive grids and mobile touch targets.

The skill router activates only the specific skill relevant to the user request, loading only that skill body into context.

## Alternatives Considered & Rejected
- **Single monolithic skill with `references/` subfolder**: Rejected because models read all references recursively, increasing token consumption and diluting domain focus.
- **Inlining all rules into a single file**: Rejected due to the 24 KB per-file limit and unnecessary token usage on single-concern tasks.

## Consequences
- **Positive**: Copywriting prompts only load text rules; frontend prompts only load UI rules.
- **Trade-off**: Requires maintaining distinct `SKILL.md` descriptors, though the frontmatter overhead is small (~30-50 tokens per description).
