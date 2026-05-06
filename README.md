# Claude Code Configuration

Shared Claude Code configuration for the team.

## Quick Start

```bash
git clone https://git.perpetuator.io/perpetuator/claude-config.git
cd claude-config
./install.sh
```

## What Gets Installed

| File | Method | Updates |
|------|--------|---------|
| `~/.claude/settings.json` | Symlink | Auto via `git pull` |
| `~/.claude/agents/` | Symlink | Auto via `git pull` |
| `~/.claude/CLAUDE.md` | Copy (once) | Manual — personalize this |

## Updating Shared Config

After making changes to agents or settings:

```bash
cd ~/projects/claude-config
git add -A
git commit -m "describe your change"
git push
```

Team members run `git pull` to get updates.

## Uninstalling

```bash
./uninstall.sh
```

Removes symlinks and restores any backed-up files.

## Structure

```
claude-config/
├── global/
│   ├── CLAUDE.md           # Template (copied to ~/.claude/)
│   ├── settings.json       # Permissions (symlinked)
│   └── agents/             # Custom agents (symlinked)
├── hooks/
│   └── check-config-repo.sh
├── install.sh
└── uninstall.sh
```
