---
description: Core token lifecycle and session invalidation rules
alwaysApply: true
---

# Token & Session Lifecycle — Core Rules

- **MUST** invalidate all active tokens/sessions when a user account is locked, disabled, or password is changed.
- **MUST** revoke old tokens on renewal — previous tokens must not remain valid.
- **MUST** use short-lived access tokens (minutes) and longer-lived refresh tokens with rotation.
- **MUST** bind refresh tokens to the client — validate client identity on refresh.
- **MUST** detect reuse of rotated refresh tokens — revoke the entire token family (indicates compromise).
