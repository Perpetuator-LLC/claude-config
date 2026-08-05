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
- **Lifecycle check before adoption — no EOL components in new infra.** Before introducing ANY
  component (image, library, collector, proxy), verify its lifecycle status AS OF TODAY (EOL date,
  deprecation, named successor) — vendor docs/release notes, not memory; training-data familiarity
  is a trailing indicator (caught 2026-07-18: Promtail was wired into new log shipping four months
  after its EOL; Grafana Alloy was the successor). EOL/deprecated components never enter new
  builds; discovering one already live creates a migration ticket in the same session. The hygiene
  protocol's component-lifecycle reconciler audits the estate for aging components.
- **Interactive credential prompts name themselves.** Any playbook/script that will prompt a human
  for a credential announces WHICH one (account + host, e.g. `🔑 sudo (BECOME) password for
  sooth@lestrange`) — never a bare `BECOME password:`/`Password:`. Ansible: a `vars_prompt` for
  `ansible_become_password` on the play (run WITHOUT `--ask-become-pass`, which would double-prompt);
  the prompt text cannot template inventory vars (rendered pre-binding), so the author writes the
  literal account@host. Shell: `read -rs` prompts carry the same naming. Reference:
  mcp `playbooks/posthog.yml` (2026-07-16).

---

## Developer flow — feature branch → integration branch → one PR
Default: work locally on feature branches, integrate into this machine's standing integration branch,
push ONLY that. One remote branch → one CI build → one PR the human reviews once. No per-feature
remote branches, no PR-per-branch churn, no rebase cascade after every merge to main. *(Resident
summary lives in the global `CLAUDE.md`; the full mechanics are here.)*

- **Branch: descriptive `type/slug`** (`fix/podcast-feed-cache`), never `claude/<random>`. Work,
  test, commit there; feature branches stay LOCAL by default (push one to remote only as end-of-day
  BACKUP — never its own PR; delete after it lands).
- **Integration branch = `merge/${USER}-${MACHINE}`** — exactly
  `merge/$(whoami)-$(hostname -s | tr 'A-Z' 'a-z')` (this Mac: `merge/nik-mac`). Compute it, don't
  improvise (no `merge`, no `merge/nik`, no `integration/*`, no suffixes). It holds the integrated
  work of THIS agent-context; merges into it happen LOCALLY, so never share one across users/machines.
  Collaborated / multi-party work uses the classic feature-branch→PR flow instead. Legacy plain
  `merge` branch → migrate delete-before-create (`git branch -m merge merge/<agent>` →
  `git push origin --delete merge` → `git push -u origin merge/<agent>`).
- **Integrate + keep ONE open PR:** when a feature branch is done, switch to the integration branch
  (create from `origin/<default>` if absent), rebase-merge the feature branch in, resolve conflicts
  yourself. Push ONLY the integration branch and keep ONE open **classic** PR → default. A merged PR
  can't reopen — each review cycle is a fresh PR; WITHIN a cycle plain `git push origin merge/<agent>`
  updates the open PR. OPEN the PR yourself (gitea/gh/API); hand over a one-click compare URL only when
  the PR tool is unavailable, and say why. **NEVER AGit (`refs/for/…`) for the integration branch**
  (retired 2026-07-04, cc-be #46/#47 — virtual head 404s, matches CLOSED PRs, mints duplicates).
- **After the human merges:** the integration branch has DRIFTED (rebase/squash left old SHAs whose
  content is now in main). REFRESH it — never route around it: `git reset --hard origin/<default>`,
  then cherry-pick back ONLY still-unmerged commits (`git cherry -v origin/<default>
  origin/merge/<agent>`: `-`=already in main, drop; `+`=keep, incl. other sessions'), then
  `--force-with-lease`. "The shared branch looks messy" is NOT a reason to bypass it with a side PR —
  that's exactly the state this refresh cleans, and it must be cleaned ON the branch.
- **Multi-session discipline:** when sessions share a repo, none does code work in the root or
  integration checkout — each works in its OWN linked worktree; the integration checkout is touched
  only for the atomic verify-branch → merge → push, then returned clean. A conflict you didn't create
  → flag + STOP; a conflict during your own merge → complete it (latest-wins toward main for files you
  didn't author).
- **Integration ops run in a STANDING, fully-provisioned checkout** (the root, or one dedicated
  `<repo>-merge` worktree with venv/deps/`.env`/inventories) — merging + pushing fire the repo's full
  hook gauntlet, which needs the environment; ad-hoc worktrees yield cascading bogus failures
  (missing venv/`.env`/`logs/`). Ad-hoc worktrees are for CODE CHANGES only.
- **Branch in the root checkout when it's free**; if it's dirty with the human's work, use a linked
  worktree and say why. Manage worktrees with `git wt` (`status` / `reap`); never
  `worktree remove --force` / `branch -D` something you didn't create without checking `git wt status`.
  Hand off human-only verification with a **TEST THIS** block.
- **Commit or push only when asked.** End commit messages with the configured `Co-Authored-By` and PR
  bodies with the Claude Code attribution. Never bypass safety checks (`--no-verify`); ask before
  destructive/irreversible git ops (force-push, hard reset, amending published commits, deleting
  branches you didn't create).
- **Condense & consolidate**: few well-scoped commits over many micro-commits; one branch/PR per
  related change. **Fix bugs you find while working** (regression test, same/sibling commit,
  documented) — defer only if it balloons the diff. **Finish before hand-over**: test, validate,
  security-scan what you touched, push, present merge-ready.
- **Script the recipe on the second hand-over**: any multi-step ops/deploy sequence handed over twice
  becomes a committed script (all flags baked in — e.g. a service `deploy.sh`).
- **Prompt & host-name standard**: every credential prompt (script AND hand-off `🔑 PROMPTS` line)
  says WHAT / WHERE-from / WHICH machine-or-service. Scripts source the format from
  `${CLAUDE_LIB:-$HOME/.claude/lib}/prompt.sh` (`prompt_secret` / `prompt_plain`). Machine NAMES are
  engagement DATA with one source of truth — the project's ansible inventory — never hardcoded
  (`resolve_host <group>`). Placement: universal tooling → `operating-canon`; engagement data
  (hostnames, registry, custody) → the engagement; secret VALUES → the store + off-box.
- **Session pre-flight**: an operator script needing a specific auth ROLE verifies the ACTIVE session
  IS that role BEFORE the work and remediates, rather than failing deep in a run (`ensure_bao_role
  <role>` in `prompt.sh`). Generalizes to any scoped credential: detect → remediate → proceed, up front.

## IaC-first — production & infra changes (2026-07-14 standard)
**Production state is only touched through committed, testable, environment-loaded surfaces — never
ad-hoc SQL/shell typed on a box or handed over.** Every read or write against a prod/infra system
goes through, in order: (1) the app's own **committed command surface** (management command, CLI
subcommand, rake task) run under the standard runtime env-injection (the OpenBao exec-injector) so
secrets load normally; (2) a **committed script/playbook** (ansible/tofu/repo `scripts/`), reviewed,
versioned, re-runnable; (3) only for genuine one-time break-glass, a hand-over block — and then the
SECOND occurrence gets scripted and the first gets an issue to backfill the command surface.
Schema/data changes belong in migrations. Handing the human an ad-hoc mutation of a live host (inline
`python`/`sed` heredocs against live files, `docker` CLI state changes, console clicks, hand-edited
on-box configs) is a VIOLATION even when it "works" and even for a one-off — it creates drift the IaC
can't see and a step no audit can replay. If the IaC doesn't exist yet, WRITING it (playbook/role/
script, committed and merged) IS the task; then hand over its one-line invocation. **Litmus:** if the
recipe contains inline SQL or a `python -c` against a prod service, stop and write the command/script
instead. Verification counts as interaction — "check how many rows are expired" is a management
command, not a paste-block of SQL. Ad-hoc commands are for read-only diagnosis only.

## Tofu/Terraform state is remote-or-nothing (2026-08-01 standard)

**Never run a first `tofu apply` against a local state file in an ephemeral checkout.** Agent
worktrees, scratch dirs, and un-pushed clones get reaped; a `terraform.tfstate` that lived only
there is gone with them, and the real cloud resources it tracked become unmanaged orphans that can
then only be retired by hand (strike: `p-synology-worm` state lost to worktree reaping — M5 teardown
had to be done via console clicks + raw `aws iam` calls, exactly the ad-hoc surgery IaC-first bans).

- **Backend before first apply.** Declaring a remote backend (S3 + lockfile, or the org's standard)
  is part of scaffolding a new tofu root — the same commit that adds the first resource adds the
  `backend` block. `tofu init` against local state is acceptable ONLY for a plan-never-apply dry run.
- **State never lives in git either** — it carries secrets/IDs; the backend, not the repo, is its home.
- **The litmus at hand-over:** before handing Nik any `tofu apply`, run `tofu init -backend=false
  -input=false` mentally against the config — if there is no `backend` block, adding one IS the task.
- **Recovery when state is already lost:** don't recreate — `tofu import` each live resource under a
  fresh backend-backed root, verified by a no-op plan; until imported, mutations to those resources
  are break-glass and must be logged in the owning plan doc.

## Tofu plan/apply split — agent plans, human applies the planfile (2026-08-02 standard, Nik-stated)

**The agent runs `tofu plan -out=<planfile>` itself — iterating until the plan is exactly right —
and the human's entire job is one command: `tofu apply <planfile>`.** Never hand over a block where
the human runs a bare `apply` (or worse, `plan && apply`) and is expected to eyeball the diff at the
prompt: the human is the *authorizer*, not the *reviewer of last resort*.

- **Why the planfile matters:** `apply <planfile>` executes the byte-exact change set the agent
  reviewed — tofu refuses the planfile if the state moved underneath it. This structurally prevents
  the stale-context apply (strike 2026-08-02: a `p-bootstrap` apply run from a checkout on an old
  branch destroyed a live IAM user and 409'd on two others; a planfile reviewed by the agent, with
  the human running only `apply`, makes that class impossible).
- **Plan is agent-runnable.** `tofu plan` is read-only against the cloud; ambient credentials
  (AWS_PROFILE, rendered credential files) get *used* by the provider, never read into context —
  the Agent Secret Ban does not apply. Enabling a normally-disabled key (e.g. `p-bootstrap`) is the
  human's authorization step and comes first; from then on the agent plans, reviews, re-plans.
- **The agent REVIEWS the plan, not just runs it:** assert the expected counts and name them in the
  hand-over ("10 add / 0 change / 0 destroy — the 2 destroys you'd see are X, there are none").
  Any unexpected `destroy` stops the line, never ships in a planfile.
- **Hand-over shape:** agent output = a committed/scripted plan step + the planfile path + the
  reviewed summary; human input = enable-key (if gated) → `tofu apply <planfile>` → disable-key.
  Wrap both sides in the repo's script (`plan.sh` / `deploy.sh`) when the root is used more than once.
- Composes with the two standards above: remote state makes the planfile trustworthy across
  checkouts; IaC-first makes the script the only mutation surface.

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

## Public engine, private config (2026-07-26 standard)

An IaC repo has two kinds of content, and only one of them can ever go public:

| Layer | Contains | Home | Publishable |
|---|---|---|---|
| **Engine** | playbooks, roles, compose files, scripts, tests — *how* things are done | the main repo | yes, by design |
| **Config** | inventories, host addresses, network policy, per-site values — *what* it's done to | a **private overlay repo** | never |
| **Secrets** | credentials | the secret store only | never, in either repo |

The engine reads the overlay by path (`-e policy_dir=…`), so the public half is complete,
runnable, and reviewable, while the private half stays a small diffable set of data files.
The split is what makes "should this repo be public?" answerable at all — otherwise a single
internal hostname anywhere in the tree vetoes publishing the whole thing forever.

**Private is not a licence to commit secrets.** The overlay is *lower-sensitivity*, not
*safe*; the same gitleaks gate and the same store-everything-else rule apply. If a value
would burn on disclosure, it belongs in the store even in the private repo.

Do the split **when you create the config**, not when you decide to publish — retrofitting
means rewriting history. First instance: the DNS policy overlay (mcp#152). Scope of a
*policy* is a separate question from location of its *config*; see
[security.md](security.md) → *Pick the rung from the CONSUMER*.

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

## Definition of done: a service isn't deployed until its backups are PROVEN (2026-07-27 standard)

**"Live" means serving traffic AND a verified backup sitting off-box. A service that answers
200 with no proven backup is not done — it is an outage waiting for its first bad day.**
Calling it done is a false claim, not an optimistic one.

- **Proven = both halves, observed**: (1) a backup actually *landed on the offsite target*
  — list the object, check size and timestamp; "the cron is installed" and "the script
  exited 0" are not evidence — and (2) it *restores*, at minimum a rehearsal into a
  throwaway target proving the dump loads and the archive unpacks. An unrestorable backup
  is a backup-shaped file.
- **Why this is a rule**: through July 2026 three services (IdP, git, customer chat
  instances) were each declared live and handed over while **not one backup had ever
  offloaded** — scripts existed, crons existed, the storage credentials were never seeded.
  Every "done" was sincere and wrong, because the check performed was "did the deploy play
  go green", which cannot see this class of gap.
- **So the check must be systematic**: backup wiring is the step with no user-visible
  symptom until the data is already gone, which is exactly why it loses the race against
  the next feature. Put the assertion INSIDE the deploy gate (smoke test asserts a fresh
  object exists in the remote bucket), never on a follow-up list.
- **Applies to language in hand-overs**: never write "✅ Live" in a board, changelog, or
  client-facing doc for a service whose backup has not been observed landing. Write "live,
  backups unverified" until it has — that distinction is the entire point of the rule.
- **Corollary — restores break silently on drift**: a rename shipped `backup.sh` writing
  one bucket while `restore.sh` read another, and secret-name drift (`DB_*` → `POSTGRES_*`)
  broke both. Only a restore rehearsal catches that class; no green deploy ever will.

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
- **Wrong-venv prompt that survives everything** (fixed hooks, fresh shells, `cd`): suspect
  the VENV ITSELF — a `.venv` created/copied under another project hardcodes that project's
  path in its `activate`, so poetry treats the foreign env as authoritative (`poetry run`
  fails "Current Python version is not allowed"). Diagnose: `grep <other-project>
  <repo>/.venv/bin/activate`. Fix: `rm -rf .venv && env -u VIRTUAL_ENV poetry install`.
- **Non-ASCII after `$VAR` in `.sh`**: old bash folds the leading byte into the name →
  `<var>?: unbound variable` under `set -u`. Worst landmine is `…` right after `$VAR`. Use
  `$PATH...` or `$PATH …` (ASCII gap), not `$PATH…`.
- **SSH + single-quoted heredoc**: the body expands *remotely*. Don't smuggle locals via a
  `'"$VAR"'` break-out — pass locals as argv to `bash -s`, secrets via stdin (`printf '%s\n'
  "$SECRET" | ssh "$HOST" bash -s "$LOCAL" <<'REMOTE' … read -r A … REMOTE`).
- **NEVER pipe secrets into `ssh <host> 'sudo …'`** — without a tty, sudo reads its password
  from the SAME stdin and silently EATS the first secret line (probes.env landed empty while
  every check passed, 2026-07-12). Two phases: (1) pipe secrets over ssh stdin into a
  user-owned 0600 STAGING file; (2) separate `ssh -t host 'sudo …'` merges staging into the
  root-owned target, shreds staging, and **verifies the keys are non-empty** before success.
- **Multi-orphan rotation**: a rotation that crashed mid-flow may have minted a new key before
  dying — an orphan to also revoke (fingerprint: recent key, `last_used_on` = the failed run's
  minute, template-matching description). Delete a list of stale IDs in one pass; treat 404 as
  success so re-runs are safe.

---

## Fix at the serving layer (2026-07-31)

When a capability must reach a SET of clients (all LAN devices, all tailnet devices, phones
included), fix it in the infrastructure layer each access path already trusts — never by
per-device configuration:

- **LAN name resolution** → the DHCP-advertised DNS (router hands every client the internal
  resolver). Already the standing setup.
- **VPN/tailnet name resolution** → Headscale split-DNS (`services/headscale/` config, ships
  like code): every tailnet client — laptops AND phones, which have no `/etc/resolver` —
  resolves the declared internal domains via the internal resolver's TAILNET address (its
  LAN address is unreachable through the tunnel; that asymmetry is the classic failure).
- Per-device overrides (`/etc/resolver/<domain>`) remain the tool for genuine one-machine
  EXCEPTIONS (the "narrowest scope" rule) — the two rules compose: scope the fix to the
  consumer set. One machine → device layer. The fleet → serving layer.

Litmus: if the fix would have to be repeated on the next device, it's at the wrong layer.
Instance that minted this rule: dns.ciminos.org resolved on LAN but died on VPN; the answer
was Headscale split-DNS + DHCP, and the hand-made `/etc/resolver` file became removable
(mcp#182).

## Where this doc lives
Canonical: `operating-canon/governance/technical.md` → `~/.claude/governance/technical.md`. Extends the
[Constitution](README.md). Security-adjacent rules (secrets, supply-chain, access) live in
[security.md](security.md).


## Host access standard — tailnet-only, `ops`-only, password-sudo (2026-08-04, Nik-stated)

Every server we run gets the SAME access shape. `cc-stage` and `cc-prod` are the
reference implementation; anything that differs is drift to repair, not a local
convention.

| Control | Standard | Why |
|---|---|---|
| Reachability | **Tailnet only.** No SSH on a public interface; the public DNS name must not answer on any SSH port | The box is unreachable to the internet, so credential-stuffing and 0-days in sshd have no surface. Verified by `ssh <public-name>` refusing |
| SSH user | **`ops` only.** No `root` login, no per-human accounts | One identity to audit, one to revoke. Root-over-SSH removes the sudo boundary entirely |
| Key | **Secretive (Touch-ID-gated) key**, no on-disk private keys | The key cannot be copied off the Mac or used without the human present |
| sudo | **Password required.** NOPASSWD only for explicitly enumerated automation commands, never `ALL` | The sudo password is the second factor: SSH-key compromise (or a confused agent) is one step short of root. Ansible uses `--ask-become-pass` |
| Config | Managed by playbook (`/etc/sudoers.d/`, `sshd_config`), never hand-edited | Otherwise the policy drifts silently, which is exactly how it drifted |

**The evidence this is not theoretical (2026-08-04):** the Gitea forge box had
`(ALL) NOPASSWD: ALL`. Within minutes of an agent gaining routine SSH access it
ran a privileged command unattended and took `git.perpetuator.io` down for four
minutes. On lestrange the identical action is *impossible* for an agent — it
must hand the step to the human, because it cannot supply the password. **The
sudo password is doing real authorization work; treat its absence as a finding.**

SSH client config follows the same shape everywhere — one alias block per host
carrying the public name, the `<name>.mesh.perpetuator.io` MagicDNS name, and a
short alias, all pointing at the tailnet IP with `User ops`.
