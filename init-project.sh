#!/bin/bash
set -e

# Claude Code project initializer
# Run this inside any project directory to set up Claude Code configuration

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_DIR")"

echo "Initializing Claude Code config for: $PROJECT_NAME"
echo "Directory: $PROJECT_DIR"
echo ""

cd "$PROJECT_DIR"

# --- Detect stack ---
RUNTIME=""
FRAMEWORK=""
TEST_CMD=""
LINT_CMD=""
BUILD_CMD=""

if [[ -f "package.json" ]]; then
  RUNTIME="Node.js"
  if grep -q '"typescript"' package.json 2>/dev/null; then
    RUNTIME="Node.js / TypeScript"
  fi

  # Detect framework
  for fw in react next vue nuxt svelte angular express fastify nestjs; do
    case "$fw" in
      angular)
        grep -q '"@angular/core"' package.json 2>/dev/null && FRAMEWORK="Angular" ;;
      next)
        grep -q '"next"' package.json 2>/dev/null && FRAMEWORK="Next.js" ;;
      nuxt)
        grep -q '"nuxt"' package.json 2>/dev/null && FRAMEWORK="Nuxt" ;;
      nestjs)
        grep -q '"@nestjs/core"' package.json 2>/dev/null && FRAMEWORK="NestJS" ;;
      *)
        grep -q "\"$fw\"" package.json 2>/dev/null && FRAMEWORK="$fw" ;;
    esac
  done

  # Extract commands from scripts
  TEST_CMD=$(jq -r '.scripts.test // empty' package.json 2>/dev/null)
  LINT_CMD=$(jq -r '.scripts.lint // empty' package.json 2>/dev/null)
  BUILD_CMD=$(jq -r '.scripts.build // empty' package.json 2>/dev/null)

  # Detect package manager
  PKG_MGR="npm"
  if [[ -f "yarn.lock" ]]; then PKG_MGR="yarn"; fi
  if [[ -f "pnpm-lock.yaml" ]]; then PKG_MGR="pnpm"; fi
  if [[ -f "bun.lockb" ]]; then PKG_MGR="bun"; fi

  [[ -n "$TEST_CMD" ]] && TEST_CMD="$PKG_MGR test"
  [[ -n "$LINT_CMD" ]] && LINT_CMD="$PKG_MGR run lint"
  [[ -n "$BUILD_CMD" ]] && BUILD_CMD="$PKG_MGR run build"
fi

if [[ -f "pyproject.toml" || -f "setup.py" || -f "requirements.txt" ]]; then
  RUNTIME="${RUNTIME:+$RUNTIME / }Python"
  if [[ -f "pyproject.toml" ]]; then
    grep -q 'django' pyproject.toml 2>/dev/null && FRAMEWORK="Django"
    grep -q 'fastapi' pyproject.toml 2>/dev/null && FRAMEWORK="FastAPI"
    grep -q 'flask' pyproject.toml 2>/dev/null && FRAMEWORK="Flask"
  fi
  [[ -z "$TEST_CMD" ]] && TEST_CMD="pytest"
  [[ -z "$LINT_CMD" ]] && LINT_CMD="ruff check ."
fi

if [[ -f "Cargo.toml" ]]; then
  RUNTIME="Rust"
  [[ -z "$TEST_CMD" ]] && TEST_CMD="cargo test"
  [[ -z "$BUILD_CMD" ]] && BUILD_CMD="cargo build"
  [[ -z "$LINT_CMD" ]] && LINT_CMD="cargo clippy"
fi

if [[ -f "go.mod" ]]; then
  RUNTIME="Go"
  [[ -z "$TEST_CMD" ]] && TEST_CMD="go test ./..."
  [[ -z "$BUILD_CMD" ]] && BUILD_CMD="go build ./..."
  [[ -z "$LINT_CMD" ]] && LINT_CMD="golangci-lint run"
fi

if [[ -f "Gemfile" ]]; then
  RUNTIME="Ruby"
  grep -q 'rails' Gemfile 2>/dev/null && FRAMEWORK="Rails"
  [[ -z "$TEST_CMD" ]] && TEST_CMD="bundle exec rspec"
  [[ -z "$LINT_CMD" ]] && LINT_CMD="bundle exec rubocop"
fi

# Defaults for undetected
RUNTIME="${RUNTIME:-<your runtime>}"
FRAMEWORK="${FRAMEWORK:-<your framework>}"
TEST_CMD="${TEST_CMD:-<test command>}"
LINT_CMD="${LINT_CMD:-<lint command>}"
BUILD_CMD="${BUILD_CMD:-<build command>}"

# --- Create CLAUDE.md ---
if [[ ! -f "CLAUDE.md" ]]; then
  sed \
    -e "s|__PROJECT_NAME__|$PROJECT_NAME|g" \
    -e "s|__RUNTIME__|$RUNTIME|g" \
    -e "s|__FRAMEWORK__|$FRAMEWORK|g" \
    -e "s|__TEST_CMD__|$TEST_CMD|g" \
    -e "s|__LINT_CMD__|$LINT_CMD|g" \
    -e "s|__BUILD_CMD__|$BUILD_CMD|g" \
    "$SCRIPT_DIR/templates/project-CLAUDE.md" > "CLAUDE.md"
  echo "Created CLAUDE.md — edit to add architecture details and conventions"
else
  echo "CLAUDE.md already exists — not overwriting"
fi

# --- Create .claude directory ---
mkdir -p .claude

# --- Create project-level settings.json if not exists ---
if [[ ! -f ".claude/settings.json" ]]; then
  cat > .claude/settings.json <<'SETTINGS'
{
  "permissions": {
    "allow": [],
    "deny": []
  }
}
SETTINGS
  echo "Created .claude/settings.json — add project-specific permissions if needed"
else
  echo ".claude/settings.json already exists — not overwriting"
fi

# --- Add .claude to .gitignore if appropriate ---
if [[ -f ".gitignore" ]]; then
  if ! grep -q '\.claude/workspace-context\.md' .gitignore 2>/dev/null; then
    echo "" >> .gitignore
    echo "# Claude Code auto-generated context (session-start hook)" >> .gitignore
    echo ".claude/workspace-context.md" >> .gitignore
    echo "Added .claude/workspace-context.md to .gitignore"
  fi
fi

echo ""
echo "Done! Next steps:"
echo "  1. Edit CLAUDE.md to fill in architecture details and conventions"
echo "  2. Add project-specific permissions to .claude/settings.json if needed"
echo "  3. Commit CLAUDE.md and .claude/settings.json to your repo"
