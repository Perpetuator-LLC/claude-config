#!/bin/bash
# Hook: PreToolUse[Write] — Prevent writing to secrets and sensitive files
# Exit 2 = block the tool call with message shown to Claude
# Exit 0 = allow

path=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // .path // empty' 2>/dev/null)

if [[ -z "$path" ]]; then
  exit 0
fi

# Block writes to environment/secrets files
if echo "$path" | grep -qE '(\.env$|\.env\.(prod|production|staging|live)|\.env\.local$)'; then
  echo "BLOCKED: Cannot write to environment files. These may contain secrets. Edit manually."
  exit 2
fi

# Block writes to credential/key files
if echo "$path" | grep -qiE '(credentials|secrets|\.pem$|\.key$|\.p12$|\.pfx$|\.jks$|id_rsa|id_ed25519|\.ssh/|\.aws/|\.gcloud/)'; then
  echo "BLOCKED: Cannot write to credential or key files. Edit manually."
  exit 2
fi

# Block writes to CI/CD secrets
if echo "$path" | grep -qE '(\.github/.*secret|vault\.y[a]?ml|\.vault-pass)'; then
  echo "BLOCKED: Cannot write to CI/CD secrets files. Edit manually."
  exit 2
fi

exit 0
