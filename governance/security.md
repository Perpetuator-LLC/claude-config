---
type: governance
domain: security
role: CISO
status: draft
owner: Nik
created: 2026-06-26
extends: governance/README.md
tags: [security, secrets, supply-chain, access, least-privilege]
---

# Security Governance (CISO)

The non-negotiable security posture. Unlike most domains, **Security holds its line even on client
work** — a client's convenience preference never overrides these (precedence in the Core: my safety
and security always apply). Flag, don't bypass.

> **Where does this secret go?** → [`secrets-registry.md`](secrets-registry.md) — the canonical
> secrets topology + path registry (stores, path conventions, per-service paths, the
> route-before-create / register-on-create / retire-on-retire rule, and the 404-diagnosis recipe).
> Consult it BEFORE seeding, moving, or hunting any secret path (added 2026-07-25).

---

## Supply chain — minimize what runs on the machine
**Default to building minimal in-house over installing third-party tools or pulling new
dependencies.** Even a well-intentioned repo can compromise you through a hacked transitive
dependency. *(Lived experience: the cc-fe ESLint supply-chain "dropper" incident — see
`Engagements/Internal/Products/Perpetuator/Security/Incidents/`.)*

- When a capability is needed, prefer a minimal version inside an **already-running, already-trusted**
  surface (e.g. the Perpetuator MCP / a Python skill), using **stdlib + deps already in use**.
- **Stdlib-first; reuse trusted deps; pin versions.** Prefer **local SQLite** over a cloud service
  for sensitive data; reach for external services only for genuinely multi-service/shared cases,
  self-hosted, and never send sensitive content (Security/Financial/Legal/NDAs) to a cloud LLM/DB.
- When suggesting any tool, **lead with the dependency/supply-chain cost** and offer a
  build-it-ourselves alternative. Don't propose `npm install` / `pip install` / running a
  third-party CLI without flagging the risk.
- **Leak detection, two layers:** pre-commit **gitleaks** + CI **gitleaks**, pinned to the same
  version so verdicts match. No config → create with `useDefault = true`.

---

## Agent secret ban (absolute)
**Never read, extract, display, or access any secret / token / password / key / credential** —
`.env`, Keychain, Docker env, config files, OpenBao/Vault responses, `/proc/*/environ`, `ps eww`,
shell history. **Why:** anything in agent context goes to the API and persists in transcripts/caches —
read once, leaks every later turn, unrecoverable.

**Instead — delegate:** write a self-contained `read -rs` script the human runs; they report the
outcome; you continue without ever seeing the secret. If a secret enters a transcript anyway, warn
and recommend rotation. Tools that touch customer data return **aggregate data + opaque IDs only** —
never name/email/phone/PII into an LLM context window.

**Gitignored env-config files are in scope** (2026-07-14 — read `environment.ts` wholesale chasing a
type error; it carried plaintext dev passwords into context). A repo's local runtime-config file
(`environment.ts`, `*.local.*`, anything gitignored because it may hold credentials) is a "config
file" under this ban even when it doesn't look like `.env`. Never `cat`/Read one whole — answer the
question with a targeted probe that cannot emit values (`grep -c '^  POSTHOG_KEY:' file`,
`grep -o 'FIELD_NAME' file`); to ADD fields, use a blind in-place edit (`sed`/`perl -pi`) keyed on
structure, not by reading first. Copying such a file (`cp` between checkouts) is fine — displaying it
is not.

---

## Secrets in code (mandatory)
Never hardcode a credential in **any** repo file (incl. throwaway/test). Source from, in order:
1. **Process env** — bail with an error that says *where to fetch it* (OpenBao/Vault path).
2. **Secret store at runtime** — services fetch on startup; never persist to disk.
3. **Interactive prompt** — one-shot admin scripts use `read -rs`; **never** secrets on argv
   (`-e VAR=`, positional → leak to `ps`/history); pipe via stdin; `trap 'unset VAR' EXIT`.

**Standard secrets pattern (Keycloak-only on disk):** on-disk `.env` holds only the bootstrap
Keycloak client secret; at every startup the service does client-credentials → Keycloak JWT →
OpenBao login → fetch runtime secrets → export → exec. No long-lived secrets on disk beyond one
bootstrap secret; bouncing re-fetches fresh (rotation without rebuild). Never commit `.env`; always
`--exclude .env` in rsync.

**Standard patterns** (never a secret on argv):
```bash
set -euo pipefail
: "${FOO_API_TOKEN:?Set FOO_API_TOKEN (fetch from <where>: <how>)}"
```
```bash
# one-shot admin: prompt (never argv); stream over ssh stdin → remote env → container via
# `-e NAME` (name only = env passthrough — the VALUE never lands on any argv / ps / audit line;
# `-e VAR="$T"` would put it back on the docker exec command line, so never do that)
read -rs "TOKEN?Paste TOKEN: " 2>/dev/null || read -rsp "Paste TOKEN: " TOKEN; echo
trap 'unset TOKEN 2>/dev/null || true' EXIT
printf '%s\n' "$TOKEN" | ssh "$HOST" 'read T; export T; docker exec -e T container cmd'
```
Multi-step credential ceremonies (generate-root, token mints) never have the human copy-paste an
intermediate: capture every nonce/OTP/encoded/decoded value into shell variables via command
substitution (`-format=json` + `jq -r`); the only typed secret is a hidden prompt (reference: mcp
`docs/ops-runbooks/openbao-operator-auth.md` break-glass ceremony).

---

## Ask-once provisioning (2026-07-12 standard)
A provisioning/setup script that collects credentials interactively must be **re-runnable without
re-collecting them** — reruns are the NORM (scripts fail mid-flow, deploys iterate). Pattern:
**store-first, prompt-fallback, write-back** — (1) try the secret store first
(`secret/<engagement>/<purpose>`); (2) prompt ONLY for values the store doesn't have; (3) after the
script's own end-to-end verification passes, write collected values back so the next run is
zero-prompt. The store is the memory; the prompt is the one-time capture.

**This binds the AGENT, not just scripts: asking the human for an API token is the LAST resort, and
doing it twice for the same service is a violation.** Before any token prompt:
1. **Check the store** — the agent runs under the human's active login and consumes tokens IN-PROCESS
   via command substitution (`TOKEN="$(bao kv get -field=… …)" cmd`; value never printed, never in
   context, never on argv). The Secret Ban forbids MY *context* seeing values — it does **not** forbid
   command substitution in the human's shell or a script. Handing the human "fetch X from the store's
   UI and paste it" when a logged-in CLI can consume it in-process violates THIS rule (caught 2026-07-15:
   sent Nik to the Infisical UI for `DO_PAT` while `infisical secrets get --plain` was available).
1a. **Store-agnostic:** "the store" is whichever secret manager the ENGAGEMENT uses — the pattern
   transfers. OpenBao is Perpetuator-internal; WeOwn uses Infisical, where the in-process form is
   `VAR="$(infisical secrets get KEY --projectId=<id> --env=<env> --plain)" cmd` under the human's
   `infisical login` session.
1b. **Empty fields ≠ absent secret** (2026-07-15): a blank latest version usually means a FAILED
   WRITE, not a missing credential — before prompting, list the subtree AND walk version history for
   the newest non-empty version, and consume that in-process. Concrete OpenBao commands (raw-path
   forms so they work under scoped tokens too): list keys `bao list secret/metadata/<p>`, version map
   `bao read secret/metadata/<p>`, read a version `bao read "secret/data/<p>?version=N"` (the `bao kv`
   conveniences preflight a UI mount path scoped tokens are denied).
2. **Verify scope** with a harmless read before using — a stored-but-stale token falls through to (3).
3. **ONE Secure-Handoff mint** that stores into the store in the same block (`read -s` →
   `bao kv put/patch`) and is then consumed from the store, so that service never prompts again. New
   tokens always land in the store at mint time — a token that only lives in a shell/history/CI var is
   a bug.

---

## Credential-at-rest gating (the meta-credential)
The token / unseal key / passphrase that *grants* access must never sit usable in plaintext at rest.
Keep each in one of four states:
1. **Off-box** — root unlockers (LUKS passphrase, unseal keys, backup private key) in a personal,
   infra-independent vault (Apple Passwords / hardware / offline), **never in the store they
   recover** (don't keep the safe's combo in the safe).
2. **Passphrase/biometric-gated** — daily tokens in the OS keychain (Touch ID), never plaintext
   `~/.vault-token` or a shell rc.
3. **Encrypted volume** — server secrets that must touch disk only on a LUKS mount.
4. **Ephemeral** — provisioning/CI tokens env-injected at point of use, short-TTL, revoked after.

**Least standing privilege:** daily-drive a *scoped* token, elevate to admin on a short TTL
deliberately, then drop it. The role in your shell prompt (Technical → host naming) reflects this.
**Litmus:** if it's needed to bring the store or a host back from cold, it can't live *in* the store.

---

## Found a hardcoded secret — rotation order matters
1. Verify it's **live** (dead = no rotation). 2. Find every runtime consumer. 3. **Mint the
replacement BEFORE revoking** (keeps a fallback). 4. Update consumers (push to store, bounce,
verify health). 5. **Verify end-to-end.** 6. **Then revoke** the old. 7. Scrub the repo to the
env-var pattern in one auditable commit. 8. Document where/when/new posture. Can't do 4–6 without an
admin token? **Stop and surface it** — never harvest an admin token from a remote `.env`.

---

## What NEVER leaves the machine
Encryption keys, keychain passwords, `.env` contents, OpenBao tokens → **never** in tool output to an
LLM. Message/document *content* may by design; PII and secrets never.

---

## Service-Credential Posture (2026-07 standard — the mcp-gateway/Gitea lesson)

Adopted 2026-07-09 after the MCP gateway's Gitea token silently rotted through the Gitea
migration (every `gitea_*` tool 404'd for days). Binding rules for every service-to-service
credential:

1. **Rotatable in OpenBao, live after at most a service RESTART — never a rebuild.** Every
   service loads its credentials from OpenBao at startup (or watches them); rotation =
   write new secret → bounce the consumer. If applying a rotation requires an image rebuild
   or redeploy, the integration is wrong — fix the loading, not the process.
2. **Scoped to the service, not a human.** Dedicated service account per consumer
   (e.g. gitea `mcp-platform`), granted least-privilege via a purpose-named group/team
   (e.g. org team `mcp-gateway`: read code + write issues/PRs, explicitly-attached repos
   only — never org-wide, never all-repos, never a human's account as the identity).
3. **Bind to network origin where the platform supports it** (CIDR allowlist, tailnet IP,
   mTLS). Where it doesn't (Gitea access tokens have no IP scoping), note the limitation in
   the rotation script header and compensate: tighter scopes, shorter rotation cadence,
   on-box minting.
4. **Rotation scripts verify BEFORE storing, through the consumer's own network path**
   (e.g. curl from inside the consumer's container), and store NOTHING on failure —
   a fail-closed check that names the root cause beats a stored-but-broken credential.
5. **Ephemeral admin tokens for one-shot surgery**: mint on the target box, use, revoke in
   the same flow (trap EXIT); a failed revocation is an orphan — prune it immediately
   (multi-orphan rule) and confirm by listing.
6. **Rotation scripts are infrastructure**: they live in the owning repo, get fixed (not
   worked around) when topology drifts, and their headers document symptom → root cause →
   knobs so the next failure is diagnosable from the error text alone.

---

## Runtime Secret Injection (2026-07 standard — the cc-be openbao_exec model)

Adopted from cc-be prod (reference: cc-be `scripts/openbao/openbao_exec.py` +
`notes/security/RUNTIME_SECRET_INJECTION.md`). The default for EVERY process that needs
secrets — apps, workers, **and periodic jobs like backups**:

1. **Secrets exist only in the process tree's memory.** An injector (AppRole login → read
   one KV path → inject as env → `exec` the child) replaces rendered `.env` files entirely.
   The only secret at rest on a box is the AppRole role_id/secret_id bootstrap pair (0600,
   LUKS volume). Fail-closed: sealed/unreachable vault ⇒ the child never starts.
2. **Rotation = `bao kv put`.** If rotating any credential requires placing a file on a box,
   the integration is wrong (same rule as service-credential posture #1). This includes
   "config-ish" material like backup public keys — put them IN the KV path too.
3. **`docker exec` inherits the container's static env** (compose `environment:`), NOT the
   injected child's. So one-off commands inside an injected container must run through the
   injector themselves: `docker exec <c> python3 openbao_exec.py -- <cmd>`. Corollary that
   bit twice (pre-migrate dump, SSV dump): there is NO `postgres` superuser on these
   clusters — the entrypoint created the vault's `DB_USER`; any tool assuming `-U postgres`
   fails "role postgres does not exist".
4. **Handing a human a secrets step**: capture every intermediate into shell VARIABLES via
   command substitution (`-format=json` + `jq`) — nothing pasted, nothing on argv, nothing
   in history; the only typed secret is a hidden `read -s` prompt. And match THEIR shell:
   `read -rsp` is bash-only; zsh needs `read -s 'VAR?prompt'` (empty-var writes from the
   mismatch caused two silent blank-secret writes to OpenBao).

## Vault access tiers (2026-07 standard — root is not a login)

Three tiers, each with its own ceremony (canonical how-to: mcp
`docs/ops-runbooks/openbao-operator-auth.md`):

| Tier | Login | TTL | For |
|---|---|---|---|
| `operator` (daily) | OIDC SSO+TOTP | 18h | KV reads/writes in granted paths |
| `admin` (elevation) | OIDC SSO+TOTP, deliberate | 1h | policy/auth/mount changes (new KV grants) |
| root (break-glass) | `generate-root` ceremony w/ OFFLINE unseal key | minutes, then `token revoke -self` | seal ops, rekey, bootstrapping `admin` itself |

**The daily TTL is a forcing function, not a convenience** (decision 2026-07-18, apply =
mcp#116): 18h = one morning `bao login` covers the whole workday, yet the token is dead by
the next morning — expiry IS the daily re-auth ritual. max_ttl equals creation TTL so
renewal can't stretch past the day. Was 8h/12h (mid-day re-auth churn) until mcp#116 lands;
never raise past 24h — that would create a standing credential.

Rules learned live: **`bao policy write` REPLACES the whole policy** — read first, include
every existing path. **If a provisioning script owns a policy, codify new grants in the
script** (its extra-paths arg), or the next re-provision silently drops them. A revoked
root token is dead forever — ceremony remnants in history decode to a corpse.

## Sealed backups (SOP-INFRA-017 posture, proven live 2026-07-09)

The box can neither READ (append-only WORM pusher, no GetObject) nor DECRYPT (public key
only; private key offline) its own backups; COMPLIANCE object-lock means ransomware can't
delete history. Plaintext artifacts (dumps, tars) are ephemeral: created, sealed, uploaded,
shredded in one run — and anything a container writes for later shredding must be created
`--user`-matched to the shredding user, or root-owned files break cleanup. Dumps that
persist between runs (pre-deploy restore points) are capped-count AND compressed; pipe
compression runs under `bash -o pipefail` so a mid-dump failure can't hide behind gzip's
exit 0. Backup MONITORING must not share fate with the backup maker (a dead celery-beat
silences a celery dead-man): in-app alerting is a layer, the real check is external.

## Network control is not an agent capability (2026-07-26 standard)

**No promptable interface — MCP tool, voice, chat, scheduled agent — may MUTATE network
control.** DNS records/blocklists/allowlists, firewall rules, routing, VPN/tailnet ACLs:
read yes, write never. Enforced, not merely documented: the DNS write tools were deleted
from the gateway and `Permission.DNS_WRITE` removed, with tests that fail if either
returns (mcp `services/mcp/tests/test_dns_no_write_tools.py`).

**Why this class is special.** DNS is the resolution layer *beneath* every other control.
Anything that can rewrite it silently redirects traffic for every device on the network —
credential capture, MITM, exfiltration — and the change reads as ordinary config, not as
an attack. Two properties make an AI interface the wrong place for it:
- **Promptable**: the model acts on content it merely READS (a web page, an email, a log
  line). A capability that reconfigures the network must not sit behind an input channel
  that untrusted text can reach.
- **Voice is worse**: weak authentication, no review step, no diff, ambient trigger.

**Calibration of the originating case (be accurate about it).** The tools actually removed
(`dns_block_domain` / `dns_allow_domain`) reached only the resolver's block/allow LISTS — no
zone or record editing — so the reachable harm was **denial and filter-bypass**, not
redirection. The class rationale above (redirection/MITM) still governs the rule, because
the class includes record control; do not read the incident as a live MITM hole. Two things
made the list-only surface serious anyway: **blinding** (blocking the alert relay or chat
homeserver silences alerting while everything looks normal) and **bypass** (an allowlist
entry overrides subscribed blocklists). No template granted the scope, so standing exposure
was to `*`-scoped sessions — narrow, but real.

**The tell to remember:** the permission's own comment read *"gate carefully"*. Someone saw
the risk and shipped it behind a scope. **"Gate carefully" is not a control** — that is
precisely why this is a hard tier rather than a scope: it removes the judgment call from the
moment of temptation. Capability without observability (no confirmation, no change alert, no
reviewable diff) is where the line falls.

**Authorization floor for network control: a human, on a dev machine, inside the tailnet,
over SSH.** That tier is the gate, and it is deliberately higher than "an agent holding a
scope". The split is the principle: **agents may SEE the network, they may not STEER it** —
observability (query logs, stats, metrics) carries no blast radius and stays freely
available.

**Generalization — rate a control surface by blast radius, not convenience.** The
automation-authority principle (move the operation to where the authority lives) says how
to automate safely; this is its ceiling: some capabilities should not be agent-reachable
at any scope. Before exposing a mutating tool, ask *what does a confused or injected agent
do with this at 3am?* If the answer is "silently reroute/deny/expose traffic for everyone",
it belongs behind SSH, not behind a scope. **Reaching that bar is the prerequisite before
building any deeper network-control-plus-AI integration** — earn the tier first.

**Corollary — network policy belongs in IaC.** Allow/block lists that live only in an
appliance are drift the repo cannot see; that invisibility is how a household ad-blocker
came to block the business's own ad-platform API without anyone knowing (mcp#152).

## DNS conflicts: fix at the narrowest scope that works (2026-07-26)

When a shared DNS policy blocks something one machine legitimately needs, **do not widen
the shared policy** — override at the narrowest scope, in this order:

1. **Per-machine, per-domain resolver override.** macOS: `/etc/resolver/<domain>` containing
   `nameserver 1.1.1.1` routes only that domain's lookups off the shared resolver, only on
   that machine. Zero effect on everyone else, and the machine keeps filtering for
   everything else. *Gotcha that will fool you:* `dig`/`nslookup` query resolvers directly
   and IGNORE `/etc/resolver` — they still show the old answer. Verify with `curl` or a
   browser, which use the system resolver. (Linux equivalent: systemd-resolved per-link
   domain routing, or a dnsmasq `server=/domain/ip` line.)
2. **Per-client-group policy on the resolver** (e.g. Technitium's Advanced Blocking app):
   infrastructure and work devices exempt, family devices keep the blocklist.
3. **Global allowlist entry — last resort**, and only with the cost stated out loud: it
   reduces filtering for *every* device on the network.

The reasoning generalizes past DNS: when a shared control blocks one legitimate use, the
fix is scoped exemption, never a blanket loosening — a global change to satisfy one machine
silently degrades the protection for everything else.

## Where this doc lives
Canonical: `claude-config/governance/security.md` → `~/.claude/governance/security.md`. Extends the
[Constitution](README.md). Infra/host conventions in [technical.md](technical.md).
