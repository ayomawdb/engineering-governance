---
description: Core output encoding and injection prevention rules
alwaysApply: true
---

# Output Encoding — Core Rules

- **MUST** use framework-provided contextual encoding for all user-controlled output.
- **MUST NOT** concatenate user input into SQL, OS commands, or template directives.
