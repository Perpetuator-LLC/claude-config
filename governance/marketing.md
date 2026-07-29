---
type: governance
domain: marketing
role: CMO
status: draft
owner: Nik
created: 2026-06-26
extends: governance/README.md
tags: [marketing, brand, content, gtm]
---

# Marketing Governance (CMO)

Brand, voice, content, and go-to-market. Layers under the [Constitution](README.md). Client brand
guidelines govern *their* deliverables; my content discipline (no overstatement — cross-ref
Financial/Security) always applies.

## Positioning — the three pillars
Perpetuator sells **Training · Consulting · Development**, each reinforcing the others ("we teach
what we build, build what we consult on"). Every piece of content should ladder to one pillar.

## Voice & substance
- **Don't overstate.** "Live/shipped/secure" claims must be true and verifiable (mirror the
  invoice-honesty rule). Security-posture content must reflect actually-deployed controls.
- Plain, concrete, builder-credible — show the real system, not hype.

## GTM mechanics
- **Lead capture pipeline:** homepage form → MCP Gateway → Matrix `#…-dev` notification → CRM lead
  (Corteza). Server-side rate-limit + sanitize + validate; never PII into an LLM context (Security).
- **Demographic landing pages** — tailor by segment (e.g. CC: entrepreneurs / CPAs+investors /
  general investors), each with its own lead-gen path + analytics (self-hosted **Matomo**, not GA).
- Offer/lead frameworks (Hormozi $100M Offers/Leads) live under `Marketing/`.

## TODO (fill in / publish)
- [ ] Brand kit: logo, palette, type, voice guide (canonical home).
- [ ] Content cadence + channel plan (LinkedIn, blog, podcast, YouTube).
- [ ] Social-posting automation + attribution standard.
- [ ] Case-study / testimonial capture process.

Canonical: `operating-canon/governance/marketing.md` → `~/.claude/governance/marketing.md`.
