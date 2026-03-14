---
description: Prevent information disclosure through error responses and stack traces
globs:
  - "**/*.java"
alwaysApply: false
---

# Error Handling & Information Disclosure

- **MUST NOT** expose stack traces, internal package names, server versions, or file paths in error responses.
- **MUST** use generic error messages for end users. Log detailed errors server-side only.
- **MUST** sanitize all error/exception messages before including in HTTP responses.

## Key Rules

- Implement a global exception handler / JAX-RS `ExceptionMapper` for all unhandled exceptions — return generic 500.
- Catch specific exceptions at the business layer. Wrap checked exceptions (`SQLException`, `NamingException`) — never propagate their messages to the response.
- Log security-relevant errors with sufficient context (who, what, when, from where).
- Config files must not be accessible over HTTP without authentication.
- Use identical messages and timing for "user not found" vs "wrong password" to prevent user enumeration. Use constant-time comparison (see `auth-checks.md`).
