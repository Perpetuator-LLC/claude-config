#!/bin/bash
# Hook: SessionEnd — Auto-clean Claude-managed worktrees
#
# When a Claude Code session ends, the worktree it ran in (under
# <project>/.claude/worktrees/<name>) stays on disk forever unless removed
# explicitly. This hook checks whether that worktree is clean and, if so,
# removes it. If anything is uncommitted or unpushed, it logs the details
# to ~/.claude/worktree-needs-attention.log and leaves the worktree alone.
#
# Disable per-session by setting CLAUDE_WORKTREE_AUTOCLEAN=0.

# Honor opt-out
if [[ "${CLAUDE_WORKTREE_AUTOCLEAN:-1}" == "0" ]]; then
  exit 0
fi

# Resolve worktree path. Claude Code passes a JSON object on stdin for
# SessionEnd hooks containing `.cwd`; fall back to $PWD if unavailable.
worktree_path=""
if [[ ! -t 0 ]]; then
  input=$(cat 2>/dev/null || true)
  if [[ -n "$input" ]] && command -v jq >/dev/null 2>&1; then
    worktree_path=$(echo "$input" | jq -r '.cwd // empty' 2>/dev/null)
  fi
fi
worktree_path="${worktree_path:-$PWD}"

# Only act on Claude-managed worktrees
case "$worktree_path" in
  */.claude/worktrees/*) ;;
  *) exit 0 ;;
esac

# Parent repo is everything before "/.claude/worktrees/..."
parent_repo="${worktree_path%/.claude/worktrees/*}"

# Sanity
[[ -d "$worktree_path" ]] || exit 0
[[ -d "$parent_repo/.git" ]] || exit 0

# Inspect cleanliness from inside the worktree
cd "$worktree_path" || exit 0

uncommitted=$(git status --porcelain 2>/dev/null)
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

unpushed=""
if git rev-parse "@{u}" >/dev/null 2>&1; then
  unpushed=$(git log @{u}..HEAD --oneline 2>/dev/null)
fi

ts="[$(date '+%Y-%m-%d %H:%M:%S')]"
log_dir="$HOME/.claude"
clean_log="$log_dir/worktree-cleanup.log"
dirty_log="$log_dir/worktree-needs-attention.log"
mkdir -p "$log_dir"

if [[ -z "$uncommitted" && -z "$unpushed" ]]; then
  # CLEAN — auto-remove. Must cd out of worktree first.
  cd "$parent_repo" || exit 0
  if git worktree remove --force "$worktree_path" 2>/dev/null; then
    echo "$ts removed clean worktree: $worktree_path (branch: $branch)" >> "$clean_log"
  else
    echo "$ts FAILED to remove worktree: $worktree_path (branch: $branch)" >> "$clean_log"
  fi
  exit 0
fi

# DIRTY — leave it, log, notify
{
  echo "$ts ===================="
  echo "$ts worktree: $worktree_path"
  echo "$ts branch:   $branch"
  if [[ -n "$uncommitted" ]]; then
    echo "$ts uncommitted changes:"
    echo "$uncommitted" | sed "s|^|$ts   |"
  fi
  if [[ -n "$unpushed" ]]; then
    echo "$ts unpushed commits (on branch $branch):"
    echo "$unpushed" | sed "s|^|$ts   |"
  fi
  echo "$ts to inspect:   cd $worktree_path"
  echo "$ts to discard:   git worktree remove --force $worktree_path"
} >> "$dirty_log"

basename_wt=$(basename "$worktree_path")
if [[ "$(uname)" == "Darwin" ]]; then
  osascript -e "display notification \"Worktree '$basename_wt' has uncommitted work — see ~/.claude/worktree-needs-attention.log\" with title \"Claude Code: cleanup deferred\"" 2>/dev/null
elif command -v notify-send >/dev/null 2>&1; then
  notify-send "Claude Code: cleanup deferred" "Worktree '$basename_wt' has uncommitted work — see ~/.claude/worktree-needs-attention.log" 2>/dev/null
fi

exit 0
