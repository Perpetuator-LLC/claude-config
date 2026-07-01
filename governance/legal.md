---
type: governance
domain: legal
role: CLO
status: draft
owner: Nik
created: 2026-06-26
extends: governance/README.md
tags: [legal, nda, contracts, ip, compliance]
---

# Legal Governance (CLO)

Contracts, IP, NDAs, entity, compliance. Layers under the [Constitution](README.md). Client legal
terms govern *their* engagement; my baseline (NDA-before-work, IP clarity) always applies.

## Contracts & NDAs
- **NDA before any contractor does work.** Signed NDAs filed under `Legal/NDAs/Signed/`.
- Pair the NDA with an **Independent Contractor agreement**; comp confirmed in writing before first
  invoice (cross-ref Financial).
- **Watch the IP + dispute clauses** — e.g. Section 6 IP assignment and remote-arbitration are the
  ones that get negotiated; narrow rather than block.

## Entity & IP
- **Perpetuator LLC** — single-member; entity docs (formation, OA, C-Corp-vs-LLC analysis,
  trademark) under `Legal/`.
- IP produced for a client under their agreement belongs per that agreement; **internal/product IP
  stays Perpetuator's** — keep the boundary clean (G8) and never commingle client IP into internal
  repos or vice-versa.

## Compliance
- **International contractor payments** — banned-country/sanctions compliance before paying
  affiliates/contractors abroad (Wise/crypto paths).
- Data handling per the Security domain; client-data residency per the client's terms.

## TODO (fill in / publish)
- [ ] Standard NDA + IC templates (canonical versions + where they live).
- [ ] Client-contract review checklist (IP, liability, termination, payment terms).
- [ ] Privacy/compliance posture (GDPR/CCPA) for products that hold user data.
- [ ] Trademark + brand-mark usage rules.

Canonical: `claude-config/governance/legal.md` → `~/.claude/governance/legal.md`.
