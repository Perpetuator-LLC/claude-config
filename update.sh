#!/bin/bash
# One-command sync: pull the latest config repo and re-apply the install.
# Safe to re-run — install.sh is idempotent.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_DIR"

echo "Pulling latest changes..."
git pull

echo ""
echo "Re-running install.sh to apply any new hooks/agents/MCP servers..."
bash "$REPO_DIR/install.sh"

echo ""
echo "Update complete."
