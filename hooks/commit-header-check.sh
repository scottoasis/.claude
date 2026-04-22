#!/usr/bin/env bash
# PreToolUse hook: validate git commit header format on Bash calls.
# Allowed prefixes: feature, infra, fix, chore, deps, docs
# Format: "<prefix>: <subject>" — lowercase, no scope, single ": " separator.
# Blocks the tool call (exit 2) with an explanatory message on mismatch.

set -uo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null || true)
[ -z "$COMMAND" ] && exit 0

# Only inspect `git commit` invocations (allow flags like `git -C path commit`).
if ! echo "$COMMAND" | grep -qE 'git([[:space:]]+-[^[:space:]]+)*[[:space:]]+commit([[:space:]]|$)'; then
  exit 0
fi

# Skip forms where the message comes from elsewhere — we can't validate ahead.
if echo "$COMMAND" | grep -qE '(^|[[:space:]])(-F|--file|-C|--reuse-message|--fixup|--squash)([= ]|$)'; then
  exit 0
fi

# Extract the header: first non-empty line of the first -m / --message value.
HEADER=$(printf '%s' "$COMMAND" | perl -0777 -ne '
  # Heredoc form: -m "$(cat <<EOF\nHEADER\n...EOF)"
  if (/<<-?\s*["\x27]?(\w+)["\x27]?[^\n]*\n([^\n]*)/s) {
    my $h = $2; $h =~ s/^\s+|\s+$//g;
    if (length $h) { print "$h\n"; exit 0; }
  }
  # -m "msg" / -am "msg" / --message="msg" / --message "msg"
  for my $re (
    qr/(?:^|\s)-[a-z]*m(?:=|\s+)(["\x27])((?:\\.|(?!\1).)*?)\1/s,
    qr/(?:^|\s)--message(?:=|\s+)(["\x27])((?:\\.|(?!\1).)*?)\1/s,
  ) {
    if (/$re/) {
      my $m = $2; $m =~ s/\n.*//s; $m =~ s/^\s+|\s+$//g;
      if (length $m) { print "$m\n"; exit 0; }
    }
  }
')

# No message found (editor-based commit, amend --no-edit, etc.) — fail open.
[ -z "$HEADER" ] && exit 0

if echo "$HEADER" | grep -qE '^(feature|infra|fix|chore|deps|docs): .+'; then
  exit 0
fi

cat >&2 <<EOF
BLOCKED: commit header does not match required format.

Got:      $HEADER
Expected: <prefix>: <subject>
Prefixes: feature | infra | fix | chore | deps | docs

Rules:
  - Lowercase prefix, no scope (no parentheses).
  - Exactly one ": " (colon + single space) between prefix and subject.
  - Use 'docs' not 'doc'; 'feature' not 'feat'.

Examples:
  feature: add commit-header validation hook
  fix: correct stale reflections path
  docs: clarify uninstall command
EOF
exit 2
