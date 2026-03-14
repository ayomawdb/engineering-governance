---
description: WSO2 product infrastructure safety — sensitive files, dangerous operations, and production hardening
globs:
  - "**/deployment.toml"
  - "**/master-keys.yaml"
  - "**/*.jks"
  - "**/*.p12"
  - "**/cipher-text.properties"
  - "**/secret-conf.properties"
  - "**/values*.yaml"
  - "**/wso2*"
alwaysApply: false
---

# WSO2 Product Infrastructure Safety

## Sensitive Files — Never Read or Output

- **`deployment.toml`** — ALL passwords in plaintext: DB, keystore, super admin, LDAP, SMTP, OAuth, encryption keys. Secret sections: `[super_admin]`, `[database.*]`, `[keystore.*]`/`[truststore]`, `[encryption]`, `[recaptcha]`, `[output_adapter.email]`.
- **`master-keys.yaml`** — master decryption key. Exposure compromises every encrypted secret.
- **`cipher-text.properties`**, **`secret-conf.properties`** — Secure Vault config and encrypted passwords.
- **Keystores** (`wso2carbon.jks`, `.p12`, `client-truststore.jks`, `.p12`) — in `repository/resources/security/`.
- **WSO2 Helm `values.yaml`** — contains all above in template form, plus subscription/registry credentials.
- **`repository/logs/`** may contain tokens in debug mode. **`bin/`** may contain `-D` passwords in JVM args.

## Default Credentials — Must Change in Production

- Super admin: `admin`/`admin` — full management console and API access.
- All keystore passwords: `wso2carbon` — enables private key extraction, token forgery.
- H2 embedded DB: `wso2carbon`/`wso2carbon` — direct database access.

## Dangerous Operations — Require Explicit Confirmation

- **Changing `[encryption] key`** after deployment — previously encrypted data becomes **permanently unrecoverable**.
- **Replacing keystores** without coordinating across all cluster nodes — breaks inter-node communication and token validation.
- **Modifying `[database.*]`** — wrong JDBC URL/credentials causes complete outage.
- **Running migration scripts** (`dbscripts/`) against production without backup — forward-only, no rollback.
- **Exposing port 9443** to public — management console and all admin APIs.
- **Modifying `[clustering]`** on a running cluster — can cause split-brain.
- **Tenant deletion** in multi-tenant deployments — permanently removes all tenant data.
- H2 database in production — dev only, no clustering, corrupts under concurrent access.
- Debug log level in production — logs OAuth tokens, SAML assertions, request payloads.

## Production Hardening

- **Secure Vault** — all passwords encrypted via Cipher Tool (`$secret{alias}` references).
- **Transport** — HTTP disabled, TLS 1.2+, HSTS enabled, Server header masked, DH key >= 2048.
- **JVM flags:** `-Djdk.tls.ephemeralDHKeySize=2048`, `-Djdk.tls.rejectClientInitiatedRenegotiation=true`, `-Dhttpclient.hostnameVerifier=Strict`.
- **Default ports changed** — 9443 (console HTTPS, change to non-standard), 9763 (console HTTP, disable), 8243 (gateway HTTPS, change if exposed), 8280 (gateway HTTP, disable).
- **DB user least-privileged** — DML only, no DDL.
- **LDAP read-only** — read-only bind DN for auth/lookup; separate credentials for provisioning.
- **Separate admin accounts** — individual accounts per operator, not shared `admin`.

## Docker and Helm Safety

- Never bake secrets into image layers — mount config at runtime via K8s ConfigMap/Secret.
- WSO2 container user: `wso2carbon` (UID 802, GID 802).
- Production images from `docker.wso2.com` require subscription credentials.
- Never commit `deployment.toml` with real passwords to Docker build context.
- WSO2 Helm `values.yaml` — treat as equivalent to `deployment.toml`, never read or display.
- When `secretStore.enabled = true`, passwords use `$secret{alias}` — actual secrets in cloud secret store.
