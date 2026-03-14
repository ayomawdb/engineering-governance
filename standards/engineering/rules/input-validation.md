---
description: Core input validation rules for all endpoints
alwaysApply: true
---

# Input Validation — Core Rules

- **MUST** validate all input parameters on every endpoint, including internal/admin endpoints.
- **MUST** validate redirect/callback URLs against an allowlist (https scheme, host match, no embedded credentials, no path traversal).
- **MUST NOT** accept sensitive data (tokens, passwords) as URL query parameters — use request body or headers. Query params appear in access logs, browser history, and Referer headers.
- **MUST** prevent SSRF: allowlist hosts, require HTTPS, resolve DNS, block loopback/link-local/private IPs, re-validate redirect targets.
