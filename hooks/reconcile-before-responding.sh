#!/usr/bin/env bash
# UserPromptSubmit hook: reconcile goal, invariants, and latest-message delta.
# Fires on every user message. Advisory only; the visible response contract
# lives in ~/.claude/CLAUDE.md.
#
# This restores the load-bearing part of the retired
# enumerate-before-acting.sh hook: a GOAL restatement must be checked against
# user-derived invariants and the latest correction, not generated from the
# agent's existing plan or an automated summary.

set -uo pipefail

jq -n '{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "STATE RECONCILIATION — before any substantive response or action: (1) Bind ambiguous/deictic terms and entities from the latest user message (for example HERE, server, client, target). Prefer the latest explicit user binding over prior plans and automated summaries. (2) Restate the user'\''s actual goal. (3) List user-derived invariants separately from observations, hypotheses, and environmental conditions. (4) Identify the DELTA: exactly what the latest message changes, corrects, excludes, or leaves unchanged. (5) Apply a causal-relevance gate: would each carried-forward fact change the decision or question currently being answered? If not, omit it from the justification. (6) If the latest correction conflicts with the current plan, discard the plan-derived inference while preserving unrelated explicit constraints. A GOAL line alone is not evidence that this reconciliation happened. For a correction, disambiguation, or scope/location instruction, expose concise INVARIANTS and DELTA lines as required by CLAUDE.md."
  }
}'
