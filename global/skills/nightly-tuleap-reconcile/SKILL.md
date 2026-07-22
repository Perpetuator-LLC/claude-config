---
name: nightly-tuleap-reconcile
description: Nightly Tuleap reconciliation: vault ↔ Tuleap drift detection. Picks up unprocessed journal entries, syncs to Tuleap, audits open Tuleap items against state-doc reality, writes a daily report.
---

Run the tuleap-reconcile skill in full per its SKILL.md at `/Users/nik/projects/notes/Perpetuator/Products/Perpetuator/Skills/tuleap-reconcile/SKILL.md`.

Steps (per the skill):
1. Read the skill's SKILL.md fresh — the workflow may have evolved.
2. Read `/Users/nik/projects/notes/Perpetuator/CLAUDE.md` for the mandatory processing workflow (current v2 — converts decisions/discoveries/action items into Tuleap artifacts).
3. Execute all five passes in order:
   - Pass 1 — Vault → Tuleap (process unprocessed journal entries, sync to Tuleap, mark `processed: true`)
   - Pass 2 — Tuleap → Vault drift detection on open items
   - Pass 3 — Orphan detection (Tuleap artifacts with no source journal; vault refs with no Tuleap artifact)
   - Pass 4 — Reassignment / archive detection on open Work Items
   - Pass 5 — Removal / resolution of duplicate entries
   - Pass 6 — Write the daily reconciliation report at `/Users/nik/projects/notes/Perpetuator/Engagements/Reconciliation/<YYYY-MM-DD>.md`
4. Before any `tuleap_create_artifact` call, read the relevant tracker-notes at `Products/Perpetuator/Infra/Tuleap-Tracker-Notes/<project>-<tracker>.md` to apply known workflow / field quirks.
5. The single deliverable is the reconciliation report file. Notify Nik via Signal/Matrix with a one-line summary linking to the report.

Hard rules from the skill: never auto-apply Pass 2-4 status changes (proposals only), never modify historical journal entry bodies (frontmatter-only edits OK), stop Pass 1 immediately on auth failure and write a partial report.

Tracker project IDs cache: 113 Perpetuator Template, 114 Perpetuator, 115 Capital Copilot, 116 RallyPoint, 117 WeOwn, 120 QSC, 121 Silverman, plus any newly-created project (e.g. BrushPass Intelligence — query via `tuleap_list_projects` if you don't know its ID).