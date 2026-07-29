---
type: governance
domain: executive
role: CEO
governs: all-surfaces
status: draft
owner: Nik
created: 2026-06-26
canonical_home: operating-canon/governance/
distribution: "install.sh → ~/.claude/governance/ + @import into global CLAUDE.md; init-project.sh → every repo surface"
---

# Governance — The Constitution (Executive / Core)

The canonical, **tool-agnostic** standard for **how I (Nik / Perpetuator LLC) work** — across every
project, repo, and AI surface. This is the **Executive (CEO)** layer: the universal rules, the
**precedence model**, the **engagement-layering** model, and the index of the role-specific
domains. It contains **no secrets and no client-specific config** (those live in each repo's own
config and each engagement's overlay).

> **Status: draft** until reviewed and published (G4 — nothing an agent authors is authoritative
> until a human publishes it). **Distributed** from the **`operating-canon`** repo: `install.sh`
> symlinks `governance/` → `~/.claude/governance/` and `@`-imports this file into the global
> `CLAUDE.md` (so every session everywhere inherits the Core); `init-project.sh` seeds a thin
> pointer into each repo's surfaces (`CLAUDE.md`, `AGENTS.md`, Copilot, Continue, Cursor).

---

## How governance is organized (C-Suite domains)

"How I do things" is partitioned by **C-Suite domain** — one doc per role. This Core is the
**Executive** layer; the seven role docs are the domains. **The Core is always loaded; the domain
docs load on demand** — consult the relevant one when working in that area.

| Domain | Role | Covers | Doc |
|---|---|---|---|
| **Executive / Core** | CEO | this constitution — rules, precedence, distribution | `governance/README.md` |
| **Technical** | CTO | engineering, infra, **host/naming**, toolchain, architecture, dev workflow | `governance/technical.md` |
| **Security** | CISO | secrets, supply-chain, threat model, access, least-standing-privilege | `governance/security.md` |
| **Financial** | CFO | invoicing, billing, rates, expenses, the money side of contracts | `governance/financial.md` |
| **Legal** | CLO | NDAs, contracts, IP, compliance, entity | `governance/legal.md` |
| **Marketing** | CMO | brand, voice, content, GTM, lead capture | `governance/marketing.md` |
| **Operations** | COO | process, project management, the Knowledge-OS / SOP system, people-ops | `governance/operations.md` |
| **Product** | CPO | product strategy, requirements, roadmap conventions | `governance/product.md` |

---

## Precedence — the layered-merge model

Resolve guidance top-down; **higher wins**:

1. **The human's explicit in-session instruction.** Always wins.
2. **Client / engagement governance** — for *that client's deliverables*: how they want THEIR
   product produced (their conventions, definitions, protocols). Declared per engagement (see
   *Engagement layering*). **Wins on the shape of their deliverable.**
3. **My role governance** (these domain docs) — *how I work*: craft, security posture, process.
   **Always applies and fills any gap** the client didn't specify.
4. **Core operating rules** (the G-rules below) — the universal baseline.

**On client work it is a MERGE, not a switch:** my craft + their product-shape. For the
*deliverable's shape and conventions*, the client wins; for *my professional conduct, security, and
safety*, I hold my standard regardless. **Flag genuine conflicts** — never silently choose between a
client's way and mine; surface it.

### Engagement layering (how a client's governance attaches)
Each engagement declares its client-governance overlay in its own `CLAUDE.md` (a `governance:`
pointer). Example: **WeOwn → FedArc** (SharedKernel · CCC · PROTOCOLS · BEST-PRACTICES; summarized in
`Engagements/WeOwn/FedArc/`). Inside that engagement's repo/folder, layer the client overlay on top
of my role governance per the precedence above. **Internal (Perpetuator) work has no client
overlay** — my governance is the whole stack.

---

## Core operating rules (universal — the G-rules)

- **G1 — Single source of truth, latest-wins.** Each fact has one authoritative home; a
  current-status field reflects the *most-recent* truth and is never regressed by older information.
  Compare the *event date*, not when you processed it.
- **G2 — History is append-only.** Never rewrite immutable records (event logs, journals,
  decisions). Correct by appending a dated update.
- **G3 — Markdown + frontmatter, everywhere.** Every document is portable Markdown with YAML
  frontmatter and `[[wiki-links]]`. Never trap content in a format it can't be exported from.
- **G4 — Draft → review → published.** Nothing an agent authors is authoritative until a human
  publishes it (a `status` gate). Stage high-risk changes for review rather than applying silently.
- **G5 — Every decision is recorded and owned.** A decision gets a stable ID, an owner, a date, and
  its rationale. Link it from where it's enacted up to the strategy it serves.
- **G6 — Every artifact has one home and one owner.** File each in the correct layer (placement
  policy below). Cross-link; never duplicate.
- **G7 — Attribute and make reversible every agent write.** Log who/when/what (human vs. agent).
  Mass edits, moves, deletions must be staged or trivially undoable.
- **G8 — Respect boundaries.** Keep engagement/client/tenant data separated. Never leak secrets,
  tokens, or one client's context into another's surface.
- **G9 — Trace upward and downward.** Work traces up to the requirement/initiative/strategy it
  serves, and down to the evidence that proves it done.
- **G10 — Capture knowledge back.** Reusable procedure or insight boils up into the knowledge layer
  (SOPs / Knowledge Base) so it's never re-derived.
- **G11 — Passport & route-before-create.** Every document carries a frontmatter **passport** whose
  `type` fixes its one canonical home and mutability. Before creating, **route**: find the existing
  canon and update it; a parallel file is the exception and must be justified. Rich canons, thin
  pointers.

---

## Artifact placement (where each artifact lives)

Work follows one **strategy-to-execution spine**; each layer has a home (roles, not products — map
them to concrete tools in each repo's config):

| Layer | Artifacts | Home |
|---|---|---|
| **Strategy & measurement** | Theme · Objective · Key Result · KPI · Snapshot | **KMS vault** (durable, cross-initiative) |
| **Definition & scope** | Initiative · Requirement Package · Requirement · Capability | **Initiative repo** |
| **Build & ship** | Work Item · Release | **Code repo** (git provider issues + releases) |
| **Cross-cutting** | Decision/ADR · RAID · Responsibility · Evidence | recorded closest to where enacted, linked upward |
| **Registry & knowledge** | Instances · Knowledge Base (rules, protocols, learnings, contributors) | **KMS vault** |

**Cross-cutting records** (refined 2026-07-25): ADRs/Decisions, RAID/Risks, and Evidence/Learnings
are **repo-specific** (live in the owning repo's docs); RACI/Accountability, Objects
(Instances/People/Organizations/Definitions/Meetings), and Governance
(Rules/Protocols/Best-Practices/SOPs) live in the **KMS vault as Bases + documents**.
Working status map: vault `PLAN-ARTIFACT-CONSOLIDATION-1` (Artifact Migration — Consolidation
Pass); repo-side standard: mcp `docs/guides/doc-standards.md`.

A PM tool (Tuleap/Jira/Linear) MAY *mirror* the spine for tracking, but the **authoritative source**
for each artifact is its home above — the mirror is a convenience, not the record.

---

## Distribution & precedence of files
`operating-canon` is the **baseline**. A repo's own `CLAUDE.md` / `AGENTS.md` may extend or override it
for that repo's specifics — the more-specific, more-local instruction wins for that repo. A human's
in-session instruction wins over all files. This Core reaches every surface via the table at the top;
if your tool didn't load it, open `~/.claude/governance/README.md`.

---

## Document history
| Date | Version | Change | By |
|---|---|---|---|
| 2026-06-23 | 0.1.0 | Initial single-file GOVERNANCE.md (G-rules + placement) in the Perpetuator vault | Nik |
| 2026-06-26 | 0.2.0 | Split into C-Suite role domains under `claude-config/governance/`; added precedence + engagement-layering; canonical home = claude-config | Nik (via Claude Code) |
