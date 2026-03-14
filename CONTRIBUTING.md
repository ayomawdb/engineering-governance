# Contributing to WSO2 Engineering Governance

## Principles

- **Data-driven:** Base everything on real advisory data, incident history, or audit findings — not theoretical concerns
- **Agent-agnostic:** Never assume a specific AI tool. Use generic references and let `setup.sh` handle tool-specific format conversion
- **Self-contained:** Each file must work standalone when copied to a product repo
- **No duplication:** Common rules live in `engineering`. Language stacks contain only language-specific content
- **No timeline-relative language:** Use neutral descriptions, not "newer", "legacy", "old"

## Repository Structure

```
standards/
  engineering/          # Common rules for all developers (the base)
    rules/              # Core security rules (auth, input validation, etc.)
    deny-patterns.yaml  # Common deny patterns
  java/                 # Java/Carbon-specific rules (use with engineering)
    rules/
  go/                   # Go-specific rules (use with engineering)
    rules/
  sre/                  # SRE operational safety (self-contained)
    rules/
    deny-patterns.yaml  # SRE-specific deny patterns
skills/                 # All skills (installed regardless of stack)
  se-*/                 # Software engineering skills
  sre-*/                # SRE skills
  gov-*/                # Governance skills
```

**Key design decisions:**
- `engineering` contains rules common to Java and Go. Language stacks add only language-specific content on top — never repeat what's in `engineering`.
- `sre` is self-contained — an SRE may not install `engineering`.
- Skills live at the top level, not under stacks. They are all installed regardless of stack selection because they are explicitly invoked and self-contained.
- No metadata files (`.txt`, `.list`, etc.). Everything is discovered from directory structure.

## Adding a New Stack

Stacks are **auto-discovered** from `standards/` subdirectories. To add a new stack:

1. Create a directory: `standards/<stack-name>/`
2. Add any combination of:
   - `rules/` — Rule files with YAML frontmatter (see Rule File Format below)
   - `deny-patterns.yaml` — File-read and command patterns to block
3. That's it. `setup.sh` will auto-discover it. No code changes needed.

The stack appears automatically in `--help` output, interactive mode, and `--stack` validation.

If adding a **language stack** (like `typescript`):
- Put common rules that apply across languages in `engineering/rules/`
- Put only language-specific patterns in your new stack
- Update README.md standards table

### Rule File Format

Each rule file in `rules/` uses tool-neutral YAML frontmatter that `setup.sh` converts per tool:

```yaml
---
description: Brief description for agent-requested activation
globs:
  - "**/*.java"
  - "**/*.jsp"
alwaysApply: false
---

# Rule Title

- **MUST** do this
- **MUST NOT** do that
```

- `alwaysApply: true` — loaded into every conversation (use for baseline safety rules, keep lean)
- `alwaysApply: false` + `globs` — loaded only when matching files are being edited
- Use language-level globs (`**/*.go`, `**/*.java`) not name-based (`**/*Auth*`) — security concerns appear in any code file
- One rule file = one security concern. Keep focused.
- Rules are prefixed with the stack name on install (`engineering-auth-checks.md`, `go-auth-checks.md`) so files with the same name in different stacks don't collide

### Common vs Stack-Specific Rules

Before writing a rule, decide where it belongs:

| If the rule is... | Put it in... |
|-------------------|-------------|
| A general security principle (e.g., "validate JWT signatures") | `engineering/rules/` |
| A language-specific implementation (e.g., `PreparedStatement` patterns) | `java/rules/` or `go/rules/` |
| An infrastructure concern (e.g., Terraform destroy blocking) | `sre/rules/` |

If you find common content duplicated across Java and Go, extract it to `engineering/rules/`.

### Writing Effective Rules

Rules are loaded into the agent's context window, consuming tokens. Concise rules produce better adherence.

- **Target under 200 lines per file.** Most rules should be 20-60 lines.
- **Use concise MUST/MUST NOT bullets** — state what to do, not how. Agents and experienced engineers know how to write code; they need to know which pattern to use.
- **Minimize code examples.** Replace code blocks with inline code references. Instead of a 10-line PreparedStatement example, write: "Use `PreparedStatement` with `?` placeholders — never concatenate user input into SQL."
- **Keep code blocks only when** the correct pattern is non-obvious or product-specific (e.g., Carbon tenant flow, ExternalSecret CRD spec). Even then, 3-5 lines max.
- **Separate product-specific instructions.** General rules go at the top. Product-specific patterns go under a `## WSO2 Product-Specific` section at the bottom. This keeps rules portable.
- **No tables** — convert to compact bullet lists (tables waste tokens on formatting).
- **No redundant headers** — if a section has only 1-2 bullets, fold into the parent.

**Checklist:**
- [ ] Rule based on real data (advisories, incidents, audit findings)
- [ ] Lives in the right stack (common → engineering, language-specific → java/go, infra → sre)
- [ ] No duplication with `engineering` rules
- [ ] Each rule file works standalone
- [ ] Each rule file under 200 lines (ideally 20-60)
- [ ] Minimal code examples — inline references over code blocks
- [ ] Product-specific patterns in separate `## WSO2 Product-Specific` section
- [ ] Baseline rule has `alwaysApply: true` with agent safety and self-review checklist
- [ ] Domain rules use language-level glob patterns (`**/*.go`, not `**/*Handler*`)
- [ ] deny-patterns.yaml covers all sensitive file types mentioned in the rules
- [ ] Go standards split patterns by framework (stdlib vs Gin) — never mixed

## Adding Deny Patterns

Deny patterns live in `deny-patterns.yaml` files. Currently only `engineering` and `sre` have them:

- `engineering/deny-patterns.yaml` — common patterns (`.env`, credentials, keys, `rm -rf`)
- `sre/deny-patterns.yaml` — everything in engineering plus infrastructure-specific (Terraform destroy, K8s delete namespace, AWS destructive commands, WSO2 sensitive files)

`setup.sh` merges deny patterns from all selected stacks and deduplicates.

Things that belong in deny patterns (hard blocks): reading sensitive files, running destructive commands.

Things that belong in rules instead (soft guidance): `env`/`printenv` (because `env VAR=x cmd` is legitimate).

## Adding a New Skill

1. Create a directory in `skills/` with the appropriate prefix:
   - `se-` — Software engineering skills (for developers)
   - `sre-` — SRE/infrastructure skills (for DevOps teams)
   - `gov-` — Governance/maintenance skills (for repository maintainers, never deployed to product repos)
2. Use descriptive action names (`change-impact` not `blast-radius`), short enough for slash-command usage
3. Add a `SKILL.md` file following this format:

```yaml
---
name: skill-name
description: One-line description. Keep under 200 chars.
argument-hint: [description of expected arguments]
---
```

4. Structure steps as: environment detection → gather input → analysis → structured report
5. Every skill that scans git diff must handle the case where there are no changes
6. Reference standards generically (not by tool-specific filenames)

Skills are installed from `skills/` regardless of stack selection. They are explicitly invoked and self-contained — they detect repo type internally.

**Checklist:**
- [ ] SE skills that handle Go code detect the HTTP framework from `go.mod` before applying patterns
- [ ] SE skills detect repo type (framework vs extension vs product) to adjust severity
- [ ] No product names hardcoded — skills work across all WSO2 products
- [ ] Report uses structured markdown with summary header, categorized findings in tables
- [ ] No timeline-relative language

## Adding Agent Support for a New Tool

1. Add format conversion functions to `setup.sh` (`install_rules_<tool>`, skill install function)
2. Update the tool-to-file mapping tables in README.md
3. Add conversion instructions to the Manual Setup section
4. Document any tool-specific setup requirements
