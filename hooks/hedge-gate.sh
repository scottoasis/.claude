#!/usr/bin/env bash
# Stop hook: gate ungrounded hedging in the assistant's FINAL prose.
#
# Why: a hedge about checkable state ("the .env likely points elsewhere",
# "DATABASE_URL should be the staging string") is a guess shipped in place of a
# one-line verification. The rule "treat likely/probably/should-be as a hard
# stop — verify or restate" kept failing as advisory text, so it is escalated
# to a structural gate (the 2+-advisory-failures -> hook path).
#
# Enforcement: BLOCK ONCE, then release. The first natural stop with a hedge is
# blocked with a verify-or-restate reason; the continuation's stop carries
# stop_hook_active=true and is allowed through (exactly one forced
# reconsideration). Claude Code's hard 3-consecutive-block guard is the deadlock
# backstop if that flag ever behaves differently than documented.
#
# Scope: the broader epistemic-hedge family, matched only in BARE PROSE. Fenced
# code, inline code, "double-quoted" spans, and >-blockquoted user text are
# stripped first, so quoting a hedge word to DISCUSS it (as this very file's
# docs do) never fires — only asserting one does.
#
# Fail-open: any read/parse failure exits 0 (allow). A gate that fails closed on
# its own bug would brick every response; the cost of a missed hedge is one
# un-reconsidered guess, far cheaper than a bricked session.

set -uo pipefail

INPUT=$(cat)

has_text() { printf '%s' "${1:-}" | grep -q '[^[:space:]]'; }

# ── Release after the one forced reconsideration ────────────────────────────
# stop_hook_active is true only when this stop is itself a continuation of a
# prior Stop-hook block. Allow it -> the gate bites exactly once per response.
ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
[ "$ACTIVE" = "true" ] && exit 0

# ── Final assistant prose ───────────────────────────────────────────────────
# Prefer the message handed in on stdin; fall back to the last assistant entry
# in the transcript. Transcript shape verified against a live session:
#   {"type":"assistant","message":{"content":[{"type":"text","text":...}, ...]}}
TEXT=$(printf '%s' "$INPUT" | jq -r '
  (.assistant_message.content // [])
  | map(select(.type == "text") | .text) | join("\n")
' 2>/dev/null || true)

if ! has_text "$TEXT"; then
  TP=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
  if [ -n "$TP" ] && [ -f "$TP" ]; then
    TEXT=$(grep '"type":"assistant"' "$TP" 2>/dev/null | tail -1 \
      | jq -r '(.message.content // []) | map(select(.type == "text") | .text) | join("\n")' 2>/dev/null || true)
  fi
fi

# Nothing to scan (pure tool-use turn, unreadable transcript) -> allow.
has_text "$TEXT" || exit 0

# ── Detect bare-prose hedges ────────────────────────────────────────────────
HEDGES=$(printf '%s' "$TEXT" | perl -0777 -ne '
  s/```.*?```//gs;     # fenced code blocks
  s/`[^`]*`//g;        # inline code
  s/"[^"]*"//g;        # double-quoted spans (quoting != asserting)
  s/^\s*>.*$//mg;      # >-blockquoted (quoted-back user text)
  my @pats = (
    ["likely",     qr/\blikely\b/i],
    ["probably",   qr/\bprobably\b/i],
    ["should be",  qr/\bshould\s+be\b/i],
    ["presumably", qr/\bpresumably\b/i],
    ["I think",    qr/\bI\s+think\b/i],
    ["I believe",  qr/\bI\s+believe\b/i],
    ["I assume",   qr/\bI\s+assume\b/i],
    ["my guess",   qr/\bmy\s+guess\b/i],
    ["seems like", qr/\bseems\s+like\b/i],
    ["apparently", qr/\bapparently\b/i],
    ["caveat",     qr/\bcaveats?\b/i],
    ["honestly",   qr/\bhonestly\b/i],
    ["honest framing", qr/\b(?:one|to\s+be|being|in\s+all|in)\s+honest(?:y)?\b/i],
  );
  my @hit;
  for my $p (@pats) { push @hit, $p->[0] if /$p->[1]/; }
  print join(", ", @hit) if @hit;
' 2>/dev/null || true)

[ -z "$HEDGES" ] && exit 0

# ── Block: lead with the recovery action ────────────────────────────────────
REASON="HEDGE GATE — your final response hedges about checkable state: ${HEDGES}. Before stopping, for EACH flagged phrase: (1) VERIFY it now — read the file, query the DB, run the command — and restate it as a grounded fact that cites the evidence; or (2) if it is genuinely not knowable from here, state it as an explicit unknown plus the exact verification path the reader should take, not a soft guess. If a flagged phrase is a deliberate, correct design or sequencing assertion (an invariant, not a guess), keep it and proceed. Re-emit the corrected response — this gate fires only once."

jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
exit 0
