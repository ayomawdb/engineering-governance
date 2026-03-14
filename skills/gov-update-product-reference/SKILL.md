---
name: update-product-reference
description: Discover new WSO2 products, research their architecture, and update product-reference.md. Crawls GitHub orgs and repo contents. Use before updating standards or skills.
---

# Update WSO2 Product Reference

You are a research agent responsible for keeping the WSO2 Product Reference document up to date. This is a governance task — run periodically before working on standards or skills to ensure they reflect the current product landscape.

## Target File

Read and update: `references/product-reference.md`

Read the current file first to understand what is already documented.

## Step 1: Discover Products

Launch parallel sub-agents to gather product information. Each should return structured findings.

### Agent 1: WSO2 Website
Fetch and analyze the WSO2 website for product listings:
- `https://wso2.com` — navigation menus, product pages
- Any new product pages linked from the main site

Extract: product names, descriptions, latest versions, marketing positioning, platform groupings. This is the primary source for SaaS products (Asgardeo, Choreo) that have no public repos, and for catching new product launches, rebranding, or deprecations that may not be reflected in GitHub.

### Agent 2: GitHub Organization — wso2
Scan the `wso2` GitHub org for product repos:
- Use `gh api` or WebFetch on `https://github.com/orgs/wso2/repositories?type=source&sort=updated`
- Look for repos matching `product-*`, `carbon-*`, `identity-*`, `apk`, `*-gateway*`, `*-manager*`, `api-platform`
- For each product repo: check `README.md`, check for `pom.xml` (Java), `go.mod` (Go), or `package.json` (TypeScript) to determine stack
- Check repo activity — last commit date, open issues, release tags — to assess if active or archived

Extract: repo URL, stack, latest version/tag, active vs archived status.

### Agent 3: GitHub Organization — asgardeo
Scan the `asgardeo` GitHub org:
- Identify product repos (not SDKs, samples, or docs). Key product: `asgardeo/thunder`
- For each: check stack, README, activity

### Agent 4: GitHub Organization — wso2-extensions
Scan for significant extensions:
- Count total repos
- Identify major categories (identity authenticators, APIM extensions, open banking)
- Note any new extension categories not already documented

### Agent 5: Other GitHub Organizations
Check these orgs:
- `openchoreo` — OpenChoreo IDP
- `ballerina-platform` — Ballerina language
- Any other WSO2-related orgs discovered

### Agent 6: Go Product Deep Dive
For each Go-based product repo (existing or newly discovered), fetch and analyze:
- `go.mod` — HTTP framework (`gin-gonic/gin`, stdlib `net/http`, gRPC, etc.), Go version, key dependencies
- Directory structure — `internal/`, `pkg/`, `cmd/`, `api/` layout
- Entry point (`cmd/*/main.go`) — server setup, middleware chain, TLS config
- Auth middleware — JWT validation, authentication patterns
- Config pattern — env vars, YAML, TOML, config structs with defaults
- Multi-tenancy — how org/tenant context is propagated
- Database — ORM vs raw SQL, which driver, parameterization pattern

This determines the correct Stack Summary entry and whether standards need updating.

### Agent 7: Java/Carbon Dependency Verification
For Java/Carbon products, verify the dependency diagram is still accurate:
- Check `product-is`, `product-apim`, `product-micro-integrator` for current dependency versions
- Verify `carbon-identity-framework`, `carbon-apimgt`, `carbon-mediation` are still the primary frameworks
- Check if any new significant repos have been added to the dependency chain
- Verify `wso2-extensions` repo categories and counts

## Step 2: Compare Against Current Reference

After all agents return, compare findings against the current reference:

### Check for:
1. **New products** — repos or products not listed in the reference
2. **Removed/archived products** — repos that are now archived or inactive
3. **Status changes** — products that moved from active to deprecated or vice versa
4. **Stack changes** — products that changed technology stack (e.g., Java to Go rewrite)
5. **Framework changes in Go repos** — did any product switch HTTP frameworks or add new services?
6. **Architecture changes** — new components, changed directory layouts, new dependencies
7. **New GitHub orgs** — any new organizations not covered
8. **New repo categories in wso2-extensions** — any new extension types?

Produce a change report before making edits.

## Step 3: Update the Reference File

Apply all discovered changes to `references/product-reference.md`:

### What to update:
- **Product Portfolio tables** — add new products, update statuses, remove archived ones
- **Stack Summary table** — add new entries, update framework info. Current categories:
  - `Java/Carbon` — Servlet/OSGi products
  - `Go (stdlib)` — Thunder, Agent Manager, OpenChoreo (net/http + oapi-codegen)
  - `Go (Gin)` — API Platform (gin-gonic/gin)
  - `Go (Gin + gRPC/K8s)` — APK (Gin HTTP APIs + gRPC xDS + controller-runtime)
  - `Go (gRPC/K8s)` — AI Gateway (gRPC + controller-runtime, no HTTP framework)
  - `TypeScript`, `Ballerina`, `SaaS`
- **GitHub Organizations table** — update repo counts, add new orgs
- **Architecture sections** — each Go product should have its own subsection under "Architecture: Go Stack" with:
  - Framework identification
  - Architecture diagram (ASCII)
  - Directory layout
  - Key patterns (auth, config, DB, multi-tenancy, error handling)
  - Key dependencies list
- **Java/Carbon dependency diagram** — update if repos were added/removed/renamed
- **Key Repos by Product table** — update if new repos discovered
- **Legacy/Superseded table** — move products here if they've been replaced

### What NOT to update:
- **Critical Differences: stdlib vs Gin table** — only update if a new framework combination is found

### Rules:
- Keep descriptions concise (1 line per product in portfolio tables)
- Do not add repos that are clearly samples, demos, documentation, or SDKs
- Mark confidence level for new discoveries: note "Stack: unverified — needs manual check" if you could not verify from the repo
- Preserve existing content structure — add to tables, don't restructure
- Architecture sections should follow the pattern of existing sections (Thunder, API Platform, APK, AI Gateway, Agent Manager, OpenChoreo)

## Step 4: Report Changes Made

After updating, produce a summary:

```markdown
## WSO2 Product Reference — Update Summary

**Date:** [today]
**Sources checked:** [list of GitHub orgs and repos examined]

### Changes Applied
1. Added [product] to [section] — [reason]
2. Updated [product] status from [x] to [y]
3. Added architecture section for [product]
4. ...

### Items Requiring Manual Verification
- [product/finding that could not be fully verified]

### Standards & Skills Impact Assessment
If new stacks or frameworks were discovered, note which may need updating:
- standards/java: [needs update for X / no changes needed]
- standards/go: [needs update for X / no changes needed]
- standards/sre: [needs update for X / no changes needed]
- skills/se-security-review: [details]
- skills/se-change-impact: [details]
- skills/se-tenant-check: [details]
```
