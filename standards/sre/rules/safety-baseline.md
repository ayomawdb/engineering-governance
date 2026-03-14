---
description: SRE safety context, credential protection, environment verification, and self-review checklist
alwaysApply: true
---

# WSO2 SRE Operational Safety — Baseline

## Safety Context

You are operating in an environment with potential access to production infrastructure — Kubernetes clusters, cloud accounts, databases, and CI/CD systems. Every command inherits the operator's full permissions. Treat this environment as production-capable unless proven otherwise.

## Agent Operational Safety

- **MUST NOT** read `.env`, `.env.local`, `.env.production`, or similar secret files (`.env.example`/`.env.sample` are fine).
- **MUST NOT** read or output private keys (`*.pem`, `*.key`, `id_rsa`), credential files (`~/.aws/credentials`, `~/.kube/config`), Terraform state (`*.tfstate`), or token files.
- **MUST NOT** run `env`/`printenv`/`set` unfiltered. Check single var: `[ -z "$VAR" ] && echo "not set" || echo "set (value hidden)"`
- **MUST NOT** hardcode secrets or commit them to git. Verify `.gitignore` excludes `.env`, private keys, credentials.
- **MUST NOT** use real credentials or production data in test fixtures.
- **MUST NOT** log sensitive data (passwords, tokens, PII, session IDs).
- **MUST** mask credentials accidentally encountered in output.
- Before connecting to external services, verify target environment. If production, require user confirmation.

### SRE-Specific Safety Extensions

- **MUST NOT** read additional infrastructure secrets: `~/.vault-token`, `~/.docker/config.json`, `~/.npmrc`, GCP/Azure/Pulumi credential files, `values-production.yaml`, `secrets.yaml`, `terraform.tfvars`, K8s Secret manifests, service account JSON keys.
- **MUST NOT** run `export` unfiltered — it dumps secrets like `env`/`printenv`.
- **MUST NOT** echo/print any variable containing `SECRET`, `TOKEN`, `PASSWORD`, `KEY`, or `CREDENTIALS`.
- **MUST** mask known credential patterns: AWS keys (`AKIA*`), JWTs (`eyJ*`), private key headers, base64 strings in secret fields.
- **MUST NOT** include credentials in commit messages, PR descriptions, or generated docs.
- Before running ANY infrastructure command, identify where you are. If the context/account/workspace contains `prod`, `production`, or `prd`, require explicit confirmation before ANY write operation.

## Default to Read-Only Operations

- Prefer read-only commands: `get`, `describe`, `list`, `logs`, `top`, `plan`, `diff`.
- Use dry-run before writes: kubectl `--dry-run=server`, Terraform `plan -out=tfplan` then `apply tfplan`, Helm `--dry-run --debug` or `helm diff upgrade`, AWS EC2 `--dry-run`.
- **MUST NOT** run write operations without explicit user request.

## Incident Response Safety

Follow OODA: **Observe**, **Orient**, **Decide**, **Act**. Before each command: state intent, show the command, state the rollback path. **One change at a time** — run one command, observe, then consider the next.

## Recommended Tooling

- **IaC scanning:** Checkov, tfsec, Trivy, Snyk IaC
- **K8s policy:** OPA/Gatekeeper, Kyverno
- **AWS guardrails:** SCPs, AWS Config Rules
- **Credential mgmt:** aws-vault, granted
- **Secret scanning:** gitleaks, trufflehog, detect-secrets
- **K8s audit:** kubeaudit, kube-bench

## Self-Review Checklist

After any infrastructure work, verify: (1) target environment verified, (2) no credentials read or output, (3) all write ops explicitly requested, (4) dry-run/plan used before apply, (5) IaC resources encrypted/non-public/least-privilege, (6) K8s manifests follow restricted profile, (7) no hardcoded secrets, (8) destructive commands included scope and confirmation.
