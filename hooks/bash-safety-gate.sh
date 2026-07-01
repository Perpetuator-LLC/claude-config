#!/bin/bash
# Hook: PreToolUse[Bash] — Block dangerous shell commands
# Exit 2 = block the tool call with message shown to Claude
# Exit 0 = allow

cmd=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)

if [[ -z "$cmd" ]]; then
  exit 0
fi

# Block destructive filesystem operations
if echo "$cmd" | grep -qE '^\s*rm\s+-rf\s+(/|~|\$HOME|\.\.)'; then
  echo "BLOCKED: Destructive rm -rf targeting root, home, or parent directory. Requires manual execution."
  exit 2
fi

# Block force pushes
if echo "$cmd" | grep -qE 'git\s+push\s+.*--force'; then
  echo "BLOCKED: Force push requires manual confirmation. Run this command yourself if intended."
  exit 2
fi

# Block hard resets
if echo "$cmd" | grep -qE 'git\s+reset\s+--hard'; then
  echo "BLOCKED: Hard reset requires manual confirmation. Run this command yourself if intended."
  exit 2
fi

# Block database destruction
if echo "$cmd" | grep -qiE '(DROP\s+(TABLE|DATABASE)|TRUNCATE\s+TABLE|DELETE\s+FROM\s+\w+\s*;?\s*$)'; then
  echo "BLOCKED: Destructive database operation. Requires manual confirmation."
  exit 2
fi

# Block piping remote scripts to shell
if echo "$cmd" | grep -qE '(curl|wget)\s+.*\|\s*(bash|sh|zsh)'; then
  echo "BLOCKED: Piping remote content to shell is unsafe. Download and review first."
  exit 2
fi

# Block eval of untrusted input
if echo "$cmd" | grep -qE '^\s*eval\s+'; then
  echo "BLOCKED: eval is dangerous. Use direct commands instead."
  exit 2
fi

# Block secret extraction — secrets must never enter agent context.
# Catches: cat/grep/rg/head/tail on .env files, keychain access, docker env dumps.
if echo "$cmd" | grep -qE 'cat\s+.*\.env|grep\s+.*\.env|rg\s+.*\.env|head\s+.*\.env|tail\s+.*\.env|less\s+.*\.env|more\s+.*\.env'; then
  echo "BLOCKED: Reading .env files would expose secrets to the AI context. Use Secure Handoff: write a script with read -rs prompts for the user to run."
  exit 2
fi

if echo "$cmd" | grep -qE 'security\s+find-generic-password|security\s+find-internet-password'; then
  echo "BLOCKED: Keychain access would expose secrets to the AI context. Keychain reads belong in runtime code only, not in development commands."
  exit 2
fi

if echo "$cmd" | grep -qE 'docker\s+(exec|inspect).*env|docker\s+(exec|inspect).*\.env|docker\s+(exec|inspect).*secret|docker\s+(exec|inspect).*token|docker\s+(exec|inspect).*password'; then
  echo "BLOCKED: Extracting secrets from containers would expose them to the AI context. Use Secure Handoff instead."
  exit 2
fi

if echo "$cmd" | grep -qE 'printenv|/proc/.*/environ'; then
  echo "BLOCKED: Reading process environment would expose secrets to the AI context."
  exit 2
fi

exit 0
