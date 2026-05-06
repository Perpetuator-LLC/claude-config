#!/bin/bash
# Hook: Check for uncommitted changes in claude-config repo
# Place in ~/.claude/hooks/ and reference from settings.json if you want auto-check

REPO_DIR="$(dirname "$(dirname "$(readlink -f "$0")")")"

if [[ -d "$REPO_DIR/.git" ]]; then
    cd "$REPO_DIR"
    if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
        echo "⚠️  claude-config has uncommitted changes: $REPO_DIR"
        echo "   Run: cd $REPO_DIR && git add -A && git commit -m 'update config' && git push"
    fi
fi
