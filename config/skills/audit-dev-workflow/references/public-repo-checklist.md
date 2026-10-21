# Public Repo Checklist

Use when preparing or reviewing a public release, README, CHANGELOG, or release notes. "Required" items can block a release; "Recommended" items are worth mentioning but do not block.

## Required

- **CI-Claim Gate**: A passing-test or platform-support claim ships only if backed by a green CI run on that platform at the current `Git HEAD SHA` (verified via non-interactive `gh run watch <id> --exit-status --compact` or `gh run view`). Label each such claim during review:
  - `CI-verified`
  - `verified locally only`
  - `stale`
  If CI is red, stop, inspect the last ~20 failing log lines via `gh run view <id> --log-failed`, and fix it or remove both the claim and the workflow before shipping.
- **Stranger-Verifiable Claims**: Whenever practical, a quality claim in public docs should be checkable by a stranger (CI badge, reproducible command, shipped artifact). If it isn't, state it as personal experience, not as a formal benchmark claim.
- **No Mutable Vanity Metrics**: Never sync test counts, coverage %, or LOC into README, CHANGELOG, or CI step names; they go stale immediately.
- **Accurate Claims**: Every claim in README, CHANGELOG, or release notes matches verified source code and test evidence.
- **Clean Rebrand / Rename**: After a rename or rebrand, grep tracked files (`rtk rg`) and build metadata for the old name. Historical commit messages are left alone.
- **Zero Process Leak**: Confirm no `handoff_artifact`, `scratch`, checkpoint branch names, or AI workflow terms appear anywhere in tracked files or commit history.

## Recommended

- No `.gitkeep` left in directories that now contain files.
- No spaces or `&` in shipped file and directory names.
- Discoverability: repo description, topics, homepage field, and one default branch name used consistently (`main` vs `master`).
- README first line says plainly what the software is.
- Stranger test as the last step: open the repo as a first-time visitor would (README first line, Actions tab, topics, releases page) and judge the 30-second impression.
- If a live demo or release artifact exists, the README links to it.
