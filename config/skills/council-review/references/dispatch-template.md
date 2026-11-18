# Council Dispatch Prompt Contract (`dispatch-template.md`)

Read on-demand during Stage 2/3 to assemble the `Prompt` argument for the single `invoke_subagent(TypeName: "teamwork", Role: "Council Review Panel", ...)` call.

Populate **only** the `N` approved seats (`3-5`) as `R1..R<N>`. Never inject unapproved seats (e.g., do not add `Community Benchmarking` or `spec-verifier` unless seated).

```markdown
Requested team: Council review panel (read-only audit & comparison)

Conduct a comprehensive, read-only multi-perspective Council evaluation of <target_name> across <N> specialized seats to assess technical rigor, operational ergonomics, maintainability/efficiency, and specification alignment.

Working directory: <appDataDir>\brain\<conversation-id>\scratch\<task>
Integrity mode: development

## References
- Target files: <absolute_paths_to_targets>
- Relevant standards, ADRs, and specs: <paths_or_docs>

## Requirements

### R1..R<N>. Dynamic Seat Audits (Instantiate Exactly N Blocks for Approved Seats)
<!-- Repeat one block per approved seat from references/seat-catalog.md (3 to 5 seats): -->
### R1. <Seat 1 Domain> (Council Seat 1 - <agent_name>)
<Seat-specific evaluation mandate from seat-catalog.md grounded in target files>

### R2. <Seat 2 Domain> (Council Seat 2 - <agent_name>)
<Seat-specific evaluation mandate>

### R3. <Seat 3 Domain> (Council Seat 3 - <agent_name>)
<Seat-specific evaluation mandate>

<!-- Add R4 / R5 only if 4 or 5 seats were approved. If spec-verifier is seated, require Context7 MCP (`resolve-library-id` -> `query-docs`) primary verification with `search_web` fallback per `deep-web-research/SKILL.md`. -->

### R<N+1>. Strictly Read-Only Execution & Infrastructure
The evaluation must remain strictly read-only. Zero mutating file edits, package installations, or destructive commands are permitted outside the scratch workspace.

### R<N+2>. Structured Deliverable & Chairman Synthesis
Generate the certified report at `<appDataDir>\brain\<conversation-id>\scratch\<task>\council_evaluation_report.md` containing:
1. Executive Summary, Chairman Verdict, Composite Score (`X.XX / 5.0`), and Grade (`A+`, `A`, `B+`, `B`, or `C`).
2. Dynamic `4 x <N>` Numerical Scorecard Matrix (scale 1.0-5.0 across all `<N>` active seats and 4 rubric axes with verified arithmetic closure).
3. Concrete Discrepancies anchored strictly to `file.ext#Lxx-Lyy`.
4. Prioritized Gap Matrix (`CRITICAL`, `HIGH`, `MEDIUM`, `LOW`) collapsed via ADR-0004 Deduplication Barrier (`${file}::${normalize(evidence)}`, `max(Severities)`).
5. Non-breaking actionable optimization roadmap.

## Acceptance Criteria & Adversarial Verification
- [ ] Report exists at `<appDataDir>\brain\<conversation-id>\scratch\<task>\council_evaluation_report.md`
- [ ] Scorecard covers all `<N>` active seats with exact `4 x <N>` arithmetic closure (row means, column means, grand mean)
- [ ] Every identified discrepancy cites concrete line coordinates (`file.ext#Lxx-Lyy`) verified against repository HEAD by Adversarial Challengers
- [ ] Anti-Sycophancy & Exploitability Gate: Scores >= 4.50 require empirical proof or fault injection; every seat reports verified gaps OR explicitly records verified invariants checked (`no critical/high gaps verified`) without fabricating findings
- [ ] Subagent Accounting: Any timed-out or failed seat is marked `Status: not run` (never counted as 0 findings; invalidates certification)
- [ ] Spec Verification (when `spec-verifier` is seated): Roadmap actions cross-checked via Context7 or official vendor docs (`[VERIFIED]` / `[UNVERIFIED]` / `[VETOED]`)
- [ ] Fail-Closed Challenge: `CRITICAL`/`HIGH` findings remain blocking unless refuted at >= 0.8 confidence with empirical proof
- [ ] Forensic Audit: Zero repository mutations and zero package installations performed during the run
```
