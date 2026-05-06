#!/bin/bash
# Hook: Check for uncommitted changes in claude-config repo
# Runs on Stop event - only outputs if there are uncommitted changes

# Resolve symlink (works on macOS and Linux)
resolve_path() {
    local path="$1"
    while [[ -L "$path" ]]; do
        local dir="$(cd "$(dirname "$path")" && pwd)"
        path="$(readlink "$path")"
        [[ "$path" != /* ]] && path="$dir/$path"
    done
    echo "$(cd "$(dirname "$path")" && pwd)/$(basename "$path")"
}

SCRIPT_PATH="$(resolve_path "$0")"
REPO_DIR="$(dirname "$(dirname "$SCRIPT_PATH")")"

if [[ -d "$REPO_DIR/.git" ]]; then
    cd "$REPO_DIR"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        echo "⚠️  claude-config has uncommitted changes"
        echo "   cd $REPO_DIR && git add -A && git commit -m 'update' && git push"
    fi
fi
