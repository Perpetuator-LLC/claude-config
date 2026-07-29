#!/bin/bash
# Hook: SessionStart — verify the on-demand context surfaces actually exist.
#
# The resident CLAUDE.md is a thin tripwire layer that POINTS at on-demand
# context (governance domain docs, skills, symlinked dirs). A broken pointer
# fails silently: the model just operates without the rules. This hook derives
# the expected surfaces from the config itself (no hardcoded manifest), checks
# them, and surfaces only UNACCEPTED gaps into the session context.
#
# Accepting a known/deliberate gap: add its exact item string (the part after
# "MISSING: "/"BROKEN: ") as a line in ~/.claude/context-integrity.accepted
# (machine-local, never committed). Accepted items are skipped silently, so
# nothing nags — but any NEW breakage always surfaces. The hook prints the
# accept instruction with each finding.
#
# Always exits 0 — this is a reporter, never a blocker.

CLAUDE_DIR="$HOME/.claude"
ACCEPT_FILE="$CLAUDE_DIR/context-integrity.accepted"
findings=()

is_accepted() {
  [[ -f "$ACCEPT_FILE" ]] && grep -Fxq "$1" "$ACCEPT_FILE"
}

add_finding() { # $1 = kind (MISSING/BROKEN), $2 = item, $3 = consequence
  is_accepted "$2" && return 0
  findings+=("$1: $2 — $3")
}

# --- 1. Symlinked config dirs resolve (a dead symlink = whole surface gone) ---
for link in CLAUDE.md settings.json agents skills governance; do
  target="$CLAUDE_DIR/$link"
  if [[ -L "$target" && ! -e "$target" ]]; then
    add_finding "BROKEN" "~/.claude/$link (dead symlink)" "everything under it is unavailable"
  elif [[ ! -e "$target" ]]; then
    add_finding "MISSING" "~/.claude/$link" "surface not installed (run operating-canon/install.sh)"
  fi
done

# --- 2. Every governance/<domain>.md referenced by the resident config exists ---
# Derive from the config itself (resident CLAUDE.md + the Core's domain index)
# so new references are checked automatically — no hardcoded manifest.
while IFS= read -r ref; do
  [[ -z "$ref" ]] && continue
  if [[ ! -f "$CLAUDE_DIR/$ref" ]]; then
    add_finding "MISSING" "~/.claude/$ref" "rules routed there will silently not load"
  fi
done < <(cat "$CLAUDE_DIR/CLAUDE.md" "$CLAUDE_DIR/governance/README.md" 2>/dev/null \
         | grep -oE 'governance/[a-zA-Z_-]+\.md' | sort -u)

# --- 3. Skills referenced in the resident tag table exist + parse ---
# A SKILL.md whose frontmatter description is empty/truncated (e.g. an unquoted
# leading # turning the rest into a YAML comment) breaks auto-triggering while
# looking installed. Check every installed skill generically.
if [[ -d "$CLAUDE_DIR/skills" ]]; then
  for skill_md in "$CLAUDE_DIR/skills"/*/SKILL.md; do
    [[ -e "$skill_md" ]] || continue
    name="$(basename "$(dirname "$skill_md")")"
    # Extract the description value as YAML would parse it (plain scalar stops at #)
    desc_line="$(grep -m1 '^description:' "$skill_md")"
    desc_val="${desc_line#description:}"
    desc_val="${desc_val# }"
    if [[ -z "$desc_val" ]]; then
      add_finding "BROKEN" "skill $name (no description)" "skill will not auto-trigger"
    elif [[ "$desc_val" != \"* && "$desc_val" != \'* && "$desc_val" != ">"* && "$desc_val" != "|"* && "$desc_val" == *"#"* ]]; then
      add_finding "BROKEN" "skill $name (unquoted # truncates YAML description)" "auto-trigger text is cut off"
    fi
  done
  # Tag table in resident config → each named skill must exist
  if [[ -e "$CLAUDE_DIR/CLAUDE.md" ]]; then
    while IFS= read -r sk; do
      [[ -z "$sk" ]] && continue
      if [[ ! -f "$CLAUDE_DIR/skills/$sk/SKILL.md" ]]; then
        add_finding "MISSING" "skill $sk" "its #tag/slash command will silently do nothing"
      fi
    done < <(grep -oE '^\| \`#[A-Za-z]+\` \| \`[a-z-]+\`' "$CLAUDE_DIR/CLAUDE.md" 2>/dev/null | grep -oE '\| \`[a-z-]+\`$' | tr -d '|` ')
  fi
fi

# --- 4. Project-level: CLAUDE.md pointers to local skill/SOP paths (generic) ---
# Check wiki-style + inline references to Skills/*/SKILL.md within the cwd project.
if [[ -f "CLAUDE.md" ]]; then
  while IFS= read -r ref; do
    [[ -z "$ref" ]] && continue
    if [[ ! -e "$ref" ]]; then
      add_finding "MISSING" "$PWD/$ref" "project CLAUDE.md routes work to a file that doesn't exist"
    fi
  done < <(grep -oE '[A-Za-z0-9 _/-]+/SKILL\.md' "CLAUDE.md" 2>/dev/null | sed 's/^ *//' | sort -u)
fi

# --- Report (stdout of a SessionStart hook enters the session context) ---
if ((${#findings[@]})); then
  echo "⚠️ CONTEXT INTEGRITY — on-demand context this config points at is missing/broken:"
  for f in "${findings[@]}"; do
    echo "  - $f"
  done
  echo "AGENT: tell the user about these findings in your first reply (they may be unaware);"
  echo "work around the gaps explicitly — never pretend the missing rules/skills loaded."
  echo "USER: to accept a gap as deliberate and silence it, add the item string (text between"
  echo "'MISSING:/BROKEN:' and ' — ') as its own line in ~/.claude/context-integrity.accepted"
fi

exit 0
