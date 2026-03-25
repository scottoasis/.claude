---
name: learn
description: Use after resolving non-obvious friction, failed approaches, debugging breakthroughs, or when reviewing session learnings. Also use when asked to "save this as a skill", "extract a skill", or "what did we learn?"
argument-hint: [friction or learning to capture]
allowed-tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
  - Skill
  - AskUserQuestion
  - WebSearch
  - Agent
---

# Learn: Friction → Constraints at Every Layer

Unified pipeline for turning friction into self-improvement. Captures every instance, analyzes to root cause depth, prescribes constraints at all applicable enforcement layers (advisory, structural, mechanical), and escalates when existing constraints fail.

Replaces `/distill` (friction routing) and subsumes `/claudeception` (skill extraction) as the primary learning pipeline.

## Three Constraint Layers

| Layer | Mechanism | Strength | Output |
|-------|-----------|----------|--------|
| **Advisory** | CLAUDE.md rules, memory, skills, domain files | Soft — guides reasoning | Rule text, memory entry, skill, domain file |
| **Structural** | Hooks (PreToolUse/PostToolUse/Stop) | Hard — blocks at tool boundaries | Hookify rule definition |
| **Mechanical** | Subagents with restricted tools | Active — parallel reasoning | Agent definition file |

A single friction may need constraints at multiple layers. Always evaluate all three.

## Process

### Step 1: Capture

**This step runs ALWAYS — before deciding whether to analyze further.**

Append a structured entry to `~/.claude/friction/ledger.jsonl`:

```jsonl
{
  "id": "f-YYYYMMDD-NNN",
  "date": "YYYY-MM-DD",
  "project": "/path/to/project",
  "domain": ["tag1", "tag2"],
  "type": "<type>",
  "description": "What happened",
  "root_cause": "First-order why",
  "deep_cause": null,
  "resolution": "What fixed it",
  "effort": "high|medium|low",
  "constraint_existed": null,
  "constraint_failed": false,
  "recurrence_of": null,
  "prescribed": {"advisory": null, "structural": null, "mechanical": null},
  "implemented": {"advisory": null, "structural": null, "mechanical": null},
  "status": "captured"
}
```

**Friction types:**
- `wrong-assumption` — Acted on unverified belief about how something works
- `missed-constraint` — No rule/hook/agent existed to prevent this class of error
- `rationalized-past` — Constraint existed but agent reasoned around it
- `tool-misuse` — Used a tool incorrectly or chose the wrong tool
- `domain-gap` — Lacked domain-specific knowledge that isn't inferable from docs
- `harness-gap` — The learning system itself failed (e.g., `/learn` produced shallow analysis)

**Domain tags:** Use concrete, specific tags. `meta-api` not `api`. `typescript-strict` not `typescript`. Tags are the primary key for pattern recognition across sessions.

**Generate ID:** `f-YYYYMMDD-NNN` where NNN is a sequential counter for that day. Check the ledger for the last ID on today's date.

**If friction occurred despite an existing constraint:** Set `constraint_existed` to the rule/hook/agent name and `constraint_failed` to `true`. This is the escalation signal.

### Step 2: Recursive Root Cause

Apply "5 Whys" starting from the first-order root cause:

1. **Why did this happen?** → First-order cause (already in `root_cause`)
2. **Why did THAT happen?** → Second-order cause
3. **Continue** until reaching one of:
   - A missing constraint (no rule/hook/agent covers this)
   - A gap in the harness itself (the learning system should have caught this earlier)
   - A domain knowledge gap (something you can only know from experience, not docs)
   - A fundamental trade-off (speed vs. correctness, scope vs. depth)

**Record the deepest cause in `deep_cause` field** of the ledger entry.

**The depth test:** If the user, reviewing your analysis, would say "yes but the REAL problem is..." — you haven't gone deep enough.

**Analytical probes to use during recursion** (not a checklist — use as needed):

- **Structural gap:** What architectural layer is _missing_ that allowed this? Distinguish "thing that broke" from "thing that should exist but doesn't."
- **Solution critique:** Where does the resolution fall on reactive → proactive → preventive? Is there a more structural approach?
- **Cross-domain check:** How do established systems solve this class of problem? Has this been solved elsewhere in a fundamentally different way?
- **Adversarial self-critique:** If someone with deep domain experience reviewed this analysis, what would they challenge?
- **Reframe:** If this learning were NOT about [the specific artifact/tool/file], what general thinking pattern does it belong to? The other probes go deeper within a frame; this one forces you to escape the frame entirely. If your root cause names a specific artifact (e.g., "CLAUDE.md", "jq query", "API endpoint"), you're probably still at the artifact level.

### Step 3: Pattern Check

Query the friction ledger for related entries:

```bash
# Same domain, similar causes
~/.claude/friction/scripts/query.sh domain <tag> --last 90

# Failing constraints
~/.claude/friction/scripts/query.sh failing --min 2

# Full-text search for similar root causes
~/.claude/friction/scripts/query.sh search "<root cause keywords>"
```

**What to look for:**
- Same domain tags + similar root causes → **recurring domain pattern** (domain file candidate)
- Same `constraint_existed` with `constraint_failed=true` → **failing constraint** (escalation candidate)
- Similar `deep_cause` across different domains → **cross-domain pattern** (CLAUDE.md rule candidate)
- 3+ domain-specific instances sharing a deep cause → **no longer a one-off** — it's a pattern worth constraining

**If recurrence found:** Set `recurrence_of` to the earliest related friction ID.

If the ledger has enough related entries (3+), dispatch the self-reflect agent for deeper pattern analysis:
```
Agent: learn/agents/self-reflect.md
Prompt: "Analyze friction ledger entries matching domain [tags]. Identify patterns, propose constraint upgrades."
Tools: Read, Grep, Bash (read-only)
```

### Step 4: Prescribe Constraints

For the friction instance, evaluate ALL three layers.

**Route by the constraint's activation scope, not by where the friction was discovered.** A friction found during `/learn` might need a CLAUDE.md rule if it applies every session. A friction found in a specific project might need a global memory entry if it's cross-project.

**Advisory — Would a rule or knowledge entry help a future agent avoid this?**

| Condition | Output |
|-----------|--------|
| Cross-domain pattern, high frequency | CLAUDE.md rule |
| Cross-domain pattern, lower frequency | Memory file |
| Domain-specific pattern | `friction/domains/<domain>.md` entry |
| Reusable process or technique | Skill (via `/claudeception`) |
| Existing rule covers it but is too vague | Sharpen existing rule |

**Structural — Is the mistake detectable at tool-use time?**

| Condition | Output |
|-----------|--------|
| Detectable in Bash command text | PreToolUse hook (event: bash) |
| Detectable in file content being written | PreToolUse hook (event: file) |
| Detectable in tool output | PostToolUse hook |
| Should be checked before completion | Stop hook |
| Not detectable by pattern matching | "Not tool-detectable" — skip structural |

**Mechanical — Does prevention require active reasoning?**

| Condition | Output |
|-----------|--------|
| Requires domain expertise to evaluate | Domain review agent |
| Requires checking multiple files/systems | Multi-step review agent |
| Requires comparing against known patterns | Pattern-matching agent |
| Simple enough for a rule or regex | "Not needed" — skip mechanical |

**Output the prescription as a tuple:**

```
Constraint Prescription:
- Advisory: [description + destination, or "existing rule X sufficient"]
- Structural: [hook definition, or "not tool-detectable"]
- Mechanical: [agent definition, or "not needed"]
```

### Step 5: Escalation Check

**Only runs when `constraint_failed=true` (Step 1 flagged an existing constraint).**

Query the ledger for the failing constraint's history:

| Evidence | Escalation |
|----------|-----------|
| Advisory rule failed 1x | Strengthen wording, add specificity, add example |
| Advisory rule failed 2x+ across sessions | **Propose structural hook** — the rule is being rationalized past |
| Structural hook fired but agent worked around it | **Propose mechanical agent** — the pattern needs active reasoning |
| Structural hook didn't fire (pattern too broad/narrow) | Fix the hook pattern |

**Present escalation proposals with evidence:**
```
Escalation Proposal:
- Constraint: "Validate risky assumptions first"
- Failure count: 3 in last 10 sessions
- Friction IDs: f-20260301-002, f-20260312-001, f-20260324-001
- Pattern: Agent skips assumption validation when under time pressure
- Proposed: PreToolUse hook on Bash — when command touches [domain] API, inject reminder
```

### Step 6: Implement

Present the full prescription (Step 4) and any escalation proposals (Step 5) to the human for approval.

**Approval rules:**
- Advisory constraints (memory entries, domain files): Can auto-create with notification
- Advisory constraints (CLAUDE.md rules): Require approval (high attention cost)
- Structural hooks: ALWAYS require approval (hard constraint, resource cost)
- Mechanical agents: ALWAYS require approval (highest cost)

**After approval, implement:**

| Output | Implementation |
|--------|---------------|
| CLAUDE.md rule | Edit `~/.claude/CLAUDE.md` — add to appropriate section (Reasoning/Execution/Learning) |
| Memory entry | Write to `~/.claude/projects/<project>/memory/` |
| Domain file | Append to `~/.claude/friction/domains/<domain>.md` |
| Skill | Invoke `/claudeception` with the abstracted strategy |
| Hookify rule | Create `.claude/hookify.<name>.local.md` in the project root |
| Agent definition | Create agent .md file in appropriate skill's `agents/` directory |

**Write for the audience** — see CLAUDE.md "Write for the audience" rule. Match writing mode to destination.

### Step 7: Update Ledger

Update the friction entry with:
- `prescribed`: What was recommended at each layer
- `implemented`: File paths of what was actually created
- `status`: `implemented`

If the user's analysis (delta) went deeper than yours, also:
1. Record a SECOND friction entry with `type: harness-gap` — the learning system itself failed
2. Note what analytical dimension was missing — this feeds back into improving Step 2

---

## When NOT to Run Full Pipeline

- **Step 1 (Capture) runs ALWAYS.** Non-negotiable. Even for trivial friction.
- **Steps 2-7 are optional** for genuinely trivial friction (typo fixes, simple misunderstandings)
- **But err toward running the full pipeline.** "Trivial" friction that recurs 5 times is not trivial — and you won't know it recurs unless you capture it.
- **Never skip for domain-specific friction.** The old system dismissed "domain-specific one-offs." The new system captures them and lets pattern recognition determine their value.

## Integration

- **After non-obvious debugging:** Run `/learn` immediately
- **End of session:** Review whether any friction occurred — if so, capture at minimum
- **User says "save as skill":** Run `/learn` — if output is a skill, it chains to `/claudeception`
- **User says "what did we learn?":** Run `/learn` in review mode across the session
- **When user provides deeper analysis:** Run Step 7's delta mechanism — their depth reveals harness gaps

## Quick Reference

| Step | Input | Output | Always? |
|------|-------|--------|---------|
| 1. Capture | Friction description | Ledger entry | YES |
| 2. Root Cause | First-order cause | Deep cause (5 Whys) | Optional |
| 3. Pattern Check | Ledger query | Recurrence evidence | Optional |
| 4. Prescribe | Analysis | Constraint tuple (advisory + structural + mechanical) | Optional |
| 5. Escalation | Failing constraint | Escalation proposal with evidence | Only if constraint_failed |
| 6. Implement | Approved prescription | Files created/edited | After approval |
| 7. Update | Implementation results | Ledger updated | After implementation |
