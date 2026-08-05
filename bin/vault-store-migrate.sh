#!/usr/bin/env bash
# vault-store-migrate.sh <vault-dir> — move listed files/dirs to the vault's NAS store.
#
# Reads <vault>/.vault-store-migrate.list (vault-relative paths, one per line, # comments;
# a directory means its whole tree). For each file: rsync --checksum → sha256 source-vs-dest
# → delete source only on match. Prints per-file progress immediately (a silent multi-minute
# script is a hand-off defect — operations.md → Hand the human a SCRIPT). TSV manifest
# appended in the store root; the agent reads that back, the human never pastes output.
set -uo pipefail
V="${1:?usage: vault-store-migrate.sh <vault-dir>}"
V="${V%/}"
cd "$V" || { echo "FATAL: $V missing"; exit 1; }
STORE=$(grep -vE '^\s*(#|$)' .vault-store | head -1)
[[ -d "$STORE" ]] || { echo "FATAL: store not available: $STORE (NAS mounted?)"; exit 1; }
LIST=".vault-store-migrate.list"
[[ -f "$LIST" ]] || { echo "FATAL: no $LIST in vault root"; exit 1; }
MANIFEST="$STORE/_migration-$(date +%Y-%m-%d).tsv"
[[ -f "$MANIFEST" ]] || printf 'status\tbytes\tvault_path\n' > "$MANIFEST"

expand() {  # list entries → individual files
  grep -vE '^\s*(#|$)' "$LIST" | while IFS= read -r e; do
    e="${e%/}"
    if   [[ -d "$e" ]]; then find "$e" -type f ! -name '.DS_Store'
    elif [[ -f "$e" ]]; then echo "$e"
    else echo "MISSING	$e" >&2
    fi
  done
}

total=$(expand 2>/dev/null | wc -l | tr -d ' ')

# ── PRE-FLIGHT: three hard fails, all BEFORE anything is copied or deleted ──────
# The move relies on Obsidian resolving embeds by BASENAME. Two link shapes and one
# broken-symlink case defeat that, silently — the file lands on the NAS, the note
# renders a missing-embed placeholder, and nothing errors. Caught by the notes-nik
# worker 2026-08-04: 24 attachment files there are referenced by FULL PATH, and a
# size-only heuristic would have moved them and broken every one.
echo "── pre-flight ──"
PF_FAIL=0

# 1. path-style references: the listed vault-relative path appears verbatim in a note
PATH_REFS=$(expand 2>/dev/null | while IFS= read -r f; do
  grep -rlF "$f" --include='*.md' . 2>/dev/null | head -1 | sed "s|^|$f\t|"
done)
if [[ -n "$PATH_REFS" ]]; then
  echo "  ABORT — these are referenced by FULL PATH; a basename move breaks the embed:"
  echo "$PATH_REFS" | sed 's|^|    |' | head -20
  echo "    ($(echo "$PATH_REFS" | wc -l | tr -d ' ') total) → exclude them, or rewrite the links first."
  PF_FAIL=1
fi

# 2. basename collisions — ambiguous resolution after the move
DUPES=$(expand 2>/dev/null | sed 's|.*/||' | sort | uniq -d)
if [[ -n "$DUPES" ]]; then
  echo "  ABORT — duplicate basenames in the move set (ambiguous after move):"
  echo "$DUPES" | sed 's|^|    |'
  PF_FAIL=1
fi

# 3. _store must resolve to the same target the copy is written to, or the moved
#    files are on the NAS but unreachable from the vault.
if [[ ! -d "$V/_store" ]]; then
  echo "  ABORT — _store does not resolve. Run: bash $(dirname "${BASH_SOURCE[0]}")/vault-store-link.sh"
  PF_FAIL=1
elif [[ "$(cd "$V/_store" && pwd -P)" != "$(cd "$STORE" && pwd -P)" ]]; then
  echo "  ABORT — _store points at $(cd "$V/_store" && pwd -P), but .vault-store says $STORE"
  PF_FAIL=1
fi

[[ $PF_FAIL -eq 0 ]] || { echo "════ nothing moved."; exit 1; }
echo "  ok: no path-style refs, no basename collisions, _store resolves"

echo "════ migrate $(basename "$V") → $STORE  ($total files)"
i=0; ok=0; fail=0
while IFS= read -r f; do
  i=$((i+1)); sz=$(stat -f%z "$f")
  printf '[%d/%d] %s (%.1f MB) ... ' "$i" "$total" "$f" "$(echo "$sz" | awk '{print $1/1048576}')"
  dest="$STORE/$f"; mkdir -p "$(dirname "$dest")"
  if rsync -a --checksum "$f" "$dest" \
     && s1=$(shasum -a 256 "$f" | cut -d' ' -f1) && s2=$(shasum -a 256 "$dest" | cut -d' ' -f1) \
     && [[ -n "$s1" && "$s1" == "$s2" ]]; then
    rm "$f"; ok=$((ok+1)); echo "ok"
    printf 'moved\t%s\t%s\n' "$sz" "$f" >> "$MANIFEST"
  else
    fail=$((fail+1)); echo "FAILED (source kept)"
    printf 'FAILED\t%s\t%s\n' "$sz" "$f" >> "$MANIFEST"
  fi
done < <(expand 2>/dev/null)

# prune emptied dirs listed as dirs
grep -vE '^\s*(#|$)' "$LIST" | while IFS= read -r e; do
  [[ -d "${e%/}" ]] && find "${e%/}" -type d -empty -delete 2>/dev/null
done
echo "════ done: $ok moved, $fail failed — manifest: $MANIFEST"
[[ $fail -eq 0 ]]
