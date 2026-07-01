---
type: governance
domain: financial
role: CFO
status: draft
owner: Nik
created: 2026-06-26
extends: governance/README.md
tags: [financial, invoicing, billing, rates]
---

# Financial Governance (CFO)

How money is tracked, billed, and recorded. Layers under the [Constitution](README.md). On client
work, the client's billing format/cadence wins on *their* invoice; my record-keeping discipline
always applies.

## Invoicing
- **One append-only invoice doc per engagement**, newest period at top — never a folder of per-week
  files, never split across files. (Canon: `Engagements/<Client>/<Client> Invoices.md`.)
- Each period: a **paste-ready ≤500-char summary** (the verbatim line item) + a Work-Performed
  breakdown by category with hour estimates + decisions captured + key deliverables + closing total.
- Lead the summary with **business-owner-visible impact** (go-lives, sales-ready milestones, cost
  savings), not infra minutiae.
- **Rate & cadence are per engagement** (declared in the engagement's config). Known: WeOwn $200/hr,
  cap 10 h/wk, ISO week Mon–Sun; Capital Copilot contractor Luke $25/hr via Wise, invoiced Fridays.

## ⚠️ Never overstate deployment status in a financial doc
A decision logged as "X LIVE" does not prove X is team-usable. Before writing "live/deployed/
mitigated" in an invoice, distinguish *proposal authored* vs *instance stood up* vs *team-live*, and
cross-check the latest journal. Risk reframes are not mitigations. When unsure, write the cautious
version + "verify before invoicing." (Past errors propagated into invoices and had to be unwound.)

## Records
- Receipts/invoices/statements filed under the business-ops `Financial/` + `Receipts/` homes.
- Contractor comp is **confirmed in writing (email of record) before the first invoice** — a hard
  gate (cross-ref Legal). Compensation models: contractors hourly; equity/profit-share for
  longer-term roles (cap ~2× a salaried equivalent as incentive).

## TODO (fill in / publish)
- [ ] Tax conventions (entity, quarterly, deductions) and where tax docs live.
- [ ] Expense categorization + reimbursement policy.
- [ ] Rate card / pricing standard across engagement types.
- [ ] Cash-flow / runway tracking surface.

Canonical: `claude-config/governance/financial.md` → `~/.claude/governance/financial.md`.
