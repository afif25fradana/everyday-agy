# Security Policy

## Supported Versions

Only the latest commit on the `main` branch receives active security updates and regression patches.

| Version / Branch | Supported          |
| ---------------- | ------------------ |
| `main`           | :white_check_mark: |
| Older commits    | :x:                |

---

## Reporting a Vulnerability

If you discover a security vulnerability, credential leak risk, or command execution bypass in this repository, please report it **privately**. Do not open a public issue.

### Preferred Reporting Method
Use GitHub's native **Private Vulnerability Reporting**:
👉 [Report a Vulnerability](https://github.com/afif25fradana/everyday-agy/security/advisories/new)

This allows secure, encrypted, and private communication directly with the maintainer without exposing details publicly before a fix is ready.

### What to Include
To help us triage and reproduce the issue quickly, please provide:
1. **Description**: Clear explanation of the potential vulnerability or bypass.
2. **Reproduction Steps**: Minimal proof-of-concept command, script, or environment configuration.
3. **Impact**: What could an attacker or misconfigured agent achieve (e.g. secret extraction, arbitrary command execution, directory traversal).
4. **Proposed Fix**: Any suggested patch or remediation (optional).

### Maintainer Response Expectations
This is an independently maintained repository. Reports will be acknowledged on a best-effort basis (typically within 48 to 72 hours), and confirmed security issues will be addressed promptly with an atomic patch and updated regression tests.
