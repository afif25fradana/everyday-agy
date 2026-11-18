# Contract Change Protocol

On-demand boundary evolution protocol referenced by [`SKILL.md`](../SKILL.md) and governed by [`orchestrator`](../../orchestrator/SKILL.md).

Never change implementation first and update the contract afterward.

## Change Steps

1. Propose the consumer need and compatibility impact.
2. Change the canonical artifact.
3. Review the contract diff with affected consumers and the provider.
4. Establish a verified rollback checkpoint (`New-AuditCheckpoint.ps1`), then regenerate types, clients, or fixtures.
5. Update provider and consumer implementations.
6. Run consumer and provider verification against the updated contract.
7. Merge only when all affected sides agree on the new contract. Under the [`orchestrator`](../../orchestrator/SKILL.md) Subagent Commit/Push/PR Ban, subagents must never commit, push, or merge; only the Parent Orchestrator merges after Gate 2 approval.

## Additive vs. Breaking Policy

- **Additive changes**: Verify that existing consumers continue to work unchanged without requiring simultaneous upgrades.
- **Breaking changes**: Follow the repository's versioning or migration policy rather than silently repurposing an existing field.
