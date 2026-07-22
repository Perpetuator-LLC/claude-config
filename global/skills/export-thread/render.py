#!/usr/bin/env python3
"""Render a Claude Code JSONL transcript into a readable Markdown thread export.

Captures the three things you want to re-read later: the ASKS (user turns), the
REASONING (thinking blocks, verbatim — the "why" behind decisions), and the
ACTIONS (tool calls, summarized). Deterministic, stdlib-only, non-interactive.

Exports land in the VISIBLE vault, so every rendered string passes a secret
redactor first. When unsure it over-redacts.

Usage:
    render.py --transcript <file.jsonl> [--out <file.md>]
              [--engagement Internal] [--project cc-be] [--title "..."]
              [--max-thinking 8000] [--max-text 5000]

With no --out, prints to stdout. Metadata (session id, cwd, branch, model,
date range) is derived from the transcript itself.
"""
import argparse
import json
import re
import sys
import uuid
from datetime import datetime, timezone

# ---------------------------------------------------------------- redaction
_SECRET_PATTERNS = [
    (re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----.*?-----END [A-Z ]*PRIVATE KEY-----', re.S), '[REDACTED-private-key]'),
    (re.compile(r'\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{4,}'), '[REDACTED-jwt]'),
    (re.compile(r'\b(?:sk|rk|pk|sk-ant)-[A-Za-z0-9_-]{16,}'), '[REDACTED-api-key]'),
    (re.compile(r'\bph[cx]_[A-Za-z0-9]{20,}'), '[REDACTED-posthog-key]'),
    (re.compile(r'\bwhsec_[A-Za-z0-9]{16,}'), '[REDACTED-stripe-whsec]'),
    (re.compile(r'\bgh[pousr]_[A-Za-z0-9]{20,}'), '[REDACTED-github-token]'),
    (re.compile(r'\bxox[baprs]-[A-Za-z0-9-]{10,}'), '[REDACTED-slack-token]'),
    (re.compile(r'\bAKIA[0-9A-Z]{16}\b'), '[REDACTED-aws-akid]'),
    (re.compile(r'\bhv[sb]\.[A-Za-z0-9_-]{18,}'), '[REDACTED-vault-token]'),
    (re.compile(r'(?im)\b(bearer|authorization|token|password|passwd|secret|api[_-]?key|access[_-]?token|client[_-]?secret)\b\s*[:=]\s*["\']?([A-Za-z0-9._\-/+=]{8,})'), r'\1=[REDACTED]'),
]


def redact(s: str) -> str:
    if not s:
        return s
    for pat, repl in _SECRET_PATTERNS:
        s = pat.sub(repl, s)
    return s


# ---------------------------------------------------------------- helpers
def _clip(s: str, n: int) -> str:
    s = s.rstrip()
    if len(s) <= n:
        return s
    return s[:n].rstrip() + f"\n\n_…(+{len(s) - n} chars trimmed)_"


def _one_line(s: str, n: int = 200) -> str:
    s = " ".join((s or "").split())
    return s if len(s) <= n else s[:n] + "…"


def _blockquote(s: str) -> str:
    return "\n".join("> " + ln if ln else ">" for ln in s.splitlines())


def _tool_summary(name: str, inp) -> str:
    """One-line, redacted summary of a tool call."""
    if not isinstance(inp, dict):
        return f"**{name}**"
    if name == "Bash" and "command" in inp:
        return f"**Bash** — `{_one_line(inp['command'], 180)}`"
    for k in ("file_path", "path", "pattern", "query", "url", "prompt", "description", "message", "subject"):
        if k in inp and isinstance(inp[k], str):
            return f"**{name}** — {k}: {_one_line(inp[k], 160)}"
    keys = ", ".join(inp.keys())
    return f"**{name}** — ({keys})"


def _text_blocks(content):
    """Yield ('text'|'thinking'|'tool_use'|'tool_result', payload) from a message content."""
    if isinstance(content, str):
        yield ("text", content)
        return
    if not isinstance(content, list):
        return
    for b in content:
        if not isinstance(b, dict):
            continue
        t = b.get("type")
        if t == "text":
            yield ("text", b.get("text", ""))
        elif t == "thinking":
            yield ("thinking", b.get("thinking", ""))
        elif t == "tool_use":
            yield ("tool_use", (b.get("name", "tool"), b.get("input")))
        elif t == "tool_result":
            yield ("tool_result", None)


# ---------------------------------------------------------------- main render
def render(events, engagement, project, title_override, max_thinking, max_text):
    meta = {}
    title = title_override
    started = ended = None
    model = None
    user_prompts = []
    body = []
    n_user = n_assistant = n_tool = n_think = 0
    last_role = None

    for ev in events:
        et = ev.get("type")
        ts = ev.get("timestamp")
        if ts:
            started = started or ts
            ended = ts
        if not meta and ev.get("cwd"):
            meta = {
                "cwd": ev.get("cwd", ""),
                "session": ev.get("sessionId", ""),
                "branch": ev.get("gitBranch", ""),
                "version": ev.get("version", ""),
            }
        if et == "custom-title" and ev.get("customTitle"):
            if not title_override:
                title = ev["customTitle"]
            continue
        msg = ev.get("message")
        if not isinstance(msg, dict):
            continue
        if et == "user":
            texts = [p for k, p in _text_blocks(msg.get("content")) if k == "text" and p and p.strip()]
            if not texts:
                continue  # tool-result carrier turn — skip the noise
            n_user += 1
            joined = redact("\n\n".join(texts).strip())
            user_prompts.append(_one_line(joined, 140))
            body.append(f"\n### 👤 Nik\n\n{_clip(joined, max_text)}\n")
            last_role = "user"
        elif et == "assistant":
            model = model or msg.get("model")
            parts = []
            for kind, payload in _text_blocks(msg.get("content")):
                if kind == "thinking" and payload.strip():
                    n_think += 1
                    parts.append("**🧠 Reasoning**\n\n" + _blockquote(_clip(redact(payload.strip()), max_thinking)))
                elif kind == "text" and payload.strip():
                    parts.append(_clip(redact(payload.strip()), max_text))
                elif kind == "tool_use":
                    n_tool += 1
                    name, inp = payload
                    parts.append("- 🔧 " + redact(_tool_summary(name, inp)))
            if not parts:
                continue
            n_assistant += 1
            joined_parts = "\n\n".join(parts)
            if last_role == "assistant":  # coalesce consecutive assistant events
                body.append("\n" + joined_parts + "\n")
            else:
                body.append("\n### 🤖 Assistant\n\n" + joined_parts + "\n")
            last_role = "assistant"

    def _fmt(ts):
        if not ts:
            return "?"
        return ts.replace("T", " ")[:19] + "Z" if "T" in ts else ts

    title = title or (user_prompts[0] if user_prompts else "Untitled thread")
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    fm = [
        "---",
        f"id: {uuid.uuid4()}",
        "type: thread-export",
        f"title: {json.dumps(title)}",
        f"engagement: {engagement}",
        f"project: {project}",
        f"source_session: {meta.get('session', '')}",
        f"cwd: {meta.get('cwd', '')}",
        f"git_branch: {meta.get('branch', '')}",
        f"model: {model or ''}",
        f"claude_code_version: {meta.get('version', '')}",
        f"started: {_fmt(started)}",
        f"ended: {_fmt(ended)}",
        f"message_counts: {{user: {n_user}, assistant: {n_assistant}, tool_calls: {n_tool}, reasoning_blocks: {n_think}}}",
        f"generated_by: export-thread",
        f"generated_at: {now}",
        "tags: [thread-export, reasoning-capture]",
        "---",
        "",
        f"# 🧵 {title}",
        "",
        f"> Thread export from `{meta.get('cwd','')}` (session `{meta.get('session','')[:8]}`), "
        f"{_fmt(started)} → {_fmt(ended)}. "
        f"{n_user} asks · {n_assistant} assistant turns · {n_tool} actions · {n_think} reasoning blocks. "
        f"Reasoning is captured verbatim (why decisions were made); secrets redacted.",
        "",
        "## Asks (navigation)",
        "",
    ]
    fm += [f"{i+1}. {p}" for i, p in enumerate(user_prompts)] or ["_(no user prompts captured)_"]
    fm += ["", "## Conversation", ""]
    return "\n".join(fm) + "\n" + "\n".join(body) + "\n"


def load_events(path):
    out = []
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                out.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--transcript", required=True)
    ap.add_argument("--out")
    ap.add_argument("--engagement", default="Internal")
    ap.add_argument("--project", default="")
    ap.add_argument("--title", default="")
    ap.add_argument("--max-thinking", type=int, default=8000)
    ap.add_argument("--max-text", type=int, default=5000)
    a = ap.parse_args()

    events = load_events(a.transcript)
    if not events:
        sys.exit(f"no events parsed from {a.transcript}")
    md = render(events, a.engagement, a.project, a.title, a.max_thinking, a.max_text)
    if a.out:
        with open(a.out, "w", encoding="utf-8") as fh:
            fh.write(md)
        print(f"wrote {a.out} ({len(md)} bytes, {md.count(chr(10))} lines)")
    else:
        sys.stdout.write(md)


if __name__ == "__main__":
    main()
