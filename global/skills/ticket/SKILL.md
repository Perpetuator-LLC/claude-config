---
name: ticket
description: File a Gitea ticket in the current (or inferred) repo. Invoke on /ticket <description>; infers the repo from cwd/context, writes a rule-16-clean issue via the gateway, and reports the issue URL.
---

# /ticket — file a Gitea issue for the repo in context

1. **Infer the repo.** Default owner `perpetuator`. Repo = the git repo of the
   cwd (`git rev-parse --show-toplevel` basename, worktrees map to their repo),
   unless the request clearly concerns another repo (cc-be, cc-fe, ai,
   inference, rp-be, rp-fe) — then use that. Say which repo you chose and why
   in one line.
2. **Draft the issue.**
   - Title: imperative, concise; prefix `[P0..P3]` only if priority is clear
     from the request (labels may not exist yet).
   - Body: context (why now), the ask, acceptance criteria as checkboxes,
     links to related tickets/docs. **Rule 16: written as if public** — no
     internal IPs, on-box paths, secret-store paths/versions; reference form
     instead ("the observability host", "the deploy token's bao path").
   - Spike/investigation tickets: frame the question, list the options to
     evaluate, and define what "answered" looks like.
3. **File it** with the gateway tool `gitea_create_issue` (load via ToolSearch
   if deferred). If the gateway connector is unavailable, do NOT fall back to
   raw API calls with tokens — save the drafted title/body in the reply, say
   filing is blocked on the connector, and offer to file on reconnect.
4. **Report**: issue number + URL, one-line summary of what was filed.
