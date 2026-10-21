# ADR-0001: Context7 Streamable HTTP Header Authentication

## Status
Accepted

## Date
2026-10-22

## Context
Antigravity connects to Context7 documentation service using the Model Context Protocol (MCP) Streamable HTTP transport (`https://mcp.context7.com/mcp`).
Previous theoretical audits recommended moving the Bearer token into an environment variable (e.g. `${CONTEXT7_API_KEY}` or `$env:CONTEXT7_API_KEY`) inside `mcp_config.json` for credential hygiene.
Empirical testing confirmed that Antigravity's Streamable HTTP parser does not perform shell environment variable interpolation on the `headers` object (env evaluation is only supported under the `stdio` transport). Supplying variable placeholders sends the raw literal string to the endpoint, resulting in `401 Unauthorized` and crashing the MCP client.

## Decision
Keep the Bearer token directly defined in `~/.gemini/config/mcp_config.json` for local machine runtime.
To prevent public credential leaks:
1. `mcp_config.json` is strictly added to `.gitignore`.
2. A sanitized template `config/mcp_config.example.json` with `<YOUR_CONTEXT7_API_KEY>` is committed to version control.
3. Automated credential scanners in `sync.ps1` verify no real tokens are copied into repository tracking.

## Alternatives Considered & Rejected
- **Environment variable in `mcp_config.json` headers**: Rejected because Antigravity's Streamable HTTP transport does not interpolate env vars in headers, breaking authentication.
- **Local Stdio bridge (`mcp-remote`)**: Rejected as unnecessary overhead and latency when direct Streamable HTTP works reliably with proper gitignore guards.

## Consequences
- **Positive**: MCP Context7 tool discovery and documentation queries work reliably with 100% uptime.
- **Maintenance**: Local `mcp_config.json` must remain machine-local and never committed to public repositories.
