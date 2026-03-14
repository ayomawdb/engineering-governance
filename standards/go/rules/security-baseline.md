---
description: WSO2 Go security context and Go-specific self-review additions
globs:
  - "**/*.go"
alwaysApply: false
---

# WSO2 Go Security

WSO2 Go products handle OAuth2/OIDC, API gateway, identity, and agent governance. Two HTTP frameworks: stdlib `net/http` and Gin — never mix patterns between them. See `secure-defaults.md` for WSO2 product-specific notes (Thunder, API Platform).

## Go Self-Review Additions

In addition to the common checklist (see engineering security-baseline):

1. TLS 1.2+ enforced, all server timeouts set, `InsecureSkipVerify` not true
2. `crypto/rand` used (not `math/rand`) for tokens, nonces, keys
3. Gin: `*gin.Context` values extracted before goroutines
4. Outbound HTTP with user-supplied URLs has SSRF validation
