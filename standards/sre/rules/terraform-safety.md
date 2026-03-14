---
description: Terraform plan-before-apply workflow, state file protection, and destroy safeguards
globs:
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/terraform*"
  - "**/.terraform*"
alwaysApply: false
---

# Terraform Safety

- **MUST** run `terraform plan -out=tfplan` then `terraform apply tfplan` — never skip the plan step.
- **MUST NOT** read or output `terraform.tfstate` — it contains plaintext secrets (DB passwords, API keys, private IPs, certs).
- **MUST NOT** run `terraform force-unlock` — investigate the lock holder instead.
- **MUST** flag any plan showing resource destruction before proceeding.
- **MUST** pin provider and module versions. Use `required_version` constraint and exact pins for modules.
- **MUST** use remote state with locking (S3+DynamoDB, GCS, Terraform Cloud).
- **MUST** prefer `moved` blocks over `terraform state mv` for renames/refactors — `state mv` is imperative, untracked, and error-prone.

## The Sacred Workflow

```bash
terraform workspace show           # 1. Verify workspace
terraform init                     # 2. Init
terraform plan -out=tfplan         # 3. Plan to file
# Review: flag any destroys        # 4. Review
terraform apply tfplan             # 5. Apply saved plan
```

## Dangerous Operations

- `terraform destroy` — destroys all managed resources. Require explicit request + target confirmation.
- `terraform apply -auto-approve` — skips plan review. Never in production.
- `terraform state rm` — orphans resources. Explicit request only.
- `terraform state mv` — can break resource associations. Explicit request only.
- `terraform force-unlock` — can corrupt state. Never — investigate lock holder.
- `terraform taint` — **deprecated**, use `-replace=<resource>` instead. Causes downtime if applied.

## Detecting Dangerous Plan Changes

Flag these patterns in `terraform plan`:
- **Forces replacement** (`must be replaced`) — for databases, this means DATA LOSS.
- **Destroy count > 0** — confirm explicitly.
- **Changes to shared resources** — VPC, IAM roles, DNS zones, security groups.
- **Changing immutable attributes** (RDS `engine`, EC2 `ami`) — forces replacement.

## State Safety

- **Safe:** `terraform state list`, `terraform show -json tfplan | jq '.resource_changes[]'`
- **Dangerous — never do:** `cat terraform.tfstate`, `terraform state pull` — exposes all secrets.
- Run `terraform init -upgrade` deliberately — never let providers auto-upgrade in production.
- If a lock is stuck, investigate the lock holder before considering `force-unlock`.
