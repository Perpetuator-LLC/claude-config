# Claude Code Bootstrap

Get Claude Code performing like GitHub Copilot's agent mode — autonomous, disciplined, and safe. This project installs a battle-tested configuration that replicates the behavioral architecture that makes Copilot + Opus so effective.

## What This Does

GitHub Copilot's agent mode works well because of a **three-layer prompt architecture** with an **8-step autonomous workflow** and **reminder instructions** injected on every request. This project replicates all of that in Claude Code using `CLAUDE.md`, hooks, and custom agents.

### Key Features

- **8-Step Workflow** — Understand → Investigate → Plan → Implement → Debug → Test → Iterate → Verify
- **Autonomy Directive** — "Keep going until done, take action, don't ask unnecessary questions" injected on every prompt
- **Safety Gates** — PreToolUse hooks block `rm -rf /`, `git push --force`, credential file writes, and other dangerous operations
- **Auto Syntax Check** — PostToolUse hook runs language-specific syntax validation after every file edit
- **Workspace Awareness** — SessionStart hook auto-generates a file tree and stack detection for each project
- **Desktop Notifications** — Get notified when Claude finishes a task
- **Custom Agents** — Code reviewer, bug investigator, and codebase explorer (read-only)

## Quick Start

### 1. Install (machine-level)

```bash
git clone <repo-url> ~/claude-config
cd ~/claude-config
./install.sh
```

This sets up `~/.claude/` with the global configuration. Hooks and agents are symlinked, so `git pull` updates them automatically.

### 2. Initialize a project (per-project)

```bash
cd /path/to/your/project
~/claude-config/init-project.sh
```

This creates a project-level `CLAUDE.md` with auto-detected stack info. Edit it to add your architecture details and conventions.

## What Gets Installed

### Machine-Level (`~/.claude/`)

| File | Method | Purpose |
|------|--------|---------|
| `CLAUDE.md` | Copy (once) | 8-step workflow + autonomy directive + safety rules |
| `settings.json` | Symlink | Hook wiring, permissions, safety denials |
| `agents/` | Symlink | Code reviewer, investigator, explorer |
| `hooks/*.sh` | Symlink | All lifecycle hooks (see below) |

### Project-Level (via `init-project.sh`)

| File | Method | Purpose |
|------|--------|---------|
| `CLAUDE.md` | Generated | Stack, commands, architecture, conventions |
| `.claude/settings.json` | Generated | Project-specific permissions |

## Hook System

Hooks are the mechanism for replicating Copilot's behavioral injection. They fire at specific lifecycle points:

| Hook | Script | When | What |
|------|--------|------|------|
| `UserPromptSubmit` | `reminder-instructions.sh` | Every prompt | Injects autonomy directive ("keep going, take action") |
| `SessionStart` | `session-start.sh` | New session | Generates workspace file tree + stack detection |
| `PreToolUse[Bash]` | `bash-safety-gate.sh` | Before shell commands | Blocks `rm -rf`, force push, `DROP TABLE`, pipe-to-shell |
| `PreToolUse[Write]` | `write-safety-gate.sh` | Before file writes | Blocks writes to `.env`, credentials, key files |
| `PostToolUse[Write\|Edit]` | `post-edit-lint.sh` | After file edits | Auto syntax-check (Python, TS, JS, Ruby, Go, JSON, YAML, shell) |
| `Stop` | `notify-complete.sh` | Task finishes | Desktop notification (macOS + Linux) |
| `Stop` | `check-config-repo.sh` | Task finishes | Warns if this config repo has uncommitted changes |

## Agents

Custom agents run as read-only subagents for specific tasks:

| Agent | Purpose |
|-------|---------|
| `code-reviewer` | Reviews code for correctness, security, performance, conventions |
| `investigator` | Traces bugs to root cause without making changes |
| `explorer` | Explores codebase structure and answers questions |

Usage in Claude Code: `/agent:code-reviewer` or `/agent:investigator`

## Architecture: How It Maps to Copilot

```
Copilot Layer                    Claude Code Equivalent
─────────────────────────────    ──────────────────────────────
Layer 1: System Prompt           ~/.claude/CLAUDE.md
  └─ 8-step workflow               └─ Same workflow, same rules
  └─ Security requirements          └─ OWASP, no secrets
  └─ Implementation discipline      └─ No over-engineering

Layer 2: Workspace Info          Auto + SessionStart hook
  └─ OS, directory tree              └─ .claude/workspace-context.md
  └─ Stack detection                 └─ Auto-detected at session start

Layer 3: Reminder Instructions   UserPromptSubmit hook
  └─ "Keep going, take action"      └─ reminder-instructions.sh
  └─ Injected on every request       └─ additionalContext injection

Safety Gates                     PreToolUse hooks
  └─ Confirm destructive ops         └─ bash-safety-gate.sh
  └─ Block credential writes         └─ write-safety-gate.sh

Post-Edit Validation             PostToolUse hooks
  └─ Auto lint/compile               └─ post-edit-lint.sh

Custom Instructions              Project CLAUDE.md
  └─ .github/copilot-instructions   └─ <repo>/CLAUDE.md
```

## Customization

### Personal Preferences

Edit `~/.claude/CLAUDE.md` directly. This file is copied (not symlinked), so your changes persist across updates. Add your preferred stack, coding style, or project-specific rules.

### Per-Project Rules

Edit `<project>/CLAUDE.md` to specify:
- Stack and framework details
- Build/test/lint commands
- Architecture patterns
- Naming conventions
- Files to never touch

### Adding Custom Agents

Create a `.md` file in `global/agents/` with YAML frontmatter:

```yaml
---
name: my-agent
description: What this agent does. When to use it.
tools: [Read, Glob, Grep]
---

Your agent instructions here...
```

### Disabling a Hook

Remove or comment out the hook entry in `global/settings.json`. Changes propagate via symlink.

## Updating

```bash
cd ~/claude-config
git pull
```

Symlinked files (settings, agents, hooks) update automatically. `CLAUDE.md` files are personal copies and won't be overwritten.

## Uninstalling

```bash
cd ~/claude-config
./uninstall.sh
```

Removes symlinks and restores any backed-up files. Your `~/.claude/CLAUDE.md` is preserved.

## Container / CI Usage

For agentic containers or CI environments, run the install non-interactively:

```bash
git clone <repo-url> /opt/claude-config
cd /opt/claude-config
./install.sh
```

The hooks and configuration work in any environment where Claude Code runs. The `session-start.sh` hook adapts to whatever project directory Claude is working in.

## Structure

```
claude-config/
├── install.sh                  # Machine-level install
├── uninstall.sh                # Remove global config
├── init-project.sh             # Per-project setup
├── global/
│   ├── CLAUDE.md               # 8-step workflow + autonomy (copied)
│   ├── settings.json           # Hooks + permissions (symlinked)
│   └── agents/
│       ├── code-reviewer.md    # Code review agent
│       ├── investigator.md     # Bug investigation agent
│       └── explorer.md         # Codebase Q&A agent
├── hooks/
│   ├── reminder-instructions.sh  # Autonomy injection
│   ├── bash-safety-gate.sh       # Dangerous command blocker
│   ├── write-safety-gate.sh      # Credential file protector
│   ├── post-edit-lint.sh         # Auto syntax check
│   ├── session-start.sh          # Workspace context generator
│   ├── notify-complete.sh        # Desktop notification
│   └── check-config-repo.sh     # Config repo status check
├── templates/
│   └── project-CLAUDE.md        # Project CLAUDE.md template
└── docs/
    └── copilot-architecture/    # Research on Copilot's internals
```

## Background

This configuration is based on detailed analysis of GitHub Copilot's agent mode system prompt, tool calling loop, and behavioral architecture. The research documents in `docs/` contain the full breakdown of how Copilot's three-layer prompt system works and how each component maps to Claude Code primitives.

See `docs/copilot-architecture/` for the complete technical analysis.
