# ADR-0003: Preservation of Ponytail 5 Discrete Modal Architecture

## Status
Accepted

## Date
2026-10-22

## Context
Ponytail 5 is a published agentic benchmark framework (tested across 39 real-world tasks) designed around the philosophy of "lazy senior developer" minimalism (YAGNI, shortest working diff).
The framework is partitioned into 6 discrete skills:
1. `ponytail`: Continuous pair-programming mode (`/ponytail lite|full|ultra`).
2. `ponytail-audit`: One-shot whole-repo quality audit.
3. `ponytail-review`: One-shot diff and pull request review.
4. `ponytail-debt`: One-shot shortcut comment ledger scanner.
5. `ponytail-gain`: Static benchmark scoreboard.
6. `ponytail-help`: Quick reference cheatsheet.

A prior theoretical audit proposed consolidating all 6 skills into a single `ponytail` skill to reduce directory count.

## Decision
Reject consolidation and preserve all 6 distinct skills:
1. Each modality serves a completely different interaction lifecycle: continuous mode toggle vs one-shot commands (`/ponytail-audit`, `/ponytail-review`, `/ponytail-debt`).
2. Merging them would force the agent to inject entire audit rubrics, regex scanning tables, and benchmark figures into the conversation turn even when the developer simply wants minimal code generation mode (`/ponytail`).
3. Discrete skills ensure progressive disclosure loads strictly what is invoked.

## Alternatives Considered & Rejected
- **Monolithic `ponytail` skill**: Rejected because it forces heavy one-shot audit and debt instructions into active pair-programming sessions.

## Consequences
- **Positive**: Clean context boundaries. One-shot reports remain purely one-shot; pair-programming remains lean and uncluttered.
- **Maintenance**: 6 short skill descriptors in `<skills>` list, consuming minimal base prompt footprint.
