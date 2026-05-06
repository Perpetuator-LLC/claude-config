#!/bin/bash
set -e

CLAUDE_DIR="$HOME/.claude"

# Remove symlinks only (don't delete actual files)
for item in settings.json agents hooks/check-config-repo.sh; do
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

echo "Done. Symlinks removed."
