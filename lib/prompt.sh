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
# Placement (governance): this universal tooling lives in claude-config (the
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
  ansible-inventory -i "$inv" --list 2>/dev/null | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
hosts = (d.get('$group', {}) or {}).get('hosts') or []
print(hosts[0] if hosts else '')
" 2>/dev/null
}
