---
description: Java secure configuration — cryptography, XML parser hardening
globs:
  - "**/*.java"
  - "**/*.xml"
alwaysApply: false
---

# Java Secure Defaults

## Java-Specific Defaults

- Session timeout: 15-30 min for admin; Password policy: enforce minimum complexity
- Cookie attributes: `Secure; HttpOnly; SameSite=Lax`
- API rate limiting: enabled with conservative defaults
- Log verbosity: no sensitive data in default log level
- **MUST** configure XML parsers to disable external entity resolution (XXE). See `input-validation.md`.

## Cryptography

- **Prohibited -> Use instead**: MD5/SHA-1 -> SHA-256/SHA-3 | DES/3DES/RC4/Blowfish -> AES-256-GCM | RSA <2048/DSA -> RSA 2048+ or ECDSA P-256+ | Plain SHA/MD5 for passwords -> bcrypt/scrypt/Argon2 | `java.util.Random`/`Math.random()` -> `SecureRandom` | ECB mode -> GCM or CBC+HMAC
- Use `Cipher.getInstance("AES/GCM/NoPadding")` with random 12-byte IV from `SecureRandom.getInstanceStrong()`.
- Never hardcode IVs, salts, or keys.
- For TLS: explicitly set protocol versions and cipher suites via `SSLContext.getInstance("TLSv1.3")` — do not rely on JVM defaults.
