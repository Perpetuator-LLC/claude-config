---
name: orchestrator-export
description: "The ORCHESTRATOR's whole-fleet migration in one invocation: export EVERY active (non-archived) worker thread AND the orchestrator's own thread, then assemble a single master migration doc that a fresh AI boss can ingest to resume the entire crew from one pasted prompt. Drives the per-thread primitives (export-thread for the reasoning, #SessionSummary for the continuation) across all streams — it does not replace them. Triggers: /orchestrator-export, export the whole fleet, migrate all threads, fleet migration, export every thread, whole-crew export, hand off the crew with full exports, migrate the crew to a new orchestrator."
---

# /orchestrator-export — migrate the WHOLE crew in one shot (every thread → one master doc → one prompt)

You are the **orchestrator**. This skill is the fleet-scale hand-off: instead of exporting one
thread, you export **every active thread at once** (each worker + your own orchestrator thread),
bundle them behind **one master migration doc**, and produce **one prompt** Nik pastes into a fresh
AI boss. That boss ingests the master doc, then re-hydrates each worker from its own export and
drives it onward — every stream resumes exactly where it was, with its loose ends, its next tasks,
and the done-work context needed to finish them.

This is the boss-level companion to the per-thread skills. It **drives** them; it does not replace
them. If you only need one thread captured, use `/export-thread` or `#SessionSummary` directly.

## What it produces (three artifacts, in this order)

1. **A refreshed board** — `ORCHESTRATOR-BOARD.md` brought to current truth (SOP-ORCH-002 outgoing
   checklist). The live, stable-filename surface. Always step 1: a migration off a stale board is a
   broken migration.
2. **Per-thread exports — two kinds per stream**, because "resume" needs both directions:
   - **Reasoning / archival** (backward — *why* each decision was made): `export-thread` renders it
     from the on-disk JSONL. **You run this yourself, from disk — no worker cooperation, no prompts,
     deterministic, secret-redacted, idempotent.** This is the guaranteed floor: even a dead or
     unreachable worker still gets its reasoning captured.
   - **Continuation / work-state** (forward — *what's left*): each worker's own `#SessionSummary`
     addendum + its per-repo continuation doc. You **drive** this via `send_message`; best-effort.
3. **The master migration doc** — one dated bundle that references the board + every per-thread
   export + your own, with the single kickoff prompt at the bottom. Pointers, not payload.

## The two-capture principle (why both, per thread)

A thread that "resumes where it was" needs *what's left* **and** *why the done work was done*. The
continuation doc alone loses the reasoning trail; the reasoning export alone doesn't say what's next.
Capture both and a fresh worker can finish an in-flight task without re-deriving the path to it. The
reasoning export is the **robustness floor** — it always succeeds because it reads disk, so the
migration never depends on a worker being awake.

## Procedure

### 0. Pre-flight — never leak, never commit
- **Agent Secret Ban.** Run the renderer as a **subprocess that writes files**; never `cat`/Read a
  raw transcript into your own context. `export-thread`'s `render.py` redacts key/token/JWT-shaped
  strings before writing — but exports land in the visible vault, so the doc set is private-vault
  only, never a public repo.
- **Never git-commit either vault** (Obsidian sync owns their git). You only write files.
- **`send_message` prompts Nik every time** (host-enforced). **Batch** the worker drives into as few
  sends as possible and tell Nik up front how many prompts are coming.

### 1. Sweep + refresh the board (current truth first)
Run one sweep (SOP-ORCH-001 rule 11): reconcile every stream against reality (ticket + git + CI),
then apply the **SOP-ORCH-002 outgoing-boss checklist** — every current task is a live ticket, every
stream has a continuation doc, board rows + the Nik-gated stack are current, the kickoff block is
current. The board is the migration's backbone; fix it before you bundle it.

### 2. Enumerate the active streams (skip archived)
The stream set is the **union** of:
- **the board's rows** (the canonical crew list — always authoritative), plus
- **live sessions** from `mcp__ccd_session_mgmt__list_sessions` that are **not archived** (catches an
  adopted successor thread the board hasn't absorbed yet; rule 14). Session-mgmt may return zero —
  that's expected; fall back to the board rows + disk transcripts.
- **your own orchestrator thread** (cwd `~/projects/notes-perpetuator`) — it is a stream too; its
  reasoning is the fleet's decision record.

Archived sessions are **out of scope** — this migrates only what's still live.

### 3. Reasoning export — all active repos, from disk (the guaranteed floor)
Fan out `export-thread`'s batch driver over every active repo. It finds each repo's recent
transcript(s) and renders them to that repo's `Journal/<YYYYMM>/Threads/`, idempotent and redacted:
```bash
python3 ~/.claude/skills/export-thread/batch.py --window-hours 72
```
`batch.py`'s `FLEET` list already covers cc-be, cc-fe, mcp, rp-be, rp-fe, ai, inference,
notes-perpetuator (your own thread), notes-nik. Widen `--window-hours` so every active thread's
newest transcript is in range; narrow with `--repos a,b` to re-run a subset. `--dry-run` first if you
want to see the file set. Record each written path — those are the "reasoning" links for the master
doc. (Desktop `local_…` session ids don't match filenames; batch.py matches by cwd + recency, so it
Just Works for the fleet.)

### 4. Continuation export — drive each worker to summarize itself
For each active worker stream, `send_message` a directive: **"Run `#SessionSummary` — write your
addendum to `Journal/<YYYYMM>/thread_handoff.md` and bring your per-repo continuation doc current;
reply with the two paths."** Batch these. The worker's own export is authoritative for its work-state
(it knows its uncommitted edits, its half-open PRs, its design exceptions). Where a worker is idle,
asleep, or unreachable, **do not block** — note "continuation: board row + tickets + reasoning export
only" for that stream and move on. The floor from step 3 still holds.

Vault streams (notes-perpetuator, notes-nik) summarize in place and **never commit**.

### 5. Assemble the master migration doc
Write **one** dated bundle — home = the same Threads folder the exports use:
`~/projects/notes-perpetuator/Engagements/Internal/Journal/<YYYYMM>/Threads/<date>-FLEET-MIGRATION.md`
Passport frontmatter (`type: thread-export`, `authoritative_for: fleet-migration-<date>`). It is
**pointers, not payload** (SOP-ORCH-002) — one section per stream:

| Field | What goes in it |
|---|---|
| stream / repo · cwd | which worker, and the dir to open it in |
| current task | the ONE task, as a live ticket ref (from the board row) |
| loose ends | open PRs, half-done edits, blocked-on — as ticket/PR links, not prose |
| continuation doc | link to the worker's `#SessionSummary` addendum + per-repo doc |
| reasoning export | link to the `export-thread` doc from step 3 (the *why*) |
| Nik-gated | what only Nik can do for this stream |

Open the doc with a two-line orientation (this is a fleet migration bundle; read the board for live
state, read each stream's two links to resume it) and a link to the live **board** and **SOP-ORCH-001
/ 002**. Close it with the kickoff prompt (below). Do not restate history — link the journals.

### 6. Emit the single kickoff prompt
Hand Nik the one paste-ready block (template below). It bootstraps the skills if the fresh boss lacks
them, becomes the orchestrator, ingests the master doc, then re-hydrates and drives each worker from
its own export. **This is the only thing Nik pastes.**

## The kickoff prompt (paste-ready template — fill the two dates)

````
Skills bootstrap first: if the `/orchestrator`, `/orchestrator-export`, `/export-thread`, or
`/session-summary` skills aren't available to you, install them from canon —
`~/projects/claude-config/install.sh` symlinks `~/.claude/skills` → the repo's `global/skills`. If
`claude-config` isn't on this machine, read each skill body directly at
`~/projects/claude-config/global/skills/<name>/SKILL.md` and follow it inline. Do not re-author skills
that already exist there.

You are the fleet ORCHESTRATOR (SOP-ORCH-001). Read, in order:
1. Engagements/Internal/Products/Perpetuator/SOPs/ORCHESTRATOR.md        (the role — rules 1–N)
2. Engagements/Internal/Products/Perpetuator/SOPs/HAND_OFF_THE_ORCHESTRATOR_CREW.md  (protocol)
3. Engagements/Internal/Products/Perpetuator/ORCHESTRATOR-BOARD.md       (live crew state)
4. Engagements/Internal/Journal/<YYYYMM>/Threads/<date>-FLEET-MIGRATION.md  (this migration bundle)

Then MIGRATE THE CREW:
- Provision the Standing Crew Routines (list_scheduled_tasks → create any missing from the board table).
- For EACH stream in the migration doc: spin up / adopt its worker thread in the listed cwd, hand that
  worker its OWN two export links (continuation + reasoning) as its starting context, and dispatch its
  ONE current task (rule 18) via a cross-session message + a ticket comment (rule 2).
- Verify every "done" three ways (ticket + git + CI) before reassigning (rule 1). Never implement.
- Surface the Nik-gated stack from the board — the only list Nik acts on.
````

## Relationship to the other skills (don't reinvent — orchestrate)
- **`/export-thread`** — the per-thread reasoning renderer. This skill fans it across the fleet (step 3).
- **`#SessionSummary`** — the per-thread continuation. This skill drives it across the fleet (step 4).
- **`/orchestrator`** — becomes/hands-off the boss via the board. This skill is what you run when the
  hand-off must carry **full per-thread exports**, not just the pointer board (e.g. migrating to a
  different machine/model, or when reasoning context matters for in-flight work).
- **SOP-ORCH-002** — the pointers-not-payload protocol both this skill and the board implement.

## Constraints & idempotency
- **Idempotent**: step 3 skips up-to-date exports; re-running the whole skill the same day only
  re-drives workers that changed and rewrites the master doc in place (same dated filename).
- **Pointers, not payload**: if the master doc starts re-narrating history, that's a defect — the
  per-thread exports and the board already hold it. Trim back to links.
- **Never commit the vaults; never read a secret into context; batch the `send_message` prompts.**
- The `ai` repo is the standing two-stream exception (keycloak + allm) — export both, scoped apart.

## Testing / maintenance
- Dry-run the reasoning fan-out (`batch.py --dry-run`) and confirm every active stream has a
  transcript in range before you widen the window or trust the floor.
- After a migration, the acceptance test is: a fresh boss, given ONLY the kickoff prompt, reaches a
  correct first dispatch for every stream without asking Nik a question the docs already answer. If it
  can't, the gap is a defect — fix the board row / file the missing ticket / write the missing
  continuation doc, per SOP-ORCH-002, so the next migration is pointer-clean again.
