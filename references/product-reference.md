# WSO2 Product & Engineering Reference

> Consolidated knowledge about WSO2 products, architecture, repos, and engineering practices.
> Use this as a reference when defining new skills, reviewing code, or analyzing changes.
>
> This file is generated and maintained using the `gov-update-product-reference` skill.

---

## Product Portfolio

WSO2 organizes products into five core platforms (API, Integration, Identity, Agent, Engineering) plus a programming language (Ballerina) and industry solutions.

### API Platform

| Product | Stack | Repo | Status | Key Security Concerns |
|---------|-------|------|--------|----------------------|
| API Manager (APIM) | Java/Carbon | `wso2/product-apim` | Active | Gateway security, rate limiting, API contract changes, key manager |
| APK | Go/K8s | `wso2/apk` | Active | Envoy ext_proc gateway, CRD-based auth, Redis-backed rate limiting |
| AI Gateway | Go/Envoy | `wso2/wso2-envoy-ai-gateway` | Active | LLM traffic control, backend credential injection, no prompt injection defense |
| API Platform | Go (Gin) | `wso2/api-platform` | Active | GitOps, multi-component monorepo, JWT auth |
| Microgateway (Choreo Connect) | Java | `wso2/product-microgateway` | Active (superseded by APK) | Lightweight gateway security |

### Integration Platform

| Product | Stack | Repo | Status | Key Security Concerns |
|---------|-------|------|--------|----------------------|
| Micro Integrator (MI) | Java/Carbon | `wso2/product-micro-integrator` | Active | Script mediator sandboxing, connector security |
| Integrator | TypeScript | `wso2/product-integrator` | Active | Low-code integration, 400+ connectors |
| Ballerina Integrator | Ballerina | `wso2/product-ballerina-integrator` | Active | Ballerina-based integration |
| WebSubHub | Ballerina | `wso2/product-integrator-websubhub` | Active | Event-driven pub/sub |

### Identity Platform

| Product | Stack | Repo | Status | Key Security Concerns |
|---------|-------|------|--------|----------------------|
| Identity Server (IS) | Java/Carbon | `wso2/product-is` | Active | Auth flows, tenant isolation, token lifecycle, adaptive auth |
| Asgardeo | SaaS | N/A | Active | Cloud CIAM |
| Asgardeo Thunder | Go (stdlib) | `asgardeo/thunder` | Active | OAuth2/OIDC, org isolation, JWT validation |
| Identity Customer Data Service | Go | `wso2/identity-customer-data-service` | Active | Customer data profiles |

### Agent Platform

| Product | Stack | Repo | Status | Key Security Concerns |
|---------|-------|------|--------|----------------------|
| Agent Manager | Go (stdlib) | `wso2/agent-manager` | Active | AI agent governance, LLM credential encryption, gateway token management |

### Engineering Platform

| Product | Stack | Repo | Status | Key Security Concerns |
|---------|-------|------|--------|----------------------|
| Choreo | SaaS | N/A | Active | iPaaS, CI/CD, observability |
| OpenChoreo | Go/K8s | `openchoreo/openchoreo` | Active | Open-source IDP, Casbin RBAC, multi-cluster isolation |

### Programming Language

| Product | Stack | Repo | Status | Key Security Concerns |
|---------|-------|------|--------|----------------------|
| Ballerina | Java (compiler) | `ballerina-platform/ballerina-lang` | Active | Language-level security constructs |

### Industry Solutions

| Product | Stack | Repo | Status | Key Security Concerns |
|---------|-------|------|--------|----------------------|
| Open Banking | Java/Carbon (accelerator on APIM + IS) | `wso2-extensions/open-banking-apim` | Active | FAPI compliance, consent management |

### Legacy / Superseded (not archived but effectively replaced)

| Product | Replaced By |
|---------|------------|
| Enterprise Integrator (EI) | Micro Integrator / Integrator |
| Streaming Integrator | Integrated into Integrator |
| Stream Processor (SP) | Streaming Integrator → Integrator |
| IoT Server | Discontinued |
| Governance Registry (GREG) | API governance in APIM |
| Application Server (AS) | Discontinued |

### Stack Summary

| Stack | Products | HTTP Framework | Context Pattern |
|-------|----------|---------------|----------------|
| **Java/Carbon** | IS, APIM, MI, Open Banking | Servlet/OSGi | `PrivilegedCarbonContext` thread-local |
| **Go (stdlib)** | Thunder | `net/http` + `http.NewServeMux` | `context.Context` via `context.WithValue` |
| **Go (Gin)** | API Platform | `gin-gonic/gin` | `*gin.Context` via `c.Set()`/`c.Get()` |
| **Go (stdlib)** | Agent Manager, OpenChoreo | `net/http` + `oapi-codegen` | `context.Context` (similar to Thunder) |
| **Go (Gin + gRPC/K8s)** | APK | Gin (HTTP APIs) + gRPC (`go-control-plane` xDS) + `controller-runtime` | K8s CRDs + Envoy xDS |
| **Go (gRPC/K8s)** | AI Gateway | gRPC + `controller-runtime` (no HTTP framework) | K8s CRDs + Envoy xDS |
| **TypeScript** | Integrator | Varies | N/A (not covered by current skills) |
| **Ballerina** | Ballerina Integrator, WebSubHub | Ballerina HTTP | N/A (not covered by current skills) |
| **SaaS** | Asgardeo, Choreo | N/A | N/A (no source code) |

### GitHub Organizations

| Organization | Purpose | Repo Count |
|-------------|---------|-----------|
| `wso2` | Core products and frameworks | Major products |
| `wso2-extensions` | Connectors, authenticators, extensions | 424+ repos |
| `asgardeo` | Asgardeo-related products (Thunder, SDKs) | Asgardeo ecosystem |
| `ballerina-platform` | Ballerina language and tooling | Language ecosystem |
| `openchoreo` | Open-source Choreo | IDP |

---

## Architecture: Java/Carbon Stack

### Build System
- **Maven** multi-module repos (e.g., `carbon-identity-framework` has 80+ modules)
- **OSGi bundles** with explicit `Export-Package` / `Import-Package`
- **Component → Feature → Product** assembly chain (P2 features)

### Repo Structure & Dependencies

> This is not a complete list — each product pulls in 50+ repos. These are the key repos an engineer needs to understand the dependency structure.

Dependency flows upward — products depend on extensions and frontends, which depend on frameworks, which depend on the kernel:

```
Product Layer
  product-is                        (Identity Server product assembly)
  product-apim                      (API Manager product assembly)
  product-micro-integrator          (Micro Integrator product assembly)
    ↓ depends on
Frontend & API Layer
  identity-apps                     (IS Console + My Account — TypeScript)
  apim-apps                         (APIM Publisher + DevPortal + Admin — JavaScript)
  identity-api-server               (IS REST APIs)
  identity-api-user                 (IS user self-service APIs)
    ↓ depends on
Extension Layer (wso2-extensions org — 143+ identity repos)
  identity-inbound-auth-oauth       (OAuth/OIDC)
  identity-inbound-auth-saml        (SAML)
  identity-governance               (password policy, account management)
  identity-conditional-auth-*       (adaptive auth scripts)
  identity-outbound-auth-*          (federated auth — Google, TOTP, etc.)
  identity-local-auth-*             (FIDO, magic link, etc.)
  apim-km-*                         (key manager connectors — Okta, Keycloak, etc.)
    ↓ depends on
Framework Layer
  carbon-identity-framework         (80+ modules — shared by IS, APIM, MI)
  carbon-apimgt                     (APIM backend — gateway, throttling, APIs)
  carbon-mediation                  (MI mediation engine — Synapse mediators, transports)
  carbon-consent-management         (consent management — shared)
    ↓ depends on
Foundation Layer
  carbon-kernel                     (core runtime — OSGi, classloading, bootstrap)
  carbon-commons                    (shared utilities, logging, NTASK)
  carbon-registry                   (artifact/governance registry)
  carbon-multitenancy               (multi-tenant support)
  carbon-data                       (data services, RDBMS connectivity)
  carbon-deployment                 (webapp/artifact deployment)
```

#### Key Repos by Product

| Product | Product Repo | Backend Framework | Frontend | Tooling |
|---------|-------------|-------------------|----------|---------|
| Identity Server | `wso2/product-is` | `carbon-identity-framework` | `wso2/identity-apps` | — |
| API Manager | `wso2/product-apim` | `carbon-apimgt` | `wso2/apim-apps` | `product-apim-tooling` (Go) |
| Micro Integrator | `wso2/product-micro-integrator` | `carbon-mediation` | — | `product-mi-tooling` |

| Repo Type | Organization | Dependency Impact |
|-----------|-------------|------------------|
| Foundation repos | `wso2/carbon-kernel`, `carbon-commons`, etc. | Changes affect ALL products |
| Framework repos | `wso2/carbon-identity-framework`, `carbon-apimgt`, `carbon-mediation` | Changes affect products using that framework |
| Extension repos | `wso2-extensions/identity-*`, `apim-km-*` | Changes affect products that include the extension |
| Product repos | `wso2/product-*` | Self-contained assembly |
| Frontend repos | `wso2/identity-apps`, `wso2/apim-apps` | UI — may affect multiple products |

### Key Patterns
- **Tenant context:** `PrivilegedCarbonContext` thread-local with `startTenantFlow()` / `endTenantFlow()` in try/finally
- **Config:** `deployment.toml` (all passwords in plaintext unless Secure Vault configured)
- **DB access:** PreparedStatement with `?` placeholders, tenant tables have `TENANT_ID` column
- **Auth:** Servlet filters, OSGi service `@Component` annotations, SOAP admin service auth
- **Caching:** `javax.cache` / Carbon caching with tenant-scoped keys
- **Sensitive files:** `deployment.toml`, `master-keys.yaml`, `cipher-text.properties`, `*.jks`/`*.p12` keystores
- **Supported databases:** MySQL, PostgreSQL, Oracle, MSSQL, H2 — migration scripts needed for all

### Common WSO2 Tables Requiring Tenant Filters
`IDN_OAUTH2_ACCESS_TOKEN`, `IDN_OAUTH_CONSUMER_APPS`, `SP_APP`, `UM_USER`, `UM_ROLE`, `REG_RESOURCE`, `IDN_IDENTITY_USER_DATA`

---

## Architecture: Go Stack

### Thunder (stdlib `net/http`)

**Framework:** Go stdlib — `http.NewServeMux` (Go 1.22+ enhanced patterns like `"POST /users"`)

**Directory layout:**
```
backend/
  cmd/server/         -- Entry point
  internal/           -- All domain packages (unexportable)
    application/      -- App management
    authn/            -- Authentication (basic, social, OTP, passkey, OAuth)
    authz/            -- Authorization engine
    flow/             -- Identity flow engine
    oauth/            -- OAuth2 server
    ou/               -- Organization unit (tenant) management
    user/             -- User management
    system/           -- Cross-cutting concerns:
      cache/          -- Custom generic Cache[T] with LRU/LFU
      config/         -- YAML + JSON config, env var substitution
      context/        -- Correlation ID via context.Context
      crypto/         -- PKI, hashing, encryption
      database/       -- DB client, transactions via context
      error/          -- Structured serviceerror types
      http/           -- HTTP client + TLS
      jose/           -- JWT signing/verification
      log/            -- Structured logging + access log middleware
      middleware/     -- Correlation ID, CORS
      security/       -- Auth middleware, SecurityContext, permissions
  dbscripts/          -- Migration scripts
api/                  -- OpenAPI specs
frontend/             -- UI apps
```

**Key patterns:**
- **Auth middleware:** Single `securityService.Process(r)` wrapping the mux. Public paths defined as regex patterns.
- **Tenant context:** Immutable `SecurityContext` struct in `context.Context` via private key. Accessor functions: `security.GetSubject(ctx)`, `security.GetOUID(ctx)`, `security.GetPermissions(ctx)`. Returns defensive copies for slices/maps.
- **Config:** YAML (`deployment.yaml`) + JSON defaults, custom loader with env var substitution. No Viper.
- **DB access:** Raw SQL with `$1, $2` positional params. `[]map[string]interface{}` results. No ORM. PostgreSQL (`lib/pq`) + SQLite (`modernc.org/sqlite`). Three separate databases: config, runtime, user.
- **Transactions:** `Transactioner.Transact(ctx, func(ctx) error)` pattern, transaction stored in context, nesting detection.
- **Cache:** Custom in-memory `Cache[T]` with Go generics, LRU/LFU eviction, configurable TTL/size per cache. No Redis.
- **Error handling:** `serviceerror.ServiceError` with codes. Buffer-before-write pattern — encode response to buffer first, only send headers if encoding succeeds.
- **Input validation:** Manual — no struct tag validation library. `utils.SanitizeString()` for HTML escaping + control character stripping.
- **Permissions:** Hierarchical scope-based — `"system"` is root, prefix matching (`"system:ou"` satisfies `"system:ou:view"`).
- **TLS:** TLS 1.3 default. `ReadHeaderTimeout: 10s` (Slowloris protection).
- **Security bypass:** Dev-only security bypass flag (disabled in production, logged with warnings when active).
- **JWT:** `golang-jwt/jwt/v5` with internal JOSE service for signing/verification.

**Key dependencies:** `lib/pq`, `modernc.org/sqlite`, `gopkg.in/yaml.v3`, `golang-jwt/jwt/v5`, `go-webauthn/webauthn`, `testify`, `go-sqlmock`, `opentelemetry`

### API Platform (Gin framework)

**Framework:** Gin (`github.com/gin-gonic/gin`) — all Go services

**Directory layout (go.work monorepo):**
```
platform-api/         -- Central control plane API
  src/internal/
    handler/          -- HTTP handlers
    service/          -- Business logic
    repository/       -- Data access
    middleware/       -- Auth, correlation ID
    database/         -- DB client
common/               -- Shared library (auth, models, constants)
  authenticators/     -- Pluggable auth (Basic, JWT+JWKS)
gateway/
  gateway-controller/ -- Gateway control plane (xDS for Envoy)
  gateway-builder/    -- Custom gateway image builder
  gateway-runtime/    -- Policy engine (Go plugins)
cli/                  -- CLI tool
sdk/                  -- Go SDK
portals/              -- UI portals
distribution/         -- Docker Compose deployment
```

**Key patterns:**
- **Auth middleware (platform-api):** JWT-based `gin.HandlerFunc`. Parses Bearer token, extracts custom claims (`organization`, `username`, `email`, `scope`). Claims stored via `c.Set("organization", ...)`.
- **Auth middleware (common module):** More mature — pluggable `Authenticator` interface (`CanHandle()`, `Authenticate()`, `Name()`). Supports Basic Auth + JWT with JWKS rotation (`MicahParks/jwkset` + `keyfunc/v3`). `AuthContext` struct in context via `constants.AuthContextKey`. Separate `AuthorizationMiddleware` with resource-to-role mappings.
- **Tenant context:** Organization from JWT claims → `c.Set("organization", claims.Organization)`. Retrieved via `middleware.GetOrganizationFromContext(c)`. Uses `gin.Context` key-value store — NOT stdlib `context.Context`. **Critical:** Gin context values do NOT propagate to `c.Request.Context()`.
- **Config (platform-api):** `kelseyhightower/envconfig` — all config via env vars with struct tags. No config files.
- **Config (gateway-controller):** `knadh/koanf` — TOML files + env var overrides (prefix `APIP_GW_`).
- **DB access:** Raw SQL with `?` placeholders + custom `db.Rebind()` for PostgreSQL conversion. Repository pattern with interfaces. SQLite3 (`mattn/go-sqlite3`) + PostgreSQL (`pgx/v5`).
- **Input validation:** Gin's built-in `go-playground/validator/v10` struct tags (`binding:"required"`). `c.ShouldBindJSON(&req)` for parsing. Plus manual validation. Also uses `oapi-codegen` for generated API types from OpenAPI specs.
- **Error handling:** Centralized `utils/error_mapper.go` — maps ~40+ domain errors to HTTP status codes via `errors.Is()`. Structured `ErrorResponse{Code, Message, Description}`. Panic recovery middleware returns generic 500.
- **File uploads:** `c.Request.ParseMultipartForm(10 << 20)` — 10 MB max. `c.Request.FormFile("definition")` for OpenAPI definitions.
- **CORS:** `gin-contrib/cors` middleware.

**Key dependencies:** `gin-gonic/gin`, `golang-jwt/jwt/v5`, `MicahParks/jwkset`, `keyfunc/v3`, `mattn/go-sqlite3`, `jackc/pgx/v5`, `kelseyhightower/envconfig`, `knadh/koanf`, `go-playground/validator/v10`, `oapi-codegen/runtime`, `gorilla/websocket`, `gin-contrib/cors`

### APK (Envoy-based K8s API Management)

**Framework:** Go with gRPC (`go-control-plane` xDS) + Gin (`gin-gonic/gin`) for HTTP APIs. Kubernetes controller-runtime for CRD reconciliation.

**Architecture:** Control plane + data plane model with Envoy Gateway as the proxy.

```
Control Plane
  common-controller (Go/Gin)   -- Subscriptions, rate-limit policies, PostgreSQL persistence
  runtime (Java)                -- Domain services
    ↓ gRPC/xDS
Data Plane
  adapter (Go)                  -- K8s operator, watches CRDs, generates xDS config for Envoy
  Envoy Gateway (router/proxy)  -- Traffic proxy, delegates to enforcer via ext_proc
  enforcer (Go/Gin)             -- JWT validation, rate limiting (Redis), API mediation
```

**Directory layout:**
```
adapter/              -- K8s operator + xDS server (controller-runtime)
common-controller/    -- Shared control plane (Gin HTTP, PostgreSQL)
common-go-libs/       -- CRD types (dp/v1alpha1-4, cp/v1alpha2-3), shared utils
gateway/enforcer/     -- Envoy ext_proc filter (Gin HTTP, Redis)
envoy-gateway-extension-server/ -- Envoy Gateway xDS hooks
runtime/              -- Java domain services
helm-charts/          -- K8s deployment
database/postgres/    -- Schema migrations
```

**Key patterns:**
- **Config (common-controller):** TOML-based (`pelletier/go-toml`) with hardcoded defaults in `default_config.go`.
- **Config (enforcer):** Env var-based (`kelseyhightower/envconfig`) with struct tags.
- **DB access:** PostgreSQL via `pgx/v5` with connection pooling (`pgxpool`). DAO pattern — all functions receive `pgx.Tx`, caller manages transactions. `retryUntilTransaction()` for reconnection.
- **Auth:** JWT via `lestrrat-go/jwx/v2` (adapter) and `golang-jwt/jwt/v5` (enforcer). CRD-based auth policy (`Authentication` CRD) supports OAuth2, API Key, and Test Console Key.
- **Token revocation:** Enforcer checks JTI against `revokedJTIStore` (Redis-backed) before processing.
- **K8s CRDs:** `API`, `APIPolicy`, `Authentication`, `Backend`, `BackendJWT`, `RateLimitPolicy`, `Scope`, `TokenIssuer`, `Subscription`.

**Key dependencies:** `envoyproxy/go-control-plane`, `envoyproxy/gateway`, `sigs.k8s.io/controller-runtime`, `sigs.k8s.io/gateway-api`, `gin-gonic/gin`, `jackc/pgx/v5`, `redis/go-redis/v9`, `lestrrat-go/jwx/v2`, `golang-jwt/jwt/v5`, `sirupsen/logrus`, `go.uber.org/zap`

### AI Gateway (Envoy ext_proc for LLMs)

**Framework:** Pure gRPC — no HTTP framework. Kubernetes controller-runtime for CRD management.

> Note: This repo is a fork of `envoyproxy/ai-gateway`. The Go module path is `github.com/envoyproxy/ai-gateway`.

**Architecture:** Envoy External Processing filter model — not a sidecar, not a standalone proxy.

```
Client → Envoy Gateway → ext_proc filter (gRPC, port 1063) → extproc service
              |                                                    |
              v                                                    v
        HTTPRoute rules                              Translate + Route + Auth
              |                                                    |
              v                                                    v
        Backend (LLM provider: OpenAI / AWS Bedrock / Azure OpenAI)
```

**Two binaries:**
- **controller** — Watches K8s CRDs (`AIGatewayRoute`, `AIServiceBackend`, `BackendSecurityPolicy`), generates HTTPRoutes + EnvoyExtensionPolicy + ConfigMaps for ext_proc pods.
- **extproc** — gRPC server implementing Envoy ext_proc. Parses request body for model name, routes to backend, translates protocol (OpenAI→Bedrock/Azure), injects auth credentials.

**Directory layout:**
```
api/v1alpha1/           -- CRD type definitions
cmd/controller/         -- K8s controller binary
cmd/extproc/            -- External processor binary
internal/controller/    -- Reconcilers, credential rotation, token providers
internal/extensionserver/ -- Envoy Gateway xDS hooks
internal/extproc/       -- Core processor, translators, router
  backendauth/          -- API Key, AWS SigV4, Azure AD handlers
  translator/           -- OpenAI↔Bedrock/Azure protocol translation
  router/               -- Header-match + weighted random backend selection
internal/llmcostcel/    -- CEL-based token cost calculation
manifests/              -- Helm charts
```

**Key patterns:**
- **Backend auth:** Three types — API Key (file-mounted K8s Secret), AWS SigV4 (OIDC token exchange for role assumption), Azure AD (client credentials).
- **Config:** YAML-based filter config in ConfigMaps, hot-reloaded via 5-second file polling.
- **Protocol translation:** OpenAI input format translated to OpenAI, AWS Bedrock, or Azure OpenAI output format.
- **Cost tracking:** Extracts token usage (input/output/total) from LLM responses, exposes as Envoy dynamic metadata. CEL expressions for custom cost calculation.
- **No built-in rate limiting** — computes token costs but delegates enforcement to external systems (Envoy native rate limiting).

**Key dependencies:** `google.golang.org/grpc`, `sigs.k8s.io/controller-runtime`, `sigs.k8s.io/gateway-api`, `envoyproxy/go-control-plane`, `envoyproxy/gateway`, `openai/openai-go`, `google/cel-go`, `aws/aws-sdk-go-v2`, `Azure/azure-sdk-for-go`, `coreos/go-oidc`

### Agent Manager (AI Agent Governance)

**Framework:** Go stdlib `net/http` — no third-party router. `oapi-codegen` for generated API handlers. Google Wire for dependency injection.

**Architecture:** Enterprise AI agent control plane — manages, deploys, and governs AI agents. Not an agent runtime.

```
Main API Server (port 9000)           -- HTTP, console/API requests
Internal HTTPS Server (port 9243)     -- WebSocket (gateway comms), self-signed TLS
Traces Observer Service               -- OpenSearch trace querying
Console                               -- React 19 + TypeScript web UI
```

**Directory layout:**
```
agent-manager-service/    -- Go backend (main service)
  controllers/            -- HTTP handlers (23 files)
  services/               -- Business logic (31 files)
  repositories/           -- Data access layer
  models/                 -- Domain models (30 files)
  middleware/             -- Auth (JWT), CORS, logging, panic recovery
  clients/               -- External service clients (OpenChoreo, Git, Vault, etc.)
  config/                -- Env var-based config
  wiring/                -- Google Wire DI
  websocket/             -- WebSocket connection management
  spec/                  -- Generated OpenAPI client (238 files)
  db_migrations/         -- gormigrate migrations
traces-observer-service/  -- Go service for OpenSearch traces
console/                  -- React 19 + TypeScript (Rush monorepo)
evaluation-job/           -- Python evaluation SDK
samples/                  -- Example agents
deployments/              -- Helm charts, docker-compose
```

**Key patterns:**
- **Auth:** JWT middleware with two modes — full JWKS signature verification OR claims-only extraction (for default issuer). JWKS key caching with 1-hour TTL.
- **Credential management:** AES-256-GCM encryption for secrets at rest. Optional OpenBao/Vault integration via pluggable `Provider` interface.
- **Gateway tokens:** Hashed with salt, first 8 chars stored as prefix for indexed lookup, never exposed in JSON.
- **Multi-tenancy:** Organization-scoped (org UUID as primary tenant boundary). Orgs synced from OpenChoreo.
- **Config:** Env var-based (`joho/godotenv`) with structured config structs.
- **DB access:** GORM ORM (`gorm.io/gorm`) with PostgreSQL. gormigrate for migrations.
- **DI:** Google Wire with compile-time code generation. 23+ service providers, 15+ controller providers.

**Key dependencies:** `gorm.io/gorm`, `jackc/pgx/v5`, `google/wire`, `golang-jwt/jwt/v5`, `gorilla/websocket`, `hashicorp/vault/api`, `oapi-codegen/runtime`, `go-gormigrate/gormigrate/v2`, `opensearch-project/opensearch-go`

### OpenChoreo (Open-Source Internal Developer Platform)

**Framework:** Go stdlib `net/http` with `oapi-codegen` for generated API handlers. Kubernetes controller-runtime for CRD reconciliation. Casbin for RBAC.

**Architecture:** Multi-cluster IDP with control plane + data plane separation.

```
Control Plane (K8s cluster)
  Controller Manager      -- Reconciles 25 CRDs
  OpenChoreo API Server   -- REST API (generated from OpenAPI specs)
  Cluster Gateway         -- WebSocket proxy to data planes
  Observer                -- Observability (OpenSearch + Prometheus)

Data Plane(s) (separate K8s clusters)
  Cluster Agent           -- Connects to control plane via WebSocket
  Workloads               -- User applications
  Cilium                  -- Network policies (eBPF, mTLS)
```

**Directory layout:**
```
api/v1alpha1/       -- CRD type definitions (31 files, 28 CRDs)
cmd/                -- 5 services + root controller manager
  openchoreo-api/   -- REST API server
  cluster-agent/    -- Data plane agent
  cluster-gateway/  -- WebSocket gateway
  observer/         -- Observability service
  occ/              -- CLI tool
internal/           -- 25 packages
  authz/            -- Casbin RBAC (PAP + PDP)
  controller/       -- 25 reconcilers
  server/           -- HTTP server + middleware (auth JWT, audit, MCP)
  dataplane/        -- Data plane management
  networkpolicy/    -- Cilium network policies
  clone/            -- Git operations
pkg/                -- Shared libraries (cli, mcp, observability)
openapi/            -- OpenAPI specs (openchoreo-api.yaml, observer-api.yaml)
rca-agent/          -- Python Root Cause Analysis agent (FastAPI)
```

**Key patterns:**
- **Auth:** JWT-based middleware. OAuth 2.0 metadata endpoint (RFC 9728). Subjects from JWT claims as `EntitlementClaim`.
- **Authorization:** Casbin v2 RBAC with hierarchical resource matching. Policies stored as K8s CRDs (`AuthzRole`, `AuthzRoleBinding`). Synced via K8s informer watchers.
- **Multi-tenancy:** Namespace-based isolation — K8s namespace = tenant boundary. All API paths prefixed with `/api/v1/namespaces/{namespaceName}/...`. Cell-based networking model (northbound/southbound/westbound/eastbound).
- **Config:** koanf v2 — file + env vars + struct defaults.
- **DB access:** PostgreSQL (`pgx/v5`) + SQLite (`modernc.org/sqlite`).
- **K8s CRDs (28 total):** Platform resources (DataPlane, Environment, DeploymentPipeline), application resources (Project, Component, ComponentRelease, Workflow), authz resources (AuthzRole, AuthzRoleBinding).
- **MCP integration:** Optional Model Context Protocol endpoints for AI tool interaction.

**Key dependencies:** `sigs.k8s.io/controller-runtime`, `casbin/casbin/v2`, `golang-jwt/jwt/v5`, `jackc/pgx/v5`, `modernc.org/sqlite`, `knadh/koanf/v2`, `oapi-codegen/runtime`, `google/cel-go`, `gorilla/websocket`, `modelcontextprotocol/go-sdk`, `opensearch-project/opensearch-go`, `prometheus/client_golang`

---

## Critical Differences: stdlib vs Gin

These are the most important architectural differences that affect security analysis. **Never mix patterns across frameworks.**

| Aspect | stdlib `net/http` (Thunder) | Gin (API Platform) |
|--------|---------------------------|-------------------|
| **Handler signature** | `func(w http.ResponseWriter, r *http.Request)` | `func(c *gin.Context)` |
| **Request context** | `r.Context()` returns `context.Context` | `c` is `*gin.Context` (separate from `c.Request.Context()`) |
| **Tenant in context** | `context.WithValue()` + typed accessor functions | `c.Set(key, value)` + `c.Get(key)` / `c.GetString(key)` |
| **Context to downstream** | Pass `ctx` (carries tenant info) | Must explicitly extract values — `c.Request.Context()` does NOT contain `c.Set()` values |
| **Goroutine safety** | Pass `ctx context.Context` to goroutine | Extract values first, NEVER pass `*gin.Context` (Gin reuses context objects across requests) |
| **Middleware pattern** | `func(http.Handler) http.Handler` wrapping | `gin.HandlerFunc` registered via `router.Use()` or `group.Use()` |
| **Route registration** | `mux.HandleFunc("POST /path", handler)` | `router.POST("/path", handler)` or `group.POST("/path", handler)` |
| **Input binding** | `json.NewDecoder(r.Body).Decode(&v)` + manual validation | `c.ShouldBindJSON(&v)` with `binding:"required"` struct tags |
| **Path params** | `r.PathValue("id")` (Go 1.22+) | `c.Param("id")` |
| **Query params** | `r.URL.Query().Get("key")` | `c.Query("key")` |
| **Response writing** | `w.Header().Set()` + `w.WriteHeader()` + `json.NewEncoder(w).Encode()` | `c.JSON(status, obj)` |

---

## Production Hardening

For production deployment guidelines, refer to the official WSO2 security documentation:
https://security.docs.wso2.com/en/latest/security-guidelines/security-guidelines-for-production-deployment/

This covers product-specific hardening for each WSO2 product version. Always consult the latest version for your product.
