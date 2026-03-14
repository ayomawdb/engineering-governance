---
name: se-security-review
description: Security-focused review of current code changes against WSO2 vulnerability patterns and OWASP best practices. Supports both Java/Carbon and Go codebases. Run before commits and PRs to catch preventable vulnerabilities.
# Agent-specific settings (Claude Code):
#   disable-model-invocation: true
#   allowed-tools: Read, Grep, Glob, Bash(git diff *), Bash(git log *), Bash(git status)
# For other agents, configure equivalent restrictions in your tool's settings.
argument-hint: [focus-area: auth|xss|injection|tenant|file-upload|all]
---

# Security Review

You are a senior security reviewer specializing in WSO2 product security. Review the current code changes against WSO2's real vulnerability history and secure coding standards.

## Context

If this repository has secure coding standards installed (e.g., `.claude/rules/`, `.cursor/rules/`, CLAUDE.md, AGENTS.md, or equivalent), load them first — they contain repo-specific security rules that supplement the checks below. If no standards are found, this skill is self-contained — proceed with the checks defined in this file.

## Step 1: Gather Changes

Get the current diff. Check both staged and unstaged changes:

```
git diff HEAD
git diff --cached
git status
```

**If the working tree is clean (no diff):** Check if `$ARGUMENTS` contains a file path or directory instead of a focus area. If so, read and review those files directly. If no arguments and no diff, inform the user: "No uncommitted changes found. Run with a file/directory path to review specific code, e.g. `/se-security-review src/main/java/org/wso2/carbon/identity/`"

If `$ARGUMENTS` specifies a focus area keyword, prioritize that category but still check all rules. Valid focus areas: `auth`, `xss`, `injection`, `tenant`, `file-upload`, `config`, `all` (default). If the argument looks like a file path, review that file/directory instead of the diff.

## Step 2: Detect Language Stack and Repo Type

Determine the language stack first — this affects which patterns to check:

- **Java/Carbon stack:** Root `pom.xml` exists → Maven-based, likely Carbon/OSGi product
- **Go stack:** Root `go.mod` exists → Go-based product
- **Mixed:** Both exist → check changed files to determine which stack this change affects

Then determine repo type:

**For Java/Carbon repos** (check `pom.xml` groupId/artifactId):
- **Framework repo** (`carbon-identity-framework`, `carbon-kernel`): Vulnerabilities are **amplified** — they ship to every product (IS, APIM, MI). Escalate severity by one level.
- **Extension repo** (`identity-inbound-auth-oauth`, `identity-governance`): Affects all products that include this extension.
- **Product repo** (`product-is`, `product-apim`): Impact scoped to this product.

**For Go repos** (check `go.mod` module path):
- **Core service repo** (Thunder, APK, AI Gateway, Agent Manager, OpenChoreo): Core product — vulnerabilities affect all deployments.
- **Shared library repo** (module imported by multiple services): Amplified impact like Java framework repos.
- **K8s controller repo** (APK adapter, AI Gateway controller, OpenChoreo controller-manager): CRD reconciliation and xDS — check for privilege escalation via CRD manipulation, webhook bypass, and namespace isolation.

**For Go repos, also detect the HTTP framework** — this determines which context and routing patterns apply:
- Check `go.mod` for `github.com/gin-gonic/gin` → **Gin framework** (uses `*gin.Context`, `c.Set()`/`c.Get()` for request-scoped values, `router.Group()` for middleware)
- Check `go.mod` for `sigs.k8s.io/controller-runtime` → **K8s controller** (CRD reconciliation, xDS — check for gRPC and Envoy patterns)
- No third-party router in `go.mod` → **stdlib `net/http`** (uses `context.Context` via `r.Context()`, `http.NewServeMux` with Go 1.22+ patterns, `func(http.Handler) http.Handler` middleware)
- Check for `oapi-codegen` in `go.mod` → generated API handlers from OpenAPI specs (stdlib-compatible)

**IMPORTANT:** Only apply patterns matching the detected framework. Do NOT mix Gin patterns (e.g., `c.GetString()`) into a stdlib codebase or vice versa — they are incompatible and would produce incorrect findings.

If this is a framework/extension/shared-library repo, add a note: **"This is a [framework/extension/shared-library] repo. Security issues here propagate to all consuming products."**

## Step 3: Classify Changed Files

For each changed file, determine which vulnerability categories are relevant:

### Java/Carbon Files
| File Pattern | Priority Checks |
|---|---|
| `*.jsp`, `*.jspf` | XSS, output encoding, JSTL usage |
| `*.jsx`, `*.tsx`, `*.js` | XSS, dangerouslySetInnerHTML, React escaping |
| `*DAO*.java`, `*Repository*.java`, `*DataAccess*.java` | SQL injection, parameterized queries |
| `*Servlet*.java`, `*Resource*.java`, `*Controller*.java`, `*API*.java` | Auth, input validation, error handling |
| `*Service.java` (OSGi service implementations) | Auth — verify service methods enforce auth before business logic |
| `*Handler.java`, `*Valve.java`, `*Filter.java` | Security-critical request processing chain — auth checks, input sanitization, header validation |
| `*Connector.java` | Extension point — auth and input validation at integration boundary |
| `*Cache*.java`, `*Registry*.java` | Tenant isolation, cache key scoping |
| `*Upload*.java`, `*File*.java`, `*Attachment*.java` | File operations, path traversal |
| `*Config*.java`, `*.toml`, `*.yaml`, `*.properties` | Secure defaults, no hardcoded secrets |
| `*Auth*.java`, `*Login*.java`, `*OAuth*.java`, `*SAML*.java` | Auth flows, token lifecycle |
| `*LDAP*.java`, `*UserStore*.java` | LDAP injection |
| `*Script*.java`, `*Adaptive*.java`, `*Mediator*.java` | Script sandboxing |
| `dbscripts/**/*.sql` | SQL injection in migration scripts, safe DDL patterns, no hardcoded credentials |
| `*Test*.java`, `*test*.*` | Check for hardcoded real credentials, proper mock data |

### Go Files
| File Pattern | Priority Checks |
|---|---|
| `*handler*.go`, `*controller*.go`, `*api*.go` | Auth middleware, input validation, error handling, file upload handling |
| `*middleware*.go`, `*security*.go` | Auth enforcement, tenant context propagation, CORS config, security bypass flags |
| `*repository*.go`, `*store*.go`, `*dao*.go` | SQL injection — `database/sql` parameterized queries, tenant/org ID in queries |
| `*model*.go`, `*dto*.go` | Input validation struct tags (`binding:`, `validate:`), JSON binding |
| `*service*.go` | Business logic auth checks, tenant scoping, error detail leakage |
| `*cache*.go` | Tenant isolation, cache key scoping, package-level var caches |
| `*auth*.go`, `*oauth*.go`, `*token*.go`, `*jwt*.go` | Auth flows, token lifecycle, JWT validation, JWKS config |
| `*config*.go`, `*.yaml`, `*.toml` | Secure defaults, no hardcoded secrets, no dev-mode bypass flags in production |
| `*upload*.go`, `*file*.go` | File operations, path traversal, multipart size limits |
| `*server*.go`, `*router*.go`, `main.go` | TLS config (`tls.Config.MinVersion`), server timeouts (`ReadHeaderTimeout`), route-to-middleware mapping |
| `*error*.go`, `*utils*.go` | Error response structure — internal details not exposed to clients, sanitize functions |
| `*_test.go` | Check for hardcoded real credentials, proper mock data |
| `internal/**/*.go` | Lower cross-repo risk (Go `internal/` packages are unexportable) |
| `pkg/**/*.go` | Higher cross-repo risk — exported packages consumed by other modules |
| `*reconciler*.go`, `*controller*.go` (K8s) | CRD reconciliation — namespace isolation, RBAC, webhook validation |
| `api/v1alpha*/*.go` | CRD type definitions — validation rules, default values, sensitive fields |
| `*_types.go` | K8s API types — check for secrets in spec, missing validation markers |

## Step 4: Apply Security Rules

For each changed file, check against the vulnerability categories below (and any repo-specific rules if loaded). Be specific — reference exact line numbers and code snippets.

### What to Look For

**Injection Flaws:**
- User input concatenated into HTML, JavaScript, SQL, LDAP, or OS commands
- SQL: use parameterized queries with bind parameters — never concatenate user input. Dynamic SQL for ORDER BY, LIMIT, or column names must use allowlist mapping
- HTML: all user-controlled values must be contextually encoded before rendering. `dangerouslySetInnerHTML` in React must be reviewed
- OS commands: pass user input as separate args — never shell-interpolate (e.g., never `sh -c "cmd " + userInput`)
- Unsafe deserialization — deserializing untrusted data without type filtering. Prefer JSON/XML over native serialization. Java: require `ObjectInputFilter` allowlist (JEP 290), audit gadget chain libraries. Go: validate decoded types
- JNDI injection (Java) — verify remote codebase loading is not re-enabled (`trustURLCodebase` must remain `false`), restrict `java.naming.factory.url.pkgs`
- XML parsers must disable external entities (XXE) — applies to all parser types (`DocumentBuilderFactory`, `SAXParser`, `XMLInputFactory`, `TransformerFactory`, `SchemaFactory`)

**Missing Validation:**
- New endpoint parameters without validation
- Redirect/callback URLs not checked against allowlist — require HTTPS scheme, validate hostname, redirect to safe default on failure
- File names/paths not sanitized — apply path canonicalization before use
- Request body size not limited before parsing — enforce max size on all endpoints accepting user input
- File uploads missing content-type validation (check actual bytes, not just headers), size limits, or filename sanitization
- JDBC URLs (Java) not checked for dangerous directives (H2 `INIT=`)

**SSRF (Server-Side Request Forgery):**
- Outbound HTTP requests to URLs derived from user input (webhooks, callback URLs, proxy endpoints)
- Must allowlist hosts, require HTTPS, resolve DNS and block internal/loopback/link-local IPs, disable redirect following, set explicit request timeout

**Auth & Access Control:**
- New endpoints missing authentication checks
- Authorization must check the TARGET RESOURCE, not just caller's role — prevents IDOR and cross-tenant escalation
- Sensitive operations (password change, MFA disable, role grant) must re-authenticate the user
- Secret comparisons (tokens, HMAC, API keys) must use constant-time functions — prevents timing side-channel attacks
- CSRF protection required on state-changing endpoints that use cookies — tokens + `SameSite` attribute on session cookies
- K8s controllers: CRD reconcilers must validate resource ownership and namespace scoping

**Insecure Defaults & Dev Bypasses:**
- Debug modes, permissive CORS, or auth-not-required defaults shipped to production
- Security-bypass flags or env vars that disable auth middleware or JWT signature verification in production
- Hardcoded default secret keys — secrets must be required with no default value
- Weak crypto: MD5/SHA-1 → SHA-256+, DES/3DES/RC4 → AES-256-GCM, RSA < 2048 → RSA 2048+ or ECDSA P-256+, ECB mode → GCM, plain hash for passwords → bcrypt/scrypt/Argon2
- Non-cryptographic PRNG used for security-sensitive values (tokens, nonces, keys) — must use cryptographic random source
- CORS: `AllowAllOrigins`/`*` combined with `AllowCredentials` is an insecure combination

**Tenant Isolation:**
- Cache keys without tenant domain/ID prefix
- Database queries without tenant/org ID filter
- Tenant context not validated at boundaries — thread-local (Java), `context.Context` (Go stdlib), `*gin.Context` (Gin)
- Gin-specific: `*gin.Context` values do NOT propagate to `c.Request.Context()` — pass org/tenant as explicit parameter to downstream functions
- Gin-specific: `*gin.Context` passed to a goroutine — Gin pools context objects, so a goroutine may read another request's tenant data. Extract all values BEFORE spawning goroutines
- Shared resources (caches, registries, queues) accessed without tenant scoping

**Goroutine Safety (Go only):**
- NEVER pass `*gin.Context` to a goroutine — extract all needed values first (tenant isolation vulnerability due to `sync.Pool` reuse)
- stdlib: pass `ctx context.Context` to goroutines, not the request object
- Use `errgroup.WithContext()` or `context.WithCancel()` for goroutine lifecycle — bare `go func()` calls leak goroutines on errors/timeouts

**Error Detail Leakage:**
- Error responses must not expose stack traces, internal package names, server versions, SQL errors, or file paths
- Panic/exception recovery must return generic 500 — log details server-side, never send to client
- Use identical messages and timing for "user not found" vs "wrong password" to prevent user enumeration

**Sensitive Data Exposure:**
- Tokens, passwords, or secrets passed as URL query parameters (logged in access logs, browser history, Referer headers)
- Sensitive data in GET request parameters instead of POST body or headers
- Logging of passwords, tokens, PII, or session identifiers

**TLS & Server Configuration:**
- No weak ciphers or weak cryptographic algorithms used (DES/3DES/MD5/RC4/DSS)
- All server timeouts set — read, write, idle, header timeouts. Missing timeouts enable Slowloris DoS
- `InsecureSkipVerify` / equivalent must not be `true`

**K8s Controller Security (APK, AI Gateway, OpenChoreo):**
- CRD reconcilers not validating resource ownership (missing `ownerReferences` or namespace checks)
- Webhook validation bypassed or missing for security-critical CRDs (`Authentication`, `BackendSecurityPolicy`, `AuthzRole`)
- Controller RBAC too broad — check `ClusterRole` for unnecessary `*` verbs or resources
- Secrets mounted as env vars instead of file volumes (env vars visible in `/proc`)

**ORM/DI Patterns (Agent Manager):**
- GORM `Raw()` or `Exec()` with string concatenation instead of parameterized queries
- DI-injected dependencies not scoped per-request (shared state across requests)
- Credential encryption at rest — verify AES-256-GCM usage, no ECB mode, proper key management

**Dependency Security:**
- New dependencies added without checking against known vulnerability databases
- Run vulnerability scanners before releases (`govulncheck`, OWASP Dependency Check, FindSecurityBugs)
- Check new dependencies for active maintenance and security response

## Step 5: Run Self-Review Checklist

After reviewing all files, explicitly answer each question. Fix any "no" before completing:

1. No user input reaches a response without context-appropriate encoding
2. No user input reaches SQL, LDAP, OS command, or XML parser without sanitization
3. Every new endpoint enforces both authentication AND authorization
4. Multi-tenant: cache keys, DB queries, and resource lookups scoped to tenant
5. File uploads restricted by type, size, name, and destination path
6. Error responses don't leak internals (stack traces, package names, file paths)
7. Redirect/callback URLs validated against allowlist
8. Config defaults secure (auth required, debug off, CORS restrictive, no bypass flags, no default keys)
9. Auth flow changes: tokens invalidated on account lock/disable/password change
10. No hardcoded secrets, credentials, or sensitive data in code
11. No logging of passwords, tokens, PII, or session identifiers
12. Outbound HTTP with user-supplied URLs has SSRF validation
13. `crypto/rand` used (not `math/rand`) for tokens, nonces, keys (Go); `SecureRandom` used (Java)
14. Secret comparisons use constant-time functions (`MessageDigest.isEqual()` for Java)
15. Gin: `*gin.Context` values extracted before goroutines (Go)

## Step 6: Produce Report

Format your findings as:

```markdown
## Security Review Summary

**Files reviewed:** [count]
**Focus area:** [all or specific]
**Risk level:** [Critical / High / Medium / Low / Clean]

### Must Fix (blocking)
Issues that represent critical security vulnerabilities and must be fixed before shipping.

- **[Category]** in `file:line` — [description]
  - **Impact:** [what an attacker could do]
  - **Fix:** [specific code change needed]

### Should Fix (important)
Issues that weaken security posture but may not be directly exploitable alone.

- **[Category]** in `file:line` — [description]
  - **Fix:** [specific code change needed]

### Consider
Best practice improvements and defense-in-depth suggestions.

- [description] in `file:line`

### Checklist Results
| # | Check | Status |
|---|-------|--------|
| 1 | Output encoding | Pass/Fail/N-A |
| ... | ... | ... |
| 15 | Goroutine safety (Go) | Pass/Fail/N-A |
```

If there are no findings, explicitly state the review is clean and which rules were checked. Do NOT skip the checklist even if everything looks good.
