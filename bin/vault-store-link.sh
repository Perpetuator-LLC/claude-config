#!/usr/bin/env bash
# vault-store-link.sh — create/repair each vault's `_store` symlink to its NAS store.
#
# THE storage-abstraction layer from Sovereign Data Architecture §2, in its simplest
# valid form: notes reference `_store/<vault-relative-path>` (or bare-basename
# wikilinks that resolve into it); ONLY this symlink knows where the bytes live.
# Swap NAS ↔ other backend by changing one line in `.vault-store` — no note ever
# hard-codes a backend path (design test §6.2).
#
# Per-vault config: a committed `.vault-store` file in the vault root whose first
# non-comment line is the absolute target directory, e.g.
#   /Volumes/private/personal/nik/vault-store/notes-nik
# The `_store` symlink itself is gitignored (machine-local, recreated by this script).
#
# New-machine bootstrap = mount the NAS + run this script. Idempotent; safe to re-run
# any time (the vault-backup timer may also invoke it as a self-heal).
set -uo pipefail
export PATH=/usr/bin:/bin:/usr/sbin:/sbin

VAULT_PARENT="${VAULT_BACKUP_PARENT:-$HOME/projects}"
rc=0

for d in "$VAULT_PARENT"/*/; do
  d="${d%/}"; name=$(basename "$d")
  [[ -f "$d/.vault-store" ]] || continue

  target=$(grep -vE '^\s*(#|$)' "$d/.vault-store" | head -1)
  if [[ -z "$target" ]]; then
    echo "$name: .vault-store present but empty — skipping"; rc=1; continue
  fi

  if [[ ! -d "$target" ]]; then
    echo "$name: store target not available: $target (NAS not mounted?) — skipping"
    rc=1; continue
  fi

  link="$d/_store"
  if [[ -L "$link" ]]; then
    current=$(readlink "$link")
    if [[ "$current" == "$target" ]]; then
      echo "$name: _store OK → $target"
    else
      ln -sfn "$target" "$link"
      echo "$name: _store repointed $current → $target"
    fi
  elif [[ -e "$link" ]]; then
    # Usual cause: the NAS was unmounted and Obsidian (or a drag-drop) created a real
    # _store/ dir, which may now hold files that never reached the NAS. Never delete it.
    echo "$name: _store exists but is NOT a symlink — refusing to touch it."
    echo "$name:   likely stranded attachments from an offline session; merge by hand:"
    echo "$name:     rsync -av --checksum '$link/' '$target/' && rm -rf '$link'  # then re-run me"
    rc=1
  else
    ln -s "$target" "$link"
    echo "$name: _store created → $target"
  fi
done
exit $rc
