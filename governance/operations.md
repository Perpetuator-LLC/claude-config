---
type: governance
domain: operations
role: COO
status: draft
owner: Nik
created: 2026-06-26
extends: governance/README.md
tags: [operations, process, knowledge-os, project-management, people-ops]
---

# Operations Governance (COO)

How work flows: knowledge capture, project management, people-ops. Layers under the
[Constitution](README.md). On client work, follow their process/protocols for *their* delivery; my
operating system always runs underneath.

## The Knowledge-OS (capture → distill → act)
The operating system for all my work — four surfaces, one direction:
**Journal** (capture, append-only) → **State** (current truth, latest-wins; the daily cockpit lives
here) → **SOP** (evergreen procedure) **+ Tuleap** (work backlog / system-of-record). Nightly jobs
keep it fresh: `zoom-ingest → signal-ingest → tuleap-reconcile → sop-distill → cockpit-rollup`.
Canonical implementation: `Engagements/Internal/Products/Perpetuator/Knowledge-OS.md`.

- **Mandatory processing:** any new input (meeting/Signal/email/doc) → journal entry → CTO analysis
  (decisions D#, discoveries Disc#, action items) → update State → sync Tuleap → mark processed.
- **Action items carry** {owner, size, priority, horizon, source, tuleap-id}. P0/P1-this-week
  surface in the **cockpit** (top of the State doc); everything else waits in Tuleap, pulled up as
  capacity frees. **Plan by capacity, not priority** — every item = hour estimate + scheduled week
  vs a fixed weekly capacity; new work triggers a displacement decision, never silent overflow.

## Project / initiative creation
Starting an initiative = define its goal as a **SMART checkbox list** (refine until every box is
checkable). New project → **auto-scaffold the vault folder + a matching PM project** from template;
confirm only the irreversible/ambiguous bits. Record the PM project id in the State doc.

## People-ops
- **Contributor record = canonical identity** (assign tickets to the contributor, link a real
  account later — zero re-assignment churn).
- **Onboarding / offboarding contractors** run from SOPs (access provisioning / revocation
  checklists) — never ad-hoc.

## TODO (fill in / publish)
- [ ] Meeting cadence + standing-agenda standard per engagement.
- [ ] Vendor/tool evaluation + registry process.
- [ ] Weekly review / ops-review ritual.

Canonical: `claude-config/governance/operations.md` → `~/.claude/governance/operations.md`.
