---
name: session-summary
description: "Invoke when the user's message contains #SessionSummary (typically a long thread has degraded and they want a clean-context continuation). Session-Export Protocol — produce a complete hand-off doc a FRESH agent can execute without this session: inventory the incomplete work, fence the settled decisions, record what can't be inferred from the repo, and write it as a committed repo hand-off doc with a paste-ready kickoff block. The sibling of #capture, but for work STATE instead of knowledge."
---

# Session-Export Protocol — `#SessionSummary`

When the human tags a message **#SessionSummary** (typically because a long thread has degraded and they want a clean-context continuation), produce a complete hand-off a FRESH agent can execute without this session — the sibling of `#capture`, but for *work state* instead of knowledge:

1. **Inventory the incomplete.** Walk the whole session (and the task list) for every action item not fully done — including human-pending steps — each with enough working context (file paths, commands, order, blockers) to act on immediately. Only incomplete items get detail.
2. **Fence the settled.** List decisions made + one-line rationale as a "do not reopen" table (link the canon docs, don't restate them), and completed work as one-line pointers — so the fresh agent neither re-litigates nor re-does.
3. **Record what a fresh AI cannot infer** from repo/docs: open PRs and their update semantics, branch/worktree topology, which host runs what, live credential state, verified-catalog values, deliberate design exceptions that look like bugs (e.g. an on-box token that must NOT move to the store).
4. **Write it as a repo hand-off doc** (`docs/handoff/HANDOFF-<topic>-continuation.md` or the project's equivalent), commit + integrate + push per the developer flow, and end with a short **paste-ready kickoff block** (`Read and do: <path>` + where to start).
5. **Route side-captures.** Anything durable the summary surfaced (a new concept, a corrected recipe) also goes through `#capture` routing; cross-session pointers → auto-memory.
