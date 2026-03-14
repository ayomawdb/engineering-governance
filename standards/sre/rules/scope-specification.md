---
description: Always specify explicit scope (namespace, profile, workspace) in infrastructure commands
alwaysApply: true
---

# Always Specify Scope

- **MUST** always use `-n <namespace>` with kubectl — never rely on default namespace.
- **MUST** always use `--profile <name>` or verify the active profile with AWS CLI.
- **MUST** always verify `terraform workspace show` before plan/apply.
- **MUST NOT** run kubectl with `--all-namespaces`/`-A` on write operations.
- **MUST NOT** run commands that affect all resources without an explicit resource name.
- **MUST** use `kubectl auth can-i <verb> <resource> -n <namespace>` to verify permissions before write operations in unfamiliar clusters.
- **MUST** use `--region` explicitly with AWS CLI when operating across multiple regions.

## Common Scope Mistakes

- **kubectl context stale after cluster switch:** `kubectx`/`kubectl config use-context` does not validate connectivity. Run `kubectl cluster-info` after switching.
- **AWS profile inheritance in subshells:** `AWS_PROFILE` set in parent shell carries into scripts silently. Verify with `aws sts get-caller-identity` inside scripts.
- **Terraform workspace drift:** If `.terraform/` was initialized for a different backend, `terraform workspace show` may show wrong state. Run `terraform init` after switching directories.
