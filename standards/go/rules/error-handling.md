---
description: Prevent information disclosure through error responses and panic recovery
globs:
  - "**/*.go"
alwaysApply: false
---

# Error Handling & Information Disclosure

- **MUST NOT** expose stack traces, internal package paths, SQL error details, file system paths, server/Go version, or configuration values in responses.
- **MUST** use structured error types (`ErrorResponse{Code, Message}`) with generic client-facing messages.
- **MUST** log detailed errors server-side only with sufficient context for forensic analysis.
- **MUST** ensure panic recovery middleware returns a generic 500 — log panic details and `debug.Stack()` server-side, never send to client.
  - Wrong: `http.Error(w, fmt.Sprintf("panic: %v", rec), 500)`
  - Correct: log `rec` + stack trace, respond with `{"code":"INTERNAL_ERROR","message":"unexpected error"}`

## Framework Patterns

- **stdlib:** Buffer-before-write pattern — encode to `bytes.Buffer` first, on encoding error return generic error response. Set `Content-Type` and status only after successful encoding.
- **Gin:** Centralized error mapper middleware — call `c.Next()`, then inspect `c.Errors`, map via `errors.Is()` to appropriate status codes. Log unhandled errors, respond with generic `INTERNAL_ERROR`.
