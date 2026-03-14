---
description: Non-negotiable IaC security defaults for encryption, access, IAM, and TLS
globs:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/cloudformation*"
  - "**/*policy*"
  - "**/*iam*"
  - "**/*IAM*"
  - "**/*security*group*"
alwaysApply: false
---

# IaC Security Defaults

When writing or modifying Infrastructure as Code, enforce these non-negotiable defaults:
- **Encryption at rest** enabled on all storage — S3 (`sse_algorithm = "aws:kms"`), EBS (`encrypted = true`), RDS (`storage_encrypted = true`), DynamoDB. Always specify `kms_key_id`.
- **No public access** — S3: all four `PublicAccessBlock` fields `true`. RDS: `publicly_accessible = false`.
- **No open security groups** — never `0.0.0.0/0` on SSH (22), RDP (3389), or database ports. Use `source_security_group_id` instead.
- **No wildcard IAM** — never `Action: "*"` or `Resource: "*"`. Scope to specific actions on specific resource ARNs. Use condition keys: `aws:RequestedRegion`, `aws:PrincipalTag`, `aws:SourceIp`, `aws:MultiFactorAuthPresent`.
- **No hardcoded secrets** — reference `aws_secretsmanager_secret_version` or use `sensitive = true` variables.
- **No privileged containers** — never `privileged: true`, `hostNetwork: true`, `hostPID: true`.
- **Resource limits required** — every K8s container must have CPU/memory requests and limits.
- **No `:latest` tags** — always use specific image versions or digests.
- **TLS 1.2 minimum** on all load balancers, ingresses, and API endpoints.

## AWS Account-Level Guardrails

- **SCPs** — deny resource creation outside approved regions, deny disabling CloudTrail/GuardDuty/Config, deny leaving the Organization, deny root user actions (except break-glass).
- **CloudTrail** — mandatory in all accounts: multi-region trail, log file validation, centralized immutable S3 bucket, CloudWatch Logs integration.
- **S3 MFA Delete** — enable on critical buckets (state files, backups, audit logs).
- **VPC Endpoints** — use gateway endpoints for S3 (free) and interface endpoints for Secrets Manager/other services to keep traffic off the public internet. Set `private_dns_enabled = true` on interface endpoints.

## Protection Against Accidental Destruction

- Set `deletion_protection = true` on databases, load balancers, and other critical resources.
- Use `lifecycle { prevent_destroy = true }` in Terraform for resources that must never be destroyed via IaC.

## CI/CD Pipeline Safety

- **MUST NOT** hardcode secrets in pipeline files — use platform secret management.
- **MUST** separate plan/review and apply stages with manual approval gates for production.
- **MUST** pin action/plugin versions by SHA, not `@latest` or `@main`.
- **MUST** run IaC scanning (checkov, tfsec, trivy) in the pipeline.
- **MUST** use OIDC federation for cloud auth — never long-lived credentials.
- **MUST** set explicit `permissions:` blocks in GitHub Actions (`contents: read`, `id-token: write` for OIDC).
- Use `terraform plan -detailed-exitcode`: exit `0` = no changes, `1` = error, `2` = changes (proceed to approval gate).
