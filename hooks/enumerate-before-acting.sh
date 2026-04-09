#!/usr/bin/env bash
# UserPromptSubmit hook: inject "enumerate before acting" heuristic.
# Fires on every user message. Lightweight context injection (~100 tokens).
# The model ignores it for simple questions; it activates for action requests.

set -uo pipefail

jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "BEFORE ACTING: Pause. What are your options? List them with effort and risk. Pick the cheapest viable one. Check what you already know from context before reaching for tools."
  }
}'
