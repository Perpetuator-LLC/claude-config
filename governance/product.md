---
type: governance
domain: product
role: CPO
status: draft
owner: Nik
created: 2026-06-26
extends: governance/README.md
tags: [product, strategy, requirements, roadmap]
---

# Product Governance (CPO)

How products are defined and shipped. Layers under the [Constitution](README.md). For a client's
product, their requirements/definitions win on *their* product's shape; my definition discipline and
traceability always apply.

## The strategy-to-execution spine
Every unit of work traces up and down (G9):
**Theme → Objective → Key Result → Initiative → Requirement Package → Requirement → Capability →
Work Item → Release**, measured by **KPI → Snapshot**, wrapped by **Decisions · RAID ·
Responsibility · Evidence**. Architecture (*when/where*) → Planning (*what/who*) → Implementation
(*how*); each layer traces to the one above.

## Defining an initiative
- Start from a **SMART goal as a checkbox list** (Specific/Measurable/Achievable/Relevant/
  Time-bound) — not *ready* until every box is checkable.
- **Meeting kinds drive outputs:** architecture → initiative/epics; planning → tickets;
  implementation → requirements/ADRs (*how to build*); **balance** → a verification checklist mapped
  1:1 to the SMART goal (*how to verify*). Pair an implementation meeting with a balance meeting.
- **Requirements are the source of truth for scope** and live in the initiative repo, versioned
  alongside what they define (placement policy).

## Owned products
Perpetuator products live under `Engagements/Internal/Products/<Name>/` with a charter + a State doc.
Current: Capital Copilot, Perpetuator KMS, Perpetuator LLM, Chain Reaction, Flow, Satoshis Signal.
Each gets a strategy/charter, a product State doc (roadmap/health — about the product, not people),
and a matching PM project.

## TODO (fill in / publish)
- [ ] PRD/BRD/FRD template + the bar for "requirement is ready."
- [ ] Roadmap + release-cadence convention; versioning standard.
- [ ] Discovery → validation process (how an idea earns a slot).
- [ ] Definition-of-Done standard across products.

Canonical: `operating-canon/governance/product.md` → `~/.claude/governance/product.md`.
