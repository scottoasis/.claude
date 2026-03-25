#!/usr/bin/env bash
# Domain context injection hook for Claude Code
# Progressive disclosure levels:
#   Level 0: CLAUDE.md (always loaded by Claude Code, not this hook)
#   Level 1: Domain friction stats from SQLite (2-3 lines per domain)
#   Level 2: Domain knowledge files from domains/*.md
# Configure as UserPromptSubmit hook in ~/.claude/settings.json

set -uo pipefail

FRICTION_DIR="${HOME}/.claude/friction"
DOMAIN_MAP="${FRICTION_DIR}/domain-map.json"
DOMAINS_DIR="${FRICTION_DIR}/domains"
DB="${FRICTION_DIR}/friction.db"

# Read hook input from stdin
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)

# Exit silently if no CWD or no domain map
if [ -z "$CWD" ] || [ ! -f "$DOMAIN_MAP" ]; then
  echo '{}'
  exit 0
fi

# Check if jq is available
if ! command -v jq &>/dev/null; then
  echo '{}'
  exit 0
fi

# Find matching domains for the current working directory
MATCHING_DOMAINS=$(jq -r --arg cwd "$CWD" '
  [.rules[] | . as $rule | try (if ($cwd | test($rule.path_pattern)) then $rule.domains[] else empty end) catch empty] | unique[]
' "$DOMAIN_MAP" 2>/dev/null || true)

# Exit if no matching domains
if [ -z "$MATCHING_DOMAINS" ]; then
  echo '{}'
  exit 0
fi

CONTEXT=""

# --- Level 1: Friction stats from SQLite ---
if [ -f "$DB" ] && command -v sqlite3 &>/dev/null; then
  while IFS= read -r domain; do
    STATS=$(sqlite3 "$DB" "
      SELECT COUNT(*) AS total,
             SUM(CASE WHEN date >= date('now','-30 days') THEN 1 ELSE 0 END) AS last_30d,
             SUM(CASE WHEN constraint_failed = 1 THEN 1 ELSE 0 END) AS failures
      FROM friction f
      JOIN friction_domain fd ON f.id = fd.friction_id
      WHERE fd.domain = '${domain}';
    " 2>/dev/null || true)

    if [ -n "$STATS" ] && [ "$STATS" != "0|0|0" ]; then
      IFS='|' read -r total last30 failures <<< "$STATS"
      # Only inject if there's actual data
      if [ "${total:-0}" -gt 0 ]; then
        CONTEXT="${CONTEXT}

## Friction: ${domain}
- ${total} total (${last30} in last 30 days, ${failures} constraint failures)"

        # Top friction type for this domain
        TOP_TYPE=$(sqlite3 "$DB" "
          SELECT f.type || ' (' || COUNT(*) || 'x)'
          FROM friction f
          JOIN friction_domain fd ON f.id = fd.friction_id
          WHERE fd.domain = '${domain}'
          GROUP BY f.type
          ORDER BY COUNT(*) DESC LIMIT 1;
        " 2>/dev/null || true)
        [ -n "$TOP_TYPE" ] && CONTEXT="${CONTEXT}
- Top type: ${TOP_TYPE}"
      fi
    fi
  done <<< "$MATCHING_DOMAINS"
fi

# --- Level 2: Domain knowledge files ---
while IFS= read -r domain; do
  DOMAIN_FILE="${DOMAINS_DIR}/${domain}.md"
  if [ -f "$DOMAIN_FILE" ]; then
    CONTENT=$(cat "$DOMAIN_FILE")
    if [ -n "$CONTENT" ]; then
      CONTEXT="${CONTEXT}

## Domain: ${domain}
${CONTENT}"
    fi
  fi
done <<< "$MATCHING_DOMAINS"

# Exit if nothing to inject
if [ -z "$CONTEXT" ]; then
  echo '{}'
  exit 0
fi

HEADER="# Active Domain Context
Domain-specific patterns and friction stats loaded based on your current project."

jq -n --arg ctx "${HEADER}
${CONTEXT}" '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": $ctx
  }
}'
