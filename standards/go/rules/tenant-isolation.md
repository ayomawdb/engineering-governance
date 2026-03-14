---
description: Multi-tenant/organization data isolation for cache, database, and resource lookups
globs:
  - "**/*.go"
alwaysApply: false
---

# Tenant/Organization Isolation

- **MUST** scope all cache keys, database queries, and resource lookups to the organization/tenant.
  - stdlib: extract org ID from `context.Context` via typed accessor (e.g., `security.GetOUID(r.Context())`). Return 403 if empty.
  - Gin: extract org from `c.GetString("organization")` — values set via `c.Set()` do **NOT** propagate to `c.Request.Context()`. Pass org as a separate parameter to downstream functions.
- **MUST** prefix all cache keys with org/tenant ID: `cacheKey := orgID + "_config_" + configName` (not just `"config_" + configName`).
- **MUST** validate tenant context on cross-tenant boundary operations.
- **MUST** test features in a multi-tenant deployment before release.

## Common Isolation Mistakes

- Shared caches without org-scoped keys — data leaks across tenants
- Lazy-loaded singletons — may cache wrong tenant's data on first load
- Background goroutines — may lose tenant context if not explicitly passed
- Event handlers/callbacks — may fire in wrong tenant context
