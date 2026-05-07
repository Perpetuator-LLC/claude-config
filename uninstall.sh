#!/bin/bash
set -e

CLAUDE_DIR="$HOME/.claude"

echo "Uninstalling Claude Code configuration..."
echo ""

# Remove symlinked hooks
if [[ -d "$CLAUDE_DIR/hooks" ]]; then
    for hook in "$CLAUDE_DIR/hooks/"*.sh; do
        if [[ -L "$hook" ]]; then
            echo "Removing hook symlink: $(basename "$hook")"
            rm "$hook"
        fi
    done
    # Remove hooks dir if empty
    rmdir "$CLAUDE_DIR/hooks" 2>/dev/null || true
fi

# Remove top-level symlinks
for item in settings.json agents; do
    target="$CLAUDE_DIR/$item"
    if [[ -L "$target" ]]; then
        echo "Removing symlink: $target"
        rm "$target"
    fi
done

# Restore backups if they exist
if [[ -f "$CLAUDE_DIR/settings.json.bak" ]]; then
    mv "$CLAUDE_DIR/settings.json.bak" "$CLAUDE_DIR/settings.json"
    echo "Restored settings.json from backup"
fi

if [[ -d "$CLAUDE_DIR/agents.bak" ]]; then
    mv "$CLAUDE_DIR/agents.bak" "$CLAUDE_DIR/agents"
    echo "Restored agents/ from backup"
fi

echo ""
echo "Done. Symlinks removed, backups restored."
echo "Note: ~/.claude/CLAUDE.md was not removed (it may contain personal customizations)."
