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

## Command hand-off format (the full standard)
*(The global `CLAUDE.md` carries the condensed rules resident; the exhaustive format + the
caught-live rationale live here, loaded when composing a non-trivial hand-off.)*

Every command handed to the human is **self-contained, runnable as-is, and verified against live
state** — which HOST, which DIRECTORY, which USER, the exact command; never "the command above."

- **Run-context header, OUTSIDE the fence:** `► <machine>` — just the arrow + machine name/alias
  (`► your Mac`, `► cc-stage (ops)`). The working directory is a literal `cd <dir>` as the FIRST LINE
  of the block, so the paste works from any cwd. The fenced block contains ONLY runnable lines (a
  header inside it breaks select-all copy-paste).
- **One block = one machine, copy-paste-runnable whole:** when work happens on a remote box, the
  `ssh <host>` login is its OWN block; the on-box commands go in a SEPARATE block headed `► <box>` —
  never one block that mixes `ssh host` then commands meant for the remote side (pasted whole, the ssh
  eats the rest as local leftovers).
- **`🔑 PROMPTS` line (outside the fence) when the block prompts for anything** — enumerate every
  prompt IN RUN ORDER, terse `credential → machine`, nothing else. Each names:
  - **WHICH machine/service** it authenticates to (host + user) — the prompt itself (`BECOME
    password:`, a bare Touch-ID dialog) never says which box. `--ask-become-pass` targets the
    PLAYBOOK's hosts (read the inventory), not the control Mac.
  - **The bao ROLE** when any command talks to OpenBao (`operator` / `provisioner` / `admin`) — a
    wrong-role session fails deep in the run, not at the prompt.
  - **The NAMESPACE** — cloud project/account/org/tenant, kube context — provider consoles scope per
    project; a token minted in the wrong one plans against an empty world.
  - Example: `🔑 1) Touch ID → bao preflight  2) BECOME → cc-stage  3) BECOME → cc-prod`. No
    parentheticals, no reassurances.
- **Before naming a credential's SOURCE, look up its POLICY class in the engagement docs** — ephemeral
  mint-use-revoke tokens (e.g. hcloud infra keys) must never be pointed at a store; the committed
  runbook's custody wins over a guessed one.
- **NO `<placeholders>` — for ANY value:** if a value isn't known at hand-over, the block discovers it
  itself via command substitution against the live source (`aws s3 ls … | sort | tail -1`,
  `git rev-parse`); if it genuinely can't, split the recipe at the discovery point. A secret is
  acquired via `read -rs`/stdin inside the block, never a placeholder the user pastes.
- **Steps in execution order** — the order on screen IS the order to run. Never present blocks A, B
  then say "do B first"; reorder the presentation. Decision points are explicit forks ("If X → step 5;
  if Y → step 7"). Never "add the secrets from above" — repeat the concrete detail inline.
- **Verify against live state before handing over** (`test -f`, `git show br:path`, a read-only API
  call), especially when YOU moved/committed the referenced file mid-session (their shell is on a
  branch/dir that lacks your change). "Live state" includes provider-side catalogs (instance types,
  image names, API enums) — verify read-only against the live API; catalogs rot. Before pointing the
  human at a URL/UI/endpoint, probe it yourself (`curl -s -o /dev/null -w "%{http_code}"`, `docker ps`);
  when they report an error against something you handed over, your FIRST move is the same probe, not a
  theory.
- **Handed git commands are fully explicit** — `git pull origin main`, `git push origin <branch>`,
  never bare `git pull`/`git push`. Before ANY pull/merge into a checkout (yours or theirs) verify it's
  on the expected branch (`git -C <dir> symbolic-ref --short HEAD`) and say you verified — worktrees get
  switched by parallel sessions. Prefer running a new file from a checkout that already has it, leaving
  their working branch untouched.

## TODO (fill in / publish)
- [ ] Meeting cadence + standing-agenda standard per engagement.
- [ ] Vendor/tool evaluation + registry process.
- [ ] Weekly review / ops-review ritual.

Canonical: `claude-config/governance/operations.md` → `~/.claude/governance/operations.md`.
