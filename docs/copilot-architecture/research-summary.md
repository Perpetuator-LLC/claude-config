
[[Replicating GitHub Copilot's Agent Intelligence in Claude Code]]

Here's the full playbook. The report covers everything end to end, but here's the quick orientation:

## The Core Insight

What makes Copilot's agent mode feel so capable isn't the model — it's a **three-layer prompt architecture** with a critical behavioral ingredient you can fully replicate: [dev](https://dev.to/seiwan-maikuma/a-deep-dive-into-github-copilot-agent-modes-prompt-structure-2i4g)

1. **Layer 1 (System)**: An explicit 8-step workflow baked in — understand → investigate → plan → implement → debug → test → iterate → verify — with hard rules like "read before edit" and "change strategy after 3 failed attempts on the same file"

2. **Layer 2 (Workspace)**: Dynamically assembled context including OS info, repo directory tree, and open files

3. **Layer 3 (User request + `<reminderInstructions>`)**: The secret sauce injected on *every* request: *"keep going until fully resolved, take action when possible, don't ask unnecessary questions"* — this is what gives it autonomous forward motion [dev](https://dev.to/seiwan-maikuma/a-deep-dive-into-github-copilot-agent-modes-prompt-structure-2i4g)

## How to Capture the Exact Prompts

You have two clean options:
- **VS Code Chat Debug View** (official, zero setup): `Ctrl+Shift+P` → `Developer: Toggle Chat Debug View` — shows full assembled prompts [dev](https://dev.to/seiwan-maikuma/a-deep-dive-into-github-copilot-agent-modes-prompt-structure-2i4g)
- **mitmproxy** (raw JSON with all tool schemas): add `"debug.overrideProxyUrl": "http://localhost:8080"` to VS Code `settings.json` and run `mitmproxy --mode reverse:https://copilot-proxy.githubusercontent.com` [tomasrepcik](https://tomasrepcik.dev/blog/2025/2025-08-10-vscode-inner-workings/)

## The Claude Code Implementation

Everything maps cleanly to Claude Code primitives: [github](https://github.com/microsoft/vscode/issues/254959)

- **`~/.claude/CLAUDE.md`** → replaces Layer 1 (global 8-step workflow + autonomy directive)
- **`<repo>/CLAUDE.md`** → replaces Layer 2 (stack, architecture, conventions)  
- **`UserPromptSubmit` hook with `additionalContext`** → replicates the per-request `<reminderInstructions>` injection
- **`SKILL.md` files** → encode planning and TDD sub-workflows
- **`PreToolUse`/`PostToolUse` hooks** → safety gates + auto-linting

The report includes complete, copy-ready implementations of all of these, plus a 20-item phased checklist to go from zero to full behavioral parity