---
description: Go-specific auth middleware patterns, JWT validation code, and WSO2 product integration
globs:
  - "**/*.go"
alwaysApply: false
---

# Go Authentication Patterns

## Middleware Enforcement

- **stdlib:** every handler must be wrapped by auth middleware (`func(http.Handler) http.Handler` chain). Register as `handler := authMiddleware(mux)`.
- **Gin:** every route group must include auth middleware via `router.Group().Use(AuthMiddleware())`. Routes **MUST NOT** be registered on the engine bypassing middleware groups.
- Use `jwt.WithValidMethods([]string{"RS256"})` for algorithm enforcement.
- Use `jwt.WithLeeway()` for clock skew tolerance instead of disabling time validation.

## Middleware Context Patterns

- **stdlib:** Auth middleware stores result via `context.WithValue()` + typed accessors, passes to handler with `r.WithContext(ctx)`.
- **Gin:** Auth middleware stores claims via `c.Set("organization", ...)`, `c.Set("username", ...)`, `c.Set("permissions", ...)`. Use `c.AbortWithStatusJSON()` on failure.

## JWT Validation

Parse with algorithm enforcement and claim validation:
`jwt.Parse(tokenString, keyFunc, jwt.WithValidMethods([]string{"RS256"}), jwt.WithIssuer(expected), jwt.WithAudience(expected), jwt.WithLeeway(30*time.Second))`

For automatic JWKS key rotation, use `keyfunc.NewDefaultCtx(ctx, []string{jwksURL})` then `jwt.Parse(tokenString, jwks.KeyfuncCtx(ctx))`.

## WSO2 Product-Specific

- **Thunder (stdlib):** Auth middleware calls `securityService.Process(r)`, stores via `security.WithContext(r.Context(), secCtx)`.
- **API Platform (Gin):** Uses `keyfunc/v3` for JWKS rotation with `MicahParks/jwkset`.
