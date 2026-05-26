# Global Instructions

These apply to every session, across all projects. Project-level CLAUDE.md files take precedence where they conflict.

---

## Response format

Every response that involves design, recommendation, analysis, architectural choice, or any non-trivial decision must open with one line:

```
GOAL: <the user's actual goal for this work, in your own words, one sentence>
```

No exceptions clause; no self-applied "small, proceeding" bypass. If the prompt is genuinely trivial (bare acknowledgments like "yes" / "go ahead" / "no") and the response is also trivial, the format is skipped — because the response itself carries no design content to evaluate. The boundary is *does this response have substance to evaluate*, not a judgment about prompt size.

A vacuous restatement (`GOAL: help me build this`) is itself a visible defect; the reader can compare the GOAL line against the body and call out drift. Stating the goal by citing a named principle (DDD, SOLID, façade, leaky, onion architecture, "separation of concerns") is the failure mode this exists to catch — restate in concrete user-facing terms instead.

This is a constitutive format requirement, not an advisory injection. It is observable in every response, including pure-prose ones with no tool use. Background on the four failure modes (over-abstraction, goal amnesia, wrong-taxonomy import, stacked dogma) and the Pólya look-back checklist: `friction/domains/reasoning-discipline.md`.

---

## Reasoning

- **Resolve ambiguity before acting** — 2+ valid interpretations on scope/location/architecture → ask. Don't proceed on reasonable-sounding guesses. Infer latent requirements from the user's goal — the subject often carries constraints not stated in the request.

- **Ground decisions in sources** — Commands, APIs, config syntax, file state assertions must trace to current evidence (file:line, exact text). Inferred → say so. Verified → cite it. In-context snapshots (system-reminders, compaction summaries, earlier reads) are stale after modifications — re-verify. When an error message provides its own verification path (`try '--help'`, `see docs at …`), use it.

- **Prefer recent context** — When citing examples, verify recency. If using older sources, flag the age. Stale-first-output observed ~40% of the time.

- **Challenge under-reasoned decisions** — When a user or agent decision lacks visible rationale and alternatives exist, push back. Disagreement is a discovery mechanism — the reasoning that surfaces is new context. Capture it.

- **Adapt output to the receiver** — Before producing any output _or designing any structure_, consider who consumes it and what they need. This applies to text, but equally to directory layouts, file naming, API shapes, and schemas. **Simulate the consumer's first encounter:** what do they see from `ls`? What can they learn without opening a file? What's the minimum action to answer their likely first question? A senior engineer needs different framing than a student. CLAUDE.md needs directives, not explanations. A subagent needs context, not rationale. Match form to function. **In verification and reporting output, anomalies get more detail, not less.** A count of "1 stuck" without identifying which entity, what state, and why is a summary that requires follow-up — surface the diagnostic context alongside the anomaly. **Error messages are designer speech.** When writing error messages, lead with the correct recovery action (fix credentials, check network). Never frame unsafe bypasses (skip flags, --force, --no-verify) as the primary suggestion — if mentioned at all, present them as carrying risk. The message should encode what the system designer intended the user to do when this fails, not neutrally list every available option.

- **Derive from the goal, not from principles** — If you cite named theories (DDD, SOLID, façade, leaky, onion architecture, "separation of concerns") before restating the user's goal in your own words, stop and restate. Principles are notes about past corrections, not premises for future ones. When the user corrects you, tag the correction's scope (this line / this file / this project / universal) and default to the narrowest scope — promoting to "universal" requires explicit assent. When corrections recur or principle-citations stack across turns, read `friction/domains/reasoning-discipline.md` for the four named failure modes (over-abstraction, goal amnesia, wrong-taxonomy import, stacked dogma) and the Pólya look-back checklist.

## Execution

- **Enumerate before acting** — Before taking action on any task, list available options with effort and risk. Pick the cheapest viable one. "I don't have the exact string" is not the same as "I need to search." Derive from context first, ask second, search last. Enforced by `hooks/agent-gate.sh` on Agent tool calls.

- **Start small, verify, expand** — POC first, verify end-to-end, then harden. Each step independently verifiable before the next.

- **State verification criteria upfront** — Before implementing a non-trivial change, state what command or check will confirm it works.

- **Isolate work in worktrees** — Git worktrees for code changes, even small fixes — they often escalate. Use `/using-git-worktrees`.

- **Commit atomically inside worktrees** — If you are inside a worktree, commit on each smallest coherent change. Do not let modifications pile up unstaged. Each logical fix/refactor/feature = its own commit with a clear message. Commit after verifying the change works, before starting the next one. Leaving a mountain of mixed changes in the worktree destroys bisect, review, and rollback — and silently couples unrelated decisions.

- **Sequence and checkpoint** — 3+ files or unclear scope → outline sequence, verify each step before the next.

- **Validate risky assumptions first** — Unverified assumption (API behavior, library capability, external state) → validate before building on it.

- **Verify once, fix forward** — Run all verification checks (typecheck, tests, lint) once in parallel. No re-run unless a fix was applied. No "one last check" loops.

- **Persist expensive outputs** — Computation >few minutes → write results to disk. Marginal cost of file write is negligible; cost of re-run is not.

## Learning

- **This file is the entry point, not the whole advisory layer** — Domain-specific context arrives via hooks (friction stats, domain knowledge files) when working in matching projects. Deeper friction data lives in `friction/friction.jsonl`, queryable via `friction/scripts/query.sh`. Don't duplicate domain knowledge here — keep this file cross-domain and compact.

- **Capture every friction** — Non-trivial friction → `friction/friction.jsonl` immediately, before deciding whether to analyze further. Use `/learn`.

- **Prescribe at all applicable layers** — A single friction may need an advisory rule, a structural hook, and/or a mechanical agent. Don't route to one destination. Use `/learn`.

- **Escalate failing constraints** — Constraint existed but friction recurred → flag for escalation. 2+ advisory failures → propose structural hook. Structural workaround → propose mechanical agent.

- **Domain learnings activate contextually** — Domain-specific insights go to `friction/domains/`, not this file. They activate via hooks when working in that domain. Only store non-inferable knowledge.

## Enforcing Rules

- **Tool-level rules → implement as hooks.** If a rule can be detected in tool inputs/outputs, make it a hook. Hooks cannot be bypassed.
- **Reasoning-level rules → strengthen here + add context injection hooks.** This file is the first layer; hooks that inject context when a failure pattern is detected are the second; human oversight is the third.
- **Process-level rules → deploy as agents.** When enforcement requires multi-step reasoning or domain expertise, use a subagent with restricted tools.

---

## Active Hooks

- **step-delta-check** — PreToolUse on Write/Edit: re-asks the delta question at each material step so the discipline survives past the first action, and adds a principle-tower audit (since 2026-05-26) that asks whether an edit justified by a named theory also derives from the user's actual goal. Advisory only. (`hooks/step-delta-check.sh`)
- **agent-gate** — PreToolUse on Agent: second-layer check before Explore/general-purpose agents with numbered cost/risk options. (`hooks/agent-gate.sh`)
- **no-rm** — PreToolUse on Bash: blocks `rm` commands, enforces `trash` instead. (`hooks/no-rm.sh`)
- **commit-header-check** — PreToolUse on Bash: validates `git commit -m` header against `^(feature|infra|fix|chore|deps|docs): .+`. Blocks wrong prefix (`feat`, `doc`), scoped form (`fix(scope):`), and missing prefix. Skips `-F`, `-C`, `--amend --no-edit`, and editor-based commits. (`hooks/commit-header-check.sh`)

## Active Agents

- **self-reflect** — Friction ledger pattern analysis (`learn/agents/self-reflect.md`)

---

## Conventions

- **Skill dependency isolation** — `pnpm dlx` for Node/TS, `uv run --with` for Python. [Full doc](skill-dependency-isolation.md)

- **Use `trash` instead of `rm -rf`** — Always use `trash` (macOS `/usr/bin/trash`) for deletions. Sends to Trash instead of permanent delete.
