---
name: harness-review
description: Use monthly or ad-hoc to review constraint system health. Also use when friction seems to recur despite existing constraints, when CLAUDE.md feels bloated, or when you want to prune stale rules and hooks.
argument-hint: [optional focus area, e.g. "meta-api domain" or "failing constraints"]
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Agent
  - AskUserQuestion
---

# Harness Review: Constraint System Health Check

Periodic review of the entire constraint system — advisory rules, structural hooks, mechanical agents, and the friction ledger that drives them. Surfaces what's working, what's failing, what's stale, and what's missing.

Run monthly, or ad-hoc when:
- Friction seems to recur despite constraints
- CLAUDE.md feels bloated or unfocused
- You want to prune unused constraints
- A new domain has accumulated friction worth reviewing

## Process

### Step 1: Friction Summary

Run ledger queries to understand the current landscape:

```bash
# Overall statistics
~/.claude/friction/scripts/query.sh stats

# Recent friction (last 30 days)
~/.claude/friction/scripts/query.sh recent --last 50

# Top friction types
~/.claude/friction/scripts/query.sh types

# Top domains
~/.claude/friction/scripts/query.sh domains
```

**Summarize:**
- Total friction entries, trend (increasing/decreasing/stable)
- Top 3 recurring patterns (by deep_cause similarity)
- Domains with most friction
- Friction types distribution — high `rationalized-past` means advisory layer is weak

### Step 2: Constraint Inventory

Audit all three layers:

**Advisory layer:**
```bash
# Count CLAUDE.md advisory constraints
grep -c "^\- \*\*" ~/.claude/CLAUDE.md

# List memory files
find ~/.claude/projects/*/memory -name "*.md" 2>/dev/null

# List domain files
ls ~/.claude/friction/domains/ 2>/dev/null
```

**Structural layer:**
```bash
# List all hookify rules across projects
find ~ -name "hookify.*.local.md" -path "*/.claude/*" 2>/dev/null

# List hooks in settings.json
jq '.hooks // empty' ~/.claude/settings.json 2>/dev/null
```

**Mechanical layer:**
```bash
# List agent definitions
find ~/.claude/skills -name "*.md" -path "*/agents/*" 2>/dev/null
```

For each constraint, note:
- When it was added (git log or file date)
- Whether it has corresponding friction entries (is it covering a real pattern?)
- Whether friction has recurred despite it (`constraint_failed=true` entries)

### Step 3: Health Checks

Run these diagnostics and flag issues:

**Stale constraints** (added >60 days ago, no related friction since):
- Advisory rules in CLAUDE.md that address patterns no longer occurring
- Hookify rules that never fire
- Domain files for projects no longer active
- **Action:** Propose pruning. But check — constraint may be *preventing* friction invisibly. If the constraint is cheap (advisory), keep it. If expensive (structural/mechanical), consider pruning.

**Failing constraints** (constraint exists but friction recurs):
```bash
~/.claude/friction/scripts/query.sh failing --min 2
```
- **Action:** Propose escalation (advisory → structural → mechanical)

**Bloated CLAUDE.md** (>100 lines):
```bash
wc -l ~/.claude/CLAUDE.md
```
- **Action:** Identify rules that could move to domain files (domain-specific) or skills (process-specific). CLAUDE.md should contain only cross-domain, high-frequency constraints.

**Orphaned domain files** (domain-map entry exists but domain file is empty or missing):
```bash
jq -r '.rules[].domains[]' ~/.claude/friction/domain-map.json 2>/dev/null | sort -u | while read d; do
  [ ! -s ~/.claude/friction/domains/"$d".md ] && echo "Orphaned: $d"
done
```

**Unconstrained patterns** (recurring friction with no constraint at any layer):
- Query ledger for entries where `constraint_existed=null` and similar deep_causes appear 2+ times
- **Action:** These are the highest-priority items — recurring friction with zero coverage

**Prescription gaps** (friction was captured but never prescribed/implemented):
```bash
# Entries stuck at 'captured' or 'analyzed' status
jq -c 'select(.status == "captured" or .status == "analyzed")' ~/.claude/friction/ledger.jsonl 2>/dev/null | wc -l
```
- **Action:** These represent `/learn` runs that were interrupted or where implementation was deferred. Triage: implement or close.

### Step 4: Self-Reflect Analysis

Dispatch the self-reflect agent for deeper pattern analysis:

```
Agent: learn/agents/self-reflect.md
Prompt: "Full ledger analysis. Identify all patterns, propose constraint upgrades, assess harness health."
Tools: Read, Grep, Bash (read-only)
```

Incorporate the agent's findings into the report.

### Step 5: Report

Present findings to the human in this structure:

```markdown
# Harness Review — [date]

## Friction Landscape
- Total entries: N (M in last 30 days)
- Top patterns: [list with counts]
- Top domains: [list with counts]
- Trend: [improving / stable / degrading]

## Constraint Health

### Working Well
[Constraints with declining friction in their domain]

### Needs Attention
[Failing constraints — with evidence and escalation proposals]

### Stale — Prune Candidates
[Constraints with no related friction in 60+ days]

### Missing — Unconstrained Patterns
[Recurring friction with no constraints at any layer]

## Proposals (priority-ordered)
1. [Highest impact proposal with evidence]
2. [...]

## CLAUDE.md Budget
- Current: N lines
- Recommendation: [keep / compress / offload specific rules]
```

**Wait for human approval before implementing any proposals.**

---

## Quick Reference

| Check | Query | Flag if |
|-------|-------|---------|
| Stale constraints | `query.sh stats` + file dates | >60 days, no related friction |
| Failing constraints | `query.sh failing --min 2` | 2+ failures for same constraint |
| Bloated CLAUDE.md | `wc -l CLAUDE.md` | >100 lines |
| Unconstrained patterns | Ledger entries with null constraint, similar causes 2x+ | Recurring with zero coverage |
| Prescription gaps | Status = captured/analyzed | `/learn` incomplete |
