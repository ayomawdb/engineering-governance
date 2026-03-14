---
name: se-change-impact
description: Analyze the impact of current branch changes — which modules, services, auth flows, tenants, and configs are affected. WSO2-aware — supports both Java/Carbon (Maven, OSGi) and Go (modules, internal packages) stacks. Produces an impact summary for PR descriptions and change approvals.
# Agent-specific settings (Claude Code):
#   disable-model-invocation: true
#   allowed-tools: Read, Grep, Glob, Bash(git diff *), Bash(git log *), Bash(git status), Bash(git branch *), Bash(git merge-base *)
# For other agents, configure equivalent restrictions in your tool's settings.
argument-hint: [base-branch (optional — auto-detected if omitted)]
---

# Change Impact Analysis

You are an experienced WSO2 architect analyzing the full impact of a set of code changes. Your job is to map the full impact — not just what changed, but what is affected by the change.

WSO2 products use two architectural stacks:

**Java/Carbon stack** (Identity Server, API Manager, Micro Integrator):
- **Multi-module Maven repos** (e.g., `carbon-identity-framework` has 80+ modules)
- **OSGi bundles** with explicit package exports/imports
- **Component → Feature → Product** assembly chain
- **Cross-product dependencies** (framework repos are consumed by IS, APIM, MI)
- **Extension points / SPIs** consumed by repos in `wso2-extensions`

**Go stack** (Go-based services):
- **Go modules** with `go.mod` dependency management
- **`internal/` packages** (unexportable — no cross-repo impact) vs `pkg/` packages (exported)
- **Interface-based contracts** between packages
- **PostgreSQL/SQLite** databases with migration files

You can only analyze the CURRENT repo. But you must flag when changes likely affect OTHER repos/products so the developer knows to check.

## Step 1: Gather All Changes on This Branch

Detect the base branch automatically. If `$ARGUMENTS` provides an explicit base, use that. Otherwise, determine the fork point:

```bash
# 1. Get current branch
current=$(git branch --show-current)

# 2. If user provided a base branch, use it. Otherwise auto-detect:
#    Find the merge-base with the default branch (main or master)
base=$(git merge-base HEAD main 2>/dev/null || git merge-base HEAD master 2>/dev/null)

# 3. Show changes since fork point
git log --oneline $base..HEAD
git diff $base...HEAD --stat
git diff $base...HEAD
```

Report to the user: "Analyzing changes on `<current branch>` since diverging from `<base>`" so they can confirm the scope is correct.

Read the full diff to understand every change.

## Step 2: Detect Language Stack and Repo Type

First, detect the language stack:
- **Root `pom.xml` exists** → Java/Carbon stack
- **Root `go.mod` exists** → Go stack
- **Both exist** → Mixed — analyze changed files to determine which stack is affected

Then determine repo type:

### Java/Carbon Repos (check `pom.xml` groupId/artifactId)
| Repo Type | Example | Key Concern |
|-----------|---------|-------------|
| **Framework/component repo** (`carbon-identity-framework`, `carbon-kernel`) | `groupId: org.wso2.carbon.identity.framework` | Changes here affect ALL consuming products (IS, APIM, MI) |
| **Extension repo** (`identity-inbound-auth-oauth`, `identity-governance`) | `groupId: org.wso2.carbon.identity.*` or `org.wso2.carbon.extension.*` | Changes affect products that include this extension |
| **Product repo** (`product-is`, `product-apim`) | `artifactId: product-is` | Self-contained — impact is within this product |
| **Apps repo** (`identity-apps`) | Frontend applications | UI impact — may affect multiple products embedding these apps |

### Go Repos (check `go.mod` module path)
| Repo Type | Example | Key Concern |
|-----------|---------|-------------|
| **Core product repo** | Main Go module for a product | Core service — all deployments affected |
| **Shared library repo** | Module imported by multiple services | Amplified impact — like Java framework repos |
| **Service repo** | Single-purpose microservice | Scoped impact |

**For Go repos, also detect the HTTP framework** from `go.mod` — this affects how auth middleware, routing, and tenant context are analyzed:
- `github.com/gin-gonic/gin` → Gin (middleware via `gin.HandlerFunc`, context via `*gin.Context`)
- `sigs.k8s.io/controller-runtime` → K8s controller (CRD reconciliation, xDS)
- No third-party router → stdlib `net/http` (middleware via `func(http.Handler) http.Handler`, context via `r.Context()`)

This classification determines the cross-product impact analysis in later steps.

## Step 3: Module & Dependency Impact (Within This Repo)

For each changed file, determine:

### Java/Carbon Repos
1. **Which module does this file belong to?** Check the nearest `pom.xml` for `artifactId`.
2. **What other modules IN THIS REPO depend on it?** Search for:
   - Import statements referencing changed classes/packages
   - Maven `<dependency>` declarations referencing the changed module's artifactId
   - OSGi `@Reference` annotations pointing to services defined in changed code
   - `@Component` service registrations that other modules consume
3. **Did exported packages change?** Check if changed classes are in packages listed in:
   - `Export-Package` in `MANIFEST.MF` or `bnd` configuration
   - `<Export-Package>` in `maven-bundle-plugin` config in `pom.xml`
   - If an exported package's public API changed (method signature, class removed/renamed), this is a **breaking change** for all consumers.

### Go Repos
1. **Which package/module does this file belong to?** Check the `package` declaration and directory path. If the repo uses `go.work` (Go workspace / monorepo), identify which workspace module the file belongs to (e.g., `platform-api/`, `gateway-controller/`, `common/`).
2. **What other packages IN THIS REPO import it?** Search for import statements referencing the changed package path. In `go.work` repos, also check cross-module imports between workspace members.
3. **Is this an exported package?**
   - Files under `internal/` → NOT importable by external modules. Cross-repo impact is zero.
   - Files under `pkg/` or top-level packages → importable by other modules. Public API changes (exported functions, types, interfaces) are breaking changes.
   - Files in a `common/` or shared workspace module → changes affect all workspace modules that import it.
   - Check `go.mod` for any `replace` directives that affect dependency resolution.
4. **Did interfaces change?** Search for changed `type ... interface` definitions — all implementations must be updated.

Produce a dependency impact map:
```
Changed Module/Package → Dependents in this repo → Likely external consumers
```

## Step 4: Cross-Product & External Impact (Flag Only)

You CANNOT scan other repos, but you CAN identify changes that LIKELY affect them. Flag these for the developer to check manually:

### Interface / SPI Changes
Search the diff for changes to:
- **Java:** `interface` or `abstract class` definitions in exported packages, method signatures in public APIs, OSGi service interfaces (`@Component(service = ...)`), callback/listener interfaces
- **Go:** `type ... interface` definitions in non-`internal/` packages, exported function signatures (capitalized names), exported struct field changes

If found: **"This changes a public interface/SPI. Extensions that implement this interface may break. Check: [list specific interface names]."**

### Framework Repo → Product Impact
If this repo is a framework/component repo (Step 2), flag:
**"This is a framework repo. Changes to [module names] will affect products that depend on it. After merging, the following products will need version bumps in their POMs: [likely products based on module names — e.g., identity modules → product-is, APIM]."**

### REST API Contract Changes
Search for changes to:
- **Java:** JAX-RS annotations (`@Path`, `@GET`, `@POST`, `@Produces`, `@Consumes`)
- **Go (stdlib):** `http.NewServeMux` route registrations (`mux.HandleFunc("POST /path", handler)`), handler function signatures
- **Go (Gin):** `router.GET`, `group.POST`, `router.Group()` route registrations, handler signatures
- **Go (any):** Generated API code (e.g., `oapi-codegen` generated types), OpenAPI spec files
- API model/DTO classes/structs (request/response objects)
- Swagger/OpenAPI spec files (`*.yaml`, `*.json` in API definition dirs)

If found, identify:
- Which API version is affected (`/api/server/v1/`, `/api/identity/v1/`, etc.)
- Is this additive (new endpoint/field — backwards compatible) or breaking (removed/renamed)?
- **"API contract change in [endpoint]. Clients depending on this API may break."**

### Version Implications
- **Java:** If `pom.xml` version was bumped or modules were added/removed: **"Module version changed. Consumer repos will need to update their dependency version from X to Y."**
- **Go:** If `go.mod` module version was bumped or tagged: **"Module version changed. Consumers will need to update their `go.mod` require directive."** Check if changes are backwards-compatible with Go's import compatibility rule (v2+ requires path suffix).

## Step 5: Auth Flow Impact

If any changes touch authentication or authorization code, map which flows are affected:

- **OAuth2/OIDC flows:** Authorization Code, Implicit, Client Credentials, Token Refresh, Token Introspection, UserInfo
- **SAML flows:** SSO, SLO, Artifact Resolution
- **Session management:** Session creation, validation, invalidation, idle timeout
- **Adaptive auth:** Script execution, step evaluation, conditional authentication
- **Token lifecycle:** Issuance, validation, refresh, revocation, JWT signing/verification

For each affected flow, note:
- Is this a public-facing flow or admin-only?
- Could this break existing integrations?
- Does this change token format, claims, or validation logic?

## Step 6: Tenant Impact

Determine the multi-tenancy impact:

- **Tenant-scoped:** Changes only affect the tenant context they run in. No cross-tenant risk.
- **Super-tenant only:** Changes only apply to the super tenant (carbon.super). Limited impact.
- **All tenants:** Changes affect shared infrastructure (caches, registries, DB schemas, OSGi services). Every tenant is impacted.
- **Tenant boundary crossing:** Changes involve cross-tenant operations (tenant provisioning, shared resource management).
- **Organization-scoped (Go):** Changes scoped to an organization context via middleware. No cross-org risk.

Check for:
- Cache operations without tenant-scoped keys
- Database queries without tenant/organization ID filtering
- **Java:** Registry operations on shared paths, event listeners that fire across tenant contexts
- **Go (stdlib):** Missing organization ID in `context.Context` (via `context.WithValue`/accessor functions), middleware not extracting tenant from JWT claims
- **Go (Gin):** Missing organization ID in `*gin.Context` (via `c.Set()`), org values not passed explicitly to service/repository layers (Gin context values do NOT propagate to `c.Request.Context()`)

## Step 7: Configuration & Migration Impact

Does this change require:

- **Configuration changes?**
  - **Java:** `deployment.toml` — new config sections, changed defaults, renamed properties
  - **Go:** Environment variables, YAML/TOML config files, command-line flags
  - Is the new config optional with a safe default, or mandatory (breaking for existing deployments)?
- **Database schema changes?** Check for:
  - New/altered tables or columns in the diff
  - **Java:** If `dbscripts/` exists, verify scripts for ALL supported databases: MySQL, PostgreSQL, Oracle, MSSQL, H2
  - **Go:** Check migration files (e.g., `migrations/`, `db/migrations/`) — verify up AND down migrations exist
  - If schema changes exist but migration scripts are missing: **"Database schema change detected but migration scripts not found for all DB types."**
- **Keystore or certificate changes?** New trust entries, changed signing keys
- **Environment variable changes?** New required variables, changed variable names
- **Helm chart value changes?** New parameters, changed defaults
- **Feature changes?**
  - **Java:** Check if `feature.xml` or P2 feature definitions need updating for new/removed components
  - **Go:** Check if Docker image, Makefile targets, or build configurations need updating

For each: is it backwards-compatible or a breaking change?

## Step 8: Rollback Complexity

Assess how hard it would be to roll back this change:

- **Trivial rollback:** Code-only change, no state mutations. Redeploy previous version.
- **Easy rollback:** Config changes that can be reverted. May need service restart.
- **Moderate rollback:** Database schema changes with backward-compatible migration (additive only — new columns/tables).
- **Hard rollback:** Database schema changes that drop columns/tables, encryption key changes, data format changes.
- **Irreversible:** Data migration that transforms existing data, encryption key rotation after data re-encryption.

## Step 9: Produce Impact Summary

Format as a structured summary suitable for a PR description:

```markdown
## Change Impact Analysis

**Branch:** [branch name]
**Commits:** [count] commits since [base branch]
**Files changed:** [count]
**Repo type:** [Framework / Extension / Product / Apps / Go Service / Go Library]
**Language stack:** [Java/Carbon / Go / Mixed]

### Module Impact (This Repo)
| Module/Package | Change Type | Dependents in Repo |
|--------|------------|-------------------|
| [module artifactId or Go package path] | [modified/added/removed] | [list] |

### Cross-Product Impact
[None — or list of external impacts with specific action items]
- [ ] **[product/repo]:** [what to check and why]

### API Contract Changes
[None — or list of changed endpoints with compatibility assessment]

### Auth Flow Impact
[None / list of affected flows with risk notes]

### Tenant Impact
**Scope:** [Tenant-scoped / Super-tenant only / All tenants / Boundary crossing]
[Details if not tenant-scoped]

### Configuration & Migration Requirements
- [ ] Configuration changes (deployment.toml / env vars / config files): [yes/no — details, backwards compatible?]
- [ ] Database migration: [yes/no — scripts for all DB types?]
- [ ] Keystore changes: [yes/no — details]
- [ ] Helm chart updates: [yes/no — details]
- [ ] Feature/P2/Dockerfile updates: [yes/no — details]
- [ ] Environment variables: [yes/no — details]

### Rollback Assessment
**Complexity:** [Trivial / Easy / Moderate / Hard / Irreversible]
**Procedure:** [brief rollback steps]

### Risk Summary
**Overall risk:** [Low / Medium / High / Critical]
**Key risks:**
1. [Most significant risk with mitigation]
2. [Second risk with mitigation]

### Recommended Review Focus
[Which files/areas need the most careful review and why]

### Action Items Before Merge
- [ ] [Any required actions — e.g., "Create dbscripts for Oracle", "Update product-is POM version"]
```
