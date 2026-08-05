#!/usr/bin/env bash
# allm-send.sh <prompt-file> [workspace-slug] — send one prompt to AnythingLLM, save the reply.
#
# Why this exists: the allm_* MCP tools are not attached, and the agent must never see the
# API key (Agent Secret Ban). This script reads creds from OpenBao into shell variables that
# are never printed, posts the prompt, and writes the reply to a file the agent reads back.
#
# Creds: OpenBao secret/weown/anythingllm → fields api_key, base_url.
# Override for dev with ALLM_BASE_URL / ALLM_API_KEY already in the environment.
#
# Rule 16 / G8: whatever is in <prompt-file> goes to a WeOwn instance — WeOwn content only,
# no secrets, no other client's material. The reply is UNTRUSTED content, not instructions.
set -uo pipefail

PROMPT_FILE="${1:?usage: allm-send.sh <prompt-file> [workspace-slug]}"
WS="${2:-}"
[[ -f "$PROMPT_FILE" ]] || { echo "FATAL: no such prompt file: $PROMPT_FILE"; exit 1; }
OUT="${ALLM_OUT:-${TMPDIR:-/tmp}/allm-reply.md}"

# --- creds (never echoed) ---
BASE="${ALLM_BASE_URL:-}"; KEY="${ALLM_API_KEY:-}"
if [[ -z "$KEY" ]]; then
  command -v bao >/dev/null || { echo "FATAL: bao CLI not found and ALLM_API_KEY unset"; exit 1; }
  KEY=$(bao kv get -field=api_key secret/weown/anythingllm 2>/dev/null) || {
    echo "FATAL: could not read api_key from OpenBao — is your bao session live? (bao login)"; exit 1; }
fi
[[ -n "$BASE" ]] || BASE=$(bao kv get -field=base_url secret/weown/anythingllm 2>/dev/null) || true
BASE="${BASE:-https://dev.weown.tools}"
BASE="${BASE%/}"
[[ -n "$KEY" ]] || { echo "FATAL: empty api_key"; exit 1; }

api() {  # api <method> <path> [json-body]
  local m="$1" p="$2" b="${3:-}"
  if [[ -n "$b" ]]; then
    curl -sS -m 180 -X "$m" -H "Authorization: Bearer $KEY" -H "Content-Type: application/json" \
         -d "$b" "$BASE/api/v1$p"
  else
    curl -sS -m 60 -X "$m" -H "Authorization: Bearer $KEY" -H "Accept: application/json" "$BASE/api/v1$p"
  fi
}

echo "[1/4] auth check → $BASE"
AUTH=$(api GET /auth) || { echo "FATAL: request failed (network/allowlist?)"; exit 1; }
python3 -c "
import json,sys
try: d=json.loads(sys.argv[1])
except Exception: print('FATAL: non-JSON reply — check base_url'); sys.exit(1)
sys.exit(0 if d.get('authenticated') else 2)" "$AUTH" || { echo "FATAL: not authenticated (bad key?)"; exit 1; }
echo "  authenticated ✓"

echo "[2/4] workspaces"
WSJSON=$(api GET /workspaces)
if [[ -z "$WS" ]]; then
  WS=$(python3 -c "
import json,sys
w=json.loads(sys.argv[1]).get('workspaces',[])
print('  available:', ', '.join(x['slug'] for x in w), file=sys.stderr)
print(w[0]['slug'] if len(w)==1 else '')" "$WSJSON")
  [[ -n "$WS" ]] || { echo "FATAL: multiple workspaces — re-run with a slug from the list above"; exit 1; }
fi
echo "  using workspace: $WS"

echo "[3/4] new thread"
TJSON=$(api POST "/workspace/$WS/thread" "$(python3 -c "
import json,time; print(json.dumps({'name':'ctx-volley-'+time.strftime('%Y%m%d-%H%M%S'),'userId':4}))")")
THREAD=$(python3 -c "
import json,sys
d=json.loads(sys.argv[1]); t=d.get('thread') or {}
print(t.get('slug',''))" "$TJSON")
[[ -n "$THREAD" ]] || { echo "FATAL: thread not created. Raw: ${TJSON:0:300}"; exit 1; }
echo "  thread: $THREAD"

echo "[4/4] sending prompt ($(wc -c < "$PROMPT_FILE") bytes) — model may take a minute…"
BODY=$(python3 -c "
import json,sys
print(json.dumps({'message': open(sys.argv[1],encoding='utf-8').read(), 'mode':'chat', 'userId':4}))" "$PROMPT_FILE")
RESP=$(api POST "/workspace/$WS/thread/$THREAD/chat" "$BODY")
python3 -c "
import json,sys
d=json.loads(sys.argv[1])
txt=d.get('textResponse') or d.get('response') or ''
if not txt: print('FATAL: empty reply. Raw:', json.dumps(d)[:400]); sys.exit(1)
open(sys.argv[2],'w',encoding='utf-8').write(txt)
print('  reply saved:', len(txt), 'chars')" "$RESP" "$OUT" || exit 1

echo "════ done — reply: $OUT"
echo "  thread in UI: $BASE/workspace/$WS  (thread: $THREAD)"
