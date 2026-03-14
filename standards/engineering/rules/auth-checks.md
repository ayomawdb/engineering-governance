---
description: Core authentication and authorization enforcement rules
alwaysApply: true
---

# Authentication & Authorization — Core Rules

- **MUST** enforce auth on every endpoint — no exceptions for "internal" or "admin-only" routes.
- **MUST** validate JWT signatures — fail closed when JWKS endpoint is unavailable (never skip validation).
- **MUST NOT** use default/placeholder secret keys.
- **MUST** validate `iss`, `aud`, `exp`, `nbf` claims on all JWTs.
- **MUST** enforce expected signing algorithm (prevent `alg:none` and key confusion attacks).
- **MUST** re-validate permissions on sensitive state changes (account lock, role change, token revocation).
