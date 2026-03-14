---
description: Agent operational safety rules and common self-review checklist
alwaysApply: true
---

# Engineering Security — Baseline

## Agent Operational Safety

- **MUST NOT** read `.env`, `.env.local`, `.env.production`, or similar secret files (`.env.example`/`.env.sample` are fine).
- **MUST NOT** read or output private keys (`*.pem`, `*.key`, `id_rsa`), credential files (`~/.aws/credentials`, `~/.kube/config`), Terraform state (`*.tfstate`), or token files.
- **MUST NOT** run `env`/`printenv`/`set` unfiltered. Check single var: `[ -z "$VAR" ] && echo "not set" || echo "set (value hidden)"`
- **MUST NOT** hardcode secrets or commit them to git. Verify `.gitignore` excludes `.env`, private keys, credentials.
- **MUST NOT** use real credentials or production data in test fixtures.
- **MUST NOT** log sensitive data (passwords, tokens, PII, session IDs).
- **MUST** mask credentials accidentally encountered in output.
- Before connecting to external services, verify target environment. If production, require user confirmation.

## Self-Review Checklist

After any code change, verify all apply — fix any "no" before completing:

1. No user input reaches response without encoding, or SQL/commands without sanitization
2. Every new endpoint enforces authentication AND authorization
3. Multi-tenant: cache keys, DB queries, resource lookups scoped to org/tenant
4. File uploads restricted by type, size, name, and destination
5. Error responses don't leak internals (stack traces, paths, SQL, versions)
6. Redirect/callback URLs validated against allowlist
7. Config defaults secure (auth required, CORS restrictive, no bypass flags, no default keys)
8. Auth flow changes: tokens invalidated on account lock/disable/password change
9. No hardcoded secrets, default keys, or bypass flags
10. No logging of passwords, tokens, PII, or session identifiers
