#!/usr/bin/env bash
# One-shot migration of notes-nik large files → NAS vault-store.
# Copy with rsync, verify EVERY file by checksum, only then remove the source.
set -uo pipefail
V=/Users/nik/projects/notes-nik
STORE=/Volumes/private/personal/nik/vault-store/notes-nik
MANIFEST="$STORE/_migration-2026-08-02.tsv"
cd "$V" || exit 1

# Move set: the three journal-image dirs + every untracked file >5MB
list_targets() {
  find ./Wealth/Investing/Journal/images ./Wealth/Investing/Journal/Attachments \
       ./Wealth/Investing/Attachments -type f ! -name '.DS_Store' 2>/dev/null
  find . -path ./.git -prune -o -path ./_store -prune -o -type f -size +5000k -print 2>/dev/null \
    | while IFS= read -r f; do
        git ls-files --error-unmatch "${f#./}" >/dev/null 2>&1 || echo "$f"
      done
}

total=0; moved=0; failed=0
printf 'status\tbytes\tvault_path\n' > "$MANIFEST"
list_targets | sort -u | while IFS= read -r f; do
  rel="${f#./}"
  sz=$(stat -f%z "$f")
  dest="$STORE/$rel"
  mkdir -p "$(dirname "$dest")"
  if rsync -a --checksum "$f" "$dest" && \
     src_sum=$(shasum -a 256 "$f" | cut -d' ' -f1) && \
     dst_sum=$(shasum -a 256 "$dest" | cut -d' ' -f1) && \
     [[ -n "$src_sum" && "$src_sum" == "$dst_sum" ]]; then
    rm "$f"
    printf 'moved\t%s\t%s\n' "$sz" "$rel" >> "$MANIFEST"
  else
    printf 'FAILED\t%s\t%s\n' "$sz" "$rel" >> "$MANIFEST"
  fi
done

echo "── summary ──"
awk -F'\t' 'NR>1 {n[$1]++; s[$1]+=$2} END {for (k in n) printf "%s: %d files, %.1f MB\n", k, n[k], s[k]/1048576}' "$MANIFEST"
# prune now-empty source dirs
find ./Wealth/Investing/Journal/images ./Wealth/Investing/Journal/Attachments ./Wealth/Investing/Attachments -type d -empty -delete 2>/dev/null
echo "manifest: $MANIFEST"
