---
description: Go-specific secure defaults — TLS, timeouts, bypass flags, stdlib vs Gin patterns
globs:
  - "**/*.go"
alwaysApply: false
---

# Go Secure Defaults

- **MUST NOT** ship with security bypass env vars or flags enabled in production.
- **MUST NOT** use `AllowAllOrigins: true` with `AllowCredentials: true` in CORS — Gin's `gin-contrib/cors` reflects the Origin header, making it equivalent to allowing any origin with credentials.
- **MUST** use `rate.NewLimiter()` as middleware, per-client (keyed by IP/API key) with periodic cleanup.
- **MUST** set TLS `MinVersion: tls.VersionTLS12` and use only AEAD cipher suites.
- **MUST NOT** set `InsecureSkipVerify: true` in `tls.Config`.
- **MUST** set all server timeouts: `ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout`, `IdleTimeout`.
- **MUST** use `crypto/rand` for all security-sensitive random values — `math/rand` is not cryptographically secure.

## Security Bypass Flags

These **MUST NOT** be enabled in production:
- Environment variables or config flags that skip auth middleware
- JWT validation bypass flags — anything that disables signature verification
- Default secret keys or placeholder values — use `required:"true"` with no default

## Configuration Patterns

- **stdlib:** YAML/TOML config with env substitution for secrets (`${DB_PASSWORD}`). Never hardcode.
- **Gin:** `envconfig` struct tags. Secrets must use `required:"true"` with no default value.

## WSO2 Product-Specific

- Check each product for dev-only security bypass flags — these must be disabled in production and logged when active in development.
- Audit CORS, JWT validation, secret key defaults, and rate limiting configuration against the rules above.

## stdlib vs Gin Key Differences

- **Handler:** stdlib `func(w http.ResponseWriter, r *http.Request)` vs Gin `func(c *gin.Context)`
- **Tenant context:** stdlib uses `context.WithValue()` + typed accessors; Gin uses `c.Set()`/`c.Get()` — `c.Request.Context()` does NOT contain `c.Set()` values
- **Goroutines:** stdlib pass `ctx`; Gin extract values first, NEVER pass `*gin.Context`
- **Middleware:** stdlib `func(http.Handler) http.Handler` wrapping; Gin `gin.HandlerFunc` via `router.Use()`
- **Input binding:** stdlib `json.NewDecoder(r.Body).Decode(&v)` + manual validation; Gin `c.ShouldBindJSON(&v)` with `binding:` tags
- **Params:** stdlib `r.PathValue("id")`, `r.URL.Query().Get("key")`; Gin `c.Param("id")`, `c.Query("key")`
- **Response:** stdlib `w.Header().Set()` + `w.WriteHeader()` + encode; Gin `c.JSON(status, obj)`
- **SQL placeholders:** PostgreSQL `$1, $2`; SQLite/generic `?` + `sqlx.Rebind()`

## Dependency Security

- Run `govulncheck ./...` before releases.
- Check new dependencies against known vulnerability databases before adding.
- Prefer dependencies with active maintenance and security response practices.
