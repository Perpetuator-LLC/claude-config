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

# --- Install CLAUDE.md as a symlink + personal-overrides layer ---
# Pattern:
#   ~/.claude/CLAUDE.md       → symlink to repo's global/CLAUDE.md  (auto-updates)
#   ~/.claude/CLAUDE.local.md → user-personal, never overwritten   (overrides)
#
# Migration for existing ~/.claude/CLAUDE.md:
#   - already a symlink                    → re-point and continue
#   - doesn't exist                        → just create the symlink
#   - matches any historical repo version  → safe to replace with symlink
#   - differs from every committed version → user customized it: preserve
#                                            content as CLAUDE.local.md and
#                                            back up the original
GLOBAL_CLAUDE_MD="$REPO_DIR/global/CLAUDE.md"
USER_CLAUDE_MD="$CLAUDE_DIR/CLAUDE.md"
USER_LOCAL_MD="$CLAUDE_DIR/CLAUDE.local.md"

if [[ -L "$USER_CLAUDE_MD" ]]; then
    ln -sf "$GLOBAL_CLAUDE_MD" "$USER_CLAUDE_MD"
    echo "~/.claude/CLAUDE.md already symlinked — re-pointed to repo"
elif [[ ! -e "$USER_CLAUDE_MD" ]]; then
    ln -s "$GLOBAL_CLAUDE_MD" "$USER_CLAUDE_MD"
    echo "Created symlink: ~/.claude/CLAUDE.md → global/CLAUDE.md"
else
    # Regular file — check if it matches any historical version of global/CLAUDE.md
    matched=0
    if git -C "$REPO_DIR" rev-parse --git-dir >/dev/null 2>&1; then
        while IFS= read -r hash; do
            if git -C "$REPO_DIR" cat-file -p "$hash:global/CLAUDE.md" 2>/dev/null \
                | diff -q - "$USER_CLAUDE_MD" > /dev/null 2>&1; then
                matched=1
                break
            fi
        done < <(git -C "$REPO_DIR" log --format='%H' -- global/CLAUDE.md 2>/dev/null)
    fi

    ts="$(date +%Y%m%d-%H%M%S)"
    if [[ $matched -eq 1 ]]; then
        mv "$USER_CLAUDE_MD" "$CLAUDE_DIR/CLAUDE.md.bak.$ts"
        ln -s "$GLOBAL_CLAUDE_MD" "$USER_CLAUDE_MD"
        echo "Upgraded ~/.claude/CLAUDE.md to symlink (backup: CLAUDE.md.bak.$ts)"
    else
        # Customized — preserve as personal overrides if no local file yet
        if [[ ! -f "$USER_LOCAL_MD" ]]; then
            cp "$USER_CLAUDE_MD" "$USER_LOCAL_MD"
            echo "Preserved your customizations → ~/.claude/CLAUDE.local.md"
        else
            echo "~/.claude/CLAUDE.local.md already exists — leaving it untouched"
            echo "Merge from ~/.claude/CLAUDE.md.bak.$ts manually if needed"
        fi
        mv "$USER_CLAUDE_MD" "$CLAUDE_DIR/CLAUDE.md.bak.$ts"
        ln -s "$GLOBAL_CLAUDE_MD" "$USER_CLAUDE_MD"
        echo "Installed symlink: ~/.claude/CLAUDE.md (original at CLAUDE.md.bak.$ts)"
    fi
fi

# --- Ensure ~/.claude/CLAUDE.local.md exists so @import never errors ---
if [[ ! -f "$USER_LOCAL_MD" ]]; then
    cat > "$USER_LOCAL_MD" <<'EOF'
# Personal Overrides

# This file is loaded after global/CLAUDE.md.
# Add personal preferences, machine-specific paths, or rules that override
# the shared config. It is never overwritten by `git pull` or install.sh.
EOF
    echo "Created empty ~/.claude/CLAUDE.local.md (your personal overrides)"
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
echo "    ~/.claude/CLAUDE.md     → global/CLAUDE.md"
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
echo "  Personalize (never overwritten):"
echo "    ~/.claude/CLAUDE.local.md"
echo ""
echo "To set up a project:  $REPO_DIR/init-project.sh /path/to/project"
echo "To update config:     $REPO_DIR/update.sh   (or: cd $REPO_DIR && git pull && ./install.sh)"
