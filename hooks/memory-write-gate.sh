#!/usr/bin/env bash
# PreToolUse hook: gate memory-file writes (Write/Edit).
#
# Scope: only files under a `.claude/.../memory/` dir ending in `.md`, and
# NOT the `MEMORY.md` index (which is pointers, not a fact).
#
# Two layers, matching the documented split (the petrification failure is
# SEMANTIC and can't be regex'd, so only the structural part hard-blocks):
#   * Hard-block (exit 2) — mechanically decidable only: a full-file Write
#     whose content lacks valid frontmatter (name / description / type).
#     Edits are partial, so they are never blocked on frontmatter.
#   * Advisory (additionalContext) — every gated write: the petrification
#     checklist (scoped-as-law / volatile-value-vs-recipe / atomicity /
#     frame) + an index-line reminder for new files.
#
# Companion to step-delta-check.sh on the same Write|Edit matcher.

set -uo pipefail

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
FILE=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)

# Gate only .claude memory fact-files; everything else passes silently.
case "$FILE" in
  */memory/*.md) : ;;
  *) exit 0 ;;
esac
case "$FILE" in
  *.claude/*) : ;;
  *) exit 0 ;;
esac
[ "$(basename "$FILE")" = "MEMORY.md" ] && exit 0

# ── Hard-block: full-file Write with missing/invalid frontmatter ────────────
if [ "$TOOL" = "Write" ]; then
  CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // empty' 2>/dev/null || true)
  fm_ok=1
  printf '%s\n' "$CONTENT" | head -1 | grep -qE '^---[[:space:]]*$' || fm_ok=0
  if [ "$fm_ok" = 1 ]; then
    FM=$(printf '%s\n' "$CONTENT" | awk 'NR==1&&/^---[[:space:]]*$/{f=1;next} f&&/^---[[:space:]]*$/{exit} f{print}')
    printf '%s\n' "$FM" | grep -qE '^name:'        || fm_ok=0
    printf '%s\n' "$FM" | grep -qE '^description:' || fm_ok=0
    printf '%s\n' "$FM" | grep -qE '(^|[[:space:]])type:' || fm_ok=0
  fi
  if [ "$fm_ok" = 0 ]; then
    cat >&2 <<'EOF'
BLOCKED: memory note is missing valid frontmatter.

A memory file must begin with:
---
name: <kebab-slug>
description: <one-line, frame-complete summary>
metadata:
  type: user | feedback | project | reference
---
<one atomic fact>

(This fires on full-file Writes only — Edits are exempt.)
EOF
    exit 2
  fi
fi

# ── Advisory: petrification checklist (cannot be mechanized) ────────────────
jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "MEMORY GATE — before saving, check this note against the petrification failure mode (a scoped observation compressing into a false law): (1) Is a scoped observation written as an absolute law? Add its frame, or demote to a dated/disposable note. (2) Is the fact volatile + cheap to re-derive? Store the RECIPE to re-derive it, not the value. (3) Is it ONE atomic claim that degrades all-or-nothing, or a bundle whose partial loss would read as false? Split only if a partial would mislead. (4) Does the durable part survive compression to its kernel without becoming a false fragment? If this is a NEW memory file, also add its one-line pointer to MEMORY.md."
  }
}'
exit 0
