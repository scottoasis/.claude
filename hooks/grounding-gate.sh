#!/usr/bin/env bash
# Stop hook: grounding-gate — block confident verification claims that the
# turn's tool history does not back. Mirror-image of hedge-gate.sh: that gate
# catches guesses that SOUND like guesses ("likely", "probably"); this one
# catches guesses that SOUND like facts ("tests pass", "I just checked").
#
# Why: the two worst trust ruptures in friction/rage-log.md (FM-1) shipped
# maximally confident prose with no or wrong evidence — "I just checked: this
# repo's only remote is …" run in the wrong directory (2026-07-07), and
# measured-sounding comparisons whose baseline build had failed (2026-06-26).
# Zero hedge words, so hedge-gate was structurally blind to both.
#
# Verdict = f(final prose, THIS TURN's tool calls) — the first hook here whose
# decision cross-references two parts of the transcript instead of one artifact:
#   Class A (evidence-required): test/build/lint/typecheck "passes/ran" claims
#     need a matching Bash command this turn whose tool_result is not is_error
#     and not interrupted. "I measured/benchmarked/profiled" needs any
#     successful Bash command this turn (weak on purpose; see Limits).
#   Class B (citation-required): "I checked/verified/confirmed <state>" needs
#     the claiming sentence to carry WHERE/HOW it was checked — a locator
#     (in/at/from/under/via/with/using + path), `git -C`, or a backticked
#     command. The gate cannot know the RIGHT directory; it forces the claim
#     to be auditable so the reader catches a wrong one instantly.
#
# Survival constraints (from the enumerate-before-acting post-mortem,
# friction/rage-log.md cross-cutting #5):
#   RARE-FIRING — stage 1 is one grep over final prose; no keyword -> exit 0.
#     The transcript walk runs only on a keyword hit.
#   NOT PERFORMABLE — the predicate is a fact in the transcript (a command ran,
#     a sentence carries a path), not a request to reason better.
#   NO PRE-BYPASS — blocks first, always; the reason text's exemption is only
#     reachable in the re-emission. Release is stop_hook_active (harness
#     state), the same bite-once contract as hedge-gate. Note: multiple Stop
#     gates share that release — if hedge-gate blocked this response first,
#     this gate lets the continuation through (bounded total blocking;
#     Claude Code's 3-consecutive-block guard is the backstop).
#   MEASURED, PRE-REGISTERED RETIREMENT — every stage-2 evaluation (pass or
#     block) appends one line to friction/grounding-gate-ledger.jsonl
#     (override: $GROUNDING_GATE_LEDGER). Review at /harness-review. Kill
#     criterion, decided at birth: if the ledger shows stage-2 firing on >5%
#     of turns, or most blocks are false (re-emission unchanged with evidence
#     already present), narrow the wordlists or retire the gate — on ledger
#     data, not accumulated annoyance. Outcome metric: FM-1 recurrence in
#     friction/rage-log.md goes to zero.
#
# Scope: BARE PROSE only (fenced/inline code, "quoted" spans, >-blockquotes
# stripped, same as hedge-gate) and PAST/PERFECT claims only — "let me run the
# tests", "make sure tests pass" never fire (guard window of intent/condition
# words before the claim).
#
# Limits (documented, not hidden): a lexical gate is a tripwire, not a fence.
# It targets the NEGLIGENT default phrasing of unverified claims — both FM-1
# flagships used it — not adversarial rephrasing ("the suite is green-ish");
# dodge phrasings observed in the rage log get appended to the wordlists, the
# same way hedge-gate grew its honesty-frame pattern. Sidechain (subagent)
# entries are excluded from the turn walk, so evidence produced inside an
# Agent call is invisible — the re-emission's citation covers that case.
# "Measured" claims accept any successful command, so half-grounded
# comparisons (the lp-ssr baseline case) pass Class A; Class B's citation
# demand is the partial cover.
#
# Transcript shapes verified against live sessions 2026-07-08: real user
# prompts have string message.content; Bash tool_use at
# message.content[].{type:"tool_use",name:"Bash",input.command}; results at
# user-entry message.content[].{type:"tool_result",is_error} with top-level
# toolUseResult {stdout,stderr,interrupted} (dict on success, "Error: …"
# string on tool-level failure).
#
# Fail-open: any read/parse failure exits 0 (allow) — same rationale as
# hedge-gate: a gate that fails closed on its own bug bricks every response.

set -uo pipefail

INPUT=$(cat)

has_text() { printf '%s' "${1:-}" | grep -q '[^[:space:]]'; }

# ── Release after the one forced reconsideration ────────────────────────────
ACTIVE=$(printf '%s' "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
[ "$ACTIVE" = "true" ] && exit 0

# ── Final assistant prose (stdin message, transcript fallback) ──────────────
TEXT=$(printf '%s' "$INPUT" | jq -r '
  (.assistant_message.content // [])
  | map(select(.type == "text") | .text) | join("\n")
' 2>/dev/null || true)

TP=$(printf '%s' "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)

if ! has_text "$TEXT"; then
  if [ -n "$TP" ] && [ -f "$TP" ]; then
    TEXT=$(grep '"type":"assistant"' "$TP" 2>/dev/null | tail -1 \
      | jq -r '(.message.content // []) | map(select(.type == "text") | .text) | join("\n")' 2>/dev/null || true)
  fi
fi

has_text "$TEXT" || exit 0

# ── Stage 1: cheap keyword pre-check — most turns exit here ─────────────────
# Coarse on purpose (matches "password" etc.) — stage 2 is the precise layer;
# \b is avoided for BSD-grep portability.
printf '%s' "$TEXT" | grep -qiE \
  'pass|green|succeed|compil| ran |re-ran|measured|benchmarked|profiled|checked|verified|confirmed' \
  || exit 0

# ── Stage 2: claim detection + turn-evidence walk ───────────────────────────
OUT=$(GG_TEXT="$TEXT" GG_TRANSCRIPT="${TP:-}" \
      GG_LEDGER="${GROUNDING_GATE_LEDGER:-/Users/scott/.claude/friction/grounding-gate-ledger.jsonl}" \
      python3 - <<'PY' 2>/dev/null
import json, os, re, sys, datetime

text = os.environ.get("GG_TEXT", "")
tp = os.environ.get("GG_TRANSCRIPT", "")
ledger = os.environ.get("GG_LEDGER", "")

# ── Strip non-assertive regions (mirror hedge-gate): quoting != asserting ──
def strip_prose(t):
    t = re.sub(r"```.*?```", " ", t, flags=re.S)   # fenced code
    t = re.sub(r"`[^`]*`", " ", t)                 # inline code
    t = re.sub(r'"[^"]*"', " ", t)                 # double-quoted spans
    t = re.sub(r"^\s*>.*$", " ", t, flags=re.M)    # blockquotes
    return t

stripped = strip_prose(text)

# Words in the window before a claim that mark intent/condition, not assertion.
GUARD = re.compile(
    r"\b(if|when|until|unless|once|whether|ensure|ensuring|make sure|making sure|"
    r"so that|should|will|would|could|might|going to|let me|let's|about to|"
    r"plan(s|ning)? to|want(s)? to|need(s)? to|to see if|to check|to confirm|"
    r"before|after you|assuming|verify that|check that|expect(s|ing)?)\b[^.!?\n]*$",
    re.I)

def guarded(m, hay):
    window = hay[max(0, m.start() - 60):m.start()]
    return bool(GUARD.search(window))

CLASS_A = [
    ("tests-pass", re.compile(
        r"\b(?:all\s+)?(?:the\s+)?(?:\d+\s+)?tests?\s+(?:now\s+|all\s+|still\s+)*"
        r"(?:pass(?:es|ed)?|are\s+(?:passing|green)|went\s+green)\b", re.I), "test"),
    ("suite-pass", re.compile(
        r"\b(?:test\s+suite|suite|specs?)\s+(?:passes|passed|is\s+green)\b", re.I), "test"),
    ("ran-tests", re.compile(
        r"\b(?:I|we)\s+(?:just\s+|then\s+)?(?:re-?)?ran\s+(?:the\s+)?"
        r"(?:tests?|suite|specs?|typecheck|linter|lint|build)\b", re.I), "test"),
    ("check-pass", re.compile(
        r"\b(?:typecheck|lint(?:er)?)\s+(?:passes|passed|succeeds|succeeded|is\s+clean)\b", re.I), "test"),
    ("build-pass", re.compile(
        r"\bbuild\s+(?:succeeds|succeeded|passes|passed|compiles|works)\b", re.I), "build"),
    ("measured", re.compile(
        r"\b(?:I|we)\s+(?:just\s+)?(?:measured|benchmarked|profiled)\b", re.I), "any"),
]
CLASS_B = re.compile(
    r"\b(?:I|we)\s+(?:just\s+|also\s+|double-?)?(?:checked|verified|confirmed)\b", re.I)

TEST_EVID = re.compile(
    r"(?:\b(?:npm|pnpm|yarn|bun)\s+(?:run\s+)?test\b|pytest|vitest|jest\b|"
    r"\bgo\s+test\b|cargo\s+test|rspec|phpunit|mix\s+test|make\s+test|"
    r"\btsc\b|typecheck|eslint|ruff\b|mypy|uv\s+run\s+pytest|"
    r"(?:bash|sh|\./)\S*test\S*\.sh)", re.I)
BUILD_EVID = re.compile(
    r"(?:\b(?:npm|pnpm|yarn|bun)\s+(?:run\s+)?build\b|next\s+build|vite\s+build|"
    r"cargo\s+build|go\s+build|docker\s+build|turbo\s+(?:run\s+)?build|"
    r"\bmake\b(?!\s+test)|\btsc\b)", re.I)
LOCATOR = re.compile(
    r"(?:\b(?:in|at|from|under|via|with|using)\s+\S*[/`~])|(?:\bgit\s+-C\b)|"
    r"(?:\bcwd\b)|(?:`[^`]+`)")

a_claims = []
for name, pat, need in CLASS_A:
    for m in pat.finditer(stripped):
        if not guarded(m, stripped):
            a_claims.append((name, m.group(0).strip(), need))
            break  # one instance per claim type is enough

b_claims = []
for m in CLASS_B.finditer(stripped):
    if guarded(m, stripped):
        continue
    phrase = m.group(0)
    # Find the claiming sentence in the ORIGINAL text (citations may live in
    # backticks, which strip_prose removes).
    pos = text.lower().find(phrase.lower())
    if pos < 0:
        continue
    start = max(text.rfind(ch, 0, pos) for ch in ".!?\n")
    endc = [text.find(ch, pos) for ch in ".!?\n"]
    endc = [e for e in endc if e >= 0]
    end = min(endc) if endc else len(text)
    sentence = text[start + 1:end].strip()
    if not LOCATOR.search(sentence):
        b_claims.append(sentence[:160])

if not a_claims and not b_claims:
    sys.exit(0)

# ── Walk THIS TURN's tool history (only needed for Class A) ─────────────────
def turn_commands(path):
    """Successful Bash commands since the last real user prompt (main chain)."""
    try:
        lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    except OSError:
        return None
    uses, results, turn = {}, {}, []
    for line in reversed(lines):
        try:
            obj = json.loads(line)
        except (json.JSONDecodeError, ValueError):
            continue
        if obj.get("isSidechain"):
            continue
        t = obj.get("type")
        msg = obj.get("message") or {}
        content = msg.get("content")
        if t == "user":
            if isinstance(content, str) and content.strip():
                break  # boundary: the real user prompt that opened this turn
            if isinstance(content, list):
                items = [i for i in content if isinstance(i, dict)]
                if any(i.get("type") == "text" for i in items) and \
                   not any(i.get("type") == "tool_result" for i in items):
                    break  # boundary (array-shaped user prompt)
                for i in items:
                    if i.get("type") == "tool_result":
                        tur = obj.get("toolUseResult")
                        interrupted = isinstance(tur, dict) and tur.get("interrupted")
                        results[i.get("tool_use_id")] = {
                            "ok": not i.get("is_error") and not interrupted}
        elif t == "assistant" and isinstance(content, list):
            for i in content:
                if isinstance(i, dict) and i.get("type") == "tool_use" and i.get("name") == "Bash":
                    uses[i.get("id")] = (i.get("input") or {}).get("command", "")
    for uid, cmd in uses.items():
        if results.get(uid, {}).get("ok"):
            turn.append(cmd)
    return turn

unbacked = []
cmds = None
if a_claims:
    cmds = turn_commands(tp) if tp and os.path.isfile(tp) else None
    if cmds is not None:  # unreadable transcript -> fail-open on Class A
        for name, phrase, need in a_claims:
            evid = {"test": TEST_EVID, "build": BUILD_EVID}.get(need)
            ok = any(evid.search(c) for c in cmds) if evid else bool(cmds)
            if not ok:
                unbacked.append((name, phrase, need))

# ── Ledger: every stage-2 evaluation, pass or block ─────────────────────────
try:
    with open(ledger, "a", encoding="utf-8") as f:
        f.write(json.dumps({
            "ts": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "verdict": "block" if (unbacked or b_claims) else "pass",
            "a_claims": [c[0] for c in a_claims],
            "a_unbacked": [c[0] for c in unbacked],
            "b_uncited": len(b_claims),
            "turn_cmds": len(cmds) if cmds is not None else None,
        }) + "\n")
except OSError:
    pass

if not unbacked and not b_claims:
    sys.exit(0)

parts = []
if unbacked:
    claims = "; ".join(f'"{p}"' for _, p, _ in unbacked)
    parts.append(
        f"UNBACKED VERIFICATION CLAIM: {claims} — no matching successful command ran this turn. "
        f"Run the verification now and let its output ground the claim, or restate it as "
        f"not-yet-verified naming the exact command the reader should run.")
if b_claims:
    sents = " | ".join(f'"{s}"' for s in b_claims[:2])
    parts.append(
        f"UNCITED STATE ASSERTION: {sents} — says checked/verified/confirmed without saying "
        f"where or how. Re-state it carrying its evidence: the absolute path or exact command "
        f"(e.g. git -C <path> …) it was checked with, so a wrong target is visible to the reader.")
parts.append(
    "GROUNDING GATE (fires once): if a flagged claim is in fact already backed by evidence "
    "visible earlier in this response, re-emit unchanged with that evidence cited inline.")
print(json.dumps({"decision": "block", "reason": " ".join(parts)}))
PY
) || exit 0

[ -n "$OUT" ] && printf '%s\n' "$OUT"
exit 0
