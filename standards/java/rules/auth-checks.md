---
description: Java-specific authentication patterns — SOAP, adaptive auth, JIT provisioning, and privilege escalation
globs:
  - "**/*.java"
alwaysApply: false
---

# Java Authentication Patterns

## Framework-Level Auth

- **MUST** check auth at the framework level (filter/interceptor) before any business logic, not just in business code.
- **MUST NOT** skip auth checks on SOAP admin services. Use `AdminService` base class or Carbon security interceptor.
- Validate subscription status before API invocations.

## Adaptive Authentication

- Treat script inputs as hostile. Sandbox execution — restrict filesystem, network, and dangerous Java classes.
- Validate and sanitize values passed from client-side flows into adaptive auth script context.

## JIT Provisioning

- Validate JIT-provisioned attributes cannot impersonate existing users.
- Enforce authorization on profile updates triggered by JIT provisioning. Verify federated claims before granting local access.

## Rate Limiting & CAPTCHA

- Validate reCAPTCHA tokens server-side. Apply rate limiting to auth endpoints, password recovery, and MFA setup APIs.
- Ensure reCAPTCHA validation works across all user stores (primary + secondary).

## Timing Attack Prevention

Use `MessageDigest.isEqual()` for all secret comparisons (tokens, HMAC digests, passwords, API keys) — constant-time comparison prevents timing side channels.

## Privilege Escalation Prevention

- Authorize on the target resource, not just the caller's role. Admin in tenant A must not operate on tenant B resources.
- Enforce horizontal privilege boundaries: prevent IDOR by validating resource ownership.
- For role/permission changes: verify the caller can grant the specific role — prevent self-elevation.
- Re-authenticate before sensitive operations (password change, MFA disable, role grant).
