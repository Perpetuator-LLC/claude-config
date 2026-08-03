---
name: nightly-signal-digest
description: "Nightly message ingest (Signal today; multi-channel by design): read the last 24h of messages via local-mcp and process them into the Perpetuator + WeOwn vaults (idempotent capture → AI summary → state docs → work items). No Matrix posting."
scope: portable
canon_origin: operating-canon/global/skills/nightly-signal-digest/SKILL.md
schedule: "30 21 * * *"
---

You are the nightly **message** ingest for Perpetuator LLC's Obsidian vaults.

**Vault roots (2026-07-31 WeOwn graduation — both are live):**
- Perpetuator: `/Users/nik/projects/notes-perpetuator`
- WeOwn: `/Users/nik/projects/notes-weown` (flattened — `Journal/<ISO-week>/`, no `Engagements/` prefix)

Do NOT post to Matrix, and do not read from it — the mautrix-signal bridge is intentionally stopped
(mcp `playbooks/matrix-remove-signal-bridge.yml`). Read Signal locally via the local-mcp tools
(`signal_get_recent_messages`, etc.).

**The canonical engine spec is the vault skill** —
`Engagements/Internal/Products/Perpetuator/Skills/signal-ingest/SKILL.md` in notes-perpetuator. It is
the single source of truth for this pipeline; this file is the thin scheduled-task wrapper. In short:

1. Read the vault `CLAUDE.md` (§*Ingestion & reconciliation* + the Mandatory Processing Workflow
   pointer, and the ⛔ **Tuleap-retired** banner at the top).
2. Read the vault `signal-ingest/SKILL.md` and do what it says.
3. Fetch the last 24h (`signal_get_recent_messages`, `hours=24`, `limit=600`) and write the full JSON
   to a temp file. **Never bulk-read message bodies into your own context** — a 2026-07-25 run pulled
   live credentials into a transcript; let the engine consume the file.
4. Run the deterministic capture engine (`plan` to preview, `write` to commit):
   ```
   SK=<notes-perpetuator>/Engagements/Internal/Products/Perpetuator/Skills/signal-ingest
   python3 "$SK/signal_ingest.py" write --vault <notes-perpetuator> \
     --messages <temp.json> --config-dir "$SK/config" \
     --report <notes-perpetuator>/.workspace/logs/signal-ingest/<YYYY-MM-DD-HHMM>.md
   ```
   (`pip install pyyaml --break-system-packages` if needed.) One run handles both vaults — the dedupe
   index scans every configured `vault_root`.
5. If the report says `noop: true`, append a "no new messages" line and STOP.
6. Otherwise, for every created/appended entry: fill the AI Summary + CTO Analysis, update impacted
   state docs (**recency rule** — newest *event date* wins, never regress a status field), file or
   refresh the work item, then set `processed: true` / `summarized: true`.
   - Work items go to **Gitea issues on the owning repo**, deduped by GOAL (Tuleap is retired —
     mcp ADR-025). **WeOwn has no repo** (`WeOwnNetwork/*` issues are disabled): set
     `work_item_sync.work_item_home: vault-state-docs` and track in `State/Nik.md`.
   - If the gateway is unreachable, set `work_item_sync.status: pending` **in the entry** (never a log
     file) and surface it in the report — nothing reconciles it automatically.
7. Finish the run report. Surface `pending_routing`, `unresolved_senders`, and
   `skipped_missing_vault_root` prominently — those are the only items needing Nik.

Idempotent: re-running the same window is a no-op; extending the look-back picks up only
newly-revealed older messages. Never hand-edit `signal_message_ids`. Journal entries are append-only.
Never git-commit either vault. Tyler uses she/her pronouns.

## Direction — this is a MESSAGE ingest, not a Signal ingest (2026-08-02, Nik-stated)

The routine is channel-shaped by accident of what shipped first. The intent is **one nightly ingest
that pulls messages from every channel** into the same capture → summarize → state-doc → work-item
pipeline. The engine is already channel-agnostic where it matters (the dedup key is
`sha256(chat|date|sender|body)`, which needs no Signal-specific field), so generalizing is a read-path
and config change, not an engine rewrite.

**Channel status as of 2026-08-02 — do not assume more than this is live:**

| Channel | Read path today | Status |
|---|---|---|
| Signal | local-mcp SQLCipher reader (`signal_*`) | ✅ live — the only channel this routine ingests |
| Email | Stalwart + `email_*` gateway tools | 🟡 P1 in progress (COMMS-HUB) — **not** in this routine yet |
| Telegram | mautrix-telegram → Synapse | ❌ **not live** — COMMS-HUB **P2 pending** |
| WhatsApp | mautrix-whatsapp | ❌ not live — P2, after Telegram |
| Discord | mautrix-discord | ❌ not live — P2 |
| iMessage | BlueBubbles / Mac bridge | ❌ not live — **P4, later** |
| SMS / RCS | Google-Messages bridge | ❌ not live — P4, later |

Architecture + phasing are canon in mcp `docs/architecture/cos/COMMS-HUB.md` (D1–D5, P1–P4). The
convergence point: once bridged rooms exist, **Matrix is the unified read surface** and this routine
reads *one* feed instead of N per-channel readers — the bespoke Signal poller and the local-mcp
SQLCipher reader retire at that point (COMMS-HUB D1). The "no Matrix" rule above is about the
*current* broken-bridge state, not the destination.

**When a channel goes live, the work is:** add its reader to step 3, add its chats to
`engagement-routing.json` (routing + ignore + labels), confirm the identity map resolves its sender
ids, and rename this routine to `nightly-message-ingest` once it reads more than one channel.
