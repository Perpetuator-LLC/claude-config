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
here) → **SOP** (evergreen procedure) **+ Gitea issues** (work backlog on the owning repo). Nightly
jobs keep it fresh: `zoom-ingest → signal-ingest → sop-distill → cockpit-rollup`
(**tuleap-reconcile retired 2026-07-25** — Tuleap is being decommissioned, ADR-025 / mcp#138).
Canonical implementation: `Engagements/Internal/Products/Perpetuator/Knowledge-OS.md`.

- **Mandatory processing:** any new input (meeting/Signal/email/doc) → journal entry → CTO analysis
  (decisions D#, discoveries Disc#, action items) → update State → **file/refresh the Gitea issue on
  the owning repo** (dedupe first) → mark processed. **Never sync to Tuleap** — it is frozen.
- **Action items carry** {owner, size, priority, horizon, source, issue-ref}. P0/P1-this-week
  surface in the **cockpit** (top of the State doc); everything else waits in the repo queue, pulled up as
  capacity frees. **Plan by capacity, not priority** — every item = hour estimate + scheduled week
  vs a fixed weekly capacity; new work triggers a displacement decision, never silent overflow.

## Project / initiative creation
Starting an initiative = define its goal as a **SMART checkbox list** (refine until every box is
checkable). New initiative → **a Gitea repository** (+ its vault folder for the strategy layer);
requirements/capabilities land in that repo's `docs/`, work items as its issues. Record the repo in
the State doc. (Artifact placement canon: the Constitution's placement table.)

## Ticket due-diligence (route-before-create for work items)
G11 applies to tickets/issues exactly as to documents (added 2026-07-20 — Nik: every ticket
creates ongoing carrying cost; spend the diligence up front):
- **Before creating ANY ticket** (Gitea issue, PM item): list the target queue's open
  items — and recent closed when the topic smells recently-worked — and match by **goal, not
  wording** ("ship logs to Loki" ≡ "promtail on the app boxes").
- **Match found** → comment the new context onto the existing ticket (re-label/re-title if scope
  grew). **Subset** → checklist item on the broader ticket. **Genuinely new** → create, naming in
  the body which adjacent tickets were checked and why this isn't them.
- **Backlog sweeps**: N candidate items ≠ N new tickets — route each against the existing queue
  first. Duplicate found later → close-as-dup immediately with a verified pointer, don't let twins
  accumulate work.
- Mechanics for Gitea live in the `/ticket` skill (dedupe step is mandatory there).
- **Every ticket carries a priority (P0–P3) AND exactly one type label (2026-07-29, Nik —
  organizational requirement, all repos):** `bug` (built behavior is wrong) · `enhancement`
  (new capability / gap / decision / spike / epic) · `performance` (correct but too slow/heavy).
  Type labels use the house colors — `bug` purple `#5319e7`, `enhancement` blue `#1d76db`,
  `performance` dark blue `#0052cc` — so they read as one organizational family, distinct from
  the red-to-green priority ramp. An unlabeled or type-less ticket in a sweep gets best-guess
  labels on sight (same rule-24 reflex as priorities).

## Ecosystem diagrams (C4 PUML with status colors)
Added 2026-07-25 (Nik directive; exemplars: vault "WeOwn.Chat - C4 Container.puml", mcp
`docs/diagrams/perpetuator-platform-c4-container.puml`):
- **Source of truth is the `.puml`**; rendered images are committed conveniences regenerated with
  `plantuml -tpng` — always commit both together.
- **Placement by altitude (G6/G11)**: Strategy/Theme/OKR/KPI-level views → the **vault** beside
  the strategy docs; Requirements/Capabilities/Container-level views → the **owning initiative
  repo's `docs/diagrams/`**. One home; the other layer links, never copies.
- **Four status tags, always with a legend**: `done` green (live-verified) · `partial` amber
  (built, not fully live) · `missing` red (decided but absent) · `spike` purple (**need known,
  technology unchosen — every purple box implies an open SPIKE ticket**). Every non-green box
  cites its ticket `[#NN]`; dashed Rels = future flows.
- **Freshness contract**: flip a box's status in the same PR/session as the change that flips it;
  the diagram header names its companion status doc when one exists.

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
- **Hand-over blocks tee to a watched log so the agent auto-progresses (2026-07-29, Nik-requested).**
  A human-run block whose outcome the agent needs (playbook run, ceremony, rotation) should not end in
  "paste me the output" — that makes the human the transport. Instead:
  - The block wraps the command so the human still sees everything live AND a log captures it, with
    the REAL exit code preserved: `{ <cmd>; echo "EXIT=$?"; } 2>&1 | tee -a ~/.agent-handoff/<task>.log`.
    The `{ …; echo EXIT=$?; }` group records the command's own status BEFORE the pipe, so tee's exit
    code doesn't mask a failure. Do NOT reach for `set -o pipefail` in a pasted block (interactive-shell
    ban stands) and don't build fancier fd plumbing — pipe-to-tee return-code games get complex fast;
    the brace-group idiom is the whole trick. `nice` the command only if it's genuinely heavy.
  - The agent ARMS THE WATCH BEFORE handing the block over: on macOS there is no inotify — use
    `fswatch` if installed, else a background poll of the log's mtime/size (or the harness Monitor
    tool); on Linux, `inotifywait`. On change, read the tail, act on `EXIT=` and the content in BOTH
    directions — failure → diagnose immediately, success → advance the next step — without waiting for
    the human to report back.
  - Existing specializations of the same principle: ansible runs are already watched via
    `infra/ansible/logs/ansible.log` (grep `fatal:`); this generalizes it to ANY handed command.
    Secret-bearing prompts stay OUT of the log (`read -rs` reads from the tty, so hidden input never
    reaches tee — but never `echo` a secret into the wrapped group).

## TODO (fill in / publish)
- [ ] Meeting cadence + standing-agenda standard per engagement.
- [ ] Vendor/tool evaluation + registry process.
- [ ] Weekly review / ops-review ritual.

Canonical: `operating-canon/governance/operations.md` → `~/.claude/governance/operations.md`.
