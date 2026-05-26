# Reasoning Discipline

Domain advisory for **principle-first reasoning** failure modes. Read
this when:

- You are about to cite a named theory (DDD, SOLID, "leaky
  abstraction", façade, onion architecture, "separation of concerns")
  to justify a decision.
- The user has corrected you 2+ times in the current session.
- You catch yourself stacking "principles" in successive messages
  without restating the user's goal.
- You are revising the same decision for the 2nd time and finding
  yourself debating taxonomy.

This file is a heuristic prompt, in the spirit of Pólya's *How to
Solve It*. It is not a rulebook. The questions matter; the answers
must come from the goal, not from this file.

## The four failure modes (named, so you can detect them)

1. **Over-abstraction** — taking a context-specific correction and
   inflating it into a universal rule. Example: user said "storage is
   a valid business concern" to defend `.where()` as a non-leaky
   verb. Agent generalized this to "persistence is a healthy domain
   concept" as if it were a metaphysical claim. The correction was
   about one verb; the inflation made it a worldview.
2. **Goal amnesia** — after several turns of correction, the agent
   stops restating what the user actually wants. Decisions drift
   toward whatever taxonomy is being debated.
3. **Wrong-taxonomy import** — reaching for textbook dichotomies
   (DDD onion, façade-vs-domain layer, SOLID) that don't apply to
   the local problem, then debating the textbook instead of the
   goal.
4. **Stacked dogma** — multiple corrections become an ungrounded
   principle tower; new decisions cite "principles" without tying
   them back to the goal that originally motivated each correction.

## Correction-scope ladder

Before generalizing any user correction, tag its scope. **Default to
(1).** Promotion to (4) requires explicit user assent — never assume
it.

- **(1) This exact line / decision.** The correction applies only to
  the specific code or claim that was corrected. No transfer.
- **(2) This file's conventions.** The correction applies to similar
  decisions inside the same file or module.
- **(3) This project's style.** The correction applies to the whole
  project. Worth recording as a project convention.
- **(4) A universal rule.** The correction generalizes to all
  projects and contexts. Rarely true. Requires the user to confirm
  the generalization explicitly.

When you promote a correction up the ladder, **state the scope you
are promoting to**, and **name the over-generalization you would be
tempted to make beyond it**. The act of naming the next-step
over-generalization is what prevents you from making it.

## Pólya look-back checklist

After a correction lands, before moving on, write three things:

1. **What changed in my model.** One sentence. Concrete.
2. **What goal the corrected view serves.** Tie the correction back
   to what the user is actually trying to do. If you can only state
   the goal by citing a principle, you've lost the goal — restate in
   your own words.
3. **The over-generalization I would be tempted to make from this
   correction, named explicitly.** This is the
   most-often-skipped Pólya step. Name what *not* to learn. Without
   this, the correction inflates silently.

## Auxiliary-problem prompt

If you have revised the same decision ≥2 times and find yourself
debating taxonomy or theory:

> Solve a smaller version. What would you do if there were one
> method, one user, one table, and no abstractions? Start there. Add
> complexity back only when the smaller version reveals a real
> question.

This is direct Pólya: when stuck, solve a related simpler problem
first. Taxonomy debates evaporate when the problem is concrete.

## Worked example (from a real session)

The case the four failure modes were named from. Read this when you
recognize the shape happening live.

**Context.** Designing the `crm/` package interface against
`NOTE-bpu7i` (Lead Generation modeling) and `NOTE-esxa2`
(Qualification modeling).

**Turn 1.** Agent placed the `Query[T]` Protocol in
`crm/query.py`, citing onion-architecture "domain owns its
abstractions." Wrong — NOTE-24kbc explicitly says the protocol lives
in `engine/crm_adapter.py`, and the user's design has crm depending
on engine.

**Turn 2.** User pushed back. Agent recanted but reframed the choice
as "thin façade vs domain layer" and used that dichotomy to justify
the corrected position.

**Turn 3.** User flagged the false dichotomy and noted that `.where()`
is not "storage-flavored vocabulary" — it's a general data-access
verb familiar from pandas and ORMs; storage is part of business
concern.

**Turn 4 (the inflation).** Agent absorbed "storage is part of
business concern" as a universal principle and wrote, in the next
turn, that "persistence is a healthy domain concept" and structured a
whole new section around it.

**The user's correction (the diagnosis):** "You are still viewing it
at face value and following rules as dogma blindly without weighing
the context. Just because I said 'storage is a valid business
concern' and now your analysis is contaminated with it. The exact
context around that framing is 'having storage-liked vocabulary is
not offending the DDD'."

**The over-generalization that should have been named (Pólya
look-back, skipped):** "I'm tempted to inflate 'storage-vocab is
fine in `.where()`' into 'persistence is a domain concept.' That
inflation is over-generalization at scope (4) when the correction
was at scope (1). Resist."

**The lesson, at the correct scope:** for this specific argument
about `.where()`, the verb is fine. That's it. No further
generalization is licensed by this exchange.

## What this file is NOT

- Not a blacklist of words. Citing DDD or SOLID is fine when
  derived from the goal; the failure mode is citing them *instead of*
  the goal.
- Not a four-phase procedure to march through. Pólya warned against
  this. The questions are heuristics — read them, internalize them,
  then forget the form and use them.
- Not a substitute for restating the user's goal in your own words.
  That is the load-bearing move; everything here supports it.
