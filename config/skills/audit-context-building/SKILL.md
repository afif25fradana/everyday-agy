---
name: audit-context-building
description: Understand a codebase before looking for bugs in it - map function guarantees, assumptions, and dependencies. Use before security audits or architecture reviews.
---

# Audit Context Building

Build understanding, not verdicts. This runs before anyone hunts for bugs, and feeds that work.

## When to Use

At the start of an audit, a threat model, or an architecture review, when the code is unfamiliar. Also when
an earlier pass produced findings nobody could judge, because no one had mapped out how the system fits
together.

## When NOT to Use

Do not name vulnerabilities, suggest fixes, write proofs-of-concept, or rate severity. Those belong to the
hunting phase, which runs next and with the whole picture in hand. When the code counts on something and
nothing checks it, record that plainly and move on - whether it matters is decided later.

Not worth the tokens on code you already understand.

## Do not analyze in this context

The analysis is long, and this context needs to survive to use it. Dispatch it:

- **A codebase, or more than one function** - invoke a read-only research subagent (`invoke_subagent` with `TypeName: "research"`, `Role: "Codebase Context Auditor"`). The subagent inspects functions using `view_file` and `rtk rg`, records findings under `$HOME/.gemini/antigravity/scratch/<task>/audit-context/`, and returns compact records via `send_message`.
- **A single function** - delegate to a read-only research subagent, or inspect inline using `read_file` if context is lean.

Then work from what comes back: the index, the unenforced assumptions, the open questions. Read a function's
record when you need its detail.

## What comes back, and how to read it

Each record lists what must always be true (with the line that shows it), what the function takes on faith
(with whatever establishes it), which functions it calls and what it needs from each, and anything still
unclear. The dossier adds the rules that span several functions, who can reach what, and where the
complicated parts cluster.

Two things matter more than the rest:

- **Assumptions marked `nothing found`.** The code counts on something being true and nothing anywhere makes
it true. This is the most useful thing to hand the hunting phase.
- **The open questions.** An honest list of what is still unclear beats a confident answer that turns out to
be wrong. Carry them forward instead of closing them out.

Where two records disagree, both are quoted rather than quietly reconciled. That is a fact about the code,
not a flaw in the analysis.

## The format

Each function audit record captures 4 core slots:

1. **Guarantees**: What must always hold upon exit or invariant preservation, citing the exact source code line.
2. **Assumptions**: What the function takes on faith from callers or environment, marked `nothing found` if unvalidated.
3. **Calls**: What functions/contracts are invoked and what invariants are required from each.
4. **Open Questions**: Unclear boundaries, missing invariants, or unverified behaviors to carry forward.

**The rule that matters most: follow the calls.** Whether a function is correct usually depends on something
another function does, and you cannot see that from the caller alone. A limit looks enforced because the
value came back from a function whose name suggests it was checked. So read the function being called, follow
every path through it rather than only the one that succeeds, and say what makes each assumption true. When
nothing does, use those words: `nothing found`. Every claim cites a line, or becomes an open question.

---

## License & Attribution

Adapted from [trailofbits/skills](https://github.com/trailofbits/skills) by Trail of Bits, Inc.  
Licensed under the [Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](./LICENSE).  
Modifications made for Google Antigravity runtime by everyday-agy contributors.
