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

# Extract the header: first non-empty line of the *first* -m / --message
# value. The value may be a plain quoted string or a "$(cat <<EOF ...)"
# heredoc; a later -m (e.g. the body) must not be read as the header.
HEADER=$(printf '%s' "$COMMAND" | perl -0777 -ne '
  # Isolate the first message flag and everything after it.
  next unless /(?:^|\s)(?:-[a-z]*m|--message)(?:=|\s+)(.*)$/s;
  my $rest = $1;
  # Heredoc value: -m "$(cat <<EOF\nHEADER\n...EOF)"
  if ($rest =~ /^["\x27]?\$\(\s*cat\s*<<-?\s*["\x27]?(\w+)["\x27]?[^\n]*\n([^\n]*)/s) {
    my $h = $2; $h =~ s/^\s+|\s+$//g;
    print "$h\n" if length $h;
    exit 0;
  }
  # Plain quoted value: -m "msg" / -am "msg" / --message="msg"
  if ($rest =~ /^(["\x27])((?:\\.|(?!\1).)*?)\1/s) {
    my $m = $2; $m =~ s/\n.*//s; $m =~ s/^\s+|\s+$//g;
    print "$m\n" if length $m;
    exit 0;
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
