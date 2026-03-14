---
description: Java XSS prevention — contextual output encoding in JSP, React, and CSP
globs:
  - "**/*.java"
  - "**/*.jsp"
  - "**/*.jspx"
alwaysApply: false
---

# Java Output Encoding

- **MUST** use OWASP Java Encoder, JSTL `<c:out>` / `fn:escapeXml()`, or React's JSX auto-escaping.
- **MUST NOT** use `dangerouslySetInnerHTML` (React), `<%= %>` unescaped (JSP), or raw string concatenation into HTML/JS.

## Encoding by Context

- **HTML body**: `Encode.forHtml()` or `<c:out>`
- **HTML attribute**: `Encode.forHtmlAttribute()`
- **JavaScript string**: `Encode.forJavaScript()`
- **URL parameter**: `Encode.forUriComponent()`
- **CSS value**: `Encode.forCssString()`
- **JSON in `<script>`**: `Encode.forJavaScriptBlock(jsonString)` — NOT `Encode.forHtml()` inside `<script>`

## React / TypeScript

- JSX auto-escapes by default — do NOT bypass with `dangerouslySetInnerHTML`.
- Validate URL scheme in `href` (allow `http:`, `https:` only). Block `javascript:` URIs.
- Use **DOMPurify** for any raw HTML rendering, `findDomNode()`, and iframe `src` sanitization.
- Use **react-markdown** with `skipHtml` + **rehype-sanitize**. Contact WSO2 security team before enabling HTML.
- Use **serialize-javascript** (not `JSON.stringify`) for SSR state serialization.
- Never pass user input to `eval()`, `Function()`, or `setTimeout(string)`.

## HTML Sanitization

When rendering user-supplied HTML is required, use OWASP Java HTML Sanitizer: `Sanitizers.FORMATTING.and(Sanitizers.LINKS).sanitize(untrustedHtml)`.

## Content Security Policy (CSP)

- Set `Content-Security-Policy` on all HTML responses. Minimum: `default-src 'self'; script-src 'self'; object-src 'none'; base-uri 'self'`.
- Eliminate `'unsafe-inline'` for `script-src` — use nonce-based or hash-based CSP. Avoid `'unsafe-eval'`.
- For Carbon console JSPs with inline scripts: add nonce-based CSP as migration path.
- Set `X-Content-Type-Options: nosniff`.

## Common WSO2 XSS Locations

- Authentication endpoint JSP pages (form parameters, error messages)
- OAuth2 authorization flow (redirect URIs, scope parameters, form_post responses)
- Carbon Management Console (registry, data sources, user management)
- API Manager Developer Portal (signup, search, API display)
- Recovery portal (callback URLs, error parameters)
