# Vault Store — NAS-backed large files for Obsidian vaults

The first concrete instance of the **Sovereign Data Architecture §2** storage-abstraction
layer (canon: Perpetuator vault → `Engagements/Internal/Products/Perpetuator/Sovereign Data
Architecture.md`). Large files live on the NAS; notes keep ordinary wikilinks; one symlink is
the only thing that knows where the bytes are.

## How it works

```
note.md ──![[chart.png]]──▶ Obsidian resolves by basename anywhere in the vault
                                  │
                            <vault>/_store          (symlink, gitignored, machine-local)
                                  │
                            target from .vault-store   (one line, committed)
                                  │
                            /Volumes/private/.../vault-store/<vault>/   (NAS, SMB)
```

| Piece | Committed? | Role |
|---|---|---|
| `.vault-store` (vault root) | ✅ | first non-comment line = absolute store path. **The only place a backend path exists.** |
| `_store` symlink (vault root) | ❌ (gitignored) | machine-local pointer; created/repaired by `vault-store-link.sh` |
| `bin/vault-store-link.sh` | ✅ (operating-canon) | idempotent create/repair for every vault under `~/projects` with a `.vault-store` |
| `bin/vault-backup.sh` | ✅ (operating-canon) | the 30-min backup timer **self-heals `_store` on every run** |
| `_migration-*.tsv` (store root) | on NAS | manifest of every file moved out of git: status, bytes, vault-relative path |

**Design tests it satisfies (SDA §6):** no consumer hard-codes a backend (§2); text stays in
the versioned vault (§1); backend swap = edit `.vault-store`, re-run the linker — every
existing link keeps working.

## New machine / restore from cold

1. Clone the vault(s) into `~/projects/`.
2. Mount the NAS (`/Volumes/private` — Finder ⌘K `smb://192.168.1.144/private`, or let
   macOS auto-mount at login).
3. `bash ~/projects/operating-canon/bin/vault-store-link.sh`
   — or do nothing: the vault-backup timer runs it every 30 min and at login.
4. Open Obsidian. Everything renders.

**Restore the store itself** (NAS died): the store tree is inside the NAS's own backup
cycle (Synology → encrypted → S3 per SDA §1). Restore the NAS share, remount, re-run the
linker. The vault git history is unaffected either way — the two tiers fail independently.

## New attachments — automatic NAS routing

`.obsidian/app.json` → `"attachmentFolderPath": "_store/Attachments"` (committed, so the
setting travels with the vault). Drag-drop into a note ⇒ Obsidian writes the file through
the symlink ⇒ it lands on the NAS ⇒ that night's NAS backup covers it. The note gets a
normal `![[file.png]]` wikilink — indistinguishable from a vault-local attachment.

## Enrolling another vault

1. `mkdir` the store tree — **placement per SDA §6.5:** personal vault → personal tree
   (`/Volumes/private/personal/<person>/vault-store/<vault>`), business vault → Perpetuator
   tree (`/Volumes/private/business/Perpetuator/vault-store/<vault>`). Never mixed.
2. Write `.vault-store` in the vault root naming that path.
3. Add `_store` to the vault's `.gitignore`.
4. Set `attachmentFolderPath` to `_store/Attachments` in `.obsidian/app.json` (if the vault
   commits its `.obsidian`; otherwise set it in the UI: Settings → Files & Links → Default
   location for new attachments).
5. Run `vault-store-link.sh`. Move existing large files with `bin/vault-store-migrate.sh
   <vault>`, driven by a committed `.vault-store-migrate.list` in the vault root (paths,
   one per line, `#` comments, a directory means its whole tree). rsync `--checksum`,
   sha256 source-vs-dest, delete only after match, TSV manifest, per-file progress.

⚠️ **Selecting the move set: size is not a sufficient heuristic.** The move works because
Obsidian resolves embeds by **basename**. Three cases defeat that silently — the file
lands on the NAS, the note renders a missing-embed placeholder, and nothing errors:

| Case | Why it breaks | Handling |
|---|---|---|
| **Path-style links** — `[[Attachments/foo.png]]` or `](Attachments/foo.png)` | The note names a location, not a basename; after the move that path is gone | **Exclude**, or rewrite the link to `_store/…` first |
| **Duplicate basenames** across the vault | Ambiguous resolution after the move | **Exclude** one, or rename |
| **`_store` not resolving** (NAS unmounted, symlink missing) | Copy succeeds to the real path; vault can't reach it | Run `vault-store-link.sh` first |

`vault-store-migrate.sh` now **hard-fails on all three before copying or deleting
anything** — it greps the vault for each listed path verbatim, checks for basename
collisions in the set, and verifies `_store` resolves to the same target `.vault-store`
names. Found the hard way: a size-only pass over `notes-nik` would have broken 24
path-referenced embeds (that vault carries 412 path-style wikilinks and 247 path-style
markdown links overall).

⚠️ **Engagement vaults (e.g. notes-weown): think before enrolling.** The vault is a
custody/subpoena boundary — "hand over the vault" stops being complete the moment some of
its bytes live outside git. If an engagement vault ever needs a store, its tree must sit
under a dedicated engagement path and be disclosed as part of the boundary. Default: leave
engagement vaults fully in git.

## Failure modes (all fail soft)

| Situation | Behavior | Fix |
|---|---|---|
| NAS unmounted | embeds show file-not-found placeholder; nothing breaks or is lost | remount; instant |
| Drag-drop while unmounted | Obsidian creates a REAL `_store/` dir; files land local, never reach NAS | linker detects it, refuses to touch it, and prints the exact `rsync` merge command; timer log shows it within 30 min |
| Basename collision (new file shadows a store file) | Obsidian disambiguates by fuller path; existing links unaffected | rename if it bites |
| Mobile Obsidian | no SMB mount — store files don't render | accepted; future box: point `.vault-store` at a synced/cached copy |
| Gitea web rendering of store embeds | not rendered (Gitea can't follow a machine-local symlink) | **deliberately not solved** — a web-served store + URL links would trade "zero note edits" for a web dependency; revisit only if reading vaults through Gitea becomes a real workflow |

## History

| Date | Change |
|---|---|
| 2026-08-02 | Built; notes-nik enrolled; 318 files / 839 MB migrated (manifest in store root); auto-attachment routing on; timer self-heal wired |
