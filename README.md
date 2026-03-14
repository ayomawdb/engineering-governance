# WSO2 Engineering Governance

Central hub for WSO2 engineering standards, secure development practices, and reusable skills to govern engineering practices across all WSO2 products.

## What's Here

```
engineering-governance/
├── standards/              # Engineering standards (auto-discovered by setup.sh)
│   ├── engineering/        # Common security rules for all developers
│   │   ├── rules/          # Core rules (auth, input validation, secure defaults, etc.)
│   │   └── deny-patterns.yaml
│   ├── java/               # Java/Carbon-specific rules (use with engineering)
│   │   └── rules/
│   ├── go/                 # Go-specific rules — stdlib & Gin (use with engineering)
│   │   └── rules/
│   └── sre/                # SRE/Infrastructure operational safety
│       ├── rules/
│       └── deny-patterns.yaml
├── skills/                 # Reusable agent skills (all installed regardless of stack)
│   ├── se-*/               # Software engineering skills
│   ├── sre-*/              # SRE/infrastructure skills
│   └── gov-*/              # Governance skills (repo maintenance only)
├── references/             # Internal knowledge base
│   └── product-reference.md
├── setup.sh                # Automated installer for all tools
└── .github/                # GitHub templates
```

## How Stacks Work

Stacks are **additive** — you combine them based on your role:

- **`engineering`** — Common security rules every WSO2 developer needs (agent safety, auth, input validation, secure defaults, output encoding, token lifecycle). This is the base.
- **`java`** — Java/Carbon-specific rules (Carbon CSRF, deserialization, XXE, JSP encoding, etc.). Use **with** `engineering`.
- **`go`** — Go-specific rules (stdlib vs Gin patterns, goroutine safety, `crypto/rand`, etc.). Use **with** `engineering`.
- **`sre`** — SRE operational safety (Terraform, K8s, container security, destructive commands). Self-contained — includes its own safety baseline.

| Role | Stacks to select |
|------|-----------------|
| Java developer | `engineering,java` |
| Go developer | `engineering,go` |
| SRE / DevOps | `sre` (or `engineering,sre` if also writing app code) |
| Go developer + SRE | `engineering,go,sre` |

Stacks are auto-discovered from `standards/` subdirectories — adding a new stack is just creating a new folder.

## Installation

### Claude Code — Install via Marketplace

The fastest way for Claude Code users. Run this in your project directory:

```bash
claude install wso2/engineering-governance
```

This installs all skills as slash commands (e.g., `/se-security-review`, `/se-change-impact`). To also install rules and deny patterns, run `setup.sh` after:

```bash
cd ~/.claude/plugins/wso2-engineering-governance
./setup.sh --tool claude --stack engineering,java --repo ~/projects/product-is
```

### Automated Setup

Clone this repo and run the setup script:

```bash
git clone https://github.com/wso2/engineering-governance.git
cd engineering-governance

# Interactive mode — guides you through everything:
./setup.sh

# Or specify directly:
./setup.sh --tool claude --stack engineering,go --repo ~/projects/thunder
```

| Flag | Values | Description |
|------|--------|-------------|
| `--tool` | `claude`, `copilot`, `cursor`, `windsurf` | Your AI coding tool |
| `--stack` | comma-separated | Stacks to install (e.g., `engineering,go`) |
| `--repo` | path | Target repo for rules. Claude: optional (omit for skills + deny only). Others: defaults to `.` |
| `--agents-md` | | Also generate AGENTS.md (cross-tool compatibility) |
| `--monolithic` | | Concatenate all rules into a single file |

**What gets installed:**

| Component | What it does |
|-----------|-------------|
| Rules | Conditional rules that activate based on which files you're editing |
| Deny patterns | Hard blocks on dangerous operations — fires before the agent can act |
| Skills | All skills from `skills/` — explicitly invoked, self-contained |

**Where it goes:**

Rules contain WSO2-specific patterns (CarbonContext, tenant tables, Secure Vault, etc.) and install to the target repo so they don't interfere with non-WSO2 work. For Claude Code, skills and deny patterns install to user-level so they're available across all repos.

| Component | Claude Code | Other tools |
|-----------|-------------|-------------|
| **Rules** | Repo-level (`.claude/rules/`) | Repo-level |
| **Skills** | User-level (`~/.claude/commands/`) | Repo-level (no user-level support) |
| **Deny patterns** | User-level (`~/.claude/settings.json`) | Manual (no native support) |

Rules are prefixed with the stack name on install (`engineering-auth-checks.md`, `go-auth-checks.md`) so multiple stacks can coexist without filename collisions.

User-level deny patterns have absolute precedence in Claude Code — they cannot be overridden by project settings, making them ideal for safety guardrails.

**Examples:**

```bash
# Interactive mode
./setup.sh

# Go developer using Claude Code — full setup
./setup.sh --tool claude --stack engineering,go --repo ~/projects/thunder

# Java developer — full setup
./setup.sh --tool claude --stack engineering,java --repo ~/projects/product-is

# Go + SRE
./setup.sh --tool claude --stack engineering,go,sre --repo .

# Just skills + deny patterns (no repo needed for Claude)
./setup.sh --tool claude --stack engineering

# Copilot user
./setup.sh --tool copilot --stack engineering,java --repo ~/projects/product-is

# With AGENTS.md for cross-tool compatibility
./setup.sh --tool cursor --stack engineering,go --repo ~/projects/my-app --agents-md
```

### Manual Setup

If you prefer to set up manually, here's what goes where:

#### Step 1: Copy Rules

Rules are split into individual files in `standards/<stack>/rules/` that load conditionally based on which files you're editing. Each tool uses different frontmatter — `setup.sh` converts automatically.

| Tool | Rules directory | Rule format |
|------|----------------|-------------|
| Claude Code | `.claude/rules/*.md` | `paths:` frontmatter |
| Cursor | `.cursor/rules/*.mdc` | `globs:` + `alwaysApply:` frontmatter |
| GitHub Copilot | `.github/instructions/*.instructions.md` | `applyTo:` frontmatter |
| Windsurf | `.windsurf/rules/*.md` | `trigger:` + `globs:` frontmatter |

Copy rules from each stack you need. Prefix filenames with the stack name to avoid collisions (e.g., `engineering-auth-checks.md`, `go-auth-checks.md`).

#### Step 2: Set Up Deny Patterns

The `deny-patterns.yaml` files in `standards/engineering/` and `standards/sre/` list operations to block. Convert for your tool:

**Claude Code** — each `file-read` entry becomes `Read(<pattern>)` and each `command` entry becomes `Bash(<command>)` in `~/.claude/settings.json` (user-level):

```json
{
  "permissions": {
    "deny": [
      "Read(.env)",
      "Read(**/.env)",
      "Bash(rm -rf /)"
    ]
  }
}
```

**Cursor** — add patterns to `.cursorignore` or configure deny rules in Cursor settings.

**GitHub Copilot** — no native deny pattern support. Use `.gitignore` to exclude sensitive files from context.

**Windsurf** — configure deny rules in Windsurf settings.

#### Step 3: Copy Skills

Copy all skills from `skills/*/SKILL.md`. Skills are explicitly invoked and self-contained — install all of them.

| Tool | User-level (recommended) | Repo-level (fallback) | Format |
|------|--------------------------|----------------------|--------|
| Claude Code | `~/.claude/commands/<skill-name>.md` | `.claude/commands/<skill-name>.md` | As-is |
| GitHub Copilot | N/A | `.github/prompts/<skill-name>.prompt.md` | Add `mode: 'agent'` front matter |
| Cursor | N/A | `.cursor/skills/<skill-name>/SKILL.md` | As-is |
| Windsurf | N/A | `.windsurf/workflows/<skill-name>.md` | Strip front matter |

## Standards

### Architecture

Standards are organized into stacks. The `engineering` stack contains common rules that apply to all developers. Language stacks (`java`, `go`) contain only language-specific rules — they complement `engineering`, not duplicate it.

| File/Dir | Purpose | When Used |
|----------|---------|-----------|
| `rules/` | Individual rules with conditional loading — concise MUST/MUST NOT directives | Rules activate based on files being edited |
| `deny-patterns.yaml` | File-read and command patterns to block | Always active (hard blocks) |

### Defense-in-Depth

Security enforcement uses two layers:

1. **Rules (soft)** — Natural language instructions the agent follows. Load conditionally based on which files you're editing.
2. **Deny patterns (hard blocks)** — Tool-specific blocking of dangerous operations. Fires before the agent can act.

### Available Standards

| Standard | Audience | Content |
|----------|----------|---------|
| [Engineering (Common)](standards/engineering/rules/) | All developers | 6 rules: agent safety, auth, token lifecycle, input validation, secure defaults, output encoding |
| [Java Secure Coding](standards/java/rules/) | Java developers | 11 rules: Carbon security, deserialization, XXE, JSP encoding, LDAP injection, and more |
| [Go Secure Coding](standards/go/rules/) | Go developers | 9 rules: stdlib/Gin patterns, goroutine safety, tenant isolation, TLS, and more |
| [SRE Operational Safety](standards/sre/rules/) | SRE/DevOps | 7 rules: Terraform, K8s, container security, destructive commands, WSO2 infrastructure |

## Skills

Reusable agent skills automate specific tasks. All skills are installed regardless of stack selection — they're explicitly invoked and self-contained.

### Software Engineering
| Skill | Purpose |
|-------|---------|
| [`se-security-review`](skills/se-security-review/) | Security-focused code review against WSO2 vulnerability patterns |
| [`se-change-impact`](skills/se-change-impact/) | Analyze impact of code changes across modules and products |
| [`se-tenant-check`](skills/se-tenant-check/) | Scan for multi-tenancy isolation violations |

### SRE / Operations
| Skill | Purpose |
|-------|---------|
| [`sre-deploy-readiness`](skills/sre-deploy-readiness/) | Pre-deployment security and operational checklist |

### Governance
| Skill | Purpose |
|-------|---------|
| [`gov-update-product-reference`](skills/gov-update-product-reference/) | Keep WSO2 product reference current (maintainers only) |

## Why This Exists

These standards exist to prevent the most common and preventable security mistakes from shipping in WSO2 products.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to add new standards, skills, or agent configurations.
