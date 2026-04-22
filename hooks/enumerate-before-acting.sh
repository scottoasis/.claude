#!/usr/bin/env bash
# UserPromptSubmit hook: inject invariants + delta + context reminder.
# Fires on every user message. Lightweight context injection.
# Replaces the prior "list 3 options, pick cheapest viable" framing, which
# degenerated into theater (strawman option #1, goldilocks option #2).
# New framing: name what must stay true, check what's already known, and
# for each planned step ask whether skipping it would change the answer.
# Explicit bypass for small tasks to avoid forcing ritual on trivial prompts.

set -uo pipefail

jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "BEFORE ACTING: Name the invariants — what must stay true for the output to be correct, regardless of approach? What is already known from context vs. needs verifying? For each step you are about to take, ask: would skipping it change the answer? If no, cut it. If the task is small and the path is obvious, say \"small, proceeding\" and skip the rest."
  }
}'
