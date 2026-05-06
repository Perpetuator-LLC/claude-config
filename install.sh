#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_DIR/agents"

# Backup existing files if they exist and aren't already symlinks
for file in settings.json; do
    if [[ -f "$CLAUDE_DIR/$file" && ! -L "$CLAUDE_DIR/$file" ]]; then
        echo "Backing up existing $file to $file.bak"
        mv "$CLAUDE_DIR/$file" "$CLAUDE_DIR/$file.bak"
    fi
done

if [[ -d "$CLAUDE_DIR/agents" && ! -L "$CLAUDE_DIR/agents" ]]; then
    echo "Backing up existing agents/ to agents.bak/"
    mv "$CLAUDE_DIR/agents" "$CLAUDE_DIR/agents.bak"
fi

# Symlink shared files (auto-update via git pull)
ln -sf "$REPO_DIR/global/settings.json" "$CLAUDE_DIR/settings.json"
ln -sf "$REPO_DIR/global/agents" "$CLAUDE_DIR/agents"

# Copy CLAUDE.md only if it doesn't exist (personal file)
if [[ ! -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
    cp "$REPO_DIR/global/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    echo "Created ~/.claude/CLAUDE.md — edit to personalize"
else
    echo "~/.claude/CLAUDE.md already exists — not overwriting"
fi

# Install session-start hook for change detection
mkdir -p "$CLAUDE_DIR/hooks"
ln -sf "$REPO_DIR/hooks/check-config-repo.sh" "$CLAUDE_DIR/hooks/check-config-repo.sh"

echo ""
echo "Done. Symlinked:"
echo "  ~/.claude/settings.json → $REPO_DIR/global/settings.json"
echo "  ~/.claude/agents/ → $REPO_DIR/global/agents/"
echo ""
echo "To update shared config: cd $REPO_DIR && git pull"
