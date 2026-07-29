---
type: audit
status: draft
owner: Nik
created: 2026-07-29
ticket: https://github.com/Perpetuator-LLC/operating-canon/issues/16
---

# All-Sessions Rule Audit — classification & move plan

Boundary model under audit (Nik, 2026-07-29): **operating-canon = machine-wide rules that must make
sense in ANY session**; Perpetuator-specific content belongs in the Perpetuator vault canon;
engagement-specific content belongs in that engagement's overlay; **notes-nik = personal only**.

Classes: **(a) universal — stays** · **(b) Perpetuator-specific — move to vault canon, thin pointer
stays** · **(c) engagement-specific — move to that engagement's overlay** · **(d) ambiguous — Nik
decides**.

The recurring pattern found everywhere: **the RULE is universal, but a concrete BINDING (host,
store, rate, vault path, forge) is baked into it.** The fix is the already-adopted "policy SCOPE vs
config LOCATION" split (commit b4adc1e): keep the rule here, move the binding to the owning
vault/overlay, reference it as "the engagement's X".

## 1 · global/CLAUDE.md

| Section | Class | Finding / move |
|---|---|---|
| Workflow, Autonomy, Tag protocols, Tool usage, Implementation discipline | (a) | Clean — no engagement content. |
| Building context on demand → "Perpetuator vault knowledge / ADR-021 / local-mcp" | (b) | The on-demand-context rule is universal; the vault-graph binding is Perpetuator. Move the local-mcp/ADR-021 pointer to the Perpetuator overlay; here say "the active engagement's knowledge index, if one is declared". |
| Engagement-scoped identity (G8) | (a) | Rule is universal and exists precisely to protect the boundary. The WeOwn/capitalcopilot strike-example is a lived incident — see §5 "examples policy" (d). |
| Network control is not an agent capability | (a)/(d) | Rule universal. The enforcement note ("gateway DNS write tools deleted + tests") is Perpetuator infra — move the enforcement citation to the vault security canon. |
| Agent Secret Ban + secret patterns | (a) | Store-agnostic as written here. Clean. |
| Resource Registry | (b) | Rule (register every provisioned resource + dedupe tickets) is universal; the registry LOCATION (`Perpetuator vault …/Infra/Resource Registry.md`) is Perpetuator. Reword to "the engagement's resource registry (Perpetuator default: vault)". |
| Developer Flow (`merge/<agent>` → PR) | (a) | Universal mechanics. Forge-specific URL patterns already live in comms rules — see below. |
| Communication style → SSH alias examples (`cc-stage`, `cc-prod`, `lestrange`), `🔑 PROMPTS`/bao examples, Gitea URL pattern `git.perpetuator.io` | (b) | The rules (aliases-not-IPs, self-contained blocks, refs-as-links) are universal; the concrete alias inventory and forge host are Perpetuator bindings. Move the alias/forge inventory to the vault (ENDPOINTS/Repo-Homing docs already exist); keep the rules with placeholder-free *pattern* examples. |

## 2 · governance/ (the @-imported Core + on-demand domains)

**Leak check asked by the ticket:** only `governance/README.md` is @-imported into every session —
it is near-clean (see below). The seven domain docs load on demand, BUT they are loaded *by topic*,
not by engagement — a WeOwn session doing billing work loads `financial.md` and today reads
Perpetuator/Capital-Copilot rates. That is the concrete leak path. Proposed layering fix in §4.

| Doc | Class | Finding / move |
|---|---|---|
| README.md (Core, G1–G11, precedence) | (a) | Universal by construction. The FedArc line in "Engagement layering" is an *example of the mechanism* — acceptable, or genericize (d). |
| technical.md | split | Principles (host/prompt naming standard, IaC-first, software/state split, dev-flow mechanics) = (a). The concrete host table (`*.perpetuator.io`, `*.weown.*`), the `lestrange` box mapping, and cc-be topology citations = (b)/(c) — move the inventory to the vault infra canon; cite incidents per §5. |
| security.md | split | Posture, Secret Ban, ask-once, service-credential and runtime-injection standards = (a). Bindings — "OpenBao is Perpetuator-internal", the Infisical/WeOwn form, cc-fe/cc-be incident references = (b)/(c). Keep the store-agnostic rule (already 1a); move the store→engagement mapping table to each overlay. |
| operations.md | split | Hand-off/recipe format, header rule, prompts-line = (a). Knowledge-OS implementation, Tuleap retirement notes, vault exemplar paths = (b). |
| financial.md | (b)/(c) | "Rates are per engagement, declared in the engagement's config" = (a) and is the whole universal content. The actual rates (WeOwn $200/hr; Luke $25/hr Wise) are exactly what the rule says should NOT live here — move WeOwn terms to the WeOwn overlay, Luke/Capital-Copilot terms to the Perpetuator vault. **This is the sharpest current G8 leak.** |
| legal.md | (b) | Perpetuator LLC entity facts → vault. Universal residue: the IP-boundary rule (client IP never commingled). |
| marketing.md | (b) | Almost wholly Perpetuator GTM. Move; leave a pointer. Universal residue: none of substance — the domain doc may become a thin pointer entirely. |
| product.md | (b) | Perpetuator product roster + vault layout → vault. Universal residue: charter/State-doc convention, arguably (d). |
| secrets-registry.md | (b) | This is a LOCATION map of Perpetuator infra (bao paths, cc-fe/cc-be rows). Whole doc moves to the vault (Security area is index-excluded by design — verify the move target keeps that property). Thin pointer stays. |

## 3 · global/skills/

| Skill | Class | Disposition |
|---|---|---|
| badagent, capture, next, session-summary | (a) | Universal protocols. Minor: capture/badagent name `~/projects/operating-canon/...` paths — fine, that IS the machine-wide canon. |
| ticket | (a)/(d) | Shape universal; bound to the Perpetuator Gitea gateway. Either parameterize per engagement forge or accept as machine default (d). |
| export-thread | (a)/(d) | Mechanism universal; export TARGET is the Perpetuator vault. Parameterize the destination (d). |
| orchestrator, orchestrator-export | (b) | Perpetuator fleet SOPs (read vault SOP-ORCH-001/002). Move to a Perpetuator skills home or accept that the skill is a thin bootstrap whose canon already lives in the vault (current state is arguably already compliant — the SKILL.md is a pointer). (d) lean-keep. |
| nightly-signal-digest, nightly-sop-distill | (b) | Perpetuator vault pipelines → vault/Perpetuator skills home. |
| nightly-tuleap-reconcile | (b) | Tuleap retired 2026-07-25 (ADR-025). **Delete candidate**, not move. |
| weown-monday-invoice | (c) | WeOwn engagement → WeOwn overlay (notes-weown when it lands). |
| daily-2021-tundra-scan | (d)→personal | Personal (truck shopping). Belongs with notes-nik / personal layer (`~/.claude/CLAUDE.local.md` territory), not the shared machine canon. |
| capex-trough-leap-monitor | (d)→personal | Personal investing monitor. Same disposition as above. |

## 4 · Proposed layering fix (the ticket's second ask)

The model (engagement overlay wins on deliverable shape; canon wins on safety/conduct) is right;
the FILES violate it by baking bindings into the canon. Concretely:

1. **Every domain doc gets a "Bindings" rule instead of binding facts**: "resolve
   {store, forge, hosts, rates, registry} from the active engagement's overlay; Perpetuator's
   own overlay lives in the Perpetuator vault." Internal work then loads the Perpetuator overlay
   exactly like WeOwn work loads FedArc — symmetry instead of Perpetuator-as-default.
2. **Move targets**: Perpetuator bindings → vault (`Products/Perpetuator/...` canon; secrets map
   stays index-excluded). WeOwn bindings → the WeOwn overlay (notes-weown per the Vault Isolation
   spec — coordinate with that program, don't duplicate).
3. **Personal artifacts** (two skills above) → personal layer, out of the shared repo.

## 5 · Ambiguous items for Nik (class d)

| # | Item | Question |
|---|---|---|
| 1 | Lived-incident examples inside universal rules (cc-fe ESLint dropper, cc-alloy prompts, capitalcopilot G8 strike) | Keep inline (they teach the rule) or move to a vault "strikes" log with one-line citations? Recommend: keep one-line, move narrative. |
| 2 | `ticket` / `export-thread` skills | Parameterize per engagement, or accept Perpetuator forge/vault as the machine default? |
| 3 | `orchestrator` skills | Already thin pointers to vault SOPs — compliant enough, or move wholesale? |
| 4 | FedArc example in Core README | Keep as illustration or genericize? |
| 5 | `nightly-tuleap-reconcile` | Confirm delete (Tuleap retired). |
| 6 | Personal skills (tundra-scan, capex-monitor) | Confirm personal-layer destination before moving. |

No moves are performed in this PR — classification only (G4: Nik reviews, then moves ship as
follow-up PRs coordinated with the vault-side graduation program).
