---
description: LDAP injection prevention for user store queries
globs:
  - "**/*LDAP*"
  - "**/*Ldap*"
  - "**/*UserStore*"
  - "**/*DirectoryServer*"
  - "**/*ldap*"
alwaysApply: false
---

# LDAP Injection Prevention

WSO2 products use LDAP extensively for user stores.

- **MUST** escape special characters before constructing LDAP queries — never concatenate user input directly into filter strings or DNs.

## Characters to Escape

- **Filters (RFC 4515)**: `*` `(` `)` `\` NUL — escape as `\XX` (hex-encoded byte).
- **DNs (RFC 4514)**: `\` `#` `+` `<` `>` `,` `;` `"` `=` and leading/trailing spaces.
- Filter context and DN context have different escape rules — handle separately.

## Escaping Methods

- Use `escapeSpecialCharactersForFilter()` for filter values: `"(&(uid=" + safeUsername + ")(objectClass=person))"`
- Use `escapeDN()` for DN construction: `"uid=" + escapeDN(username) + ",ou=People,dc=wso2,dc=org"`
- Spring LDAP (preferred): `LdapEncoder.filterEncode()` for filters, `LdapEncoder.nameEncode()` for DNs.

## JNDI/LDAP Security

- Disable JNDI lookup of remote references to prevent RCE: restrict `java.naming.factory.url.pkgs`.
- On Java 8u191+/11+, remote codebase loading via JNDI is disabled by default (`com.sun.jndi.ldap.object.trustURLCodebase=false`). Do not re-enable.
