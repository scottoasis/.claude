#!/usr/bin/env bash
# PreToolUse hook: block 'rm' in Bash commands, enforce 'trash' instead.
# Exits non-zero with a reason to BLOCK the tool call when rm is detected.

set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)

[ -z "$COMMAND" ] && exit 0

# Strip quoted strings and comments to avoid false positives on data containing 'rm'
STRIPPED=$(echo "$COMMAND" | sed -E "s/'[^']*'//g; s/\"[^\"]*\"//g; s/#.*$//g")

# Match rm as a command: after start-of-line, command separator, sudo, or command builtin
if echo "$STRIPPED" | grep -qE '(^|[;&|]\s*|sudo\s+|command\s+)\brm\b'; then
  echo "BLOCKED: Use 'trash' instead of 'rm'. The trash command sends files to macOS Trash instead of permanent deletion. Rewrite the command replacing 'rm' (and any flags like -rf) with 'trash'." >&2
  exit 2
fi

exit 0
