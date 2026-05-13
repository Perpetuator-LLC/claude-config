#!/bin/bash
# Hook: SessionStart — Generate workspace context for Claude
# Creates a compact file tree and identifies key entry points
# Output goes to .claude/workspace-context.md in the current project

CONTEXT_DIR=".claude"
CONTEXT_FILE="$CONTEXT_DIR/workspace-context.md"

# Only generate if we're in a git repo or project directory
if [[ ! -d ".git" && ! -f "package.json" && ! -f "pyproject.toml" && ! -f "Cargo.toml" && ! -f "go.mod" && ! -f "Makefile" && ! -f "Gemfile" ]]; then
  exit 0
fi

mkdir -p "$CONTEXT_DIR"

{
  echo "# Workspace Context (auto-generated at session start)"
  echo ""
  echo "## File Tree"
  echo '```'

  # Generate compact tree, excluding common non-source directories
  if command -v tree &>/dev/null; then
    tree -I 'node_modules|.git|dist|build|__pycache__|.venv|venv|.mypy_cache|.pytest_cache|.next|.nuxt|target|vendor|coverage|.turbo|.cache' \
      --dirsfirst -L 3 --noreport 2>/dev/null | head -150
  else
    find . -type f \
      -not -path "*/node_modules/*" \
      -not -path "*/.git/*" \
      -not -path "*/dist/*" \
      -not -path "*/build/*" \
      -not -path "*/__pycache__/*" \
      -not -path "*/.venv/*" \
      -not -path "*/venv/*" \
      -not -path "*/target/*" \
      -not -path "*/vendor/*" \
      -not -path "*/.next/*" \
      -not -path "*/.nuxt/*" \
      -not -path "*/coverage/*" \
      -not -path "*/.turbo/*" \
      -not -path "*/.cache/*" \
      | sort | head -150
  fi

  echo '```'
  echo ""

  # Detect stack from project files
  echo "## Detected Stack"

  if [[ -f "package.json" ]]; then
    echo "- **Runtime**: Node.js"
    if grep -q '"typescript"' package.json 2>/dev/null; then
      echo "- **Language**: TypeScript"
    fi
    if grep -q '"react"' package.json 2>/dev/null; then
      echo "- **Framework**: React"
    elif grep -q '"@angular/core"' package.json 2>/dev/null; then
      echo "- **Framework**: Angular"
    elif grep -q '"vue"' package.json 2>/dev/null; then
      echo "- **Framework**: Vue"
    elif grep -q '"svelte"' package.json 2>/dev/null; then
      echo "- **Framework**: Svelte"
    elif grep -q '"next"' package.json 2>/dev/null; then
      echo "- **Framework**: Next.js"
    elif grep -q '"nuxt"' package.json 2>/dev/null; then
      echo "- **Framework**: Nuxt"
    elif grep -q '"express"' package.json 2>/dev/null; then
      echo "- **Framework**: Express"
    elif grep -q '"fastify"' package.json 2>/dev/null; then
      echo "- **Framework**: Fastify"
    fi
    # Extract test command
    test_cmd=$(jq -r '.scripts.test // empty' package.json 2>/dev/null)
    if [[ -n "$test_cmd" ]]; then
      echo "- **Test**: \`npm test\` → $test_cmd"
    fi
    # Extract lint command
    lint_cmd=$(jq -r '.scripts.lint // empty' package.json 2>/dev/null)
    if [[ -n "$lint_cmd" ]]; then
      echo "- **Lint**: \`npm run lint\` → $lint_cmd"
    fi
  fi

  if [[ -f "pyproject.toml" || -f "setup.py" || -f "requirements.txt" ]]; then
    echo "- **Runtime**: Python"
    if [[ -f "pyproject.toml" ]]; then
      if grep -q 'django' pyproject.toml 2>/dev/null; then
        echo "- **Framework**: Django"
      elif grep -q 'fastapi' pyproject.toml 2>/dev/null; then
        echo "- **Framework**: FastAPI"
      elif grep -q 'flask' pyproject.toml 2>/dev/null; then
        echo "- **Framework**: Flask"
      fi
    fi
  fi

  if [[ -f "Cargo.toml" ]]; then
    echo "- **Runtime**: Rust"
  fi

  if [[ -f "go.mod" ]]; then
    echo "- **Runtime**: Go"
  fi

  if [[ -f "Gemfile" ]]; then
    echo "- **Runtime**: Ruby"
    if grep -q 'rails' Gemfile 2>/dev/null; then
      echo "- **Framework**: Rails"
    fi
  fi

  # Detect AI-instruction files from other coding tools.
  # Claude is told (via global CLAUDE.md) to read any of these that exist.
  echo ""
  echo "## Other AI Instruction Files"
  found_any=0
  # Single-file candidates
  for f in \
    ".github/copilot-instructions.md" \
    "AGENTS.md" \
    ".cursorrules" \
    ".windsurfrules" \
    ".junie/guidelines.md" \
    "GEMINI.md" \
    "CONVENTIONS.md" \
    ".aider.conf.yml" \
    ".continuerules"
  do
    if [[ -f "$f" ]]; then
      echo "- \`$f\`"
      found_any=1
    fi
  done
  # .clinerules can be a file OR a directory
  if [[ -f ".clinerules" ]]; then
    echo "- \`.clinerules\`"
    found_any=1
  elif [[ -d ".clinerules" ]]; then
    for f in .clinerules/*.md; do
      [[ -f "$f" ]] && { echo "- \`$f\`"; found_any=1; }
    done
  fi
  # Directory-based rule sets
  for dir in ".cursor/rules" ".roo/rules" ".continue/rules"; do
    if [[ -d "$dir" ]]; then
      for f in "$dir"/*.md "$dir"/*.mdc; do
        [[ -f "$f" ]] && { echo "- \`$f\`"; found_any=1; }
      done
    fi
  done
  if [[ $found_any -eq 0 ]]; then
    echo "_None detected._"
  else
    echo ""
    echo "_Read these on the first task — they may contain project conventions, forbidden patterns, or build/test commands. See global CLAUDE.md for conflict-resolution rules._"
  fi

  echo ""
  echo "---"
  echo "*Read this file at the start of any task for workspace awareness.*"

} > "$CONTEXT_FILE" 2>/dev/null

exit 0
