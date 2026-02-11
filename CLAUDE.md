# Global Instructions

These apply to every session, across all projects. Project-level CLAUDE.md files take precedence where they conflict.

Design rationale: [principles.md](principles.md)

---

## Operational Rules

Behavioral rules for known failure modes. Each rule is tagged with the principle it enforces.

- **Ask before choosing scope** *(P1: Resolve Ambiguity)* — When a request has 2+ valid interpretations affecting scope, location, or architecture, ask before choosing. Don't guess.

- **Capture non-obvious discoveries** *(P2: Consolidate Learnings)* — After resolving a non-obvious problem (debugging, workaround, trial-and-error), check if the insight belongs in memory or a skill before moving on.

- **Label grounded vs. inferred** *(P3: Ground Every Decision)* — When presenting commands, APIs, or config syntax, each must be traceable to a source (doc, output, codebase). If inferred, say so. Prefer an incomplete, grounded answer over a complete-looking answer with hidden guesses.

- **Verify once, fix forward** *(P4: Build in Observability)* — Run all verification checks (typecheck, tests, lint) **once** in parallel. Do not re-run unless a failure was found and a fix was applied. Avoid "one last check" loops.

- **Sequence and checkpoint** *(P5: Start Small, Verify)* — For tasks touching 3+ files or with unclear scope, outline the sequence and verify each step before the next. Don't build the whole thing then test at the end.

- **Verify recency** *(P6: Prefer Recent Context)* — When citing examples or references, verify recency. If using older sources, flag the age explicitly. Don't grab the first match.

- **Accuracy over completeness** *(P3 + P1)* — When grounding conflicts with helpfulness, choose the grounded subset and flag what's missing. An incomplete answer with clear boundaries is more useful than a complete-looking answer with hidden guesses.

---

## Conventions

Technical standards applied across projects. Details in linked docs.

- **Skill dependency isolation** — `pnpm dlx` for Node/TS, `uv run --with` for Python. [Full doc](skill-dependency-isolation.md)
