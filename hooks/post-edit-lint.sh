#!/bin/bash
# Hook: PostToolUse[Write|Edit] — Auto syntax-check after file edits
# Runs a quick syntax check based on file extension
# Exit 0 always — this is advisory, not blocking

path=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.file_path // .path // empty' 2>/dev/null)

if [[ -z "$path" || ! -f "$path" ]]; then
  exit 0
fi

ext="${path##*.}"

case "$ext" in
  py)
    python3 -m py_compile "$path" 2>&1 | head -10
    ;;
  ts|tsx)
    if command -v npx &>/dev/null && [[ -f "$(dirname "$path")/tsconfig.json" || -f "./tsconfig.json" ]]; then
      npx tsc --noEmit --pretty false 2>&1 | grep -A2 "$(basename "$path")" | head -15
    fi
    ;;
  js|jsx|mjs)
    if command -v node &>/dev/null; then
      node --check "$path" 2>&1 | head -10
    fi
    ;;
  rb)
    if command -v ruby &>/dev/null; then
      ruby -c "$path" 2>&1 | head -10
    fi
    ;;
  go)
    if command -v gofmt &>/dev/null; then
      gofmt -e "$path" >/dev/null 2>&1 | head -10
    fi
    ;;
  rs)
    # Rust — just check syntax of the single file isn't practical,
    # so skip unless cargo check is fast
    ;;
  json)
    if command -v jq &>/dev/null; then
      jq empty "$path" 2>&1 | head -5
    elif command -v python3 &>/dev/null; then
      python3 -m json.tool "$path" >/dev/null 2>&1 | head -5
    fi
    ;;
  yaml|yml)
    if command -v python3 &>/dev/null; then
      python3 -c "import yaml; yaml.safe_load(open('$path'))" 2>&1 | head -5
    fi
    ;;
  sh|bash|zsh)
    if command -v bash &>/dev/null; then
      bash -n "$path" 2>&1 | head -5
    fi
    ;;
esac

exit 0
