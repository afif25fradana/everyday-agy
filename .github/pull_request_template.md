## Summary

<!-- Provide a concise 1-2 sentence overview of what this PR changes and why. -->

## Changes Proposed

- 

## Verification Checklist

Before submitting, please ensure the following checks pass:

- [ ] **Syntax Validation**: Checked all modified `.ps1` scripts using PowerShell's AST parser.
- [ ] **Safety Tests**: Ran `pwsh -File config/skills/audit-dev-workflow/scripts/Test-PowerShellCommandSafety.Tests.ps1` (all tests passing).
- [ ] **Secret Scrub**: Verified that no API keys, private tokens, or credential strings are present in the diff.
- [ ] **Anti-Slop Cleanliness**: Removed generic AI comments, conversational apologies, and filler text.
- [ ] **Architecture Records**: Added or updated a Nygard ADR under `docs/adr/` if this introduces or modifies architectural boundaries.
