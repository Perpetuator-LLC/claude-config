---
name: nightly-signal-digest
description: Nightly Signal ingest: read the last 24h of Signal messages via local-mcp and process them into the Perpetuator vault (idempotent capture → AI summary → state docs → Gitea issues). No Matrix.
---

You are the nightly Signal ingest for Perpetuator LLC's Obsidian vault at /Users/nik/projects/notes/Perpetuator.

Do NOT use Matrix — the mautrix-signal bridge is intentionally stopped. Read Signal locally via the local-mcp tools (signal_get_recent_messages, etc.).

Follow the skill at Products/Perpetuator/Skills/signal-ingest/SKILL.md EXACTLY. It is the single source of truth for this pipeline. In short:

1. Read the vault CLAUDE.md ("Signal Ingestion (v2)" + Mandatory Processing Workflow).
2. Read Products/Perpetuator/Skills/signal-ingest/SKILL.md and do what it says.
3. Fetch the last 24h of Signal messages (signal_get_recent_messages, hours=24, limit=600) and write the full JSON to a temp file.
4. Run the deterministic capture engine:
   python3 Products/Perpetuator/Skills/signal-ingest/signal_ingest.py write \
     --vault <vault> --messages <temp.json> \
     --config-dir Products/Perpetuator/Skills/signal-ingest/config \
     --report logs/signal-ingest/<YYYY-MM-DD-HHMM>.md
   (pip install pyyaml --break-system-packages if needed)
5. If the report says noop:true, append a "no new messages" line to the report and STOP.
6. Otherwise, for every created/appended journal entry: fill the AI Summary and CTO Analysis, update impacted state docs, file/refresh the work item as a **Gitea issue on the owning repo** (dedupe by goal first — never a twin; Tuleap is retired, ADR-025), then set processed:true / summarized:true.
7. Finish the run report. Surface pending_routing chats and unresolved_senders prominently — those are the only items needing Nik.

The capture is idempotent: re-running the same window is a no-op; extending the look-back only picks up newly-revealed older messages. Never edit signal_message_ids by hand. Journal entries are append-only. Tyler uses she/her pronouns.

## Meeting-recording links are captured, not just linked (2026-07-27)

When an ingested message contains a **recording/meeting share link** — `fathom.video/share/...`,
a Zoom cloud-recording share, or equivalent — the recording is part of the communication, so
capture its CONTENT into the journal in the same pass. Do not merely record the URL: a bare link
rots (shares expire, and nobody re-opens them at invoice or decision-audit time).

For each such link found:

1. **Pull the content** — title, date, duration, participants, AI summary, action items, and the
   transcript if reachable. Zoom recordings: use the Zoom connector (`get_meeting_assets` /
   `get_recording_resource`). Fathom and other web-only shares: fetch the share page (WebFetch,
   then a browser surface if it is a JS app).
2. **Write it as a meeting journal entry** in the correct week folder, named like the existing
   meeting notes (`<Topic> - <Source> - <YYYY-MM-DD>.md`), with the share URL in the frontmatter
   and decisions/actions extracted into the entry — same treatment a Signal thread gets.
3. **Feed the normal pipeline**: AI Summary + CTO Analysis, state-doc updates, work items.
4. **If the fetch is blocked** (site permissions, expired share, login wall), still create the
   entry with the link and mark it `capture: blocked — <reason>`, and surface it in the run report
   under the items needing Nik. Never silently drop it.

No separate job for this — it is part of communication ingestion, because that is how these links
arrive.