#!/usr/bin/env bash
# Domain context injection hook for Claude Code
# Progressive disclosure levels:
#   Level 0: CLAUDE.md (always loaded by Claude Code, not this hook)
#   Level 1: Domain friction stats from JSONL (2-3 lines per domain)
#   Level 2: Domain knowledge files from domains/*.md
# Configure as UserPromptSubmit hook in ~/.claude/settings.json

set -uo pipefail

FRICTION_DIR="${HOME}/.claude/friction"
DOMAIN_MAP="${FRICTION_DIR}/domain-map.json"
DOMAINS_DIR="${FRICTION_DIR}/domains"
LEDGER="${FRICTION_DIR}/friction.jsonl"

# Read hook input from stdin
INPUT=$(cat)
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)

# Exit silently if no CWD, no domain map, or no jq
if [ -z "$CWD" ] || [ ! -f "$DOMAIN_MAP" ] || ! command -v jq &>/dev/null; then
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

# --- Level 1: Friction stats from JSONL ---
if [ -f "$LEDGER" ]; then
  CUTOFF_30D=$(date -v-30d +%Y-%m-%d 2>/dev/null || date -d "-30 days" +%Y-%m-%d)
  while IFS= read -r domain; do
    DOMAIN_STATS=$(jq -s --arg d "$domain" --arg cutoff "$CUTOFF_30D" '
      [.[] | select((.domains // [])[] == $d)] |
      if length == 0 then empty else
        {
          total: length,
          last_30d: [.[] | select(.date >= $cutoff)] | length,
          failures: [.[] | select(.constraint_failed == 1)] | length,
          top_type: (group_by(.type) | sort_by(length) | reverse | .[0] | "\(.[0].type) (\(length)x)")
        }
      end
    ' "$LEDGER" 2>/dev/null || true)

    if [ -n "$DOMAIN_STATS" ]; then
      total=$(echo "$DOMAIN_STATS" | jq -r '.total')
      last30=$(echo "$DOMAIN_STATS" | jq -r '.last_30d')
      failures=$(echo "$DOMAIN_STATS" | jq -r '.failures')
      top_type=$(echo "$DOMAIN_STATS" | jq -r '.top_type')
      CONTEXT="${CONTEXT}

## Friction: ${domain}
- ${total} total (${last30} in last 30 days, ${failures} constraint failures)
- Top type: ${top_type}"
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
