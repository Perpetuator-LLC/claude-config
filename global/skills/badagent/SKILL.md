---
name: badagent
description: "Invoke when the user's message contains #badagent (alone or with a hint). Self-Correction Protocol — diagnose what the agent did wrong THIS session and durably fix the rule that failed to bind (edit + commit the config/governance/memory). Never ask the user what went wrong; that is the agent's job to diagnose."
---

# Self-Correction Protocol — `#badagent`

When the human tags a message **#badagent** (alone or with a hint), do NOT ask what went wrong — diagnose and fix your own rules:

1. **Diagnose.** Re-read the recent turns and identify what the agent did wrong or suboptimally. Look for: a rule violated (the global `CLAUDE.md`, a project `CLAUDE.md`, governance, an SOP), or a gap where no rule exists yet. A hint after the tag narrows the search; no hint = full sweep of the current session.
2. **Root-cause the rule, not just the act.** (a) Rule existed and was violated → why didn't it bind (buried in another context, ambiguous wording, example contradicted it, copied stale text verbatim)? (b) No rule → what durable rule would have prevented it?
3. **Fix durably, in the right layer** (edit + commit, don't just acknowledge):
   - Universal behavior → the **source** `~/projects/operating-canon/global/CLAUDE.md` (never `~/.claude/` directly — it's a symlink), committed with a `docs():` message stating violation → rule.
   - Project-specific → that repo's/vault's `CLAUDE.md`.
   - Fact or preference → auto-memory.
   Prefer **amending the rule that failed to bind** over adding a new one — rules-bloat is itself a failure mode. Fix every violation found, not just the first.
4. **Report back**, briefly: the violation(s), the root cause, the exact edit + where + commit hash. If genuinely unable to identify the violation, say so and ask for one hint — never guess-edit the config.

**Config ships like code (2026-07-14):** the edit to `operating-canon` goes on the standard integration branch (`merge/<agent>`) and reaches `main` only through a human-reviewed PR — never a direct commit/push to `main`. Because the active config is symlinked, the edit is live on THIS machine immediately (pre-review); the PR gates the *published canon*. G4: until it merges, the rule change is a draft — if review rejects it, revert the local edit too.
