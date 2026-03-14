---
description: Secure file upload, download, and path traversal prevention
globs:
  - "**/*.java"
alwaysApply: false
---

# File Operations

- **MUST** restrict file uploads: validate extension (allowlist), content type, and magic bytes (e.g., Apache Tika). Enforce size limits. Sanitize file names.
- **MUST** prevent path traversal: `UPLOAD_DIR.resolve(name).normalize()` then verify result `startsWith(UPLOAD_DIR)`. For zip extraction, validate each entry path the same way (Zip Slip).
- **MUST NOT** write uploads to web-accessible directories or allow execution of uploaded files.

## Key Rules

- Admin-only upload endpoints are still attack vectors (4 of 7 historical file upload flaws were in admin APIs).
- Generate random file names for storage — never use client-supplied names directly.
- Validate extension AND content type AND magic bytes — all three are needed since extension and Content-Type header are client-controlled.
- For Carbon admin console uploads: validate through Carbon security framework.
- Set `Content-Disposition: attachment` on downloads to prevent browser rendering.
- For file paths: canonicalize with `getCanonicalPath()` first, then validate against allowed directories.
