---
type: governance
domain: security
role: CISO
title: Secrets Topology & Path Registry
status: draft
owner: Nik
created: 2026-07-25
created_note: "Drafted by cc-fe worker agent per Nik's #capture (2026-07-25): the 'where do secrets go' question keeps recurring; this is the single answer. Draft until published (G4)."
extends: governance/security.md
---

# Secrets Topology & Path Registry

The **single canonical answer to "where does this secret go?"** — loaded via governance (this repo
symlinks into `~/.claude/governance/`), so every session on every repo can route a secret without
archaeology. Contains **conventions and path SHAPES only — never values, never tokens**. The
Perpetuator vault (notes) deliberately excludes Security paths from its agent-searchable index, so
this registry lives HERE, not there.

## Topology (who talks to which store)

| Store | Address | Serves | Unlock |
|---|---|---|---|
| **Central OpenBao** | the central vault host (`vault.` on the company domain) | ALL stage + prod service config/secrets; CI AppRoles | operator OIDC (humans), AppRole (services/CI) |
| **Local dev OpenBao** | per-machine Docker vault | dev-only secrets for that machine | YubiKey-gated unseal |
| **Gitea repo secrets** | per-repo Actions settings | CI-only injectables (registry PATs, AppRole id pairs, API keys the workflow itself needs) | repo admin |
| **Box-side files** | on each deploy box | AppRole role-id/secret-id pair files the compose reads | box access (tailnet + SSH) |

Runtime injection everywhere — **no `.env` files at rest on any box**; containers render env from
the store at start via each repo's `generate-env-from-vault-runtime.sh` (or equivalent).

## Path convention (central OpenBao, kv2 mount `secret/`)

```
secret/services/<service>/<env>        # service runtime config+secrets; env ∈ {staging, prod}
secret/services/<vendor-or-tool>       # cross-env vendor keys (e.g. an AI API key)
```

- CLI reads/writes use `secret/services/...`; the HTTP API (and compose `VAULT_PATH`) needs the
  `secret/data/services/...` form — a recurring confusion, both are the SAME secret.
- **Env segment is exactly `staging` or `prod`** — never `stage`, `production`, `dev`. A 404 on a
  path that "should exist" is usually this naming drift or a policy that 404s on deny — diagnose
  with `bao token capabilities <data-path>` + `bao kv list` on the parent, never by guessing writes.

## The rule (extends G11 + the Resource Registry)

1. **Route-before-create:** before seeding any new secret path, `bao kv list` the parent and check
   this registry — update an existing path rather than minting a near-duplicate.
2. **Register-on-create:** any NEW path (new service, new env) gets a row in the registry table
   below in the same session, plus a Resource Registry row if it accompanies a provisioned resource.
3. **Repo-side pointer:** every deployable repo's `docs/deployment.md` (or CLAUDE.md) names its
   exact paths and its seeding script. The registry is the index; the repo doc is the procedure.
4. **Retire-on-retire:** when a service is decommissioned, its `secret/services/<service>/` subtree
   is deleted in the same change that retires the service, and the row here is struck through with
   a date. (2026-07-25: listing showed subtrees for at least one retired service still present —
   cleanup ticketed on the platform repo.)

## Known service paths (shape only; verify with `bao kv list` before relying)

| Service | Paths | Seeded by | Notes |
|---|---|---|---|
| cc-fe | `secret/services/cc-fe/staging` ✅ · `secret/services/cc-fe/prod` ⚠️ | repo `scripts/seed-vault-staging.sh` (adapt per docs/deployment.md for prod) | **2026-07-25: prod path found MISSING on the central store while prod runs** — box-side compose drift or sibling-name seed suspected; must exist before any prod FE deploy (container renders env from it at start) |
| cc-be | `secret/services/…` per repo docs | repo-side | |
| mcp/platform services | `secret/services/<service>/…` (gitea, homepage, matrix-signal, mautrix-telegram, mcp, suitecrm, …) | platform repo | retired-service subtrees pending cleanup (see platform repo ticket) |
| vendor keys | `secret/services/<vendor>` (e.g. the AI-API key the release changelog uses) | one-off | referenced from workflows as repo secrets where CI needs them |

## Diagnosis recipe (the one from 2026-07-25)

```
bao token capabilities secret/data/services/<svc>/<env>   # deny → policy gap, not a missing secret
bao kv metadata get secret/services/<svc>/<env>           # 404 with caps present → truly missing
bao kv list secret/services/<svc>/                        # shows sibling names → catches naming drift
```
