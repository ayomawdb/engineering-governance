---
description: WSO2 Java security context — Carbon framework, deserialization, and dependency security
globs:
  - "**/*.java"
alwaysApply: false
---

# WSO2 Java Security

## Security Context

WSO2 products handle authentication, authorization, API management, and identity for enterprise deployments. Security flaws here directly compromise customer infrastructure.

## Java Self-Review Additions

In addition to the common checklist (see engineering security-baseline):

- XML parsers configured to prevent XXE?
- Any hardcoded secrets, credentials, or logging of passwords/tokens/PII?

## Carbon-Specific Security

- **CSRF**: Use both CSRFGuard tokens AND `SameSite=Lax`/`Strict` on session cookies. Config: `repository/conf/security/Owasp.CsrfGuard.Carbon.properties`. In JSP: use `<csrf:tokenname/>`/`<csrf:tokenvalue/>` taglib for forms, AJAX headers, and multipart upload action URLs.
- **Session fixation (Carbon 4)**: Call `session.invalidate()`, then `request.getSession()`, then set authenticated attribute on the new session.
- **Log injection**: Carbon 4.4.3+ supports `%K` in log4j pattern to append UUIDs — forged entries lack valid UUIDs.
- **Admin console access**: Deny Carbon Management Console "login" permission to self-registered users. Critical for API Manager where Store users must not access admin console.

## Deserialization Security

- Use `ObjectInputFilter` (JEP 290, Java 9+): `-Djdk.serialFilter=com.wso2.expected.**;!*`
- On older Java, subclass `ObjectInputStream` and override `resolveClass()` to allowlist expected classes, throwing `InvalidClassException` for unauthorized classes.
- Mark sensitive fields `transient`. Prefer JSON/XML over Java serialization.
- Audit dependencies for known gadget libraries (Commons Collections, Spring Beans, Groovy).

## Dependency Security

- Tools: FindSecurityBugs (static), OWASP ZAP (dynamic), OWASP Dependency Check (dependency scanning).
- Check new dependencies against vulnerability databases. Known vulnerabilities require **WSO2 Security and Compliance Team review**.
- NPM packages: complete WSO2's dependency onboarding process before adoption.
- Prefer actively maintained dependencies. XML/JSON parsing libraries: always enable security features.

---

<!-- PROJECT-SPECIFIC NOTES
Teams: Add your product-specific security context below this line.
Examples:
- Product-specific auth patterns or security utilities your codebase provides
- Known sensitive areas in your codebase that need extra review
- Product-specific threat model considerations
- Custom validation or encoding utilities available in your project
-->
