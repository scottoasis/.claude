#!/usr/bin/env bash
# PreToolUse hook for Bash: emit permission decisions for git commands in
# both direct (`git <cmd>`) and `-C <path>` forms.
#
# Claude Code's permission matcher only honors trailing `*` wildcards, so
# rules like `Bash(git -C * log:*)` in settings.json are literal (dead) —
# the `-C` form needs a hook. The direct form is also handled here so that
# deny/ask decisions can carry a concrete recovery instruction; bare
# settings.json denies surface only "Permission ... has been denied."

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

# Match either `git -C <path> <rest>` or plain `git <rest>`. We need the
# direct form too so deny/ask decisions carry a useful reason — bare
# settings.json denies surface only "Permission ... has been denied."
if [[ "$COMMAND" =~ ^[[:space:]]*git[[:space:]]+-C[[:space:]]+[^[:space:]]+[[:space:]]+(.+)$ ]]; then
  REST="${BASH_REMATCH[1]}"
elif [[ "$COMMAND" =~ ^[[:space:]]*git[[:space:]]+(.+)$ ]]; then
  REST="${BASH_REMATCH[1]}"
else
  exit 0
fi

emit() {
  jq -cn --arg d "$1" --arg r "$2" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}'
  exit 0
}

# DENY (most restrictive, check first).
if [[ "$REST" =~ ^merge([[:space:]]|$) ]]; then
  # Parse the first non-flag token after `merge` as the target branch.
  TARGET=""
  read -r -a _ARGS <<<"$REST"
  for ((i=1; i<${#_ARGS[@]}; i++)); do
    tok="${_ARGS[i]}"
    case "$tok" in
      -*) continue ;;
      *)  TARGET="$tok"; break ;;
    esac
  done
  if [ -n "$TARGET" ]; then
    emit "deny" "git merge is blocked. To bring ${TARGET}'s commits onto the current branch: 'git rebase ${TARGET}'. To fast-forward ${TARGET} to the current branch instead: 'git switch ${TARGET} && git rebase -' (then 'git switch -' to return). For PR integration: push and merge via the PR UI."
  else
    emit "deny" "git merge is blocked. Use 'git rebase <branch>' to bring <branch>'s commits onto the current branch, or 'git pull --rebase' to update from upstream. For PR integration: push and merge via the PR UI."
  fi
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
