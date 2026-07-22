#!/usr/bin/env python3
"""Nightly batch driver for /export-thread — active repos only, idempotent.

For each active fleet repo, finds transcripts touched in the last N hours and
renders each to its vault `Journal/<YYYYMM>/Threads/` folder. Idempotent: skips a
thread whose export already exists and is at least as new as the transcript, so
re-running the same night is a no-op and a thread that got more activity re-exports.

Deterministic + stdlib-only; reuses render.py. Never commits (Obsidian owns vault git).

    batch.py [--window-hours 26] [--dry-run] [--repos cc-be,cc-fe]
"""
import argparse
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render  # noqa: E402

PERP = os.path.expanduser("~/projects/notes-perpetuator")
NIK = os.path.expanduser("~/projects/notes-nik")

# repo → routing. base_journal is where "<YYYYMM>/Threads/" hangs.
FLEET = [
    ("cc-be",             "Internal", "cc-be",             PERP, "Engagements/Internal/Journal"),
    ("cc-fe",             "Internal", "cc-fe",             PERP, "Engagements/Internal/Journal"),
    ("mcp",               "Internal", "Perpetuator",       PERP, "Engagements/Internal/Journal"),
    ("rp-be",             "Internal", "RallyPoint",        PERP, "Engagements/Internal/Journal"),
    ("rp-fe",             "Internal", "RallyPoint",        PERP, "Engagements/Internal/Journal"),
    ("ai",                "WeOwn",    "WeOwn",             PERP, "Engagements/Internal/Journal"),
    ("inference",         "Internal", "Perpetuator Inference", PERP, "Engagements/Internal/Journal"),
    ("notes-perpetuator", "Internal", "Perpetuator",       PERP, "Engagements/Internal/Journal"),
    ("notes-nik",         "Personal", "notes-nik",         NIK,  "Work/Journal"),
]

PROJECTS = os.path.expanduser("~/.claude/projects")


def flat(cwd):
    return cwd.replace("/", "-")


def first_meta(events):
    """(session_id, start_ts) from the earliest event carrying them."""
    sid, start = "", None
    for ev in events:
        if not sid and ev.get("sessionId"):
            sid = ev["sessionId"]
        ts = ev.get("timestamp")
        if ts and start is None:
            start = ts
        if sid and start:
            break
    return sid, start


def run(window_hours, dry_run, only):
    cutoff = time.time() - window_hours * 3600
    exported, skipped, empty = [], [], []
    for repo, eng, proj, vault, base in FLEET:
        if only and repo not in only:
            continue
        cwd = os.path.expanduser(f"~/projects/{repo}")
        pdir = os.path.join(PROJECTS, flat(cwd))
        if not os.path.isdir(pdir):
            continue
        for name in os.listdir(pdir):
            if not name.endswith(".jsonl"):
                continue
            tpath = os.path.join(pdir, name)
            try:
                tmtime = os.path.getmtime(tpath)
            except OSError:
                continue
            if tmtime < cutoff:
                continue
            events = render.load_events(tpath)
            if not events:
                empty.append(name)
                continue
            sid, start = first_meta(events)
            sid8 = (sid or name)[:8]
            start_date = (start or "")[:10] or "undated"
            month = (start or "")[:7].replace("-", "") or "unknown"
            out_dir = os.path.join(vault, base, month, "Threads")
            out = os.path.join(out_dir, f"{start_date}-{repo}-{sid8}.md")
            if os.path.exists(out) and os.path.getmtime(out) >= tmtime:
                skipped.append(os.path.basename(out))
                continue
            if dry_run:
                exported.append(os.path.basename(out) + " (would write)")
                continue
            os.makedirs(out_dir, exist_ok=True)
            md = render.render(events, eng, proj, "", 8000, 5000)
            with open(out, "w", encoding="utf-8") as fh:
                fh.write(md)
            exported.append(os.path.basename(out))
    return exported, skipped, empty


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--window-hours", type=int, default=26)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--repos", default="")
    a = ap.parse_args()
    only = set(x.strip() for x in a.repos.split(",") if x.strip())
    exported, skipped, empty = run(a.window_hours, a.dry_run, only)
    verb = "WOULD export" if a.dry_run else "exported"
    print(f"thread-export batch: {verb} {len(exported)}, skipped {len(skipped)} up-to-date"
          + (f", {len(empty)} empty" if empty else ""))
    for e in exported:
        print(f"  + {e}")
    if a.dry_run and skipped:
        print(f"  ({len(skipped)} already current: " + ", ".join(skipped[:6]) + ("…" if len(skipped) > 6 else "") + ")")


if __name__ == "__main__":
    main()
