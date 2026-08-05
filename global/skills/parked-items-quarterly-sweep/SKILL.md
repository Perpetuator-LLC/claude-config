---
name: parked-items-quarterly-sweep
description: Quarter-start sweep: surface parked vault items whose revisit_when quarter is due, into the CTO cockpit Next Up.
---

You are the quarterly "parked items" sweep for the Perpetuator Obsidian vault. Your job: make sure no deliberately-parked idea gets lost. A parked item is any vault note whose frontmatter has `adoption_status: parked` (or `status: parked`) plus a `revisit_when:` quarter. At the start of each quarter, render the WHOLE parked shelf (every parked item, year-round) and flag the ones that are now DUE.

VAULT ROOT (edit this MAIN checkout only — never a `.claude/worktrees/*` copy):
/Users/nik/projects/notes-perpetuator

Do NOT commit anything — the Obsidian sync plugin owns git. Do NOT send anything outbound (no Matrix/Tuleap/email); this sweep is vault-internal only. Skip any note whose frontmatter has `outbound_prohibited: true` from any external mention, but still list it in the report.

STEP 1 — Determine the current quarter.
Today's date is available in your context. Q1=Jan–Mar, Q2=Apr–Jun, Q3=Jul–Sep, Q4=Oct–Dec. Encode any `YYYY-Qn` as a sortable integer: `year*4 + (n-1)`. An item is DUE when its `revisit_when` integer is <= the current quarter's integer (i.e. this quarter or overdue).

STEP 2 — Find all parked items. Run:
  cd /Users/nik/projects/notes-perpetuator && grep -rilE '^(adoption_status|status):[[:space:]]*parked' --include='*.md' . | grep -v '/.claude/worktrees/'
For each hit, read its frontmatter and extract: title, path, `revisit_when`, `revisit_trigger` (if any).

STEP 3 — Classify each parked item:
  - DUE — revisit_when quarter <= current quarter.
  - FUTURE — revisit_when quarter > current quarter (not yet due; list count only).
  - DEFECT — `adoption_status: parked` but NO `revisit_when` (or malformed). These violate the convention (a parked item MUST carry a revisit date or it gets lost) — always surface these as needing a date, regardless of quarter.

STEP 4 — Write a report to:
  /Users/nik/projects/notes-perpetuator/.workspace/logs/parked-sweep/<YYYY-MM-DD>.md
(create the folder if missing). Include: the current quarter, a DUE table (title · revisit_when · revisit_trigger · path), the DEFECT list, and the FUTURE count. If nothing is due and no defects, say so plainly.

STEP 5 — Update the CTO cockpit at:
  /Users/nik/projects/notes-perpetuator/Engagements/Internal/State/Nik.md
Find the `## Next Up` section (create nothing else). Maintain an IDEMPOTENT managed block delimited exactly by these marker lines so each run REPLACES the prior block (never appends duplicates):
  <!-- parked-sweep:start -->
  ... generated content ...
  <!-- parked-sweep:end -->
Inside the block put a dated subheading `### ⏸ Parked shelf (as of <YYYY-MM-DD>, <current quarter>)` and list EVERY parked item (the whole shelf, not just due ones), one bullet each: `- [ ] [[<path-without-.md>|<title>]] — parked, revisit_when <quarter><trigger if any>.` Prefix DUE/overdue items with `🔔 DUE — ` and append `; decide: adopt / re-park (bump revisit_when) / drop.` Add any DEFECT items as `- [ ] ⚠️ [[…|title]] — parked with NO revisit_when; assign a quarter.` If there are no parked items at all, set the block body to a single line: `_No parked items as of <YYYY-MM-DD>._` Preserve everything outside the markers unchanged; if the markers don't exist yet, insert the whole block at the TOP of the `## Next Up` section.

STEP 6 — Because you edited the cockpit (a state doc) outside the normal journal workflow, that is fine — the nightly reconciliation catches orphan state edits. Do not create a journal entry yourself.

Keep it terse and factual. The entire point is that a parked item resurfaces on a hard date even when its event trigger never fired.