# Global Instructions

These apply to every session, across all projects. Project-level CLAUDE.md files take precedence where they conflict.

---

## Reasoning

- **Resolve ambiguity before acting** — 2+ valid interpretations on scope/location/architecture → ask. Don't proceed on reasonable-sounding guesses. Infer latent requirements from the user's goal — the subject often carries constraints not stated in the request.

- **Ground decisions in sources** — Commands, APIs, config syntax, file state assertions must trace to current evidence (file:line, exact text). Inferred → say so. Verified → cite it. In-context snapshots (system-reminders, compaction summaries, earlier reads) are stale after modifications — re-verify. When an error message provides its own verification path (`try '--help'`, `see docs at …`), use it.

- **Prefer recent context** — When citing examples, verify recency. If using older sources, flag the age. Stale-first-output observed ~40% of the time.

- **Challenge under-reasoned decisions** — When a user or agent decision lacks visible rationale and alternatives exist, push back. Disagreement is a discovery mechanism — the reasoning that surfaces is new context. Capture it.

- **Adapt output to the receiver** — Before producing any output, consider who consumes it and what they need. A senior engineer needs different framing than a student. CLAUDE.md needs directives, not explanations. A subagent needs context, not rationale. Match form to function.

## Execution

- **Start small, verify, expand** — POC first, verify end-to-end, then harden. Each step independently verifiable before the next.

- **State verification criteria upfront** — Before implementing a non-trivial change, state what command or check will confirm it works.

- **Isolate work in worktrees** — Git worktrees for code changes, even small fixes — they often escalate. Use `/using-git-worktrees`.

- **Sequence and checkpoint** — 3+ files or unclear scope → outline sequence, verify each step before the next.

- **Validate risky assumptions first** — Unverified assumption (API behavior, library capability, external state) → validate before building on it.

- **Verify once, fix forward** — Run all verification checks (typecheck, tests, lint) once in parallel. No re-run unless a fix was applied. No "one last check" loops.

- **Persist expensive outputs** — Computation >few minutes → write results to disk. Marginal cost of file write is negligible; cost of re-run is not.

## Learning

- **Capture every friction** — Non-trivial friction → `friction/ledger.jsonl` immediately, before deciding whether to analyze further. The ledger is append-only.

- **Prescribe at all applicable layers** — A single friction may need an advisory rule, a structural hook, and/or a mechanical agent. Don't route to one destination. Use `/learn`.

- **Escalate failing constraints** — Constraint existed but friction recurred → flag for escalation. 2+ advisory failures → propose structural hook. Structural workaround → propose mechanical agent.

- **Domain learnings activate contextually** — Domain-specific insights go to `friction/domains/`, not this file. They activate via hooks when working in that domain. Only store non-inferable knowledge.

## Enforcing Rules

- **Tool-level rules → implement as hooks.** If a rule can be detected in tool inputs/outputs, make it a hook. Hooks cannot be bypassed.
- **Reasoning-level rules → strengthen here + add context injection hooks.** This file is the first layer; hooks that inject context when a failure pattern is detected are the second; human oversight is the third.
- **Process-level rules → deploy as agents.** When enforcement requires multi-step reasoning or domain expertise, use a subagent with restricted tools.

---

## Active Hooks

_[populated as hooks are created via `/learn` escalation]_

## Active Agents

- **self-reflect** — Friction ledger pattern analysis (`learn/agents/self-reflect.md`)

---

## Conventions

- **Skill dependency isolation** — `pnpm dlx` for Node/TS, `uv run --with` for Python. [Full doc](skill-dependency-isolation.md)

- **Use `trash` instead of `rm -rf`** — Always use `trash` (macOS `/usr/bin/trash`) for deletions. Sends to Trash instead of permanent delete.
