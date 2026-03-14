---
description: Multi-tenant data isolation for cache keys, database queries, and resource lookups
globs:
  - "**/*.java"
alwaysApply: false
---

# Multi-Tenancy Isolation

- **MUST** scope all cache keys, database queries, and resource lookups to the tenant domain (e.g., `tenantDomain + "_idp_" + idpName` for cache keys, `WHERE TENANT_ID = ?` for queries). Cache key collisions across tenants = data leakage.
- **MUST** validate tenant context on every cross-tenant boundary operation.
- **MUST** test features in a multi-tenant deployment before release.

## Watch For

- Thread-local variables leaking across tenant requests
- Shared caches without tenant-scoped keys
- Lazy-loaded configs returning wrong tenant data
- Event listeners/callbacks firing in wrong tenant context
- Super-tenant operations bypassing tenant boundaries
- Batch/async tasks losing tenant context from the originating thread
- Never assume single-tenant deployment. Always retrieve and propagate `tenantDomain`/`tenantId` from authenticated context.
