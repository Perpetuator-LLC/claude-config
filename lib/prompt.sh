#!/usr/bin/env bash
# Universal secret-prompt helpers — ONE self-describing format across all projects.
#
# Source it from any operator script:
#   . "${CLAUDE_LIB:-$HOME/.claude/lib}/prompt.sh"
#
# WHY: every credential prompt should say WHAT it is, WHERE it comes from, and
# WHICH machine/service it authenticates to — so the human never has to guess at a
# bare "password:". But hostnames are ENGAGEMENT-specific data: they live in ONE
# source of truth (the project's ansible inventory), never hardcoded in scripts or
# hand-off blocks. This library is the universal FORMAT; `resolve_host` reads the
# engagement's inventory for the NAMES. A machine rename is then one edit.
#
# Placement (governance): this universal tooling lives in operating-canon (the
# all-projects layer); the hostnames it renders come from each project's inventory
# (the engagement layer). See global/CLAUDE.md → "Prompt & host-name standard".

# prompt_secret VAR "label" ["source"] ["target"]
#   Print a standard descriptive line, then read a HIDDEN value into VAR:
#     🔑 <label> (hidden) — from <source> → <target>
#       ↳
prompt_secret() {
  local __var="$1" label="$2" src="${3:-}" tgt="${4:-}"
  local line="🔑 ${label} (hidden)"
  [ -n "$src" ] && line="${line} — from ${src}"
  [ -n "$tgt" ] && line="${line} → ${tgt}"
  printf '%s\n' "$line" >&2
  if [ -n "${ZSH_VERSION-}" ]; then
    # shellcheck disable=SC2229,SC2296
    read -rs "${__var}?  ↳ "
  else
    read -rsp "  ↳ " "${__var?}"
  fi
  printf '\n' >&2
}

# prompt_plain VAR "label" ["source"]
#   Visible (non-secret) input into VAR, with the same descriptive prefix.
prompt_plain() {
  local __var="$1" label="$2" src="${3:-}"
  local line="🔑 ${label}"
  [ -n "$src" ] && line="${line} — from ${src}"
  read -rp "${line}: " "${__var?}"
}

# resolve_host <group> [inventory]
#   The SINGLE source of truth for hostnames = the project's ansible inventory.
#   Prints the first host in <group> (empty if unavailable). Callers use this
#   instead of hardcoding a hostname:  TARGET="$(resolve_host baremetal)".
resolve_host() {
  local group="$1" inv="${2:-inventory/hosts.ini}"
  command -v ansible-inventory >/dev/null 2>&1 || return 0
  # group passed as argv — never interpolated into the code (injection-safe)
  ansible-inventory -i "$inv" --list 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
g = sys.argv[1]
hosts = (d.get(g, {}) or {}).get('hosts') or []
print(hosts[0] if hosts else '')
" "$group" 2>/dev/null
}

# ensure_bao_role <role>
#   PRE-FLIGHT a bao session: verify the ACTIVE token was minted for <role> (its
#   OIDC token meta.role); if not — wrong role, or no/expired session — log in as
#   <role>. No-op when already correct. Catches a wrong-credential UP FRONT instead
#   of failing deep in a run (e.g. an operator token where a provisioner is needed).
#   Returns non-zero only if bao is missing or the login is declined.
ensure_bao_role() {
  local want="$1" have=""
  command -v bao >/dev/null 2>&1 || { printf '⚠️  bao CLI not found — cannot verify session role.\n' >&2; return 1; }
  if bao token lookup >/dev/null 2>&1; then
    have="$(bao token lookup -format=json 2>/dev/null \
      | python3 -c 'import sys,json; print(json.load(sys.stdin).get("data",{}).get("meta",{}).get("role",""))' 2>/dev/null || true)"
  fi
  if [ "$have" = "$want" ]; then
    printf '✓ bao session role=%s — OK.\n' "$want" >&2
    return 0
  fi
  printf "⚠️  bao session role='%s', need '%s' — logging in…\n" "${have:-none}" "$want" >&2
  bao login -method=oidc "role=${want}" >/dev/null
}
