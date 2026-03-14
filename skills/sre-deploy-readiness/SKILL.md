---
name: sre-deploy-readiness
description: Pre-deployment readiness checklist for WSO2 products. Validates Kubernetes manifests, Helm values, IaC security defaults, container security, and WSO2-specific configuration against SRE safety standards. Produces a go/no-go checklist.
# Agent-specific settings (Claude Code):
#   disable-model-invocation: true
#   allowed-tools: Read, Grep, Glob, Bash(kubectl get *), Bash(kubectl describe *), Bash(helm template *), Bash(helm lint *), Bash(helm diff *), Bash(terraform plan *), Bash(terraform validate *), Bash(git diff *), Bash(git log *)
# For other agents, configure equivalent restrictions in your tool's settings.
argument-hint: [product environment] e.g. "identity-server staging"
---

# Deploy Readiness Check

You are an SRE validating that a deployment meets all security and operational requirements before it reaches the target environment.

## Safety Context

If this repository has operational safety standards installed (e.g., `.claude/rules/`, `.cursor/rules/`, AGENTS.md, CLAUDE.md, or equivalent), load them first — they contain repo-specific SRE safety rules that supplement the checks below. If no standards are found, this skill is self-contained — proceed with the checks defined in this file.

**Critical rule:** Do NOT read the VALUES of secret/password fields. Only check that they EXIST and reference external secret sources (environment variables, Vault, Sealed Secrets, External Secrets Operator).

## Step 1: Identify Deployment Scope

Parse `$ARGUMENTS` for:
- **Product:** Identity Server, API Manager, Micro Integrator, or other
- **Environment:** dev, staging, production (if not specified, ask)

If the target environment is `production` or `prod`, flag:
> **PRODUCTION DEPLOYMENT — All checks enforced at maximum strictness. Any "Should Fix" becomes "Must Fix".**

Find the deployment artifacts:
```
# Look for Helm charts, K8s manifests, Terraform files
```
Search for: `values.yaml`, `Chart.yaml`, `deployment.yaml`, `*.tf`, `kustomization.yaml`, `docker-compose*.yaml`

## Step 2: Container Security Checks

For every container in every Pod spec (Deployments, StatefulSets, Jobs, CronJobs, DaemonSets):

| # | Check | Requirement | How to Verify |
|---|-------|-------------|---------------|
| C1 | Non-root user | `runAsNonRoot: true` AND `runAsUser` > 0 | Search for `securityContext` in pod/container spec |
| C2 | No privilege escalation | `allowPrivilegeEscalation: false` | Must be explicitly set |
| C3 | Read-only root filesystem | `readOnlyRootFilesystem: true` | Use `emptyDir` for temp/logs if needed |
| C4 | Drop all capabilities | `capabilities.drop: ["ALL"]` | Only add back specific caps with justification |
| C5 | No service account auto-mount | `automountServiceAccountToken: false` | Unless pod needs K8s API access (document why) |
| C6 | Seccomp profile | `seccompProfile.type: RuntimeDefault` | Must be set |
| C7 | No host namespaces | No `hostNetwork`, `hostPID`, `hostIPC` | Must not be present or must be `false` |
| C8 | Resource limits | Both `requests` and `limits` for CPU and memory | All containers including init containers |
| C9 | Specific image tag | No `:latest` tag, prefer digest (`@sha256:...`) | Check all `image:` fields |
| C10 | Liveness & readiness probes | Both probes defined with appropriate thresholds | Check all main containers |

## Step 3: IaC Security Checks

For Terraform, CloudFormation, or raw cloud resource definitions:

| # | Check | Requirement |
|---|-------|-------------|
| I1 | Encryption at rest | Enabled on ALL storage: S3 (`sse_algorithm`), EBS (`encrypted = true`), RDS (`storage_encrypted = true`), DynamoDB |
| I2 | No public access | S3 `PublicAccessBlock` all true, RDS `publicly_accessible = false`, no public subnets for databases |
| I3 | No open security groups | No `0.0.0.0/0` on ports 22 (SSH), 3389 (RDP), 1433/3306/5432/27017 (databases), 9443 (WSO2 admin) |
| I4 | No wildcard IAM | No `Action: "*"` or `Resource: "*"` in IAM policies |
| I5 | No hardcoded secrets | All secrets via Secrets Manager, SSM Parameter Store, Vault, or `sensitive = true` variables |
| I6 | TLS 1.2 minimum | On all load balancers, ingresses, and API endpoints |
| I7 | Logging enabled | Access logging on ALB/NLB, S3 access logging, CloudTrail, VPC Flow Logs |

## Step 4: Application-Specific Checks

### 4a. Generic Checks (all stacks)

| # | Check | Requirement |
|---|-------|-------------|
| A1 | No default credentials | No default admin/admin, default secret keys, or placeholder passwords in deployment artifacts |
| A2 | Admin/management interfaces not public | Admin endpoints must not be exposed via Ingress/LoadBalancer to public internet. Require NetworkPolicy, mTLS, or VPN |
| A3 | TLS 1.2+ enforced | No weak ciphers (DES/3DES/MD5/RC4). HSTS headers enabled. HTTP transport disabled in production |
| A4 | No debug settings in production | No debug ports, debug log levels, or hot deployment flags |
| A5 | Secrets externalized | All secrets via K8s Secrets, External Secrets Operator, Vault, or Secret Store CSI — not plaintext in ConfigMaps or config files |
| A6 | CORS restricted | `allow_origins` not `*` in production. `allow_credentials + allow_origins = *` is a critical vulnerability |
| A7 | Separate admin accounts | No shared `admin` account in production. Dedicated accounts per operator for audit trail |
| A8 | Sensitive data not in URLs | Tokens, passwords, secrets in request body/headers only — never as query parameters |
| A9 | Database hardened | Production database (not dev/embedded), private subnet, connection pool sized for load, DB user with least-privilege (no DDL permissions) |
| A10 | Dependency vulnerabilities | No known vulnerabilities — `govulncheck` (Go), OWASP Dependency Check (Java) |

### 4b. Java/Carbon-Specific Checks

Skip this section for Go-only deployments.

**Default credentials:**
- `admin`/`admin` in super admin password fields → full platform compromise
- `wso2carbon` in keystore passwords (`*.jks`, `*.p12`) → key extraction. Do NOT read actual values — search for DEFAULT values only.

**Transport & TLS hardening** — check startup scripts and deployment config:
- Strong ciphers only (`PreferredCiphers` configured, no DES/3DES/MD5/RC4/DSS)
- Server header masked (default `Server: WSO2 Carbon Server` changed)
- DH key size ≥ 2048 (`-Djdk.tls.ephemeralDHKeySize=2048`)
- Client renegotiation disabled (`-Djdk.tls.rejectClientInitiatedRenegotiation=true`)
- Hostname verification enabled (`-Dhttpclient.hostnameVerifier=Strict`)
- No debug JVM flags (`-agentlib:jdwp`, `-Xdebug`, `MaxPermSize`)
- Mutual SSL for service-to-service auth where applicable

**Secure Vault:** Passwords in deployment.toml must use `$secret{alias}` references, NOT plaintext. Check for `[secrets]` section or `cipher-text.properties`.

**Port & session config:**
- Default ports changed (9443, 9763, 8243, 8280) in production
- Session ID length increased from default 16 bytes (`sessionIDLength` in `context.xml`)
- Session timeout ≤30 minutes

**Debug settings:** `hot_deployment` must be false, `log4j.rootLogger` must be INFO or WARN, no `-agentlib:jdwp` or `-Xdebug` in JAVA_OPTS.

**H2 database:** Must NOT be used in staging/production (embedded, dev-only).

### 4c. Go Service-Specific Checks

Skip this section for Java-only deployments.

| # | Check | Requirement | How to Verify |
|---|-------|-------------|---------------|
| G1 | TLS min version | `tls.Config.MinVersion` set to `tls.VersionTLS12` or higher | Search source or config for TLS settings |
| G2 | Server timeouts | `ReadHeaderTimeout`, `ReadTimeout`, `WriteTimeout`, `IdleTimeout` all set on `http.Server` | Check `main.go` or server initialization |
| G3 | No `InsecureSkipVerify` | `tls.Config.InsecureSkipVerify` must not be `true` | Search source for `InsecureSkipVerify` |
| G4 | Goroutine safety | Gin `*gin.Context` not passed to goroutines; stdlib uses `context.Context` | Review handler code |
| G5 | Security bypass flags disabled | No auth-skip or validation-bypass flags enabled in deployment config | Check Helm values, ConfigMaps, env vars |
| G6 | Go binary container | Minimal base image (distroless/scratch), non-root user, no shell | Check Dockerfile |
| G7 | gRPC TLS (if applicable) | gRPC services use TLS, not plaintext | Check gRPC server config |
| G8 | CRD validation (if K8s controllers) | CRD schemas have validation rules, webhook validation configured | Check CRD manifests |

## Step 5: Helm Chart Checks (if applicable)

```bash
helm lint <chart-path>
helm template <release-name> <chart-path> -f <values-file> > /tmp/rendered.yaml
```

Check the rendered output against all rules above. Also verify:
- Chart version is pinned (not `latest` or `*`)
- Dependency chart versions are pinned
- Values that should differ per environment actually differ (DB host, replica count, resource limits)

## Step 6: Produce Readiness Report

```markdown
## Deployment Readiness Report

**Product:** [product name]
**Target environment:** [environment]
**Date:** [timestamp]
**Verdict:** [GO / NO-GO / CONDITIONAL GO]

### Container Security
| # | Check | Status | Details |
|---|-------|--------|---------|
| C1 | Non-root user | PASS/FAIL | [details] |
| C2 | No privilege escalation | PASS/FAIL | |
| C3 | Read-only root FS | PASS/FAIL | |
| C4 | Drop all capabilities | PASS/FAIL | |
| C5 | No SA auto-mount | PASS/FAIL | |
| C6 | Seccomp profile | PASS/FAIL | |
| C7 | No host namespaces | PASS/FAIL | |
| C8 | Resource limits | PASS/FAIL | |
| C9 | Specific image tag | PASS/FAIL | |
| C10 | Health probes | PASS/FAIL | |

### IaC Security
| # | Check | Status | Details |
|---|-------|--------|---------|
| I1-I7 | [each check] | PASS/FAIL | |

### Application Security
| # | Check | Status | Details |
|---|-------|--------|---------|
| A1-A10 | [each generic check] | PASS/FAIL | |

### Stack-Specific (Java/Carbon or Go)
| Check | Status | Details |
|-------|--------|---------|
| [applicable checks from 4b or 4c] | PASS/FAIL | |

### Must Fix (Blocking)
Items that MUST be resolved before deployment:
1. [item with specific fix instructions]

### Should Fix (Non-blocking for staging, blocking for production)
1. [item with recommendation]

### Advisory Notes
1. [best practice suggestions]

### Deployment Procedure Reminders
- [ ] Backup database before deploying
- [ ] Verify rollback procedure is documented and tested
- [ ] Notify affected teams/stakeholders
- [ ] Monitor error rates for 30 minutes after deployment
- [ ] Verify health checks pass on all pods
```
