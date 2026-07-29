---
name: export-thread
description: "Export a Claude Code thread from its on-disk transcript into a readable Markdown record in the vault — capturing the reasoning/thinking verbatim so you can see WHY decisions were made, not just what changed. Non-interactive (no dialogs), schedulable. Triggers: /export-thread, export this thread, export conversation to notes, save thread to the vault, archive this conversation, thread export, capture the reasoning."
---

# /export-thread — render a thread's transcript into readable vault notes (with the reasoning)

Claude Code already writes every session to disk as JSONL at
`~/.claude/projects/<flattened-cwd>/<session-id>.jsonl` — including the **thinking blocks**. This
skill renders one (or a batch) into a clean Markdown record in the vault so you can read your threads
as notes and, crucially, see the **why** behind each decision. Deterministic, **non-interactive**
(never opens a dialog), and safe to run on a schedule.

## Where this sits (export vs import vs session-summary — they are different)
- **`/export-thread` (this)** = the **archival record** — backward-looking: what was asked, the
  reasoning, the actions. For reading later + understanding decisions. → a vault Journal `Threads/` doc.
- **`/session-summary`** = the **continuation hand-off** — forward-looking work STATE a fresh agent
  resumes from (what's left, decisions fenced). Different purpose; keep both.
- **ORCHESTRATOR-BOARD** = the **crew** state (fleet-level continuation, SOP-ORCH-002).
- **"Import"** = point a fresh thread at an export (or a session-summary / the board) as its starting
  context. There is no separate importer — the export IS the import artifact; a worker reads it to
  reconstruct the reasoning trail. Keep exports self-contained so this works.

## The renderer
`render.py` (beside this file, stdlib-only) does the work: parses the JSONL, emits vault-ready
frontmatter (passport `type: thread-export`, session id, cwd, branch, model, date range, counts),
a navigation list of the asks, then the conversation — **reasoning verbatim**, narration, and tool
calls summarized to one line each. **It redacts secret-looking strings** (keys/tokens/JWTs/private
keys) before writing, because exports land in the visible vault — but still eyeball anything sensitive.

## Run it (non-interactive)
1. **Locate the transcript** for the thread. For a repo/cwd:
   ```bash
   DIR=~/.claude/projects/$(echo "<abs-cwd>" | sed 's#/#-#g')   # e.g. /Users/nik/projects/cc-fe
   F=$(ls -t "$DIR"/*.jsonl | head -1)                          # newest session in that cwd
   ```
   (Desktop `local_…` ids don't match filenames — match by newest / by content if needed.)
2. **Route** by cwd → engagement/project, and pick the vault + folder:
   - Perpetuator/product repos (cc-be, cc-fe, mcp, rp-*, ai, inference) and the Perpetuator vault →
     `~/projects/notes-perpetuator/Engagements/Internal/Journal/<YYYYMM>/Threads/`
   - Personal / `notes-nik` cwds → `~/projects/notes-nik/…/Journal/<YYYYMM>/Threads/` (create if absent).
   Filename: `<ended-date>-<repo>-<session8>.md`.
3. **Render:**
   ```bash
   python3 <skill-dir>/render.py --transcript "$F" \
     --engagement Internal --project cc-fe \
     --out "<vault>/Engagements/Internal/Journal/202607/Threads/2026-07-22-cc-fe-29e3cdc1.md"
   ```
4. **Never git-commit either vault** — the Obsidian sync owns git. Just write the file.

## Batch / scheduled (the "on a regular basis" mode)
Run nightly (mirror the other nightly engines in `~/Documents/Claude/Scheduled/`): for each active
repo cwd, take the transcript(s) touched in the last 24h and render each to its `Threads/` folder,
skipping any whose `source_session` + `ended` already exist (idempotent). Keep it a proposer of files,
never a committer. A one-line run report (how many threads exported, per vault) is the deliverable.

## Testing / optimizing the parts
- `render.py` is pure and deterministic — unit-test `redact()` with synthetic secrets, and diff the
  rendered output of a fixed transcript across changes. `--max-thinking` / `--max-text` tune verbosity.
- Consecutive assistant events coalesce under one heading; user↔assistant turns should be balanced.
- If an export reads poorly, fix the renderer (not the doc) so every future export improves.
