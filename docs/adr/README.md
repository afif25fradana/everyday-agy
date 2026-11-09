# Architectural Decision Records (ADRs)

This directory contains the record of technical and architectural decisions for everyday-agy, formatted according to the Michael Nygard standard.

| ADR | Title | Status | Date | Primary Subject |
|:---|:---|:---:|:---:|:---|
| [ADR-0001](./0001-context7-streamable-http-token-headers.md) | Context7 Streamable HTTP Header Authentication | Accepted | 2026-10-22 | MCP & Authentication |
| [ADR-0002](./0002-domain-partitioned-skills-vs-greedy-references.md) | Domain-Scoped Skills vs Monolithic Reference Trees | Superseded (ADR-0016) | 2026-10-22 | Skill Packaging |
| [ADR-0003](./0003-ponytail-5-suite-architecture.md) | Discrete Commands for Ponytail Pair-Programming vs Audits | Superseded (ADR-0016) | 2026-10-22 | Skill Packaging |
| [ADR-0004](./0004-subagent-model-tiering-inherit.md) | Model Inheritance for Planners and Flash for Routine Tasks | Partially Superseded (ADR-0027) | 2026-10-22 | Model Selection |
| [ADR-0005](./0005-spec-kit-and-ast-grep-tooling.md) | Spec-Kit, GitHub Workflow & AST-Grep Integration | Partially Superseded (ADR-0024) | 2026-10-22 | Developer Tooling |
| [ADR-0006](./0006-marketplace-plugin-decoupling-and-security-adaptation.md) | Decouple Marketplace Plugins from Git Tracking | Superseded (ADR-0011, 0016) | 2026-10-22 | Git Tracking |
| [ADR-0007](./0007-audit-dev-workflow-harmonization-and-anti-cheating.md) | Development Workflow Tooling and Reproducer-First Tests | Superseded (ADR-0014, 0015, 0022, 0028) | 2026-10-22 | Workflow Protocol |
| [ADR-0008](./0008-tri-pillar-council-review-architecture.md) | Multi-Perspective Architecture and Pre-Release Review Board | Accepted | 2026-10-22 | Multi-Agent Review |
| [ADR-0009](./0009-ecc-harness-adaptation-and-security.md) | PowerShell AST Command Safety Validation and Gotcha Limits | Partially Superseded (ADR-0024) | 2026-10-23 | Command Safety |
| [ADR-0010](./0010-domain-specific-academic-council.md) | Academic Review Panel for Empirical Finance Research | Accepted | 2026-10-23 | Multi-Agent Review |
| [ADR-0011](./0011-ast-security-hardening-and-deployment-parity.md) | Intercept .NET Deletions and Mirror Secret Scans in Restore | Partially Superseded (ADR-0024, 0026) | 2026-10-24 | Security & Deployment |
| [ADR-0012](./0012-flash-high-optimization-ast-hardening-and-model-tiering-invariants.md) | Retain Flash for Tactical Agents and Strip Commit Message Flags | Partially Superseded (ADR-0015, 0024, 0027) | 2026-10-28 | Model Selection & Shell |
| [ADR-0013](./0013-teamwork-engine-graduation-and-council-parity.md) | Standardize Multi-Agent Tool Invocations to `teamwork` | Accepted | 2026-10-29 | Engine Bindings |
| [ADR-0014](./0014-superpowers-heuristics-distillation-and-platform-adaptation.md) | Adopt TDD Discipline, Failure-First Checks, and Anti-Sycophancy | Partially Superseded (ADR-0022) | 2026-10-30 | Testing & Review Rules |
| [ADR-0015](./0015-checkpoint-gated-autonomous-execution-and-dynamic-elevation.md) | Checkpoint-Gated Autonomous Execution for Tiers 0 and 1 | Partially Superseded (ADR-0019, 0024, 0026, 0028) | 2026-10-31 | Workflow & Rollback |
| [ADR-0016](./0016-third-party-upstream-skills-decoupling.md) | Decouple Vendored Community Skills to External Upstream Links | Accepted | 2026-10-31 | Git Tracking & Footprint |
| [ADR-0017](./0017-custom-agent-consolidation-and-mandatory-skill-gates.md) | Consolidate Documentation Agents and Enforce Absolute Paths for Skills | Partially Superseded (ADR-0018, 0024) | 2026-11-01 | Custom Agents & Paths |
| [ADR-0018](./0018-fleet-parity-and-deployment-path-symmetry.md) | Track 11th Agent (`l10n-humanizer`) and Align ADR Directory Paths | Partially Superseded (ADR-0021, ADR-0027) | 2026-11-02 | Custom Agents & Config |
| [ADR-0019](./0019-universal-lead-orchestrator-and-context-insulation.md) | Lead Orchestrator Protocol: Insulate Parent Context via Subagents | Partially Superseded (ADR-0020, 0021, 0027, 0028) | 2026-11-03 | Orchestration Protocol |
| [ADR-0020](./0020-protocol-harmonization-gate1-flow-and-fleet-parity.md) | Restore Gate 1 Human Approval in Tier 2 and Add Pre-Test Syntax Checks | Partially Superseded (ADR-0021, 0022, 0026) | 2026-11-04 | Workflow & Syntax Gate |
| [ADR-0021](./0021-orchestrator-implementer-parity-and-checkpoint-sequencing.md) | Enable Mutator Implementers in Tier 2 and Clarify Checkpoint Timing | Partially Superseded (ADR-0022, 0028) | 2026-11-04 | Workflow & Topology |
| [ADR-0022](./0022-deep-web-research-and-5-axis-audit-hardening.md) | Register Deep Web Research, Fix RED Test Sequencing, Unify Scratch Paths | Partially Superseded (ADR-0027) | 2026-11-05 | Skills & Workflow Order |
| [ADR-0023](./0023-elephant-goldfish-heuristics-distillation.md) | Adopt Zero-Decision Planning, 4-Bucket Dispute Actions, and Unrun Checks | Accepted | 2026-11-08 | Review Heuristics |
| [ADR-0024](./0024-checkpoint-data-loss-mitigation-and-protocol-unification.md) | Checkpoint Data-Loss Mitigation, AST Hardening, and Protocol Unification | Partially Superseded (ADR-0026, 0028) | 2026-11-08 | Rollback & Command Safety |
| [ADR-0025](./0025-programmatic-diff-injection-and-two-layer-yaml-validation.md) | Programmatic Diff Injection and Two-Layer YAML Validation | Partially Superseded (ADR-0028) | 2026-11-08 | Encoding & YAML CI |
| [ADR-0026](./0026-council-evaluation-remediation-ast-hardening-and-schema-grounding.md) | Council Evaluation Remediation, AST Hardening, and Schema Grounding | Accepted | 2026-11-09 | AST Security & Architecture |
| [ADR-0027](./0027-agent-fleet-rationalization-single-pass-tdd-and-subagent-hardening.md) | Agent Fleet Rationalization, Single-Pass TDD, and Subagent Hardening | Accepted | 2026-11-09 | Fleet Architecture & TDD |
| [ADR-0028](./0028-orchestrator-consolidation-audit-dev-streamlining-and-dual-subagent-pipeline.md) | Orchestrator Script Consolidation, Audit-Dev Streamlining, and Dual-Subagent Pipeline | Accepted | 2026-11-09 | Workflow & Governance |

