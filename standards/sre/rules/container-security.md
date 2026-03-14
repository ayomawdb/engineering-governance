---
description: Kubernetes pod security restricted profile defaults for containers
globs:
  - "**/*.yaml"
  - "**/*.yml"
  - "**/Dockerfile*"
  - "**/docker-compose*"
  - "**/values*.yaml"
  - "**/Chart.yaml"
  - "**/kustomization.yaml"
  - "**/*deployment*"
  - "**/*statefulset*"
  - "**/*daemonset*"
alwaysApply: false
---

# Container Security Defaults

When writing Kubernetes manifests or Helm values:
- **MUST** set pod-level: `runAsNonRoot: true`, `runAsUser`/`runAsGroup`/`fsGroup` to non-zero UIDs, `seccompProfile.type: RuntimeDefault`, `automountServiceAccountToken: false`.
- **MUST** set container-level: `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: ["ALL"]`. Use `emptyDir` for temp/log paths.
- **MUST** use image digests (`image: repo/app@sha256:...`) for production — tags are mutable.
- **MUST** define CPU/memory requests and limits on every container.
- **MUST** define `PodDisruptionBudget` (`minAvailable` or `maxUnavailable`) for critical workloads.
- **MUST NOT** use `kubectl delete pod --grace-period=0 --force` unless pod is stuck in `Terminating`.
- **NEVER** set: `privileged: true`, `hostNetwork: true`, `hostPID: true`, `hostIPC: true`, or use `hostPath` volumes.

## Network Policies — Default Deny

Apply to every namespace. This pattern is non-obvious because it must allow DNS egress:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  egress:
    - ports:
        - {protocol: UDP, port: 53}
        - {protocol: TCP, port: 53}
```

Then add specific allow policies per service.

## Container Image Security

- Use multi-stage builds — final image should contain only runtime and binary. Prefer distroless/nonroot base images.
- Run as `USER nonroot:nonroot` in Dockerfile.
- Sign images with `cosign` and enforce verification at admission with Kyverno or Sigstore policy-controller.

## Secrets in Kubernetes

Use External Secrets Operator (ESO) or Secret Store CSI Driver — avoid `kubectl create secret`:

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: db-credentials
  data:
    - secretKey: password
      remoteRef:
        key: prod/db/password
```
