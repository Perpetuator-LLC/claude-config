#!/bin/bash
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

echo "Installing Claude Code configuration..."
echo "Repository: $REPO_DIR"
echo "Target: $CLAUDE_DIR"
echo ""

# --- Create directory structure ---
mkdir -p "$CLAUDE_DIR/hooks"

# --- Backup existing files if they exist and aren't already symlinks ---
for file in settings.json; do
    if [[ -f "$CLAUDE_DIR/$file" && ! -L "$CLAUDE_DIR/$file" ]]; then
        echo "Backing up existing $file → $file.bak"
        cp "$CLAUDE_DIR/$file" "$CLAUDE_DIR/$file.bak"
    fi
done

if [[ -d "$CLAUDE_DIR/agents" && ! -L "$CLAUDE_DIR/agents" ]]; then
    echo "Backing up existing agents/ → agents.bak/"
    mv "$CLAUDE_DIR/agents" "$CLAUDE_DIR/agents.bak"
fi

# --- Symlink settings and agents (auto-update via git pull) ---
# Remove existing symlinks first — ln -sf on a dir symlink places the link *inside* the dir
ln -sf "$REPO_DIR/global/settings.json" "$CLAUDE_DIR/settings.json"
rm -f "$CLAUDE_DIR/agents"
ln -s "$REPO_DIR/global/agents" "$CLAUDE_DIR/agents"

# --- Copy CLAUDE.md only if it doesn't exist (users personalize this) ---
if [[ ! -f "$CLAUDE_DIR/CLAUDE.md" ]]; then
    cp "$REPO_DIR/global/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
    echo "Created ~/.claude/CLAUDE.md — edit to personalize"
else
    echo "~/.claude/CLAUDE.md already exists — not overwriting"
fi

# --- Symlink all hook scripts ---
for hook in "$REPO_DIR/hooks/"*.sh; do
    hook_name="$(basename "$hook")"
    ln -sf "$hook" "$CLAUDE_DIR/hooks/$hook_name"
done

# --- Make all hooks executable ---
chmod +x "$REPO_DIR/hooks/"*.sh
chmod +x "$CLAUDE_DIR/hooks/"*.sh 2>/dev/null || true

# --- Make project init script executable ---
chmod +x "$REPO_DIR/init-project.sh"

# --- Merge MCP servers into ~/.claude.json (Claude Code's config) ---
# Claude Code stores mcpServers in ~/.claude.json at the top level
CLAUDE_JSON="$HOME/.claude.json"

if command -v jq &>/dev/null; then
    # Extract servers from global/mcp.json and merge into ~/.claude.json mcpServers
    NEW_SERVERS="$(jq '.servers' "$REPO_DIR/global/mcp.json")"
    if [[ -f "$CLAUDE_JSON" ]]; then
        # Merge: preserve existing mcpServers, add/overwrite ours
        jq --argjson new "$NEW_SERVERS" '.mcpServers = (.mcpServers // {} | . * $new)' \
            "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" \
            && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON"
        echo "Merged MCP servers into $CLAUDE_JSON"
    else
        # Create a minimal ~/.claude.json with just mcpServers
        jq -n --argjson new "$NEW_SERVERS" '{mcpServers: $new}' > "$CLAUDE_JSON"
        echo "Created $CLAUDE_JSON with MCP servers"
    fi
else
    echo "⚠️  jq not found — skipping MCP server config. Install jq and re-run."
    echo "   Or manually add the servers from global/mcp.json to ~/.claude.json under 'mcpServers'"
fi

echo ""
echo "Done! Installed:"
echo ""
echo "  Symlinked (auto-update via git pull):"
echo "    ~/.claude/settings.json → global/settings.json"
echo "    ~/.claude/agents/       → global/agents/"
echo ""
echo "  Hooks (symlinked):"
for hook in "$REPO_DIR/hooks/"*.sh; do
    echo "    ~/.claude/hooks/$(basename "$hook")"
done
echo ""
echo "  MCP servers (merged into Claude Code config):"
echo "    $CLAUDE_JSON"
echo ""
echo "  Copied (personalize these):"
echo "    ~/.claude/CLAUDE.md"
echo ""
echo "To set up a project:  $REPO_DIR/init-project.sh /path/to/project"
echo "To update config:     cd $REPO_DIR && git pull"
