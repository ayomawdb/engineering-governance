---
description: Go-specific output encoding — html/template, parameterized queries, and OS command safety
globs:
  - "**/*.go"
alwaysApply: false
---

# Go Output Encoding & Injection Prevention

- **MUST** use `html/template` (not `text/template`) for any HTML rendering — it auto-escapes by context. `template.HTML` type bypasses escaping — only use for trusted, pre-sanitized content, NEVER for user input.
- **MUST** use parameterized queries for all database access: PostgreSQL `$1, $2`; SQLite `?`; sqlx named params `:name` or `?` with `sqlx.Rebind()`.
- **MUST NOT** build dynamic SQL for `ORDER BY`, `LIMIT`, or table/column names from user input — use an allowlist mapping (e.g., `validSortCols := map[string]string{...}`) and validate before interpolating.
- **MUST NOT** pass unsanitized user input to `os/exec.Command` — pass as separate args (no shell interpretation). If shell is required, validate input strictly with `regexp.MustCompile("^[a-zA-Z0-9_-]+$")`. Never use `exec.Command("sh", "-c", "cmd " + userInput)`.
- **MUST** sanitize user input for HTML output (e.g., `html.EscapeString()`).
