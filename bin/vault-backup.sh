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

# --- discovery -------------------------------------------------------------
# Vaults are DISCOVERED, not listed. Any git repo directly under ~/projects that is
# an Obsidian vault (has a .obsidian/ directory) is backed up automatically.
#
# This is deliberate: the bug this script was written to fix was "a vault was created
# and nobody remembered to wire it up" (notes-weown sat unpushed from graduation on
# 2026-07-29 until 2026-08-02). A hardcoded list reproduces that failure every time a
# vault is graduated. Discovery means the next one is covered the moment it exists.
#
# Opt out by dropping a `.no-vault-backup` file in the vault root (put the reason
# inside it). Large first commits are refused by the size guard below rather than
# silently committed — so discovery can never blindly swallow an unprepared repo.

VAULT_PARENT="${VAULT_BACKUP_PARENT:-$HOME/projects}"
MAX_FILES="${VAULT_BACKUP_MAX_FILES:-750}"
MAX_MB="${VAULT_BACKUP_MAX_MB:-250}"

discover_vaults() {
  local d
  for d in "$VAULT_PARENT"/*/; do
    d="${d%/}"
    [[ -d "$d/.git" ]] || continue
    [[ -d "$d/.obsidian" ]] || continue
    if [[ -e "$d/.no-vault-backup" ]]; then
      echo "  $(basename "$d"): SKIP — .no-vault-backup present" >&2
      continue
    fi
    printf '%s\n' "$d"
  done
}

LOG="${VAULT_BACKUP_LOG:-$HOME/Library/Logs/vault-backup.log}"
mkdir -p "$(dirname "$LOG")"
# keep the log from growing forever: truncate to the last 2000 lines when it passes ~1 MB
if [[ -f "$LOG" && $(stat -f%z "$LOG" 2>/dev/null || echo 0) -gt 1048576 ]]; then
  tail -n 2000 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
fi
exec >> "$LOG" 2>&1

echo "════ vault-backup $(date -u +%FT%TZ)"

# Self-heal the vault-store symlinks first (Sovereign Data Architecture §2): if a
# vault has a .vault-store config but its _store link is missing/stale (fresh clone,
# new machine), repair it here so attachments keep landing on the NAS. Best-effort —
# an unmounted NAS just logs and moves on; the backup itself never depends on it.
LINKER="$(dirname "${BASH_SOURCE[0]}")/vault-store-link.sh"
[[ -x "$LINKER" ]] && bash "$LINKER" 2>&1 | sed 's/^/  [store] /'

# Discovery runs AFTER the log redirect so opt-out skips land in the log, not the terminal.
# Test hook: colon-separated repo paths bypass discovery, so the script can be
# exercised against throwaway repos without touching a real vault.
if [[ -n "${VAULT_BACKUP_TARGETS:-}" ]]; then
  IFS=':' read -r -a VAULTS <<< "$VAULT_BACKUP_TARGETS"
else
  VAULTS=()
  while IFS= read -r line; do VAULTS+=("$line"); done < <(discover_vaults)
fi

[[ ${#VAULTS[@]} -gt 0 ]] || echo "  (no vaults discovered under $VAULT_PARENT)"

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

  # --- size guard: MEASURED BEFORE STAGING --------------------------------
  # This must run before `git add`, not after. Staging writes every file's blob
  # into .git/objects, and `git reset` only unstages — it does not delete those
  # objects. Guarding after the add therefore leaves the entire refused payload
  # behind as loose garbage. Observed in the wild on notes-nik: .git grew from
  # 624 MB to 916 MB because refused runs had already written ~1 GB of blobs.
  # Measuring first means a refused vault is never touched at all.
  #
  # An unprepared vault (no media policy, a stray .venv, an un-ignored export)
  # must not be swallowed whole by an automated commit. Once the first big commit
  # is made deliberately by hand, increments are small and this never fires again.
  # Override per-vault with .vault-backup-allow-large.
  pending=$( { git -C "$V" ls-files --others --exclude-standard -z
               git -C "$V" ls-files --modified -z; } | tr -dc '\0' | wc -c | tr -d ' ')

  if (( pending == 0 )); then
    echo "  $name: clean, nothing to commit"
  else
    if [[ ! -e "$V/.vault-backup-allow-large" ]]; then
      mb=$( { git -C "$V" ls-files --others --exclude-standard -z
              git -C "$V" ls-files --modified -z; } \
            | tr '\0' '\n' \
            | while IFS= read -r f; do [ -f "$V/$f" ] && stat -f%z "$V/$f"; done \
            | awk '{s+=$1} END {printf "%.0f", s/1048576}')
      mb=${mb:-0}
      if (( pending > MAX_FILES )) || (( mb > MAX_MB )); then
        echo "  $name: REFUSED — $pending pending file(s) / ${mb} MB exceeds guard (${MAX_FILES} files / ${MAX_MB} MB). Nothing was staged."
        echo "        An unreviewed bulk commit is almost always a missing .gitignore."
        echo "        Review with:  git -C $V status --short | head -40"
        echo "        Then either fix .gitignore, or make the first commit by hand,"
        echo "        or bypass permanently:  touch $V/.vault-backup-allow-large"
        continue          # nothing staged, nothing written — the repo is untouched
      fi
    fi

    git -C "$V" add -A || { echo "  $name: FAIL — git add"; continue; }
    if git -C "$V" diff --cached --quiet; then
      echo "  $name: clean, nothing to commit"
    elif git -C "$V" commit -q -m "vault backup (timer): $(date '+%Y-%m-%d %H:%M:%S')"; then
      echo "  $name: committed $pending file(s)"
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
