---
description: Goroutine safety rules for context propagation and preventing data races
globs:
  - "**/*.go"
alwaysApply: false
---

# Goroutine Safety

- **stdlib:** Pass `ctx context.Context` to goroutines — it carries tenant/auth info safely (immutable).
- **Gin: MUST** extract all needed values from `*gin.Context` **before** spawning a goroutine — **NEVER** pass `*gin.Context` to a goroutine. Gin pools context objects via `sync.Pool`, so a goroutine reading `c` after the handler returns may read another request's tenant data (tenant isolation vulnerability, not just a data race). Extract with `c.GetString("organization")` etc., and use `c.Request.Context()` for the request context.
- **MUST NOT** share mutable state across goroutines without proper synchronization.
- **MUST** use `errgroup.WithContext()` or `context.WithCancel()` for goroutine lifecycle management — bare `go func()` calls leak goroutines on errors or timeouts. First error cancels the context so all goroutines see cancellation.
