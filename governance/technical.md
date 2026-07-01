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

## Where this doc lives
Canonical: `claude-config/governance/technical.md` → `~/.claude/governance/technical.md`. Extends the
[Constitution](README.md). Security-adjacent rules (secrets, supply-chain, access) live in
[security.md](security.md).
