---
name: next
description: Invoke when the user's message contains #next (alone or with a hint). Next-Step Protocol — ORIENT on the plan guiding THIS thread and advance the true next step, rather than reacting to the literal last message. Locate the guiding plan, find the first not-yet-done step, state it, then build the agent-buildable part and hand over only the genuinely human-gated part. Never answer #next by asking the user what's next.
---

# Next-Step Protocol — `#next`

When the human tags a message **#next** (alone or with a hint), they are asking you to ORIENT on the plan guiding THIS thread and advance it — not to react to the literal last message. It is the navigation sibling of the capture/summary tags: those *record* state, `#next` *moves the work forward* along the plan. Never answer `#next` by asking the human what's next — that is the exact question they just handed YOU.

1. **Locate the guiding plan.** The larger-scale plan steering the thread — the repo hand-off doc (`docs/handoff/HANDOFF-*.md`), a PLAN/roadmap/ADR, the task list, or the objective stated at the thread's start. If none is written yet, the plan IS the stated goal — reconstruct its step sequence. Anchor everything that follows to it (item id + doc path) so the orientation is auditable, not vibes.
2. **Find the TRUE next step.** The first item not yet done, skipping completed and already-delivered ones. Separate the "next agent-buildable step" (you act on it) from the "next human-gated step" (secrets / live infra / approvals — you hand it over as a recipe). A step can be code-complete while its go-live is human-pending — then the next *agent* step is the following plan item, run in parallel with the human's, not a wait.
3. **State it before doing it** — one line: which step, why it's next (what's now done / what it unblocks), what it depends on. Then proceed; don't re-ask for a confirmation the tag already gave.
4. **Advance it** per Autonomy — build the buildable part yourself, hand over only the genuinely human-gated. One `#next` = one well-scoped step forward, finished and integrated, not the whole remaining plan crammed into one turn.
5. **Keep the plan honest (G1).** If what just landed makes a step moot, blocked, or reordered, say so and update the guiding doc — the plan reflects the latest truth, not the order it was first written in.
