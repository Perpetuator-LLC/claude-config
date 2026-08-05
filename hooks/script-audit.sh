#!/bin/bash
# Hook: PreToolUse[Bash] — Audit agent-run SCRIPTS by capturing their content before execution.
#
# Why: shell history records `bash foo.sh` / `python3 deploy.py` / `node run.js` but NOT what the
# file contained. When an agent writes-then-runs a script (the sanctioned pattern for complex flows —
# `set -e` lives in a file, not a pasted block), the file may be transient and the actual steps
# become invisible. This recorder closes that blind spot: it appends each executed script's content
# to a local audit log the moment before it runs.
#
# Covers shell (bash/sh/zsh/dash + source/.), python (python/python2/python3), and node, plus direct
# execution (`./x`, `../x`) and recognizable files (*.sh *.py *.js *.mjs *.cjs *.ts).
#
# Contract:
#   - Exit 0 ALWAYS. This is an audit recorder, never a gate — it must never block a tool call
#     and never fail the command (the safety gate is bash-safety-gate.sh's job).
#   - Emits NOTHING to stdout. Script content must not enter the agent context (secret-ban spirit);
#     it goes only to the on-disk log.
#   - Best-effort: file-based scripts only. Inline heredocs (`bash <<EOF … EOF`) are already fully
#     present in the command string, so they need no capture here.
#
# Log: ~/.claude/audit/scripts.log  (dir chmod 700; local-only, never transmitted; rotates at ~5MB).

cmd=$(echo "$CLAUDE_TOOL_INPUT" | jq -r '.command // empty' 2>/dev/null)
[[ -z "$cmd" ]] && exit 0

AUDIT_DIR="$HOME/.claude/audit"
LOG="$AUDIT_DIR/scripts.log"

# --- Extract candidate script paths ------------------------------------------------------------
# Cases: interpreter invocation (`bash|sh|zsh|dash|python|python3|node` + optional flags + file),
# sourcing (`source file` / `. file`), and direct execution (`./x`, `../x`, any recognizable
# script file). Separators (; | & ( ) < >) are flattened to spaces so tokens split cleanly.
declare -a candidates=()
armed=0
for tok in $(echo "$cmd" | tr ';|&()<>' '        '); do
  if [[ "$tok" =~ ^(bash|sh|zsh|dash|source|\.|python|python2|python3|node)$ ]]; then
    armed=1
    continue
  fi
  if [[ $armed -eq 1 ]]; then
    [[ "$tok" == -* ]] && continue      # skip interpreter flags (bash -x foo.sh, python3 -u x.py), stay armed
    candidates+=("$tok")
    armed=0
    continue
  fi
  # direct execution / recognizable script files (shell, python, node)
  if [[ "$tok" == ./* || "$tok" == ../* \
        || "$tok" == *.sh || "$tok" == *.py \
        || "$tok" == *.js || "$tok" == *.mjs || "$tok" == *.cjs || "$tok" == *.ts ]]; then
    candidates+=("$tok")
  fi
done

[[ ${#candidates[@]} -eq 0 ]] && exit 0

# --- Record -----------------------------------------------------------------------------------
mkdir -p "$AUDIT_DIR" 2>/dev/null
chmod 700 "$AUDIT_DIR" 2>/dev/null

# Rotate at ~5MB so the log can't grow unbounded (keep one previous generation).
if [[ -f "$LOG" ]] && [[ "$(wc -c <"$LOG" 2>/dev/null || echo 0)" -gt 5242880 ]]; then
  mv -f "$LOG" "$LOG.1" 2>/dev/null
fi

ts=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
declare -A seen=()
for f in "${candidates[@]}"; do
  [[ -n "${seen[$f]}" ]] && continue    # dedup within a single command
  seen[$f]=1
  [[ -f "$f" && -r "$f" ]] || continue   # unresolved ($VAR, missing, cd'd-away) → skip silently
  sha=$(shasum -a 256 "$f" 2>/dev/null | awk '{print $1}')
  {
    echo "===== ${ts} | cwd=${PWD} | script=${f} | sha256=${sha} ====="
    cat "$f"
    echo "===== end ${f} ====="
    echo
  } >> "$LOG" 2>/dev/null
done

exit 0
