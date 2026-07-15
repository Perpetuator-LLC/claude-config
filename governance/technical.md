---
type: governance
domain: technical
role: CTO
status: draft
owner: Nik
created: 2026-06-26
extends: governance/README.md
tags: [technical, infra, dev, host-naming, toolchain]
---

# Technical Governance (CTO)

How I build: infrastructure, hosts, toolchain, architecture, and the development workflow. Layers
under the [Constitution](README.md); a repo's own `CLAUDE.md` wins on repo-local specifics; on client
work the client's technical conventions win on *their deliverable's shape* (precedence in the Core).

---

## Host & role naming

**Convention: `<role>@<host>`** — readable straight from the shell prompt, telling you *which host*
and *as which role* at a glance.

### `<host>` — reverse-DNS, no TLD
Take the service FQDN, **drop the public suffix/TLD, reverse the remaining labels, join with `-`**:

| Service FQDN | Host name |
|---|---|
| `hs.perpetuator.io` | `perpetuator-hs` |
| `sso.perpetuator.io` | `perpetuator-sso` |
| `git.perpetuator.io` | `perpetuator-git` |
| `crm.perpetuator.io` | `perpetuator-crm` |
| `ai.weown.agency` | `weown-ai` |
| `do.weown.tools` | `weown-do` |
| `lite.burnedout.xyz` | `burnedout-lite` |
| `perpetuator.io` (apex, no subdomain) | `perpetuator` |
| `a.b.c.io` (deep) | `c-b-a` |

Rules of the algorithm: strip the full **public suffix** (`.io`, `.agency`, and multi-label suffixes
like `.co.uk`), reverse label order (most-specific → least-specific becomes org-first), lowercase,
hyphen-join. Org always sorts first, so all of an org's hosts group together.

### `<role>` — the least-privilege function
The username is the **role you're operating as** on that host, mapped to least standing privilege:
`ops`, `deploy`, `admin`, `app`, `backup`, … One role = one privilege scope. (Migration in flight:
`deploy@` → **`ops@`**.)

### Why
- The prompt `ops@perpetuator-hs` instantly says *host = `hs.perpetuator.io`*, *role = ops* — **no
  TLD noise**.
- Reverse-DNS order groups every host by org (like reverse-domain package naming) so they sort
  together in inventories, configs, and `~/.ssh/config`.
- The role in the prompt **is** your current privilege — pairs with least-standing-privilege
  (Security governance): you can see you're not `admin@` when you shouldn't be.

### Open reconciliation (TODO — confirm with Nik)
Map this onto the physical box **`lestrange`** (baremetal) and its containers/VMs: are the
reverse-DNS names the **logical service hosts** (containers/VMs/SSH-config aliases), with `lestrange`
the metal underneath? Document the metal↔logical-host mapping once confirmed. Apply the same
convention to `~/.ssh/config` Host aliases, Ansible inventory names, and Tailscale/Headscale machine
names so a name means the same thing everywhere.

---

## Toolchain — use what exists, never reinvent
Every repo pins its language/dependency tooling; **always use what's there**. Never global-install,
never bare `pip`, never ad-hoc venvs outside the established toolchain.

| Language | Version manager | Dependency manager | Pin file |
|---|---|---|---|
| Python | pyenv (`.python-version`) | **poetry** (`pyproject.toml`) | `poetry.lock` |
| Node | volta / nvm (`package.json`.volta / `.nvmrc`) | **npm** (`package.json`) | `package-lock.json` |

`cd` into a service → the pin auto-activates. Use `poetry install`/`poetry run`, `npm install`/
`npm run`. In monorepos, copy a sibling service's structure. **Prefer building minimal in-house over
adding a dependency** (see Security — supply-chain): stdlib-first, reuse already-trusted deps, pin
versions.

---

## Architecture & implementation discipline
- **Only directly-requested or clearly-necessary changes.** No unrequested features, refactors, or
  "improvements"; no docstrings/comments/types on code you didn't change; no error handling for
  impossible cases; no abstractions for one-time ops.
- **Write code that reads like its neighbors** — match comment density, naming, idioms.
- **Read a file fully before editing it.** Change approach if a patch fails twice; change strategy
  after 3 failed attempts on one file.
- **Reproducibility — everything scripted.** Never configure a service by hand via UI/ad-hoc command:
  deployments → playbooks, identity clients → roles, secrets → bootstrap scripts, DB → migrations.
  If you're doing it manually, stop and script it, commit the script, then run it.
- **Decompose the gateway / keep services thin** — namespaced tools (`{service}.{tool}`); a thin
  aggregator over per-service servers, not a monolith.

---

## Git & worktrees
- **Branches: descriptive `type/slug`** (`fix/podcast-feed-cache`), never `claude/<random>`.
- **Commit or push only when asked.** End commit messages with the configured `Co-Authored-By` and
  PR bodies with the Claude Code attribution line.
- **Parallel-worktree workflow:** the main worktree (`.git` is a dir) is the human's testing
  stage — **read-only, never edit/commit there**; agents work in linked worktrees
  (`<repo>/.claude/worktrees/<name>`). Use `git wt` (`status` / `reap`) to manage them. Hand off for
  human testing with a **TEST THIS** block.
- **Never bypass safety checks** (`--no-verify`); ask before destructive/irreversible git ops
  (force-push, hard reset, amending published commits, deleting branches you didn't create).

---

## Service topology: software/state split (2026-07 standard — the cc-be model)

Every service separates **software** (image/repo, rebuildable) from **state** (ONE named
docker volume: DB data via `PGDATA` subdir + dumps + anything needed for identical
resurrection). The **runnable unit** for DR is: image (or repo@ref) + state volume +
OpenBao (secrets) + object storage (media) + edge/DNS — restore = provision box, restore
volume, `up` at the ref. Two hard rules paid for in a prod outage (cc-be 2026-07-06):

- **A stateful-path flip (PGDATA/volume/bind relocation) NEVER ships ahead of its data
  migration.** The migration is atomic with, or precedes, the compose change — otherwise a
  routine deploy silently boots the service on EMPTY storage while the real data sits in
  the abandoned path. Stage-first, and gate on data-present.
- **Image ↔ state is a compatibility contract**, not a pairing: restore is always
  *volume → migrate with this image → verify counts*, never "attach and up".

## Deploys & health (2026-07 standard — pull-based)

- **Boxes deploy themselves** (webhook, HMAC-verified, + catch-up timer gated on CI-green
  commit status). CI holds no credential that can reach a box; SSH stays operator-only.
- **Two health surfaces, never conflated**: `/health/` = liveness (shallow, no DB — the
  container healthcheck) and `/health/ready/` = readiness (DB reachable + no unapplied
  migrations, 503 on fail — what MONITORING probes). A liveness-only monitor watched a
  total functional outage stay green.
- **Monitoring must not share fate with what it watches**: in-app dead-men (celery/beat)
  are a layer; the authoritative probe is external (blackbox → Alertmanager).
- **Scripts re-exec'd by path need the git exec bit AND `exec bash "$path"`** — checkout
  restores committed modes; a 0644 script killed a prod deploy with "Permission denied".

## Shell & CI gotchas (each cost a live failure)

- **Unanchored ignore patterns** (`backups/` in `.gitignore`/`.dockerignore`) match at
  EVERY depth — `scripts/backups/` was silently never committed and would've been excluded
  from images. Anchor to root (`/backups/`).
- **DinD runners**: the daemon never sees the runner's filesystem — `-v` mounts of runner
  files materialize as empty dirs. Bake files into a scratch image (`COPY` via build
  context) instead; the context tarball IS DinD-safe.
- **Pipelines mask failures**: `a | tee`/`a | gzip` return the LAST command's status — any
  gate or artifact-producing pipe runs under `set -o pipefail` (bash, not dash).
- **Fixed shared resource names race concurrent sessions** (one pre-push test-DB name
  broke every first push while two agents worked the repo) — derive per-checkout names.
- **Commands handed to the human run in THEIR shell** (zsh here): `read -rsp` is
  bash-only; zsh is `read -s 'VAR?prompt'`. A silent mismatch wrote empty secrets twice.

---

## Where this doc lives
Canonical: `claude-config/governance/technical.md` → `~/.claude/governance/technical.md`. Extends the
[Constitution](README.md). Security-adjacent rules (secrets, supply-chain, access) live in
[security.md](security.md).
