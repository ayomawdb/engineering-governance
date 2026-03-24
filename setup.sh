#!/usr/bin/env bash
# ----------------------------------------------------------------------------
# Copyright (c) 2026, WSO2 LLC. (https://www.wso2.com).
#
# WSO2 LLC. licenses this file to you under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied. See the License for the
# specific language governing permissions and limitations
# under the License.
# ----------------------------------------------------------------------------
set -euo pipefail

# WSO2 Engineering Governance — Setup Script
# Installs standards (rules + deny patterns), skills, and AGENTS.md.
#
# Stacks are auto-discovered from standards/ subdirectories.
# Each stack can provide: rules/, deny-patterns.yaml
#
# Rules contain WSO2-specific patterns and always install to the target repo.
# Skills and deny patterns are universal — for Claude Code, they install to
# user-level (~/.claude/) so they're available across all repos.
#
# Run with flags:  ./setup.sh --tool claude --stack engineering,go --repo .
# Run interactive:  ./setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ─── Auto-discover available stacks ─────────────────────────────────────────

discover_stacks() {
  local stacks=""
  for dir in "$SCRIPT_DIR"/standards/*/; do
    [[ -d "$dir" ]] || continue
    local name
    name=$(basename "$dir")
    # A valid stack has at least one of: rules/, deny-patterns.yaml
    if [[ -d "$dir/rules" || -f "$dir/deny-patterns.yaml" ]]; then
      stacks="${stacks} ${name}"
    fi
  done
  echo "$stacks" | xargs  # trim whitespace
}

AVAILABLE_STACKS=$(discover_stacks)

usage() {
  cat <<EOF
Usage: ./setup.sh [--tool <tool>] [--stack <stacks>] [--repo <path>] [options]

Install WSO2 engineering standards, deny patterns, and skills.
Run without arguments for interactive mode.

Rules contain WSO2-specific patterns (CarbonContext, tenant tables, Secure Vault,
etc.) and install to the target repo so they don't interfere with non-WSO2 work.
For Claude Code, skills and deny patterns install to user-level (~/.claude/).

Available stacks (auto-discovered from standards/):
EOF
  for stack in $AVAILABLE_STACKS; do
    echo "  $stack"
  done
  cat <<EOF

Required (or use interactive mode):
  --tool <tool>       AI coding tool: claude, copilot, cursor, windsurf
  --stack <stacks>    Comma-separated stacks (e.g., engineering,go)

Options:
  --repo <path>       Target repository for rules (defaults to . for non-Claude tools)
                      Claude Code: optional — omit to install only skills + deny patterns
  --agents-md         Also generate an AGENTS.md file (cross-tool compatibility)
  --monolithic        Use single-file standards instead of split rules
  --help              Show this help message

What gets installed:
  Rules           → Repo-level (WSO2-specific, must not leak to other projects)
  Deny patterns   → User-level for Claude (~/.claude/settings.json), manual for others
  Skills          → User-level for Claude (~/.claude/commands/), repo-level for others

Examples:
  ./setup.sh                                                        # Interactive mode
  ./setup.sh --tool claude --stack engineering,java --repo .         # Full setup for Java dev
  ./setup.sh --tool claude --stack engineering,go --repo .           # Full setup for Go dev
  ./setup.sh --tool claude --stack engineering,go,sre --repo .       # Go dev + SRE
  ./setup.sh --tool claude --stack engineering                       # Skills + deny patterns only
  ./setup.sh --tool cursor --stack engineering,go --repo ~/projects/thunder --agents-md
EOF
  exit 0
}

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Interactive Mode ────────────────────────────────────────────────────────

prompt_select() {
  local prompt="$1"
  shift
  local options=("$@")
  local count=${#options[@]}

  echo -e "\n${BOLD}${prompt}${NC}" >&2
  for i in "${!options[@]}"; do
    echo -e "  ${BOLD}$((i+1))${NC}) ${options[$i]}" >&2
  done

  while true; do
    echo -ne "\n${BLUE}▸${NC} Enter choice [1-${count}]: " >&2
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
      echo $((choice - 1))
      return 0
    fi
    echo -e "  ${RED}Invalid choice${NC}" >&2
  done
}

# Multi-select: returns one 0-indexed selection per line
prompt_multi_select() {
  local prompt="$1"
  shift
  local options=("$@")
  local count=${#options[@]}

  echo -e "\n${BOLD}${prompt}${NC}" >&2
  for i in "${!options[@]}"; do
    echo -e "  ${BOLD}$((i+1))${NC}) ${options[$i]}" >&2
  done

  while true; do
    echo -ne "\n${BLUE}▸${NC} Enter choices (comma-separated, e.g., 1,3): " >&2
    read -r choices
    local valid=true
    local selected=()
    IFS=',' read -ra parts <<< "$choices"
    for part in "${parts[@]}"; do
      part=$(echo "$part" | tr -d ' ')
      if [[ "$part" =~ ^[0-9]+$ ]] && (( part >= 1 && part <= count )); then
        selected+=("$part")
      else
        valid=false
        break
      fi
    done
    if [[ "$valid" == true && ${#selected[@]} -gt 0 ]]; then
      for s in "${selected[@]}"; do
        echo $((s - 1))
      done
      return 0
    fi
    echo -e "  ${RED}Invalid choice — enter numbers separated by commas${NC}" >&2
  done
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-y}"

  if [[ "$default" == "y" ]]; then
    echo -ne "${BLUE}▸${NC} ${prompt} [Y/n]: "
  else
    echo -ne "${BLUE}▸${NC} ${prompt} [y/N]: "
  fi

  read -r answer
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy] ]]
}

prompt_path() {
  local prompt="$1"
  local default="$2"

  echo -ne "${BLUE}▸${NC} ${prompt} [${default}]: " >&2
  read -r path
  path="${path:-$default}"
  echo "$path"
}

run_interactive() {
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}  WSO2 Engineering Governance — Setup${NC}"
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

  # Step 1: Tool selection
  local tool_options=("Claude Code" "GitHub Copilot" "Cursor" "Windsurf")
  local tool_values=("claude" "copilot" "cursor" "windsurf")
  local tool_idx
  tool_idx=$(prompt_select "Which AI coding tool do you use?" "${tool_options[@]}")
  TOOL="${tool_values[$tool_idx]}"

  # Step 2: Stack selection (multi-select, auto-discovered)
  local stack_names=()
  local stack_options=()
  for stack in $AVAILABLE_STACKS; do
    stack_names+=("$stack")
    stack_options+=("$stack")
  done

  echo ""
  echo -e "${YELLOW}Note:${NC} 'engineering' contains common security rules for all developers."
  echo "Language stacks (java, go) add language-specific rules on top."
  echo "Example: A Go developer should select both 'engineering' and 'go'."

  local selected_indices
  selected_indices=$(prompt_multi_select "Which stacks do you need? (select all that apply)" "${stack_options[@]}")

  STACKS=()
  while IFS= read -r idx; do
    STACKS+=("${stack_names[$idx]}")
  done <<< "$selected_indices"

  # Join stacks with comma for display
  STACK=$(IFS=','; echo "${STACKS[*]}")

  # Step 3: Repo path
  if [[ "$TOOL" == "claude" ]]; then
    # Claude: repo is optional — without it, only skills + deny patterns install
    echo ""
    if prompt_yes_no "Install rules into a repo? (skip to install only skills + deny patterns)" "y"; then
      REPO=$(prompt_path "Target repository path" ".")
      REPO="$(cd "$REPO" 2>/dev/null && pwd)" || { log_error "Path does not exist: $REPO"; exit 1; }
    fi
  else
    # Other tools: repo is required
    REPO=$(prompt_path "Target repository path" ".")
    REPO="$(cd "$REPO" 2>/dev/null && pwd)" || { log_error "Path does not exist: $REPO"; exit 1; }
  fi

  # Step 4: AGENTS.md (only if repo is set)
  if [[ -n "$REPO" ]]; then
    echo ""
    if prompt_yes_no "Generate AGENTS.md? (cross-tool compatibility)" "y"; then
      INSTALL_AGENTS_MD=true
    fi
  fi

  # Confirmation
  echo ""
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "  Tool:       ${BOLD}${TOOL}${NC}"
  echo -e "  Stacks:     ${BOLD}${STACK}${NC}"

  if [[ "$TOOL" == "claude" ]]; then
    if [[ -n "$REPO" ]]; then
      echo -e "  Rules:      ${BOLD}${REPO}/.claude/rules/ (repo-level)${NC}"
    else
      echo -e "  Rules:      ${BOLD}skipped (no repo)${NC}"
    fi
    echo -e "  Skills:     ${BOLD}~/.claude/commands/ (user-level)${NC}"
    echo -e "  Deny:       ${BOLD}~/.claude/settings.json (user-level)${NC}"
  else
    echo -e "  Repo:       ${BOLD}${REPO}${NC}"
  fi

  if [[ "$INSTALL_AGENTS_MD" == true ]]; then
    echo -e "  AGENTS.md:  ${BOLD}yes${NC}"
  fi
  echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  if ! prompt_yes_no "Proceed with installation?"; then
    echo ""
    log_info "Aborted."
    exit 0
  fi
}

# ─── Parse Arguments ─────────────────────────────────────────────────────────

TOOL=""
STACK=""
STACKS=()
REPO=""
INSTALL_AGENTS_MD=false
MONOLITHIC=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --tool) TOOL="$2"; shift 2 ;;
    --stack) STACK="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --agents-md) INSTALL_AGENTS_MD=true; shift ;;
    --monolithic) MONOLITHIC=true; shift ;;
    --help) usage ;;
    *) log_error "Unknown option: $1"; usage ;;
  esac
done

# If nothing provided at all, go interactive
if [[ -z "$TOOL" && -z "$STACK" && -z "$REPO" ]]; then
  run_interactive
else
  # Validate required arguments
  if [[ -z "$TOOL" ]]; then log_error "--tool is required (claude, copilot, cursor, or windsurf)"; exit 1; fi
  if [[ -z "$STACK" ]]; then log_error "--stack is required (comma-separated, e.g., engineering,go)"; exit 1; fi

  # Parse comma-separated stacks
  IFS=',' read -ra STACKS <<< "$STACK"

  # Repo handling
  if [[ "$TOOL" == "claude" ]]; then
    # Claude: --repo is optional — without it, only skills + deny patterns install
    if [[ -n "$REPO" ]]; then
      REPO="$(cd "$REPO" 2>/dev/null && pwd)" || { log_error "Repository path does not exist: $REPO"; exit 1; }
    fi
  else
    # Other tools: --repo defaults to current directory
    if [[ -z "$REPO" ]]; then
      REPO="."
      log_info "No --repo specified, using current directory"
    fi
    REPO="$(cd "$REPO" 2>/dev/null && pwd)" || { log_error "Repository path does not exist: $REPO"; exit 1; }
  fi
fi

# Validate tool
case "$TOOL" in
  claude|copilot|cursor|windsurf) ;;
  *) log_error "Invalid tool: $TOOL (must be claude, copilot, cursor, or windsurf)"; exit 1 ;;
esac

# Validate stacks against discovered stacks
for s in "${STACKS[@]}"; do
  local_valid=false
  for avail in $AVAILABLE_STACKS; do
    if [[ "$s" == "$avail" ]]; then
      local_valid=true
      break
    fi
  done
  if [[ "$local_valid" != true ]]; then
    log_error "Invalid stack: $s (available: $AVAILABLE_STACKS)"
    exit 1
  fi
done

# Warn if repo doesn't look like a git repository
if [[ -n "$REPO" && ! -d "$REPO/.git" ]]; then
  log_warn "$REPO does not appear to be a git repository"
fi

echo ""
log_info "WSO2 Engineering Governance Setup"
if [[ -n "$REPO" ]]; then
  log_info "Tool: $TOOL | Stacks: $STACK | Repo: $REPO"
else
  log_info "Tool: $TOOL | Stacks: $STACK | Skills + deny patterns only"
fi
echo ""

# ─── Frontmatter Helpers ─────────────────────────────────────────────────────

# Extract a field value from YAML frontmatter
extract_frontmatter_field() {
  local file="$1" field="$2"
  sed -n '/^---$/,/^---$/p' "$file" | grep "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//"
}

# Extract globs array from YAML frontmatter — returns one glob per line
extract_globs() {
  local file="$1"
  sed -n '/^---$/,/^---$/p' "$file" | sed -n '/^globs:/,/^[a-zA-Z]/p' | grep '^\s*-' | sed 's/^[[:space:]]*- "//' | sed 's/"$//'
}

# Check if alwaysApply is true
is_always_apply() {
  local file="$1"
  local val
  val=$(extract_frontmatter_field "$file" "alwaysApply")
  [[ "$val" == "true" ]]
}

# Strip YAML frontmatter and return body content
strip_frontmatter() {
  local file="$1"
  awk 'BEGIN{n=0} /^---$/{n++; next} n>=2{print}' "$file"
}

# ─── Deny Pattern Helpers ────────────────────────────────────────────────────

# Parse a deny-patterns.yaml file and output deny entries (one per line)
# Format: Read(pattern) or Bash(pattern)
parse_deny_patterns() {
  local deny_file="$1"
  local section=""
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    if [[ "$line" == "file-read:" ]]; then
      section="file-read"
      continue
    elif [[ "$line" == "command:" ]]; then
      section="command"
      continue
    fi

    local pattern
    pattern=$(echo "$line" | sed 's/^[[:space:]]*- "//' | sed 's/"$//')

    case "$section" in
      file-read) echo "Read(${pattern})" ;;
      command) echo "Bash(${pattern})" ;;
    esac
  done < "$deny_file"
}

# ─── Generate Monolithic File (from rules) ───────────────────────────────────

generate_monolithic_from_dirs() {
  local output="$1"
  shift
  local rules_dirs=("$@")

  {
    # Always-apply rules first, then conditional rules
    for rules_dir in "${rules_dirs[@]}"; do
      for rule_file in "$rules_dir"/*.md; do
        [[ -f "$rule_file" ]] || continue
        if is_always_apply "$rule_file"; then
          strip_frontmatter "$rule_file"
          echo ""
        fi
      done
    done
    for rules_dir in "${rules_dirs[@]}"; do
      for rule_file in "$rules_dir"/*.md; do
        [[ -f "$rule_file" ]] || continue
        if ! is_always_apply "$rule_file"; then
          strip_frontmatter "$rule_file"
          echo ""
        fi
      done
    done
  } > "$output"
}

# ─── Install Rules (always repo-level) ───────────────────────────────────────
# Rules are prefixed with stack name to avoid filename collisions across stacks.

install_rules_claude() {
  local stack_name="$1"
  local rules_dir="$2"
  local target_dir="$REPO/.claude/rules"

  mkdir -p "$target_dir"

  for rule_file in "$rules_dir"/*.md; do
    [[ -f "$rule_file" ]] || continue
    local basename
    basename=$(basename "$rule_file")
    local target_name="${stack_name}-${basename}"
    local description

    description=$(extract_frontmatter_field "$rule_file" "description")

    if is_always_apply "$rule_file"; then
      {
        echo "---"
        echo "description: \"${description}\""
        echo "---"
        echo ""
        strip_frontmatter "$rule_file"
      } > "$target_dir/$target_name"
    else
      local globs_list
      globs_list=$(extract_globs "$rule_file")
      {
        echo "---"
        echo "description: \"${description}\""
        echo "paths:"
        echo "$globs_list" | while IFS= read -r glob; do
          [[ -n "$glob" ]] && echo "  - \"$glob\""
        done
        echo "---"
        echo ""
        strip_frontmatter "$rule_file"
      } > "$target_dir/$target_name"
    fi

    log_ok "Installed rule → .claude/rules/$target_name"
  done
}

install_rules_copilot() {
  local stack_name="$1"
  local rules_dir="$2"
  local target_dir="$REPO/.github/instructions"

  mkdir -p "$target_dir"

  for rule_file in "$rules_dir"/*.md; do
    [[ -f "$rule_file" ]] || continue
    local basename
    basename=$(basename "$rule_file" .md)
    local target_name="${stack_name}-${basename}"
    local description

    description=$(extract_frontmatter_field "$rule_file" "description")

    if is_always_apply "$rule_file"; then
      {
        echo "---"
        echo "description: \"${description}\""
        echo "---"
        echo ""
        strip_frontmatter "$rule_file"
      } > "$target_dir/${target_name}.instructions.md"
    else
      local globs_csv
      globs_csv=$(extract_globs "$rule_file" | paste -sd ',' -)
      {
        echo "---"
        echo "description: \"${description}\""
        echo "applyTo: \"${globs_csv}\""
        echo "---"
        echo ""
        strip_frontmatter "$rule_file"
      } > "$target_dir/${target_name}.instructions.md"
    fi

    log_ok "Installed rule → .github/instructions/${target_name}.instructions.md"
  done
}

install_rules_cursor() {
  local stack_name="$1"
  local rules_dir="$2"
  local target_dir="$REPO/.cursor/rules"

  mkdir -p "$target_dir"

  for rule_file in "$rules_dir"/*.md; do
    [[ -f "$rule_file" ]] || continue
    local basename
    basename=$(basename "$rule_file" .md)
    local target_name="${stack_name}-${basename}"
    local description

    description=$(extract_frontmatter_field "$rule_file" "description")

    if is_always_apply "$rule_file"; then
      {
        echo "---"
        echo "description: \"${description}\""
        echo "alwaysApply: true"
        echo "---"
        echo ""
        strip_frontmatter "$rule_file"
      } > "$target_dir/${target_name}.mdc"
    else
      local globs_json
      globs_json=$(extract_globs "$rule_file" | awk '{printf "\"%s\", ", $0}' | sed 's/, $//')
      {
        echo "---"
        echo "description: \"${description}\""
        echo "globs: [${globs_json}]"
        echo "alwaysApply: false"
        echo "---"
        echo ""
        strip_frontmatter "$rule_file"
      } > "$target_dir/${target_name}.mdc"
    fi

    log_ok "Installed rule → .cursor/rules/${target_name}.mdc"
  done
}

install_rules_windsurf() {
  local stack_name="$1"
  local rules_dir="$2"
  local target_dir="$REPO/.windsurf/rules"

  mkdir -p "$target_dir"

  for rule_file in "$rules_dir"/*.md; do
    [[ -f "$rule_file" ]] || continue
    local basename
    basename=$(basename "$rule_file")
    local target_name="${stack_name}-${basename}"
    local description

    description=$(extract_frontmatter_field "$rule_file" "description")

    if is_always_apply "$rule_file"; then
      {
        echo "---"
        echo "description: \"${description}\""
        echo "trigger: always_on"
        echo "---"
        echo ""
        strip_frontmatter "$rule_file"
      } > "$target_dir/$target_name"
    else
      local globs_json
      globs_json=$(extract_globs "$rule_file" | awk '{printf "\"%s\", ", $0}' | sed 's/, $//')
      {
        echo "---"
        echo "description: \"${description}\""
        echo "trigger: glob"
        echo "globs: [${globs_json}]"
        echo "---"
        echo ""
        strip_frontmatter "$rule_file"
      } > "$target_dir/$target_name"
    fi

    log_ok "Installed rule → .windsurf/rules/$target_name"
  done
}

# ─── Install Deny Patterns ──────────────────────────────────────────────────

install_deny_patterns_claude() {
  local settings_file="$1"
  shift
  local deny_files=("$@")

  # Collect all deny entries from all stacks, then deduplicate
  local all_entries=""
  for deny_file in "${deny_files[@]}"; do
    [[ -f "$deny_file" ]] || continue
    while IFS= read -r entry; do
      all_entries="${all_entries}${entry}"$'\n'
    done < <(parse_deny_patterns "$deny_file")
  done

  # If settings.json already exists, extract existing deny entries and merge
  if [[ -f "$settings_file" ]]; then
    local existing
    existing=$(sed -n 's/.*"\(Read([^)]*)\)".*/\1/p; s/.*"\(Bash([^)]*)\)".*/\1/p' "$settings_file" 2>/dev/null || true)
    if [[ -n "$existing" ]]; then
      all_entries="${all_entries}${existing}"$'\n'
    fi
    log_info "Merging deny patterns into existing $(basename "$settings_file")"
  fi

  # Deduplicate and format
  local deny_entries=""
  local deduped
  deduped=$(echo "$all_entries" | grep -v '^$' | sort -u)

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    if [[ -n "$deny_entries" ]]; then
      deny_entries="${deny_entries},"$'\n'
    fi
    deny_entries="${deny_entries}      \"${entry}\""
  done <<< "$deduped"

  local settings_dir
  settings_dir=$(dirname "$settings_file")
  mkdir -p "$settings_dir"

  cat > "$settings_file" <<SETTINGS_EOF
{
  "permissions": {
    "deny": [
${deny_entries}
    ]
  }
}
SETTINGS_EOF

  local display_path
  if [[ "$settings_file" == "$HOME"* ]]; then
    display_path="~${settings_file#$HOME}"
  else
    display_path="$settings_file"
  fi
  log_ok "Installed deny patterns → $display_path"
}

# ─── Install AGENTS.md ───────────────────────────────────────────────────────

install_agents_md() {
  local agents_file="$REPO/AGENTS.md"
  local rules_dirs=("$@")

  {
    echo "# AGENTS.md"
    echo ""
    echo "> Generated by [WSO2 Engineering Governance](https://github.com/wso2/engineering-governance) setup.sh"
    echo ""

    for rules_dir in "${rules_dirs[@]}"; do
      for rule_file in "$rules_dir"/*.md; do
        [[ -f "$rule_file" ]] || continue
        strip_frontmatter "$rule_file"
        echo ""
      done
    done
  } > "$agents_file"

  log_ok "Installed cross-tool standard → AGENTS.md"
}

# ─── Install Skills ───────────────────────────────────────────────────────────
# Skills are auto-discovered from skills.list files in each stack directory.

# ─── Install Skills ───────────────────────────────────────────────────────────
# Skills are auto-discovered from the skills/ directory at repo root.
# All skills are installed regardless of stack selection — they are explicitly invoked and self-contained.

install_skills_to_dir() {
  local target_dir="$1"
  local display_prefix="$2"

  mkdir -p "$target_dir"
  local found=false
  for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    found=true
    local skill_name
    skill_name=$(basename "$skill_dir")
    cp "$skill_dir/SKILL.md" "$target_dir/${skill_name}.md"
    log_ok "Installed skill → ${display_prefix}${skill_name}.md"
  done
  [[ "$found" == false ]] && log_info "No skills found"
}

install_skills_copilot() {
  mkdir -p "$REPO/.github/prompts"

  for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    local skill_file="$skill_dir/SKILL.md"
    local description
    description=$(grep '^description:' "$skill_file" | head -1 | sed 's/^description: //')
    {
      echo "---"
      echo "agent: 'agent'"
      echo "description: '$description'"
      echo "---"
      echo ""
      strip_frontmatter "$skill_file"
    } > "$REPO/.github/prompts/${skill_name}.prompt.md"
    log_ok "Installed skill → .github/prompts/${skill_name}.prompt.md"
  done
}

install_skills_cursor() {
  mkdir -p "$REPO/.cursor/skills"

  for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    [[ -d "$skill_dir" ]] || continue
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    cp -r "$skill_dir" "$REPO/.cursor/skills/$skill_name"
    log_ok "Installed skill → .cursor/skills/$skill_name/"
  done
}

install_skills_windsurf() {
  mkdir -p "$REPO/.windsurf/workflows"

  for skill_dir in "$SCRIPT_DIR"/skills/*/; do
    [[ -f "$skill_dir/SKILL.md" ]] || continue
    local skill_name
    skill_name=$(basename "$skill_dir")
    strip_frontmatter "$skill_dir/SKILL.md" > "$REPO/.windsurf/workflows/${skill_name}.md"
    log_ok "Installed skill → .windsurf/workflows/${skill_name}.md"
  done
}

# ─── Execute ──────────────────────────────────────────────────────────────────

# Build list of rules directories and deny pattern files for all selected stacks
RULES_DIRS=()
DENY_FILES=()
for s in "${STACKS[@]}"; do
  local_rules="$SCRIPT_DIR/standards/$s/rules"
  if [[ -d "$local_rules" ]]; then
    RULES_DIRS+=("$local_rules")
  fi
  local_deny="$SCRIPT_DIR/standards/$s/deny-patterns.yaml"
  if [[ -f "$local_deny" ]]; then
    DENY_FILES+=("$local_deny")
  fi
done

# ── Step 1: Install rules (repo-level — skip if no repo) ──
if [[ -n "$REPO" ]]; then
  if [[ "$MONOLITHIC" == true ]]; then
    case "$TOOL" in
      claude)
        generate_monolithic_from_dirs "$REPO/CLAUDE.md" "${RULES_DIRS[@]}"
        log_ok "Installed standards → CLAUDE.md (monolithic)"
        ;;
      copilot)
        mkdir -p "$REPO/.github"
        generate_monolithic_from_dirs "$REPO/.github/copilot-instructions.md" "${RULES_DIRS[@]}"
        log_ok "Installed standards → .github/copilot-instructions.md (monolithic)"
        ;;
      cursor)
        generate_monolithic_from_dirs "$REPO/.cursorrules" "${RULES_DIRS[@]}"
        log_ok "Installed standards → .cursorrules (monolithic)"
        ;;
      windsurf)
        generate_monolithic_from_dirs "$REPO/.windsurfrules" "${RULES_DIRS[@]}"
        log_ok "Installed standards → .windsurfrules (monolithic)"
        ;;
    esac
  else
    for s in "${STACKS[@]}"; do
      local_rules="$SCRIPT_DIR/standards/$s/rules"
      [[ -d "$local_rules" ]] || continue
      log_info "Installing $s rules..."
      "install_rules_${TOOL}" "$s" "$local_rules"
    done
  fi
else
  log_info "Skipping rules (no repo specified)"
fi

# ── Step 2: Install deny patterns ──
if [[ ${#DENY_FILES[@]} -gt 0 ]]; then
  echo ""
  log_info "Installing deny patterns..."
  case "$TOOL" in
    claude)
      # User-level — universal safety, can't be overridden by project settings
      install_deny_patterns_claude "$HOME/.claude/settings.json" "${DENY_FILES[@]}"
      ;;
    copilot)
      log_warn "GitHub Copilot does not support deny patterns. Use .gitignore to exclude sensitive files."
      for f in "${DENY_FILES[@]}"; do log_info "Deny patterns reference: $f"; done
      ;;
    cursor)
      log_warn "Cursor deny patterns require manual configuration in Cursor settings."
      for f in "${DENY_FILES[@]}"; do log_info "Deny patterns reference: $f"; done
      ;;
    windsurf)
      log_warn "Windsurf deny patterns require manual configuration in Windsurf settings."
      for f in "${DENY_FILES[@]}"; do log_info "Deny patterns reference: $f"; done
      ;;
  esac
else
  echo ""
  log_info "No deny patterns for selected stacks"
fi

# ── Step 3: Install skills ──
echo ""
log_info "Installing skills..."
case "$TOOL" in
  claude)
    # User-level — available across all repos, explicitly invoked
    install_skills_to_dir "$HOME/.claude/commands" "~/.claude/commands/"
    ;;
  copilot)  install_skills_copilot ;;
  cursor)   install_skills_cursor ;;
  windsurf) install_skills_windsurf ;;
esac

# ── Step 4: AGENTS.md (if requested and repo is available) ──
if [[ "$INSTALL_AGENTS_MD" == true && -n "$REPO" ]]; then
  echo ""
  log_info "Generating AGENTS.md..."
  install_agents_md "${RULES_DIRS[@]}"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────────────────────────"
log_ok "Setup complete for $TOOL (${STACK})"
echo ""

case "$TOOL" in
  claude)
    if [[ -n "$REPO" ]]; then
      if [[ "$MONOLITHIC" == true ]]; then
        echo "  Standards installed as CLAUDE.md (monolithic mode)"
      else
        echo "  Rules installed to .claude/rules/ (repo-level)"
        echo "  Rules load conditionally based on which files you're editing."
      fi
    else
      echo "  Rules skipped (no repo — run again with --repo to install rules)"
    fi
    if [[ ${#DENY_FILES[@]} -gt 0 ]]; then
      echo "  Deny patterns installed to ~/.claude/settings.json (user-level)"
    fi
    echo "  Skills installed to ~/.claude/commands/ (user-level, all repos)"
    ;;
  copilot)
    if [[ "$MONOLITHIC" == true ]]; then
      echo "  Standards installed as .github/copilot-instructions.md (monolithic)"
    else
      echo "  Rules installed to .github/instructions/"
    fi
    echo "  Skills installed to .github/prompts/"
    ;;
  cursor)
    if [[ "$MONOLITHIC" == true ]]; then
      echo "  Standards installed as .cursorrules (monolithic)"
    else
      echo "  Rules installed to .cursor/rules/"
    fi
    echo "  Skills installed to .cursor/skills/"
    ;;
  windsurf)
    if [[ "$MONOLITHIC" == true ]]; then
      echo "  Standards installed as .windsurfrules (monolithic)"
    else
      echo "  Rules installed to .windsurf/rules/"
    fi
    echo "  Skills installed to .windsurf/workflows/"
    ;;
esac

if [[ "$INSTALL_AGENTS_MD" == true ]]; then
  echo "  AGENTS.md generated for cross-tool compatibility."
fi

echo ""
echo "  Use skills via /se-security-review, /se-change-impact, etc."
echo "  Update: Re-run this script to pull the latest standards from engineering-governance."
echo ""
