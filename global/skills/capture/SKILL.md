---
name: capture
description: "Invoke when the user's message contains #capture (alone or with a hint narrowing the topic). Knowledge-Capture Protocol — distill the durable lessons (concepts + why, not the transcript) from THIS session and route each to the right canonical home (config / vault / repo docs / auto-memory), correcting any note the session proved stale. The sibling of #badagent, but for knowledge instead of behavior."
---

# Knowledge-Capture Protocol — `#capture`

When the human tags a message **#capture** (alone or with a hint narrowing the topic), distill the durable lesson(s) from the current session and write them where they'll be found again — the sibling of `#badagent`, but for knowledge instead of behavior:

1. **Distill.** Extract the *concepts and why*, not the session transcript: how the system works, the threat/decision model, the non-obvious gotchas, how to recover/rebuild from cold. A hint scopes it; no hint = capture everything durable from the session.
2. **Route to the right layer(s)** (G6/G11 — route-before-create, update the canon, thin pointers elsewhere):
   - Universal agent behavior → the config source (`~/projects/operating-canon/global/CLAUDE.md`), committed `docs():`.
   - Personal/家 systems (home infra, backups, succession) → **Nik vault**, canonical doc for that domain (e.g. `Foundation/*`); append dated sections (G2), respect frontmatter/8×8 (G3/L6), never commit (sync automation owns git).
   - Business/product/ops knowledge → **Perpetuator vault** (SOP beside its product, or R&D note) or the owning code repo's docs; stale recipes get a dated correction appended, not a rewrite.
   - Cross-session facts/pointers → auto-memory (pointer to the canon, never the content).
3. **Correct the stale.** If the session proved an existing note wrong (the cause of an outage, a rotted value), append a dated correction to that note pointing at the new canon — the old recipe must not be followable in ignorance.
4. **Report back**: what was captured, where (each file), and what was corrected.
