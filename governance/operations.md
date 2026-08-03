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

## Execution efficiency — run-what-you-can, ≤3-step hand-offs, KPIs (2026-08-01, Nik-stated)

The global `CLAUDE.md` carries the resident rule (*Optimization priority & self-improvement*); the
mechanics + measures live here.

**Standing optimization priority** (strict; a lower rank never trades a higher):
**1 correctness · 2 tokens-to-complete · 3 token-frugality.** #2 vs #3: prefer a bigger single turn
that gets it right first time over a cheap guess that needs three retries — total tokens to the
*verified result* is what #2 minimizes.

**Run-what-you-can:** attempt every agent-runnable step yourself before composing a hand-off. The
human section contains ONLY their irreducible parts — secret entry, Touch-ID, SSH-to-live-infra, a
decision, a credential only they hold, or a harness-gated action you tried and were denied. Handing
over a step you could have run is a defect: it costs a human round-trip, the most expensive unit.
(Strike 2026-08-01: handed Nik a `bao kv put` I could attempt myself; should have tried it first and
handed over only the genuinely blocked part.)

**≤3-step batching:** a hand-off carries at most three human-run steps. The reason is token-economic —
if step 2 of an 8-step block fails, steps 3–8's output was wasted AND the whole block re-processes on
correction; three bounds the waste without the context-re-establishment cost of one-at-a-time. Steps
beyond three wait for the batch to report; fewer than three when steps are risky/irreversible.

**KPIs** (home = Strategy OKR board; draft proposal
`Engagements/Internal/Strategy/PROPOSAL Agentic Execution Efficiency (OKR).md`):

| KPI | Unit | Dir | What it catches |
|---|---|---|---|
| Correctness / rework rate | % | down | the P1 guardrail — a "done" later found wrong |
| Tokens-per-completed-task | tokens | down | total cost to a verified result |
| Human round-trips-to-completion | turns | down | the run-what-you-can + ≤3-step payoff |
| Wasted-output ratio | % | down | output for steps/plans never used (over-batching) |
| Canon-improvement cadence | count/week | up | the self-improvement loop actually firing |

**Self-improvement loop:** spot an improvement → implement it in the canon immediately (never a passive
note) → it compounds. The cadence KPI exists so the loop is visible, not aspirational.

## Hand the human a SCRIPT, not steps — self-logging by design (2026-08-02, Nik-stated)

When the human must run something, the deliverable is **one committed script invoked by one line**
(`bash ~/projects/.../thing.sh`), not a pasted block of commands — proven by the vault-store
migration (318 files / 839 MB: one line for Nik; the script carried rsync + sha256 verify + delete +
manifest). Why it wins on every rank:

- **Traceable** — committed beside the work; what ran is exactly what's in git, reviewable later.
- **Self-logging** — the script writes its evidence to a FILE (manifest, log, TSV) that the agent
  reads back itself, extracting only the parts it cares about. The human never hand-carries
  terminal output into chat, and big outputs never enter context wholesale (rank 3).
- **Verifiable mid-flight** — the agent polls the artifact (`wc -l` a manifest) while the human's
  terminal runs; no "paste me the output so far".
- **Idempotent + fail-safe** by construction (checksum-before-delete, guards) — properties a pasted
  block can't reliably carry.

Mechanics: script lives in the owning repo (committed BEFORE the human runs it); writes a
machine-readable progress artifact from the first seconds (a silent multi-minute script is a
hand-off defect — the human can't tell hung from working; strike 2026-08-02: the migrate script
printed nothing until done and Nik asked "is it hung?"); prints an explicit end-state summary; the
agent reads the artifact, never asks for the scrollback. The `## Command hand-off format` rules
(PROMPTS line, ► header, zsh-safety) still bind the one-line invocation.

## Act → verify, every action (2026-08-02, Nik-stated)

**Every operation is a pair: do the thing, then verify it had the effect you expected** — with an
independent check, not the action's own exit code. This is the per-action form of Workflow #8
(verify the whole task) and it prevents churn: a wrong assumption caught in 5 seconds costs one
probe; caught three steps later it costs the whole chain (rank 2+3).

- Wrote a file → probe the property that matters (exec bit, lint, parse), not "no error".
- Committed → `git show --stat HEAD` (nothing stray rode along). Pushed → ahead/behind is `0 0`.
- Moved data → checksum/spot-check at the destination AND absence at the source.
- Installed a job/service → force a run and read its output (`launchctl kickstart` + log).
- Claimed a fix → re-run the failing case, watch it pass.
- **Verify the CLAIM, not the vibe** (2026-08-02 strike: Nik saw an image render and concluded the
  symlink worked — but that file had never moved; the verifying probe is "a MOVED file renders").

Cheap-probe rule: the verify step should be the smallest observation that would catch the likely
failure (`grep -c`, `stat`, one-line probe) — verification is not a second full pass.

## Routines are infrastructure — they migrate, or the crew silently dies (2026-08-02, Nik-stated)

**Every scheduled task and skill is migration payload, equal to threads and tickets.** A migration
that carries threads but not routines hands the destination a crew that has stopped doing everything
nightly — and it fails *silently*, because a routine that never fires emits nothing to notice.

**Verified defect (2026-08-02):** `~/.claude/skills` is a symlink into `operating-canon` (versioned,
portable ✅) but **`~/.claude/scheduled-tasks/` is a plain directory** with no canon backing and no
handling in `install.sh`/`update.sh` — 14 tasks existing on exactly one Mac. Bodies migrate, schedules
do not. Until that is fixed, every migration must inventory schedules by hand.

Two durable rules:

1. **A routine declares its own portability.** Frontmatter carries `scope`
   (`portable` · `host-local` · `engagement:<name>`), `canon_origin`, `canon_version`, `schedule`, and
   `retired:` for tombstones. Without these the destination can only guess, and guessing either drops
   work or clones machine-specific junk onto every host.
2. **Reconcile, never copy.** At the destination each routine resolves to exactly one of: **ADD**
   (missing + portable) · **UPDATE** (stale) · **ADOPT UPWARD** (destination is newer → PR it back to
   canon *before* the migration closes) · **INVESTIGATE → adopt or stop** (present here, unknown to
   canon) · **STOP** (tombstoned — disarm, keep the body) · **LEAVE ALONE** (host-local) · **LEAVE
   DORMANT** (inactive engagement). **Never delete during a migration** — disarm and tombstone; a
   deleting migration is unrecoverable. **Adoption is bidirectional**: migration is exactly when
   host-local improvements get promoted, and an undecided destination routine is a defect.

Acceptance is behavioral, not documentary: every portable routine **armed and fired once** at the
destination. Full matrix + inventory procedure: `global/skills/orchestrator-export/SKILL.md`.

## "Deliver to the forge" assumes the forge is REACHABLE (2026-08-02)

The *Unattended runs* rule — deliver to a durable, polled channel, never a run summary — has a
failure mode it did not name. On 2026-08-02 the nightly ingest found `mcp.perpetuator.io` returning
**502** while `git.perpetuator.io` answered **200**: the forge was healthy but every `gitea_*` tool
routes through the gateway, so the routine had **no durable delivery channel at all**. Separately, a
scheduled run **cannot complete an interactive OAuth flow**, so an OAuth-gated MCP entry is
structurally unusable unattended even when the service is up (the fix is M2M auth — the gateway
already supports OpenBao AppRole → Transit-signed JWT).

So an unattended routine must:
- **Probe the delivery channel before claiming delivery** (act → verify, above). "Filed a ticket" is
  a claim; an unreachable gateway makes it false.
- **Record the failure where the work lives** — `work_item_sync.status: pending` in the *entry*, never
  in a log file — so a later run can find and reconcile it.
- **Make the outage the run's headline**, not a footnote. An undelivered finding plus an unread
  summary is lost work, which is the exact outcome the forge rule exists to prevent.

## TODO (fill in / publish)
- [ ] Meeting cadence + standing-agenda standard per engagement.
- [ ] Vendor/tool evaluation + registry process.
- [ ] Weekly review / ops-review ritual.

Canonical: `operating-canon/governance/operations.md` → `~/.claude/governance/operations.md`.
