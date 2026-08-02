#!/usr/bin/env bash
# vault-backup.sh — commit + push Obsidian vaults on a timer, INDEPENDENT of Obsidian.
#
# Why this exists: the Obsidian Git plugin only runs while Obsidian is open. Close the
# app (or let an agent write files while it's closed) and nothing is committed or pushed.
# This is the safety net for that window. It COEXISTS with the plugin rather than
# replacing it — whichever runs first commits, the other finds a clean tree.
#
# LaunchAgent: ~/Library/LaunchAgents/io.perpetuator.vault-backup.plist (every 30 min + at load)
# Log:         ~/Library/Logs/vault-backup.log
#
# Design notes:
#   - `git add -A` is CORRECT here (it is the inverse of the usual "never add -A" rule):
#     a vault backup is a whole-tree snapshot of a single-human notes repo, there is no
#     curated index to clobber, and it is exactly what the Obsidian plugin does.
#   - Push is BEST-EFFORT. The git host is on the tailnet (100.64.0.4) and SSH keys are in
#     Secretive, so a push can legitimately fail when the VPN is down or the agent is
#     locked. A failed push never fails the run: the local commit is already durable and
#     the next run catches up. Same graceful-skip shape as nightly-backup.sh.
#   - Commit messages are prefixed "vault backup (timer)" so this mechanism is
#     distinguishable in history from the plugin's "vault backup:" commits.

set -uo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

VAULTS=(
  "$HOME/projects/notes-perpetuator"
  "$HOME/projects/notes-weown"
  # notes-nik is deliberately NOT here yet: 1.6 GB with ~1190 untracked files and a
  # .gitignore that only covers sync cache. It needs a media/binary policy (ignore or
  # LFS) before anything auto-commits it. Add the line once that's decided.
)

# Test hook: colon-separated repo paths override the list above, so the script can be
# exercised against throwaway repos without touching a real vault.
if [[ -n "${VAULT_BACKUP_TARGETS:-}" ]]; then
  IFS=':' read -r -a VAULTS <<< "$VAULT_BACKUP_TARGETS"
fi

LOG="${VAULT_BACKUP_LOG:-$HOME/Library/Logs/vault-backup.log}"
mkdir -p "$(dirname "$LOG")"
# keep the log from growing forever: truncate to the last 2000 lines when it passes ~1 MB
if [[ -f "$LOG" && $(stat -f%z "$LOG" 2>/dev/null || echo 0) -gt 1048576 ]]; then
  tail -n 2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
exec >> "$LOG" 2>&1

echo "════ vault-backup $(date -u +%FT%TZ)"

for V in "${VAULTS[@]}"; do
  name=$(basename "$V")

  [[ -d "$V/.git" ]] || { echo "  $name: SKIP — not a git repo"; continue; }

  # Obsidian Git may be mid-operation; don't race it. Next run catches up.
  if [[ -e "$V/.git/index.lock" ]]; then
    echo "  $name: SKIP — index.lock present (plugin busy)"
    continue
  fi

  # Never auto-commit on top of an in-progress merge/rebase — that needs a human.
  if [[ -e "$V/.git/MERGE_HEAD" || -d "$V/.git/rebase-merge" || -d "$V/.git/rebase-apply" ]]; then
    echo "  $name: SKIP — merge/rebase in progress, needs manual resolution"
    continue
  fi

  branch=$(git -C "$V" symbolic-ref --short -q HEAD) || {
    echo "  $name: SKIP — detached HEAD"; continue; }

  git -C "$V" add -A || { echo "  $name: FAIL — git add"; continue; }

  if git -C "$V" diff --cached --quiet; then
    echo "  $name: clean, nothing to commit"
  else
    n=$(git -C "$V" diff --cached --name-only | wc -l | tr -d ' ')
    if git -C "$V" commit -q -m "vault backup (timer): $(date '+%Y-%m-%d %H:%M:%S')"; then
      echo "  $name: committed $n file(s)"
    else
      echo "  $name: FAIL — git commit"; continue
    fi
  fi

  # --- push: best-effort, never fails the run ---
  if ! git -C "$V" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    echo "  $name: NO UPSTREAM for '$branch' — nothing has ever been pushed."
    echo "        fix once, by hand:  git -C $V push -u origin $branch"
    continue
  fi

  ahead=$(git -C "$V" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
  if [[ "$ahead" == "0" ]]; then
    echo "  $name: up to date with origin"
  elif git -C "$V" push -q origin "$branch" 2>&1; then
    echo "  $name: pushed $ahead commit(s)"
  else
    echo "  $name: PUSH FAILED ($ahead commit(s) local-only) — tailnet down or ssh agent locked; will retry next run"
  fi
done

echo "done $(date -u +%FT%TZ)"
exit 0   # the log is the signal; a bad push must not mark the job failed
