---
name: nightly-sop-distill
description: Nightly SOP distillation (22:30, after tuleap-reconcile): scan vault for promotable procedure/reference knowledge, DRAFT condensed SOPs in their engagement/product SOPs folder (proposer only — never publishes), update the register + bidirectional provenance, write a run report.
---

Run the sop-distill skill in full per its SKILL.md at `/Users/nik/projects/notes/Perpetuator/Engagements/Internal/Products/Perpetuator/Skills/sop-distill/SKILL.md`.

This runs nightly at 22:30, AFTER nightly-tuleap-reconcile (22:00), so State docs are settled before distilling.

Steps (per the skill):
1. Read the skill's SKILL.md fresh — the workflow may have evolved.
2. Read `/Users/nik/projects/notes/Perpetuator/SOPs/README.md` (governance + register) and the SOP section of `/Users/nik/projects/notes/Perpetuator/CLAUDE.md` before drafting.
3. Execute the six passes in order: (1) scan journals + state docs for promotable knowledge — reusable + procedural/reference + stable + currently buried; skip anything already carrying `promoted_to_sop:`; (2) cluster + match against the register (new draft vs. update existing vs. leave published bodies alone); (3) DRAFT SOPs — `status: draft` only, generalized, instance-noise stripped, placed in the correct `Engagements/Internal/Products/<X>/SOPs/` or `Engagements/<engagement>/SOPs/` folder per the distributed rule; (4) update the register + write bidirectional provenance (`promoted_to_sop:` frontmatter + a bottom pointer note on each source); (5) freshness audit (flag published SOPs past last_reviewed + review_cadence_days); (6) write a run report to `/Users/nik/projects/notes/Perpetuator/logs/sop-distill/<YYYY-MM-DD-HHMM>.md`.

Hard rules: you are a PROPOSER, not a publisher — every SOP is `status: draft`; only Nik flips to `published`. Never overwrite a published SOP body (propose a diff in the report instead). Never edit journal bodies — frontmatter `promoted_to_sop:` pointer + a one-line bottom note only. Generalize and strip names/dates/ticket-IDs/tenant-specifics (those stay in the source as provenance). Bias toward fewer, higher-quality drafts; list uncertain items as "candidates" for Nik to confirm rather than drafting them.

The single deliverable is the run report. End by surfacing the count of new drafts + proposed published-SOP updates + candidates awaiting Nik's review.