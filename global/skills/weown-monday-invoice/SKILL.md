---
name: weown-monday-invoice
description: Every Monday: WeOwn Open-of-Week — last week's invoice + commitments review (Jason/Tyler asks, Nik's commitments, delegated-and-outstanding, untracked) + proposed SOWs per contributor + DRAFT SOW-request messages + global-progress update.
---

You are running the **WeOwn Monday Open-of-Week** session. It does THREE things: (1) closes last week with the fractional-CTO invoice, (2) reviews last week's commitments and surfaces untracked items, (3) opens next week with proposed SOWs and DRAFT SOW-request messages. Tyler / Jason mandated this cadence — D406 (collect + approve + document weekly SOWs for the audit trail), D407 (document the process this week for #WeOwnSeason004), A216 + A219 (weekly SOW + Anything invoice from each contributor, Monday cadence). Owner: Nik (CTO). The vault is the **WeOwn** Obsidian vault at `/Users/nik/projects/notes-weown` (the graduated WeOwn engagement vault — the whole vault IS WeOwn, so paths below are vault-root-relative — no `Engagements/WeOwn/` prefix, unlike the old frozen tree) — **read its `CLAUDE.md` first** for the Mandatory Processing Workflow, the State Doc taxonomy, the recency rule, the Tuleap sync rules, and the reply/draft conventions. Work only on the WeOwn engagement.

### Roster (contributors under the CTO, weekly SOW required)
**Mohammed, Shahid, Peter, Roman, Dilonne** (Dilonne W23 onwards — onboarding focus). Dhruv is terminated; his state doc lives at `State/Terminated/Dhruv.md` and he is **excluded** from the roster. If a roster member doesn't have a state doc yet (likely Dilonne the first time), create one using `State/Peter.md` as the structural template, populated from journal evidence.

### Date math (run this first)
- "Last week" = the most recently completed Mon–Sun ISO week ending the Sunday before today. If today is Mon 2026-06-01 → last week = W22 (2026-05-25 → 2026-05-31).
- "Next week" = the current/upcoming Mon–Sun ISO week starting today (or the upcoming Monday if the task fires on a non-Monday catchup). Mon 2026-06-01 → next week = W23 (2026-06-01 → 2026-06-07).
- Use `python3 -c "from datetime import date, timedelta; ..."` in bash if you need exact ISO-week math. Report both windows at the top of every output file.

### Authority and prioritization
- **D20 (3/31, Jason agreed):** the CTO is task-routing authority. Jason gives direction, not direct contributor assignments — Nik routes. The "Jason's Asks" list (Step 8a) is built **so Nik can route them**, not so they bypass him.
- Tyler is also a co-founder + CEO/CFO. Her direct asks weigh equal to Jason's.
- **Recency-weight asks from the last 7 days**, then carry-forward the older Top-Priorities only where they remain accurate. Apply the recency rule from CLAUDE.md when updating any current-status field: never let an older fact overwrite a newer one.
- Active umbrella: **#ZeroTo100 / #SpeedToMarket June launch (D373)** + the **D408 build sprint** (Pop DB → Supabase + RLS in DOKS — the substrate Jason confirmed 5/31 04:09). Both are compatible: build sprint *fulfills* 0-to-100 sales.

---

## STEP 1 — Data-capture verification (last week)
- **Signal journals** live at `Journal/<ISOweek>/` (e.g. `2026W22`). Confirm an entry exists for each day Mon–Sun. Signal is normally ingested nightly (21:30 via `nightly-signal-digest`). If a day is missing, note it; do not block the run.
- **Zoom:** call the Zoom MCP `search_meetings` for last week's UTC window. Only count WeOwn meetings (WeOwn attendees/topics, or already journaled under WeOwn). **Exclude** generic recruiting/1:1 meetings with non-WeOwn external people (e.g. candidate interviews) — list them separately for Nik to route, do NOT bill them.
- **Phone calls:** use what's journaled as `Call - <name> - <date>.md`. Flag that off-Signal/off-Zoom calls may need manual addition.

## STEP 2 — Estimate billable engagement minutes
Methodology must match the existing CSV at `Financial/WeOwn-time-estimate-*.csv`:
- Journals embed per-message timestamps in UTC; the CSV `Start (MT)/End (MT)` columns are Mountain Time = UTC−6. Convert and assign each burst to its MT date.
- Bill ACTIVE engagement, not the full thread span: cluster messages into bursts and estimate active reading+replying time. Quick pings = 5 min minimum. Big multi-party team threads (WeOwn.Dev, C-Suite) where Nik participates = 25–35 min; passive weekend monitoring = 5–10 min. Calls/meetings = their actual duration.
- To get burst structure fast, grep each journal for lines like `**Name** · HH:MM` (sender + UTC time) and the frontmatter `signal_date_range`.
- **Late-night sessions that cross midnight** (e.g. a build session running to ~01:00) are billed to the week they **began** unless Nik says otherwise — do not bleed a Sunday-night session into next week. If a session spans past midnight, note the span but attribute the minutes to the start day.

## STEP 3 — Update the time-estimate CSV
File: `Financial/WeOwn-time-estimate-<start>_to_<end>.csv`. If a CSV for this week doesn't exist, create one (same 7 columns: `Date, Start (MT), End (MT), Est. Minutes, Category, Who / Channel, Notes`). Otherwise append the new rows and re-sort all data rows by (date, start-time, blank start sorts first so calls lead the day).

## STEP 4 — Compute the invoice
Total minutes ÷ 60 × $200/hr = actual-estimate total. Report per-day minutes and the weekly total. Apply Nik's **10 h/wk self-cap**: bill $2,000 net, comp the overage, and mark ⚠️ CONFIRM (Nik flips to FINAL). If Nik confirms in-session, mark the invoice FINAL.

## STEP 5 — Update `WeOwn Billing.numbers` (CREATE + POPULATE the week's sheet — do NOT just leave a note)
One sheet per week named like `S1-W<n>-<MonStart>-<SunEnd>-2026`. **BACK UP the .numbers file first** (`cp` it aside, dated). Use the `numbers-parser` Python lib (`pip install numbers-parser --break-system-packages`).
- **These sheets are all static values (no live formulas), so author the week's sheet in full.** If the week's sheet doesn't exist, **create it** — `Document.add_sheet("S1-W<n>-...", "Table 1", num_rows=~40, num_cols=9)` — and populate it to match the most recent week's layout (read that sheet first to copy the exact structure): row0 `Price | 200`; a **curated block** (header `Date | Time Start | Time End | Time Total | Cost | Task | …`) = the meetings/calls + authoring/project sessions with hours + `$` cost, then a `Total (curated)` row (hours, $); a blank; a **Signal-detail block** (header `Date | Start (MT) | End (MT) | Est. Minutes | Category | Who / Channel | Notes`) = the messaging rows, then a `Total (Signal)` row (minutes, `X.XX hrs`, `$X,XXX.00`); a blank; a **GRAND TOTAL (curated + Signal)** row = total minutes, `X.XX hrs`, `$X,XXX.00` + a note. Numbers/hours/$ must reconcile to the CSV + the invoice.
- `numbers-parser` cannot author formulas, so all totals are static values — expected. **Never touch the other sheets' cells.** After `Document.save(...)`, **reopen and verify**: sheet count went up by one, the new GRAND TOTAL reads correctly, and a prior sheet (e.g. last week's) still reads intact.
- `add_sheet` appends the new sheet at the END; note in the report that Nik may want to drag it above the newest week (numbers-parser can't reorder). If the save would exceed the shell time cap, note it and leave the backup for Nik.

## STEP 6 — Invoice: (a) append to the ledger, (b) generate the standalone CTO invoice file
(a) **Ledger** — append the week's section to `WeOwn Invoices.md`, inserted ABOVE the most recent existing week (newest-first). Section header: `## Week of M/D (Wxx) — X.XX hrs (gross) · $2,000 net at 10 h/wk self-cap · <FINAL ✅ | ⚠️ CONFIRM>`. Match the existing format: summary paragraph (business-owner priority order), Sprint theme, Work Performed grouped by area with est. hours, Key Deliverables, bold Hours/Rate/Total line. Pull substance from the week's journal AI Summaries / CTO Analysis sections.
(b) **Standalone CTO invoice file** — also generate `Planning/<NextWeek>/CTO Invoice - <LastWeek> - <NextWeekStartISO>.md` (matching the prior week's file, e.g. `Planning/2026W26/CTO Invoice - W25 - 2026-06-22.md`). Frontmatter: `type: invoice`, `week`, `week_window`, `ccc_id: CTO_2026-W<n>_30NN` (**continue the sequence**: W23=_3008, W24=_3009, W25=_3010, W26=_3011 → increment by 1), `gross_hours`, `gross_amount`, `self_cap_hours: 10`, `amount_due: 2000`, `rate: 200`, `status`. Body: the invoice header (From **Perpetuator LLC** / **Bill To** Web3 Freedom Club DAO LLC, 5830 E 2nd Dr., Casper WY 82609 / Invoice # W<n>-2026 / phone 720-936-5908), an **Invoice Detail** table (per-day line items: Date · Type · Hours · Description · Cost), a **Self-Cap Adjustment** table (Gross → −comp at the 10 h cap → NET $2,000), a **Summary by Area** table, a **Week Summary** table, and Terms (Due upon receipt · Mercury ACH · CCC-ID). This is the sendable invoice; the ledger section is the running record.

## STEP 7 — Produce the Stripe summary
A single paragraph, ≤500 characters, no markdown, starting with `Week of M/D`, business-owner priority order (major features then major fixes), imperative tone. Output it in the final chat response ready to paste into Stripe.

---

## STEP 8 — Commitments surfaced last week (NEW — drives the workflow Nik is missing)
Write a detailed file at `Planning/<NextWeek>/Open Commitments - <NextWeekStartISO>.md`. Sections:

**(a) Jason's Asks (last week)**
Every request from Jason in last-week's journals (Signal/Zoom). For each: short verbatim quote (≤2 sentences), journal link `[[…]]`, **suggested route** (whose backlog this lands in, per D20). If an ask conflicts with a Tyler ask, flag it.

**(b) Tyler's Asks (last week)**
Same, for Tyler. Her asks are co-founder/CEO weight — never park silently.

**(c) Nik's Commitments (last week)**
Every action item Nik personally committed to in last week's journals (search for `Owner: Nik` or `| Nik |` in action-item tables, and prose like "Nik will…"). For each: title, source link, **status** = `done` / `in-progress` / `overdue` / `untracked`, Tuleap ID if any. This is the "what did I say I'd do" list Nik has been missing. (This list also seeds **Nik's own weekly SOW** in Step 11.5.)

**(d) Delegated to Others (last 2 weeks)**
Items assigned to Mohammed/Shahid/Peter/Roman/Dilonne in the last 14 days. **One table per person**: item, status, source journal, Tuleap ID, `is-tracked (y/n)`. Cross-reference Tuleap via `tuleap_search_artifacts` against project 117 (WeOwn) — text-search the action item phrase. If found, link the artifact; if not, mark `is-tracked: n`.

**(e) Untracked Commitments — Triage**
Everything from (a)–(d) that has **no Tuleap artifact AND is not already in a State doc** is a leak. List them under this heading. This is the section Nik will scan first.

**(f) Items Jason Assigned Directly to Contributors (D20 bypass watch)**
Any task in last week's journals where Jason assigned work directly to a contributor without routing through Nik. List these for Nik to re-route or accept retroactively. This is the bookkeeping-and-planning flag Nik specifically asked for.

## STEP 9 — Update `State/WeOwn.md` (Global Progress + Next Steps)
- Update `## Top Priorities — as of <today>` (re-rank if Jason/Tyler asks from last week have shifted things). Preserve existing D-number references.
- Append or update a `## Global Progress & Next Steps — Week of <NextWeekStart>` section: one paragraph "what shipped last week", one paragraph "what's blocked", one paragraph "what's planned for next week" (tied to the per-contributor proposed SOWs below).
- Update frontmatter `last_processed_journal` + `last_processed_at` per CLAUDE.md state-doc convention.

## STEP 10 — Update the SOW Log ledger
File: `State/SOW Log.md` (exists; preserve format).
- Add a row for **last week** with each contributor's status: ✅ received / 🟡 partial / ❌ missing / — not-yet-contracted / n/a excluded. If you have no signal that a contributor sent in a SOW (no journal entry, no email, no Signal message body containing their SOW), the cell is **❌ missing**.
- Add a row for **next week** with all `pending` (the proposed-SOW drafts you write in Step 11 go out today; their replies are not yet due).
- If any prior-week cell is ❌, list those under **Outstanding SOWs Owed** with a draft follow-up Signal message per person (Status: DRAFT — awaiting CTO send).

## STEP 10.5 — Delivery verification (per contributor, BEFORE drafting any SOW)
**Do NOT carry forward last week's *proposed* SOW items as if still open — verify what's already been delivered first.** For each roster member, before writing their SOW:
1. **State doc** — read the newest status updates in `State/<Name>.md` for ✅-delivered / "claimed complete" items.
2. **Audit / reconciliation docs** — read any `<Name> - SOW vs Delivered vs Billed`, invoice-reconciliation, or performance-assessment doc (e.g. `Shahid - SOW vs Delivered vs Billed (W22-W26) - INTERNAL`). These are the canonical "what was actually done vs said vs billed" record.
3. **Invoice ingestion** — if the contributor has sent an invoice (vault journal, email to `invoices+sow@weown.net`, or a Signal message body), ingest it and **line-match against the last paid invoice**: anything already covered by a paid invoice is **not payable again** (the R48 over-bill pattern). Note net-new vs already-paid.

Then scope the SOW to **genuinely-incomplete work only**. An already-done-but-unverified item becomes a **"verify / close-out" line** (deliver a reachable proof — live URL, dashboard, commit/PR ref), **never a re-build**. Carrying completed work back into a SOW inflates scope and, with billing, risks paying twice. (Root cause, 2026-06-29: Shahid's W27 SOW re-listed paid-SigNoz cloud + SearXNG-via-MCP, both already delivered in W25 — the answer was in the audit doc + his State doc, just not read before drafting.)

## STEP 11 — Draft Proposed SOWs (one per roster member)
For each contributor in the roster:
1. Read their State doc (`State/<Name>.md`) — **including the Step 10.5 delivery-verification pass** so you don't re-list completed work. Create from `Peter.md` template if absent.
2. Read the last 14 days of journal entries mentioning them (search frontmatter `people:` or filenames).
3. Cross-reference WeOwn.md Top Priorities (just updated) + the Jason/Tyler asks from Step 8 + the Strategy-to-Execution doc at `Projects/Strategy-to-Execution and SOW Workflow.md` (incl. §4a — the delivery-verification gate).
4. **Append** a section to their State doc titled `## Proposed SOW — Week of <NextWeekStart> (W<n>)` containing:
   - One-line header: dates, sprint theme (umbrella from WeOwn.md), proposer = `CTO (Nik)`, status = `DRAFT — awaiting contributor confirmation`.
   - **3–6 prioritized tasks** for the week. Each: title, *why it matters this week*, expected output / definition of done, Tuleap link if any, owner = the contributor.
   - Explicit **guidance / onboarding notes** when applicable (heavier for Dilonne).
   - **Mandatory boilerplate line:** `All work performed in Zed (D350/D377).`
   - **Mandatory close line:** `Please send back your own SOW + Anything invoice by EOD Tuesday (A216 / A219). A one-line confirmation of the above also works if nothing differs.`

**Per-person carry-forward defaults (verify against latest journals + the Step 10.5 delivery check before writing — recency rule applies; never re-list already-delivered work):**
- **Peter** — stay on **Keycloak + ownCloud**. Do not add new workstreams. Keycloak is critical #ZeroTo100 infra (Disc #691) — Nik wants Peter to keep that focus.
- **Mohammed** — **finish burnedout.xyz first**, then continue what Jason was asking on Connex/AgencyPRO. If the journals show a Mohammed Wk1/Wk2 split (Jason-side Wk1 → build Wk2 — see Drafts in 2026W22), encode it explicitly in his SOW.
- **Shahid** — ⚠️ **continuation-sensitive, flat-rate, bounded (D418/R48)**, and **delivery-verify first (Step 10.5)**: as of W25 he *delivered* `dev.weown.tools`, the devbox, the OTel→SigNoz agent, and SearXNG-via-MCP — do **not** re-list those; make them a verify/close-out line. Genuinely-open observability = **status pages + domain-expiry (A200/#1311)**. Route key items by experience (e.g. OpenRouter rotation A411 → Dilonne leads, Shahid executes). No HR editorializing in his message.
- **Roman** — review WeOwn.md for current Roman tasks; default to closing auto-review noise (D398, ~20-page autoreview → signal-only), closing the 4–5 open PRs (A197), and running new `*-docker` templates through the Trimeta security pass (A196).
- **Dilonne** — **Supabase + RLS in DOKS for the Pop DB substrate (D408)**, folded into the build plan laid out with Tyler 5/29. Heavier onboarding section: contracting status, repo access, dev-env (Zed mandatory), the proposal at `Projects/ZeroTo100 - Unified Persistence Proposal - 2026-05-29.md` as the spec. The Pop DB ask (Jason 5/31 04:09) IS the substrate of the build sprint — encode that framing so he understands he's the headliner.

## STEP 11.5 — Draft Nik's own weekly SOW (the CTO's SOW for NEXT week)
Nik files his own weekly SOW too — the CTO is on the same cadence as the contributors. Write it at `Planning/<NextWeek>/Nik SOW - <NextWeek> - <NextWeekStartISO>.md`. Source it from the **Open Commitments §(c) Nik's-commitments list** + the **Top-3** + WeOwn.md's "Nik's week" line. Frontmatter: `type: sow`, `subtype: cto-weekly-sow`, `person: Nik`, `week`, `rate: 200`, `billing_cap_hours_per_week: 10`, `status: READY TO SEND — CTO weekly SOW (W<n>)`. Body: a one-line header (dates, sprint umbrella, owner = CTO (Nik), planned-hours vs the 10 h billing cap with overage comped), then **capacity-based prioritized tasks with hour estimates** (contributor-gating unblocks first, then deadline-bound items, then the rest) — each with a DoD + Tuleap/link — a capacity note naming the slip-to-next-week candidates if it overflows, and a close tying it to the W<n> Stripe invoice. This is a **sendable** artifact (to Tyler/Jason), not a DRAFT-to-send message.

## STEP 12 — DRAFT SOW-request messages (one per roster member)
For each contributor, create a file at `Planning/<NextWeek>/SOW Request - <Name> - <NextWeekStartISO>.md`. Frontmatter:

```yaml
---
type: draft-message
recipient: <Name>
channel: signal-private
status: DRAFT — awaiting CTO send
date: <today>
related_state_doc: State/<Name>.md
---
```

Body: short ask. Quote the proposed-SOW section inline (so they have full context in one message). Open with `Hey <Name>, here's the proposed SOW for Week of <date>...`. Close with the Tuesday deadline + Zed reminder + Anything-invoice line. **Do NOT auto-send under any condition.** Per CLAUDE.md, all reply/outbound messages are DRAFTs awaiting CTO review.

## STEP 13 — Monday Open summary file
Write the run's top-level summary at `Planning/<NextWeek>/Monday Open - <NextWeekStartISO>.md`. Contents:
- **Invoice headline:** weekly total ($ and hours), per-day breakdown, the Stripe summary text, and a one-line confirmation the Billing.numbers sheet was created/populated (Step 5).
- **Last week's deliverables** — one paragraph from `WeOwn Invoices.md`'s new section.
- **Counts:** Jason asks, Tyler asks, Nik commitments (split done/in-progress/overdue/untracked), delegated-and-outstanding per person, untracked-commitments total, SOWs owed (from the ledger).
- **Top 3 things needing Nik attention this week** — extract from untracked commitments + missing SOWs + ambiguous priorities. Be concrete (`Send the SOW request to Mohammed — Planning/2026W23/SOW Request - Mohammed - 2026-06-01.md`).
- **Links** to: each contributor's proposed-SOW section, **Nik's own SOW (Step 11.5)**, **the standalone CTO invoice file (Step 6b)**, the Open Commitments file, the SOW Log, WeOwn.md.

## STEP 14 — Tuleap sync (per CLAUDE.md Mandatory Processing Workflow Step 3)
For any new D-numbers, action items, or discoveries created during this run (commitments triage often surfaces new ones): sync to Tuleap project 117 (WeOwn). Include `Source: <vault-path>` in each new artifact body and record the artifact ID in journal frontmatter `tuleap_sync.artifacts`. If Tuleap is down, set `tuleap_sync.status: pending` and surface in the Monday Open summary — do **not** add to the deprecated `logs/tuleap-offline-queue.md`.

---

## DO NOT
- Auto-send any Signal / email message. Everything goes out as a DRAFT.
- Modify historical journal entries. Append to State docs, but the original journal entries are immutable.
- Regress current-status fields in any State doc with older information (CLAUDE.md recency rule).
- Rewrite other weeks' sheets in `WeOwn Billing.numbers`. Author only the new week's sheet (all-static values); back up first and verify prior sheets still read after saving.
- Commit to git — the vault auto-syncs.
- Re-route a task that Jason assigned directly to a contributor without first **flagging** it in Step 8(f). Re-routing is a Nik decision, not yours.
- **Re-list already-delivered work in any SOW** (Step 10.5). Completed-but-unverified items become a verify/close-out line, never a re-build.

## FINAL REPORT (in chat at end of run)
1. Invoice headline (weekly $ + hours + per-day breakdown) + confirmation the Billing.numbers sheet was created/populated.
2. The Stripe summary paragraph, paste-ready.
3. Counts table: Jason asks / Tyler asks / Nik commitments (status split) / delegated / untracked / SOWs owed.
4. The **Top 3 things needing Nik attention this week**.
5. Paths to: Monday Open summary, Open Commitments file, **the standalone CTO invoice file**, **Nik's own weekly SOW**, each per-contributor proposed-SOW section, each DRAFT SOW request.
6. Any data-capture gaps (missing Signal days, Zoom permission denials, off-channel calls to add manually).
7. Anything ambiguous that needs a Nik decision before next Monday.