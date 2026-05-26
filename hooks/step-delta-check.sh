#!/usr/bin/env bash
# PreToolUse hook: per-step delta + invariant + principle-tower check for Write/Edit.
# Fires before every file mutation. Advisory only — does not block.
#
# Paired with hooks/enumerate-before-acting.sh (UserPromptSubmit). That hook
# asks for invariants/delta/goal at the start of a task; this hook re-asks
# the delta question at the moment of each material step, so the discipline
# survives into the middle of a task instead of decaying after the first
# tool call.
#
# Principle-tower layer (since 2026-05-26): if the edit is justified by a
# named theory (DDD, SOLID, leaky, façade, onion), check that the same
# decision derives from the user's actual goal. Targets stacked-dogma and
# wrong-taxonomy-import failure modes. See
# friction/domains/reasoning-discipline.md.
#
# Deliberately narrow scope: Write/Edit only. Bash already has multiple
# gates stacked, and read-only tool calls are rarely the ritual-work
# culprit. Widen later if friction recurs on other tool types.

set -uo pipefail

jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "additionalContext": "STEP CHECK: Would skipping this edit change the outcome of the task? If no, cut it. Does the change respect the invariants you named upfront — and did you name them? PRINCIPLE CHECK: If this edit is justified by a named principle (DDD, SOLID, leaky, façade, onion), can you also derive it from the user'\''s actual goal? If goal-derivation and principle-derivation agree, fine. If not, the principles are wrong here — drop them and re-derive from the goal. If the edit is small and obvious, proceed silently."
  }
}'
