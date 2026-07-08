#!/usr/bin/env bash
# Smoke tests for grounding-gate.sh — deterministic stdin -> verdict cases.
# Golden cases come from the real FM-1 incidents in friction/rage-log.md
# (lp-ssr "DID YOU EVEN RAN TEST" 2026-06-26; crm-connect-data "I just
# checked" wrong-directory 2026-07-07).
#
# Usage: ./test-grounding-gate.sh    # exits non-zero on any failure

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GATE="$SCRIPT_DIR/grounding-gate.sh"
TMP=$(mktemp -d /tmp/gg-test-XXXXXX)
trap 'rm -rf "$TMP"' EXIT
export GROUNDING_GATE_LEDGER="$TMP/ledger.jsonl"

PASS=0; FAIL=0

# build_transcript <path> [test_ok|test_err|build_ok|none|lsonly]
build_transcript() {
  local path="$1" kind="$2"
  {
    printf '%s\n' '{"type":"user","message":{"content":"please do the thing"}}'
    case "$kind" in
      test_ok)
        printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"pnpm test"}}]}}'
        printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","is_error":false}]},"toolUseResult":{"stdout":"12 passed","stderr":"","interrupted":false}}'
        ;;
      test_err)
        printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"pnpm test"}}]}}'
        printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","is_error":true}]},"toolUseResult":"Error: 3 failed"}'
        ;;
      build_ok)
        printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"pnpm run build"}}]}}'
        printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","is_error":false}]},"toolUseResult":{"stdout":"built","stderr":"","interrupted":false}}'
        ;;
      lsonly)
        printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t1","name":"Bash","input":{"command":"ls -la src/"}}]}}'
        printf '%s\n' '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t1","is_error":false}]},"toolUseResult":{"stdout":"files","stderr":"","interrupted":false}}'
        ;;
      none) ;;
    esac
  } > "$path"
}

# run_case <name> <expect: block|allow> <final_text> <transcript_kind> [stop_hook_active]
run_case() {
  local name="$1" expect="$2" text="$3" kind="$4" active="${5:-false}"
  local tp="$TMP/$name.jsonl"
  build_transcript "$tp" "$kind"
  local out
  out=$(jq -n --arg t "$text" --arg tp "$tp" --argjson a "$active" \
    '{stop_hook_active: $a, transcript_path: $tp, assistant_message: {content: [{type:"text", text:$t}]}}' \
    | "$GATE")
  local got="allow"
  printf '%s' "$out" | grep -q '"decision"' && got="block"
  if [ "$got" = "$expect" ]; then
    PASS=$((PASS+1)); echo "  PASS: $name"
  else
    FAIL=$((FAIL+1)); echo "  FAIL: $name (expected $expect, got $got)"; echo "        out: ${out:0:200}"
  fi
}

echo "grounding-gate smoke tests"
echo "--------------------------"

# ── Class A: evidence-required claims ───────────────────────────────────────
run_case "tests-pass-no-run"      block "Done. All tests pass and the change is committed." none
run_case "tests-pass-with-run"    allow "Done. All tests pass and the change is committed." test_ok
run_case "tests-pass-failed-run"  block "Done. All tests pass and the change is committed." test_err
run_case "ran-tests-no-run"       block "I ran the tests and everything looks good." none
run_case "build-pass-with-build"  allow "The build succeeds after the fix." build_ok
run_case "build-pass-no-build"    block "The build succeeds after the fix." none
run_case "measured-no-cmds"       block "I measured the response time at 120ms." none
run_case "measured-any-cmd"       allow "I measured the response time at 120ms." lsonly

# ── Class B: citation-required state assertions (crm-connect-data golden) ───
run_case "checked-uncited"        block "I just checked: this repo's only configured remote is crm, a plain local directory with no remotes." none
run_case "checked-cited-gitc"     allow "I checked with git -C /Users/scott/Projects/x remote -v: the only remote is crm." none
run_case "checked-cited-backtick" allow 'I verified via `cat package.json` that the script exists.' none

# ── Guards: future/conditional intent must not fire ─────────────────────────
run_case "future-tense"           allow "Let me run the tests to confirm the fix works." none
run_case "make-sure-guard"        allow "Please make sure the tests pass before merging." none
run_case "will-verify-guard"      allow "Next I will run the tests and report back." none

# ── Quoting / code is not asserting ─────────────────────────────────────────
run_case "quoted-discussion"      allow 'The gate matches the "tests pass" phrasing in prose.' none
run_case "code-span"              allow 'Add `npm test` so CI fails when tests break; I have not run it here.' none

# ── Release + fail-open ─────────────────────────────────────────────────────
run_case "stop-hook-active"       allow "All tests pass, trust me." none true

echo -n "  "
if printf '%s' "garbage-not-json" | "$GATE" >/dev/null 2>&1; then
  PASS=$((PASS+1)); echo "PASS: garbage-stdin-fail-open"
else
  FAIL=$((FAIL+1)); echo "FAIL: garbage-stdin-fail-open (non-zero exit)"
fi

# ── Ledger got stage-2 entries ──────────────────────────────────────────────
echo -n "  "
if [ -s "$GROUNDING_GATE_LEDGER" ] && grep -q '"verdict"' "$GROUNDING_GATE_LEDGER"; then
  PASS=$((PASS+1)); echo "PASS: ledger-written ($(wc -l < "$GROUNDING_GATE_LEDGER" | tr -d ' ') entries)"
else
  FAIL=$((FAIL+1)); echo "FAIL: ledger-written (no entries at $GROUNDING_GATE_LEDGER)"
fi

echo "--------------------------"
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
