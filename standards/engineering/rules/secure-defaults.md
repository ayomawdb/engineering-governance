---
description: Core secure configuration defaults
alwaysApply: true
---

# Secure Defaults — Core Rules

- **MUST** ship features with secure defaults — auth required, debug disabled, restrictive CORS.
- **MUST NOT** expose management interfaces or internal endpoints without authentication.
- **MUST** set CORS to restrictive origin list (never `*` with credentials in production).
- **MUST** enforce TLS 1.2+ with AEAD cipher suites (AES-GCM preferred).
- **MUST** configure rate limiting on public endpoints.
- **MUST NOT** hardcode secrets, IVs, salts, or cryptographic keys.
- Prefer SHA-256+, AES-GCM, ECDSA P-256+. Avoid MD5, SHA1, DES, RC4, RSA < 2048-bit.
