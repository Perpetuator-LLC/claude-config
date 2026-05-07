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

exit 0
