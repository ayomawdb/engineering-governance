---
description: Java session security — cookies, session fixation, and timeouts
globs:
  - "**/*.java"
alwaysApply: false
---

# Java Session Security

- **MUST** set `Secure`, `HttpOnly`, and `SameSite` attributes on session cookies.
- Regenerate session ID after authentication (session fixation prevention). See `security-baseline.md` for Carbon pattern.
- Implement absolute session timeout in addition to idle timeout.
- On logout, invalidate server-side — do not rely on client-side cookie deletion.
