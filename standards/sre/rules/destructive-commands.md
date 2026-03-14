---
description: Require explicit confirmation before destructive infrastructure commands
alwaysApply: true
---

# Destructive Command Safety

These commands require explicit request — never run them proactively:
- `terraform destroy`, `terraform apply -auto-approve`, `terraform state rm`
- `kubectl delete namespace`, `kubectl delete --all`, `kubectl drain`
- `aws s3 rb`, `aws ec2 terminate-instances`, `aws rds delete-db-instance`
- `helm uninstall`, `helm rollback`
- `kubectl delete pod --grace-period=0 --force` (bypasses graceful shutdown — data loss risk)
- Any command with `--force`, `rm -rf`, or `DROP`/`TRUNCATE` on databases

When asked to run a destructive command, state what will be affected and the rollback path before executing.

## kubectl Risk Classification

- **Safe** (run freely): `get`, `describe`, `logs`, `top`, `explain`, `api-resources`
- **High** (require explicit request + context verification): `apply`, `patch`, `scale`, `rollout restart`
- **Destructive** (require explicit confirmation + rollback path): `delete`, `drain`, `cordon`, `taint`, `edit`

Before any write operation: verify context and namespace, use `--dry-run=server` before `apply`, show targets with `get` before deleting. Note current state for rollback (e.g., current replica count, `kubectl diff`). After failed deployment: `kubectl rollout undo`.

## AWS CLI Safety

Always verify identity first: `aws sts get-caller-identity`
- **Safe:** `describe-*`, `get-*`, `list-*`
- **High:** `modify-*`, `update-*`, `put-*`
- **Critical:** `delete-*`, `terminate-*`
- **Extreme:** IAM/VPC/DNS/KMS writes
- **Blast radius beyond target:** `delete-role` breaks all services using it, `delete-vpc` breaks everything in it, Route53 changes affect all users globally.
- **Irreversible without backups:** `delete-db-instance --skip-final-snapshot`, `s3 rb --force`, `terminate-instances`, `schedule-key-deletion`.

## Helm Safety

- Run `helm list -n <namespace>` before upgrade. Use `helm diff upgrade` or `--dry-run --debug` before install/upgrade. Never `helm uninstall` without explicit request.

## Docker Safety

- Never use `--privileged` — use specific `--cap-add` capabilities.
- `docker-compose down -v` destroys volumes (DATA LOSS) — omit `-v` to preserve data.
- `docker system prune -a --volumes` deletes everything. Verify target registry before `docker push`.

## Database CLI Safety

- Before any operation, verify connection target: `SELECT current_database(), current_user, inet_server_addr()`.
- **Destructive (require explicit request + confirmation):** `DROP DATABASE/TABLE`, `TRUNCATE`, `DELETE FROM` (without WHERE), `UPDATE` (without WHERE), `ALTER TABLE DROP COLUMN`, `FLUSHALL`/`FLUSHDB`.
- Never run `DELETE`/`UPDATE` without `WHERE`. Use `BEGIN`/`ROLLBACK` to preview before `COMMIT`.
- Before destructive DDL/DML, verify a recent backup exists and is restorable.
