---
description: Go-specific token lifecycle — jti generation and revocation checking
globs:
  - "**/*.go"
alwaysApply: false
---

# Go Token Lifecycle

- **MUST** generate token identifiers (`jti`) using `crypto/rand`, not `math/rand`.
- **MUST** check token revocation status (e.g., `cache.Get(ctx, "revoked:"+jti)`) and fail closed on cache errors.
