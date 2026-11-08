# ADR-0003: Discrete Commands for Ponytail Pair-Programming vs Audits

## Status
Superseded by ADR-0016

## Date
2026-10-22

## Context
The ponytail framework is designed around minimal code diffs and pragmatic developer practices. It is divided into six discrete skills:
1. `ponytail`: Continuous pair-programming mode (`/ponytail lite|full|ultra`).
2. `ponytail-audit`: One-shot whole-repository quality audit.
3. `ponytail-review`: One-shot diff and pull request review.
4. `ponytail-debt`: One-shot shortcut comment ledger scanner.
5. `ponytail-gain`: Measured savings display.
6. `ponytail-help`: Quick reference cheatsheet.

A proposal suggested consolidating all six skills into a single `ponytail` skill to reduce directory count.

## Decision
Retain distinct skills for pair-programming mode versus one-shot commands:
1. Each command serves a distinct interaction lifecycle: continuous mode toggle versus one-shot reports (`/ponytail-audit`, `/ponytail-review`, `/ponytail-debt`).
2. Merging them would inject full audit rubrics, regex scanning patterns, and benchmark data into the conversation turn when the developer only wants minimal code generation mode (`/ponytail`).
3. Discrete skills ensure progressive disclosure loads strictly what is invoked.

## Alternatives Considered & Rejected
- **Monolithic `ponytail` skill**: Rejected because it forces heavy one-shot audit and debt instructions into active pair-programming sessions.

## Consequences
- **Positive**: Clean context boundaries. One-shot reports remain purely one-shot; pair-programming remains lean and uncluttered.
- **Maintenance**: Six short skill descriptors in the `<skills>` list, consuming minimal base prompt footprint.
