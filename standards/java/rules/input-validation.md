---
description: Java input validation — XXE, LDAP, SQL injection, and JDBC security
globs:
  - "**/*.java"
alwaysApply: false
---

# Java Input Validation

- **MUST** validate file names, paths, JDBC connection strings, and XML content before processing.
- **MUST** reject JDBC URLs containing dangerous directives (`INIT=`, `RUNSCRIPT`, `SCRIPT=`). Allowlist permitted JDBC prefixes (`jdbc:mysql://`, `jdbc:postgresql://`, etc.).
- **MUST** use `PreparedStatement` with `?` placeholders for all database access — never concatenate user input into SQL.

## XXE Prevention

Disable external entity resolution on all XML parsers:
- **DocumentBuilderFactory / SAXParserFactory**: Set `FEATURE_SECURE_PROCESSING` true, `disallow-doctype-decl` true, external general/parameter entities false, `ACCESS_EXTERNAL_DTD` and `ACCESS_EXTERNAL_SCHEMA` to `""`.
- **XMLInputFactory (StAX)**: Set `IS_SUPPORTING_EXTERNAL_ENTITIES` false, `SUPPORT_DTD` false.
- **TransformerFactory**: Set `ACCESS_EXTERNAL_DTD` and `ACCESS_EXTERNAL_STYLESHEET` to `""`.
- **SchemaFactory / Validator**: Set `ACCESS_EXTERNAL_DTD` and `ACCESS_EXTERNAL_SCHEMA` to `""`.

## LDAP Filter Injection

Escape special characters with `escapeSpecialCharactersForFilter()` before constructing filters. See `ldap-injection.md` for full details.

## SSRF Prevention

- Resolve the URL host to an IP and reject loopback, link-local, site-local, and any-local addresses. Block cloud metadata endpoints (`169.254.169.254`, `fd00:ec2::254`).
- Validate scheme (https only), port, and host against allowlist. Re-resolve DNS after validation to prevent TOCTOU / DNS rebinding.
- Validate both initial URL and redirect targets — follow redirects manually with same checks.
- For federation/OIDC discovery: validate discovered endpoints share the issuer's origin.

## SQL Injection Prevention

- Use `PreparedStatement` with `?` placeholders for all values. For dynamic table/column names (cannot be parameterized), validate against an allowlist.
- **JPA/Hibernate**: Use named parameters (`:name`) or `CriteriaBuilder` API — never concatenate into JPQL/HQL.
- **Stored procedures**: Use `CallableStatement` with `?` placeholders. Ensure procedure bodies also use parameterized queries internally.

## General Validation Rules

- Validate server-side. Client-side validation is UX, not security.
- Allowlists over denylists. Validate type, length, range, and format.
- For file paths: canonicalize first, then validate against allowed directories.
- For emails, URLs, phone numbers: use well-tested library validators, not custom regex.
