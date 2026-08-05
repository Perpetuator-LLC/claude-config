#!/usr/bin/env bash
# One-shot re-baseline of notes-nik (approved by Nik 2026-08-02): replace the single
# stale pre-reorg commit with a fresh root reflecting the post-vault-store tree, then
# force-push and prune. DESTROYS the old 1-commit history by design.
# Self-logging: full log → NAS store root, progress to the terminal throughout.
set -uo pipefail
V="$HOME/projects/notes-nik"
LOG="/Volumes/private/personal/nik/vault-store/notes-nik/_rebaseline-2026-08-02.log"
exec > >(tee "$LOG") 2>&1

echo "════ re-baseline $(date -u +%FT%TZ)"
cd "$V" || { echo "FATAL: vault missing"; exit 1; }

echo "[1/6] pre-flight"
[[ $(git rev-list --count HEAD) == 1 ]] || { echo "FATAL: expected exactly 1 commit, refusing"; exit 1; }
git remote get-url origin | grep -q notes-nik || { echo "FATAL: wrong remote"; exit 1; }
echo "  ok: 1 commit, remote $(git remote get-url origin), .git $(du -sh .git | cut -f1)"

echo "[2/6] fresh orphan root"
git checkout -q --orphan rebaseline || exit 1
git add -A || exit 1
echo "  staged: $(git diff --cached --name-only | wc -l | tr -d ' ') files"

echo "[3/6] commit"
git commit -q -m "vault re-baseline 2026-08-02 — post vault-store migration

Fresh root: the previous single commit snapshotted a folder structure that no
longer exists (pre-reorg paths, pre-NAS media). Large files now live on the NAS
vault-store (operating-canon docs/vault-store.md); this baseline is the lean
text-first vault going forward." || exit 1
git branch -M main
echo "  new root: $(git log --oneline)"

echo "[4/6] force-push"
git push --force origin main || { echo "PUSH FAILED — local re-baseline done, retry push later"; exit 1; }

echo "[5/6] prune old objects"
git reflog expire --expire=now --all
git gc --prune=now --quiet

echo "[6/6] verify"
echo "  commits: $(git rev-list --count HEAD) (want 1)"
echo "  ahead/behind: $(git rev-list --left-right --count origin/main...HEAD) (want 0 0)"
echo "  .git size: $(du -sh .git | cut -f1) (was 602M)"
echo "  tracked: $(git ls-files | wc -l | tr -d ' ') files"
echo "  worktree intact: $(find . -path ./.git -prune -o -path ./_store -prune -o -type f -print 2>/dev/null | wc -l | tr -d ' ') files"
echo "done $(date -u +%FT%TZ) — log: $LOG"
