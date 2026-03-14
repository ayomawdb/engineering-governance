---
description: Go-specific input validation — stdlib/Gin patterns, file paths, multipart, and SSRF
globs:
  - "**/*.go"
alwaysApply: false
---

# Go Input Validation

- **stdlib:** manual validation after `json.NewDecoder(r.Body).Decode(&v)`.
- **Gin:** use `binding:"required"` struct tags and always check `c.ShouldBindJSON()` errors. Register custom validators via `binding.Validator.Engine().(*validator.Validate).RegisterValidation()`.
- **MUST** limit request body size — stdlib: `http.MaxBytesReader(w, r.Body, maxBytes)`; Gin: `c.Request.Body = http.MaxBytesReader(c.Writer, c.Request.Body, maxBytes)` before binding.
- **MUST** validate file paths: `filepath.Clean()` then `filepath.Join(baseDir, cleaned)` then verify result has `strings.HasPrefix(absPath, filepath.Clean(baseDir)+string(os.PathSeparator))`.
- **MUST** restrict multipart uploads: explicit size limit via `r.ParseMultipartForm(maxBytes)`, validate extension against allowlist, sanitize filename with `filepath.Base()`, validate content type via `http.DetectContentType()` on first 512 bytes.

## SSRF Prevention

- Allowlist hosts and require HTTPS scheme.
- Resolve DNS and block internal/loopback/link-local IPs (`IsLoopback()`, `IsPrivate()`, `IsLinkLocalUnicast()`).
- Disable redirect following: `CheckRedirect: func(...) error { return http.ErrUseLastResponse }`.
- Set explicit `Timeout` on the HTTP client.
