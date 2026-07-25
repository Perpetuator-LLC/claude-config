---
name: nightly-tuleap-reconcile
description: RETIRED 2026-07-25 — Tuleap is being decommissioned (ADR-025 / mcp#138). This skill no longer syncs anything; if invoked it reports the retirement and exits. Kept as a stub so scheduled runs fail loudly-but-harmlessly instead of erroring against frozen write tools.
---

# RETIRED — do not run a reconcile

**Tuleap is frozen for retirement** (ADR-025, migration ticket mcp#138). Its
gateway write tools refuse by default, so the old vault→Tuleap sync passes
cannot and must not run.

If this skill fires (a leftover schedule), do exactly this:

1. Post/print one line: `nightly-tuleap-reconcile is RETIRED (ADR-025) — no sync performed.`
2. Do **not** call any `tuleap_*` write tool.
3. If a schedule still triggers this nightly, delete that scheduled task and say so
   in the run report — a retired job should not keep waking up.

**Where the work went:** journal/State processing now files or refreshes a
**Gitea issue on the owning repo** (dedupe by goal first). Strategy artifacts
live in the vault; requirements/capabilities in the owning repo's `docs/`.
Canon: the Constitution's placement table + mcp `docs/guides/doc-standards.md`.
