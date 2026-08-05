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
2. **Dedupe BEFORE drafting (mandatory — tickets are expensive once they
   exist).** `gitea_list_issues` the target repo (state `open`; check `closed`
   too when the topic smells recently-worked) and scan titles/labels for the
   same or an overlapping ask. Judge by *goal*, not wording — "ship logs to
   Loki" and "promtail on the app boxes" are one ticket. Then:
   - **Exact/near match** → do NOT create. Comment the new context/requirement
     onto the existing ticket (re-label/re-title it if the scope grew).
   - **Subset of a broader ticket** → add it there as a comment/checklist item.
   - **Genuinely new** → create, and name in the body which adjacent tickets
     you checked and why this isn't them (one line).
   The same rule governs backlog sweeps: N candidate items ≠ N new tickets —
   route each against the existing queue first (G11 route-before-create
   applies to tickets exactly as to documents).
3. **Draft the issue.**
   - Title: imperative, concise. Do NOT encode priority in the title — it
     goes in the label (below).
   - **Priority label is MANDATORY on every ticket (2026-07-25):** decide
     P0–P3 from the request (default **P2** when genuinely unstated — never
     skip). The create API rejects label NAMES (integer-id only, a known 422),
     so ALWAYS apply it with `gitea_set_issue_labels` (accepts names,
     `create_missing: true`) immediately after `gitea_create_issue` — one
     labeled ticket = create + set_labels, every time. A 422 on labeling is a
     bug to fix, not a reason to ship an unlabeled ticket.
   - **Type label is MANDATORY on every ticket (2026-07-29, Nik — org-wide,
     all repos):** exactly one of `bug` (something built behaves wrong),
     `enhancement` (new capability, gap, decision, spike, epic), or
     `performance` (works, too slow/heavy). Applied in the same
     `gitea_set_issue_labels` call as the priority. House colors (set via
     `gitea_edit_label` if a `create_missing` created the label fresh):
     `bug` `#5319e7` (purple) · `enhancement` `#1d76db` (blue) ·
     `performance` `#0052cc` (dark blue).
   - Body: context (why now), the ask, acceptance criteria as checkboxes,
     links to related tickets/docs. **Rule 16: written as if public** — no
     internal IPs, on-box paths, secret-store paths/versions; reference form
     instead ("the observability host", "the deploy token's bao path").
   - Spike/investigation tickets: frame the question, list the options to
     evaluate, and define what "answered" looks like.
4. **File it** with the gateway tool `gitea_create_issue` (load via ToolSearch
   if deferred). If the gateway connector is unavailable, do NOT fall back to
   raw API calls with tokens — save the drafted title/body in the reply, say
   filing is blocked on the connector, and offer to file on reconnect.
5. **Report**: issue number + URL, one-line summary of what was filed.
