#!/usr/bin/env bash
# PreToolUse hook for Bash: emit permission decisions for `git -C <path> <cmd>`.
#
# Claude Code's permission matcher only honors trailing `*` wildcards, so
# rules like `Bash(git -C * log:*)` in settings.json are literal (dead).
# This hook parses the `-C` form and emits the same allow/ask/deny decisions
# that the direct-form rules already encode.
#
# Direct-form commands (`git log`, `git add`, etc.) are matched by the
# permission rules in .claude/settings.json — this hook only handles the
# `git -C <path> ...` form and passes everything else through.

set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -z "$COMMAND" ] && exit 0

# Only decide for plain git -C commands. If shell chaining/redirection/
# substitution is present, let Claude Code's settings.json rules handle the
# full command string rather than risk allowing a dangerous tail.
case "$COMMAND" in
  *'&&'*|*'||'*|*';'*|*'|'*|*'>'*|*'<'*|*'`'*|*'$('*) exit 0 ;;
esac

# Match: optional ws, git, ws, -C, ws, path-token (unquoted), ws, rest.
# Quoted paths with spaces fall through to default prompting.
if ! [[ "$COMMAND" =~ ^[[:space:]]*git[[:space:]]+-C[[:space:]]+[^[:space:]]+[[:space:]]+(.+)$ ]]; then
  exit 0
fi
REST="${BASH_REMATCH[1]}"

emit() {
  jq -cn --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

# DENY (most restrictive, check first).
if [[ "$REST" =~ ^merge([[:space:]]|$) ]]; then
  emit "deny" "git merge is blocked here (use rebase or pull --rebase)"
fi

# ASK (check before ALLOW so `worktree remove` wins over the `worktree` allow).
if [[ "$REST" =~ ^worktree[[:space:]]+remove([[:space:]]|$) ]]; then
  emit "ask" "git worktree remove is destructive"
fi
if [[ "$REST" =~ ^rm([[:space:]]|$) ]]; then
  emit "ask" "git rm is destructive"
fi
if [[ "$REST" =~ ^reset[[:space:]]+--hard([[:space:]]|$) ]]; then
  emit "ask" "git reset --hard discards changes"
fi
if [[ "$REST" =~ ^push([[:space:]]|$) ]]; then
  emit "ask" "git push is visible to others"
fi

# ALLOW.
if [[ "$REST" =~ ^worktree[[:space:]]+(add|list|move|prune|lock|unlock|repair)([[:space:]]|$) ]]; then
  emit "allow" "git worktree ${BASH_REMATCH[1]} is safe"
fi
if [[ "$REST" =~ ^(add|commit|stash)([[:space:]]|$) ]]; then
  emit "allow" "git ${BASH_REMATCH[1]} is safe"
fi
if [[ "$REST" =~ ^(log|reflog|show|status|diff|blame|ls-files|ls-tree|ls-remote|rev-parse|rev-list|check-ignore|describe|shortlog|cat-file)([[:space:]]|$) ]]; then
  emit "allow" "git ${BASH_REMATCH[1]} is read-only"
fi

# Not in curated table; let Claude Code prompt by default.
exit 0
