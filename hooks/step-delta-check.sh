#!/usr/bin/env bash
# PreToolUse hook: per-step delta + invariant check for Write/Edit.
# Fires before every file mutation. Advisory only — does not block.
#
# Paired with hooks/enumerate-before-acting.sh (UserPromptSubmit). That hook
# asks for invariants and delta analysis once at the start of a task; this
# hook re-asks the delta question at the moment of each material step, so
# the discipline survives into the middle of a task instead of decaying after
# the first tool call.
#
# Deliberately narrow scope: Write/Edit only. Bash already has multiple
# gates stacked, and read-only tool calls are rarely the ritual-work
# culprit. Widen later if friction recurs on other tool types.

set -uo pipefail

jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "STEP CHECK: Would skipping this edit change the outcome of the task? If no, cut it. Does the change respect the invariants you named upfront — and did you name them? If the edit is small and obvious, proceed silently."
  }
}'
