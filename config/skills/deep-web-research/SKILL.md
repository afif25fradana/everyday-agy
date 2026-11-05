---
name: deep-web-research
description: Verifiable primary-source web research protocol enforcing version-locked queries and official domain constraints.
---

# Deep Web Research Protocol

Goal: Every external claim, API signature, or version constraint must trace directly to an authoritative primary source (official documentation, release notes, or vendor changelogs), not unverified search snippets or secondary blog aggregators.

---

## 1. When to Activate

- Verifying third-party library APIs, method signatures, return types, or parameter options.
- Checking runtime compatibility, LTS floors, deprecation schedules, or breaking changes.
- Cross-checking proposed remediation plans or bugfixes against live vendor documentation when Context7 MCP does not cover the library.
- Auditing dependency versions, CVE advisories, or security patches.

**When to Skip**:
- Stable language built-ins or standard library concepts known without drift.
- Logic completely answerable from repository source code, local tests, or existing ADRs.

---

## 2. Core Operational Rules

### A. Version-Locked Queries
Never execute generic or unpinned web searches (e.g. `pydantic model validator`).
- Always extract target version from project manifests (`package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `pom.xml`).
- Include the exact package name, major/minor version, and year in the query (e.g. `pydantic v2.8 model_validator mode after syntax 2024`).

### B. Mandatory Official Domain Targeting
Search snippets and AI overview summaries are pointers, not authoritative contracts.
- Always utilize the `domain` parameter in `search_web` targeting official documentation domains (e.g. `docs.python.org`, `react.dev`, `angular.dev`, `nodejs.org`, `docs.rs`, `github.com`).
- Discard or strongly downweight SEO blog aggregators (Medium, TowardsDataScience, generic tutorial re-publishers) unless official docs are demonstrably unreachable.

### C. Direct Raw Source Verification (CLI Fallback)
If `search_web` summary feels ambiguous, incomplete, or conflicts across sources:
- Pull raw release notes, markdown documentation, or type declarations directly using CLI tooling:
  - GitHub releases: `gh release view <tag> --repo <owner/repo>`
  - Raw GitHub files: `curl -sSL https://raw.githubusercontent.com/<owner>/<repo>/<branch>/<file>`
  - Package metadata: `npm view <pkg>@<ver> ...` or `pip index versions <pkg>`

### D. Version Disambiguation Matrix
When documentation from different major versions conflicts (e.g. v1 vs v2):
- Explicitly trace the breaking change boundary in the changelog.
- Never accept a pattern without verifying which major version introduced or removed it.

### E. Blast Radius & Token Economy
- Keep searches focused: 1–3 targeted queries max. Stop immediately once the exact method signature or version constraint is verified.
- Never dump raw web pages or multi-screen documentation text into chat or artifacts. Extract only the precise signature, return shape, and caveat constraints.

---

## 3. Reporting & Verification Status Tags

Every external claim or API recommendation must carry an explicit status tag:
- **`[VERIFIED: <source_url_or_ref>]`**: Confirmed directly via official documentation, release notes, or raw repository source.
- **`[UNVERIFIED: <reason>]`**: Inferred from model memory, unconfirmed secondary blog post, or unresolved conflicting sources.
- **`[VETOED: <reason>]`**: Definitively rejected due to deprecation, version incompatibility, or hallucinated signature.
