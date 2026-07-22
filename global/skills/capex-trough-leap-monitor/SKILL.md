---
name: capex-trough-leap-monitor
description: Weekly Capex-Trough LEAP monitor for META — evaluates the system gates/rules on fresh data and flags triggers.
---

You are running the weekly "Capex-Trough Compounder LEAP" monitor for Nik. This is ANALYSIS TOOLING ONLY — never place trades or move money; output recommendations/alerts that Nik approves himself.

WATCHLIST: META (Meta Platforms).
Config of record (read it if accessible for exact thresholds/bands): /Users/nik/projects/notes/Nik/Investing/Strategies/Capex-Trough LEAP System/meta-capex-leap.yml . The companion playbook is "Capex-Trough Compounder LEAP System.md" in the same folder.

STEP 1 — Pull CURRENT data via web search (most recent available):
- META current price and 52-week high.
- Latest reported quarter: revenue YoY growth, operating-margin trend, ad price-per-ad YoY (pricing power), capex guidance and whether a 2027 capex ceiling has been given, any guidance shock.
- Major news in the last ~week (earnings, guidance, regulatory, senior AI departures, FCF).

STEP 2 — Evaluate the gates:
- QUALITY: ROIC>=15%; op margin flat or rising; net cash or net-debt/EBITDA<1.5; rev growth>=10%.
- CAPEX-TROUGH: capex/revenue at a 3-yr high; capex YoY>40%; FCF margin falling WHILE op margin flat/up; D&A/capex<0.7.
- VALUATION: reverse-DCF implied growth<=10%; forward P/E<=5-yr median; (DCF base band / price) >= 1.25. Use DCF bands bear/base/bull = 190 / 712 / 1051 UNLESS a new earnings report has come out — if so, recompute the bands with an owner-FCF DCF and say you did.
- DISLOCATION: drawdown from 52-wk high <= -20%  (drawdown = price/high - 1).
- KPIs INTACT: price-per-ad YoY>0 AND rev growth>=10%.
- FALSIFIERS (count true): (1) capex YoY>40% AND no 2027 ceiling; (2) price-per-ad YoY<=0; (3) op-margin trend<0; (4) rev growth<10%.

STEP 3 — State & rules:
- screen_pass = QUALITY and CAPEX-TROUGH and VALUATION.
- R1 ARMS when screen_pass AND dislocation AND KPIs intact AND IV-rank<50.
- X1 TRIM if price>=base band; X1b EXIT/ROLL if price>=bull band.
- X2 THESIS BREAK (priority alert) if >=2 falsifiers true.
- Also report base margin-of-safety = base/price - 1, and the price level (base/1.25) and base-estimate (price*1.25) that would flip the valuation gate.

STEP 4 — Report titled "META LEAP Monitor — <today's date>", tight:
- One-line STATUS (e.g. "WATCH — fails valuation gate (1.2x<1.25x)", "R1 ARMED", or "THESIS BREAK").
- A small table of each gate: pass/fail + the number.
- Drawdown, base MoS, falsifier count, IV-rank (note if unknown).
- If R1 not yet armed, state exactly what would arm it (price level / base-estimate / IVR check).
- Any news flags.
- Close with: "Recommendations only — Nik approves any order. Not investment advice."