#!/usr/bin/env bash
# PreToolUse hook: gate Agent tool calls with a lightweight cost check.
# Injects context reminding Claude to consider simpler alternatives before
# delegating to an Agent/Explore subagent.
#
# Does NOT block — just adds advisory context so the model can self-correct.

set -uo pipefail

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty' 2>/dev/null || true)
SUBAGENT=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // "general-purpose"' 2>/dev/null || true)

# Only gate Explore and general-purpose agents (the ones used for research/search)
case "$SUBAGENT" in
  Explore|general-purpose) ;;
  *) echo '{}'; exit 0 ;;
esac

# Check if the prompt mentions reading a specific known file
# (signals the task is directed, not exploratory)
if echo "$PROMPT" | grep -qiE '(README|CHANGELOG|CLAUDE\.md|package\.json|Cargo\.toml|setup|config)'; then
  HINT="The prompt references a specific file. Can you Read it directly instead of delegating?"
else
  HINT="Before delegating, check: is the answer derivable from context you already have (git status, conversation history, working directory)? Could Read, Glob, or Grep handle this in one call?"
fi

jq -n --arg ctx "AGENT GATE: $HINT

Enumerate your options before proceeding:
1. Derive from existing context (effort: none, risk: none)
2. Read/Glob/Grep directly (effort: one tool call, risk: minimal)
3. Ask the user (effort: one round trip, risk: none)
4. Launch Agent (effort: 30s+, risk: agent goes off-script)

Pick the cheapest viable option. Only proceed with Agent if 1-3 genuinely can't work." '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": $ctx
  }
}'
